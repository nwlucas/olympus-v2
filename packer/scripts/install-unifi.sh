#!/bin/bash -eux

UNIFI_VERSION=${UNIFI_VERSION:-6.2.26}

readonly DEFAULT_INSTALL_PATH="/opt/unifi"
readonly DEFAULT_REPO="https://www.ui.com/downloads/unifi/debian stable ubiquiti"
readonly DEFAULT_REPO_KEY_URL="https://dl.ui.com/unifi"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SYSTEM_BIN_DIR="/usr/local/bin"

readonly SCRIPT_NAME="$(basename "$0")"

function print_usage {
  echo
  echo "Usage: install-unifi [OPTIONS]"
  echo
  echo "This script can be used to install unifi and its dependencies. This script has been tested with Ubuntu 16.04/18.04/20.04 and Amazon Linux 2."
  echo
  echo "Options:"
  echo
  echo -e "  --version\t\tThe version of unifi to install. Optional if download-url is provided."
  echo -e "  --path\t\tThe path where unifi should be installed. Optional. Default: $DEFAULT_INSTALL_PATH."
  echo -e "  --user\t\tThe user who will own the unifi install directories. Optional. Default: $DEFAULT_UNIFI_USER."
  echo
  echo "Example:"
  echo
  echo "  install-unifi --version 1.2.2"
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
    sudo apt-get install -y gnupg haveged openjdk-8-jdk ca-certificates apt-transport-https net-tools jq
  elif has_yum; then
    sudo yum update -y
    sudo yum install -y gnupg haveged openjdk-8-jdk ca-certificates apt-transport-https net-tools jq
  else
    log_error "Could not find apt-get or yum. Cannot install dependencies on this OS."
    exit 1
  fi
}

function fetch_binary {
  local readonly version="$1"

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
    # The following info is taken from https://www.unifi.io/downloads
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
    log_error "CPU architecture $cpu_arch is not a supported by unifi."
    exit 1
    ;;
  esac

  curl ${DEFAULT_REPO_KEY_URL}/unifi-repo.gpg --output /usr/share/keyrings/unifi-repo.gpg
  echo "deb [signed-by=/usr/share/keyrings/unifi-repo.gpg] ${DEFAULT_REPO}" >/etc/apt/sources.list.d/100-unifios.list
  apt update -qq
  apt install -y -qq unifi
}

function install {
  local version=${UNIFI_VERSION}

  while [[ $# -gt 0 ]]; do
    local key="$1"

    case "$key" in
    --version)
      version="$2"
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

  # assert_not_empty "--version" "$version"

  log_info "Starting unifi install"

  install_dependencies

  fetch_binary "$version"

}

install "$@"
