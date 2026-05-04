# Sourced by ../build.sh; final package list normalization

# 7Z. Final package list
# ------------------------------------------------------------

log "Finalizing package list"

ensure_local_repo_config
prune_unavailable_runtime_packages
prune_slim_packages
prune_missing_local_repo_packages

# LoliOS kernels are linux-zen plus linux-lts. Keep the generic linux package out
# of the final profile so its mkinitcpio preset cannot target missing
# /boot/vmlinuz-linux during mkarchiso package installation.
remove_pkg "linux"
remove_pkg "linux-headers"

case "${LOLIOS_FLAVOR:-full}" in
    test|minimal)
        log "Applying LoliOS test/minimal package flavor"
        for pkg in \
            linux-lts \
            linux-lts-headers \
            linux-zen-headers \
            nvidia-dkms \
            opencl-nvidia \
            lib32-opencl-nvidia \
            pycharm-community-jre \
            onlyoffice-bin \
            rustdesk-bin \
            noto-fonts-cjk \
            virt-manager \
            libvirt \
            qemu-desktop \
            edk2-ovmf \
            discover \
            packagekit-qt6
        do
            remove_pkg "$pkg"
        done
        ;;
    full)
        ;;
    *)
        die "Unknown LOLIOS_FLAVOR='${LOLIOS_FLAVOR}'. Use full or test."
        ;;
esac

dedup_packages

refresh_local_repo
if declare -F sync_embedded_local_repo >/dev/null 2>&1; then
    sync_embedded_local_repo
fi

mkdir -p "$MANIFEST_DIR"
cp "$PROFILE/packages.x86_64" "$MANIFEST_DIR/packages-final-$BUILD_ID.x86_64"

log "Final package count: $(grep -Ev '^[[:space:]]*(#|$)' "$PROFILE/packages.x86_64" | wc -l)"

# ------------------------------------------------------------
