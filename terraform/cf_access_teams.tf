locals {
  access_groups = defaults(var.access_groups, {
    email_includes = ""
  })

  lb_apps = defaults(var.lb_apps, {
    host_name        = ""
    domain           = var.APP_ZONE
    proto            = "https"
    port             = "443"
    path             = ""
    session_duration = "1h"
    access_enabled   = true
    type             = "self_hosted"
    public_cert      = false
  })

  cf_apps = [for app in local.lb_apps :
    {
      app_name         = app.app_name
      host_name        = app.host_name == "" ? app.app_name : app.host_name
      domain           = app.domain
      access_enabled   = app.access_enabled
      service          = format("%s://%s:%s", app.proto, app.backend, app.port)
      session_duration = app.session_duration
      proto            = app.proto
      port             = app.port
      path             = app.path
      public_cert      = app.public_cert
      type             = app.type
      cname            = app.host_name == "" ? format("%s.%s", app.app_name, app.domain) : format("%s.%s", app.host_name, app.domain)
    }
  ]
}

data "cloudflare_ip_ranges" "cloudflare" {}

data "dns_a_record_set" "cloudflare_tunnel_region" {
  for_each = toset(["region1.argotunnel.com", "region2.argotunnel.com"])
  host     = each.key
}
data "dns_a_record_set" "cloudflare_tunnel_api" {
  for_each = toset(["api.cloudflare.com"])
  host     = each.key
}
data "cloudflare_zone" "app_zone" {
  for_each = toset(distinct(compact([for i, app in local.cf_apps : app.domain])))

  account_id = var.CF_ACCOUNT_ID
  name       = each.key
}
resource "random_id" "tunnel_secret" {
  byte_length = 35
}

resource "cloudflare_argo_tunnel" "olympus_tunnel" {
  account_id = var.CF_ACCOUNT_ID
  name       = "olympus-tunnel"
  secret     = random_id.tunnel_secret.b64_std
}

resource "cloudflare_access_group" "access_groups" {
  for_each = local.access_groups

  account_id = var.CF_ACCOUNT_ID
  name       = each.key
  include {
    email = each.value.email_includes
  }
}

resource "cloudflare_access_application" "access_apps" {
  for_each = { for app in local.cf_apps : app.app_name => app if app.access_enabled }

  account_id       = var.CF_ACCOUNT_ID
  name             = each.key
  domain           = each.value.host_name == "" ? format("%s.%s", each.value.app_name, each.value.domain) : format("%s.%s", each.value.host_name, each.value.domain)
  type             = each.value.type
  session_duration = each.value.session_duration
}

resource "cloudflare_access_policy" "admin_policies" {
  for_each = cloudflare_access_application.access_apps

  application_id = each.value.id
  zone_id        = each.value.zone_id
  name           = "Admin-Access"
  precedence     = "1"
  decision       = "allow"

  include {
    group = [
      cloudflare_access_group.access_groups[(element([for e in local.lb_apps : e if e.app_name == each.key], 0)).admin_group].id
    ]
  }
}

resource "cloudflare_record" "apps_cnames" {
  for_each = { for app in local.cf_apps : app.app_name => app }

  zone_id = data.cloudflare_zone.app_zone[each.value.domain].id
  type    = "CNAME"
  name    = each.value.host_name
  value   = format("%s.cfargotunnel.com", cloudflare_argo_tunnel.olympus_tunnel.id)
  proxied = true
}

resource "cloudflare_workers_kv_namespace" "access_apps_ns" {
  title = "ACCESSAPPS"
}

resource "cloudflare_access_ca_certificate" "access_ssh_certificates" {
  for_each = { for app in local.cf_apps : app.app_name => app if app.proto == "ssh" }

  zone_id        = cloudflare_access_application.access_apps[each.key].zone_id
  application_id = cloudflare_access_application.access_apps[each.key].id
}

resource "cloudflare_workers_kv" "access_apps" {
  for_each = cloudflare_access_application.access_apps

  namespace_id = cloudflare_workers_kv_namespace.access_apps_ns.id
  key          = each.key
  value = jsonencode({
    "hostname"       = each.value.domain,
    "service"        = one([for s in local.cf_apps : s.service if s.app_name == each.key]),
    "application_id" = each.value.id,
    "zone_id"        = each.value.zone_id,
    "ssh_key"        = try(cloudflare_access_ca_certificate.access_ssh_certificates[each.key].public_key, "")
  })
}
