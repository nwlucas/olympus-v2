#!/bin/sh -eux

echo "remove linux-headers"
dpkg --list |
  awk '{ print $2 }' |
  grep 'linux-headers' |
  xargs apt-get -qq -y purge

echo "remove specific Linux kernels, such as linux-image-3.11.0-15-generic but keeps the current kernel and does not touch the virtual packages"
dpkg --list |
  awk '{ print $2 }' |
  grep 'linux-image-.*-generic' |
  grep -v $(uname -r) |
  xargs apt-get -qq -y purge

echo "remove old kernel modules packages"
dpkg --list |
  awk '{ print $2 }' |
  grep 'linux-modules-.*-generic' |
  grep -v $(uname -r) |
  xargs apt-get -qq -y purge

echo "remove linux-source package"
dpkg --list |
  awk '{ print $2 }' |
  grep linux-source |
  xargs apt-get -qq -y purge

echo "remove all development packages"
dpkg --list |
  awk '{ print $2 }' |
  grep -- '-dev\(:[a-z0-9]\+\)\?$' |
  xargs apt-get -qq -y purge

echo "remove docs packages"
dpkg --list |
  awk '{ print $2 }' |
  grep -- '-doc$' |
  xargs apt-get -qq -y purge

echo "remove X11 libraries"
apt-get -qq -y purge libx11-data xauth libxmuu1 libxcb1 libx11-6 libxext6

echo "remove obsolete networking packages"
apt-get -qq -y purge ppp pppconfig pppoeconf

echo "remove packages we don't need"
apt-get -qq -y purge popularity-contest friendly-recovery bash-completion fonts-ubuntu-font-family-console laptop-detect motd-news-config usbutils grub-legacy-ec2

echo "remove the console font"
apt-get -qq -y purge fonts-ubuntu-console || true

echo "removing command-not-found-data"
# 19.10+ don't have this package so fail gracefully
apt-get -qq -y purge command-not-found-data || true

# Exclude the files we don't need w/o uninstalling linux-firmware
echo "Setup dpkg excludes for linux-firmware"
cat <<_EOF_ | cat >>/etc/dpkg/dpkg.cfg.d/excludes
#DTLR-BEGIN
path-exclude=/lib/firmware/*
path-exclude=/usr/share/doc/linux-firmware/*
#DTLR-END
_EOF_

echo "delete the massive firmware files"
rm -rf /lib/firmware/*
rm -rf /usr/share/doc/linux-firmware/*

echo "autoremoving packages and cleaning apt data"
apt-get -qq -y autoremove
apt-get -qq -y clean

echo "remove /usr/share/doc/"
rm -rf /usr/share/doc/*

echo "remove /var/cache"
find /var/cache -type f -exec rm -rf {} \;

echo "truncate any logs that have built up during the install"
find /var/log -type f -exec truncate --size=0 {} \;

echo "blank netplan machine-id (DUID) so machines get unique ID generated on boot"
truncate -s 0 /etc/machine-id

echo "remove the contents of /tmp and /var/tmp"
rm -rf /tmp/* /var/tmp/*

echo "force a new random seed to be generated"
rm -f /var/lib/systemd/random-seed

echo "clear the history so our install isn't there"
rm -f /root/.wget-hsts
export HISTSIZE=0

echo "nuke all cloud-init semaphore files to force cloud-init to re-run"
rm -Rf /var/lib/cloud/data/scripts \
  /var/lib/cloud/scripts/per-instance \
  /var/lib/cloud/data/user-data* \
  /var/lib/cloud/instance \
  /var/lib/cloud/instances/*

echo "force cloud-init to clean"
cloud-init clean --log

echo "removing tmp.conf"
rm /usr/lib/tmpfiles.d/tmp.conf
