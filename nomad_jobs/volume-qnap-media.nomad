type        = "csi"

id          = "qnap-media"
name        = "qnap-media"
external_id = "qnap-media"
plugin_id   = "nfs-qnap"

capability {
  access_mode     = "multi-node-multi-writer"
  attachment_mode = "file-system"
}

capability {
  access_mode     = "multi-node-single-writer"
  attachment_mode = "file-system"
}

mount_options {
  fs_type = "ext4"
}

context {
  server  = "192.168.251.7"
  share   = "/MEDIA/MEDIA"
}

