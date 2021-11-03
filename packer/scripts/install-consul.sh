#!/bin/bash -eux

CONSUL_VERSION=${CONSUL_VERSION:-1.10.1}

readonly DEFAULT_INSTALL_PATH="/opt/consul"
readonly DEFAULT_CONSUL_USER="consul"
readonly DOWNLOAD_PACKAGE_PATH="/tmp/consul.zip"

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SYSTEM_BIN_DIR="/usr/local/bin"

readonly SCRIPT_NAME="$(basename "$0")"

function print_usage {
  echo
  echo "Usage: install-consul [OPTIONS]"
  echo
  echo "This script can be used to install Consul and its dependencies. This script has been tested with Ubuntu 16.04/18.04/20.04 and Amazon Linux 2."
  echo
  echo "Options:"
  echo
  echo -e "  --version\t\tThe version of Consul to install. Optional if download-url is provided."
  echo -e "  --download-url\t\tUrl to exact Consul package to be installed. Optional if version is provided."
  echo -e "  --path\t\tThe path where Consul should be installed. Optional. Default: $DEFAULT_INSTALL_PATH."
  echo -e "  --user\t\tThe user who will own the Consul install directories. Optional. Default: $DEFAULT_CONSUL_USER."
  echo -e "  --ca-file-path\t\tPath to a PEM-encoded certificate authority used to encrypt and verify authenticity of client and server connections. Will be installed under <install-path>/tls/ca."
  echo -e "  --cert-file-path\t\tPath to a PEM-encoded certificate, which will be provided to clients or servers to verify the agent's authenticity. Will be installed under <install-path>/tls. Must be provided along with --key-file-path."
  echo -e "  --key-file-path\t\tPath to a PEM-encoded private key, used with the certificate to verify the agent's authenticity. Will be installed under <install-path>/tls. Must be provided along with --cert-file-path"
  echo
  echo "Example:"
  echo
  echo "  install-consul --version 1.2.2"
}

function log {
  local readonly level="$1"
  local readonly message="$2"
  local readonly timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo >&2 -e "${timestamp} [${level}] [$SCRIPT_NAME] ${message}"
}

function log_info {
  local readonly message="$1"
  log "INFO" "$message"
}

function log_warn {
  local readonly message="$1"
  log "WARN" "$message"
}

function log_error {
  local readonly message="$1"
  log "ERROR" "$message"
}

function assert_not_empty {
  local readonly arg_name="$1"
  local readonly arg_value="$2"

  if [[ -z "$arg_value" ]]; then
    log_error "The value for '$arg_name' cannot be empty"
    print_usage
    exit 1
  fi
}

function assert_either_or {
  local readonly arg1_name="$1"
  local readonly arg1_value="$2"
  local readonly arg2_name="$3"
  local readonly arg2_value="$4"

  if [[ -z "$arg1_value" && -z "$arg2_value" ]]; then
    log_error "Either the value for '$arg1_name' or '$arg2_name' must be passed, both cannot be empty"
    print_usage
    exit 1
  fi
}

# A retry function that attempts to run a command a number of times and returns the output
function retry {
  local readonly cmd="$1"
  local readonly description="$2"

  for i in $(seq 1 5); do
    log_info "$description"

    # The boolean operations with the exit status are there to temporarily circumvent the "set -e" at the
    # beginning of this script which exits the script immediatelly for error status while not losing the exit status code
    output=$(eval "$cmd") && exit_status=0 || exit_status=$?
    log_info "$output"
    if [[ $exit_status -eq 0 ]]; then
      echo "$output"
      return
    fi
    log_warn "$description failed. Will sleep for 10 seconds and try again."
    sleep 10
  done

  log_error "$description failed after 5 attempts."
  exit $exit_status
}

function has_yum {
  [ -n "$(command -v yum)" ]
}

function has_apt_get {
  [ -n "$(command -v apt-get)" ]
}

function install_dependencies {
  log_info "Installing dependencies"

  if has_apt_get; then
    sudo apt-get update -y
    sudo apt-get install -y awscli curl unzip jq
  elif has_yum; then
    sudo yum update -y
    sudo yum install -y aws curl unzip jq
  else
    log_error "Could not find apt-get or yum. Cannot install dependencies on this OS."
    exit 1
  fi
}

function user_exists {
  local readonly username="$1"
  id "$username" >/dev/null 2>&1
}

