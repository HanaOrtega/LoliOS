# Sourced by ../build.sh; original section: 16. Installer launcher

# 16. Installer launcher
# ------------------------------------------------------------

log "Writing installer launcher"

mkdir -p "$PROFILE/airootfs/usr/share/applications"
mkdir -p "$PROFILE/airootfs/etc/skel/Desktop"
mkdir -p "$PROFILE/airootfs/root/Desktop"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-installer" <<'EOF'
#!/usr/bin/env bash
set -u
LOG="/tmp/lolios-installer.log"

echo "=== LoliOS installer launcher ===" > "$LOG"
echo "user=$(id)" >> "$LOG"
echo "DISPLAY=${DISPLAY:-}" >> "$LOG"
echo "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-}" >> "$LOG"

if ! command -v calamares >/dev/null 2>&1; then
    echo "ERROR: calamares not found" >> "$LOG"
    kdialog --error "Calamares nie jest zainstalowany. Log: $LOG" 2>/dev/null || true
    exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
    exec calamares -d >> "$LOG" 2>&1
fi

if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
    exec sudo -E calamares -d >> "$LOG" 2>&1
fi

if command -v pkexec >/dev/null 2>&1; then
    exec pkexec env DISPLAY="${DISPLAY:-}" XAUTHORITY="${XAUTHORITY:-}" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-}" calamares -d >> "$LOG" 2>&1
fi

if command -v kdesu >/dev/null 2>&1; then
    exec kdesu -c "calamares -d" >> "$LOG" 2>&1
fi

echo "ERROR: no privilege escalation method worked" >> "$LOG"
kdialog --error "Nie można uruchomić instalatora jako root. Log: $LOG" 2>/dev/null || true
exit 1
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-installer"

cat > "$PROFILE/airootfs/usr/share/applications/lolios-installer.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Install LoliOS
Comment=Install LoliOS to this computer
Exec=/usr/local/bin/lolios-installer
Icon=system-software-install
Categories=System;
Terminal=false
StartupNotify=true
EOF

cp "$PROFILE/airootfs/usr/share/applications/lolios-installer.desktop" "$PROFILE/airootfs/etc/skel/Desktop/lolios-installer.desktop"
cp "$PROFILE/airootfs/usr/share/applications/lolios-installer.desktop" "$PROFILE/airootfs/root/Desktop/lolios-installer.desktop"
chmod +x "$PROFILE/airootfs/etc/skel/Desktop/lolios-installer.desktop"
chmod +x "$PROFILE/airootfs/root/Desktop/lolios-installer.desktop"

# ------------------------------------------------------------
