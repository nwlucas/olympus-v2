#!/bin/bash -eux

VAULT_VERSION=${VAULT_VERSION:-1.8.0}

readonly DEFAULT_INSTALL_PATH="/opt/vault"
readonly DEFAULT_VAULT_USER="vault"
readonly DEFAULT_SKIP_PACKAGE_UPDATE="false"

readonly DOWNLOAD_PACKAGE_PATH="/tmp/vault.zip"

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SYSTEM_BIN_DIR="/usr/local/bin"

readonly SCRIPT_NAME="$(basename "$0")"

function print_usage {
  echo
  echo "Usage: install-vault [OPTIONS]"
  echo
  echo "This script can be used to install Vault and its dependencies. This script has been tested with Ubuntu 16.04, Ubuntu 18.04 and Amazon Linux 2."
  echo
  echo "Options:"
  echo
  echo -e "  --version\t\tThe version of Vault to install. Optional if download-url is provided."
  echo -e "  --download-url\t\tUrl to exact Vault package to be installed. Optional if version is provided."
  echo -e "  --path\t\tThe path where Vault should be installed. Optional. Default: $DEFAULT_INSTALL_PATH."
  echo -e "  --user\t\tThe user who will own the Vault install directories. Optional. Default: $DEFAULT_VAULT_USER."
  echo -e "  --skip-package-update\t\tSkip yum/apt updates. Optional. Only recommended if you already ran yum update or apt-get update yourself. Default: $DEFAULT_SKIP_PACKAGE_UPDATE."
  echo
  echo "Example:"
  echo
  echo "  install-vault --version 0.10.4"
}

