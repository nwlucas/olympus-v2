terraform {
  required_version = ">= 0.15"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 3.4.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.65"
    }
    acme = {
      source  = "vancluever/acme"
      version = "2.7.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.1"
    }
    dns = {
      source  = "hashicorp/dns"
      version = "3.2.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "3.1.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.2.0"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.16.0"
    }
  }
}
