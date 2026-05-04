# Sourced by ../build.sh; installed system autologin must target the Calamares-created user

log "Writing installed-system user autologin finalizer"

mkdir -p "$PROFILE/airootfs/usr/local/bin" "$PROFILE/airootfs/etc/systemd/system" "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-installed-autologin-user" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

LOG="/var/log/lolios-installed-autologin-user.log"
mkdir -p /var/log /etc/sddm.conf.d
exec > >(tee -a "$LOG") 2>&1

echo "[LOLIOS] installed autologin user finalizer started"

# Never run in Live ISO. Live uses the transient live account only.
if [ -e /etc/lolios-live ]; then
    echo "[LOLIOS] live marker present; refusing installed autologin setup"
    exit 0
fi

# Pick the first real desktop user created by Calamares.
REAL_USER="$(awk -F: '$3 >= 1000 && $3 < 60000 && $1 != "live" && $7 !~ /(nologin|false)$/ {print $1; exit}' /etc/passwd)"

if [ -z "$REAL_USER" ]; then
    echo "[LOLIOS] no real desktop user found; leaving SDDM without autologin"
    exit 0
fi

echo "[LOLIOS] selected installed autologin user: $REAL_USER"

# Ensure this user is not affected by Live-only groups/policy. Autologin is an SDDM config decision,
# not passwordless sudo and not the Live nopasswdlogin policy.
for group in autologin; do
    getent group "$group" >/dev/null 2>&1 || groupadd -r "$group" 2>/dev/null || groupadd "$group" 2>/dev/null || true
    usermod -aG "$group" "$REAL_USER" 2>/dev/null || true
done

# Remove all Live login fragments. Then explicitly configure installed autologin to the Calamares user.
rm -f /etc/sddm.conf.d/*live* /etc/sddm.conf.d/*autologin* 2>/dev/null || true
cat > /etc/sddm.conf.d/20-lolios-installed-autologin.conf <<EOF_SDDM
[Autologin]
User=$REAL_USER
Session=plasma.desktop
Relogin=false
EOF_SDDM

cat > /etc/sddm.conf <<EOF_SDDM_MAIN
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
User=$REAL_USER
Session=plasma.desktop
Relogin=false
EOF_SDDM_MAIN

# Disable KDE lock screen for the installed user's first session and future sessions.
HOME_DIR="$(getent passwd "$REAL_USER" | cut -d: -f6)"
if [ -n "$HOME_DIR" ] && [ -d "$HOME_DIR" ]; then
    mkdir -p "$HOME_DIR/.config"
    cat > "$HOME_DIR/.config/kscreenlockerrc" <<'EOF_LOCK'
[Daemon]
Autolock=false
LockOnResume=false
Timeout=0
EOF_LOCK
    chown "$REAL_USER:$REAL_USER" "$HOME_DIR/.config/kscreenlockerrc" 2>/dev/null || true
fi

# Keep defaults for new users as well.
mkdir -p /etc/skel/.config
cat > /etc/skel/.config/kscreenlockerrc <<'EOF_LOCK'
[Daemon]
Autolock=false
LockOnResume=false
Timeout=0
EOF_LOCK

systemctl daemon-reload 2>/dev/null || true
systemctl restart sddm.service 2>/dev/null || true
systemctl disable lolios-installed-autologin-user.service 2>/dev/null || true

echo "[LOLIOS] installed autologin user finalizer completed"
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-installed-autologin-user"

cat > "$PROFILE/airootfs/etc/systemd/system/lolios-installed-autologin-user.service" <<'EOF'
[Unit]
Description=LoliOS configure installed-user autologin after Calamares
ConditionPathExists=!/etc/lolios-live
After=local-fs.target systemd-user-sessions.service
Before=display-manager.service sddm.service graphical.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/lolios-installed-autologin-user
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF

ln -sf /etc/systemd/system/lolios-installed-autologin-user.service \
    "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants/lolios-installed-autologin-user.service"

# ------------------------------------------------------------