function create_consul_user {
  local readonly username="$1"

  if user_exists "$username"; then
    echo "User $username already exists. Will not create again."
  else
    log_info "Creating user named $username"
    sudo useradd "$username"
  fi
}

function create_consul_install_paths {
  local readonly path="$1"
  local readonly username="$2"

  log_info "Creating install dirs for Consul at $path"
  sudo mkdir -p "$path"
  sudo mkdir -p "$path/bin"
  sudo mkdir -p "$path/config"
  sudo mkdir -p "$path/data"
  sudo mkdir -p "$path/tls/ca"

  log_info "Changing ownership of $path to $username"
  sudo chown -R "$username:$username" "$path"
}

function fetch_binary {
  local readonly version="$1"
  local download_url="$2"

  local cpu_arch
  cpu_arch="$(uname -m)"
  local binary_arch=""
  case "$cpu_arch" in
  x86_64)
    binary_arch="amd64"
    ;;
  x86)
    binary_arch="386"
    ;;
  arm64 | aarch64)
    binary_arch="arm64"
    ;;
  arm*)
    # The following info is taken from https://www.consul.io/downloads
    #
    # Note for ARM users:
    #
    # Use Armelv5 for all 32-bit armel systems
    # Use Armhfv6 for all armhf systems with v6+ architecture
    # Use Arm64 for all v8 64-bit architectures
    # The following commands can help determine the right version for your system:
    #
    # $ uname -m
    # $ readelf -a /proc/self/exe | grep -q -c Tag_ABI_VFP_args && echo "armhf" || echo "armel"
    #
    local vfp_tag
    vfp_tag="$(readelf -a /proc/self/exe | grep -q -c Tag_ABI_VFP_args)"
    if [[ -z $vfp_tag ]]; then
      binary_arch="armelv5"
    else
      binary_arch="armhfv6"
    fi
    ;;
  *)
    log_error "CPU architecture $cpu_arch is not a supported by Consul."
    exit 1
    ;;
  esac

  if [[ -z "$download_url" && -n "$version" ]]; then
    download_url="https://releases.hashicorp.com/consul/${version}/consul_${version}_linux_${binary_arch}.zip"
  fi

  retry \
    "curl -o '$DOWNLOAD_PACKAGE_PATH' '$download_url' --location --silent --fail --show-error" \
    "Downloading Consul to $DOWNLOAD_PACKAGE_PATH"
}

function install_binary {
  local readonly install_path="$1"
  local readonly username="$2"

  local readonly bin_dir="$install_path/bin"
  local readonly consul_dest_path="$bin_dir/consul"
  local readonly run_consul_dest_path="$bin_dir/run-consul"

  unzip -d /tmp "$DOWNLOAD_PACKAGE_PATH"

  log_info "Moving Consul binary to $consul_dest_path"
  sudo mv "/tmp/consul" "$consul_dest_path"
  sudo chown "$username:$username" "$consul_dest_path"
  sudo chmod a+x "$consul_dest_path"

  local readonly symlink_path="$SYSTEM_BIN_DIR/consul"
  if [[ -f "$symlink_path" ]]; then
    log_info "Symlink $symlink_path already exists. Will not add again."
  else
    log_info "Adding symlink to $consul_dest_path in $symlink_path"
    sudo ln -s "$consul_dest_path" "$symlink_path"
  fi

  # log_info "Copying Consul run script to $run_consul_dest_path"
  # sudo cp "$SCRIPT_DIR/../run-consul/run-consul" "$run_consul_dest_path"
  # sudo chown "$username:$username" "$run_consul_dest_path"
  # sudo chmod a+x "$run_consul_dest_path"
}

function install_tls_certificates {
  local readonly path="$1"
  local readonly user="$2"
  local readonly ca_file_path="$3"
  local readonly cert_file_path="$4"
  local readonly key_file_path="$5"

  local readonly consul_tls_certs_path="$path/tls"
  local readonly ca_certs_path="$consul_tls_certs_path/ca"

  log_info "Moving TLS certs to $consul_tls_certs_path and $ca_certs_path"

  sudo mkdir -p "$ca_certs_path"
  sudo mv "$ca_file_path" "$ca_certs_path/"
  sudo mv "$cert_file_path" "$consul_tls_certs_path/"
  sudo mv "$key_file_path" "$consul_tls_certs_path/"

  sudo chown -R "$user:$user" "$consul_tls_certs_path/"
  sudo find "$consul_tls_certs_path/" -type f -exec chmod u=r,g=,o= {} \;
}

