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

output "hashi_ca" {
  value = {
    pub = module.hashi_ca.ca_cert_pem
    prv = module.hashi_ca.ca_private_key_pem
  }

  sensitive = true
}

output "nomad_hosts" {
  value = { for k, v in local.hashi_hosts : format("%s.%s", k, v.domain) => {
    shortname = k
    cluster = {
      pub_cert = module.nomad_cert[k].cert_public_key
      prv_key  = module.nomad_cert[k].cert_private_key
    }
    } if v.nomad_enabled
  }
  sensitive = true
}

output "consul_hosts" {
  value = { for k, v in local.hashi_hosts : format("%s.%s", k, v.domain) => {
    shortname = k
    cluster = {
      pub_cert = module.consul_cert[k].cert_public_key
      prv_key  = module.consul_cert[k].cert_private_key
    }

    } if v.consul_enabled
  }
  sensitive = true
}

output "vault_hosts" {
  value = { for k, v in local.hashi_hosts : format("%s.%s", k, v.domain) => {
    shortname = k
    cluster = {
      pub_cert = module.vault_cert[k].cert_public_key
      prv_key  = module.vault_cert[k].cert_private_key
    }
    } if v.vault_enabled
  }
  sensitive = true
}
