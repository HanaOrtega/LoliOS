# Sourced by ../build.sh; fix installed-system pacman.conf section placement

log "Writing installed pacman.conf section repair"

mkdir -p "$PROFILE/airootfs/usr/local/bin"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-fix-pacman-conf-sections" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

CONF="${1:-/etc/pacman.conf}"
[ -f "$CONF" ] || exit 0
TMP="$(mktemp)"

# Remove LoliOS NoExtract lines from every section first; they will be reinserted
# under [options], where pacman actually accepts them.
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
' "$CONF" > "$TMP.clean"

awk '
BEGIN { inserted=0 }
{
    print
    if (!inserted && $0 == "[options]") {
        print ""
        print "# LoliOS KDE theme ownership"
        print "# LoliOS provides the Plasma Global Theme and desktop theme via system overlay."
        print "# Do not let future plasma-workspace/breeze upgrades restore upstream KDE Global Themes."
        print "NoExtract = usr/share/plasma/look-and-feel/org.kde.*"
        print "NoExtract = usr/share/plasma/desktoptheme/breeze/*"
        print "NoExtract = usr/share/plasma/desktoptheme/breeze-dark/*"
        print "NoExtract = usr/share/plasma/desktoptheme/oxygen/*"
        print "NoExtract = usr/share/sddm/themes/breeze/*"
        inserted=1
    }
}
END { if (!inserted) exit 2 }
' "$TMP.clean" > "$TMP"

install -m 0644 "$TMP" "$CONF"
rm -f "$TMP" "$TMP.clean"
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-fix-pacman-conf-sections"

# Make generated postinstall repair pacman.conf after repo setup and NoExtract insertion.
if [ -f "$PROFILE/airootfs/root/postinstall.sh" ] && ! grep -q 'lolios-fix-pacman-conf-sections' "$PROFILE/airootfs/root/postinstall.sh"; then
    sed -i '/^install_lolios_pacman_noextract$/a command -v lolios-fix-pacman-conf-sections >/dev/null 2>\&1 && lolios-fix-pacman-conf-sections /etc/pacman.conf || true' "$PROFILE/airootfs/root/postinstall.sh"
fi

# ------------------------------------------------------------
