SHELL=/bin/bash
.SHELL=SHELL=/bin/bash

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

.PHONY: all deploy
.ONESHELL:

all: deploy

env_check:
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
	@if [[ -z "$$TF_VAR_CF_ACCOUNT_ID" ]]; then echo "TF_VAR_CF_ACCOUNT_ID is unset"; exit 1; fi
	@if [[ -z "$$TF_VAR_AWS_ACCESS_KEY_ID" ]]; then echo "TF_VAR_AWS_ACCESS_KEY_ID is unset"; exit 1; fi
	@if [[ -z "$$TF_VAR_AWS_SECRET_ACCESS_KEY" ]]; then echo "TF_VAR_AWS_SECRET_ACCESS_KEY is unset"; exit 1; fi
	@if [[ -z "$$TF_VAR_AWS_BUCKET" ]]; then echo "TF_VAR_AWS_BUCKET is unset"; exit 1; fi
	@if [[ -z "$$TF_VAR_AWS_BUCKET_KEY" ]]; then echo "TF_VAR_AWS_BUCKET_KEY is unset"; exit 1; fi
	@if [[ -z "$$TF_VAR_LB_INSTANCES" ]]; then echo "TF_VAR_LB_INSTANCES is unset"; exit 1; fi
	@if [[ -z "$$TF_VAR_LB_TUNNEL_NAME" ]]; then echo "TF_VAR_LB_TUNNEL_NAME is unset"; exit 1; fi
	@if [[ -z "$$TF_VAR_LB_INSTANCE_TEMPLATE" ]]; then echo "TF_VAR_LB_INSTANCE_TEMPLATE is unset"; exit 1; fi
	@if [[ -z "$$TF_VAR_K8_INSTANCE_TEMPLATE" ]]; then echo "TF_VAR_K8_INSTANCE_TEMPLATE is unset"; exit 1; fi
	@if [[ -z "$$TF_VAR_K8_API_CNAME_TARGET" ]]; then echo "TF_VAR_K8_API_CNAME_TARGET is unset"; exit 1; fi
	@if [[ -z "$$TF_VAR_K8_VERSION" ]]; then echo "TF_VAR_K8_VERSION is unset"; exit 1; fi
	@if [[ -z "$$TF_VAR_COREDNS_VERSION" ]]; then echo "TF_VAR_COREDNS_VERSION is unset"; exit 1; fi
	@if [[ -z "$$TF_VAR_CALICO_VERSION" ]]; then echo "TF_VAR_CALICO_VERSION is unset"; exit 1; fi
	@if [[ -z "$$TF_VAR_SSH_PASSWORD" ]]; then echo "TF_VAR_SSH_PASSWORD is unset"; exit 1; fi
	@if [[ -z "$$GITLAB_TOKEN" ]]; then echo "GITLAB_TOKEN is unset"; exit 1; fi
	@if [[ -z "$$TF_VAR_ANSIBLE_VAULT_PASSWORD_FILE" ]]; then echo "TF_VAR_ANSIBLE_VAULT_PASSWORD_FILE is unset"; exit 1; fi
	@if [[ -z "$$TF_VAR_ANSIBLE_VAULT_PWD" ]]; then echo "TF_VAR_ANSIBLE_VAULT_PWD is unset"; exit 1; fi
	@if [[ -z "$$DIGITALOCEAN_TOKEN" ]]; then echo "DIGITALOCEAN_TOKEN is unset"; exit 1; fi

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

deploy-cloud: ssh_check deploy-do-nc deploy-do-unifi

deploy-infra: ssh_check deploy-oob-syncer deploy-front deploy-cluster

deploy-do-nc: | env_check
	@echo "$@: Preparing to deploy Nomad/Consul cluster...";

	@terraform -chdir=do-nomad-consul init -upgrade;
	@terraform validate;
	@-terraform -chdir=do-nomad-consul plan -compact-warnings -detailed-exitcode -var-file="../tfvars/do-nomad-consul.tfvars" -var-file="../tfvars/common/digitalocean.tfvars" -out=$@.plan; EXIT_CODE=$$?
	@if [[ $$EXIT_CODE -eq 2 ]]; then terraform -chdir=do-nomad-consul apply -auto-approve $@.plan; \
		elif [[ $$EXIT_CODE -eq 0 ]]; then echo "Nothing to do..."; terraform -chdir=do-nomad-consul output; \
		else echo "Error detected: $$EXIT_CODE..."; exit 1; \
	fi
	@$(RM) ./do-nomad-consul/$@.plan;

