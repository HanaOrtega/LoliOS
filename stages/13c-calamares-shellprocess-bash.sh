# Sourced by ../build.sh; force Calamares shellprocess scripts through bash

log "Writing Calamares shellprocess bash wrapper"

mkdir -p "$PROFILE/airootfs/etc/calamares/modules"
cat > "$PROFILE/airootfs/etc/calamares/modules/shellprocess.conf" <<'EOF'
---
dontChroot: false
timeout: 2400
script:
  - "/bin/bash /root/lolios-calamares-user-check.sh"
  - "/bin/bash /root/postinstall.sh"
EOF

# ------------------------------------------------------------
