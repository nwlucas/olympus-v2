#!/bin/sh -eux

. /etc/os-release

DDCLIENT_VERSION=${DDCLIENT_VERSION:-3.9.1}
GITHUB_URL=https://github.com/ddclient/ddclient/archive/

cd /tmp

curl --no-progress-meter -L ${GITHUB_URL}/v$DDCLIENT_VERSION.tar.gz -o ddclient-v$DDCLIENT_VERSION.tar.gz

tar xzvf ddclient-v$DDCLIENT_VERSION.tar.gz
rm ddclient-v$DDCLIENT_VERSION.tar.gz

cd ddclient-$DDCLIENT_VERSION
cp ddclient /usr/local/bin

which ddclient
cd /
rm -rf /tmp/ddclient-$DDCLIENT_VERSION

mkdir -p /var/cache/ddclient
mkdir -p /etc/ddclient

useradd -s /usr/sbin/nologin -r -M ddclient
chown ddclient /var/cache/ddclient -R
