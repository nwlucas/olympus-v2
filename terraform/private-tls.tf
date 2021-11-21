locals {
  hashi_hosts = defaults(var.hashi_hosts, {
    vault_enabled  = true
    consul_enabled = true
    nomad_enabled  = true
  })

  lb_hosts = defaults(var.lb_hosts, {
    traefik_enabled    = false
    cf_tunnnel_enabled = true
  })
}

data "dns_a_record_set" "hosts" {
  for_each = merge(local.hashi_hosts, local.lb_hosts)

  host = format("%s.%s", each.key, each.value.domain)
}

module "hashi_ca" {
  source = "./modules/ca"

  aws_bucket = var.AWS_BUCKET
  aws_key    = "hashi/certs"

  private_key_algorithm   = "ECDSA"
  private_key_ecdsa_curve = "P384"

  ca_common_name     = "hashi-ca"
  organization_name  = var.organization_name
  ca_public_key_path = "hashi-ca.crt"
}

module "vault_cert" {
  source = "./modules/cert"

  for_each = { for k, v in local.hashi_hosts : k => v if v.vault_enabled }

  aws_bucket = var.AWS_BUCKET
  aws_key    = "hashi/certs/vault/cluster/${format("%s.%s", each.key, each.value.domain)}"

  private_key_algorithm   = "ECDSA"
  private_key_ecdsa_curve = "P384"

  common_name       = format("%s.%s", each.key, each.value.domain)
  organization_name = var.organization_name
  dns_names = [
    each.key,
    format("%s.%s", each.key, each.value.domain),
    format("%s.vault.service.consul", each.key),
    format("%s.vault.service.consul", format("%s.%s", each.key, each.value.domain)),
    "vault.service.consul",
    "vault-server"
  ]
  ip_addresses       = data.dns_a_record_set.hosts[each.key].addrs
  ca_key_algorithm   = module.hashi_ca.ca_key_algorithm
  ca_private_key_pem = module.hashi_ca.ca_private_key_pem
  ca_cert_pem        = module.hashi_ca.ca_cert_pem

  cert_private_key_path = format("vault_%s.%s.key", each.key, each.value.domain)
  cert_public_key_path  = format("vault_%s.%s.pem", each.key, each.value.domain)

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth"
  ]
}

module "consul_cert" {
  source = "./modules/cert"

  for_each = { for k, v in local.hashi_hosts : k => v if v.consul_enabled }

  aws_bucket = var.AWS_BUCKET
  aws_key    = "hashi/certs/consul/cluster/${format("%s.%s", each.key, each.value.domain)}"

  private_key_algorithm   = "ECDSA"
  private_key_ecdsa_curve = "P384"

  common_name       = format("%s.%s", each.key, each.value.domain)
  organization_name = var.organization_name
  dns_names = [
    each.key,
    format("%s.%s", each.key, each.value.domain),
    format("%s.consul.service.consul", each.key),
    format("%s.consul.service.consul", format("%s.%s", each.key, each.value.domain)),
    "consul.service.consul",
    "consul-server"
  ]
  ip_addresses       = data.dns_a_record_set.hosts[each.key].addrs
  ca_key_algorithm   = module.hashi_ca.ca_key_algorithm
  ca_private_key_pem = module.hashi_ca.ca_private_key_pem
  ca_cert_pem        = module.hashi_ca.ca_cert_pem

  cert_private_key_path = format("consul_%s.%s.key", each.key, each.value.domain)
  cert_public_key_path  = format("consul_%s.%s.pem", each.key, each.value.domain)

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth"
  ]
}

module "nomad_cert" {
  source = "./modules/cert"

  for_each = { for k, v in local.hashi_hosts : k => v if v.nomad_enabled }

  aws_bucket = var.AWS_BUCKET
  aws_key    = "hashi/certs/nomad/cluster/${format("%s.%s", each.key, each.value.domain)}"

  private_key_algorithm   = "ECDSA"
  private_key_ecdsa_curve = "P384"

  common_name       = format("%s.%s", each.key, each.value.domain)
  organization_name = var.organization_name
  dns_names = [
    each.key,
    format("%s.%s", each.key, each.value.domain),
    format("%s.nomad.service.consul", each.key),
    format("%s.nomad.service.consul", format("%s.%s", each.key, each.value.domain)),
    "nomad.service.consul",
    "nomad-server"
  ]
  ip_addresses       = data.dns_a_record_set.hosts[each.key].addrs
  ca_key_algorithm   = module.hashi_ca.ca_key_algorithm
  ca_private_key_pem = module.hashi_ca.ca_private_key_pem
  ca_cert_pem        = module.hashi_ca.ca_cert_pem

  cert_private_key_path = format("nomad_%s.%s.key", each.key, each.value.domain)
  cert_public_key_path  = format("nomad_%s.%s.pem", each.key, each.value.domain)

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth"
  ]
}