function install {
  local version=${CONSUL_VERSION}
  local download_url=""
  local path="$DEFAULT_INSTALL_PATH"
  local user="$DEFAULT_CONSUL_USER"
  local ca_file_path=""
  local cert_file_path=""
  local key_file_path=""

  while [[ $# -gt 0 ]]; do
    local key="$1"

    case "$key" in
    --version)
      version="$2"
      shift
      ;;
    --download-url)
      download_url="$2"
      shift
      ;;
    --path)
      path="$2"
      shift
      ;;
    --user)
      user="$2"
      shift
      ;;
    --ca-file-path)
      assert_not_empty "$key" "$2"
      ca_file_path="$2"
      shift
      ;;
    --cert-file-path)
      assert_not_empty "$key" "$2"
      cert_file_path="$2"
      shift
      ;;
    --key-file-path)
      assert_not_empty "$key" "$2"
      key_file_path="$2"
      shift
      ;;
    --help)
      print_usage
      exit
      ;;
    *)
      log_error "Unrecognized argument: $key"
      print_usage
      exit 1
      ;;
    esac

    shift
  done

  # assert_either_or "--version" "$version" "--download-url" "$download_url"
  # assert_not_empty "--path" "$path"
  # assert_not_empty "--user" "$user"

  log_info "Starting Consul install"

  install_dependencies
  create_consul_user "$user"
  create_consul_install_paths "$path" "$user"

  fetch_binary "$version" "$download_url"
  install_binary "$path" "$user"

  if [[ -n "$ca_file_path" || -n "$cert_file_path" || -n "$key_file_path" ]]; then
    install_tls_certificates "$path" "$user" "$ca_file_path" "$cert_file_path" "$key_file_path"
  fi

  # This command is run with sudo rights so that it will succeed in cases where image hardening alters the permissions
  # on the directories where Consul may be installed. See https://github.com/hashicorp/terraform-aws-consul/issues/210.
  if sudo -E PATH=$PATH bash -c "command -v consul"; then
    log_info "Consul install complete!"
  else
    log_info "Could not find consul command. Aborting."
    exit 1
  fi
}

install "$@"

cat <<'EOCONSUL' >/opt/consul/bin/run-consul
#!/bin/bash
# This script is used to configure and run Consul on an DO server.

set -e

readonly CONSUL_CONFIG_FILE="default.json"
readonly SYSTEMD_CONFIG_PATH="/etc/systemd/system/consul.service"

readonly DIGITALOCEAN_METADATA_URL="http://169.254.169.254/metadata/v1"
readonly DIGITALOCEAN_DYNAMIC_DATA_URL="http://169.254.169.254/metadata/v1"

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "$0")"

readonly MAX_RETRIES=30
readonly SLEEP_BETWEEN_RETRIES_SEC=10

readonly DEFAULT_AUTOPILOT_CLEANUP_DEAD_SERVERS="true"
readonly DEFAULT_AUTOPILOT_LAST_CONTACT_THRESHOLD="200ms"
readonly DEFAULT_AUTOPILOT_MAX_TRAILING_LOGS="250"
readonly DEFAULT_AUTOPILOT_SERVER_STABILIZATION_TIME="10s"
readonly DEFAULT_AUTOPILOT_REDUNDANCY_ZONE_TAG="az"
readonly DEFAULT_AUTOPILOT_DISABLE_UPGRADE_MIGRATION="false"

