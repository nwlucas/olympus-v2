job "indexer" {
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

  group "htpc-collectors" {
    count = 3

    network {
      port "radarr" { to = "7878" }
      port "sonarr" { to = "8989" }
      port "lidarr" { to = "8686" }
    }

    restart {
      attempts  = 3
      delay     = "30s"
      interval  = "5m"
      mode      = "fail"
    }

    update {
      max_parallel      = 3
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
        image         = "docker://linuxserver/radarr:latest"
        network_mode  = "bridge"
        ports         = ["radarr"]
        labels = {
          "nomad"         = "job"
          "htpc"          = "true"
          "media-server"  = "radarr"
        }
      }

      service {
        name = "radarr"
        tags = ["radarr"]
        port = "radarr"

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
        memory      = 500
      }

      logs {
        max_files     = 3
        max_file_size = 10
      }
    }
    task "sonarr-container" {
      driver = "podman"
      config {
        image         = "docker://linuxserver/sonarr:latest"
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
        cpu         = 500
        memory      = 500
      }

      logs {
        max_files     = 3
        max_file_size = 10
      }
    }
    task "lidarr-container" {
      driver = "podman"
      config {
        image         = "docker://linuxserver/lidarr:latest"
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
        cpu         = 500
        memory      = 500
      }

      logs {
        max_files     = 3
        max_file_size = 10
      }
    }
  }
}
