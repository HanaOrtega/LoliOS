# Sourced by ../build.sh; original section: 9. mkinitcpio archiso

# 9. mkinitcpio archiso
# ------------------------------------------------------------

log "Writing mkinitcpio archiso config"

mkdir -p \
    "$PROFILE/airootfs/etc/mkinitcpio.conf.d" \
    "$PROFILE/airootfs/etc/mkinitcpio.d" \
    "$PROFILE/airootfs/etc/pacman.d/hooks" \
    "$PROFILE/airootfs/usr/bin" \
    "$PROFILE/airootfs/usr/local/bin"

# Hard pre-clean: the stock ArchISO profile may contain /etc/mkinitcpio.d/linux.preset,
# but LoliOS does not install the generic linux package. Leaving this preset causes
# pacman's mkinitcpio hook to fail on /boot/vmlinuz-linux.
rm -f "$PROFILE/airootfs/etc/mkinitcpio.d/linux.preset" || true

cat > "$PROFILE/airootfs/etc/mkinitcpio.conf.d/archiso.conf" <<'EOF'
MODULES=()
BINARIES=()
FILES=()
HOOKS=(base udev microcode modconf kms block filesystems keyboard archiso)
COMPRESSION="zstd"
EOF

# LoliOS boots linux-zen and ships linux-lts as fallback. Some package dependency
# stacks or stale profile state can leave /etc/mkinitcpio.d/linux.preset in the
# image without /boot/vmlinuz-linux. Pacman's mkinitcpio hook then runs:
#   mkinitcpio -k /boot/vmlinuz-linux -c /etc/mkinitcpio.conf.d/archiso.conf ...
# and fails before the ISO is produced. Remove only invalid generic-linux preset
# data before mkinitcpio hooks run; keep linux-zen/linux-lts intact.
cat > "$PROFILE/airootfs/usr/bin/lolios-fix-mkinitcpio-presets" <<'EOF'
#!/usr/bin/env bash
set -u

# Generic Arch linux preset is invalid in LoliOS unless the generic linux kernel
# exists. LoliOS intentionally uses linux-zen + linux-lts.
if [ -f /etc/mkinitcpio.d/linux.preset ] && [ ! -r /boot/vmlinuz-linux ]; then
    rm -f /etc/mkinitcpio.d/linux.preset
fi

for preset in /etc/mkinitcpio.d/*.preset; do
    [ -f "$preset" ] || continue
    kernel="$(awk -F= '/^[[:space:]]*ALL_kver=/{gsub(/["'"'"'[:space:]]/, "", $2); print $2; exit}' "$preset" 2>/dev/null || true)"
    [ -n "$kernel" ] || continue
    case "$kernel" in
        /boot/vmlinuz-linux-zen|/boot/vmlinuz-linux-lts) continue ;;
    esac
    [ -r "$kernel" ] || rm -f "$preset"
done

exit 0
EOF
chmod 0755 "$PROFILE/airootfs/usr/bin/lolios-fix-mkinitcpio-presets"
ln -sf /usr/bin/lolios-fix-mkinitcpio-presets "$PROFILE/airootfs/usr/local/bin/lolios-fix-mkinitcpio-presets"

# Pacman hooks execute in a constrained chroot environment. Use /bin/bash -c as
# the hook executable instead of directly exec'ing a staged /usr/local/bin script;
# this avoids the observed "call to execv failed (Permission denied)" while still
# running before mkinitcpio's own PostTransaction hook.
cat > "$PROFILE/airootfs/etc/pacman.d/hooks/00-lolios-pre-mkinitcpio-preset-cleanup.hook" <<'EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = linux
Target = linux-zen
Target = linux-lts
Target = mkinitcpio

[Action]
Description = Removing invalid generic linux mkinitcpio preset before LoliOS ISO initramfs generation...
When = PreTransaction
Exec = /bin/bash -c '/usr/bin/lolios-fix-mkinitcpio-presets || { rm -f /etc/mkinitcpio.d/linux.preset; exit 0; }'
EOF

cat > "$PROFILE/airootfs/etc/pacman.d/hooks/00-lolios-post-mkinitcpio-preset-cleanup.hook" <<'EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = linux
Target = linux-zen
Target = linux-lts
Target = mkinitcpio

[Action]
Description = Removing invalid generic linux mkinitcpio preset after package transaction...
When = PostTransaction
Exec = /bin/bash -c '/usr/bin/lolios-fix-mkinitcpio-presets || { rm -f /etc/mkinitcpio.d/linux.preset; exit 0; }'
EOF

# Also mask the exact invalid preset in the profile overlay so any later stage that
# accidentally recreates it will be caught during audit/finalization.
rm -f "$PROFILE/airootfs/etc/mkinitcpio.d/linux.preset" || true

# ------------------------------------------------------------
