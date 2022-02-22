type        = "csi"

id          = "qnap-data-torrents"
name        = "qnap-data-torrents"
external_id = "qnap-data-torrents"
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
  share   = "/share/MEDIA/data/torrents"
}

