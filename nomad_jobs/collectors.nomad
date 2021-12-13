job "htpc-collectors" {
  datacenters = ["olympus"]
  type = "service"

  constraint {
    attribute = "${node.class}"
    value     = "rpi"
  }

  constraint {
    operator = "distinct_hosts"
    value = true
  }

  group "collector-radarr" {
    network {
      // mode = "bridge"
      port "radarr" { static = "7878" }
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
      driver = "podman"
      config {
        image         = "quay.io/linuxserver.io/radarr"
        network_mode  = "bridge"
        ports         = ["radarr"]
        labels = {
          "nomad"         = "job"
          "htpc"          = "true"
          "media-server"  = "radarr"
        }
      }

      service {
        name          = "radarr"
        tags          = ["radarr"]
        port          = "radarr"
        address_mode  = "host"

        meta {
          meta = "radarr"
        }

        check {
          type      = "http"
          port      = "radarr"
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

  group "collector-sonarr" {
    network {
      // mode = "bridge"
      port "sonarr" { static = "8989" }
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

    task "sonarr-container" {
      driver = "podman"
      config {
        image         = "quay.io/linuxserver.io/sonarr"
        network_mode  = "bridge"
        ports         = ["sonarr"]
        labels = {
          "nomad"         = "job"
          "htpc"          = "true"
          "media-server"  = "sonarr"
        }
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
          port      = "sonarr"
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

  group "collector-lidarr" {
    network {
      // mode = "bridge"
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

    task "lidarr-container" {
      driver = "podman"
      config {
        image         = "quay.io/linuxserver.io/lidarr"
        network_mode  = "bridge"
        ports         = ["lidarr"]
        labels = {
          "nomad"         = "job"
          "htpc"          = "true"
          "media-server"  = "lidarr"
        }
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
          port      = "lidarr"
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
