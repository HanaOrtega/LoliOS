# Sourced by ../build.sh; original section: 7. packages.x86_64

# 7. packages.x86_64
# ------------------------------------------------------------

log "Writing packages.x86_64"

cat > "$PROFILE/packages.x86_64" <<'EOF'
# ------------------------------------------------------------
# Base system
# ------------------------------------------------------------
base
base-devel
linux-zen
linux-zen-headers
linux-lts
linux-lts-headers
linux-firmware
mkinitcpio
mkinitcpio-archiso
archlinux-keyring

# ------------------------------------------------------------
# Boot / ISO / installer base
# ------------------------------------------------------------
grub
efibootmgr
syslinux
memtest86+
memtest86+-efi
edk2-shell
squashfs-tools
arch-install-scripts
pacman-contrib
reflector

# ------------------------------------------------------------
# CPU microcode
# ------------------------------------------------------------
amd-ucode
intel-ucode

# ------------------------------------------------------------
# Filesystems / storage
# ------------------------------------------------------------
e2fsprogs
dosfstools
ntfs-3g
exfatprogs
parted
gptfdisk
btrfs-progs
xfsprogs
f2fs-tools
cryptsetup
lvm2
smartmontools
hdparm
nvme-cli

# ------------------------------------------------------------
# Network
# ------------------------------------------------------------
networkmanager
network-manager-applet
wget
curl
openssh
avahi
nss-mdns

# ------------------------------------------------------------
# Core desktop services
# ------------------------------------------------------------
sudo
polkit
kdesu
nano
vim
less
bash-completion
dbus
xdg-utils
xdg-user-dirs
desktop-file-utils
git
rsync
unzip
p7zip
zip
htop
btop
fastfetch
pciutils
usbutils
lsof
which
ripgrep
jq
libpwquality
tk

# ------------------------------------------------------------
# Audio / PipeWire
# ------------------------------------------------------------
pipewire
pipewire-alsa
pipewire-pulse
pipewire-jack
wireplumber
alsa-utils
pavucontrol
helvum
qpwgraph
easyeffects
lib32-pipewire
lib32-alsa-lib
lib32-alsa-plugins
lib32-libpulse
lib32-openal

# ------------------------------------------------------------
# Graphics / Vulkan / VAAPI / VDPAU / OpenCL
# ------------------------------------------------------------
mesa
lib32-mesa
vulkan-icd-loader
lib32-vulkan-icd-loader
vulkan-tools
mesa-utils
vulkan-radeon
lib32-vulkan-radeon
vulkan-intel
lib32-vulkan-intel
libva
lib32-libva
libvdpau
lib32-libvdpau
libva-mesa-driver
lib32-libva-mesa-driver
opencl-headers
ocl-icd

# NVIDIA DKMS stack for linux-zen/linux-lts
nvidia-dkms
nvidia-utils
lib32-nvidia-utils
nvidia-settings
nvidia-prime
opencl-nvidia
lib32-opencl-nvidia

# ------------------------------------------------------------
# Xorg / Wayland base
# ------------------------------------------------------------
xorg-server
xorg-xwayland
xorg-xauth
xorg-xrandr
xorg-xinput
xorg-xdpyinfo
wayland
wayland-utils
xf86-input-libinput
xterm

# ------------------------------------------------------------
# KDE Plasma desktop - explicit stack, no broad meta packages
# ------------------------------------------------------------
plasma-workspace
plasma-desktop
kwin
kglobalacceld
kscreen
powerdevil
kmenuedit
breeze
breeze-icons
hicolor-icon-theme
sddm
konsole
dolphin
kate
kcalc
kdialog
kde-cli-tools
plasma-nm
plasma-pa
plasma-firewall
bluedevil
systemsettings
spectacle
ark
gwenview
partitionmanager
print-manager
plasma-disks
kinfocenter
xdg-desktop-portal
xdg-desktop-portal-kde

# ------------------------------------------------------------
# GTK/libadwaita runtime for Bottles and mixed desktop apps
# ------------------------------------------------------------
gtk4
gtksourceview5
libadwaita
libportal-gtk4
python-gobject
python-cairo
python-orjson
imagemagick

