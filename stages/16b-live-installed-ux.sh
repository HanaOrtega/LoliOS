# Sourced by ../build.sh; Live and installed-system UX tools

log "Writing Live and installed-system UX tools"

mkdir -p \
  "$PROFILE/airootfs/usr/local/bin" \
  "$PROFILE/airootfs/usr/share/applications" \
  "$PROFILE/airootfs/etc/skel/.config/autostart" \
  "$PROFILE/airootfs/etc/skel/Desktop" \
  "$PROFILE/airootfs/etc/xdg/autostart" \
  "$PROFILE/airootfs/var/lib/lolios"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-session-mode" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
if [ -e /etc/lolios-live ]; then
    echo live
else
    echo installed
fi
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-session-mode"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-live-doctor" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
fail=0
ok(){ echo "OK: $*"; }
bad(){ echo "BAD: $*"; fail=1; }
warn(){ echo "WARN: $*"; }

[ -e /etc/lolios-live ] && ok "Live marker exists" || bad "Live marker missing"
id live >/dev/null 2>&1 && ok "live user exists" || bad "live user missing"
getent group wheel >/dev/null 2>&1 && ok "wheel group exists" || bad "wheel group missing"
if id live >/dev/null 2>&1; then
    id -nG live | grep -qw wheel && ok "live is in wheel" || bad "live not in wheel"
    id -nG live | grep -qw autologin && ok "live is in autologin" || bad "live not in autologin"
    id -nG live | grep -qw nopasswdlogin && ok "live is in nopasswdlogin" || bad "live not in nopasswdlogin"
fi
[ -f /etc/sudoers.d/99-lolios-live ] && ok "Live sudo rule exists" || bad "Live sudo rule missing"
[ -f /etc/polkit-1/rules.d/49-lolios-live-admin.rules ] && ok "Live polkit rule exists" || bad "Live polkit rule missing"
[ -f /etc/sddm.conf.d/90-lolios-live-autologin.conf ] && ok "Live SDDM autologin exists" || bad "Live SDDM autologin missing"
command -v calamares >/dev/null 2>&1 && ok "Calamares installed" || bad "Calamares missing"
command -v lolios-installer >/dev/null 2>&1 && ok "Installer launcher installed" || bad "Installer launcher missing"
systemctl is-enabled NetworkManager.service >/dev/null 2>&1 && ok "NetworkManager enabled" || warn "NetworkManager not enabled"
command -v vulkaninfo >/dev/null 2>&1 && ok "vulkaninfo available" || warn "vulkaninfo missing"
command -v nvidia-smi >/dev/null 2>&1 && ok "nvidia-smi available" || warn "nvidia-smi missing or not NVIDIA"
command -v lolios-gaming-center >/dev/null 2>&1 && ok "Game Center available" || warn "Game Center missing"
exit "$fail"
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-live-doctor"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-installed-doctor" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
fail=0
ok(){ echo "OK: $*"; }
bad(){ echo "BAD: $*"; fail=1; }
warn(){ echo "WARN: $*"; }

[ ! -e /etc/lolios-live ] && ok "Live marker absent" || bad "Live marker still present"
! id live >/dev/null 2>&1 && ok "live user absent" || bad "live user still exists"
[ ! -f /etc/sudoers.d/99-lolios-live ] && ok "Live sudo rule absent" || bad "Live sudo rule still exists"
[ ! -f /etc/polkit-1/rules.d/49-lolios-live-admin.rules ] && ok "Live polkit rule absent" || bad "Live polkit rule still exists"
[ ! -f /etc/sddm.conf.d/90-lolios-live-autologin.conf ] && ok "Live autologin absent" || bad "Live autologin still exists"
[ -f /etc/sddm.conf.d/10-lolios-installed.conf ] || [ -f /etc/sddm.conf.d/10-lolios-theme.conf ] && ok "LoliOS SDDM config present" || bad "LoliOS SDDM config missing"
[ -f /boot/vmlinuz-linux-zen ] && ok "linux-zen kernel present" || warn "linux-zen kernel not found in /boot"
[ -f /boot/initramfs-linux-zen.img ] && ok "linux-zen initramfs present" || warn "linux-zen initramfs missing"
[ -s /boot/grub/grub.cfg ] && ok "GRUB config exists" || warn "GRUB config missing"
grep -q '^\[lolios-local\]' /etc/pacman.conf 2>/dev/null && ok "local repo configured" || warn "local repo not configured"
[ -d /opt/lolios/repo ] && ok "embedded repo exists" || warn "embedded repo missing"
command -v lolios-gaming-center >/dev/null 2>&1 && ok "Game Center available" || warn "Game Center missing"
command -v lolios-profile >/dev/null 2>&1 && ok "profile manager available" || warn "profile manager missing"

