variable "hashi_hosts" {
  type = map(object({
    domain         = string
    vault_enabled  = optional(bool)
    consul_enabled = optional(bool)
    nomad_enabled  = optional(bool)
  }))
}

variable "hashi_datacenter" {
  type = string

  default = "dc1"
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

variable "CF_API_TOKEN" {
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

variable "validity_period_hours" {
  type        = number
  description = "Certificate valid lifetime in hours/"
  default     = 87600
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

variable "DIGITALOCEAN_API_TOKEN" {
  type = string
}

variable "SSH_PASSWORD" {
  type = string
}

# variable "ANSIBLE_VAULT_PASSWORD_FILE" {
#   type = string
# }

# variable "ANSIBLE_VAULT_PWD" {
#   type = string
# }

variable "ANSIBLE_VERSION" {
  type = string

  default = "4.8.0"
}

variable "NOMAD_VERSION" {
  type = string

  default = "1.1.2"
}

variable "CONSUL_VERSION" {
  type = string

  default = "1.10.1"
}

## DigitalOcean variables
variable "droplet_specs" {
  type = map(object({
    image    = optional(string)
    region   = optional(string)
    size     = optional(string)
    dns_zone = string
  }))

  description = "Map of Droplet specifications."
}

variable "nc_project" {
  type = map(string)
}

# variable "bastion_node" {
#   type = object({
#     prefix = optional(string)
#     spec   = optional(string)
#   })

#   description = "Basic details about a Bastion node"
# }

variable "nc_node" {
  type = object({
    prefix = optional(string)
    spec   = optional(string)
  })

  description = "Basic details about a Nomad/Consul node"
}

# variable "bastion_fw_inbound" {
#   type = list(object({
#     protocol         = string
#     port_range       = optional(string)
#     source_addresses = list(string)
#   }))

#   description = "List of firewall rules to be applied inbound on the Nomad/Consul cluster"
# }
# variable "bastion_fw_outbound" {
#   type = list(object({
#     protocol              = string
#     port_range            = optional(string)
#     destination_addresses = list(string)
#   }))

#   description = "List of firewall rules to be applied outbound on the Nomad/Consul cluster"
# }
variable "nc_fw_rules_inbound" {
  type = list(object({
    protocol         = string
    port_range       = optional(string)
    source_addresses = list(string)
  }))

  description = "List of firewall rules to be applied inbound on the Nomad/Consul cluster"
}
variable "nc_fw_rules_outbound" {
  type = list(object({
    protocol              = string
    port_range            = optional(string)
    destination_addresses = list(string)
  }))

  description = "List of firewall rules to be applied outbound on the Nomad/Consul cluster"
}
variable "node_count" {
  type = number

  description = "Number of nodes in the Nomad/Consul cluster. Default: 3"
  default     = 3
}
