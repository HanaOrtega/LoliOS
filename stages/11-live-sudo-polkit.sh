# Sourced by ../build.sh; original section: 11. Live-only sudo / polkit

# 11. Live-only sudo / polkit
# ------------------------------------------------------------

log "Writing live-only sudo and polkit rules"

mkdir -p "$PROFILE/airootfs/etc/sudoers.d"
mkdir -p "$PROFILE/airootfs/etc/polkit-1/rules.d"

cat > "$PROFILE/airootfs/etc/sudoers.d/99-lolios-live" <<'EOF'
# LIVE ISO ONLY - removed from installed system by /root/postinstall.sh
%wheel ALL=(ALL:ALL) NOPASSWD: ALL
live ALL=(ALL:ALL) NOPASSWD: ALL
root ALL=(ALL:ALL) NOPASSWD: ALL
EOF
chmod 0440 "$PROFILE/airootfs/etc/sudoers.d/99-lolios-live"

cat > "$PROFILE/airootfs/etc/polkit-1/rules.d/49-lolios-live-admin.rules" <<'EOF'
// LIVE ISO ONLY - removed from installed system by /root/postinstall.sh
polkit.addRule(function(action, subject) {
    if (subject.user == "live" || subject.user == "root" || subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF

# GameMode polkit, acceptable for installed gaming system.
cat > "$PROFILE/airootfs/etc/polkit-1/rules.d/10-gamemode.rules" <<'EOF'
polkit.addRule(function(action, subject) {
    if (action.id == "org.feralinteractive.GameMode.governor-control" ||
        action.id == "org.feralinteractive.GameMode.gpu-control") {
        return polkit.Result.YES;
    }
});
EOF

# ------------------------------------------------------------
