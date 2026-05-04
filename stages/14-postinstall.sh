# Sourced by ../build.sh; original section: 14. Postinstall

# 14. Postinstall
# ------------------------------------------------------------

log "Writing postinstall"

mkdir -p "$PROFILE/airootfs/root"

cat > "$PROFILE/airootfs/root/postinstall.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

LOG="/var/log/lolios-postinstall.log"
mkdir -p /var/log
exec > >(tee -a "$LOG") 2>&1

echo "[LOLIOS] postinstall started"
rm -f /etc/lolios-live || true

fail() {
    echo "[LOLIOS][ERROR] $*" >&2
    exit 1
}

remove_legacy_lolios_kde_noextract() {
    local conf="/etc/pacman.conf" tmp
    [ -f "$conf" ] || return 0
    tmp="$(mktemp)"
    awk '
BEGIN { skip_comment=0 }
/^# LoliOS KDE theme ownership$/ { skip_comment=1; next }
skip_comment && /^# LoliOS provides the Plasma Global Theme/ { next }
skip_comment && /^# Do not let future plasma-workspace/ { next }
skip_comment && /^NoExtract = usr\/share\/plasma\/look-and-feel\/org\.kde\.\*/ { next }
skip_comment && /^NoExtract = usr\/share\/plasma\/desktoptheme\/breeze\/\*/ { next }
skip_comment && /^NoExtract = usr\/share\/plasma\/desktoptheme\/breeze-dark\/\*/ { next }
skip_comment && /^NoExtract = usr\/share\/plasma\/desktoptheme\/oxygen\/\*/ { next }
skip_comment && /^NoExtract = usr\/share\/sddm\/themes\/breeze\/\*/ { skip_comment=0; next }
/^NoExtract = usr\/share\/plasma\/look-and-feel\/org\.kde\.\*/ { next }
/^NoExtract = usr\/share\/plasma\/desktoptheme\/breeze\/\*/ { next }
/^NoExtract = usr\/share\/plasma\/desktoptheme\/breeze-dark\/\*/ { next }
/^NoExtract = usr\/share\/plasma\/desktoptheme\/oxygen\/\*/ { next }
/^NoExtract = usr\/share\/sddm\/themes\/breeze\/\*/ { next }
{ skip_comment=0; print }
' "$conf" > "$tmp"
    install -m 0644 "$tmp" "$conf"
    rm -f "$tmp"
}

configure_offline_local_repo() {
    if command -v lolios-enable-local-repo >/dev/null 2>&1; then
        LOLIOS_SKIP_PACMAN_SYNC=1 lolios-enable-local-repo --no-sync 2>/dev/null || true
    fi
    local conf="/etc/pacman.conf"
    [ -f "$conf" ] || return 0
    if [ -d /opt/lolios/repo ] && ! grep -q '^\[lolios-local\]' "$conf"; then
        cat >> "$conf" <<'EOCONF'

[lolios-local]
SigLevel = Optional TrustAll
Server = file:///opt/lolios/repo
EOCONF
    fi
}

remove_live_user_from_installed_system() {
    echo "[LOLIOS] removing live user from installed system"
    rm -f /etc/sysusers.d/lolios-live.conf || true
    rm -f /etc/tmpfiles.d/lolios-live.conf || true
    rm -f /etc/systemd/system/lolios-live-user.service || true
    rm -f /etc/systemd/system/multi-user.target.wants/lolios-live-user.service || true
    rm -f /etc/systemd/system/graphical.target.wants/lolios-live-user.service || true
    rm -f /etc/systemd/system/display-manager.service.d/10-lolios-live-user.conf || true

    if id live >/dev/null 2>&1; then
        userdel -r live 2>/dev/null || userdel live 2>/dev/null || true
    fi

    rm -rf /home/live || true

    for group in nopasswdlogin live; do
        if getent group "$group" >/dev/null 2>&1; then
            if ! getent group "$group" | awk -F: '{exit ($4 == "" ? 0 : 1)}'; then
                continue
            fi
            groupdel "$group" 2>/dev/null || true
        fi
    done

    sed -i '/^live:/d' /etc/passwd /etc/shadow /etc/group /etc/gshadow 2>/dev/null || true
}

