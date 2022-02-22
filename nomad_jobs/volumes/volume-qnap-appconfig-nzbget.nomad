type        = "csi"

id          = "qnap-config-nzbget"
name        = "qnap-config-nzbget"
external_id = "qnap-config-nzbget"
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
  share   = "/share/MEDIA/data/app_configs/nzbget"
}