awk -F: '$3 >= 1000 && $3 < 60000 && $7 !~ /(nologin|false)$/ {print $1":"$6}' /etc/passwd | while IFS=: read -r user home; do
    [ -n "$user" ] || continue
    [ "$user" = live ] && continue
    [ -d "$home" ] && echo "OK: user home exists: $user" || echo "WARN: user home missing: $user"
    [ -d "$home/Games/LoliOS" ] && echo "OK: Games/LoliOS exists for $user" || echo "WARN: Games/LoliOS missing for $user"
done
exit "$fail"
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-installed-doctor"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-start-center" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
MODE="$(lolios-session-mode 2>/dev/null || echo installed)"

run_cmd() {
    local title="$1"; shift
    if command -v konsole >/dev/null 2>&1; then
        konsole --new-tab -p tabtitle="$title" -e "$@" >/dev/null 2>&1 &
    elif command -v xterm >/dev/null 2>&1; then
        xterm -T "$title" -e "$@" >/dev/null 2>&1 &
    else
        "$@"
    fi
}

if command -v kdialog >/dev/null 2>&1; then
    if [ "$MODE" = live ]; then
        choice="$(kdialog --title "LoliOS Live Start Center" --menu "Wybierz akcję:" \
            install "Install LoliOS" \
            try "Try Live Desktop" \
            gamecenter "Open Game Center" \
            network "Open Network Settings" \
            gpu "Show GPU/Vulkan status" \
            doctor "Run Live Doctor" \
            logs "Open logs" 2>/dev/null || true)"
        case "$choice" in
            install) lolios-installer & ;;
            try) exit 0 ;;
            gamecenter) lolios-gaming-center & ;;
            network) systemsettings kcm_networkmanagement >/dev/null 2>&1 & ;;
            gpu) run_cmd "LoliOS GPU Status" bash -lc 'lspci | grep -Ei "vga|3d|display"; echo; command -v vulkaninfo >/dev/null && vulkaninfo --summary || true; echo; command -v nvidia-smi >/dev/null && nvidia-smi || true; read -rp "Press Enter..."' ;;
            doctor) run_cmd "LoliOS Live Doctor" bash -lc 'lolios-live-doctor; read -rp "Press Enter..."' ;;
            logs) xdg-open /var/log >/dev/null 2>&1 & ;;
        esac
    else
        choice="$(kdialog --title "LoliOS Start Center" --menu "Wybierz akcję:" \
            gamecenter "Open Game Center" \
            doctor "Run Installed Doctor" \
            updates "Open Update Tool" \
            network "Open Network Settings" \
            games "Open ~/Games/LoliOS" \
            logs "Open logs" 2>/dev/null || true)"
        case "$choice" in
            gamecenter) lolios-gaming-center & ;;
            doctor) run_cmd "LoliOS Installed Doctor" bash -lc 'lolios-installed-doctor; read -rp "Press Enter..."' ;;
            updates) command -v lolios-update >/dev/null 2>&1 && run_cmd "LoliOS Update" lolios-update || true ;;
            network) systemsettings kcm_networkmanagement >/dev/null 2>&1 & ;;
            games) mkdir -p "$HOME/Games/LoliOS"; xdg-open "$HOME/Games/LoliOS" >/dev/null 2>&1 & ;;
            logs) xdg-open /var/log >/dev/null 2>&1 & ;;
        esac
    fi
else
    if [ "$MODE" = live ]; then
        cat <<EOM
