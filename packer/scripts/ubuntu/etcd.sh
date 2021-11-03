#!/bin/sh -eux

ETCD_VERSION=${ETCD_VERSION:-v3.4.15}
GOOGLE_URL=https://storage.googleapis.com/etcd
GITHUB_URL=https://github.com/etcd-io/etcd/releases/download
DOWNLOAD_URL=${GITHUB_URL}

curl --no-progress-meter -L ${DOWNLOAD_URL}/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-amd64.tar.gz -o etcd-${ETCD_VERSION}-linux-amd64.tar.gz

tar xzvf etcd-${ETCD_VERSION}-linux-amd64.tar.gz
rm etcd-${ETCD_VERSION}-linux-amd64.tar.gz

cd etcd-${ETCD_VERSION}-linux-amd64
cp etcd /usr/local/bin/
cp etcdctl /usr/local/bin/

rm -rf etcd-${ETCD_VERSION}-linux-amd64

etcd --version
etcdctl version

groupadd --system etcd
useradd -s /sbin/nologin --system -g etcd etcd
mkdir /var/lib/etcd
chown -R etcd:etcd /var/lib/etcd/

cat >/etc/systemd/system/etcd-member.service <<EOF
[Unit]
Description=etcd key-value store
Documentation=https://github.com/etcd-io/etcd
After=network.target

[Service]
User=etcd
Type=notify
Environment=ETCD_DATA_DIR=/var/lib/etcd
ExecStart=/usr/local/bin/etcd
Restart=always
RestartSec=10s
LimitNOFILE=40000

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
