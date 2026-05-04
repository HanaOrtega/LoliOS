# Sourced by ../build.sh; live marker and installed-system first boot hardening

log "Writing Live/installed system boundary and first-boot hardening"

mkdir -p "$PROFILE/airootfs/etc/systemd/system" \
         "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants" \
         "$PROFILE/airootfs/usr/local/bin" \
         "$PROFILE/airootfs/var/lib/lolios"

# Marker: present only in the Live ISO. /root/postinstall.sh removes it from the
# installed system. Services that must not run in Live can use ConditionPathExists=!/etc/lolios-live.
cat > "$PROFILE/airootfs/etc/lolios-live" <<'EOF'
LoliOS Live ISO marker. Removed by /root/postinstall.sh after Calamares installation.
EOF

cat > "$PROFILE/airootfs/usr/local/bin/lolios-installed-firstboot" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

LOG="/var/log/lolios-installed-firstboot.log"
mkdir -p /var/log /var/lib/lolios
exec > >(tee -a "$LOG") 2>&1

echo "[LOLIOS] installed first boot started: $(date -Iseconds 2>/dev/null || date)"

if [ -e /etc/lolios-live ]; then
    echo "[LOLIOS] live marker still present; refusing to run installed firstboot tasks"
    exit 0
fi

if [ -e /var/lib/lolios/installed-firstboot.done ]; then
    echo "[LOLIOS] firstboot already completed"
    exit 0
fi

restore_secure_sddm_pam() {
    echo "[LOLIOS] restoring secure installed-system SDDM PAM policy"
    mkdir -p /etc/pam.d
    cat > /etc/pam.d/sddm <<'EOPAM'
#%PAM-1.0
auth      include    system-login
account   include    system-login
password  include    system-login
session   include    system-login
EOPAM
    cat > /etc/pam.d/sddm-autologin <<'EOPAM'
#%PAM-1.0
auth      required   pam_succeed_if.so user ingroup autologin
auth      include    system-login
account   include    system-login
password  include    system-login
session   include    system-login
EOPAM
}

remove_live_remnants() {
    echo "[LOLIOS] removing remaining Live-only files"
    rm -f /etc/lolios-live || true
    rm -f /etc/sudoers.d/99-lolios-live || true
    rm -f /etc/polkit-1/rules.d/49-lolios-live-admin.rules || true
    rm -f /etc/sysusers.d/lolios-live.conf || true
    rm -f /etc/tmpfiles.d/lolios-live.conf || true
    rm -f /etc/systemd/system/lolios-live-user.service || true
    rm -f /etc/systemd/system/multi-user.target.wants/lolios-live-user.service || true
    rm -f /etc/systemd/system/graphical.target.wants/lolios-live-user.service || true
    rm -f /etc/systemd/system/display-manager.service.d/10-lolios-live-user.conf || true
    rm -f /etc/sddm.conf.d/*live* /etc/sddm.conf.d/*autologin* 2>/dev/null || true
    rm -f /usr/share/applications/lolios-installer.desktop || true
    find /home /root -maxdepth 4 -type f \( -name 'lolios-installer.desktop' -o -name 'calamares.desktop' \) -delete 2>/dev/null || true
    if id live >/dev/null 2>&1; then
        userdel -r live 2>/dev/null || userdel live 2>/dev/null || true
    fi
    rm -rf /home/live || true
}

configure_installed_sddm() {
    echo "[LOLIOS] enforcing installed-system SDDM config without autologin"
    mkdir -p /etc/sddm.conf.d
    cat > /etc/sddm.conf.d/10-lolios-installed.conf <<'EOSDDM'
[General]
DisplayServer=x11

[Theme]
Current=lolios
CursorTheme=LoliOS
Font=Noto Sans,10,-1,5,50,0,0,0,0,0

[Users]
MinimumUid=1000
MaximumUid=60513
HideUsers=live

[Autologin]
Session=plasma.desktop
User=
Relogin=false
EOSDDM
    rm -f /etc/sddm.conf.d/90-lolios-live-autologin.conf /etc/sddm.conf.d/00-lolios-live-autologin.conf 2>/dev/null || true
    if [ -e /usr/lib/systemd/system/sddm.service ]; then
        ln -sf /usr/lib/systemd/system/sddm.service /etc/systemd/system/display-manager.service
        systemctl enable sddm.service 2>/dev/null || true
    fi
}

prepare_real_users() {
    echo "[LOLIOS] applying first-run defaults to installed users"
    local user home
    awk -F: '$3 >= 1000 && $3 < 60000 && $7 !~ /(nologin|false)$/ {print $1":"$6}' /etc/passwd | while IFS=: read -r user home; do
        [ -n "$user" ] && [ -d "$home" ] || continue
        [ "$user" = "live" ] && continue
        mkdir -p "$home/.config" "$home/.local/share/applications" "$home/Games/LoliOS"
        cp -an /etc/skel/. "$home/" 2>/dev/null || true
        chown -R "$user:$user" "$home/.config" "$home/.local" "$home/Games" 2>/dev/null || true
        chmod 700 "$home/.config" 2>/dev/null || true
    done
}

restore_secure_sddm_pam
remove_live_remnants
configure_installed_sddm
prepare_real_users
systemctl daemon-reload 2>/dev/null || true

touch /var/lib/lolios/installed-firstboot.done
systemctl disable lolios-installed-firstboot.service 2>/dev/null || true

echo "[LOLIOS] installed first boot completed"
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-installed-firstboot"

cat > "$PROFILE/airootfs/etc/systemd/system/lolios-installed-firstboot.service" <<'EOF'
[Unit]
Description=LoliOS installed-system first boot hardening
ConditionPathExists=!/etc/lolios-live
ConditionPathExists=!/var/lib/lolios/installed-firstboot.done
After=local-fs.target systemd-remount-fs.service
Before=display-manager.service sddm.service graphical.target
Wants=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/lolios-installed-firstboot
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF

ln -sf /etc/systemd/system/lolios-installed-firstboot.service \
    "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants/lolios-installed-firstboot.service"

# ------------------------------------------------------------
