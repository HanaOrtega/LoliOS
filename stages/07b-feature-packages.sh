# Sourced by ../build.sh; original section: 7B. Integrated 10/10 feature package adjustments

# 7B. Integrated 10/10 feature package adjustments
# ------------------------------------------------------------

log "Adding 10/10 feature package adjustments"

for pkg in \
    python \
    python-pyqt6 \
    inxi \
    lshw \
    dmidecode \
    vulkan-tools \
    mesa-utils \
    smartmontools \
    nvme-cli \
    btrfs-progs \
    snapper \
    snap-pac \
    grub-btrfs \
    pacman-contrib \
    arch-install-scripts \
    qemu-desktop \
    edk2-ovmf \
    shellcheck \
    shfmt \
    zstd \
    tar \
    rsync \
    jq \
    xdg-utils \
    xdg-user-dirs \
    iproute2
 do
    add_pkg "$pkg"
done

# These packages are intentionally excluded because they are obsolete, conflict
# with the selected stack, or are replaced elsewhere. Bottles is not listed here:
# it is built from GitHub into lolios-local and must remain installable offline.
for bad in \
    mesa-vdpau \
    lib32-mesa-vdpau \
    lib32-gst-plugins-base-libs \
    lib32-gst-plugins-good \
    lib32-gst-plugins-bad-libs \
    lib32-gst-plugins-ugly \
    bridge-utils \
    appimagelauncher \
    noise-suppression-for-voice \
    corectrl \
    btrfs-assistant
 do
    remove_pkg "$bad"
done

# Repeat local-repo cleanup after feature adjustments, because some features may re-add package names.
if [ -z "$PREBUILT_REPO_DIR" ] && [ "$USE_AUR_FALLBACK" != "1" ]; then
    log "No prebuilt repo/AUR fallback: enforcing official-repo-only package list"
    for aur_only in \
        calamares \
        ttf-ms-fonts \
        brave-bin \
        rustdesk-bin \
        pycharm-community-jre \
        onlyoffice-bin \
        heroic-games-launcher-bin \
        protonup-qt-bin \
        proton-ge-custom-bin \
        input-remapper \
        yay \
        lact
    do
        remove_pkg "$aur_only"
    done
fi

dedup_packages
prune_slim_packages
prune_missing_local_repo_packages

# ------------------------------------------------------------