deploy-do-unifi: | env_check
	@echo "$@: Preparing to deploy Unifi Controller...";

	@terraform -chdir=do-unifi init -upgrade;
	@terraform validate;
	@-terraform -chdir=do-unifi plan -compact-warnings -detailed-exitcode -var-file="../tfvars/do-unifi.tfvars" -var-file="../tfvars/common/digitalocean.tfvars" -out=$@.plan; EXIT_CODE=$$?
	@if [[ $$EXIT_CODE -eq 2 ]]; then terraform -chdir=do-unifi apply -auto-approve $@.plan; \
		elif [[ $$EXIT_CODE -eq 0 ]]; then echo "Nothing to do..."; terraform -chdir=do-unifi output; \
		else echo "Error detected: $$EXIT_CODE..."; exit 1; \
	fi

deploy-oob-syncer: | env_check
	@echo "$@: Preparing to deploy OOB Syncer Repo...";

	@terraform -chdir=oob-syncer init -upgrade;
	@terraform validate;
	@-terraform -chdir=oob-syncer plan -compact-warnings -detailed-exitcode -var-file="../tfvars/oob-syncer.tfvars" -out=$@.plan; EXIT_CODE=$$?
	@if [[ $$EXIT_CODE -eq 2 ]]; then terraform -chdir=oob-syncer apply -auto-approve $@.plan; \
		elif [[ $$EXIT_CODE -eq 0 ]]; then echo "Nothing to do..."; terraform -chdir=oob-syncer output; \
		else echo "Error detected: $$EXIT_CODE..."; exit 1; \
	fi

deploy-front: | env_check
	@echo "$@: Preparing to deploy Front Loadbalancers...";

	@terraform -chdir=front-lbs init -upgrade;
	@terraform validate;
	@-terraform -chdir=front-lbs plan -compact-warnings -detailed-exitcode -var-file="../tfvars/front-lb.tfvars" -var-file="../tfvars/common/vsphere.tfvars" -out=$@.plan; EXIT_CODE=$$?
	@if [[ $$EXIT_CODE -eq 2 ]]; then terraform -chdir=front-lbs apply -auto-approve $@.plan; \
		elif [[ $$EXIT_CODE -eq 0 ]]; then echo "Nothing to do..."; terraform -chdir=front-lbs output; \
		else echo "Error detected: $$EXIT_CODE..."; exit 1; \
	fi

deploy-cluster: | env_check
	@echo "$@: Preparing to deploy K8 cluster...";

	@terraform -chdir=k8s-cluster init -upgrade;
	@terraform validate;
	@-terraform -chdir=k8s-cluster plan -compact-warnings -detailed-exitcode -var-file="../tfvars/k8-cluster.tfvars" -var-file="../tfvars/common/vsphere.tfvars" -out=$@.plan; EXIT_CODE=$$?
	@if [[ $$EXIT_CODE -eq 2 ]]; then terraform -chdir=k8s-cluster apply -auto-approve $@.plan; \
		elif [[ $$EXIT_CODE -eq 0 ]]; then echo "Nothing to do..."; terraform -chdir=k8s-cluster output; \
		else echo "Error detected: $$EXIT_CODE..."; exit 1; \
	fi

clean-cloud: clean-do-unifi clean-do-nc

clean-infra: clean-cluster clean-front

clean-do-nc: | env_check
	@echo "$@: Preparing to destroy Nomad/Consul Cluster...";
	@terraform -chdir=do-nomad-consul destroy -auto-approve -var-file="../tfvars/do-nomad-consul.tfvars" -var-file="../tfvars/common/digitalocean.tfvars";

clean-do-unifi: | env_check
	@echo "$@: Preparing to destroy Unifi Controller...";
	@terraform -chdir=do-unifi destroy -auto-approve -var-file="../tfvars/do-unifi.tfvars" -var-file="../tfvars/common/digitalocean.tfvars";

clean-oob-syncer: | env_check
	@echo "$@: Preparing to destroy OOB Syncer...";
	@terraform -chdir=oob-syncer destroy -auto-approve -var-file="../tfvars/oob-syncer.tfvars";

clean-front: | env_check
	@echo "$@: Preparing to destroy Front Loadbalancers...";
	@terraform -chdir=front-lbs destroy -auto-approve -var-file="../tfvars/front-lb.tfvars" -var-file="../tfvars/common/vsphere.tfvars";

clean-cluster: | env_check
	@echo "$@: Preparing to destroy K8 cluster...";
	@terraform -chdir=k8s-cluster destroy -auto-approve -var-file="../tfvars/k8-cluster.tfvars" -var-file="../tfvars/common/vsphere.tfvars";