# ------------------------------------------------------------
# Calamares installer
# ------------------------------------------------------------
calamares
kpmcore
qt6-svg
qt6-tools
yaml-cpp

# ------------------------------------------------------------
# Fonts
# ------------------------------------------------------------
noto-fonts
noto-fonts-cjk
noto-fonts-emoji
ttf-dejavu
ttf-hack
ttf-liberation
ttf-carlito
ttf-caladea
ttf-ms-fonts

# ------------------------------------------------------------
# Browsers / apps / productivity
# ------------------------------------------------------------
brave-bin
gimp
transmission-qt
tor
torbrowser-launcher
gnupg
kleopatra
kgpg
rustdesk-bin
pycharm-community-jre
onlyoffice-bin

# ------------------------------------------------------------
# Gaming core
# ------------------------------------------------------------
steam
steam-devices
lolios-game-devices-udev
lutris
bottles
heroic-games-launcher-bin
wine
wine-mono
wine-gecko
winetricks
protontricks
protonup-qt-bin
proton-ge-custom-bin
gamescope
gamemode
lib32-gamemode
mangohud
lib32-mangohud
goverlay
sdl2-compat
lib32-sdl2-compat
cabextract

# ------------------------------------------------------------
# Game/runtime compatibility libraries
# ------------------------------------------------------------
lib32-gnutls
lib32-mpg123
lib32-v4l-utils

# ------------------------------------------------------------
# Multimedia / capture / streaming
# ------------------------------------------------------------
ffmpeg
gst-libav
gst-plugins-base
gst-plugins-good
gst-plugins-bad
gst-plugins-ugly
gst-plugin-pipewire
vlc
mpv
v4l-utils

# ------------------------------------------------------------
# Bluetooth / controllers / input
# ------------------------------------------------------------
bluez
bluez-utils
blueman
antimicrox

# ------------------------------------------------------------
# App integration
# ------------------------------------------------------------
fuse2
fuse3

# ------------------------------------------------------------
# Virtualization / Windows interoperability / file sharing
# ------------------------------------------------------------
virt-manager
libvirt
dnsmasq
iproute2
spice-vdagent
samba
cifs-utils

# ------------------------------------------------------------
# Printing / scanning
# ------------------------------------------------------------
cups
system-config-printer
sane
simple-scan
ipp-usb

# ------------------------------------------------------------
# Phone / device integration
# ------------------------------------------------------------
kdeconnect
android-tools
mtpfs
gvfs-mtp
ifuse
libimobiledevice

# ------------------------------------------------------------
# Maintenance / updates / rollback
# ------------------------------------------------------------
ufw
gufw
timeshift
snapper
snap-pac
grub-btrfs
fwupd
discover
packagekit-qt6

# ------------------------------------------------------------
# Hardware monitoring / tuning
# ------------------------------------------------------------
lm_sensors
nvtop
radeontop
intel-gpu-tools

# ------------------------------------------------------------
# AUR helper
# ------------------------------------------------------------
yay
EOF

for bad in \
    plasma-meta \
    kde-system-meta \
    appimagelauncher \
    noise-suppression-for-voice \
    corectrl \
    btrfs-assistant \
    archiso-calamares-config \
    calamares-settings-arch \
    plasma-wayland-session \
    mintstick \
    flatpak \
    flatpak-kcm \
    game-devices-udev \
    input-remapper \
    lact \
    nvidia \
    wine-staging \
    wine-ge-custom \
    mesa-vdpau \
    lib32-mesa-vdpau \
    lib32-gst-plugins-base-libs \
    lib32-gst-plugins-good \
    lib32-gst-plugins-bad-libs \
    lib32-gst-plugins-ugly \
    bridge-utils
 do
    remove_pkg "$bad"
done

if [ -z "$PREBUILT_REPO_DIR" ] && [ "$USE_AUR_FALLBACK" != "1" ]; then
    log "No prebuilt repo/AUR fallback: removing AUR-only local-repo packages from ISO package list"
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

# ------------------------------------------------------------
