node_name               = "${ node_name }"
disable_update_check    = true
verify_server_hostname  = true
verify_incoming         = true
verify_outgoing         = true
enable_syslog           = true
server                  = true
leave_on_terminate      = true

log_level     = "${ log_level }"
datacenter    = "${ datacenter }"
data_dir      = "${ consul_path }/data"
domain        = "consul."
recursors     = ["1.1.1.1","8.8.8.8"]
retry_join    = ["provider=digitalocean region=${ region } tag_name=${ tag_name } api_token=${ do_api_token }"]

encrypt  = "${ encrypt_token }"
ca_file   = "/opt/hashi/hashi_ca.pem"
cert_file = "/opt/hashi/consul_${ instance_fqdn }.pem"
key_file  = "/opt/hashi/consul_${ instance_fqdn }.key"

auto_encrypt {
  allow_tls = true
}

ui_config {
  enabled = true
}

bind_addr           = "{{ GetInterfaceIP \"eth1\" }}"
advertise_addr      = "{{ GetInterfaceIP \"eth1\" }}"
advertise_addr_wan  = "{{ GetPublicIP }}"

addresses {
  grpc  = "127.0.0.1 {{ GetInterfaceIP \"eth1\" }}"
  http  = "127.0.0.1"
  https = "127.0.0.1 {{ GetInterfaceIP \"eth1\" }}"
  dns   = "127.0.0.1 {{ GetInterfaceIP \"eth1\" }}"
}
{% endif %}

ports {
  grpc  = 8502
  http  = 8500
  https = 8501
  dns   = 8600
  server   = 8300
  serf_lan = 8301
  serf_wan = 8302
}

connect {
  enabled = true
  ca_provider = "consul"
  ca_config {
    private_key = "/opt/hashi/hashi_int_key.pem"
    root_cert = "/opt/hashi/hashi_int_cert.pem"
  }
}
