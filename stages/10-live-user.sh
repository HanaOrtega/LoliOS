# Sourced by ../build.sh; original section: 10. Live user service

# 10. Live user service
# ------------------------------------------------------------

log "Writing passwordless live user and synchronization service"

mkdir -p "$PROFILE/airootfs/usr/local/bin"
mkdir -p "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants"
mkdir -p "$PROFILE/airootfs/etc/systemd/system/graphical.target.wants"
mkdir -p "$PROFILE/airootfs/etc/systemd/system/display-manager.service.d"
mkdir -p "$PROFILE/airootfs/etc/sysusers.d" "$PROFILE/airootfs/etc/tmpfiles.d"
mkdir -p "$PROFILE/airootfs/etc/skel/Desktop"
mkdir -p "$PROFILE/airootfs/etc/skel/.config" "$PROFILE/airootfs/root/.config"
mkdir -p "$PROFILE/airootfs/home/live"

# Never ship partial account database files in the overlay. They replace package
# owned databases and remove service accounts needed by systemd, journald, polkit
# and SDDM.
rm -f \
    "$PROFILE/airootfs/etc/passwd" \
    "$PROFILE/airootfs/etc/shadow" \
    "$PROFILE/airootfs/etc/group" \
    "$PROFILE/airootfs/etc/gshadow"

cat > "$PROFILE/airootfs/etc/sysusers.d/lolios-live.conf" <<'EOF'
g live 1000 -
g autologin - -
g nopasswdlogin - -
g wheel - -
g audio - -
g video - -
g storage - -
g power - -
g network - -
g lp - -
g scanner - -
g libvirt - -
g input - -
u live 1000:1000 "LoliOS Live User" /home/live /bin/bash
m live wheel
m live audio
m live video
m live storage
m live power
m live network
m live lp
m live scanner
m live libvirt
m live input
m live autologin
m live nopasswdlogin
EOF

cat > "$PROFILE/airootfs/etc/tmpfiles.d/lolios-live.conf" <<'EOF'
d /home/live 0755 live live -
d /home/live/Desktop 0755 live live -
d /home/live/.config 0755 live live -
d /home/live/.local 0755 live live -
EOF

chown -R 1000:1000 "$PROFILE/airootfs/home/live" 2>/dev/null || true
chmod 755 "$PROFILE/airootfs/home/live"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-create-live-user" <<'EOF'
#!/usr/bin/env bash
set -u

LOG="/var/log/lolios-live-user.log"
mkdir -p /var/log 2>/dev/null || true
exec >>"$LOG" 2>&1

echo "=== lolios-create-live-user $(date -Iseconds 2>/dev/null || date) ==="

systemd-sysusers /etc/sysusers.d/lolios-live.conf 2>/dev/null || true
systemd-tmpfiles --create /etc/tmpfiles.d/lolios-live.conf 2>/dev/null || true

EXTRA_GROUPS="wheel,audio,video,storage,power,network,lp,scanner,libvirt,input,autologin,nopasswdlogin"

getent group live >/dev/null 2>&1 || groupadd -g 1000 live 2>/dev/null || groupadd live 2>/dev/null || true
if ! id live >/dev/null 2>&1; then
    echo "live user missing; creating fallback"
    useradd -m -u 1000 -g live -s /bin/bash live 2>/dev/null || useradd -M -g live -s /bin/bash live 2>/dev/null || true
fi

for group in wheel audio video storage power network lp scanner libvirt input autologin nopasswdlogin; do
    getent group "$group" >/dev/null 2>&1 || groupadd -r "$group" 2>/dev/null || groupadd "$group" 2>/dev/null || true
done

usermod -s /bin/bash live 2>/dev/null || true
usermod -aG "$EXTRA_GROUPS" live 2>/dev/null || true
passwd -d live >/dev/null 2>&1 || true
usermod -p '' live 2>/dev/null || true
chage -E -1 -M -1 live 2>/dev/null || true
if [ -f /etc/shadow ]; then
    awk -F: 'BEGIN{OFS=":"} $1=="live"{$2=""} {print}' /etc/shadow > /etc/shadow.lolios-live 2>/dev/null && \
        cat /etc/shadow.lolios-live > /etc/shadow && rm -f /etc/shadow.lolios-live || true
fi

mkdir -p /home/live/Desktop /home/live/.config /home/live/.local 2>/dev/null || true
cp -an /etc/skel/. /home/live/ 2>/dev/null || true
chown -R live:live /home/live 2>/dev/null || chown -R live:users /home/live 2>/dev/null || true
chmod -R u+rwX /home/live/.config /home/live/.local 2>/dev/null || true
chmod 755 /home/live 2>/dev/null || true

echo "live user status:"
id live 2>/dev/null || true
getent passwd live 2>/dev/null || true
getent shadow live 2>/dev/null | awk -F: '{print "shadow field length=" length($2)}' || true
exit 0
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-create-live-user"

cat > "$PROFILE/airootfs/etc/skel/.config/kscreenlockerrc" <<'EOF'
[Daemon]
Autolock=false
LockOnResume=false
Timeout=0
EOF
cp -f "$PROFILE/airootfs/etc/skel/.config/kscreenlockerrc" "$PROFILE/airootfs/root/.config/kscreenlockerrc"

cat > "$PROFILE/airootfs/etc/systemd/system/lolios-live-user.service" <<'EOF'
[Unit]
Description=Prepare LoliOS live user before display manager
After=systemd-sysusers.service systemd-tmpfiles-setup.service local-fs.target
Before=display-manager.service sddm.service graphical.target
Wants=systemd-sysusers.service systemd-tmpfiles-setup.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/lolios-create-live-user
RemainAfterExit=yes
SuccessExitStatus=0

[Install]
WantedBy=multi-user.target
WantedBy=graphical.target
EOF

cat > "$PROFILE/airootfs/etc/systemd/system/display-manager.service.d/10-lolios-live-user.conf" <<'EOF'
[Unit]
Wants=lolios-live-user.service
After=lolios-live-user.service
EOF

ln -sf /etc/systemd/system/lolios-live-user.service \
    "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants/lolios-live-user.service"
ln -sf /etc/systemd/system/lolios-live-user.service \
    "$PROFILE/airootfs/etc/systemd/system/graphical.target.wants/lolios-live-user.service"

# ------------------------------------------------------------