function print_usage {
  echo
  echo "Usage: run-consul [OPTIONS]"
  echo
  echo "This script is used to configure and run Consul on an DO server."
  echo
  echo "Options:"
  echo
  echo -e "  --server\t\tIf set, run in server mode. Optional. Exactly one of --server or --client must be set."
  echo -e "  --client\t\tIf set, run in client mode. Optional. Exactly one of --server or --client must be set."
  echo -e "  --cluster-tag-key\tAutomatically form a cluster with Instances that have this tag key and the tag value in --cluster-tag-value. Optional."
  echo -e "  --cluster-tag-value\tAutomatically form a cluster with Instances that have the tag key in --cluster-tag-key and this tag value. Optional."
  echo -e "  --datacenter\t\tThe name of the datacenter Consul is running in. Optional. If not specified, will default to AWS region name."
  echo -e "  --config-dir\t\tThe path to the Consul config folder. Optional. Default is the absolute path of '../config', relative to this script."
  echo -e "  --data-dir\t\tThe path to the Consul data folder. Optional. Default is the absolute path of '../data', relative to this script."
  echo -e "  --systemd-stdout\t\tThe StandardOutput option of the systemd unit.  Optional.  If not configured, uses systemd's default (journal)."
  echo -e "  --systemd-stderr\t\tThe StandardError option of the systemd unit.  Optional.  If not configured, uses systemd's default (inherit)."
  echo -e "  --bin-dir\t\tThe path to the folder with Consul binary. Optional. Default is the absolute path of the parent folder of this script."
  echo -e "  --user\t\tThe user to run Consul as. Optional. Default is to use the owner of --config-dir."
  echo -e "  --enable-gossip-encryption\t\tEnable encryption of gossip traffic between nodes. Optional. Must also specify --gossip-encryption-key."
  echo -e "  --gossip-encryption-key\t\tThe key to use for encrypting gossip traffic. Optional. Must be specified with --enable-gossip-encryption."
  echo -e "  --enable-rpc-encryption\t\tEnable encryption of RPC traffic between nodes. Optional. Must also specify --ca-file-path, --cert-file-path and --key-file-path."
  echo -e "  --ca-path\t\tPath to the directory of CA files used to verify outgoing connections. Optional. Must be specified with --enable-rpc-encryption."
  echo -e "  --cert-file-path\tPath to the certificate file used to verify incoming connections. Optional. Must be specified with --enable-rpc-encryption and --key-file-path."
  echo -e "  --key-file-path\tPath to the certificate key used to verify incoming connections. Optional. Must be specified with --enable-rpc-encryption and --cert-file-path."
  echo -e "  --verify-server-hostname\tWhen passed in, enable server hostname verification as part of RPC encryption. Each server in Consul should get their own certificate that contains SERVERNAME.DATACENTERNAME.consul in the hostname or SAN. This prevents an authenticated agent from being converted into a server that streams all data, bypassing ACLs."
  echo -e "  --environment\t\tA single environment variable in the key/value pair form 'KEY=\"val\"' to pass to Consul as environment variable when starting it up. Repeat this option for additional variables. Optional."
  echo -e "  --skip-consul-config\tIf this flag is set, don't generate a Consul configuration file. Optional. Default is false."
  echo -e "  --recursor\tThis flag provides address of upstream DNS server that is used to recursively resolve queries if they are not inside the service domain for Consul. Repeat this option for additional variables. Optional."
  echo
  echo "Options for Consul Autopilot:"
  echo
  echo -e "  --autopilot-cleanup-dead-servers\tSet to true or false to control the automatic removal of dead server nodes periodically and whenever a new server is added to the cluster. Defaults to $DEFAULT_AUTOPILOT_CLEANUP_DEAD_SERVERS. Optional."
  echo -e "  --autopilot-last-contact-threshold\tControls the maximum amount of time a server can go without contact from the leader before being considered unhealthy. Must be a duration value such as 10s. Defaults to $DEFAULT_AUTOPILOT_LAST_CONTACT_THRESHOLD. Optional."
  echo -e "  --autopilot-max-trailing-logs\t\tControls the maximum number of log entries that a server can trail the leader by before being considered unhealthy. Defaults to $DEFAULT_AUTOPILOT_MAX_TRAILING_LOGS. Optional."
  echo -e "  --autopilot-server-stabilization-time\tControls the minimum amount of time a server must be stable in the 'healthy' state before being added to the cluster. Only takes effect if all servers are running Raft protocol version 3 or higher. Must be a duration value such as 30s. Defaults to $DEFAULT_AUTOPILOT_SERVER_STABILIZATION_TIME. Optional."
  echo -e "  --autopilot-redundancy-zone-tag\t\t(Enterprise-only) This controls the -node-meta key to use when Autopilot is separating servers into zones for redundancy. Only one server in each zone can be a voting member at one time. If left blank, this feature will be disabled. Defaults to $DEFAULT_AUTOPILOT_REDUNDANCY_ZONE_TAG. Optional."
  echo -e "  --autopilot-disable-upgrade-migration\t(Enterprise-only) If this flag is set, this will disable Autopilot's upgrade migration strategy in Consul Enterprise of waiting until enough newer-versioned servers have been added to the cluster before promoting any of them to voters. Defaults to $DEFAULT_AUTOPILOT_DISABLE_UPGRADE_MIGRATION. Optional."
  echo -e "  --autopilot-upgrade-version-tag\t\t(Enterprise-only) That tag to be used to override the version information used during a migration. Optional."
  echo
  echo
  echo "Example:"
  echo
  echo "  run-consul --server --config-dir /custom/path/to/consul/config"
}

