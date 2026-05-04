# Sourced by ../build.sh; Calamares installed-user validation and installation hardening

log "Writing Calamares installed-user validation hardening"

mkdir -p "$PROFILE/airootfs/root" "$PROFILE/airootfs/etc/skel/.config"

cat > "$PROFILE/airootfs/root/lolios-calamares-user-check.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

LOG="/var/log/lolios-calamares-user-check.log"
mkdir -p /var/log
exec > >(tee -a "$LOG") 2>&1

echo "[LOLIOS] Calamares user validation started"

find_installed_user() {
    awk -F: '$3 >= 1000 && $3 < 60000 && $1 != "live" && $7 !~ /(nologin|false)$/ {print $1; exit}' /etc/passwd
}

fail() {
    echo "[LOLIOS][ERROR] $*" >&2
    exit 1
}

REAL_USER="$(find_installed_user || true)"
[ -n "$REAL_USER" ] || fail "No real desktop user was created by Calamares. Refusing to finish installation."

echo "[LOLIOS] Found installed user: $REAL_USER"

SHADOW_LINE="$(awk -F: -v user="$REAL_USER" '$1 == user {print $2; exit}' /etc/shadow 2>/dev/null || true)"
[ -n "$SHADOW_LINE" ] || fail "User $REAL_USER has no /etc/shadow entry."

case "$SHADOW_LINE" in
    '!'|'*'|'!!'|'' )
        fail "User $REAL_USER has a locked or empty password hash. Set a password in Calamares."
        ;;
    \$y\$*|\$gy\$*|\$7\$*|\$6\$*|\$5\$*|\$2a\$*|\$2y\$*)
        echo "[LOLIOS] User password hash looks valid."
        ;;
    *)
        fail "User $REAL_USER has an unexpected password hash format. Refusing unsafe installation."
        ;;
esac

HOME_DIR="$(getent passwd "$REAL_USER" | cut -d: -f6)"
[ -n "$HOME_DIR" ] || fail "User $REAL_USER has no home directory in passwd."
mkdir -p "$HOME_DIR" "$HOME_DIR/.config" "$HOME_DIR/Games/LoliOS" "$HOME_DIR/.local/share/lolios/exe-launcher/apps"
chown -R "$REAL_USER:$REAL_USER" "$HOME_DIR" 2>/dev/null || true

# Ensure sudo/polkit will have a normal administrator account after install.
getent group wheel >/dev/null 2>&1 || groupadd wheel
usermod -aG wheel "$REAL_USER" || fail "Cannot add $REAL_USER to wheel group."

# SDDM autologin can be used, but not by keeping Calamares/Live fragments.
rm -f /etc/sddm.conf.d/*live* /etc/sddm.conf.d/*autologin* 2>/dev/null || true

# Disable KDE lockscreen by default to match LoliOS autologin policy, while still
# keeping the user's account password available for sudo/polkit/admin operations.
cat > "$HOME_DIR/.config/kscreenlockerrc" <<'EOLOCK'
[Daemon]
Autolock=false
LockOnResume=false
Timeout=0
EOLOCK
chown "$REAL_USER:$REAL_USER" "$HOME_DIR/.config/kscreenlockerrc" 2>/dev/null || true

mkdir -p /etc/skel/.config
cat > /etc/skel/.config/kscreenlockerrc <<'EOLOCK'
[Daemon]
Autolock=false
LockOnResume=false
Timeout=0
EOLOCK

echo "[LOLIOS] Calamares user validation passed"
EOF
chmod +x "$PROFILE/airootfs/root/lolios-calamares-user-check.sh"

# Keep skel consistent even before the postinstall script runs.
cat > "$PROFILE/airootfs/etc/skel/.config/kscreenlockerrc" <<'EOF'
[Daemon]
Autolock=false
LockOnResume=false
Timeout=0
EOF

# ------------------------------------------------------------
