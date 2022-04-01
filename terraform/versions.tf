terraform {
  required_version = ">= 0.15"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 3"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.8"
    }
    acme = {
      source  = "vancluever/acme"
      version = "2.8"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.2"
    }
    dns = {
      source  = "hashicorp/dns"
      version = "3.2"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "3.1"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.2.0"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2"
    }
  }
}
