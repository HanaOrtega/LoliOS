# Sourced by ../build.sh; fix installed-system pacman.conf section placement

log "Writing installed pacman.conf section repair"

mkdir -p "$PROFILE/airootfs/usr/local/bin"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-fix-pacman-conf-sections" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

CONF="${1:-/etc/pacman.conf}"
[ -f "$CONF" ] || exit 0
TMP="$(mktemp)"

# Remove old LoliOS KDE-theme NoExtract rules from every section. LoliOS now
# ships its theme as an additional theme and must not block upstream KDE/Breeze
# themes from Plasma packages.
awk '
BEGIN { skip_comment=0 }
/^# LoliOS KDE theme ownership$/ { skip_comment=1; next }
skip_comment && /^# LoliOS provides the Plasma Global Theme/ { next }
skip_comment && /^# Do not let future plasma-workspace/ { next }
skip_comment && /^NoExtract = usr\/share\/plasma\/look-and-feel\/org\.kde\.\*/ { next }
skip_comment && /^NoExtract = usr\/share\/plasma\/desktoptheme\/breeze\/\*/ { next }
skip_comment && /^NoExtract = usr\/share\/plasma\/desktoptheme\/breeze-dark\/\*/ { next }
skip_comment && /^NoExtract = usr\/share\/plasma\/desktoptheme\/oxygen\/\*/ { next }
skip_comment && /^NoExtract = usr\/share\/sddm\/themes\/breeze\/\*/ { skip_comment=0; next }
/^NoExtract = usr\/share\/plasma\/look-and-feel\/org\.kde\.\*/ { next }
/^NoExtract = usr\/share\/plasma\/desktoptheme\/breeze\/\*/ { next }
/^NoExtract = usr\/share\/plasma\/desktoptheme\/breeze-dark\/\*/ { next }
/^NoExtract = usr\/share\/plasma\/desktoptheme\/oxygen\/\*/ { next }
/^NoExtract = usr\/share\/sddm\/themes\/breeze\/\*/ { next }
{ skip_comment=0; print }
' "$CONF" > "$TMP"

install -m 0644 "$TMP" "$CONF"
rm -f "$TMP"
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-fix-pacman-conf-sections"

# Make generated postinstall repair pacman.conf after repo setup. This removes
# legacy KDE NoExtract lines from installed systems instead of reinserting them.
if [ -f "$PROFILE/airootfs/root/postinstall.sh" ] && ! grep -q 'lolios-fix-pacman-conf-sections' "$PROFILE/airootfs/root/postinstall.sh"; then
    sed -i '/^configure_offline_local_repo$/a command -v lolios-fix-pacman-conf-sections >/dev/null 2>\&1 && lolios-fix-pacman-conf-sections /etc/pacman.conf || true' "$PROFILE/airootfs/root/postinstall.sh"
fi

# ------------------------------------------------------------
