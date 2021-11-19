variable "CF_ACCOUNT_ID" {
  type = string
}

variable "APP_ZONE" {
  type = string
}

variable "access_apps" {
  type = list(object({
    name    = string
    service = string
  }))
}

locals {
  cf_apps = [for app in var.access_apps :
    {
      "name"    = app.name
      "service" = app.service
      "cname"   = format("%s.%s", app.name, var.APP_ZONE)
    }
  ]
}

data "cloudflare_zone" "app_zone" {
  account_id = var.CF_ACCOUNT_ID
  name       = var.APP_ZONE
}
resource "random_id" "tunnel_secret" {
  byte_length = 35
}

resource "cloudflare_argo_tunnel" "olympus_tunnel" {
  account_id = var.CF_ACCOUNT_ID
  name       = "olympus-tunnel"
  secret     = random_id.tunnel_secret.b64_std
}

resource "cloudflare_access_group" "olympus_group" {
  account_id = var.CF_ACCOUNT_ID
  name       = "olympus_group"

  include {
    email = ["nigel.williamslucas@gmail.com", "nigel.williamslucas@pm.me"]
  }
}

resource "cloudflare_access_application" "ssh_apps" {
  for_each = { for app in var.access_apps : app.name => app }

  zone_id          = data.cloudflare_zone.app_zone.id
  name             = each.key
  domain           = format("%s.%s", each.key, var.APP_ZONE)
  type             = "self_hosted"
  session_duration = "1h"

}

resource "cloudflare_access_policy" "ssh_admin_policies" {
  for_each = cloudflare_access_application.ssh_apps

  application_id = each.value.id
  zone_id        = each.value.zone_id
  name           = "Admin-Access"
  precedence     = "1"
  decision       = "allow"

  include {
    group = [cloudflare_access_group.olympus_group.id]
  }
}

resource "cloudflare_record" "ssh_apps_cnames" {
  for_each = cloudflare_access_application.ssh_apps

  zone_id = data.cloudflare_zone.app_zone.id
  type    = "CNAME"
  name    = each.key
  value   = format("%s.cfargotunnel.com", cloudflare_argo_tunnel.olympus_tunnel.id)
  proxied = true
}
