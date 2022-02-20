variables {
  uid = "1028"
  gid = "65536"
}


job "htpc" {
  datacenters = ["olympus"]
  type = "service"

  constraint {
    attribute = "${node.class}"
    value     = "host"
  }

  constraint {
    attribute = "${attr.cpu.arch}"
    value     = "amd64"
  }

  constraint {
    operator = "distinct_hosts"
    value = true
  }

  group "collectors" {
    volume "syn-media" {
      type              = "csi"
      source            = "syn-media"
      read_only         = false
      attachment_mode   = "file-system"
      access_mode       = "multi-node-multi-writer"

      mount_options {
        fs_type         = "ext4"
      }
    }

    network {
      mode = "bridge"
      port "radarr" { static = "7878" }
      port "sonarr" { static = "8989" }
      port "lidarr" { static = "8686" }
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
        image         = "quay.io/linuxserver.io/radarr"
      }

      volume_mount {
        volume = "syn-media"
        destination = "${NOMAD_ALLOC_DIR}/syn-media"
      }

      env{
        UID = var.uid
        GID = var.gid
        MOUNT_PATH = "${NOMAD_ALLOC_DIR}/syn-media"
      }

      service {
        name          = "radarr"
        tags          = ["radarr"]
        address_mode  = "auto"
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
      }

      volume_mount {
        volume = "syn-media"
        destination = "${NOMAD_ALLOC_DIR}/syn-media"
      }

      env{
        UID = var.uid
        GID = var.gid
        MOUNT_PATH = "${NOMAD_ALLOC_DIR}/syn-media"
      }

      service {
        name = "sonarr"
        tags = ["sonarr"]
        address_mode  = "auto"

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
      }

      volume_mount {
        volume = "syn-media"
        destination = "${NOMAD_ALLOC_DIR}/syn-media"
      }

      env{
        UID = var.uid
        GID = var.gid
        MOUNT_PATH = "${NOMAD_ALLOC_DIR}/syn-media"
      }

      service {
        name = "lidarr"
        tags = ["lidarr"]
        address_mode  = "auto"

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
        labels = {
          "nomad"         = "job"
          "htpc"          = "true"
          "media-server"  = "jackett"
        }
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
        labels = {
          "nomad"         = "job"
          "htpc"          = "true"
          "media-server"  = "hydra"
        }
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
}
