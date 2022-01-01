job "htpc-collectors" {
  datacenters = ["olympus"]
  type = "service"

  constraint {
    attribute = "${node.class}"
    value     = "host"
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
      driver = "containerd-driver"
      config {
        image         = "quay.io/linuxserver.io/radarr"
        ports         = ["radarr"]
      }

      env{
        UID = "998"
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
        cpu         = 500
        memory      = 256
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
      driver = "containerd-driver"
      config {
        image         = "quay.io/linuxserver.io/sonarr"
        ports         = ["sonarr"]
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
        cpu         = 500
        memory      = 256
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
      driver = "containerd-driver"
      config {
        image         = "quay.io/linuxserver.io/lidarr"
        ports         = ["lidarr"]
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
        cpu         = 500
        memory      = 256
      }

      logs {
        max_files     = 3
        max_file_size = 10
      }
    }
  }
}
