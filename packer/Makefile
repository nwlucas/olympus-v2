SHELL=/bin/bash

# Check to see if the ssh keys are in the AWS bucket already
ssh_prv_exists :=$$(aws s3api head-object --bucket ${AWS_BUCKET} --key "ssh_keys/ssh_instance") || true
ssh_pub_exists :=$$(aws s3api head-object --bucket ${AWS_BUCKET} --key "ssh_keys/ssh_instance.pub") || true

govc_path := /${GOVC_DATACENTER}/vm

define govc_check
	govc about; \
	govc ls ${govc_path}
endef

EMPTY:=
SPACE:=$(EMPTY) $(EMPTY)
COMMA:=$(EMPTY),$(EMPTY)

ifeq (, $(shell which curl))
    $(error "No curl in $$PATH, please install")
endif

ifeq (, $(shell which packer))
    $(error "No packer in $$PATH, please install")
endif

ifeq (, $(shell which terraform))
    $(error "No terraform in $$PATH, please install")
endif

ifeq (, $(shell which aws))
    $(error "No aws-cli in $$PATH, please install")
endif

.PHONY: all rebuild
.ONESHELL:

all: build rebuild

env_check:
	@if [[ -z "$$GOVC_INSECURE" ]]; then echo "GOVC_INSECURE is unset"; exit 1; fi
	@if [[ -z "$$GOVC_HOST" ]]; then echo "GOVC_HOST is unset"; exit 1; fi
	@if [[ -z "$$GOVC_DATASTORE" ]]; then echo "GOVC_DATASTORE is unset"; exit 1; fi
	@if [[ -z "$$GOVC_NETWORK" ]]; then echo "GOVC_NETWORK is unset"; exit 1; fi
	@if [[ -z "$$GOVC_URL" ]]; then echo "GOVC_URL is unset"; exit 1; fi
	@if [[ -z "$$GOVC_USERNAME" ]]; then echo "GOVC_USERNAME is unset"; exit 1; fi
	@if [[ -z "$$GOVC_PASSWORD" ]]; then echo "GOVC_PASSWORD is unset"; exit 1; fi
	@if [[ -z "$$GOVC_INSECURE" ]]; then echo "GOVC_INSECURE is unset"; exit 1; fi
	@if [[ -z "$$PACKER_CACHE_DIR" ]]; then echo "PACKER_CACHE_DIR is unset"; exit 1; fi
	@if [[ -z "$$PKR_VAR_vcenter_user" ]]; then echo "PKR_VAR_vcenter_user is unset"; exit 1; fi
	@if [[ -z "$$PKR_VAR_vcenter_password" ]]; then echo "PKR_VAR_vcenter_password is unset"; exit 1; fi
	@if [[ -z "$$PKR_VAR_ssh_username" ]]; then echo "PKR_VAR_ssh_username is unset"; exit 1; fi
	@if [[ -z "$$PKR_VAR_ssh_password" ]]; then echo "PKR_VAR_ssh_password is unset"; exit 1; fi
	@if [[ -z "$$PKR_VAR_crio_version" ]]; then echo "PKR_VAR_crio_version is unset"; exit 1; fi
	@if [[ -z "$$PKR_VAR_etcd_version" ]]; then echo "PKR_VAR_etcd_version is unset"; exit 1; fi
	@if [[ -z "$$PKR_VAR_calico_version" ]]; then echo "PKR_VAR_calico_version is unset"; exit 1; fi
	@if [[ -z "$$PKR_VAR_k8s_version" ]]; then echo "PKR_VAR_k8s_version is unset"; exit 1; fi
	@if [[ -z "$$PKR_VAR_ddclient_version" ]]; then echo "PKR_VAR_ddclient_version is unset"; exit 1; fi
	@if [[ -z "$$AWS_DEFAULT_REGION" ]]; then echo "AWS_DEFAULT_REGION is unset"; exit 1; fi
	@if [[ -z "$$AWS_ACCESS_KEY_ID" ]]; then echo "AWS_ACCESS_KEY_ID is unset"; exit 1; fi
	@if [[ -z "$$AWS_SECRET_ACCESS_KEY" ]]; then echo "AWS_SECRET_ACCESS_KEY is unset"; exit 1; fi
	@if [[ -z "$$AWS_BUCKET" ]]; then echo "AWS_BUCKET is unset"; exit 1; fi
	@if [[ -z "$$VSPHERE_SERVER" ]]; then echo "VSPHERE_SERVER is unset"; exit 1; fi
	@if [[ -z "$$VSPHERE_USER" ]]; then echo "VSPHERE_USER is unset"; exit 1; fi
	@if [[ -z "$$VSPHERE_PASSWORD" ]]; then echo "VSPHERE_PASSWORD is unset"; exit 1; fi
	@if [[ -z "$$VSPHERE_ALLOW_UNVERIFIED_SSL" ]]; then echo "VSPHERE_ALLOW_UNVERIFIED_SSL is unset"; exit 1; fi
	@if [[ -z "$$CLOUDFLARE_ACCOUNT_ID" ]]; then echo "CLOUDFLARE_ACCOUNT_ID is unset"; exit 1; fi
	@if [[ -z "$$CLOUDFLARE_API_TOKEN" ]]; then echo "CLOUDFLARE_API_TOKEN is unset"; exit 1; fi

