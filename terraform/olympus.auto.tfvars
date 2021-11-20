access_apps = [
  {
    name    = "hades-ssh"
    service = "ssh://localhost:22"
  },
  {
    name    = "charon-ssh"
    service = "ssh://192.168.253.1:22"
  },
  {
    name    = "janus-01-ssh"
    service = "ssh://janus-01.nwlnexus.net:22"
  },
  {
    name    = "janus-02-ssh"
    service = "ssh://janus-02.nwlnexus.net:22"
  },
  {
    name    = "rpi-01-ssh"
    service = "ssh://rpi-01.nwlnexus.net:22"
  },
  {
    name    = "rpi-02-ssh"
    service = "ssh://rpi-02.nwlnexus.net:22"
  },
  {
    name    = "rpi-03-ssh"
    service = "ssh://rpi-03.nwlnexus.net:22"
  },
  {
    name    = "rpi-04-ssh"
    service = "ssh://rpi-04.nwlnexus.net:22"
  },
  {
    name    = "rpi-05-ssh"
    service = "ssh://rpi-05.nwlnexus.net:22"
  },
  {
    name    = "rpi-06-ssh"
    service = "ssh://rpi-06.nwlnexus.net:22"
  },
  {
    name    = "qnap-ssh"
    service = "ssh://qnap.nwlnexus.net:22"
  },
  {
    name    = "qnap-ui"
    service = "https://qnap.nwlnexus.net:8443"
  },
  {
    name    = "charon-ui"
    service = "https://mgmt.nwlnexus.net:8443"
  }
]

hashi_hosts = {
  "rpi-01" = {
    consul_enabled = true
    domain         = "nwlnexus.net"
    nomad_enabled  = true
    vault_enabled  = true
  },
  "rpi-02" = {
    consul_enabled = true
    domain         = "nwlnexus.net"
    nomad_enabled  = true
    vault_enabled  = true
  },
  "rpi-03" = {
    consul_enabled = true
    domain         = "nwlnexus.net"
    nomad_enabled  = true
    vault_enabled  = true
  }
}

organization_name = "NWLNEXS LLC"
