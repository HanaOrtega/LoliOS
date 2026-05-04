# Sourced by ../build.sh; original section: 2. Preflight

# 2. Preflight
# ------------------------------------------------------------

init_v2_runtime
trap cleanup_v2 EXIT INT TERM
log "Preflight checks"
acquire_lock
write_snapshot_mirrorlist_if_needed

if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    die "Nie uruchamiaj tego skryptu jako root. Uruchom jako zwykły użytkownik z sudo."
fi

require_cmd sudo
require_cmd git

if [ -n "$WALL_SRC" ]; then
    require_file "$WALL_SRC"
fi

sudo -v

HOST_DEPS=(
    archiso
    base-devel
    git
    pacman-contrib
    squashfs-tools
    rsync
    gpgme
)

if [ "${RUN_NAMCAP:-0}" = "1" ]; then
    HOST_DEPS+=(namcap)
fi

if [ "$QEMU_SMOKE_TEST" = "1" ] || [ "$QEMU_GUI_TEST" = "1" ]; then
    HOST_DEPS+=(qemu-desktop edk2-ovmf)
fi

log "Installing host build dependencies"
# Use -Syu instead of -Sy to avoid creating a partial-upgrade host state on Arch.
sudo pacman -Syu --needed --noconfirm "${HOST_DEPS[@]}"

# ------------------------------------------------------------