ssh_check: | env_check create_ssh_dir
	@echo "$@: Checking for ssh key in AWS...";

	@if [[ -z "${ssh_prv_exists}" ]] && [[ -z "${ssh_pub_exists}" ]]; then \
		echo "SSH Public & Private keys does not exist."; \
		echo "Generating keys..."; \
		ssh-keygen -q -o -a 100 -t ed25519 -C "automation@nwlnexus.net" -f "./ssh_keys/ssh_instance" -N ""; \
		echo "Uploading SSH keys to AWS S3..."; \
		for file in "./ssh_keys"/*; do \
			$$(aws s3 cp "./ssh_keys/${file##*/}" s3://"${AWS_BUCKET}"/ssh_keys/"${file##*}"); \
		done; \
	else \
		echo "SSH Public & Private keys do exist."; \
		aws s3 cp --quiet s3://"${AWS_BUCKET}"/ssh_keys/ssh_instance ./ssh_keys/; \
		aws s3 cp --quiet s3://"${AWS_BUCKET}"/ssh_keys/ssh_instance.pub ./ssh_keys/; \
		chmod 0400 ./ssh_keys/ssh_instance; \
		chmod 0400 ./ssh_keys/ssh_instance.pub; \
	fi

create_ssh_dir:
	@mkdir -p ssh_keys/tmp;

build: ubuntu windows

rebuild: clean build

ubuntu: ubuntu-2004-do ubuntu-2004-local ubuntu-2104-local

ubuntu-2004-do: ssh_check | env_check
	@echo "Preparing to build Ubuntu 20.04 Digital Ocean image..."
	@cd builds/linux/ubuntu-2004-do;
	@packer init .
	@packer build --timestamp-ui -force -var-file="../../../do-ubuntu-2004-general.pkrvars.hcl" .

ubuntu-2004-local: ssh_check | env_check
	@echo "Preparing to build Ubuntu 20.04 local image..."
	@$(call govc_check,$@)
	@cd builds/linux/ubuntu-2004-local;
	@packer build --timestamp-ui -force -var-file="../../../vsphere.pkrvars.hcl" .

ubuntu-2104-local: ssh_check | env_check
	@echo "Preparing to build Ubuntu 21.04 local image..."
	@cd builds/linux/ubuntu-2104-local;
	@packer build --timestamp-ui -force -var-file="../../../vsphere.pkrvars.hcl" .


windows: windows-2019 windows-2016

windows-2019:

windows-2016:


clean:
