variables {
  uid = "1002"
  gid = "1000"
  umask = "002"
  tz = "America/New_York"
}


job "htpc" {
  datacenters = ["olympus"]
  type = "service"

  constraint {
    attribute = "${attr.cpu.arch}"
    value = "amd64"
  }

  group "collectors" {
    volume "data" {
      type              = "csi"
      source            = "qnap-data"
      read_only         = false
      attachment_mode   = "file-system"
      access_mode       = "multi-node-multi-writer"

      mount_options {
        fs_type      = "ext4"
        mount_flags   = ["noatime", "nfsvers=4", "nolock"]
      }
    }

    volume "config-radarr" {
      type              = "csi"
      source            = "qnap-config-radarr"
      read_only         = false
      attachment_mode   = "file-system"
      access_mode       = "multi-node-multi-writer"

      mount_options {
        fs_type      = "ext4"
        mount_flags   = ["noatime", "nfsvers=4", "nolock"]
      }
    }

    volume "config-lidarr" {
      type              = "csi"
      source            = "qnap-config-lidarr"
      read_only         = false
      attachment_mode   = "file-system"
      access_mode       = "multi-node-multi-writer"

      mount_options {
        fs_type      = "ext4"
        mount_flags   = ["noatime", "nfsvers=4", "nolock"]
      }
    }

    volume "config-sonarr" {
      type              = "csi"
      source            = "qnap-config-sonarr"
      read_only         = false
      attachment_mode   = "file-system"
      access_mode       = "multi-node-multi-writer"

      mount_options {
        fs_type      = "ext4"
        mount_flags   = ["noatime", "nfsvers=4", "nolock"]
      }
    }

    network {
      mode = "bridge"
      port "radarr" { static = "7878" }
      port "sonarr" { static = "8989" }
      port "lidarr" { static = "8686" }

      dns {
        servers = ["127.0.0.1"]
      }
    }

    restart {
      attempts  = 3
      delay     = "30s"
      interval  = "5m"
      mode      = "fail"
    }

    update {
      max_parallel      = 1
      health_check      = "checks"
      min_healthy_time  = "10s"
      healthy_deadline  = "5m"
      auto_revert       = true
      canary            = 0
      stagger           = "30s"
    }

    task "radarr-container" {
      driver = "docker"
      config {
        image         = "quay.io/hotio/radarr"
        ports         = ["radarr"]
      }

      volume_mount {
        volume = "data"
        destination = "/data"
      }

      volume_mount {
        volume = "config-radarr"
        destination = "/config"
      }

      env{
        PUID  = var.uid
        PGID  = var.gid
        TZ    = var.tz
      }

      service {
        name          = "radarr"
        tags          = ["radarr"]
        port          = "radarr"

        meta {
          meta = "radarr"
        }

        check {
          type          = "http"
          path          = "/"
          port          = "radarr"
          interval      = "5s"
          timeout       = "10s"
        }
      }

      resources {
        cpu         = 500
        memory      = 256
      }

      logs {
        max_files     = 3
        max_file_size = 10
      }
    }
    task "sonarr-container" {
      driver = "docker"
      config {
        image         = "quay.io/linuxserver.io/sonarr"
        ports         = ["sonarr"]
      }

      volume_mount {
        volume = "data"
        destination = "/data"
      }

      volume_mount {
        volume = "config-sonarr"
        destination = "/config"
      }

      env{
        PUID  = var.uid
        PGID  = var.gid
        TZ    = var.tz
      }

      service {
        name = "sonarr"
        tags = ["sonarr"]
        port = "sonarr"

        meta {
          meta = "sonarr"
        }

        check {
          type      = "http"
          path      = "/"
          port      = "sonarr"
          interval  = "5s"
          timeout   = "10s"
        }
      }

      resources {
        cpu         = 500
        memory      = 256
      }

      logs {
        max_files     = 3
        max_file_size = 10
      }
    }
    task "lidarr-container" {
      driver = "docker"
      config {
        image         = "quay.io/linuxserver.io/lidarr"
        ports         = ["lidarr"]
      }

      volume_mount {
        volume = "data"
        destination = "/data"
      }

      volume_mount {
        volume = "config-lidarr"
        destination = "/config"
      }

      env{
        PUID  = var.uid
        PGID  = var.gid
        TZ    = var.tz
      }

      service {
        name = "lidarr"
        tags = ["lidarr"]
        port = "lidarr"

        meta {
          meta = "lidarr"
        }

        check {
          type      = "http"
          path      = "/"
          port      = "lidarr"
          interval  = "5s"
          timeout   = "10s"
        }
      }

      resources {
        cpu         = 500
        memory      = 256
      }

      logs {
        max_files     = 3
        max_file_size = 10
      }
    }
  }

  group "indexers" {
    volume "data-torrents" {
      type              = "csi"
      source            = "qnap-data-torrents"
      read_only         = false
      attachment_mode   = "file-system"
      access_mode       = "multi-node-multi-writer"

      mount_options {
        fs_type      = "ext4"
        mount_flags   = ["noatime", "nfsvers=4", "nolock"]
      }
    }

    volume "data-usenet" {
      type              = "csi"
      source            = "qnap-data-usenet"
      read_only         = false
      attachment_mode   = "file-system"
      access_mode       = "multi-node-multi-writer"

      mount_options {
        fs_type      = "ext4"
        mount_flags   = ["noatime", "nfsvers=4", "nolock"]
      }
    }

    volume "config-jackett" {
      type              = "csi"
      source            = "qnap-config-jackett"
      read_only         = false
      attachment_mode   = "file-system"
      access_mode       = "multi-node-multi-writer"

      mount_options {
        fs_type      = "ext4"
        mount_flags   = ["noatime", "nfsvers=4", "nolock"]
      }
    }

    volume "config-hydra" {
      type              = "csi"
      source            = "qnap-config-nzbhydra2"
      read_only         = false
      attachment_mode   = "file-system"
      access_mode       = "multi-node-multi-writer"

      mount_options {
        fs_type      = "ext4"
        mount_flags   = ["noatime", "nfsvers=4", "nolock"]
      }
    }

    network {
      mode = "bridge"
      port "jackett" { static = "9117" }
      port "hydra" { static = "5076" }
    }

    restart {
      attempts  = 3
      delay     = "30s"
      interval  = "5m"
      mode      = "fail"
    }

    update {
      max_parallel      = 1
      health_check      = "checks"
      min_healthy_time  = "10s"
      healthy_deadline  = "5m"
      auto_revert       = true
      canary            = 0
      stagger           = "30s"
    }

    task "jackett-container" {
      driver = "docker"
      config {
        image         = "quay.io/linuxserver.io/jackett"
        ports         = ["jackett"]

        labels = {
          "nomad"         = "job"
          "htpc"          = "true"
          "media-server"  = "jackett"
        }
      }

      volume_mount {
        volume = "data-torrents"
        destination = "/downloads"
      }

      volume_mount {
        volume = "config-jackett"
        destination = "/config"
      }

      env{
        PUID  = var.uid
        PGID  = var.gid
        TZ    = var.tz
      }

      service {
        name          = "jackett"
        tags          = ["jackett"]
        port          = "jackett"
        address_mode  = "host"

        meta {
          meta = "jackett"
        }

        check {
          type      = "tcp"
          port      = "jackett"
          path      = "/"
          interval  = "5s"
          timeout   = "10s"
        }
      }

      resources {
        cpu         = 1000
        memory      = 1000
      }

      logs {
        max_files     = 3
        max_file_size = 10
      }
    }

    task "hydra-container" {
      driver = "docker"
      config {
        image         = "quay.io/linuxserver.io/nzbhydra2"
        ports         = ["hydra"]

        labels = {
          "nomad"         = "job"
          "htpc"          = "true"
          "media-server"  = "hydra"
        }
      }

      volume_mount {
        volume = "data-usenet"
        destination = "/downloads"
      }

      volume_mount {
        volume = "config-hydra"
        destination = "/config"
      }

      env{
        PUID  = var.uid
        PGID  = var.gid
        TZ    = var.tz
      }

      service {
        name = "hydra"
        tags = ["hydra"]
        port = "hydra"
        address_mode = "host"

        meta {
          meta = "hydra"
        }

        check {
          type      = "http"
          port      = "hydra"
          path      = "/"
          interval  = "5s"
          timeout   = "10s"
        }
      }

      resources {
        cpu         = 1000
        memory      = 1000
      }

      logs {
        max_files     = 3
        max_file_size = 10
      }
    }
  }

  group "downloaders" {
    volume "data-torrents" {
      type              = "csi"
      source            = "qnap-data-torrents"
      read_only         = false
      attachment_mode   = "file-system"
      access_mode       = "multi-node-multi-writer"

      mount_options {
        fs_type      = "ext4"
        mount_flags   = ["noatime", "nfsvers=4", "nolock"]
      }
    }

    volume "data-usenet" {
      type              = "csi"
      source            = "qnap-data-usenet"
      read_only         = false
      attachment_mode   = "file-system"
      access_mode       = "multi-node-multi-writer"

      mount_options {
        fs_type      = "ext4"
        mount_flags   = ["noatime", "nfsvers=4", "nolock"]
      }
    }

    volume "config-qflood" {
      type              = "csi"
      source            = "qnap-config-qbitorrent"
      read_only         = false
      attachment_mode   = "file-system"
      access_mode       = "multi-node-multi-writer"

      mount_options {
        fs_type      = "ext4"
        mount_flags   = ["noatime", "nfsvers=4", "nolock"]
      }
    }

    volume "config-sabnzbd" {
      type              = "csi"
      source            = "qnap-config-sabnzbd"
      read_only         = false
      attachment_mode   = "file-system"
      access_mode       = "multi-node-multi-writer"

      mount_options {
        fs_type      = "ext4"
        mount_flags   = ["noatime", "nfsvers=4", "nolock"]
      }
    }

    volume "config-nzbget" {
      type              = "csi"
      source            = "qnap-config-nzbget"
      read_only         = false
      attachment_mode   = "file-system"
      access_mode       = "multi-node-multi-writer"

      mount_options {
        fs_type      = "ext4"
        mount_flags   = ["noatime", "nfsvers=4", "nolock"]
      }
    }

    network {
      mode = "bridge"
      port "sabnzbd" { static = "8080" }
      port "qflood-ui" { static = "8100" }
      port "qflood-udp" { static = "3000" }
    }

    restart {
      attempts  = 3
      delay     = "30s"
      interval  = "5m"
      mode      = "fail"
    }

    update {
      max_parallel      = 1
      health_check      = "checks"
      min_healthy_time  = "10s"
      healthy_deadline  = "5m"
      auto_revert       = true
      canary            = 0
      stagger           = "30s"
    }

    task "sabnzbd-container" {
      driver = "docker"
      config {
        image         = "quay.io/linuxserver.io/sabnzbd"
        ports         = ["sabnzbd"]

        labels = {
          "nomad"         = "job"
          "htpc"          = "true"
        }
      }

      volume_mount {
        volume = "data-torrents"
        destination = "/downloads"
      }

      volume_mount {
        volume = "config-sabnzbd"
        destination = "/config"
      }

      env{
        PUID  = var.uid
        PGID  = var.gid
        TZ    = var.tz
      }

      service {
        name          = "sabnzbd"
        tags          = ["sabnzbd"]
        port          = "sabnzbd"
        address_mode  = "host"

        meta {
          meta = "sabnzbd"
        }

        check {
          type      = "tcp"
          port      = "sabnzbd"
          path      = "/"
          interval  = "5s"
          timeout   = "10s"
        }
      }

      resources {
        cpu         = 1000
        memory      = 1000
      }

      logs {
        max_files     = 3
        max_file_size = 10
      }
    }

    task "qflood-container" {
      driver = "docker"
      config {
        image         = "quay.io/hotio/qflood"
        ports         = ["qflood-ui", "qflood-udp"]

        labels = {
          "nomad"         = "job"
          "htpc"          = "true"
        }
      }

      volume_mount {
        volume = "data-torrents"
        destination = "/downloads"
      }

      volume_mount {
        volume = "config-qflood"
        destination = "/config"
      }

      env{
        PUID        = var.uid
        PGID        = var.gid
        UMASK       = var.umask
        TZ          = var.tz
        WEBUI_PORTS = "8100/tcp,3000/udp"
        FLOOD_AUTH  ="false"
      }

      service {
        name = "qflood"
        tags = ["qflood"]
        port = "qflood-ui"
        address_mode = "host"

        meta {
          meta = "qflood"
        }

        check {
          type      = "http"
          port      = "qflood-ui"
          path      = "/"
          interval  = "5s"
          timeout   = "10s"
        }
      }

      resources {
        cpu         = 1000
        memory      = 1000
      }

      logs {
        max_files     = 3
        max_file_size = 10
      }
    }
  }

  group "players" {
    volume "data-media" {
      type              = "csi"
      source            = "qnap-data-media"
      read_only         = false
      attachment_mode   = "file-system"
      access_mode       = "multi-node-multi-writer"

      mount_options {
        fs_type      = "ext4"
        mount_flags   = ["noatime", "nfsvers=4", "nolock"]
      }
    }

    volume "config-stash" {
      type              = "csi"
      source            = "qnap-config-stash"
      read_only         = false
      attachment_mode   = "file-system"
      access_mode       = "multi-node-multi-writer"

      mount_options {
        fs_type      = "ext4"
        mount_flags   = ["noatime", "nfsvers=4", "nolock"]
      }
    }

    network {
      mode = "bridge"
      port "stash" { static = "9999" }
    }

    restart {
      attempts  = 3
      delay     = "30s"
      interval  = "5m"
      mode      = "fail"
    }

    update {
      max_parallel      = 1
      health_check      = "checks"
      min_healthy_time  = "10s"
      healthy_deadline  = "5m"
      auto_revert       = true
      canary            = 0
      stagger           = "30s"
    }

    task "stash-container" {
      driver = "docker"
      config {
        image         = "quay.io/hotio/stash"
        ports         = ["stash"]

        labels = {
          "nomad"         = "job"
          "htpc"          = "true"
        }
      }

      volume_mount {
        volume = "data-media"
        destination = "/media"
      }

      volume_mount {
        volume = "config-stash"
        destination = "/config"
      }

      env{
        PUID  = var.uid
        PGID  = var.gid
        UMASK = var.umask
        TZ    = var.tz
      }

      service {
        name          = "stash"
        tags          = ["stash"]
        port          = "stash"
        address_mode  = "host"

        meta {
          meta = "stash"
        }

        check {
          type      = "tcp"
          port      = "stash"
          path      = "/"
          interval  = "5s"
          timeout   = "10s"
        }
      }

      resources {
        cpu         = 1000
        memory      = 1000
      }

      logs {
        max_files     = 3
        max_file_size = 10
      }
    }
  }
}
