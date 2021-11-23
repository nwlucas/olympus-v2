resource "tls_private_key" "ssh" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "random_id" "consul_secret" {
  byte_length = 35
}

resource "random_id" "nomad_secret" {
  byte_length = 35
}