LoliOS Live Start Center
1) Install LoliOS: lolios-installer
2) Game Center: lolios-gaming-center
3) Live Doctor: lolios-live-doctor
EOM
    else
        cat <<EOM
LoliOS Start Center
1) Game Center: lolios-gaming-center
2) Installed Doctor: lolios-installed-doctor
3) Games folder: ~/Games/LoliOS
EOM
    fi
fi
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-start-center"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-first-login-setup" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
MODE="$(lolios-session-mode 2>/dev/null || echo installed)"
DONE="$HOME/.local/state/lolios/first-login.done"
mkdir -p "$(dirname "$DONE")" "$HOME/Games/LoliOS" "$HOME/.local/share/applications" "$HOME/.config/autostart" "$HOME/Desktop"

# Live mode should stay transient, but still ensure useful folders exist.
if [ "$MODE" = live ]; then
    exit 0
fi

[ -e "$DONE" ] && exit 0

cp -an /etc/skel/. "$HOME/" 2>/dev/null || true
mkdir -p "$HOME/Games/LoliOS" "$HOME/.local/share/lolios/exe-launcher/apps"

if [ -f /usr/share/applications/lolios-game-center.desktop ]; then
    cp -f /usr/share/applications/lolios-game-center.desktop "$HOME/.local/share/applications/" 2>/dev/null || true
fi
if [ -f /usr/share/applications/lolios-start-center.desktop ]; then
    cp -f /usr/share/applications/lolios-start-center.desktop "$HOME/Desktop/" 2>/dev/null || true
    chmod +x "$HOME/Desktop/lolios-start-center.desktop" 2>/dev/null || true
fi

if command -v kdialog >/dev/null 2>&1; then
    kdialog --passivepopup "LoliOS jest gotowy. Game Center i folder ~/Games/LoliOS zostały przygotowane." 8 >/dev/null 2>&1 || true
fi

touch "$DONE"
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-first-login-setup"

cat > "$PROFILE/airootfs/usr/share/applications/lolios-start-center.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=LoliOS Start Center
Comment=Start center for Live and installed LoliOS sessions
Exec=/usr/local/bin/lolios-start-center
Icon=system-help
Categories=System;Utility;
Terminal=false
StartupNotify=true
EOF

cat > "$PROFILE/airootfs/usr/share/applications/lolios-live-doctor.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=LoliOS Live Doctor
Comment=Check Live ISO session health
Exec=konsole -e bash -lc 'lolios-live-doctor; read -rp "Press Enter..."'
Icon=utilities-system-monitor
Categories=System;Utility;
Terminal=false
StartupNotify=true
OnlyShowIn=KDE;
EOF

cat > "$PROFILE/airootfs/usr/share/applications/lolios-installed-doctor.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=LoliOS Installed Doctor
Comment=Check installed LoliOS system health
Exec=konsole -e bash -lc 'lolios-installed-doctor; read -rp "Press Enter..."'
Icon=utilities-system-monitor
Categories=System;Utility;
Terminal=false
StartupNotify=true
OnlyShowIn=KDE;
EOF

cat > "$PROFILE/airootfs/etc/xdg/autostart/lolios-start-center.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=LoliOS Start Center
Comment=Show LoliOS Live/Installed start center
Exec=/usr/local/bin/lolios-start-center
Icon=system-help
X-KDE-autostart-after=panel
X-GNOME-Autostart-enabled=true
OnlyShowIn=KDE;
Terminal=false
EOF

cat > "$PROFILE/airootfs/etc/xdg/autostart/lolios-first-login-setup.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=LoliOS First Login Setup
Comment=Prepare user folders and shortcuts on installed systems
Exec=/usr/local/bin/lolios-first-login-setup
Icon=system-run
X-KDE-autostart-after=panel
X-GNOME-Autostart-enabled=true
OnlyShowIn=KDE;
Terminal=false
EOF

cp -f "$PROFILE/airootfs/usr/share/applications/lolios-start-center.desktop" "$PROFILE/airootfs/etc/skel/Desktop/lolios-start-center.desktop"
chmod +x "$PROFILE/airootfs/etc/skel/Desktop/lolios-start-center.desktop"

# ------------------------------------------------------------
