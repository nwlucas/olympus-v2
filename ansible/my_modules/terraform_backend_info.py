#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Copyright: (c) 2021, Nigel Williams-Lucas <nigel.williamslucas@gmail.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

from __future__ import (absolute_import, division, print_function)
import json
import boto3
import pprint
from ansible.module_utils.basic import *

__metaclass__ = type

ANSIBLE_METADATA = {
    'status': ['preview'],
    'supported_by': 'community',
    'metadata_version': '1.1'
}

DOCUMENTATION = '''
    ---
    module: terraform_backend_info
    short_description: Get output variables from Terraform s3 backend.
    description:
      - Get output variables from Terraform s3 backend.
    version_added: "2.4"
    author: Nigel Williams-Lucas
    options:
      bucket:
        description:
          - Name of the s3 bucket where Terraform state is stored.
        required: true
      object:
        description:
          - Name of the s3 object where Terraform state is stored.
        required: true
      aws_profile:
        description:
          - Name of the aws profile to be used.
        default: "default"
      aws_access_key:
        description:
          - AWS access key to be used for bucket access.
          - If declared aws_profile option is ignored and aws_secret_access_key option is required.
        default: ""
      aws_secret_access_key:
        description:
          - AWS secret access key to be used for bucket access.
          - If declared aws_profile option is ignored and aws_access_key option is required.
        default: ""
      aws_region:
        description:
          - ID of AWS region to connect to s3 bucket from.
        default: "us-east-1"
    ...
    '''

EXAMPLES = '''
    ---
    - name: Get Terraform EFS backend variables
      fetch_terraform_backend_outputs:
        bucket: "example-bucket"
        object: "storage/terraform.tfstate"
      register: terraform_storage

    - name: Mount EFS storage
      mount:
        state: "mounted"
      path: /mnt
        src: "{{ terraform_storage.vars.efs_id }}"
        fstype: efs
        opts: rw
    ...
    '''

RETURN = '''
    ---
    vars:
      description:
        - Outputs from Terraform backend in JSON format are returned upon successful execution.
      type: json
      returned: success
      version_added: "2.4"
    ...
    '''


def format_data(data):
    pretty_data = json.loads(data)
    result = {}
    permanent = pretty_data['outputs']

    for key, value in permanent.items():
        result[key] = value['value']

    return result


def backend_pull(client, data):
    s3 = client.resource('s3')
    obj = s3.Object(data['bucket'], data['object'])
    raw_data = obj.get()['Body'].read().decode('utf-8')
    return format_data(raw_data)


def build_client(data, ansible_module):
    aws_access_key = data['aws_access_key']
    aws_secret_access_key = data['aws_secret_access_key']
    aws_profile = data['aws_profile']
    aws_region = data['aws_region']
    if aws_access_key and aws_secret_access_key:
        return boto3.session.Session(
            aws_access_key_id=aws_access_key,
            aws_secret_access_key=aws_secret_access_key,
            region_name=aws_region)
    elif not aws_access_key and not aws_secret_access_key:
        return boto3.session.Session(profile_name=aws_profile)
    else:
        return False


def run_module():
    module_args = dict(
        bucket=dict(type='str', required=True),
        object=dict(type='str', required=True),
        aws_profile=dict(type='str', default="default"),
        aws_access_key=dict(type='str', default=""),
        aws_secret_access_key=dict(type='str', default=""),
        aws_region=dict(type='str', default="us-east-1")
    )

    result = dict(
        changed=False,
        orginal_message='',
        message='',
        my_useful_info={},
    )

    module = AnsibleModule(argument_spec=module_args,
                           supports_check_mode=True)

    if module.check_mode:
        module.exit_json(**result)

    s3_client = build_client(module.params, module)

    if s3_client:
        result = backend_pull(s3_client, module.params)
        module.exit_json(changed=False, vars=result)
    else:
        module.fail_json(msg="Wrong AWS credentials")


def main():
    run_module()


if __name__ == '__main__':
    main()
