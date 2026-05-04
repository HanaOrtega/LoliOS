# Sourced by ../build.sh; original section: 13. Calamares

# 13. Calamares
# ------------------------------------------------------------

log "Writing Calamares config"

CALAMARES_MIN_STORAGE_GB="${LOLIOS_MIN_STORAGE_GB:-60}"
case "$CALAMARES_MIN_STORAGE_GB" in
    ''|*[!0-9]*) die "LOLIOS_MIN_STORAGE_GB must be a positive integer, got: $CALAMARES_MIN_STORAGE_GB" ;;
esac
[ "$CALAMARES_MIN_STORAGE_GB" -ge 20 ] || die "LOLIOS_MIN_STORAGE_GB is too small for LoliOS: $CALAMARES_MIN_STORAGE_GB"

rm -rf "$PROFILE/airootfs/etc/calamares"
mkdir -p "$PROFILE/airootfs/etc/calamares/modules"
mkdir -p "$PROFILE/airootfs/etc/calamares/branding/default"

cat > "$PROFILE/airootfs/etc/calamares/settings.conf" <<'EOF'
---
modules-search: [ local, /usr/lib/calamares/modules ]
branding: default
prompt-install: false
dont-chroot: false
oem-setup: false
disable-cancel: false
disable-cancel-during-exec: false
hide-back-and-next-during-exec: false
quit-at-end: false

sequence:
  - show:
    - welcome
    - locale
    - keyboard
    - partition
    - users
    - summary

  - exec:
    - partition
    - mount
    - unpackfs
    - machineid
    - fstab
    - locale
    - keyboard
    - localecfg
    - users
    # SDDM is configured by /root/postinstall.sh. The Calamares displaymanager
    # Python module is skipped because it is version-sensitive and has failed on
    # Calamares 3.4.x with "invalid main script" exceptions.
    - networkcfg
    - hwclock
    # Bootloader is installed by /root/postinstall.sh.
    # The Calamares bootloader module is skipped because it is fragile on mixed UEFI layouts.
    # shellprocess first validates the Calamares-created account, then runs the
    # full postinstall. If the account has no usable password, installation aborts.
    - shellprocess
    - umount

  - show:
    - finished
EOF

cp "$WALL_SRC" "$PROFILE/airootfs/etc/calamares/branding/default/welcome.png"
cp "$WALL_SRC" "$PROFILE/airootfs/etc/calamares/branding/default/logo.png"

cat > "$PROFILE/airootfs/etc/calamares/branding/default/branding.desc" <<EOF
---
componentName: default
welcomeStyleCalamares: false
windowExpanding: normal
windowPlacement: center
sidebar: widget
navigation: widget
slideshowAPI: 2
slideshow: show.qml

strings:
  productName: "LoliOS"
  shortProductName: "LoliOS"
  version: "${PRODUCT_VERSION}"
  shortVersion: "${PRODUCT_VERSION%%-*}"
  versionedName: "LoliOS ${PRODUCT_VERSION}"
  shortVersionedName: "LoliOS ${PRODUCT_VERSION%%-*}"
  bootloaderEntryName: "LoliOS"

images:
  productLogo: "logo.png"
  productIcon: "logo.png"
  productWelcome: "welcome.png"

style:
  sidebarBackground: "#111018"
  sidebarText: "#f5e9ff"
  sidebarTextSelect: "#ffffff"
  sidebarTextHighlight: "#c92dff"
EOF

cat > "$PROFILE/airootfs/etc/calamares/branding/default/show.qml" <<'EOF'
import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    anchors.fill: parent

    Rectangle { anchors.fill: parent; color: "#111018" }

    Image {
        anchors.fill: parent
        source: "welcome.png"
        fillMode: Image.PreserveAspectCrop
        opacity: 0.34
    }

    Rectangle { anchors.fill: parent; color: "#66000000" }

    Column {
        anchors.centerIn: parent
        spacing: 16

        Text {
            text: "LoliOS"
            color: "#f5e9ff"
            font.pixelSize: 44
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: "Personal Gaming Workstation"
            color: "#f0d7ff"
            font.pixelSize: 20
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
EOF

for key in productName shortProductName version shortVersion versionedName shortVersionedName bootloaderEntryName; do
    if grep -Eq "^[[:space:]]*$key:[[:space:]]*$" "$PROFILE/airootfs/etc/calamares/branding/default/branding.desc"; then
        die "Calamares branding.desc has empty required key: $key"
    fi
done

cat > "$PROFILE/airootfs/etc/calamares/modules/unpackfs.conf" <<'EOF'
---
unpack:
  - source: "/run/archiso/bootmnt/arch/x86_64/airootfs.sfs"
    sourcefs: "squashfs"
    destination: ""
    exclude:
      - "/dev/*"
      - "/proc/*"
      - "/sys/*"
      - "/run/*"
      - "/tmp/*"
      - "/var/tmp/*"
      - "/mnt/*"
      - "/media/*"
      - "/home/live/.cache/*"
      - "/root/.cache/*"
      - "/var/cache/pacman/pkg/*"
      - "/var/lib/pacman/sync/*"
      - "/var/log/journal/*"
      - "/var/log/calamares/*"
EOF

cat > "$PROFILE/airootfs/etc/calamares/modules/welcome.conf" <<EOF
---
showSupportUrl: false
showKnownIssuesUrl: false
requirements:
  requiredStorage: $CALAMARES_MIN_STORAGE_GB
  requiredRam: 4
  check:
    - storage
    - ram
  required:
    - storage
    - ram
EOF

cat > "$PROFILE/airootfs/etc/calamares/modules/partition.conf" <<EOF
---
requiredStorage: $CALAMARES_MIN_STORAGE_GB
initialPartitioningChoice: erase
userSwapChoices:
  - none
  - small
  - suspend
  - file
  - reuse
EOF

cat > "$PROFILE/airootfs/etc/calamares/modules/displaymanager.conf" <<'EOF'
---
displaymanagers:
  - sddm
basicSetup: false
EOF

cat > "$PROFILE/airootfs/etc/calamares/modules/bootloader.conf" <<'EOF'
---
efiBootLoader: "grub"
kernel: "/boot/vmlinuz-linux-zen"
img: "/boot/initramfs-linux-zen.img"
timeout: 5
EOF

cat > "$PROFILE/airootfs/etc/calamares/modules/users.conf" <<'EOF'
---
defaultGroups:
  - wheel
  - audio
  - video
  - storage
  - power
  - network
  - lp
  - scanner
  - libvirt
  - input
sudoersGroup: wheel
setRootPassword: false
userShell: /bin/bash
# LoliOS handles autologin after installation in /root/postinstall.sh so Calamares
# does not write version-dependent SDDM fragments that can conflict with Live cleanup.
doAutologin: false
# LoliOS installed systems may use SDDM autologin, but the account itself must
# still have a password for sudo, polkit, recovery, lockscreen fallback and admin tasks.
# These keys are intentionally duplicated across Calamares users-module variants;
# unsupported keys are ignored by older versions, supported keys enforce sane UX.
allowEmptyPassword: false
allowWeakPassword: false
passwordRequired: true
requirePassword: true
userPasswordRequired: true
passwordRequirements:
  minLength: 8
  maxLength: 64
  libpwquality: true
EOF

cat > "$PROFILE/airootfs/etc/calamares/modules/shellprocess.conf" <<'EOF'
---
dontChroot: false
timeout: 2400
script:
  - "/root/lolios-calamares-user-check.sh"
  - "/root/postinstall.sh"
EOF

# ------------------------------------------------------------
