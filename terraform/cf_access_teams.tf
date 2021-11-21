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
      app_name       = app.app_name
      host_name      = app.host_name == "" ? app.app_name : app.host_name
      domain         = app.domain
      access_enabled = app.access_enabled
      service        = format("%s://%s:%s", app.proto, app.backend, app.port)
      proto          = app.proto
      port           = app.port
      path           = app.path
      public_cert    = app.public_cert
      cname          = app.host_name == "" ? format("%s.%s", app.app_name, app.domain) : format("%s.%s", app.host_name, app.domain)
    }
  ]
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
  for_each = { for app in local.lb_apps : app.app_name => app if app.access_enabled }

  zone_id          = data.cloudflare_zone.app_zone[each.value.domain].id
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
