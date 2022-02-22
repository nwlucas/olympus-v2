type        = "csi"

id          = "qnap-config-lidarr"
name        = "qnap-config-lidarr"
external_id = "qnap-config-lidarr"
plugin_id   = "nfs-qnap"

capability {
  access_mode     = "multi-node-multi-writer"
  attachment_mode = "file-system"
}

capability {
  access_mode     = "multi-node-single-writer"
  attachment_mode = "file-system"
}

context {
  server  = "192.168.251.7"
  share   = "/share/MEDIA/data/app_configs/lidarr"
}

