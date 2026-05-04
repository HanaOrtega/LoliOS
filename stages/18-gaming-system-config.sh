# Sourced by ../build.sh; original section: 18. Gaming limits / sysctl / module config

# 18. Gaming limits / sysctl / module config
# ------------------------------------------------------------

log "Writing gaming limits and sysctl tuning"

mkdir -p "$PROFILE/airootfs/etc/security/limits.d" "$PROFILE/airootfs/etc/sysctl.d" "$PROFILE/airootfs/etc/modprobe.d"

cat > "$PROFILE/airootfs/etc/security/limits.d/10-lolios-gaming.conf" <<'EOF'
* soft nofile 1048576
* hard nofile 1048576
EOF

cat > "$PROFILE/airootfs/etc/sysctl.d/90-lolios-gaming.conf" <<'EOF'
vm.max_map_count = 2147483642
EOF

cat > "$PROFILE/airootfs/etc/modprobe.d/nvidia-drm.conf" <<'EOF'
options nvidia-drm modeset=1
EOF

# ------------------------------------------------------------
