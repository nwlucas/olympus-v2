type        = "csi"

id          = "syn-media"
name        = "syn-media"
external_id = "syn-media"
plugin_id   = "nfs-syn"

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
  server  = "192.168.251.8"
  share   = "/volume1/MEDIA"
}

