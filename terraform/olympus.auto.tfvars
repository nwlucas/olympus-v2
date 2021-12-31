droplet_specs = {
  "generic" = {
    size     = "s-1vcpu-1gb"
    dns_zone = "nwlnexus.net"
    region   = "nyc3"
  },

  "controller" = {
    size     = "s-1vcpu-2gb"
    dns_zone = "nwlnexus.net"
    region   = "nyc3"
  }
}

access_groups = {
  "olympus_group" = {
    email_includes = ["nigel.williamslucas@gmail.com", "nigel.williamslucas@pm.me"]
  }
}

lb_apps = [
  {
    app_name    = "hades-ssh"
    backend     = "localhost"
    admin_group = "olympus_group"
    proto       = "ssh"
    port        = "22"
  },
  {
    app_name    = "charon-ssh"
    backend     = "192.168.253.1"
    admin_group = "olympus_group"
    proto       = "ssh"
    port        = "22"
  },
  {
    app_name    = "janus-01-ssh"
    backend     = "janus-01.nwlnexus.net"
    admin_group = "olympus_group"
    proto       = "ssh"
    port        = "22"
  },
  {
    app_name    = "janus-02-ssh"
    backend     = "janus-02.nwlnexus.net"
    admin_group = "olympus_group"
    proto       = "ssh"
    port        = "22"
  },
  {
    app_name    = "rpi-01-ssh"
    backend     = "rpi-01.nwlnexus.net"
    admin_group = "olympus_group"
    proto       = "ssh"
    port        = "22"
  },
  {
    app_name    = "rpi-02-ssh"
    backend     = "rpi-02.nwlnexus.net"
    admin_group = "olympus_group"
    proto       = "ssh"
    port        = "22"
  },
  {
    app_name    = "rpi-03-ssh"
    backend     = "rpi-03.nwlnexus.net"
    admin_group = "olympus_group"
    proto       = "ssh"
    port        = "22"
  },
  {
    app_name    = "rpi-04-ssh"
    backend     = "rpi-04.nwlnexus.net"
    admin_group = "olympus_group"
    proto       = "ssh"
    port        = "22"
  },
  {
    app_name    = "rpi-05-ssh"
    backend     = "rpi-05.nwlnexus.net"
    admin_group = "olympus_group"
    proto       = "ssh"
    port        = "22"
  },
  {
    app_name    = "rpi-06-ssh"
    backend     = "rpi-06.nwlnexus.net"
    admin_group = "olympus_group"
    proto       = "ssh"
    port        = "22"
  },
  {
    app_name    = "qnap-ssh"
    backend     = "qnap.nwlnexus.net"
    admin_group = "olympus_group"
    proto       = "ssh"
    port        = "22"
  },
  {
    app_name    = "qnap-ui"
    backend     = "qnap.nwlnexus.net"
    admin_group = "olympus_group"
    proto       = "https"
    port        = "8443"
  },
  {
    app_name    = "charon-ui"
    backend     = "mgmt.nwlnexus.net"
    admin_group = "olympus_group"
    proto       = "https"
    port        = "8443"
  },
  {
    app_name       = "vault-ui"
    host_name      = "vault-ui"
    access_enabled = true
    backend        = "localhost"
    proto          = "https"
    port           = "8200"
    path           = "/ui"
    admin_group    = "olympus_group"
    public_cert    = true
  },
  {
    app_name       = "vault-tcp"
    host_name      = "vault"
    access_enabled = false
    backend        = "localhost"
    proto          = "tcp"
    port           = "8200"
    admin_group    = ""
    public_cert    = true
  }
]

lb_hosts = {
  "rpi-06" = {
    domain          = "nwlnexus.net"
    traefik_enabled = true
  }
}

hashi_hosts = {
  "rpi-01" = {
    domain     = "nwlnexus.net"
    datacenter = "olympus"
  },
  "rpi-02" = {
    domain     = "nwlnexus.net"
    datacenter = "olympus"
  },
  "rpi-03" = {
    domain     = "nwlnexus.net"
    datacenter = "olympus"
  },
  "rpi-04" = {
    domain     = "nwlnexus.net"
    datacenter = "olympus"
  },
  "rpi-05" = {
    domain     = "nwlnexus.net"
    datacenter = "olympus"
  }
}
hashi_datacenter = "olympus"

organization_name = "NWLNEXUS LLC"

nc_project = {
  "name"        = "homelab-nc-cluster"
  "description" = "Nomad Consul cluster project."
  "purpose"     = "Service or API"
  "environment" = "Production"
}

// bastion_node = {
//   "prefix" = "bst"
//   "spec"   = "generic"
// }

nc_node = {
  "prefix" = "nc"
  "spec"   = "generic"
}

nc_fw_rules_inbound = [
  {
    protocol         = "tcp"
    port_range       = "8600"
    source_addresses = ["0.0.0.0/0", "::/0"]
  },
  {
    protocol         = "udp"
    port_range       = "8600"
    source_addresses = ["0.0.0.0/0", "::/0"]
  },
  {
    protocol         = "tcp"
    port_range       = "8500"
    source_addresses = ["0.0.0.0/0", "::/0"]
  },
  {
    protocol         = "tcp"
    port_range       = "8501"
    source_addresses = ["0.0.0.0/0", "::/0"]
  },
  {
    protocol         = "tcp"
    port_range       = "8502"
    source_addresses = ["0.0.0.0/0", "::/0"]
  },
  {
    protocol         = "tcp"
    port_range       = "8300"
    source_addresses = ["0.0.0.0/0", "::/0"]
  },
  {
    protocol         = "tcp"
    port_range       = "8301"
    source_addresses = ["0.0.0.0/0", "::/0"]
  },
  {
    protocol         = "udp"
    port_range       = "8301"
    source_addresses = ["0.0.0.0/0", "::/0"]
  },
  {
    protocol         = "tcp"
    port_range       = "8302"
    source_addresses = ["0.0.0.0/0", "::/0"]
  },
  {
    protocol         = "udp"
    port_range       = "8302"
    source_addresses = ["0.0.0.0/0", "::/0"]
  },
]

nc_fw_rules_outbound = [
  {
    protocol              = "tcp"
    port_range            = "80"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  },
  {
    protocol              = "tcp"
    port_range            = "443"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  },
  {
    protocol              = "udp"
    port_range            = "53"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  },
  {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  },
]

// bastion_fw_inbound = [
//   {
//     protocol         = "tcp"
//     port_range       = "22"
//     source_addresses = ["0.0.0.0/0", "::/0"]
//   },
//   {
//     protocol         = "tcp"
//     port_range       = "9090"
//     source_addresses = ["0.0.0.0/0", "::/0"]
//   },
//   {
//     protocol         = "icmp"
//     source_addresses = ["0.0.0.0/0", "::/0"]
//   },
// ]

// bastion_fw_outbound = [
//   {
//     protocol              = "tcp"
//     port_range            = "80"
//     destination_addresses = ["0.0.0.0/0", "::/0"]
//   },
//   {
//     protocol              = "tcp"
//     port_range            = "443"
//     destination_addresses = ["0.0.0.0/0", "::/0"]
//   },
//   {
//     protocol              = "udp"
//     port_range            = "53"
//     destination_addresses = ["0.0.0.0/0", "::/0"]
//   },
//   {
//     protocol              = "icmp"
//     destination_addresses = ["0.0.0.0/0", "::/0"]
//   },
// ]
