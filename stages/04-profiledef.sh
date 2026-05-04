# Sourced by ../build.sh; original section: 4. profiledef.sh

# 4. profiledef.sh
# ------------------------------------------------------------

log "Writing profiledef.sh"

cat > "$PROFILE/profiledef.sh" <<EOF
#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="$ISO_NAME"
iso_label="${ISO_LABEL_PREFIX}_\$(date --date="@\${SOURCE_DATE_EPOCH:-\$(date +%s)}" +%Y%m)"
iso_publisher="$PRODUCT_NAME"
iso_application="LoliOS Personal Gaming Workstation"
iso_version="\$(date --date="@\${SOURCE_DATE_EPOCH:-\$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux.mbr'
           'bios.syslinux.eltorito'
           'uefi-x64.systemd-boot.esp'
           'uefi-x64.systemd-boot.eltorito')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '$SQUASHFS_COMPRESSION_LEVEL' '-b' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-$BOOTSTRAP_COMPRESSION_LEVEL')

file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/postinstall.sh"]="0:0:755"
  ["/usr/local/bin/lolios-installer"]="0:0:755"
  ["/usr/local/bin/lolios-set-wallpaper"]="0:0:755"
  ["/usr/local/bin/lolios-activate-kde-theme"]="0:0:755"
  ["/usr/local/bin/lolios-apply-kde-theme"]="0:0:755"
  ["/usr/local/bin/lolios-ensure-plasma-panel"]="0:0:755"
  ["/usr/local/bin/lolios-detect-exe-runtime"]="0:0:755"
  ["/usr/local/bin/lolios-exe-launcher"]="0:0:755"
  ["/usr/local/bin/lolios-exe-runner"]="0:0:755"
  ["/usr/local/bin/lolios-gaming-doctor"]="0:0:755"
  ["/usr/local/bin/lolios-install-physx"]="0:0:755"
  ["/usr/local/bin/lolios-compat-center"]="0:0:755"
  ["/usr/local/bin/lolios-prefix-manager"]="0:0:755"
  ["/usr/local/bin/lolios-gaming-center"]="0:0:755"
  ["/usr/local/bin/lolios-update"]="0:0:755"
  ["/usr/local/bin/lolios-gpu-profile"]="0:0:755"
  ["/usr/local/bin/lolios-repair-installed-system"]="0:0:755"
  ["/usr/local/bin/lolios-enable-local-repo"]="0:0:755"
  ["/usr/local/bin/lolios-validate-packages"]="0:0:755"
  ["/usr/local/bin/lolios-first-run"]="0:0:755"
  ["/usr/local/bin/lolios-setup-snapper"]="0:0:755"
  ["/usr/local/bin/lolios-collect-logs"]="0:0:755"
  ["/usr/local/bin/lolios-install-dotnet-wine"]="0:0:755"
  ["/usr/local/bin/lolios-photoshop-installer"]="0:0:755"
  ["/etc/sudoers.d/99-lolios-live"]="0:0:440"
)
EOF

# ------------------------------------------------------------
