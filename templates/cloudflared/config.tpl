credentials-file: ${ cloudflared_path }/credentials.json
tunnel: ${ tunnel_uuid }
loglevel: info
logfile: ${ cloudflared_path }/cloudflared.log

ingress:
  - hostname: ${ hostname }
    service: ssh://localhost:22
# Catch All
  - service: http_status:404
