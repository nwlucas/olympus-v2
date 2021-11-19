output "olympus_tunnel" {
  value = {
    cname  = cloudflare_argo_tunnel.olympus_tunnel.cname
    uuid   = cloudflare_argo_tunnel.olympus_tunnel.id
    secret = random_id.tunnel_secret.b64_std
  }
}


output "cf_apps" {
  value = local.cf_apps
}
