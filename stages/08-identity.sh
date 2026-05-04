# Sourced by ../build.sh; original section: 8. Identity

# 8. Identity
# ------------------------------------------------------------

log "Writing LoliOS identity"

mkdir -p "$PROFILE/airootfs/etc/profile.d"

cat > "$PROFILE/airootfs/etc/os-release" <<EOF
NAME="LoliOS"
PRETTY_NAME="LoliOS Personal Gaming Workstation"
ID=lolios
BUILD_ID=rolling
VERSION="$PRODUCT_VERSION"
ANSI_COLOR="1;35"
HOME_URL="https://lolios.local"
DOCUMENTATION_URL="https://lolios.local/docs"
SUPPORT_URL="https://lolios.local/support"
BUG_REPORT_URL="https://lolios.local/bugs"
EOF

echo "lolios" > "$PROFILE/airootfs/etc/hostname"
# Marker używany przez first-run, żeby konfiguratory nie startowały w Live ISO.
touch "$PROFILE/airootfs/etc/lolios-live"
echo "Welcome to LoliOS" > "$PROFILE/airootfs/etc/issue"
echo "Welcome to LoliOS" > "$PROFILE/airootfs/etc/issue.net"
echo "Welcome to LoliOS" > "$PROFILE/airootfs/etc/motd"

cat > "$PROFILE/airootfs/etc/profile.d/lolios.sh" <<'EOF'
#!/usr/bin/env bash
# Keep scripted shell output clean; greet only in interactive terminals.
case "$-" in
  *i*) echo "Welcome to LoliOS Personal Gaming Workstation" ;;
esac
EOF
chmod +x "$PROFILE/airootfs/etc/profile.d/lolios.sh"

# ------------------------------------------------------------
