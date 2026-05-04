# Sourced by ../build.sh; original section: 1. Logging and safety helpers

# 1. Logging and safety helpers
# ------------------------------------------------------------

log() {
    echo
    echo "============================================================"
    echo "[LOLIOS] $*"
    echo "============================================================"
}

warn() {
    echo "[WARN] $*" >&2
}

die() {
    echo "[ERROR] $*" >&2
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Brak programu: $1"
}

require_file() {
    [ -f "$1" ] || die "Brak pliku: $1"
}

require_dir() {
    [ -d "$1" ] || die "Brak katalogu: $1"
}

add_pkg() {
    local pkg="$1"
    grep -qxF "$pkg" "$PROFILE/packages.x86_64" || echo "$pkg" >> "$PROFILE/packages.x86_64"
}

remove_pkg() {
    local pkg="$1"
    sed -i "/^$(printf '%s' "$pkg" | sed 's/[.[\*^$()+?{}|]/\\&/g')$/d" "$PROFILE/packages.x86_64"
}

dedup_packages() {
    awk '
        /^[[:space:]]*#/ { print; next }
        /^[[:space:]]*$/ { print; next }
        !seen[$0]++ { print }
    ' "$PROFILE/packages.x86_64" > "$PROFILE/packages.x86_64.tmp"
    mv "$PROFILE/packages.x86_64.tmp" "$PROFILE/packages.x86_64"
}

safe_ln_service() {
    local service="$1"
    local target_dir="$2"
    mkdir -p "$target_dir"
    [ -e "$target_dir/$service" ] || ln -sf "/usr/lib/systemd/system/$service" "$target_dir/$service"
}

sudo_maybe() {
    if [ "${EUID:-$(id -u)}" -eq 0 ]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
        sudo "$@"
    else
        warn "sudo is not available/non-interactive; skipping privileged command: $*"
        return 0
    fi
}

lolios_work_mounts_exist() {
    local root="$PROFILE/work"
    [ -d "$root" ] || return 1
    if command -v findmnt >/dev/null 2>&1; then
        findmnt -R -n --target "$root" >/dev/null 2>&1
    else
        mount 2>/dev/null | awk -v root="$root" 'index($3, root) == 1 {found=1} END {exit found ? 0 : 1}'
    fi
}

print_lolios_work_mounts() {
    local root="$PROFILE/work"
    [ -d "$root" ] || return 0
    if command -v findmnt >/dev/null 2>&1; then
        findmnt -R --target "$root" 2>/dev/null || true
    else
        mount 2>/dev/null | awk -v root="$root" 'index($3, root) == 1 {print}' || true
    fi
}

pid_belongs_to_lolios_build() {
    local pid="$1"
    local cmdline
    cmdline="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)"
    [ -n "$cmdline" ] || return 1
    case "$cmdline" in
        *"$PROFILE/work"*|*"$WORKROOT"*) return 0 ;;
        *) return 1 ;;
    esac
}

kill_by_exact_name_scoped() {
    local signal="$1"
    local name="$2"
    command -v pgrep >/dev/null 2>&1 || return 0
    pgrep -x "$name" 2>/dev/null | while IFS= read -r pid; do
        [ -n "$pid" ] || continue
        [ "$pid" = "$$" ] && continue
        pid_belongs_to_lolios_build "$pid" || continue
        sudo_maybe kill "$signal" "$pid" >/dev/null 2>&1 || true
    done
}

kill_archiso_processes() {
    if [ "${LOLIOS_KILL_OLD_BUILDS:-0}" != "1" ]; then
        warn "LOLIOS_KILL_OLD_BUILDS=0: not killing host mkarchiso/mksquashfs processes"
        return 0
    fi

    log "Stopping old LoliOS-scoped mkarchiso/mksquashfs processes"
    kill_by_exact_name_scoped -TERM mkarchiso
    kill_by_exact_name_scoped -TERM mksquashfs
    sleep 2
    kill_by_exact_name_scoped -KILL mkarchiso
    kill_by_exact_name_scoped -KILL mksquashfs
}

force_unmount_archiso() {
    if [ "${LOLIOS_FORCE_UNMOUNT_ON_EXIT:-0}" != "1" ]; then
        warn "LOLIOS_FORCE_UNMOUNT_ON_EXIT=0: not unmounting host filesystems"
        return 0
    fi

    log "Force unmounting old ArchISO mounts"

    local root="$PROFILE/work"
    if [ -d "$root" ] && command -v findmnt >/dev/null 2>&1; then
        while IFS= read -r mnt; do
            [ -n "$mnt" ] || continue
            sudo_maybe umount -lf "$mnt" >/dev/null 2>&1 || true
        done < <(findmnt -R -n -o TARGET --target "$root" 2>/dev/null | sort -r || true)
    elif [ -d "$root" ]; then
        while IFS= read -r mnt; do
            [ -n "$mnt" ] || continue
            sudo_maybe umount -lf "$mnt" >/dev/null 2>&1 || true
        done < <(mount 2>/dev/null | awk -v root="$root" 'index($3, root) == 1 {print $3}' | sort -r || true)
    fi

    sudo_maybe umount -R "$PROFILE/work/x86_64/airootfs" >/dev/null 2>&1 || true
    sudo_maybe umount -R "$PROFILE/work" >/dev/null 2>&1 || true
}