function log {
  local -r level="$1"
  local -r message="$2"
  local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  >&2 echo -e "${timestamp} [${level}] [$SCRIPT_NAME] ${message}"
}

function log_info {
  local -r message="$1"
  log "INFO" "$message"
}

function log_warn {
  local -r message="$1"
  log "WARN" "$message"
}

function log_error {
  local -r message="$1"
  log "ERROR" "$message"
}

# Based on code from: http://stackoverflow.com/a/16623897/483528
function strip_prefix {
  local -r str="$1"
  local -r prefix="$2"
  echo "${str#$prefix}"
}

function assert_not_empty {
  local -r arg_name="$1"
  local -r arg_value="$2"

  if [[ -z "$arg_value" ]]; then
    log_error "The value for '$arg_name' cannot be empty"
    print_usage
    exit 1
  fi
}

function lookup_path_in_instance_metadata {
  local -r path="$1"
  curl --silent --show-error --location "$DIGITALOCEAN_METADATA_URL/$path"
}

function lookup_path_in_instance_dynamic_data {
  local -r path="$1"
  curl --silent --show-error --location "$DIGITALOCEAN_DYNAMIC_DATA_URL/$path"
}

function get_instance_ip_address {
  lookup_path_in_instance_metadata "interfaces/private/0/ipv4/address"
}

function get_instance_id {
  lookup_path_in_instance_metadata "id"
}

function get_instance_region {
  lookup_path_in_instance_dynamic_data "region"
}

function get_instance_tags {
  local tags=""
  local count_tags=""

  log_info "Looking up tags for Instance"
  for (( i=1; i<="$MAX_RETRIES"; i++ )); do
    tags=$(curl --silent --show-error --location "$DIGITALOCEAN_METADATA_URL/tags")
    count_tags=$(echo $tags | wc -w)
    if [[ "$count_tags" -gt 0 ]]; then
      log_info "This Instance has Tags."
      echo "$tags"
      return
    else
      log_warn "This Instance does not have any Tags."
      log_warn "Will sleep for $SLEEP_BETWEEN_RETRIES_SEC seconds and try again."
      sleep "$SLEEP_BETWEEN_RETRIES_SEC"
    fi
  done

  log_error "Could not find Instance Tags for after $MAX_RETRIES retries."
  exit 1
}

function assert_is_installed {
  local -r name="$1"

  if [[ ! $(command -v ${name}) ]]; then
    log_error "The binary '$name' is required by this script but is not installed or in the system's PATH."
    exit 1
  fi
}

function split_by_lines {
  local prefix="$1"
  shift

  for var in "$@"; do
    echo "${prefix}${var}"
  done
}

