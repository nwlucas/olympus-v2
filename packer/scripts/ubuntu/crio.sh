#!/bin/sh -eux

. /etc/os-release

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/kubic-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/x${NAME}_${VERSION_ID}/ /" >/etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/crio-o-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/${CRIO_VERSION}/x${NAME}_${VERSION_ID}/ /" >/etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION.list
curl --no-progress-meter -L https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:${CRIO_VERSION}/x${NAME}_${VERSION_ID}/Release.key | gpg --dearmor >/usr/share/keyrings/crio-o-archive-keyring.gpg
curl --no-progress-meter -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/x${NAME}_${VERSION_ID}/Release.key | gpg --dearmor >/usr/share/keyrings/kubic-archive-keyring.gpg
apt-get update -qq
apt-get install -qq -y podman-rootless cri-o cri-o-runc cri-tools

cat >/etc/crio/crio.conf <<EOF
[crio]
#root = "/var/lib/containers/storage"
#runroot = "/var/run/containers/storage"
#storage_driver = "btrfs"
#storage_option = [
#]
log_dir = "/var/log/crio/pods"
version_file = "/var/run/crio/version"
version_file_persist = "/var/lib/crio/version"

[crio.api]
listen = "/var/run/crio/crio.sock"
stream_address = "127.0.0.1"
stream_port = "0"
stream_enable_tls = false
stream_tls_cert = ""
stream_tls_key = ""
stream_tls_ca = ""
grpc_max_send_msg_size = 16777216
grpc_max_recv_msg_size = 16777216

[crio.runtime]
#default_ulimits = [
#]
no_pivot = false
decryption_keys_path = "/etc/crio/keys/"
conmon = ""
conmon_cgroup = "system.slice"
conmon_env = [
	"PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
]
default_env = [
]
selinux = false
seccomp_profile = ""
seccomp_use_default_when_empty = false
apparmor_profile = "crio-default"
cgroup_manager = "systemd"
separate_pull_cgroup = ""
default_capabilities = [
	"CHOWN",
	"DAC_OVERRIDE",
	"FSETID",
	"FOWNER",
	"SETGID",
	"SETUID",
	"SETPCAP",
	"NET_BIND_SERVICE",
	"KILL",
]
default_sysctls = [
]
additional_devices = [
]
hooks_dir = [
	"/usr/share/containers/oci/hooks.d",
]
#default_mounts_file = ""
pids_limit = 1024
log_size_max = -1
log_to_journald = false
container_exits_dir = "/var/run/crio/exits"
container_attach_socket_dir = "/var/run/crio"
bind_mount_prefix = ""
read_only = false
log_level = "info"
log_filter = ""
uid_mappings = ""
gid_mappings = ""
ctr_stop_timeout = 30
manage_ns_lifecycle = true
drop_infra_ctr = false
namespaces_dir = "/var/run"
pinns_path = ""
default_runtime = "runc"
#[crio.runtime.runtimes.runtime-handler]
#  runtime_path = "/path/to/the/executable"
#  runtime_type = "oci"
#  runtime_root = "/path/to/the/root"
#  privileged_without_host_devices = false
#  allowed_annotations = []
# Where:
# - runtime-handler: name used to identify the runtime
# - runtime_path (optional, string): absolute path to the runtime executable in
#   the host filesystem. If omitted, the runtime-handler identifier should match
#   the runtime executable name, and the runtime executable should be placed
#   in $PATH.
# - runtime_type (optional, string): type of runtime, one of: "oci", "vm". If
#   omitted, an "oci" runtime is assumed.
# - runtime_root (optional, string): root directory for storage of containers
#   state.
# - privileged_without_host_devices (optional, bool): an option for restricting
#   host devices from being passed to privileged containers.
# - allowed_annotations (optional, array of strings): an option for specifying
#   a list of experimental annotations that this runtime handler is allowed to process.
#   The currently recognized values are:
#   "io.kubernetes.cri-o.userns-mode" for configuring a user namespace for the pod.
#   "io.kubernetes.cri-o.Devices" for configuring devices for the pod.
#   "io.kubernetes.cri-o.ShmSize" for configuring the size of /dev/shm.

[crio.runtime.runtimes.runc]
runtime_path = ""
runtime_type = "oci"
runtime_root = "/run/runc"

# crun is a fast and lightweight fully featured OCI runtime and C library for
# running containers
#[crio.runtime.runtimes.crun]

# Kata Containers is an OCI runtime, where containers are run inside lightweight
# VMs. Kata provides additional isolation towards the host, minimizing the host attack
# surface and mitigating the consequences of containers breakout.

# Kata Containers with the default configured VMM
#[crio.runtime.runtimes.kata-runtime]

# Kata Containers with the QEMU VMM
#[crio.runtime.runtimes.kata-qemu]

# Kata Containers with the Firecracker VMM
#[crio.runtime.runtimes.kata-fc]

[crio.image]
default_transport = "docker://"
global_auth_file = ""
pause_image = "k8s.gcr.io/pause:3.2"
pause_image_auth_file = ""
pause_command = "/pause"
signature_policy = ""
#insecure_registries = "[]"
image_volumes = "mkdir"
#registries = [
# ]
big_files_temporary_dir = ""

[crio.network]
# cni_default_network = ""
network_dir = "/etc/cni/net.d/"
plugin_dirs = [
	"/opt/cni/bin/",
  "/usr/libexec/cni"
]

[crio.metrics]
enable_metrics = false
metrics_port = 9090
metrics_socket = ""
EOF

cat >/etc/containers/storage.conf <<EOF
[storage]

driver = "overlay"
runroot = "/run/containers/storage"
graphroot = "/var/lib/containers/storage"
# rootless_storage_path = "$HOME/.local/share/containers/storage"

[storage.options]
additionalimagestores = [
]
# remap-uids = 0:1668442479:65536
# remap-gids = 0:1668442479:65536
# remap-user = "containers"
# remap-group = "containers"
# root-auto-userns-user = "storage"
# auto-userns-min-size=1024
# auto-userns-max-size=65536

[storage.options.overlay]
#ignore_chown_errors = "false"
#mount_program = "/usr/bin/fuse-overlayfs"
mountopt = "nodev"
# skip_mount_home = "false"
# size = ""
# force_mask = ""

[storage.options.thinpool]
# autoextend_percent = "20"
# autoextend_threshold = "80"
# basesize = "10G"
# blocksize="64k"
# directlvm_device = ""
# directlvm_device_force = "True"
# fs="xfs"
# log_level = "7"
# min_free_space = "10%"
# mkfsarg = ""
# metadata_size = ""
# size = ""
# use_deferred_removal = "True"
# use_deferred_deletion = "True"
# xfs_nospace_max_retries = "0"
EOF

systemctl daemon-reload
systemctl enable crio