clean_build_dirs() {
    log "Cleaning previous ISO build directories"

    if lolios_work_mounts_exist; then
        if [ "${LOLIOS_FORCE_UNMOUNT_ON_EXIT:-0}" = "1" ]; then
            force_unmount_archiso
        else
            warn "Mounted filesystems exist under $PROFILE/work. Refusing automatic unmount to protect host/KIO."
            print_lolios_work_mounts
            die "Unmount manually or run once with LOLIOS_FORCE_UNMOUNT_ON_EXIT=1 after closing file managers/terminals in the work tree."
        fi
    fi

    rm -rf "$PROFILE/work" "$PROFILE/out"
    mkdir -p "$PROFILE/work" "$PROFILE/out"
}

ensure_local_repo_config() {
    log "Ensuring local repo configuration"

    mkdir -p "$CUSTOMREPO"

    if ! grep -q "^\[$REPO_NAME\]" "$PROFILE/pacman.conf" 2>/dev/null; then
        cat >> "$PROFILE/pacman.conf" <<EOF

[$REPO_NAME]
SigLevel = Optional TrustAll
Server = file://$CUSTOMREPO
EOF
    fi
}

prune_unavailable_runtime_packages() {
    log "Pruning packages that must not block ISO build"

    # These are fragile on rolling Arch, deprecated, or already replaced.
    # Bottles is intentionally allowed: it is built from AUR into lolios-local.
    for pkg in \
        appimagelauncher \
        noise-suppression-for-voice \
        corectrl \
        btrfs-assistant \
        mesa-vdpau \
        lib32-mesa-vdpau \
        lib32-gst-plugins-base-libs \
        lib32-gst-plugins-good \
        lib32-gst-plugins-bad-libs \
        lib32-gst-plugins-ugly \
        bridge-utils
    do
        remove_pkg "$pkg"
    done

    if [ -z "$PREBUILT_REPO_DIR" ] && [ "$USE_AUR_FALLBACK" != "1" ]; then
        for pkg in game-devices-udev input-remapper lact; do
            remove_pkg "$pkg"
        done
    fi

    add_pkg "iproute2"
    dedup_packages
}

prune_slim_packages() {
    log "Pruning excluded heavy/duplicate packages"

    [ -f "$PROFILE/packages.x86_64" ] || return 0

    remove_pkg "obs-studio"
    remove_pkg "libreoffice-fresh"
    remove_pkg "qemu-full"

    sed -i '/^haskell-/d' "$PROFILE/packages.x86_64"
    sed -i '/^ghc/d' "$PROFILE/packages.x86_64"

    sed -i '/^qemu-system-/d' "$PROFILE/packages.x86_64"
    sed -i '/^qemu-user/d' "$PROFILE/packages.x86_64"
    sed -i '/^qemu-tests/d' "$PROFILE/packages.x86_64"
    sed -i '/^qemu-block-/d' "$PROFILE/packages.x86_64"
    sed -i '/^qemu-hw-/d' "$PROFILE/packages.x86_64"
    sed -i '/^qemu-audio-/d' "$PROFILE/packages.x86_64"
    sed -i '/^qemu-ui-/d' "$PROFILE/packages.x86_64"

    sed -i '/^akonadi/d' "$PROFILE/packages.x86_64"
    sed -i '/kmail/d' "$PROFILE/packages.x86_64"
    sed -i '/kpim/d' "$PROFILE/packages.x86_64"

    sed -i '/egl-wayland2/d' "$PROFILE/packages.x86_64"
    sed -i '/webrtc-audio-processing-1/d' "$PROFILE/packages.x86_64"

    sed -i '/glusterfs/d' "$PROFILE/packages.x86_64"
    sed -i '/multipath-tools/d' "$PROFILE/packages.x86_64"
    sed -i '/net-snmp/d' "$PROFILE/packages.x86_64"
    sed -i '/rdma-core/d' "$PROFILE/packages.x86_64"
    sed -i '/rpcbind/d' "$PROFILE/packages.x86_64"

    sed -i '/xdg-desktop-portal-gtk/d' "$PROFILE/packages.x86_64"

    dedup_packages
}

add_local_repo_pkg_if_available() {
    local pkg="$1"
    if [ -n "$PREBUILT_REPO_DIR" ] || [ "$USE_AUR_FALLBACK" = "1" ]; then
        add_pkg "$pkg"
    else
        remove_pkg "$pkg"
    fi
}

# ------------------------------------------------------------
