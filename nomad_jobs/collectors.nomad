job "htpc-collectors" {
  datacenters = ["olympus"]
  type = "service"

  constraint {
    attribute = "${node.class}"
    value     = "host"
  }

  group "collector-radarr" {
    network {
      mode = "bridge"
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
      driver = "docker"
      config {
        image         = "quay.io/linuxserver.io/radarr"
      }

      env{
        UID = "998"
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
  }

  group "collector-sonarr" {
    network {
      mode = "bridge"
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
      driver = "docker"
      config {
        image         = "quay.io/linuxserver.io/sonarr"
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
  }

  group "collector-lidarr" {
    network {
      mode = "bridge"
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
      driver = "docker"
      config {
        image         = "quay.io/linuxserver.io/lidarr"
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
}
