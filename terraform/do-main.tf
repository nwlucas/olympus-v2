locals {
  droplet_specs = defaults(var.droplet_specs, {
    image  = "ubuntu-21-04-x64"
    region = "nyc3"
    size   = "s-1vcpu-1gb"
  })

  cf_zones = distinct(compact([for z in local.droplet_specs : z.dns_zone]))
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

data "cloudflare_zone" "zones" {
  for_each = toset(local.cf_zones)

  name       = each.key
  account_id = var.CF_ACCOUNT_ID
}

resource "random_id" "do_tunnel_secrets" {
  count = var.node_count

  byte_length = 35
}

resource "cloudflare_argo_tunnel" "do_tunnels" {
  count = var.node_count

  account_id = var.CF_ACCOUNT_ID
  name       = "do-${local.nc_nodes_fqdn[count.index]}"
  secret     = random_id.do_tunnel_secrets[count.index].b64_std
}

data "digitalocean_regions" "available" {
  filter {
    key    = "available"
    values = ["true"]
  }
  filter {
    key    = "features"
    values = ["backups", "metadata", "ipv6"]
  }
  sort {
    key       = "name"
    direction = "desc"
  }
}

resource "digitalocean_ssh_key" "tf_ssh" {
  name       = "TF SSH"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "digitalocean_vpc" "nc_internal" {
  name     = "nomad-consul-network"
  region   = local.droplet_specs["generic"].region
  ip_range = "10.10.10.0/24"
}

resource "digitalocean_project" "homelab_nc_cluster" {
  name        = var.nc_project["name"]
  description = var.nc_project["description"]
  purpose     = var.nc_project["purpose"]
  environment = var.nc_project["environment"]
  resources   = flatten([digitalocean_droplet.nc_nodes[*].urn])
}
