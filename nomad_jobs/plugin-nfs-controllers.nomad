job "plugin-nfs-controllers" {
  datacenters = ["olympus"]

  constraint {
    operator = "distinct_hosts"
    value = true
  }

  group "synology" {
    network {
      mode = "bridge"
    }

    task "plugin" {
      driver = "docker"

      config {
        image         = "mcr.microsoft.com/k8s/csi/nfs-csi:v3.2.0-linux-${attr.cpu.arch}"

        args = [
          "-v=5",
          "--nodeid=syn-${attr.unique.hostname}",
          "--endpoint=unix://csi/csi.sock"
        ]
      }

      csi_plugin {
        id        = "nfs-syn"
        type      = "controller"
        mount_dir = "/csi"
      }

      resources {
        cpu     = 500
        memory  = 256
      }
    }
  }
  group "qnap" {
    network {
      mode = "bridge"
    }

    task "plugin" {
      driver = "docker"

      config {
        image         = "mcr.microsoft.com/k8s/csi/nfs-csi:v3.2.0-linux-${attr.cpu.arch}"

        args = [
          "-v=5",
          "--nodeid=qnap-${attr.unique.hostname}",
          "--endpoint=unix://csi/csi.sock"
        ]
      }

      csi_plugin {
        id        = "nfs-qnap"
        type      = "controller"
        mount_dir = "/csi"
      }

      resources {
        cpu     = 500
        memory  = 256
      }
    }
  }
}
