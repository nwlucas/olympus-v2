output "olympus_tunnel" {
  value = {
    cname      = cloudflare_argo_tunnel.olympus_tunnel.cname
    uuid       = cloudflare_argo_tunnel.olympus_tunnel.id
    secret     = random_id.tunnel_secret.b64_std
    name       = cloudflare_argo_tunnel.olympus_tunnel.name
    account_id = var.CF_ACCOUNT_ID
  }
}


output "cf_apps" {
  value = local.cf_apps
}
