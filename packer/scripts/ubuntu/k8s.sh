#!/bin/sh -eux

echo 'deb http://apt.kubernetes.io/ kubernetes-xenial main' >/etc/apt/sources.list.d/kubernetes.list
curl --no-progress-meter -L https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
apt-get update -qq
apt-get install -qq -y kubelet="${K8S_VERSION}" kubectl="${K8S_VERSION}"

systemctl disable kubelet
