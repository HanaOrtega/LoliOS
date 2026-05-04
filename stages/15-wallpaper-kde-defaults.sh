# Sourced by ../build.sh; wallpaper compatibility helper only

# 15. Wallpaper
# ------------------------------------------------------------

log "Checking LoliOS wallpaper overlay"

# The wallpaper asset is owned by stages/12b-kde-theme.sh because it is part of
# the LoliOS Global Theme. This stage only keeps the legacy helper executable for
# audit/backward compatibility and does not create another KDE autostart.
require_file "$PROFILE/airootfs$WALL_ISO"

mkdir -p "$PROFILE/airootfs/usr/local/bin"
cat > "$PROFILE/airootfs/usr/local/bin/lolios-set-wallpaper" <<'EOF'
#!/usr/bin/env bash
set -u
WALL="/usr/share/wallpapers/LoliOS/contents/lolios-dark.png"
LOG="$HOME/.cache/lolios-wallpaper.log"
mkdir -p "$HOME/.cache"

[ -f "$WALL" ] || exit 0

{
    echo "[$(date -Iseconds)] setting LoliOS wallpaper"
    if command -v plasma-apply-wallpaperimage >/dev/null 2>&1; then
        plasma-apply-wallpaperimage "$WALL" || true
    fi
    if command -v qdbus6 >/dev/null 2>&1; then
        qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
var allDesktops = desktops();
for (i = 0; i < allDesktops.length; i++) {
    d = allDesktops[i];
    d.wallpaperPlugin = 'org.kde.image';
    d.currentConfigGroup = Array('Wallpaper', 'org.kde.image', 'General');
    d.writeConfig('Image', 'file://$WALL');
    d.writeConfig('FillMode', '2');
}
" || true
    fi
} >>"$LOG" 2>&1
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-set-wallpaper"

rm -f "$PROFILE/airootfs/etc/xdg/autostart/lolios-set-wallpaper.desktop"

# ------------------------------------------------------------
