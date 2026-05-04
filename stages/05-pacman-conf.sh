# Sourced by ../build.sh; original section: 5. pacman.conf

# 5. pacman.conf
# ------------------------------------------------------------

log "Writing pacman.conf"

cat > "$PROFILE/pacman.conf" <<EOF
[options]
Architecture = auto
CheckSpace
ParallelDownloads = $PARALLEL_DOWNLOADS
Color
ILoveCandy
SigLevel = Required DatabaseOptional
LocalFileSigLevel = Optional

# LoliOS ships its own theme as an additional theme. Do not block or overwrite
# upstream KDE/Breeze themes from Plasma packages; users must be able to switch
# back to default KDE themes normally.

# mkarchiso/pacstrap runs package transactions in a chroot without a working
# desktop D-Bus session. PackageKit and AppStream post-transaction hooks try to
# contact services that are not activatable there and produce noisy hook errors.
# The installed system can rebuild these caches normally after first boot/update.
NoExtract = usr/share/libalpm/hooks/*PackageKit*.hook
NoExtract = usr/share/libalpm/hooks/*packagekit*.hook
NoExtract = usr/share/libalpm/hooks/*appstream*.hook
NoExtract = usr/share/libalpm/hooks/*AppStream*.hook
NoExtract = usr/share/libalpm/hooks/90-packagekit-refresh.hook
NoExtract = usr/share/libalpm/hooks/90-appstream-cache.hook

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

[multilib]
Include = /etc/pacman.d/mirrorlist

[$REPO_NAME]
SigLevel = Optional TrustAll
Server = file://$CUSTOMREPO
EOF
apply_snapshot_to_profile_pacman_conf

# ------------------------------------------------------------
