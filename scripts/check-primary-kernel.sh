#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

fail=0
ok() { printf '[kernel] OK: %s\n' "$*"; }
bad() { printf '[kernel] BAD: %s\n' "$*" >&2; fail=1; }
require_file() { [ -f "$1" ] && ok "file exists: $1" || bad "missing file: $1"; }
require_grep() {
    local pattern="$1" file="$2" label="$3"
    grep -Eq -- "$pattern" "$file" && ok "$label" || bad "$label"
}
forbid_grep() {
    local pattern="$1" file="$2" label="$3"
    grep -Eq -- "$pattern" "$file" && bad "$label" || ok "$label"
}

# LoliOS policy: linux-zen is the primary kernel. linux-lts may exist only as a
# fallback package/kernel, never as the primary Calamares/bootloader target.

declare -a related_files=(
    build.sh
    stages/07-packages.sh
    stages/09-mkinitcpio.sh
    stages/13-calamares.sh
    stages/14-postinstall.sh
    stages/19-boot-menu.sh
    stages/21-audit.sh
    scripts/check-project.sh
    README.md
)

for file in "${related_files[@]}"; do
    require_file "$file"
done

require_grep '^linux-zen$' stages/07-packages.sh 'packages list contains primary kernel package linux-zen'
require_grep '^linux-zen-headers$' stages/07-packages.sh 'packages list contains linux-zen headers for DKMS/build support'
require_grep '^linux-lts$' stages/07-packages.sh 'packages list may contain linux-lts fallback package'
require_grep '^linux-lts-headers$' stages/07-packages.sh 'packages list may contain linux-lts headers fallback'

require_grep '/boot/vmlinuz-linux-zen' stages/13-calamares.sh 'Calamares bootloader kernel points to linux-zen'
require_grep '/boot/initramfs-linux-zen\.img' stages/13-calamares.sh 'Calamares bootloader initramfs points to linux-zen'
forbid_grep 'kernel:[[:space:]]*"?/boot/vmlinuz-linux-lts"?' stages/13-calamares.sh 'Calamares does not set linux-lts as bootloader kernel'
forbid_grep 'img:[[:space:]]*"?/boot/initramfs-linux-lts\.img"?' stages/13-calamares.sh 'Calamares does not set linux-lts as bootloader initramfs'
forbid_grep 'kernel:[[:space:]]*"?/boot/vmlinuz-linux"?' stages/13-calamares.sh 'Calamares does not set generic linux as bootloader kernel'
forbid_grep 'img:[[:space:]]*"?/boot/initramfs-linux\.img"?' stages/13-calamares.sh 'Calamares does not set generic linux as bootloader initramfs'

require_grep 'Calamares uses linux-zen kernel' stages/21-audit.sh 'audit explicitly validates linux-zen kernel'
require_grep 'Calamares uses linux-zen initramfs' stages/21-audit.sh 'audit explicitly validates linux-zen initramfs'
require_grep '/boot/vmlinuz-linux-zen' stages/21-audit.sh 'audit checks vmlinuz-linux-zen path'
require_grep '/boot/initramfs-linux-zen\.img' stages/21-audit.sh 'audit checks initramfs-linux-zen path'
forbid_grep 'Calamares uses linux-lts' stages/21-audit.sh 'audit does not treat linux-lts as primary Calamares kernel'

# Boot menu may mention fallback kernels, but the project must not point the main
# Calamares-installed system at linux-lts or generic linux.
forbid_grep 'bootloader.*linux-lts|primary.*linux-lts|main.*linux-lts' stages/*.sh scripts/*.sh README.md 'no build script documents linux-lts as primary kernel'
forbid_grep 'vmlinuz-linux-lts.*primary|initramfs-linux-lts.*primary' stages/*.sh scripts/*.sh README.md 'no file marks linux-lts boot artifacts as primary'

# Generated-profile checks are optional: when a profile exists, verify the actual
# installer files that will go into ISO.
PROFILE="${PROFILE:-${WORKROOT:-/home/Hana/lolios-build-v2}/profile}"
if [ -d "$PROFILE" ]; then
    pkgfile="$PROFILE/packages.x86_64"
    calamares_boot="$PROFILE/airootfs/etc/calamares/modules/bootloader.conf"
    if [ -f "$pkgfile" ]; then
        require_grep '^linux-zen$' "$pkgfile" 'generated packages.x86_64 contains linux-zen'
        require_grep '^linux-zen-headers$' "$pkgfile" 'generated packages.x86_64 contains linux-zen-headers'
    fi
    if [ -f "$calamares_boot" ]; then
        require_grep '/boot/vmlinuz-linux-zen' "$calamares_boot" 'generated Calamares bootloader.conf uses vmlinuz-linux-zen'
        require_grep '/boot/initramfs-linux-zen\.img' "$calamares_boot" 'generated Calamares bootloader.conf uses initramfs-linux-zen.img'
        forbid_grep 'vmlinuz-linux-lts|initramfs-linux-lts\.img|vmlinuz-linux"|initramfs-linux\.img' "$calamares_boot" 'generated Calamares bootloader.conf does not use lts/generic as primary'
    fi
fi

exit "$fail"
