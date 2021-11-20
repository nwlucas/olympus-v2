
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
  default     = 3072
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

variable "ca_common_name" {
  description = "The common name to use in the subject of the CA certificate (e.g. acme.co cert)."
  default     = "example.com"
}

variable "organization_name" {
  description = "The name of the organization to associate with the certificates (e.g. Acme Co)."
  default     = "Example Organization"
}

variable "ca_allowed_uses" {
  description = "List of keywords from RFC5280 describing a use that is permitted for the CA certificate. For more info and the list of keywords, see https://www.terraform.io/docs/providers/tls/r/self_signed_cert.html#allowed_uses."
  type        = list(string)

  default = [
    "cert_signing",
    "key_encipherment",
    "digital_signature",
  ]
}

variable "ca_public_key_path" {
  description = "Path at which CA Public key will be stored."
}

variable "write_local" {
  type        = bool
  description = "Determine if to write certs to local files."

  default = false
}

resource "tls_private_key" "ca" {
  algorithm   = var.private_key_algorithm
  rsa_bits    = var.private_key_rsa_bits
  ecdsa_curve = var.private_key_ecdsa_curve
}

resource "tls_self_signed_cert" "ca" {
  key_algorithm         = tls_private_key.ca.algorithm
  private_key_pem       = tls_private_key.ca.private_key_pem
  is_ca_certificate     = true
  validity_period_hours = var.validity_period_hours
  allowed_uses          = var.ca_allowed_uses

  subject {
    common_name  = var.ca_common_name
    organization = var.organization_name
  }
}

resource "local_file" "ca_public_key" {
  count = var.write_local ? 1 : 0

  content  = tls_self_signed_cert.ca.cert_pem
  filename = var.ca_public_key_path
}

output "ca_key_algorithm" {
  value = tls_private_key.ca.algorithm
}

output "ca_private_key_pem" {
  value = tls_private_key.ca.private_key_pem
}

output "ca_cert_pem" {
  value = tls_self_signed_cert.ca.cert_pem
}