function log {
  local -r level="$1"
  local -r message="$2"
  local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo >&2 -e "${timestamp} [${level}] [$SCRIPT_NAME] ${message}"
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

function assert_not_empty {
  local -r arg_name="$1"
  local -r arg_value="$2"

  if [[ -z "$arg_value" ]]; then
    log_error "The value for '$arg_name' cannot be empty"
    print_usage
    exit 1
  fi
}

function assert_either_or {
  local -r arg1_name="$1"
  local -r arg1_value="$2"
  local -r arg2_name="$3"
  local -r arg2_value="$4"

  if [[ -z "$arg1_value" && -z "$arg2_value" ]]; then
    log_error "Either the value for '$arg1_name' or '$arg2_name' must be passed, both cannot be empty"
    print_usage
    exit 1
  fi
}

# A retry function that attempts to run a command a number of times and returns the output
function retry {
  local -r cmd="$1"
  local -r description="$2"

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
  [[ -n "$(command -v yum)" ]]
}

function has_apt_get {
  [[ -n "$(command -v apt-get)" ]]
}

function install_dependencies {
  local -r skip_package_update=$1
  log_info "Installing dependencies"
  if $(has_apt_get); then
    if [[ "$skip_package_update" != "true" ]]; then
      log_info "Running apt-get update"
      sudo apt-get update -y
    fi
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y awscli curl unzip jq libcap2-bin
  elif $(has_yum); then
    if [[ "$skip_package_update" != "true" ]]; then
      log_info "Running yum update"
      sudo yum update -y
    fi
    sudo yum install -y awscli curl unzip jq
  else
    log_error "Could not find apt-get or yum. Cannot install dependencies on this OS."
    exit 1
  fi
}

function user_exists {
  local -r username="$1"
  id "$username" >/dev/null 2>&1
}

function create_vault_user {
  local -r username="$1"

  if $(user_exists "$username"); then
    echo "User $username already exists. Will not create again."
  else
    log_info "Creating user named $username"
    sudo useradd --system "$username"
  fi
}

function create_vault_install_paths {
  local -r path="$1"
  local -r username="$2"

  log_info "Creating install dirs for Vault at $path"
  sudo mkdir -p "$path"
  sudo mkdir -p "$path/bin"
  sudo mkdir -p "$path/config"
  sudo mkdir -p "$path/data"
  sudo mkdir -p "$path/tls"
  sudo mkdir -p "$path/scripts"
  sudo chmod 755 "$path"
  sudo chmod 755 "$path/bin"
  sudo chmod 755 "$path/data"

  log_info "Changing ownership of $path to $username"
  sudo chown -R "$username:$username" "$path"
}

function fetch_binary {
  local -r version="$1"
  local download_url="$2"

  if [[ -z "$download_url" && -n "$version" ]]; then
    download_url="https://releases.hashicorp.com/vault/${version}/vault_${version}_linux_amd64.zip"
  fi

  retry \
    "curl -o '$DOWNLOAD_PACKAGE_PATH' '$download_url' --location --silent --fail --show-error" \
    "Downloading Vault to $DOWNLOAD_PACKAGE_PATH"
}

function install_binary {
  local -r install_path="$1"
  local -r username="$2"

  local -r bin_dir="$install_path/bin"
  local -r vault_dest_path="$bin_dir/vault"
  local -r run_vault_dest_path="$bin_dir/run-vault"

  unzip -d /tmp "$DOWNLOAD_PACKAGE_PATH"

  log_info "Moving Vault binary to $vault_dest_path"
  sudo mv "/tmp/vault" "$vault_dest_path"
  sudo chown "$username:$username" "$vault_dest_path"
  sudo chmod a+x "$vault_dest_path"

  local -r symlink_path="$SYSTEM_BIN_DIR/vault"
  if [[ -f "$symlink_path" ]]; then
    log_info "Symlink $symlink_path already exists. Will not add again."
  else
    log_info "Adding symlink to $vault_dest_path in $symlink_path"
    sudo ln -s "$vault_dest_path" "$symlink_path"
  fi

}

# For more info, see: https://www.vaultproject.io/docs/configuration/#disable_mlock
function configure_mlock {
  echo "Giving Vault permission to use the mlock syscall"
  # Requires installing libcap2-bin on Ubuntu 18
  sudo setcap cap_ipc_lock=+ep $(readlink -f $(which vault))
}

function install {
  local version=${VAULT_VERSION}
  local download_url=""
  local path="$DEFAULT_INSTALL_PATH"
  local user="$DEFAULT_VAULT_USER"
  local skip_package_update="$DEFAULT_SKIP_PACKAGE_UPDATE"

  while [[ $# > 0 ]]; do
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
    --skip-package-update)
      skip_package_update="true"
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

  assert_either_or "--version" "$version" "--download-url" "$download_url"
  assert_not_empty "--path" "$path"
  assert_not_empty "--user" "$user"

  log_info "Starting Vault install"

  install_dependencies "$skip_package_update"
  create_vault_user "$user"
  create_vault_install_paths "$path" "$user"
  fetch_binary "$version" "$download_url"
  install_binary "$path" "$user"
  configure_mlock

  if command -v vault; then
    log_info "Vault install complete!"
  else
    log_info "Could not find vault command. Aborting."
    exit 1
  fi
}

install "$@"

cat <<'EOCONSUL' >/opt/vault/bin/run-vault
#!/bin/bash
# This script is used to configure and run Vault on an DO server.

set -e

readonly VAULT_CONFIG_FILE="default.hcl"
readonly VAULT_PID_FILE="vault-pid"
readonly VAULT_TOKEN_FILE="vault-token"
readonly SYSTEMD_CONFIG_PATH="/etc/systemd/system/vault.service"

readonly DEFAULT_AGENT_VAULT_ADDRESS="vault.service.consul"
readonly DEFAULT_AGENT_AUTH_MOUNT_PATH="auth/digitalocean"

readonly DEFAULT_PORT=8200
readonly DEFAULT_LOG_LEVEL="info"

readonly DEFAULT_CONSUL_AGENT_SERVICE_REGISTRATION_ADDRESS="localhost:8500"

readonly DO_INSTANCE_METADATA_URL="http://169.254.169.254/metadata/v1"

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "$0")"

function print_usage {
  echo
  echo "Usage: run-vault [OPTIONS]"
  echo
  echo "This script is used to configure and run Vault on an DO server."
  echo
  echo "Options:"
  echo
  echo -e "  --tls-cert-file\tSpecifies the path to the certificate for TLS. Required. To use a CA certificate, concatenate the primary certificate and the CA certificate together."
  echo -e "  --tls-key-file\tSpecifies the path to the private key for the certificate. Required."
  echo -e "  --port\t\tThe port for Vault to listen on. Optional. Default is $DEFAULT_PORT."
  echo -e "  --cluster-port\tThe port for Vault to listen on for server-to-server requests. Optional. Default is --port + 1."
  echo -e "  --api-addr\t\tThe full address to use for Client Redirection when running Vault in HA mode. Defaults to \"https://[instance_ip]:$DEFAULT_PORT\". Optional."
  echo -e "  --config-dir\t\tThe path to the Vault config folder. Optional. Default is the absolute path of '../config', relative to this script."
  echo -e "  --bin-dir\t\tThe path to the folder with Vault binary. Optional. Default is the absolute path of the parent folder of this script."
  echo -e "  --data-dir\t\tThe path to the Vault data folder. Optional. Default is the absolute path of '../data', relative to this script."
  echo -e "  --log-level\t\tThe log verbosity to use with Vault. Optional. Default is $DEFAULT_LOG_LEVEL."
  echo -e "  --systemd-stdout\t\tThe StandardOutput option of the systemd unit.  Optional.  If not configured, uses systemd's default (journal)."
  echo -e "  --systemd-stderr\t\tThe StandardError option of the systemd unit.  Optional.  If not configured, uses systemd's default (inherit)."
  echo -e "  --user\t\tThe user to run Vault as. Optional. Default is to use the owner of --config-dir."
  echo -e "  --skip-vault-config\tIf this flag is set, don't generate a Vault configuration file. Optional. Default is false."
  echo -e "  --enable-s3-backend\tIf this flag is set, an S3 backend will be enabled in addition to the HA Consul backend. Default is false."
  echo -e "  --s3-bucket\tSpecifies the S3 bucket to use to store Vault data. Only used if '--enable-s3-backend' is set."
  echo -e "  --s3-bucket-path\tSpecifies the S3 bucket path to use to store Vault data. Only used if '--enable-s3-backend' is set."
  echo -e "  --s3-bucket-region\tSpecifies the AWS region where '--s3-bucket' lives. Only used if '--enable-s3-backend' is set."
  echo -e "  --consul-agent-service-registration-address\tSpecifies the address of the Consul agent to communicate with when using a different storage backend, in this case an S3 backend. Only used if '--enable-s3-backend' is set. Default is ${DEFAULT_CONSUL_AGENT_SERVICE_REGISTRATION_ADDRESS}."
  echo -e "  --enable-dynamo-backend\tIf this flag is set, DynamoDB will be enabled as the backend storage (HA)"
  echo -e "  --dynamo-region\tSpecifies the AWS region where --dynamo-table lives.  Only used if '--enable-dynamo-backend is on'"
  echo -e "  --dynamo--table\tSpecifies the DynamoDB table to use for HA Storage.  Only used if '--enable-dynamo-backend is on'"
  echo
  echo "Options for Vault Agent:"
  echo
  echo -e "  --agent\t\t\tIf set, run in Vault Agent mode.  If not set, run as a regular Vault server.  Optional."
  echo -e "  --agent-vault-address\t\tThe hostname or IP address of the Vault server to connect to.  Optional. Default is $DEFAULT_AGENT_VAULT_ADDRESS"
  echo -e "  --agent-vault-port\t\tThe port of the Vault server to connect to.  Optional. Default is $DEFAULT_PORT"
  echo -e "  --agent-ca-cert-file\t\tSpecifies the path to a CA certificate to verify the Vault server's TLS certificate.  Optional."
  echo -e "  --agent-client-cert-file\tSpecifies the path to a certificate to use for TLS authentication to the Vault server.  Optional."
  echo -e "  --agent-client-key-file\tSpecifies the path to the private key for the client certificate used for TLS authentication to the Vault server.  Optional."
  echo -e "  --agent-auth-mount-path\tThe Vault mount path to the auth method used for auto-auth.  Optional.  Defaults to $DEFAULT_AGENT_AUTH_MOUNT_PATH"
  echo -e "  --agent-auth-type\t\tThe Vault AWS auth type to use for auto-auth.  Required.  Must be either iam or ec2"
  echo -e "  --agent-auth-role\t\tThe Vault role to authenticate against.  Required."
  echo
  echo "Optional Arguments for enabling the AWS KMS seal (Vault Enterprise or 1.0 and above):"
  echo
  echo -e "  --enable-auto-unseal\tIf this flag is set, enable the AWS KMS Auto-unseal feature. Default is false."
  echo -e "  --auto-unseal-kms-key-id\tThe key id of the AWS KMS key to be used for encryption and decryption. Required if --enable-auto-unseal is enabled."
  echo -e "  --auto-unseal-kms-key-region\tThe AWS region where the encryption key lives. Required if --enable-auto-unseal is enabled."
  echo -e "  --auto-unseal-endpoint\tThe KMS API endpoint to be used to make AWS KMS requests. Optional. Defaults to \"\". Only used if --enable-auto-unseal is enabled."
  echo
  echo "Examples:"
  echo
  echo "  run-vault --tls-cert-file /opt/vault/tls/vault.crt.pem --tls-key-file /opt/vault/tls/vault.key.pem"
  echo
  echo "Or"
  echo
  echo "  run-vault --tls-cert-file /opt/vault/tls/vault.crt.pem --tls-key-file /opt/vault/tls/vault.key.pem --enable-s3-backend --s3-bucket my-vault-bucket --s3-bucket-region us-east-1"
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
  curl --silent --location "$DO_INSTANCE_METADATA_URL/$path"
}

function get_instance_ip_address {
  lookup_path_in_instance_metadata "interfaces/public/0/ipv4/address"
}

function assert_is_installed {
  local -r name="$1"

  if [[ ! $(command -v ${name}) ]]; then
    log_error "The binary '$name' is required by this script but is not installed or in the system's PATH."
    exit 1
  fi
}

function get_vault_version {
  #Runs vault -v to get the vault version, then strips out everything but the version number.
  #The current output format of vault -v is:
  #Vault v0.10.4 ('e21712a687889de1125e0a12a980420b1a4f72d3')
  /usr/local/bin/vault -v|awk '{print $2}'|tr -d v
}

function vault_version_at_least {
  local -r config_path=$1
  local -r ui_config=$2
  VAULT_VERSION=$(get_vault_version)

  #This if statement will echo the current vault version and the minimum version required for ui support.
  #It then strips out the comments, sorts the two values, and chooses the top (least) one.
  if [[ $(echo "$VAULT_VERSION 0.10.0" | tr " " "\n" |sort --version-sort| head -n 1) = 0.10.0 ]]
    then
      echo -e "$ui_config" >> "$config_path"
    else
      log_info "Vault 0.10.0 or greater is required for UI support."
  fi
}

function generate_vault_agent_config {
  local -r config_dir="$1"
  local -r data_dir="$2"
  local -r vault_address="$3"
  local -r vault_port="$4"
  local -r ca_cert_file="$5"
  local -r client_cert_file="$6"
  local -r client_key_file="$7"
  local -r auth_mount_path="$8"
  local -r auth_type="$9"
  local -r auth_role="${10}"

  local -r config_path="$config_dir/$VAULT_CONFIG_FILE"

  log_info "Creating default Vault Agent config file in $config_path"

  local -r pid_config="pid_file   = \"$data_dir/$VAULT_PID_FILE\""

  local ca_cert_config=""
  if [[ ! -z $ca_cert_file ]]; then
   ca_cert_config=$(cat <<EOF
  ca_cert = "$ca_cert_file"\n
EOF
)
  fi

  local client_cert_config=""
  if [[ ! -z $client_cert_file ]] && [[ ! -z $client_key_file ]]; then
   client_cert_config=$(cat <<EOF
  client_cert = "$client_cert_file"
  client_key = "$client_key_file"\n
EOF
)
  fi

  local -r vault_config=$(cat <<EOF
vault {
  address = "https://$vault_address:$vault_port"
$ca_cert_config
$client_cert_config
}\n
EOF
)

  local -r auto_auth_config=$(cat <<EOF
auto_auth {
  method "aws" {
    mount_path = "$auth_mount_path"
    config = {
      type = "$auth_type"
      role = "$auth_role"
    }
  }
  sink "file" {
    config = {
      path = "$data_dir/$VAULT_TOKEN_FILE"
    }
  }
}\n
EOF
)
  echo -e "$pid_config" > "$config_path"
  echo -e "$vault_config" >> "$config_path"
  echo -e "$auto_auth_config" >> "$config_path"

  chown "$user:$user" "$config_path"
}

function generate_vault_config {
  local -r tls_cert_file="$1"
  local -r tls_key_file="$2"
  local -r port="$3"
  local -r cluster_port="$4"
  local -r api_addr="$5"
  local -r config_dir="$6"
  local -r user="$7"
  local -r enable_s3_backend="$8"
  local -r s3_bucket="$9"
  local -r s3_bucket_path="${10}"
  local -r s3_bucket_region="${11}"
  local -r consul_agent_service_registration_address="${12}"
  local -r enable_dynamo_backend="${13}"
  local -r dynamo_region="${14}"
  local -r dynamo_table="${15}"
  local -r enable_auto_unseal="${16}"
  local -r auto_unseal_kms_key_id="${17}"
  local -r auto_unseal_kms_key_region="${18}"
  local -r auto_unseal_endpoint="${19}"
  local -r config_path="$config_dir/$VAULT_CONFIG_FILE"

  local instance_ip_address
  instance_ip_address=$(get_instance_ip_address)

  local auto_unseal_config=""
  if [[ "$enable_auto_unseal" == "true" ]]; then

    local endpoint=""
    if [[ -n "$auto_unseal_endpoint" ]]; then
      endpoint="endpoint   = \"$auto_unseal_endpoint\""
    fi

    auto_unseal_config=$(cat <<EOF
seal "awskms" {
  kms_key_id = "$auto_unseal_kms_key_id"
  region     = "$auto_unseal_kms_key_region"
  $endpoint
}\n
EOF
)
  fi

  log_info "Creating default Vault config file in $config_path"
  local -r ui_config=$(cat <<EOF
ui = true
EOF
)

  local -r listener_config=$(cat <<EOF
listener "tcp" {
  address         = "0.0.0.0:$port"
  cluster_address = "0.0.0.0:$cluster_port"
  tls_cert_file   = "$tls_cert_file"
  tls_key_file    = "$tls_key_file"
}\n
EOF
)

  local consul_storage_type="storage"
  local dynamodb_storage_type="storage"
  local s3_config=""
  local vault_storage_backend=""
  local service_registration=""
  if [[ "$enable_s3_backend" == "true" ]]; then
    s3_config=$(cat <<EOF
storage "s3" {
  bucket = "$s3_bucket"
  path   = "$s3_bucket_path"
  region = "$s3_bucket_region"
}\n
EOF
)
    consul_storage_type="ha_storage"
    dynamodb_storage_type="ha_storage"
    service_registration=$(cat <<EOF
service_registration "consul" {
  address = "${consul_agent_service_registration_address}"
}\n
EOF
)
  fi

  if [[ "$enable_dynamo_backend" == "true" ]]; then
    vault_storage_backend=$(cat <<EOF
$dynamodb_storage_type "dynamodb" {
  ha_enabled = "true"
  region = "$dynamo_region"
  table  = "$dynamo_table"
}
# HA settings
cluster_addr  = "https://$instance_ip_address:$cluster_port"
api_addr      = "$api_addr"
EOF
)
  else
    vault_storage_backend=$(cat <<EOF
$consul_storage_type "consul" {
  address = "127.0.0.1:8500"
  path    = "vault/"
  scheme  = "http"
  service = "vault"
}
# HA settings
cluster_addr  = "https://$instance_ip_address:$cluster_port"
api_addr      = "$api_addr"
EOF
)
  fi

  vault_version_at_least "$config_path" "$ui_config"

  echo -e "$auto_unseal_config" >> "$config_path"
  echo -e "$listener_config" >> "$config_path"
  echo -e "$s3_config" >> "$config_path"
  echo -e "$vault_storage_backend" >> "$config_path"
  echo -e "$service_registration" >> "$config_path"

  chown "$user:$user" "$config_path"
}

function generate_systemd_config {
  local -r systemd_config_path="$1"
  local -r vault_config_dir="$2"
  local -r vault_bin_dir="$3"
  local -r vault_log_level="$4"
  local -r vault_systemd_stdout="$5"
  local -r vault_systemd_stderr="$6"
  local -r vault_user="$7"
  local -r is_vault_agent="$8"
  local -r config_path="$config_dir/$VAULT_CONFIG_FILE"

  local vault_description="HashiCorp Vault - A tool for managing secrets"
  local vault_command="server"
  local vault_config_file_or_dir="$vault_config_dir"  # Vault agent requires single file, but server can accept config dir.
  if [[ "$is_vault_agent" == "true" ]]; then
    vault_command="agent"
    vault_description="HashiCorp Vault Agent"
    vault_config_file_or_dir="$config_path"
  fi

  log_info "Creating systemd config file to run Vault in $systemd_config_path"

  local -r unit_config=$(cat <<EOF
[Unit]
Description=\"$vault_description\"
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=$config_path
StartLimitIntervalSec=60
StartLimitBurst=3
EOF
)

  local -r service_config=$(cat <<EOF
[Service]
User=$vault_user
Group=$vault_user
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
Capabilities=CAP_IPC_LOCK+ep
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=$vault_bin_dir/vault $vault_command -config $vault_config_file_or_dir -log-level=$vault_log_level
ExecReload=/bin/kill --signal HUP \$MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
StartLimitInterval=60
StartLimitIntervalSec=60
StartLimitBurst=3
LimitNOFILE=65536
LimitMEMLOCK=infinity
EOF
)

  local log_config=""
  if [[ ! -z $vault_systemd_stdout ]]; then
    log_config+="StandardOutput=$vault_systemd_stdout\n"
  fi
  if [[ ! -z $vault_systemd_stderr ]]; then
    log_config+="StandardError=$vault_systemd_stderr\n"
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

function start_vault {
  log_info "Reloading systemd config and starting Vault"
  sudo systemctl daemon-reload
  sudo systemctl enable vault.service
  sudo systemctl restart vault.service
}

# Based on: http://unix.stackexchange.com/a/7732/215969
function get_owner_of_path {
  local -r path="$1"
  ls -ld "$path" | awk '{print $3}'
}

function run {
  local tls_cert_file=""
  local tls_key_file=""
  local port="$DEFAULT_PORT"
  local cluster_port=""
  local api_addr=""
  local config_dir=""
  local bin_dir=""
  local data_dir=""
  local log_level="$DEFAULT_LOG_LEVEL"
  local systemd_stdout=""
  local systemd_stderr=""
  local user=""
  local skip_vault_config="false"
  local enable_s3_backend="false"
  local s3_bucket=""
  local s3_bucket_path=""
  local s3_bucket_region=""
  local consul_agent_service_registration_address="${DEFAULT_CONSUL_AGENT_SERVICE_REGISTRATION_ADDRESS}"
  local enable_dynamo_backend="false"
  local dynamo_region=""
  local dynamo_table=""
  local agent="false"
  local agent_vault_address="$DEFAULT_AGENT_VAULT_ADDRESS"
  local agent_vault_port="$DEFAULT_PORT"
  local agent_ca_cert_file=""
  local agent_client_cert_file=""
  local agent_client_key_file=""
  local agent_auth_mount_path="$DEFAULT_AGENT_AUTH_MOUNT_PATH"
  local agent_auth_type=""
  local agent_auth_role=""
  local enable_auto_unseal="false"
  local auto_unseal_kms_key_id=""
  local auto_unseal_kms_key_region=""
  local auto_unseal_endpoint=""
  local all_args=()

  while [[ $# > 0 ]]; do
    local key="$1"

    case "$key" in
      --tls-cert-file)
        tls_cert_file="$2"
        shift
        ;;
      --tls-key-file)
        tls_key_file="$2"
        shift
        ;;
      --port)
        assert_not_empty "$key" "$2"
        port="$2"
        shift
        ;;
      --cluster-port)
        assert_not_empty "$key" "$2"
        cluster_port="$2"
        shift
        ;;
      --config-dir)
        assert_not_empty "$key" "$2"
        config_dir="$2"
        shift
        ;;
       --api-addr)
        assert_not_empty "$key" "$2"
        api_addr="$2"
        shift
        ;;
      --bin-dir)
        assert_not_empty "$key" "$2"
        bin_dir="$2"
        shift
        ;;
      --data-dir)
        assert_not_empty "$key" "$2"
        data_dir="$2"
        shift
        ;;
      --log-level)
        assert_not_empty "$key" "$2"
        log_level="$2"
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
      --skip-vault-config)
        skip_vault_config="true"
        ;;
      --enable-s3-backend)
        enable_s3_backend="true"
        ;;
      --s3-bucket)
        s3_bucket="$2"
        shift
        ;;
      --s3-bucket-path)
        s3_bucket_path="$2"
        shift
        ;;
      --s3-bucket-region)
        s3_bucket_region="$2"
        shift
        ;;
      --consul-agent-service-registration-address)
        assert_not_empty "$key" "$2"
        consul_agent_service_registration_address="$2"
        shift
        ;;
      --enable-dynamo-backend)
        enable_dynamo_backend="true"
        ;;
      --dynamo-region)
        dynamo_region="$2"
        shift
        ;;
      --dynamo-table)
        dynamo_table="$2"
        shift
        ;;
      --agent)
        agent="true"
        ;;
      --agent-vault-address)
        assert_not_empty "$key" "$2"
        agent_vault_address="$2"
        shift
        ;;
      --agent-vault-port)
        assert_not_empty "$key" "$2"
        agent_vault_port="$2"
        shift
        ;;
      --agent-ca-cert-file)
        assert_not_empty "$key" "$2"
        agent_ca_cert_file="$2"
        shift
        ;;
      --agent-client-cert-file)
        assert_not_empty "$key" "$2"
        agent_client_cert_file="$2"
        shift
        ;;
      --agent-client-key-file)
        assert_not_empty "$key" "$2"
        agent_client_key_file="$2"
        shift
        ;;
      --agent-auth-mount-path)
        assert_not_empty "$key" "$2"
        agent_auth_mount_path="$2"
        shift
        ;;
      --agent-auth-type)
        agent_auth_type="$2"
        shift
        ;;
      --agent-auth-role)
        agent_auth_role="$2"
        shift
        ;;
      --enable-auto-unseal)
        enable_auto_unseal="true"
        ;;
      --auto-unseal-kms-key-id)
        auto_unseal_kms_key_id="$2"
        shift
        ;;
      --auto-unseal-kms-key-region)
        auto_unseal_kms_key_region="$2"
        shift
        ;;
      --auto-unseal-endpoint)
        auto_unseal_endpoint="$2"
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

  # Required flags
  if [[ "$agent" == "true" ]]; then
    assert_not_empty "--agent-auth-type" "$agent_auth_type"
    assert_not_empty "--agent-auth-role" "$agent_auth_role"
  else
    assert_not_empty "--tls-cert-file" "$tls_cert_file"
    assert_not_empty "--tls-key-file" "$tls_key_file"

    if [[ "$enable_s3_backend" == "true" ]]; then
      assert_not_empty "--s3-bucket" "$s3_bucket"
      assert_not_empty "--s3-bucket-region" "$s3_bucket_region"
      assert_not_empty "--consul-agent-service-registration-address" "${consul_agent_service_registration_address}"
    fi
  fi

  if [[ "$enable_dynamo_backend" == "true" ]]; then
    assert_not_empty "--dynamo-table" "$dynamo_table"
    assert_not_empty "--dynamo-region" "$dynamo_region"
  fi

  assert_is_installed "systemctl"
  assert_is_installed "curl"
  assert_is_installed "jq"

  if [[ -z "$config_dir" ]]; then
    config_dir=$(cd "$SCRIPT_DIR/../config" && pwd)
  fi

  # If $systemd_stdout and/or $systemd_stderr are empty, we leave them empty so that generate_systemd_config will use systemd's defaults (journal and inherit, respectively)

  if [[ -z "$bin_dir" ]]; then
    bin_dir=$(cd "$SCRIPT_DIR/../bin" && pwd)
  fi

  if [[ -z "$data_dir" ]]; then
    data_dir=$(cd "$SCRIPT_DIR/../data" && pwd)
  fi

  if [[ -z "$user" ]]; then
    user=$(get_owner_of_path "$config_dir")
  fi

  if [[ -z "$cluster_port" ]]; then
    cluster_port=$(( $port + 1 ))
  fi

  if [[ -z "$api_addr" ]]; then
    api_addr="https://$(get_instance_ip_address):${port}"
  fi

  if [[ "$agent" == "false" ]] && [[ "$enable_auto_unseal" == "true" ]]; then
    log_info "The --enable-auto-unseal flag is set to true"
    assert_not_empty "--auto-unseal-kms-key-id" "$auto_unseal_kms_key_id"
    assert_not_empty "--auto-unseal-kms-key-region" "$auto_unseal_kms_key_region"
  fi

  if [[ "$skip_vault_config" == "true" ]]; then
    log_info "The --skip-vault-config flag is set, so will not generate a default Vault config file."
  else
    if [[ "$agent" == "true" ]]; then
      log_info "Running as Vault agent (--agent flag is set)"
      generate_vault_agent_config \
        "$config_dir" \
        "$data_dir" \
        "$agent_vault_address" \
        "$agent_vault_port" \
        "$agent_ca_cert_file" \
        "$agent_client_cert_file" \
        "$agent_client_key_file" \
        "$agent_auth_mount_path" \
        "$agent_auth_type" \
        "$agent_auth_role"
    else
      log_info "Running as Vault server"
      generate_vault_config \
        "$tls_cert_file" \
        "$tls_key_file" \
        "$port" \
        "$cluster_port" \
        "$api_addr" \
        "$config_dir" \
        "$user" \
        "$enable_s3_backend" \
        "$s3_bucket" \
        "$s3_bucket_path" \
        "$s3_bucket_region" \
        "${consul_agent_service_registration_address}" \
        "$enable_dynamo_backend" \
        "$dynamo_region" \
        "$dynamo_table" \
        "$enable_auto_unseal" \
        "$auto_unseal_kms_key_id" \
        "$auto_unseal_kms_key_region" \
        "$auto_unseal_endpoint"
    fi
  fi

  generate_systemd_config "$SYSTEMD_CONFIG_PATH" "$config_dir" "$bin_dir" "$log_level" "$systemd_stdout" "$systemd_stderr" "$user" "$agent"
  start_vault
}

run "$@"
EOCONSUL

chmod a+x /opt/vault/bin/run-vault
