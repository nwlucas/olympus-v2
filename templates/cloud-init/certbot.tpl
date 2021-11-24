#cloud-config
merge_how:
- name: list
  settings: [append]
- name: dict
  settings: [no_replace, recurse_list]
write_files:
- content: dns_cloudflare_api_token = ${ cf_token }
  path: /opt/bootstrap/acme/cf_creds.ini
  owner: root:root
  permissions: '0600'
- path: /etc/letsencrypt/renewal-hooks/post/001-restart-cockpit.sh
  owner: root:root
  permissions: '0755'
  content: |
    #!/usr/bin/env bash

    echo "SSL certificates renewed"

    cp /etc/letsencrypt/live/${ instance_fqdn }/fullchain.pem /etc/cockpit/ws-certs.d/${ instance_fqdn }.crt
    cp /etc/letsencrypt/live/${ instance_fqdn }/privkey.pem /etc/cockpit/ws-certs.d/${ instance_fqdn }.key
    chown cockpit-ws:cockpit-ws /etc/cockpit/ws-certs.d/${ instance_fqdn }.crt /etc/cockpit/ws-certs.d/${ instance_fqdn }.key

    echo "Restarting Cockpit"
    systemctl restart cockpit
runcmd:
- snap install --classic certbot
- snap set certbot trust-plugin-with-root=ok
- snap install certbot-dns-cloudflare
- ln -s $(which certbot) /usr/bin/certbot
- /usr/bin/certbot register --email ${le_email} --no-eff-email --agree-tos
- /usr/bin/certbot certonly --dns-cloudflare --dns-cloudflare-credentials /opt/bootstrap/acme/cf_creds.ini -d ${instance_fqdn}
- /etc/letsencrypt/renewal-hooks/post/001-restart-cockpit.sh
