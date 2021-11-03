#!/bin/bash -eux

NOMAD_VERSION=${NOMAD_VERSION:-1.1.2}

readonly DEFAULT_INSTALL_PATH="/opt/nomad"
readonly DEFAULT_NOMAD_USER="nomad"

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SYSTEM_BIN_DIR="/usr/local/bin"

readonly SUPERVISOR_DIR="/etc/supervisor"
readonly SUPERVISOR_CONF_DIR="$SUPERVISOR_DIR/conf.d"

readonly SCRIPT_NAME="$(basename "$0")"

function print_usage {
  echo
  echo "Usage: install-nomad [OPTIONS]"
  echo
  echo "This script can be used to install Nomad and its dependencies. This script has been tested with Ubuntu 16.04, Ubuntu 18.04 and Amazon Linux 2."
  echo
  echo "Options:"
  echo
  echo -e "  --version\t\tThe version of Nomad to install. Required."
  echo -e "  --path\t\tThe path where Nomad should be installed. Optional. Default: $DEFAULT_INSTALL_PATH."
  echo -e "  --user\t\tThe user who will own the Nomad install directories. Optional. Default: $DEFAULT_NOMAD_USER."
  echo
  echo "Example:"
  echo
  echo "  install-nomad --version 0.5.4"
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

function has_yum {
  [ -n "$(command -v yum)" ]
}

function has_apt_get {
  [ -n "$(command -v apt-get)" ]
}

function install_dependencies {
  log_info "Installing dependencies"

  if $(has_apt_get); then
    sudo apt-get update -y
    sudo apt-get install -y awscli curl unzip jq
  elif $(has_yum); then
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

function create_nomad_user {
  local readonly username="$1"

  if $(user_exists "$username"); then
    echo "User $username already exists. Will not create again."
  else
    log_info "Creating user named $username"
    sudo useradd "$username"
  fi
}

function create_nomad_install_paths {
  local readonly path="$1"
  local readonly username="$2"

  log_info "Creating install dirs for Nomad at $path"
  sudo mkdir -p "$path"
  sudo mkdir -p "$path/bin"
  sudo mkdir -p "$path/config"
  sudo mkdir -p "$path/data"

  log_info "Changing ownership of $path to $username"
  sudo chown -R "$username:$username" "$path"
}

function install_binaries {
  local readonly version="$1"
  local readonly path="$2"
  local readonly username="$3"

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
    binary_arch="arm"
    ;;
  *)
    log_error "CPU architecture $cpu_arch is not a supported by Consul."
    exit 1
    ;;
  esac

  local readonly url="https://releases.hashicorp.com/nomad/${version}/nomad_${version}_linux_${binary_arch}.zip"
  local readonly download_path="/tmp/nomad_${version}_linux_${binary_arch}.zip"
  local readonly bin_dir="$path/bin"
  local readonly nomad_dest_path="$bin_dir/nomad"
  local readonly run_nomad_dest_path="$bin_dir/run-nomad"

  log_info "Downloading Nomad $version from $url to $download_path"
  curl -o "$download_path" "$url"
  unzip -d /tmp "$download_path"

  log_info "Moving Nomad binary to $nomad_dest_path"
  sudo mv "/tmp/nomad" "$nomad_dest_path"
  sudo chown "$username:$username" "$nomad_dest_path"
  sudo chmod a+x "$nomad_dest_path"

  local readonly symlink_path="$SYSTEM_BIN_DIR/nomad"
  if [[ -f "$symlink_path" ]]; then
    log_info "Symlink $symlink_path already exists. Will not add again."
  else
    log_info "Adding symlink to $nomad_dest_path in $symlink_path"
    sudo ln -s "$nomad_dest_path" "$symlink_path"
  fi
}

function install {
  local version="$NOMAD_VERSION"
  local path="$DEFAULT_INSTALL_PATH"
  local user="$DEFAULT_NOMAD_USER"

  while [[ $# > 0 ]]; do
    local key="$1"

    case "$key" in
    --version)
      version="$2"
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

  assert_not_empty "--version" "$version"
  assert_not_empty "--path" "$path"
  assert_not_empty "--user" "$user"

  log_info "Starting Nomad install"

  install_dependencies
  create_nomad_user "$user"
  create_nomad_install_paths "$path" "$user"
  install_binaries "$version" "$path" "$user"

  log_info "Nomad install complete!"
}

install "$@"

echo "Installing custom run-nomad script..."
cat <<'EONOMAD' >/opt/nomad/bin/run-nomad
#!/bin/bash
# This script is used to configure and run Nomad on an DO server.

set -e

readonly NOMAD_CONFIG_FILE="default.hcl"
readonly SYSTEMD_CONFIG_PATH="/etc/systemd/system/nomad.service"

readonly DIGITALOCEAN_METADATA_URL="http://169.254.169.254/metadata/v1"
readonly DIGITALOCEAN_DYNAMIC_DATA_URL="http://169.254.169.254/metadata/v1"

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "$0")"

function print_usage {
  echo
  echo "Usage: run-nomad [OPTIONS]"
  echo
  echo "This script is used to configure and run Nomad on an DO server."
  echo
  echo "Options:"
  echo
  echo -e "  --server\t\tIf set, run in server mode. Optional. At least one of --server or --client must be set."
  echo -e "  --client\t\tIf set, run in client mode. Optional. At least one of --server or --client must be set."
  echo -e "  --num-servers\t\tThe number of servers to expect in the Nomad cluster. Required if --server is true."
  echo -e "  --config-dir\t\tThe path to the Nomad config folder. Optional. Default is the absolute path of '../config', relative to this script."
  echo -e "  --data-dir\t\tThe path to the Nomad data folder. Optional. Default is the absolute path of '../data', relative to this script."
  echo -e "  --bin-dir\t\tThe path to the folder with Nomad binary. Optional. Default is the absolute path of the parent folder of this script."
  echo -e "  --systemd-stdout\t\tThe StandardOutput option of the systemd unit.  Optional.  If not configured, uses systemd's default (journal)."
  echo -e "  --systemd-stderr\t\tThe StandardError option of the systemd unit.  Optional.  If not configured, uses systemd's default (inherit)."
  echo -e "  --user\t\tThe user to run Nomad as. Optional. Default is to use the owner of --config-dir."
  echo -e "  --use-sudo\t\tIf set, run the Nomad agent with sudo. By default, sudo is only used if --client is set."
  echo -e "  --environment\t\A single environment variable in the key/value pair form 'KEY=\"val\"' to pass to Nomad as environment variable when starting it up. Repeat this option for additional variables. Optional."
  echo -e "  --skip-nomad-config\tIf this flag is set, don't generate a Nomad configuration file. Optional. Default is false."
  echo
  echo "Example:"
  echo
  echo "  run-nomad --server --config-dir /custom/path/to/nomad/config"
}

function log {
  local readonly level="$1"
  local readonly message="$2"
  local readonly timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  >&2 echo -e "${timestamp} [${level}] [$SCRIPT_NAME] ${message}"
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

# Based on code from: http://stackoverflow.com/a/16623897/483528
function strip_prefix {
  local readonly str="$1"
  local readonly prefix="$2"
  echo "${str#$prefix}"
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

function split_by_lines {
  local prefix="$1"
  shift

  for var in "$@"; do
    echo "${prefix}${var}"
  done
}

function lookup_path_in_instance_metadata {
  local readonly path="$1"
  curl --silent --location "$DIGITALOCEAN_METADATA_URL/$path"
}

function lookup_path_in_instance_dynamic_data {
  local readonly path="$1"
  curl --silent --location "$DIGITALOCEAN_DYNAMIC_DATA_URL/$path"
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

function assert_is_installed {
  local readonly name="$1"

  if [[ ! $(command -v ${name}) ]]; then
    log_error "The binary '$name' is required by this script but is not installed or in the system's PATH."
    exit 1
  fi
}

function generate_nomad_config {
  local readonly server="$1"
  local readonly client="$2"
  local readonly num_servers="$3"
  local readonly config_dir="$4"
  local readonly user="$5"
  local readonly config_path="$config_dir/$NOMAD_CONFIG_FILE"

  local instance_id=""
  local instance_ip_address=""
  local instance_region=""

  instance_id=$(get_instance_id)
  instance_ip_address=$(get_instance_ip_address)
  instance_region=$(get_instance_region)

  local server_config=""
  if [[ "$server" == "true" ]]; then
    server_config=$(
  cat <<EOF
server {
  enabled = true
  bootstrap_expect = $num_servers
}
EOF
)
  fi

  local client_config=""
  if [[ "$client" == "true" ]]; then
    client_config=$(
  cat <<EOF
client {
  enabled = true
}
EOF
)
  fi

  log_info "Creating default Nomad config file in $config_path"
  cat > "$config_path" <<EOF
datacenter = "$instance_region"
name       = "$instance_id"
region     = "$instance_region"
bind_addr  = "0.0.0.0"

advertise {
  http = "$instance_ip_address"
  rpc  = "$instance_ip_address"
  serf = "$instance_ip_address"
}

$client_config

$server_config

consul {
  address = "127.0.0.1:8500"
}
EOF
  chown "$user:$user" "$config_path"
}

function generate_systemd_config {
  local readonly systemd_config_path="$1"
  local readonly nomad_config_dir="$2"
  local readonly nomad_data_dir="$3"
  local readonly nomad_bin_dir="$4"
  local readonly nomad_sytemd_stdout="$5"
  local readonly nomad_sytemd_stderr="$6"
  local readonly nomad_user="$7"
  local readonly use_sudo="$8"
  shift 8
  local readonly environment=("$@")
  local readonly config_path="$nomad_config_dir/$NOMAD_CONFIG_FILE"

  if [[ "$use_sudo" == "true" ]]; then
    log_info "The --use-sudo flag is set, so running Nomad as the root user"
    nomad_user="root"
  fi

  log_info "Creating systemd config file to run Nomad in $systemd_config_path"

  local readonly unit_config=$(
  cat <<EOF
[Unit]
Description="HashiCorp Nomad"
Documentation=https://www.nomadproject.io/
Requires=network-online.target
After=network-online.target
ConditionalFileNotEmpty=$config_path
EOF
)

  local readonly service_config=$(
  cat <<EOF
[Service]
User=$nomad_user
Group=$nomad_user
ExecStart=$nomad_bin_dir/nomad agent -config $nomad_config_dir -data-dir $nomad_data_dir
ExecReload=/bin/kill --signal HUP \$MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536
$(split_by_lines "Environment=" "${environment[@]}")

EOF
)

  local log_config=""
  if [[ ! -z $nomad_sytemd_stdout ]]; then
    log_config+="StandardOutput=$nomad_sytemd_stdout\n"
  fi
  if [[ ! -z $nomad_sytemd_stderr ]]; then
    log_config+="StandardError=$nomad_sytemd_stderr\n"
  fi

  local readonly install_config=$(
  cat <<EOF
[Install]
WantedBy=multi-user.target
EOF
)

  echo -e "$unit_config" > "$systemd_config_path"
  echo -e "$service_config" >> "$systemd_config_path"
  echo -e "$log_config" >> "$systemd_config_path"
  echo -e "$install_config" >> "$systemd_config_path"
}

function start_nomad {
  log_info "Reloading systemd config and starting Nomad"

  sudo systemctl daemon-reload
  sudo systemctl enable nomad.service
  sudo systemctl restart nomad.service
}

# Based on: http://unix.stackexchange.com/a/7732/215969
function get_owner_of_path {
  local readonly path="$1"
  ls -ld "$path" | awk '{print $3}'
}

function run {
  local server="false"
  local client="false"
  local num_servers=""
  local config_dir=""
  local data_dir=""
  local bin_dir=""
  local systemd_stdout=""
  local systemd_stderr=""
  local user=""
  local skip_nomad_config="false"
  local use_sudo=""
  local environment=()
  local all_args=()

  while [[ $# > 0 ]]; do
    local key="$1"

    case "$key" in
      --server)
        server="true"
        ;;
      --client)
        client="true"
        ;;
      --num-servers)
        num_servers="$2"
        shift
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
      --bin-dir)
        assert_not_empty "$key" "$2"
        bin_dir="$2"
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
      --user)
        assert_not_empty "$key" "$2"
        user="$2"
        shift
        ;;
      --cluster-tag-key)
        assert_not_empty "$key" "$2"
        cluster_tag_key="$2"
        shift
        ;;
      --cluster-tag-value)
        assert_not_empty "$key" "$2"
        cluster_tag_value="$2"
        shift
        ;;
      --skip-nomad-config)
        skip_nomad_config="true"
        ;;
      --use-sudo)
        use_sudo="true"
        ;;
      --environment)
        assert_not_empty "$key" "$2"
        environment+=("$2")
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

  if [[ "$server" == "true" ]]; then
    assert_not_empty "--num-servers" "$num_servers"
  fi

  if [[ "$server" == "false" && "$client" == "false" ]]; then
    log_error "At least one of --server or --client must be set"
    exit 1
  fi

  if [[ -z "$use_sudo" ]]; then
    if [[ "$client" == "true" ]]; then
      use_sudo="true"
    else
      use_sudo="false"
    fi
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

  if [[ -z "$bin_dir" ]]; then
    bin_dir=$(cd "$SCRIPT_DIR/../bin" && pwd)
  fi

  # If $systemd_stdout and/or $systemd_stderr are empty, we leave them empty so that generate_systemd_config will use systemd's defaults (journal and inherit, respectively)

  if [[ -z "$user" ]]; then
    user=$(get_owner_of_path "$config_dir")
  fi

  if [[ "$skip_nomad_config" == "true" ]]; then
    log_info "The --skip-nomad-config flag is set, so will not generate a default Nomad config file."
  else
    generate_nomad_config "$server" "$client" "$num_servers" "$config_dir" "$user"
  fi

  generate_systemd_config "$SYSTEMD_CONFIG_PATH" "$config_dir" "$data_dir" "$bin_dir" "$systemd_stdout" "$systemd_stderr" "$user" "$use_sudo" "${environment[@]}"
  start_nomad
}
EONOMAD

chmod a+x /opt/nomad/bin/run-nomad