cleanup_sddm_fragments() {
    echo "[LOLIOS] cleaning Live/Calamares SDDM fragments"
    mkdir -p /etc/sddm.conf.d
    rm -f \
        /etc/sddm.conf.d/*live* \
        /etc/sddm.conf.d/*autologin* \
        /etc/sddm.conf.d/*calamares* \
        /etc/sddm.conf.d/*users* \
        /etc/sddm.conf.d/*displaymanager* \
        /etc/sddm.conf.d/00-* \
        /etc/sddm.conf.d/90-* \
        2>/dev/null || true
}

cleanup_live_only_files() {
    remove_live_user_from_installed_system
    cleanup_sddm_fragments
    rm -f /etc/sudoers.d/99-lolios-live || true
    rm -f /etc/polkit-1/rules.d/49-lolios-live-admin.rules || true
    rm -f /usr/share/applications/lolios-installer.desktop || true
    find /home /root -maxdepth 3 -type f -name 'lolios-installer.desktop' -delete 2>/dev/null || true
    find /etc/xdg/autostart /root/.config/autostart /etc/skel/.config/autostart -maxdepth 1 -type f \
        \( -name 'lolios-first-run.desktop' -o -name 'lolios-installer.desktop' -o -name 'calamares.desktop' \) \
        -delete 2>/dev/null || true
}

find_installed_user() {
    awk -F: '$3 >= 1000 && $3 < 60000 && $1 != "live" && $7 !~ /(nologin|false)$/ {print $1; exit}' /etc/passwd
}

user_has_valid_password_hash() {
    local user="$1" hash
    hash="$(awk -F: -v user="$user" '$1 == user {print $2; exit}' /etc/shadow 2>/dev/null || true)"
    case "$hash" in
        \$y\$*|\$gy\$*|\$7\$*|\$6\$*|\$5\$*|\$2a\$*|\$2y\$*) return 0 ;;
        *) return 1 ;;
    esac
}

disable_kde_lock_for_user() {
    local user="$1" home_dir
    [ -n "$user" ] || return 0
    home_dir="$(getent passwd "$user" | cut -d: -f6)"
    [ -n "$home_dir" ] && [ -d "$home_dir" ] || return 0
    mkdir -p "$home_dir/.config"
    cat > "$home_dir/.config/kscreenlockerrc" <<'EOLOCK'
[Daemon]
Autolock=false
LockOnResume=false
Timeout=0
EOLOCK
    chown "$user:$user" "$home_dir/.config/kscreenlockerrc" 2>/dev/null || true
}

configure_sddm() {
    mkdir -p /etc/sddm.conf.d /etc/systemd/system /etc/skel/.config
    local real_user
    real_user="$(find_installed_user || true)"

    cleanup_sddm_fragments

    cat > /etc/skel/.config/kscreenlockerrc <<'EOLOCK'
[Daemon]
Autolock=false
LockOnResume=false
Timeout=0
EOLOCK

    [ -n "$real_user" ] || fail "No Calamares-created desktop user found while configuring installed SDDM."
    user_has_valid_password_hash "$real_user" || fail "Installed user $real_user has no valid password hash."

    echo "[LOLIOS] configuring installed SDDM autologin for Calamares user: $real_user"
    getent group autologin >/dev/null 2>&1 || groupadd -r autologin 2>/dev/null || groupadd autologin 2>/dev/null || true
    usermod -aG autologin "$real_user" 2>/dev/null || true
    disable_kde_lock_for_user "$real_user"
    cat > /etc/sddm.conf <<EOSDDM
[General]
DisplayServer=x11

[Theme]
Current=lolios
CursorTheme=LoliOS
Font=Noto Sans,10,-1,5,50,0,0,0,0,0

[Users]
MaximumUid=60513
MinimumUid=1000
HideUsers=live

[Autologin]
Session=plasma.desktop
User=$real_user
Relogin=false
EOSDDM
    cat > /etc/sddm.conf.d/20-lolios-installed-autologin.conf <<EOSDDM_AUTO
[Autologin]
Session=plasma.desktop
User=$real_user
Relogin=false
EOSDDM_AUTO

    cat > /etc/sddm.conf.d/10-lolios-theme.conf <<'EOSDDM_THEME'
[General]
DisplayServer=x11

[Theme]
Current=lolios
CursorTheme=LoliOS
Font=Noto Sans,10,-1,5,50,0,0,0,0,0

[Users]
MinimumUid=1000
MaximumUid=60513
HideUsers=live
EOSDDM_THEME

    if [ -e /usr/lib/systemd/system/sddm.service ]; then
        ln -sf /usr/lib/systemd/system/sddm.service /etc/systemd/system/display-manager.service
    fi
}

enable_services() {
    configure_sddm
    for svc in NetworkManager.service sddm.service bluetooth.service fstrim.timer cups.service avahi-daemon.service ufw.service libvirtd.service; do
        systemctl enable "$svc" 2>/dev/null || true
    done
}

setup_snapshots() {
    command -v snapper >/dev/null 2>&1 || return 0
    findmnt -n -o FSTYPE / 2>/dev/null | grep -qx btrfs || return 0
    snapper -c root create-config / 2>/dev/null || echo "[LOLIOS][WARN] snapper root config failed; continuing"
    systemctl enable snapper-timeline.timer 2>/dev/null || true
    systemctl enable snapper-cleanup.timer 2>/dev/null || true
    systemctl list-unit-files 2>/dev/null | grep -q '^grub-btrfsd.service' && systemctl enable grub-btrfsd.service 2>/dev/null || true
}

apply_gpu_profile() {
    command -v lolios-gpu-profile >/dev/null 2>&1 || return 0
    local gpu_info has_intel=0 has_amd=0 has_nvidia=0 is_laptop=0
    gpu_info="$(lspci 2>/dev/null || true)"
    echo "$gpu_info" | grep -qi "Intel" && has_intel=1 || true
    echo "$gpu_info" | grep -qiE "AMD|ATI" && has_amd=1 || true
    echo "$gpu_info" | grep -qi "NVIDIA" && has_nvidia=1 || true
    [ -d /sys/class/power_supply ] && ls /sys/class/power_supply 2>/dev/null | grep -qiE '^BAT|BAT[0-9]' && is_laptop=1 || true
    if [ "$has_nvidia" = "1" ] && [ "$is_laptop" = "1" ]; then lolios-gpu-profile nvidia-laptop || true
    elif [ "$has_nvidia" = "1" ]; then lolios-gpu-profile nvidia-desktop || true
    elif [ "$has_amd" = "1" ]; then lolios-gpu-profile amd || true
    elif [ "$has_intel" = "1" ]; then lolios-gpu-profile intel || true
    fi
}

write_gaming_sysctl() {
    mkdir -p /etc/sysctl.d
    cat > /etc/sysctl.d/90-lolios-gaming.conf <<'EOSYSCTL'
vm.max_map_count = 2147483642
EOSYSCTL
}

copy_kernel_from_modules() {
    local pkgbase="$1" target="$2" dir src
    [ -r "$target" ] && return 0
    for dir in /usr/lib/modules/*; do
        [ -d "$dir" ] || continue
        [ -f "$dir/pkgbase" ] || continue
        [ "$(cat "$dir/pkgbase" 2>/dev/null || true)" = "$pkgbase" ] || continue
        for src in "$dir/vmlinuz" "$dir/vmlinux" "$dir/Image"; do
            if [ -r "$src" ]; then
                echo "[LOLIOS] restoring $target from $src"
                install -Dm644 "$src" "$target"
                return 0
            fi
        done
    done
    return 1
}

write_installed_mkinitcpio_config() {
    echo "[LOLIOS] writing installed-system mkinitcpio config"
    rm -f /etc/mkinitcpio.conf.d/archiso.conf
    rm -f /etc/mkinitcpio.d/linux.preset
    cat > /etc/mkinitcpio.conf <<'EOMK'
MODULES=(btrfs ext4 xfs f2fs vfat ahci nvme sd_mod virtio_pci virtio_blk virtio_scsi virtio_net)
BINARIES=()
FILES=()
HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)
COMPRESSION="zstd"
EOMK
}

write_kernel_preset_if_kernel_exists() {
    local name="$1" kernel="$2" initrd="$3" fallback="$4"
    [ -r "$kernel" ] || return 0
    cat > "/etc/mkinitcpio.d/${name}.preset" <<EOF_PRESET
# mkinitcpio preset generated by LoliOS postinstall
ALL_config="/etc/mkinitcpio.conf"
ALL_kver="$kernel"

PRESETS=('default' 'fallback')

default_image="$initrd"
default_options="--splash /usr/share/systemd/bootctl/splash-arch.bmp"

fallback_image="$fallback"
fallback_options="-S autodetect"
EOF_PRESET
}

validate_mkinitcpio_presets() {
    echo "[LOLIOS] validating mkinitcpio presets"
    local preset kernel valid=0
    rm -f /etc/mkinitcpio.d/linux.preset
    for preset in /etc/mkinitcpio.d/*.preset; do
        [ -f "$preset" ] || continue
        kernel="$(awk -F= '/^[[:space:]]*ALL_kver=/{gsub(/["[:space:]]/, "", $2); print $2; exit}' "$preset" 2>/dev/null || true)"
        [ -n "$kernel" ] || fail "mkinitcpio preset $preset has no ALL_kver."
        [ -r "$kernel" ] || fail "mkinitcpio preset $preset points to unreadable kernel: $kernel"
        valid=$((valid + 1))
    done
    [ "$valid" -gt 0 ] || fail "No valid mkinitcpio presets found."
}

repair_boot_kernels_and_presets() {
    echo "[LOLIOS] repairing installed /boot kernel files and mkinitcpio presets"
    mkdir -p /boot /etc/mkinitcpio.d
    copy_kernel_from_modules linux-zen /boot/vmlinuz-linux-zen || true
    copy_kernel_from_modules linux-lts /boot/vmlinuz-linux-lts || true
    write_installed_mkinitcpio_config
    write_kernel_preset_if_kernel_exists linux-zen /boot/vmlinuz-linux-zen /boot/initramfs-linux-zen.img /boot/initramfs-linux-zen-fallback.img
    write_kernel_preset_if_kernel_exists linux-lts /boot/vmlinuz-linux-lts /boot/initramfs-linux-lts.img /boot/initramfs-linux-lts-fallback.img
    validate_mkinitcpio_presets
}

mount_esp_from_fstab() {
    local mp="$1"
    [ -n "$mp" ] || return 1
    mkdir -p "$mp"
    if ! findmnt "$mp" >/dev/null 2>&1 && grep -Eq "^[^#][[:space:]]+$mp[[:space:]]+" /etc/fstab 2>/dev/null; then
        echo "[LOLIOS] mounting possible ESP from fstab at $mp"
        mount "$mp" || true
    fi
    findmnt "$mp" >/dev/null 2>&1
}

is_valid_esp() {
    local mp="$1" fstype src
    mount_esp_from_fstab "$mp" || return 1
    fstype="$(findmnt -n -o FSTYPE "$mp" 2>/dev/null || true)"
    src="$(findmnt -n -o SOURCE "$mp" 2>/dev/null || true)"
    case "$fstype" in
        vfat|fat|msdos) ;;
        *) echo "[LOLIOS][WARN] $mp is mounted as $fstype, not FAT/vfat; not using as ESP"; return 1 ;;
    esac
    [ -n "$src" ] || return 1
    mkdir -p "$mp/EFI"
    return 0
}

find_efi_dir() {
    local candidate
    for candidate in /boot/efi /efi /boot; do
        if is_valid_esp "$candidate"; then echo "$candidate"; return 0; fi
    done
    awk '$1 !~ /^#/ && ($3 == "vfat" || $3 == "fat" || $3 == "msdos") {print $2}' /etc/fstab 2>/dev/null | while read -r candidate; do
        [ -n "$candidate" ] || continue
        if is_valid_esp "$candidate"; then echo "$candidate"; exit 0; fi
    done
}

find_bios_disk() {
    local root_src pk disk
    root_src="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
    [ -n "$root_src" ] || return 1
    pk="$(lsblk -no PKNAME "$root_src" 2>/dev/null | head -n1 || true)"
    if [ -n "$pk" ] && [ -b "/dev/$pk" ]; then echo "/dev/$pk"; return 0; fi
    disk="$(lsblk -ndo NAME,TYPE | awk '$2 == "disk" {print "/dev/"$1; exit}')"
    [ -n "$disk" ] && [ -b "$disk" ] && echo "$disk"
}

install_lolios_grub() {
    command -v grub-install >/dev/null 2>&1 || fail "grub-install missing"
    command -v grub-mkconfig >/dev/null 2>&1 || fail "grub-mkconfig missing"
    mkdir -p /boot/grub
    rm -f /tmp/lolios-grub-install.log

    if [ -d /sys/firmware/efi ]; then
        local efi_dir
        efi_dir="$(find_efi_dir | head -n1 || true)"
        [ -n "$efi_dir" ] || fail "UEFI detected but no valid mounted FAT/vfat EFI System Partition found."
        mkdir -p "$efi_dir/EFI" /boot/grub
        echo "[LOLIOS] installing GRUB UEFI to validated ESP: $efi_dir"

        if grub-install --target=x86_64-efi --efi-directory="$efi_dir" --bootloader-id=LoliOS --recheck 2>>/tmp/lolios-grub-install.log; then
            echo "[LOLIOS] GRUB UEFI install with NVRAM succeeded"
        elif grub-install --target=x86_64-efi --efi-directory="$efi_dir" --bootloader-id=LoliOS --recheck --no-nvram 2>>/tmp/lolios-grub-install.log; then
            echo "[LOLIOS] GRUB UEFI install with --no-nvram succeeded"
        else
            cat /tmp/lolios-grub-install.log >&2 || true
            fail "GRUB UEFI install failed"
        fi
        grub-install --target=x86_64-efi --efi-directory="$efi_dir" --bootloader-id=LoliOS --removable --recheck --no-nvram 2>>/tmp/lolios-grub-install.log || true
        [ -f "$efi_dir/EFI/LoliOS/grubx64.efi" ] || [ -f "$efi_dir/EFI/BOOT/BOOTX64.EFI" ] || fail "GRUB UEFI files were not created under $efi_dir/EFI"
    else
        local disk
        disk="$(find_bios_disk || true)"
        [ -n "$disk" ] && [ -b "$disk" ] || fail "BIOS install: cannot determine target disk."
        echo "[LOLIOS] installing GRUB BIOS to $disk"
        grub-install --target=i386-pc "$disk" --recheck 2>>/tmp/lolios-grub-install.log || { cat /tmp/lolios-grub-install.log >&2 || true; fail "GRUB BIOS install failed"; }
    fi

    grub-mkconfig -o /boot/grub/grub.cfg
    [ -s /boot/grub/grub.cfg ] || fail "/boot/grub/grub.cfg was not created"
}

installed_sanity_check() {
    echo "[LOLIOS] running final installed-system sanity check"
    local real_user configured_user
    real_user="$(find_installed_user || true)"
    [ -n "$real_user" ] || fail "Final sanity: no real installed user exists."
    user_has_valid_password_hash "$real_user" || fail "Final sanity: installed user $real_user has no valid password hash."
    ! id live >/dev/null 2>&1 || fail "Final sanity: live user still exists."
    [ ! -e /etc/lolios-live ] || fail "Final sanity: /etc/lolios-live still exists."
    ! grep -R 'User=live' /etc/sddm.conf /etc/sddm.conf.d 2>/dev/null || fail "Final sanity: SDDM still references User=live."
    configured_user="$(awk -F= '/^[[:space:]]*User=/{gsub(/[[:space:]]/, "", $2); print $2; exit}' /etc/sddm.conf.d/20-lolios-installed-autologin.conf /etc/sddm.conf 2>/dev/null || true)"
    [ "$configured_user" = "$real_user" ] || fail "Final sanity: SDDM autologin user '$configured_user' != installed user '$real_user'."
    [ -s /boot/grub/grub.cfg ] || fail "Final sanity: grub.cfg missing or empty."
    ! grep -R '^NoExtract = usr/share/plasma/look-and-feel/org\.kde\.\*' /etc/pacman.conf 2>/dev/null || fail "Final sanity: legacy KDE theme NoExtract still blocks upstream KDE themes."
    echo "[LOLIOS] final installed-system sanity check passed"
}

configure_offline_local_repo
remove_legacy_lolios_kde_noextract
cleanup_live_only_files
enable_services
setup_snapshots
apply_gpu_profile
write_gaming_sysctl
repair_boot_kernels_and_presets

echo "[LOLIOS] regenerating installed-system initramfs"
validate_mkinitcpio_presets
mkinitcpio -P

echo "[LOLIOS] installing bootloader"
install_lolios_grub
installed_sanity_check

echo "[LOLIOS] postinstall done"
EOF
chmod +x "$PROFILE/airootfs/root/postinstall.sh"

# ------------------------------------------------------------
