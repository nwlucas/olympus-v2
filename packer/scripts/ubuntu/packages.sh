#!/bin/sh -eux

ANSIBLE_VERSION=${ANSIBLE_VERSION:-3.4.0}

apt-get -qq install -y python-is-python3
apt-get -qq install -y python3-pip python3-testresources
apt-get -qq install -y jq

pip3 install --no-cache-dir --quiet --upgrade setuptools
pip3 install --no-cache-dir --quiet --upgrade ansible==${ANSIBLE_VERSION}
pip3 install --no-cache-dir --quiet --upgrade boto3
if [ "${BUILD_TYPE}" = "K8S" ]; then
  pip3 install --no-cache-dir --quiet --upgrade pyvmomi
  pip3 install --no-cache-dir --quiet --upgrade awscli
  pip3 install --no-cache-dir --quiet --upgrade git+https://github.com/vmware/vsphere-automation-sdk-python.git
fi
pip3 list
