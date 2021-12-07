#cloud-config
merge_how:
- name: list
  settings: [append]
- name: dict
  settings: [no_replace, recurse_list]
chpasswd:
  list: |
    ubuntu:${ ssh_password }
  expire: false
manage_etc_hosts: "template"
timezone: "America/New_York"
hostname: ${ instance_fqdn }
fqdn: ${ instance_fqdn }
package_update: true
package_upgrade: true
packages:
- cockpit
- ca-certificates
- apt-transport-https
- wget
- curl
- gnupg
- net-tools
- jq
- unzip
ssh_authorized_keys:
- ${ ssh_instance_key ~}
users:
- name: ubuntu
  shell: /bin/bash
  gecos: Ubuntu
  sudo: ALL=(ALL) NOPASSWD:ALL
  groups: [sudo, adm, audio, cdrom, dialout, floppy, video, plugdev, dip, netdev, ddclient]
  ssh_authorized_keys:
  - ${ ssh_instance_key ~}
write_files:
- content: ""
  path: /opt/bootstrap/.cloudcreate
  owner: root:root
  permissions: '0644'
- content: ""
  path: /opt/bin/.cloudcreate
  owner: root:root
  permissions: '0644'
- content: |
    [Unit]
    Description=Setup Network Environment
    Documentation=https://github.com/kelseyhightower/setup-network-environment
    Requires=systemd-networkd-wait-online.service
    After=systemd-networkd-wait-online.service

    [Service]
    ExecStartPre=-/usr/bin/mkdir -p /opt/bin
    ExecStartPre=/usr/bin/wget -N -P /opt/bin https://github.com/kelseyhightower/setup-network-environment/releases/download/1.0.1/setup-network-environment

    ExecStartPre=/usr/bin/chmod +x /opt/bin/setup-network-environment
    ExecStart=/opt/bin/setup-network-environment
    RemainAfterExit=yes
    Type=oneshot

    [Install]
    WantedBy=multi-user.target
  path: /etc/systemd/system/setup-network-environment.service
  owner: root:root
  permissions: '0600'
runcmd:
- [modprobe, br_netfilter]
- [systemctl, enable, setup-network-environment.service]
- [systemctl, start, setup-network-environment.service]
- [systemctl, enable, --now, cockpit.socket]
- [systemctl, stop, network-manager.service]
- [systemctl, disable, network-manager.service]
