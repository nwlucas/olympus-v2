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
  validity_period_hours   = var.validity_period_hours


  ca_common_name     = format("%s-hashi-ca", var.hashi_datacenter)
  organization_name  = var.organization_name
  ca_public_key_path = format("%s-hashi-ca.crt", var.hashi_datacenter)
}

module "hashi_intermediate_ca" {
  source = "./modules/cert"

  aws_bucket = var.AWS_BUCKET
  aws_key    = "hashi/certs"

  private_key_algorithm   = "ECDSA"
  private_key_ecdsa_curve = "P384"
  validity_period_hours   = var.validity_period_hours


  common_name        = format("%s-connect-ca", var.hashi_datacenter)
  organization_name  = var.organization_name
  is_ca_certificate  = true
  ca_key_algorithm   = module.hashi_ca.ca_key_algorithm
  ca_private_key_pem = module.hashi_ca.ca_private_key_pem
  ca_cert_pem        = module.hashi_ca.ca_cert_pem

  cert_private_key_path = format("%s-connect-ca-key.pem", var.hashi_datacenter)
  cert_public_key_path  = format("%s-connect-ca-cert.pem", var.hashi_datacenter)

  allowed_uses = [
    "cert_signing",
    "key_encipherment",
    "digital_signature",
  ]
}

module "vault_cert" {
  source = "./modules/cert"

  for_each = { for k, v in local.hashi_hosts : k => v if v.vault_enabled }

  aws_bucket = var.AWS_BUCKET
  aws_key    = "hashi/certs/vault/cluster/${format("%s.%s", each.key, each.value.domain)}"

  private_key_algorithm   = "ECDSA"
  private_key_ecdsa_curve = "P384"
  validity_period_hours   = var.validity_period_hours


  common_name       = format("%s.%s", each.key, each.value.domain)
  organization_name = var.organization_name
  dns_names = [
    each.key,
    format("%s.%s", each.key, each.value.domain),
    format("%s.vault.service.consul", each.key),
    format("%s.vault.service.consul", format("%s.%s", each.key, each.value.domain)),
    "vault.service.consul",
    format("vault.service.%s.consul", var.hashi_datacenter),
    "vault-server",
    "localhost"
  ]
  ip_addresses       = flatten([data.dns_a_record_set.hosts[each.key].addrs, "127.0.0.1"])
  ca_key_algorithm   = module.hashi_intermediate_ca.cert_algorithm
  ca_private_key_pem = module.hashi_intermediate_ca.cert_key
  ca_cert_pem        = module.hashi_intermediate_ca.cert_pem

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
  validity_period_hours   = var.validity_period_hours


  common_name       = format("%s.%s", each.key, each.value.domain)
  organization_name = var.organization_name
  dns_names = [
    each.key,
    format("%s.%s", each.key, each.value.domain),
    format("%s.consul.service.consul", each.key),
    format("%s.consul.service.consul", format("%s.%s", each.key, each.value.domain)),
    "consul.service.consul",
    format("server.%s.consul", var.hashi_datacenter),
    "consul-server",
    "localhost"
  ]
  ip_addresses       = flatten([data.dns_a_record_set.hosts[each.key].addrs, "127.0.0.1"])
  ca_key_algorithm   = module.hashi_intermediate_ca.cert_algorithm
  ca_private_key_pem = module.hashi_intermediate_ca.cert_key
  ca_cert_pem        = module.hashi_intermediate_ca.cert_pem

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
  validity_period_hours   = var.validity_period_hours


  common_name       = format("%s.%s", each.key, each.value.domain)
  organization_name = var.organization_name
  dns_names = [
    each.key,
    format("%s.%s", each.key, each.value.domain),
    format("%s.nomad.service.consul", each.key),
    format("%s.nomad.service.consul", format("%s.%s", each.key, each.value.domain)),
    "nomad.service.consul",
    format("nomad.service.%s.consul", var.hashi_datacenter),
    "nomad-server",
    "server.global.nomad",
    "localhost"
  ]
  ip_addresses       = flatten([data.dns_a_record_set.hosts[each.key].addrs, "127.0.0.1"])
  ca_key_algorithm   = module.hashi_intermediate_ca.cert_algorithm
  ca_private_key_pem = module.hashi_intermediate_ca.cert_key
  ca_cert_pem        = module.hashi_intermediate_ca.cert_pem

