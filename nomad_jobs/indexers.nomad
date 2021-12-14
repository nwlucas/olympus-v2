job "htpc-indexers" {
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

  group "indexer-jackett" {
    network {
      port "jackett" { static = "9117" }
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
      driver = "podman"
      config {
        image         = "quay.io/linuxserver.io/jackett"
        network_mode  = "bridge"
        ports         = ["jackett"]
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
          type      = "http"
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
  }
  group "indexer-hydra" {
    network {
      port "hydra2" { static = "5076" }
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

    task "hydra-container" {
      driver = "podman"
      config {
        image         = "quay.io/linuxserver.io/nzbhydra2"
        network_mode  = "bridge"
        ports         = ["hydra2"]
        labels = {
          "nomad"         = "job"
          "htpc"          = "true"
          "media-server"  = "hydra"
        }
      }

      service {
        name = "hydra"
        tags = ["hydra"]
        port = "hydra2"
        address_mode = "host"

        meta {
          meta = "hydra"
        }

        check {
          type      = "http"
          port      = "hydra2"
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
