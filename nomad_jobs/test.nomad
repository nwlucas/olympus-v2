job "http-echo" {
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

  group "http-echo" {
    count = 3

    network {
      port "http-echo" { static = "5678" }
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

    task "server" {
      driver = "podman"
      config {
        image = "docker://hashicorp/http-echo:latest"
        args = [
          "-listen",
          ":5678",
          "-text",
          "Hello and welcome to."
        ]
        ports = ["http-echo"]
      }

      service {
        tags = ["http-echo"]
        port = "http-echo"

        meta {
          meta = "http-echo"
        }

        check {
          type      = "http"
          port      = "http-echo"
          path      = "/health"
          interval  = "5s"
          timeout   = "10s"
        }
      }

      resources {
        cpu         = 300
        memory      = 100
      }

      logs {
        max_files     = 3
        max_file_size = 10
      }
    }
  }
}
