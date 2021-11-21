variable "hashi_hosts" {
  type = map(object({
    domain         = string
    vault_enabled  = optional(bool)
    consul_enabled = optional(bool)
    nomad_enabled  = optional(bool)
  }))
}

variable "organization_name" {
  type = string
}

locals {
  hashi_hosts = defaults(var.hashi_hosts, {
    vault_enabled  = true
    consul_enabled = true
    nomad_enabled  = true
  })
}

data "dns_a_record_set" "hashi_hosts" {
  for_each = var.hashi_hosts

  host = format("%s.%s", each.key, each.value.domain)
}

module "vault_ca" {
  source = "./modules/ca"

  private_key_algorithm   = "ECDSA"
  private_key_ecdsa_curve = "P384"

  ca_common_name     = "vault-ca"
  organization_name  = var.organization_name
  ca_public_key_path = "vault-ca.crt"
}

module "consul_ca" {
  source = "./modules/ca"

  private_key_algorithm   = "ECDSA"
  private_key_ecdsa_curve = "P384"

  ca_common_name     = "consul-ca"
  organization_name  = var.organization_name
  ca_public_key_path = "consul-ca.crt"
}

module "nomad_ca" {
  source = "./modules/ca"

  private_key_algorithm   = "ECDSA"
  private_key_ecdsa_curve = "P384"

  ca_common_name     = "nomad-ca"
  organization_name  = var.organization_name
  ca_public_key_path = "nomad-ca.crt"
}

module "vault_cert" {
  source = "./modules/cert"

  for_each = { for k, v in var.hashi_hosts : k => v if v.vault_enabled }

  private_key_algorithm   = "ECDSA"
  private_key_ecdsa_curve = "P384"

  common_name       = each.value
  organization_name = var.organization_name
  dns_names = [
    each.key,
    format("%s.%s", each.key, each.value.domain),
    format("%s.service.consul", each.key),
    format("%s.service.consul", format("%s.%s", each.key, each.value.domain)),
    "vault-server"
  ]
  ip_addresses       = data.dns_a_record_set.hashi_hosts[each.key].addrs
  ca_key_algorithm   = module.vault_ca.ca_key_algorithm
  ca_private_key_pem = module.vault_ca.ca_private_key_pem
  ca_cert_pem        = module.vault_ca.ca_cert_pem

  cert_private_key_path = format("vault_%s.key", each.value)
  cert_public_key_path  = format("vault_%s.pem", each.value)

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth"
  ]
}

module "consul_cert" {
  source = "./modules/cert"

  for_each = { for k, v in var.hashi_hosts : k => v if v.consul_enabled }

  private_key_algorithm   = "ECDSA"
  private_key_ecdsa_curve = "P384"

  common_name       = each.value
  organization_name = var.organization_name
  dns_names = [
    each.key,
    format("%s.%s", each.key, each.value.domain),
    format("%s.service.consul", each.key),
    format("%s.service.consul", format("%s.%s", each.key, each.value.domain)),
    "consul-server"
  ]
  ip_addresses       = data.dns_a_record_set.hashi_hosts[each.key].addrs
  ca_key_algorithm   = module.consul_ca.ca_key_algorithm
  ca_private_key_pem = module.consul_ca.ca_private_key_pem
  ca_cert_pem        = module.consul_ca.ca_cert_pem

  cert_private_key_path = format("consul_%s.key", each.value)
  cert_public_key_path  = format("consul_%s.pem", each.value)

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth"
  ]
}

module "nomad_cert" {
  source = "./modules/cert"

  for_each = { for k, v in var.hashi_hosts : k => v if v.nomad_enabled }

  private_key_algorithm   = "ECDSA"
  private_key_ecdsa_curve = "P384"

  common_name       = format("%s.%s", each.key, each.value.domain)
  organization_name = var.organization_name
  dns_names = [
    each.key,
    format("%s.%s", each.key, each.value.domain),
    format("%s.service.consul", each.key),
    format("%s.service.consul", format("%s.%s", each.key, each.value.domain)),
    "nomad-server"
  ]
  ip_addresses       = data.dns_a_record_set.hashi_hosts[each.key].addrs
  ca_key_algorithm   = module.nomad_ca.ca_key_algorithm
  ca_private_key_pem = module.nomad_ca.ca_private_key_pem
  ca_cert_pem        = module.nomad_ca.ca_cert_pem

  cert_private_key_path = format("nomad_%s.key", each.value)
  cert_public_key_path  = format("nomad_%s.pem", each.value)

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth"
  ]
}
