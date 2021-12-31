job "plugin-nfs-provisioner" {
  datacenters = ["olympus"]
  type = "system"

  group "controller" {
    task "plugin" {
      driver = "podman"

      env {
        NFS_SERVER        = "192.168.251.8"
        NFS_PATH          = "/volume1/MEDIA"
        PROVISIONER_NAME  = "nfs-provisioner"
      }

      config {
        image         = "quay.io/external_storage/nfs-client-provisioner-arm"
        network_mode  = "bridge"

        args = [
          "-v=5"
        ]
      }

      csi_plugin {
        id        = "nfs-provisioner"
        type      = "monolith"
        mount_dir = "/csi"
      }

      resources {
        cpu     = 500
        memory  = 256
      }
    }
  }
}
