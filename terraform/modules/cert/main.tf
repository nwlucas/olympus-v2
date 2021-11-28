variable "private_key_algorithm" {
  description = "The name of the algorithm to use for private keys. Must be one of: RSA or ECDSA."
  default     = "RSA"

  validation {
    condition     = contains(["RSA", "ECDSA"], var.private_key_algorithm)
    error_message = "Must be one of: RSA or ECDSA."
  }
}

variable "private_key_rsa_bits" {
  description = "The size of the generated RSA key in bits. Should only be used if var.private_key_algorithm is RSA."
  default     = 2048
}

variable "private_key_ecdsa_curve" {
  description = "The name of the elliptic curve to use. Should only be used if var.private_key_algorithm is ECDSA. Must be one of P224, P256, P384 or P521."
  default     = "P224"

  validation {
    condition     = contains(["P224", "P256", "P384", "P521"], var.private_key_ecdsa_curve)
    error_message = "Must be one of P224, P256, P384 or P521."
  }
}

variable "validity_period_hours" {
  description = "The number of hours after initial issuing that the certificate will become invalid."
  default     = 8760
}

variable "organization_name" {
  description = "The name of the organization to associate with the certificates (e.g. Acme Co)."
  default     = "Example Organization"
}

variable "common_name" {
  description = "The common name to use in the subject of the certificate (e.g. acme.co cert)."
}

variable "dns_names" {
  description = "List of DNS names for which the certificate will be valid (e.g. foo.example.com)."
  type        = list(string)

  default = []
}

variable "ip_addresses" {
  description = "List of IP addresses for which the certificate will be valid (e.g. 192.168.254.1)."
  type        = list(string)

  default = []
}

variable "uris" {
  description = "List of URIs for which the certificate will be valid (e.g. 192.168.254.1)."
  type        = list(string)

  default = []
}

variable "ca_key_algorithm" {
  description = "The name of Algorithm used for CA key"
}

variable "ca_private_key_pem" {
  description = "Private key pem of CA"
}

variable "allowed_uses" {
  description = "List of keywords from RFC5280 describing a use that is permitted for the issued certificate. For more info and the list of keywords, see https://www.terraform.io/docs/providers/tls/r/self_signed_cert.html#allowed_uses."
  type        = list(string)

  default = [
    "key_encipherment",
    "digital_signature",
  ]
}

variable "is_ca_certificate" {
  type = bool

  default = false
}

variable "ca_cert_pem" {
  description = "Cert PEM of CA"
}

variable "cert_public_key_path" {
  description = "Path to store the certificate public key"
}

variable "cert_private_key_path" {
  description = "Path to store the private key of certificate"
}

variable "aws_bucket" {
  type = string
}

variable "aws_key" {
  type = string
}

variable "write_local" {
  type        = bool
  description = "Determine if to write certs to local files."

  default = false
}

resource "tls_private_key" "cert" {
  algorithm   = var.private_key_algorithm
  ecdsa_curve = var.private_key_ecdsa_curve
  rsa_bits    = var.private_key_rsa_bits
}

resource "local_file" "cert_file" {
  count = var.write_local ? 1 : 0

  content  = tls_private_key.cert.private_key_pem
  filename = var.cert_private_key_path
}

resource "tls_cert_request" "cert" {
  key_algorithm   = tls_private_key.cert.algorithm
  private_key_pem = tls_private_key.cert.private_key_pem

  dns_names    = var.dns_names
  ip_addresses = var.ip_addresses
  uris         = var.uris

  subject {
    common_name  = var.common_name
    organization = var.organization_name
  }
}

resource "tls_locally_signed_cert" "cert" {
  cert_request_pem = tls_cert_request.cert.cert_request_pem

  ca_key_algorithm   = var.ca_key_algorithm
  ca_private_key_pem = var.ca_private_key_pem
  ca_cert_pem        = var.ca_cert_pem
  is_ca_certificate  = var.is_ca_certificate

  validity_period_hours = var.validity_period_hours
  allowed_uses          = var.allowed_uses
}

resource "local_file" "cert_public_key" {
  count = var.write_local ? 1 : 0

  content  = tls_locally_signed_cert.cert.cert_pem
  filename = var.cert_public_key_path
}

resource "aws_s3_bucket_object" "cert_key" {
  bucket  = var.aws_bucket
  key     = format("%s/%s", var.aws_key, var.cert_private_key_path)
  content = tls_private_key.cert.private_key_pem
}

resource "aws_s3_bucket_object" "cert_pem" {
  bucket  = var.aws_bucket
  key     = format("%s/%s", var.aws_key, var.cert_public_key_path)
  content = tls_locally_signed_cert.cert.cert_pem
}

output "cert_algorithm" {
  value = tls_private_key.cert.algorithm
}

output "cert_pem" {
  value = tls_locally_signed_cert.cert.cert_pem
}

output "cert_key" {
  value = tls_private_key.cert.private_key_pem
}

output "cert_private_key" {
  value = {
    filename = var.cert_private_key_path
    cert     = nonsensitive(tls_private_key.cert.private_key_pem)
  }
}

output "cert_public_key" {
  value = {
    filename = var.cert_public_key_path
    cert     = tls_locally_signed_cert.cert.cert_pem
  }
}
