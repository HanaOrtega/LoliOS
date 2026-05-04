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

# LoliOS owns KDE Global Theme defaults through the airootfs overlay. Do not
# extract upstream KDE theme packages from official Plasma packages into the ISO.
NoExtract = usr/share/plasma/look-and-feel/org.kde.*
NoExtract = usr/share/plasma/desktoptheme/breeze/*
NoExtract = usr/share/plasma/desktoptheme/breeze-dark/*
NoExtract = usr/share/plasma/desktoptheme/oxygen/*
NoExtract = usr/share/sddm/themes/breeze/*

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
