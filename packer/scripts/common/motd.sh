#!/bin/sh -eux

build_message='
This system is built by the NWLNEXUS LLC.
'

if [ -d /etc/update-motd.d ]; then
    MOTD_CONFIG='/etc/update-motd.d/99-nexus'

    cat >>"$MOTD_CONFIG" <<NWLNEXUS
#!/bin/sh
cat <<'EOF'
$build_message
EOF
NWLNEXUS

    chmod 0755 "$MOTD_CONFIG"
else
    echo "$build_message" >>/etc/motd
fi