function generate_consul_config {
  local -r server="${1}"
  local -r config_dir="${2}"
  local -r user="${3}"
  local -r cluster_size="${4}"
  local -r cluster_api_token="${5}"
  local -r cluster_tag_name="${6}"
  local -r datacenter="${7}"
  local -r enable_gossip_encryption="${8}"
  local -r gossip_encryption_key="${9}"
  local -r enable_rpc_encryption="${10}"
  local -r verify_server_hostname="${11}"
  local -r ca_path="${12}"
  local -r cert_file_path="${13}"
  local -r key_file_path="${14}"
  local -r cleanup_dead_servers="${15}"
  local -r last_contact_threshold="${16}"
  local -r max_trailing_logs="${17}"
  local -r server_stabilization_time="${18}"
  local -r redundancy_zone_tag="${19}"
  local -r disable_upgrade_migration="${20}"
  local -r upgrade_version_tag=${21}
  local -r config_path="$config_dir/$CONSUL_CONFIG_FILE"

  shift 21
  local -r recursors=("$@")

  local instance_id=""
  local instance_ip_address=""
  local instance_region=""
  # https://www.consul.io/docs/agent/options#ui-1
  local ui_config_enabled="false"

  instance_id=$(get_instance_id)
  instance_ip_address=$(get_instance_ip_address)
  instance_region=$(get_instance_region)

  local retry_join_json=""
  if [[ -z "$cluster_api_token" || -z "$cluster_tag_name" ]]; then
    log_warn "Either the cluster API token ($cluster_api_token) or name ($cluster_tag_name) is empty. Will not automatically try to form a cluster based on DigitalOcean tags."
  else
    retry_join_json=$(cat <<EOF
"retry_join": ["provider=digitalocean region=$instance_region api_token=$cluster_api_token tag_name=$cluster_tag_name"],
EOF
)
  fi

  local recursors_config=""
  if (( ${#recursors[@]} != 0 )); then
        recursors_config="\"recursors\" : [ "
        for recursor in "${recursors[@]}"
        do
            recursors_config="${recursors_config}\"${recursor}\", "
        done
        recursors_config=$(echo "${recursors_config}"| sed 's/, $//')" ],"
  fi

  local bootstrap_expect=""
  if [[ "$server" == "true" ]]; then
    local instance_tags=""

    instance_tags=$(get_instance_tags)

    bootstrap_expect="\"bootstrap_expect\": $cluster_size,"
    ui_config_enabled="true"
  fi

  local autopilot_configuration
  autopilot_configuration=$(cat <<EOF
"autopilot": {
  "cleanup_dead_servers": $cleanup_dead_servers,
  "last_contact_threshold": "$last_contact_threshold",
  "max_trailing_logs": $max_trailing_logs,
  "server_stabilization_time": "$server_stabilization_time",
  "redundancy_zone_tag": "$redundancy_zone_tag",
  "disable_upgrade_migration": $disable_upgrade_migration,
  "upgrade_version_tag": "$upgrade_version_tag"
},
EOF
)

  local gossip_encryption_configuration=""
  if [[ "$enable_gossip_encryption" == "true" && -n "$gossip_encryption_key" ]]; then
    log_info "Creating gossip encryption configuration"
    gossip_encryption_configuration="\"encrypt\": \"$gossip_encryption_key\","
  fi

  local rpc_encryption_configuration=""
  if [[ "$enable_rpc_encryption" == "true" && -n "$ca_path" && -n "$cert_file_path" && -n "$key_file_path" ]]; then
    log_info "Creating RPC encryption configuration"
    rpc_encryption_configuration=$(cat <<EOF
"verify_outgoing": true,
"verify_incoming": true,
"verify_server_hostname": $verify_server_hostname,
"ca_path": "$ca_path",
"cert_file": "$cert_file_path",
"key_file": "$key_file_path",
EOF
)
  fi

  log_info "Creating default Consul configuration"
  local default_config_json
  default_config_json=$(cat <<EOF
{
  "advertise_addr": "$instance_ip_address",
  "bind_addr": "$instance_ip_address",
  $bootstrap_expect
  "client_addr": "0.0.0.0",
  "datacenter": "$datacenter",
  "node_name": "$instance_id",
  $recursors_config
  $retry_join_json
  "server": $server,
  $gossip_encryption_configuration
  $rpc_encryption_configuration
  $autopilot_configuration
  "telemetry": {
    "disable_compat_1.9": true
  },
  "ui_config": {
    "enabled": $ui_config_enabled
  }
}
EOF
)
  log_info "Installing Consul config file in $config_path"
  echo "$default_config_json" | jq '.' > "$config_path"
  chown "$user:$user" "$config_path"
}

function generate_systemd_config {
  local -r systemd_config_path="$1"
  local -r consul_config_dir="$2"
  local -r consul_data_dir="$3"
  local -r consul_systemd_stdout="$4"
  local -r consul_systemd_stderr="$5"
  local -r consul_bin_dir="$6"
  local -r consul_user="$7"
  shift 7
  local -r environment=("$@")
  local -r config_path="$consul_config_dir/$CONSUL_CONFIG_FILE"

  log_info "Creating systemd config file to run Consul in $systemd_config_path"

  local -r unit_config=$(cat <<EOF
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=$config_path

EOF
)

  local -r service_config=$(cat <<EOF
[Service]
Type=notify
User=$consul_user
Group=$consul_user
ExecStart=$consul_bin_dir/consul agent -config-dir $consul_config_dir -data-dir $consul_data_dir
ExecReload=$consul_bin_dir/consul reload
KillMode=process
Restart=on-failure
TimeoutSec=300s
LimitNOFILE=65536
$(split_by_lines "Environment=" "${environment[@]}")

EOF
)

  local log_config=""
  if [[ -n $consul_systemd_stdout ]]; then
    log_config+="StandardOutput=$consul_systemd_stdout\n"
  fi
  if [[ -n $consul_systemd_stderr ]]; then
    log_config+="StandardError=$consul_systemd_stderr\n"
  fi

  local -r install_config=$(cat <<EOF
[Install]
WantedBy=multi-user.target
EOF
)

  echo -e "$unit_config" > "$systemd_config_path"
  echo -e "$service_config" >> "$systemd_config_path"
  echo -e "$log_config" >> "$systemd_config_path"
  echo -e "$install_config" >> "$systemd_config_path"
}

function start_consul {
  log_info "Reloading systemd config and starting Consul"

  sudo systemctl daemon-reload
  sudo systemctl enable consul.service
  sudo systemctl restart consul.service
}

# Based on: http://unix.stackexchange.com/a/7732/215969
function get_owner_of_path {
  local -r path="$1"
  ls -ld "$path" | awk '{print $3}'
}

function run {
  local server="false"
  local client="false"
  local config_dir=""
  local data_dir=""
  local systemd_stdout=""
  local systemd_stderr=""
  local bin_dir=""
  local user=""
  local cluster_size=""
  local cluster_api_token=""
  local cluster_tag_name=""
  local datacenter=""
  local upgrade_version_tag=""
  local enable_gossip_encryption="false"
  local gossip_encryption_key=""
  local enable_rpc_encryption="false"
  local verify_server_hostname="false"
  local ca_path=""
  local cert_file_path=""
  local key_file_path=""
  local environment=()
  local skip_consul_config="false"
  local recursors=()
  local cleanup_dead_servers="$DEFAULT_AUTOPILOT_CLEANUP_DEAD_SERVERS"
  local last_contact_threshold="$DEFAULT_AUTOPILOT_LAST_CONTACT_THRESHOLD"
  local max_trailing_logs="$DEFAULT_AUTOPILOT_MAX_TRAILING_LOGS"
  local server_stabilization_time="$DEFAULT_AUTOPILOT_SERVER_STABILIZATION_TIME"
  local redundancy_zone_tag="$DEFAULT_AUTOPILOT_REDUNDANCY_ZONE_TAG"
  local disable_upgrade_migration="$DEFAULT_AUTOPILOT_DISABLE_UPGRADE_MIGRATION"

  while [[ $# -gt 0 ]]; do
    local key="$1"

    case "$key" in
      --server)
        server="true"
        ;;
      --client)
        client="true"
        ;;
      --config-dir)
        assert_not_empty "$key" "$2"
        config_dir="$2"
        shift
        ;;
      --data-dir)
        assert_not_empty "$key" "$2"
        data_dir="$2"
        shift
        ;;
      --systemd-stdout)
        assert_not_empty "$key" "$2"
        systemd_stdout="$2"
        shift
        ;;
      --systemd-stderr)
        assert_not_empty "$key" "$2"
        systemd_stderr="$2"
        shift
        ;;
      --bin-dir)
        assert_not_empty "$key" "$2"
        bin_dir="$2"
        shift
        ;;
      --user)
        assert_not_empty "$key" "$2"
        user="$2"
        shift
        ;;
      --cluster-size)
        assert_not_empty "$key" "$2"
        cluster_size="$2"
        shift
        ;;
      --cluster-api-token)
        assert_not_empty "$key" "$2"
        cluster_api_token="$2"
        shift
        ;;
      --cluster-tag-name)
        assert_not_empty "$key" "$2"
        cluster_tag_name="$2"
        shift
        ;;
      --datacenter)
        assert_not_empty "$key" "$2"
        datacenter="$2"
        shift
        ;;
      --autopilot-cleanup-dead-servers)
        assert_not_empty "$key" "$2"
        cleanup_dead_servers="$2"
        shift
        ;;
      --autopilot-last-contact-threshold)
        assert_not_empty "$key" "$2"
        last_contact_threshold="$2"
        shift
        ;;
      --autopilot-max-trailing-logs)
        assert_not_empty "$key" "$2"
        max_trailing_logs="$2"
        shift
        ;;
      --autopilot-server-stabilization-time)
        assert_not_empty "$key" "$2"
        server_stabilization_time="$2"
        shift
        ;;
      --autopilot-redundancy-zone-tag)
        assert_not_empty "$key" "$2"
        redundancy_zone_tag="$2"
        shift
        ;;
      --autopilot-disable-upgrade-migration)
        disable_upgrade_migration="true"
        shift
        ;;
      --autopilot-upgrade-version-tag)
        assert_not_empty "$key" "$2"
        upgrade_version_tag="$2"
        shift
        ;;
      --enable-gossip-encryption)
        enable_gossip_encryption="true"
        ;;
      --gossip-encryption-key)
        assert_not_empty "$key" "$2"
        gossip_encryption_key="$2"
        shift
        ;;
      --enable-rpc-encryption)
        enable_rpc_encryption="true"
        ;;
      --verify-server-hostname)
        verify_server_hostname="true"
        ;;
      --ca-path)
        assert_not_empty "$key" "$2"
        ca_path="$2"
        shift
        ;;
      --cert-file-path)
        assert_not_empty "$key" "$2"
        cert_file_path="$2"
        shift
        ;;
      --key-file-path)
        assert_not_empty "$key" "$2"
        key_file_path="$2"
        shift
        ;;
      --environment)
        assert_not_empty "$key" "$2"
        environment+=("$2")
        shift
        ;;
      --skip-consul-config)
        skip_consul_config="true"
        ;;
      --recursor)
        assert_not_empty "$key" "$2"
        recursors+=("$2")
        shift
        ;;
      --help)
        print_usage
        exit
        ;;
      *)
        log_error "Unrecognized argument: $key"
        print_usage
        exit 1
        ;;
    esac

    shift
  done

  if [[ ("$server" == "true" && "$client" == "true") || ("$server" == "false" && "$client" == "false") ]]; then
    log_error "Exactly one of --server or --client must be set."
    exit 1
  fi

  assert_is_installed "systemctl"
  assert_is_installed "curl"
  assert_is_installed "jq"

  if [[ -z "$config_dir" ]]; then
    config_dir=$(cd "$SCRIPT_DIR/../config" && pwd)
  fi

  if [[ -z "$data_dir" ]]; then
    data_dir=$(cd "$SCRIPT_DIR/../data" && pwd)
  fi

  # If $systemd_stdout and/or $systemd_stderr are empty, we leave them empty so that generate_systemd_config will use systemd's defaults (journal and inherit, respectively)

  if [[ -z "$bin_dir" ]]; then
    bin_dir=$(cd "$SCRIPT_DIR/../bin" && pwd)
  fi

  if [[ -z "$user" ]]; then
    user=$(get_owner_of_path "$config_dir")
  fi

  if [[ -z "$datacenter" ]]; then
    datacenter=$(get_instance_region)
  fi

  if [[ "$skip_consul_config" == "true" ]]; then
    log_info "The --skip-consul-config flag is set, so will not generate a default Consul config file."
  else
    if [[ "$enable_gossip_encryption" == "true" ]]; then
      assert_not_empty "--gossip-encryption-key" "$gossip_encryption_key"
    fi
    if [[ "$enable_rpc_encryption" == "true" ]]; then
      assert_not_empty "--ca-path" "$ca_path"
      assert_not_empty "--cert-file-path" "$cert_file_path"
      assert_not_empty "--key_file_path" "$key_file_path"
    fi

    generate_consul_config "$server" \
      "$config_dir" \
      "$user" \
      "$cluster_size" \
      "$cluster_api_token" \
      "$cluster_tag_name" \
      "$datacenter" \
      "$enable_gossip_encryption" \
      "$gossip_encryption_key" \
      "$enable_rpc_encryption" \
      "$verify_server_hostname" \
      "$ca_path" \
      "$cert_file_path" \
      "$key_file_path" \
      "$cleanup_dead_servers" \
      "$last_contact_threshold" \
      "$max_trailing_logs" \
      "$server_stabilization_time" \
      "$redundancy_zone_tag" \
      "$disable_upgrade_migration" \
      "$upgrade_version_tag" \
      "${recursors[@]}"
  fi

  generate_systemd_config "$SYSTEMD_CONFIG_PATH" "$config_dir" "$data_dir" "$systemd_stdout" "$systemd_stderr" "$bin_dir" "$user" "${environment[@]}"
  start_consul
}

run "$@"
EOCONSUL

chmod a+x /opt/consul/bin/run-consul
