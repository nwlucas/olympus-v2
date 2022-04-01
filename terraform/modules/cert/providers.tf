terraform {
  experiments = [module_variable_optional_attrs]
}

terraform {
  required_version = ">= 0.15"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # version = "~> 3.65"
    }
    local = {
      source = "hashicorp/local"
      # version = "~> 2.1"
    }
    tls = {
      source = "hashicorp/tls"
      # version = "3.1.0"
    }
  }
}
