#!/bin/bash -eux

mkdir -p /etc/ansible
mkdir -p /opt/ansible/roles
mkdir -p /opt/ansible/modules
mkdir -p /opt/ansible/collections

echo "Placing ansible config"
cat <<EOF >/etc/ansible/ansible.cfg
[defaults]

# some basic default values...
interpreter_python = auto_silent
#inventory      = ./hosts
library        = /opt/ansible/modules
#module_utils   = /usr/share/my_module_utils/
#remote_tmp     = ~/.ansible/tmp
#local_tmp      = ~/.ansible/tmp
#plugin_filters_cfg = /etc/ansible/plugin_filters.yml
#forks          = 5
#poll_interval  = 15
#sudo_user      = root
#ask_sudo_pass = True
#ask_pass      = True
transport      = smart
#remote_port    = 22
#module_lang    = C
#module_set_locale = False

gathering = implicit
#gather_subset = all
# gather_timeout = 10
inject_facts_as_vars = False
roles_path    = /opt/ansible/roles
collections_paths = /opt/ansible/collections
#host_key_checking = False
#stdout_callback = skippy
#callback_whitelist = timer, mail
#task_includes_static = False
#handler_includes_static = False
#error_on_missing_handler = True
#sudo_exe = sudo
#sudo_flags = -H -S -n
#timeout = 10
#remote_user = root
#log_path = /var/log/ansible.log
#module_name = command
#executable = /bin/sh
#hash_behaviour = replace
#private_role_vars = yes
#jinja2_extensions = jinja2.ext.do,jinja2.ext.i18n
#private_key_file = /path/to/file
vault_password_file = /opt/ansible/.vault
ansible_managed = Ansible managed
#display_skipped_hosts = True
#display_args_to_stdout = False
#error_on_undefined_vars = False
#system_warnings = True
deprecation_warnings = False
# command_warnings = False


# set plugin path directories here, separate with colons
#action_plugins     = /usr/share/ansible/plugins/action
#become_plugins     = /usr/share/ansible/plugins/become
#cache_plugins      = /usr/share/ansible/plugins/cache
#callback_plugins   = /usr/share/ansible/plugins/callback
#connection_plugins = /usr/share/ansible/plugins/connection
#lookup_plugins     = /usr/share/ansible/plugins/lookup
#inventory_plugins  = /usr/share/ansible/plugins/inventory
#vars_plugins       = /usr/share/ansible/plugins/vars
#filter_plugins     = /usr/share/ansible/plugins/filter
#test_plugins       = /usr/share/ansible/plugins/test
#terminal_plugins   = /usr/share/ansible/plugins/terminal
#strategy_plugins   = /usr/share/ansible/plugins/strategy

#strategy = free
#bin_ansible_callbacks = False
nocows = 1
#cow_selection = default
#cow_selection = random
#cow_whitelist=bud-frogs,bunny,cheese,daemon,default,dragon,elephant-in-snake,elephant,eyes,\
#              hellokitty,kitty,luke-koala,meow,milk,moofasa,moose,ren,sheep,small,stegosaurus,\
#              stimpy,supermilker,three-eyes,turkey,turtle,tux,udder,vader-koala,vader,www
nocolor = 1
#fact_caching = memory
#fact_caching_connection=/tmp
#retry_files_enabled = False
#retry_files_save_path = ~/.ansible-retry
#squash_actions = apk,apt,dnf,homebrew,pacman,pkgng,yum,zypper
#no_log = False
#no_target_syslog = False
#allow_world_readable_tmpfiles = False
#var_compression_level = 9
#module_compression = 'ZIP_DEFLATED'
#max_diff_size = 1048576
#merge_multiple_cli_flags = True
#show_custom_stats = True
#inventory_ignore_extensions = ~, .orig, .bak, .ini, .cfg, .retry, .pyc, .pyo
#network_group_modules=eos, nxos, ios, iosxr, junos, vyos
#allow_unsafe_lookups = False
#any_errors_fatal = False

[inventory]
enable_plugins = community.vmware.vmware_vm_inventory, community.kubernetes.k8s, community.digitalocean
#ignore_extensions = .pyc, .pyo, .swp, .bak, ~, .rpm, .md, .txt, ~, .orig, .ini, .cfg, .retry
#ignore_patterns=
#unparsed_is_failed=False

[privilege_escalation]
#become=True
#become_method=sudo
#become_user=root
#become_ask_pass=False

[paramiko_connection]
#record_host_keys=False
#pty=False
#look_for_keys = False
#host_key_auto_add = True

[ssh_connection]
#ssh_args = -C -o ControlMaster=auto -o ControlPersist=60s
#control_path_dir = ~/.ansible/cp
#control_path =
#pipelining = False
#scp_if_ssh = smart
#transfer_method = smart
#sftp_batch_mode = False
#usetty = True
#retries = 3

[persistent_connection]
#connect_timeout = 30
#command_timeout = 30

[accelerate]
#accelerate_port = 5099
#accelerate_timeout = 30
#accelerate_connect_timeout = 5.0
#accelerate_daemon_timeout = 30
#accelerate_multi_key = yes

[selinux]
#special_context_filesystems=nfs,vboxsf,fuse,ramfs,9p,vfat
#libvirt_lxc_noseclabel = yes

[colors]
#highlight = white
#verbose = blue
#warn = bright purple
#error = red
#debug = dark gray
#deprecate = purple
#skip = cyan
#unreachable = red
#ok = green
#changed = yellow
#diff_add = green
#diff_remove = red
#diff_lines = cyan


[diff]
always = yes
context = 3
EOF

if [[ "${BUILD_TYPE}" = "K8S" ]]; then
  ansible-galaxy collection install -p /opt/ansible/collections community.kubernetes
  ansible-galaxy collection install -p /opt/ansible/collections community.vmware
elif [[ "${BUILD_TYPE}" = "UNIFI" || "${BUILD_TYPE}" = "NOMAD_CONSUL" ]]; then
  ansible-galaxy collection install -p /opt/ansible/collections community.digitalocean
fi
ansible-galaxy collection install -p /opt/ansible/collections community.general
