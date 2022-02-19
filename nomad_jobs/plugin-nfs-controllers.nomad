job "plugin-nfs-controllers" {
  datacenters = ["olympus"]

  constraint {
    attribute = "${node.class}"
    value     = "host"
  }

  group "synology" {
    network {
      mode = "bridge"
    }

    task "plugin" {
      driver = "docker"

      config {
        image         = "mcr.microsoft.com/k8s/csi/nfs-csi:latest"

        args = [
          "-v=5",
          "--nodeid=${attr.unique.hostname}",
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
        image         = "mcr.microsoft.com/k8s/csi/nfs-csi:latest"

        args = [
          "-v=5",
          "--nodeid=${attr.unique.hostname}",
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
