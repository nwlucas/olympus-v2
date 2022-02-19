job "plugin-nfs-nodes" {
  datacenters = ["olympus"]
  type = "system"

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

        privileged = true
      }

      csi_plugin {
        id        = "nfs-syn"
        type      = "node"
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
