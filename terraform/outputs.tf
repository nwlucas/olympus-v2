output "olympus_tunnel" {
  value = {
    "cname"      = cloudflare_argo_tunnel.olympus_tunnel.cname
    "uuid"       = cloudflare_argo_tunnel.olympus_tunnel.id
    "secret"     = random_id.tunnel_secret.b64_std
    "name"       = cloudflare_argo_tunnel.olympus_tunnel.name
    "account_id" = var.CF_ACCOUNT_ID
  }
}
output "cf_apps" {
  value = local.cf_apps
}

output "hashi_cas" {
  value = {
    "root" = {
      "pub" = module.hashi_ca.ca_cert_pem
      "prv" = module.hashi_ca.ca_private_key_pem
    }
    "intermediate" = {
      "pub" = module.hashi_intermediate_ca.cert_pem
      "prv" = module.hashi_intermediate_ca.cert_key
    }

  }

  sensitive = true
}

output "nomad_hosts" {
  value = {
    "datacenter"   = var.hashi_datacenter
    "nomad_secret" = random_id.nomad_secret.b64_std
    "client" = {
      "${var.hashi_datacenter}" = module.nomad_client_cert
    }
    "cluster" = { for k, v in local.hashi_hosts : format("%s.%s", k, v.domain) => {
      pub_cert = module.nomad_cert[k].cert_public_key
      prv_key  = module.nomad_cert[k].cert_private_key
      } if v.nomad_enabled
    }
  }
  sensitive = true
}

output "consul_hosts" {
  value = {
    "datacenter"    = var.hashi_datacenter
    "consul_secret" = random_id.consul_secret.b64_std
    "client" = {
      "${var.hashi_datacenter}" = module.consul_client_cert
    }
    "cluster" = { for k, v in local.hashi_hosts : format("%s.%s", k, v.domain) => {
      pub_cert = module.consul_cert[k].cert_public_key
      prv_key  = module.consul_cert[k].cert_private_key
      } if v.consul_enabled
    }
  }
  sensitive = true
}

output "vault_hosts" {
  value = {
    "datacenter" = var.hashi_datacenter
    "client" = {
      "${var.hashi_datacenter}" = module.vault_client_cert
    }
    "cluster" = { for k, v in local.hashi_hosts : format("%s.%s", k, v.domain) => {
      pub_cert = module.vault_cert[k].cert_public_key
      prv_key  = module.vault_cert[k].cert_private_key
      } if v.vault_enabled
    }
  }
  sensitive = true
}

output "ssh_key" {
  value = {
    "prv" = tls_private_key.ssh_key.private_key_pem
    "pub" = tls_private_key.ssh_key.public_key_openssh
  }
  sensitive = true
}

output "dns_a_records" {
  value = data.dns_a_record_set.hosts
}

# output "cloudflare_ips" {
#   value = flatten(data.cloudflare_ip_ranges.cloudflare.cidr_blocks)
# }

# output "nodes" {
#   value = digitalocean_droplet.nc_nodes[*].urn
# }

# output "vpc" {
#   value = digitalocean_vpc.nc_internal.id
# }

# output "project_homelab" {
#   value = digitalocean_project.homelab_nc_cluster.id
# }

# output "available_regions" {
#   value = data.digitalocean_regions.available.regions[*].slug
# }