  cert_private_key_path = format("nomad_%s.%s.key", each.key, each.value.domain)
  cert_public_key_path  = format("nomad_%s.%s.pem", each.key, each.value.domain)

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth"
  ]
}

module "vault_client_cert" {
  source = "./modules/cert"

  aws_bucket = var.AWS_BUCKET
  aws_key    = "hashi/certs/vault/client"

  private_key_algorithm   = "ECDSA"
  private_key_ecdsa_curve = "P384"
  validity_period_hours   = var.validity_period_hours


  common_name       = "vault-client"
  organization_name = var.organization_name
  dns_names = concat([
    "vault.service.consul",
    "vault-client.service.consul",
    format("vault-client.%s.consul", var.hashi_datacenter),
    format("vault-client.service.%s.consul", var.hashi_datacenter),
    "vault-client",
    ],
    [for k, h in local.hashi_hosts : format("%s.%s", k, h.domain)]
  )
  ip_addresses       = flatten(concat([for k, v in data.dns_a_record_set.hosts : v.addrs], ["127.0.0.1"]))
  ca_key_algorithm   = module.hashi_intermediate_ca.cert_algorithm
  ca_private_key_pem = module.hashi_intermediate_ca.cert_key
  ca_cert_pem        = module.hashi_intermediate_ca.cert_pem

  cert_private_key_path = format("vault_%s_client_key.pem", var.hashi_datacenter)
  cert_public_key_path  = format("vault_%s_client_crt.pem", var.hashi_datacenter)

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth"
  ]
}

module "nomad_client_cert" {
  source = "./modules/cert"

  aws_bucket = var.AWS_BUCKET
  aws_key    = "hashi/certs/nomad/client"

  private_key_algorithm   = "ECDSA"
  private_key_ecdsa_curve = "P384"
  validity_period_hours   = var.validity_period_hours


  common_name       = "nomad-client"
  organization_name = var.organization_name
  dns_names = concat([
    "nomad.service.consul",
    "nomad-client.service.consul",
    format("nomad-client.%s.consul", var.hashi_datacenter),
    format("nomad-client.service.%s.consul", var.hashi_datacenter),
    "client.global.nomad",
    "nomad-client",
    ],
    [for k, h in local.hashi_hosts : format("%s.%s", k, h.domain)]
  )
  ip_addresses       = flatten(concat([for k, v in data.dns_a_record_set.hosts : v.addrs], ["127.0.0.1"]))
  ca_key_algorithm   = module.hashi_intermediate_ca.cert_algorithm
  ca_private_key_pem = module.hashi_intermediate_ca.cert_key
  ca_cert_pem        = module.hashi_intermediate_ca.cert_pem

  cert_private_key_path = format("nomad_%s_client_key.pem", var.hashi_datacenter)
  cert_public_key_path  = format("nomad_%s_client_crt.pem", var.hashi_datacenter)

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth"
  ]
}

module "consul_client_cert" {
  source = "./modules/cert"

  aws_bucket = var.AWS_BUCKET
  aws_key    = "hashi/certs/consul/client"

  private_key_algorithm   = "ECDSA"
  private_key_ecdsa_curve = "P384"
  validity_period_hours   = var.validity_period_hours


  common_name       = "consul-client"
  organization_name = var.organization_name
  dns_names = concat([
    "client.consul.service.consul",
    "consul.service.consul",
    "consul-client.service.consul",
    format("client.consul.service.%s.consul", var.hashi_datacenter),
    format("client.consul.%s.consul", var.hashi_datacenter),
    format("consul-client.%s.consul", var.hashi_datacenter),
    format("consul-client.service.%s.consul", var.hashi_datacenter),
    "consul-client",
    ],
    [for k, h in local.hashi_hosts : format("%s.%s", k, h.domain)]
  )
  ip_addresses       = flatten(concat([for k, v in data.dns_a_record_set.hosts : v.addrs], ["127.0.0.1"]))
  ca_key_algorithm   = module.hashi_intermediate_ca.cert_algorithm
  ca_private_key_pem = module.hashi_intermediate_ca.cert_key
  ca_cert_pem        = module.hashi_intermediate_ca.cert_pem

  cert_private_key_path = format("consul_%s_client_key.pem", var.hashi_datacenter)
  cert_public_key_path  = format("consul_%s_client_crt.pem", var.hashi_datacenter)

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth"
  ]
}
