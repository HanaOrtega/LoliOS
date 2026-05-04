# Sourced by ../build.sh; original section: 0. Global config

set -Eeuo pipefail

# ============================================================
# LoliOS Builder v2 Production Pipeline + Clean Workstation
# ============================================================

# Optional local config. Keep secrets and machine-specific paths outside git.
if [ -f "${LOLIOS_PROJECT_ROOT:-.}/config/lolios.env" ]; then
    # shellcheck source=/dev/null
    source "${LOLIOS_PROJECT_ROOT:-.}/config/lolios.env"
fi

ISO_NAME="${ISO_NAME:-lolios}"
ISO_LABEL_PREFIX="${ISO_LABEL_PREFIX:-LOLIOS}"
PRODUCT_NAME="${PRODUCT_NAME:-LoliOS}"
PRODUCT_VERSION="${PRODUCT_VERSION:-2.0-production}"
LOLIOS_FLAVOR="${LOLIOS_FLAVOR:-full}" # full | test

WORKROOT="${WORKROOT:-$HOME/lolios-build-v2}"
PROFILE="${PROFILE:-$WORKROOT/profile}"
CUSTOMREPO="$PROFILE/customrepo"
AURBUILD="${AURBUILD:-$WORKROOT/aur-build}"
OUTDIR="$PROFILE/out"

WALL_SRC="${WALL_SRC:-$HOME/Obrazy/lolios-dark.png}"
WALL_ISO="/usr/share/wallpapers/LoliOS/contents/lolios-dark.png"
PHYSX_EXE="${PHYSX_EXE:-}"

SKIP_AUR="${SKIP_AUR:-0}"
ISO_STAGE="${ISO_STAGE:-${BUILD_ISO:-1}}"
BUILD_ISO="$ISO_STAGE" # legacy alias, kept for older commands
KEEP_WORK="${KEEP_WORK:-0}"
USE_EXISTING_PROFILE="${USE_EXISTING_PROFILE:-0}"
PARALLEL_DOWNLOADS="${PARALLEL_DOWNLOADS:-10}"
SQUASHFS_COMPRESSION_LEVEL="${SQUASHFS_COMPRESSION_LEVEL:-15}"
BOOTSTRAP_COMPRESSION_LEVEL="${BOOTSTRAP_COMPRESSION_LEVEL:-19}"

# Host cleanup safety. Default behavior must not kill host processes or force
# unmounts on normal exit. Enable only for a known-stale interrupted build.
LOLIOS_KILL_OLD_BUILDS="${LOLIOS_KILL_OLD_BUILDS:-0}"
LOLIOS_FORCE_UNMOUNT_ON_EXIT="${LOLIOS_FORCE_UNMOUNT_ON_EXIT:-0}"

# Binary repo / release engineering
# Recommended mode for stable builds:
#   PREBUILT_REPO_DIR=/srv/lolios-repo REPO_SIGN=1 GPG_KEY_ID="YOURKEY" ./build.sh
# Prototype/local mode:
#   USE_AUR_FALLBACK=1 ./build.sh
PREBUILT_REPO_DIR="${PREBUILT_REPO_DIR:-}"
USE_AUR_FALLBACK="${USE_AUR_FALLBACK:-1}"
REPO_SIGN="${REPO_SIGN:-0}"
GPG_KEY_ID="${GPG_KEY_ID:-}"
REPO_NAME="${REPO_NAME:-lolios-local}"
ALLOW_INSTALLERLESS_ISO="${ALLOW_INSTALLERLESS_ISO:-0}"

# Optional post-build QEMU smoke test
QEMU_SMOKE_TEST="${QEMU_SMOKE_TEST:-0}"
QEMU_GUI_TEST="${QEMU_GUI_TEST:-0}"
QEMU_MEMORY="${QEMU_MEMORY:-4096}"
QEMU_CPUS="${QEMU_CPUS:-2}"
QEMU_TIMEOUT="${QEMU_TIMEOUT:-90}"

# v2 production pipeline controls
REPO_STAGE="${REPO_STAGE:-1}"
FORCE_REPO_REBUILD="${FORCE_REPO_REBUILD:-0}"
REPO_DIR="${REPO_DIR:-$WORKROOT/repo}"
AUR_ROOT="${AUR_ROOT:-$WORKROOT/aur}"
AUR_SRC_DIR="${AUR_SRC_DIR:-$AUR_ROOT/src}"
AUR_BUILD_DIR="${AUR_BUILD_DIR:-$AUR_ROOT/build}"
LOG_DIR="${LOG_DIR:-$WORKROOT/logs}"
CACHE_DIR="${CACHE_DIR:-$WORKROOT/cache}"
MANIFEST_DIR="${MANIFEST_DIR:-$WORKROOT/manifest}"
LOCKFILE="${LOCKFILE:-$WORKROOT/.build.lock}"
BUILD_ID="${BUILD_ID:-$(date +%Y%m%d-%H%M%S)}"
ARCH_SNAPSHOT_DATE="${ARCH_SNAPSHOT_DATE:-}"
AUR_BUILD_MODE="${AUR_BUILD_MODE:-host}" # host | clean-chroot
CLEAN_CHROOT_DIR="${CLEAN_CHROOT_DIR:-$WORKROOT/chroot}"
MAIN_LOG="${MAIN_LOG:-$LOG_DIR/build-$BUILD_ID.log}"

# game-devices-udev upstream/source handling.
INCLUDE_GAME_DEVICES_UDEV="${INCLUDE_GAME_DEVICES_UDEV:-1}"
REQUIRE_GAME_DEVICES_UDEV="${REQUIRE_GAME_DEVICES_UDEV:-0}"
GAME_DEVICES_UDEV_PKGNAME="${GAME_DEVICES_UDEV_PKGNAME:-lolios-game-devices-udev}"
GAME_DEVICES_UDEV_REF="${GAME_DEVICES_UDEV_REF:-}"

case "$LOLIOS_FLAVOR" in
    full|test|minimal) ;;
    *) echo "[ERROR] Unknown LOLIOS_FLAVOR=$LOLIOS_FLAVOR" >&2; exit 1 ;;
esac

# ------------------------------------------------------------
