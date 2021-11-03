#!/bin/sh -eux

ubuntu_version="$(lsb_release -r | awk '{print $2}')"
major_version="$(echo $ubuntu_version | awk -F. '{print $1}')"

if [ "$major_version" -ge "18" ]; then
  echo "Create netplan config for eth0"
  cat <<EOF >/etc/netplan/01-netcfg.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      match: {name: "eth0"}
      dhcp-identifier: mac
      dhcp4: true
      dhcp6: false
      accept-ra: false
      ipv6-privacy: false
EOF
else
  # Adding a 2 sec delay to the interface up, to make the dhclient happy
  echo "pre-up sleep 2" >>/etc/network/interfaces
  # Disable Predictable Network Interface names and use eth0
  sed -i 's/en[[:alnum:]]*/eth0/g' /etc/network/interfaces
fi

sed -i 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0 \1"/g' /etc/default/grub
update-grub

echo "Disabling IPv6"
cat <<EOF >/etc/sysctl.d/10-disable-ipv6.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF

sysctl --system
