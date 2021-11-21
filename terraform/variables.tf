variable "hashi_hosts" {
  type = map(object({
    domain         = string
    vault_enabled  = optional(bool)
    consul_enabled = optional(bool)
    nomad_enabled  = optional(bool)
  }))
}

variable "lb_hosts" {
  type = map(object({
    domain             = string
    traefik_enabled    = optional(bool)
    cf_tunnnel_enabled = optional(bool)
  }))
}

variable "ACME_EMAIL" {
  type = string
}
variable "CF_ACCOUNT_ID" {
  type = string
}
variable "APP_ZONE" {
  type = string
}

variable "access_groups" {
  type = map(object({
    email_includes = optional(list(string))
  }))
}

variable "acme_algorithm" {
  type = string

  default = "ECDSA"
  validation {
    condition     = contains(["RSA", "ECDSA"], var.acme_algorithm)
    error_message = "Must be one of: RSA, ECDSA."
  }
}

variable "acme_private_key_rsa_bits" {
  description = "The size of the generated RSA key in bits. Should only be used if var.private_key_algorithm is RSA."
  default     = 3072
}

variable "acme_private_key_ecdsa_curve" {
  description = "The name of the elliptic curve to use. Should only be used if var.private_key_algorithm is ECDSA. Must be one of P224, P256, P384 or P521."
  default     = "P256"

  validation {
    condition     = contains(["P224", "P256", "P384", "P521"], var.acme_private_key_ecdsa_curve)
    error_message = "Must be one of P224, P256, P384 or P521."
  }
}

variable "lb_apps" {
  type = list(object({
    app_name         = string
    host_name        = optional(string)
    domain           = optional(string)
    backend          = string
    proto            = optional(string)
    port             = optional(string)
    path             = optional(string)
    access_enabled   = optional(bool)
    admin_group      = string
    session_duration = optional(string)
    type             = optional(string)
    public_cert      = optional(bool)
  }))
}

variable "consul_dc" {
  type = string

  default = "dc1"
}

variable "organization_name" {
  type = string

  default = "Example Org"
}

variable "AWS_BUCKET" {
  type = string
}

variable "AWS_ACCESS_KEY_ID" {
  type = string
}

variable "AWS_SECRET_ACCESS_KEY" {
  type = string
}
variable "AWS_DEFAULT_REGION" {
  type = string
}
