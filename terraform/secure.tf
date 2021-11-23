resource "tls_private_key" "ssh_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "aws_s3_bucket_object" "ssh_key" {
  for_each = {
    "pub" = tls_private_key.ssh_key.public_key_openssh
    "prv" = tls_private_key.ssh_key.private_key_pem
  }

  bucket  = var.AWS_BUCKET
  key     = each.key == "pub" ? "/ssh_keys/ssh_instance.pub" : "/ssh_keys/ssh_instance"
  content = each.value
}

resource "random_id" "consul_secret" {
  byte_length = 35
}

resource "aws_s3_bucket_object" "consul_secret" {
  bucket  = var.AWS_BUCKET
  key     = "/hashi/consul_secret"
  content = random_id.consul_secret.b64_std
}

resource "random_id" "nomad_secret" {
  byte_length = 35
}

resource "aws_s3_bucket_object" "nomad_secret" {
  bucket  = var.AWS_BUCKET
  key     = "/hashi/nomad_secret"
  content = random_id.nomad_secret.b64_std
}
