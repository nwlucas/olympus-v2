variable "do_image" {
  type    = string
  default = "ubuntu-20-04-x64"
}

variable "do_region" {
  type        = string
  description = "The region for droplet creation."
  default     = "nyc3"
}

variable "nomad_version" {
  type        = string
  description = "Version of Nomad to install."
}

variable "consul_version" {
  type        = string
  description = "Version of Consul Agent to install."
}

variable "vault_version" {
  type        = string
  description = "Version of Consul Agent to install."
}

variable "ansible_version" {
  type        = string
  description = "Version of Ansible to install."
}

variable "unifi_version" {
  type        = string
  description = "Version of UnifiOS to install."
}

variable "ssh_password" {
  type        = string
  description = "The password to login to the guest operating system."
  default     = ""
  sensitive   = true
}


source "digitalocean" "base-ubuntu-amd64" {

  region = var.do_region
  image  = var.do_image

  communicator = "ssh"
  ssh_timeout  = "10000s"
  ssh_username = "root"
  ssh_pty      = true
}

locals {
  builds = {
    nomad_consul = {
      build_type = "nomad-consul"
      tags       = ["template", "nomad", "consul"]
      size       = "s-2vcpu-4gb"
    }
    unifi = {
      build_type = "unifi-controller"
      tags       = ["template", "unifios", "unifi"]
      size       = "s-1vcpu-2gb"
    }
    vault = {
      build_type = "vault"
      tags       = ["template", "vault"]
      size       = "s-1vcpu-2gb"
    }
  }
}

build {
  dynamic "source" {
    for_each = local.builds

    labels = ["source.digitalocean.base-ubuntu-amd64"]
    content {
      name          = source.key
      size          = source.value.size
      droplet_name  = "base-${source.value.build_type}"
      snapshot_name = "base-${source.value.build_type}"
      user_data = templatefile("${path.root}/../../../templates/user-data.pkrtpl", merge(source.value, {
        ssh_password = var.ssh_password
        ssh_pub_key  = file("${path.root}/../../../ssh_keys/ssh_instance.pub")
      }))
      tags = source.value.tags
    }
  }

  provisioner "shell" {
    expect_disconnect   = true
    start_retry_timeout = "3m"
    scripts = [
      "${path.root}/../../../scripts/ubuntu/update.sh",
    ]
  }

  provisioner "shell" {
    environment_vars = [
      "ANSIBLE_VERSION=${var.ansible_version}",
      "BUILD_TYPE=${upper(source.name)}"
    ]
    expect_disconnect   = true
    pause_before        = "3m"
    start_retry_timeout = "3m"
    scripts = [
      "${path.root}/../../../scripts/common/motd.sh",
      "${path.root}/../../../scripts/common/sshd.sh",
      "${path.root}/../../../scripts/ubuntu/sudoers.sh",
      "${path.root}/../../../scripts/ubuntu/packages.sh",
      "${path.root}/../../../scripts/setup-ansible.sh",
    ]
  }

  provisioner "shell" {
    only = ["digitalocean.nomad_consul"]
    environment_vars = [
      "CONSUL_VERSION=${var.consul_version}",
      "NOMAD_VERSION=${var.nomad_version}"
    ]
    expect_disconnect   = true
    start_retry_timeout = "3m"
    scripts = [
      "${path.root}/../../../scripts/install-nomad.sh",
      "${path.root}/../../../scripts/install-consul.sh",
    ]
  }


  provisioner "shell" {
    only = ["digitalocean.vault"]
    environment_vars = [
      "VAULT_VERSION=${var.vault_version}",
    ]
    expect_disconnect   = true
    start_retry_timeout = "3m"
    scripts = [
      "${path.root}/../../../scripts/install-vault.sh",
    ]
  }

  provisioner "shell" {
    only = ["digitalocean.unifi"]
    environment_vars = [
      "UNIFI_VERSION=${var.unifi_version}",
    ]
    expect_disconnect   = true
    start_retry_timeout = "3m"
    scripts = [
      "${path.root}/../../../scripts/install-unifi.sh",
    ]
  }

  provisioner "shell" {
    expect_disconnect = true
    scripts = [
      "${path.root}/../../../scripts/common/minimize.sh",
      "${path.root}/../../../scripts/ubuntu/cleanup.sh",
    ]
  }
}
