#cloud-config
merge_how:
- name: list
  settings: [append]
- name: dict
  settings: [no_replace, recurse_list]
write_files:
- content: |
    ${ indent(4, cloudflared_credentials_file) }
  path: ${ cloudflared_path }/credentials.json
  owner: root:root
  permissions: '0644'
- content: |
    ${ indent(4, cloudflared_config_file) }
  path: ${ cloudflared_path }/config.yml
  owner: root:root
  permissions: '0644'
- content: |
    [Unit]
    Description=Cloudflare Tunnel
    After=network.target

    [Service]
    TimeoutStartSec=0
    Type=notify
    ExecStart=/usr/local/bin/cloudflared --config ${ cloudflared_path }/config.yml --no-autoupdate tunnel run
    Restart=on-failure
    RestartSec=5s

    [Install]
    WantedBy=multi-user.target
  path: /etc/systemd/system/cloudflared.service
  owner: root:root
  permissions: '0644'
apt:
  sources:
    cloudflare.list:
      source: "deb [arch=amd64] http://pkg.cloudflare.com/ focal main"
      key: |
        -----BEGIN PGP PUBLIC KEY BLOCK-----
        Version: GnuPG v1

        mQENBFTJNTUBCADZtil+vA5moao8PseavB1lzayrpuRhANlLRtaXGd1mj4JmZRoi
        2Ns8WyZpuOaPItOALg7aifBwKwXeLIB6OiCNTxry2gs9SOx57sn+zYiFNKJYK+v3
        qJAJ8qGm8w6E1x32BYeO3RuZt2VHGoYlRKLLVgiY5wmZg6xj6R0YvfxZ9UQa24wu
        V4BnPlpX4g1uSqJ8anSyRSdFb7DYf+28L4JNkl5mCW6q0HSB+/yfLXk1tC2jqPyc
        e0zzfH9J8homH4YquZsWkrwxkJKdIalqjl4VLamLYiauhJN+5Jf0HxOgcXKQCyql
        0m7Wxu6aaSu/0qLo9wRIT06jvyh77HMKNdsnABEBAAG0M0Nsb3VkRmxhcmUgU29m
        dHdhcmUgUGFja2FnaW5nIDxoZWxwQGNsb3VkZmxhcmUuY29tPokBOAQTAQIAIgUC
        VMk1NQIbAwYLCQgHAwIGFQgCCQoLBBYCAwECHgECF4AACgkQJUs5HYysy/gHqwgA
        japcx0rcEiH0g5/4URaW05wxKuIyCwbtsihDd2cNW6RF8XvEB9cWnSbE/HEN9I2W
        tePIjQRag7k6wPU1GIrQxnhjK/Dw4wpwppCAVRajCgxWnxJ34zmvMpx9yRDk2+aW
        vaBV0VwXCRTro/qleyb3IWokorxjqe8hEc2qVoNwkysKvB3ZTL7hxVzeMvTKTvti
        A84+9h4In2V4XaqTBgEPtmINVJoorEUN5US6xqWX+25YGei459TvBRHf5YQfYL3N
        dZkmPzbTl7Em3zwbNXKvfzwkmRG2QABdHCe0hhhJLjjWuCJ3vObB+6QxInbm9uEp
        kf86007RP1cWqCpwKpsUmg==
        =62cw
        -----END PGP PUBLIC KEY BLOCK-----
users:
- name: ${ cloudflared_user }
  shell: /sbin/nologin
  gecos: "Consul NoLogin User"
  primary_group: ${ cloudflared_group }
  groups: [adm, audio, cdrom, dialout, floppy, video, plugdev, dip, netdev]
  system: true
package_update: true
package_upgrade: true
packages:
- cloudflared
runcmd:
- [chown, -R, "${cloudflared_user}:${cloudflared_group}", "${cloudflared_path}"]
- [systemctl, enable, cloudflared.service]
- [systemctl, start, cloudflared.service]
