#!/bin/sh -eux

# For Kubernetes in general
swapoff -a

swapon --show

# For cri-o
modprobe overlay
modprobe br_netfilter

cat >/etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system

cat >/etc/containers/registries.conf <<EOF
[registries.search]
registries = ['quay.io', 'docker.io']

[registries.insecure]
registries = []

[registries.block]
registries = []
EOF

mkdir -p \
  /etc/kubernetes/bootstrap-secrets \
  /etc/kubernetes/secrets \
  /etc/kubernetes/manifests \
  /opt/bootstrap/assets \
  /etc/ssl/etcd \
  /var/lib/kublet \
  /run/kubelet

# Removing these files to address issues that came up with pods being attached to teh wrong networks. This came about
# when debugging In cluster DNS resolution.
rm -rf /etc/cni/net.d/100-crio-bridge.conf
rm -rf /etc/cni/net.d/200-loopback.conf
rm -rf /etc/cni/net.d/87-podman-bridge.conflist

# Install Calicoctl binary for direct execution and also as a plugin of kubectl
curl --no-progress-meter -o calicoctl -L https://github.com/projectcalico/calicoctl/releases/download/v${CALICO_VERSION}/calicoctl
curl --no-progress-meter -o kubectl-calico -L https://github.com/projectcalico/calicoctl/releases/download/v${CALICO_VERSION}/calicoctl
chmod +x kubectl-calico
chmod +x calicoctl
mv calicoctl /usr/local/bin
mv kubectl-calico /usr/local/bin

cat >/etc/profile.d/packer_etcd.sh <<EOF
export ETCDCTL_API=3
export ETCDCTL_CACERT="/etc/kubernetes/bootstrap-secrets/etcd-client-ca.crt"
export ETCDCTL_CERT="/etc/kubernetes/bootstrap-secrets/etcd-client.crt"
export ETCDCTL_KEY="/etc/kubernetes/bootstrap-secrets/etcd-client.key"
EOF

cat >/etc/profile.d/packer_kubernetes.sh <<EOF
export KUBECONFIG="/etc/kubernetes/bootstrap-secrets/kubeconfig"
EOF
