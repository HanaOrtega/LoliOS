# Sourced by ../build.sh; original section: 17B. Integrated 10/10 ISO feature tools

# 17B. Integrated 10/10 ISO feature tools
# ------------------------------------------------------------

log "Writing 10/10 ISO feature tools"

mkdir -p \
    "$PROFILE/airootfs/usr/share/doc/lolios" \
    "$PROFILE/airootfs/etc/skel/Desktop" \
    "$PROFILE/airootfs/root/Desktop" \
    "$PROFILE/airootfs/etc/xdg/autostart"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-validate-packages" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

PROFILE="${1:-${PROFILE:-/home/${SUDO_USER:-$USER}/lolios-build/profile}}"
PKGS="$PROFILE/packages.x86_64"
PACMAN_CONF="$PROFILE/pacman.conf"
CUSTOMREPO="$PROFILE/customrepo"

fail=0
err() { echo "BAD: $*"; fail=1; }
ok() { echo "OK: $*"; }
warn() { echo "WARN: $*"; }

if [ ! -f "$PKGS" ]; then
    echo "Usage: lolios-validate-packages /path/to/profile" >&2
    exit 2
fi

[ -f "$PACMAN_CONF" ] || err "missing pacman.conf: $PACMAN_CONF"

# These package names are intentionally forbidden because they are obsolete,
# conflict with the chosen stack, or are replaced by LoliOS packages. Bottles is
# intentionally allowed: it is built from GitHub into lolios-local and must be
# installed offline from the custom repository.
for bad in \
    mesa-vdpau \
    lib32-mesa-vdpau \
    bridge-utils \
    lib32-gst-plugins-base-libs \
    lib32-gst-plugins-good \
    lib32-gst-plugins-bad-libs \
    lib32-gst-plugins-ugly \
    appimagelauncher \
    noise-suppression-for-voice \
    corectrl \
    btrfs-assistant \
    wine-staging \
    wine-ge-custom \
    nvidia
 do
    if grep -qxF "$bad" "$PKGS"; then
        err "unwanted/problematic package present: $bad"
    else
        ok "not present: $bad"
    fi
done

for required in linux-zen linux-lts nvidia-dkms steam lutris bottles wine winetricks gamemode mangohud gamescope snapper grub-btrfs; do
    if grep -qxF "$required" "$PKGS"; then
        ok "required package present: $required"
    else
        err "required package missing: $required"
    fi
done

if [ -d "$CUSTOMREPO" ]; then
    if compgen -G "$CUSTOMREPO/*.pkg.tar.zst" >/dev/null 2>&1; then
        ok "custom repo has packages"
    else
        warn "custom repo has no .pkg.tar.zst packages"
    fi
else
    warn "custom repo missing: $CUSTOMREPO"
fi

if command -v pacman >/dev/null 2>&1 && [ -f "$PACMAN_CONF" ]; then
    echo
    echo "Checking package availability through pacman -Sp..."
    mapfile -t pkg_lines < <(grep -Ev '^[[:space:]]*(#|$)' "$PKGS")
    if [ "${#pkg_lines[@]}" -gt 0 ]; then
        VALIDATION_DB="$PROFILE/pacman-validate-db"
        VALIDATION_CACHE="$PROFILE/pacman-validate-cache"
        rm -rf "$VALIDATION_DB"
        mkdir -p "$VALIDATION_DB" "$VALIDATION_CACHE"

        if ! sudo pacman --config "$PACMAN_CONF" --dbpath "$VALIDATION_DB" --cachedir "$VALIDATION_CACHE" -Sy --noconfirm >/tmp/lolios-validate-sync.out 2>/tmp/lolios-validate-sync.err; then
            warn "pacman could not sync validation databases; details: /tmp/lolios-validate-sync.err"
            cat /tmp/lolios-validate-sync.err || true
            fail=1
        elif sudo pacman --config "$PACMAN_CONF" --dbpath "$VALIDATION_DB" --cachedir "$VALIDATION_CACHE" -Sp --needed --print-format '%n' "${pkg_lines[@]}" >/tmp/lolios-validate-packages.out 2>/tmp/lolios-validate-packages.err; then
            ok "pacman resolved package list"
        else
            warn "pacman could not resolve all packages; details: /tmp/lolios-validate-packages.err"
            cat /tmp/lolios-validate-packages.err || true
            fail=1
        fi
    fi
fi
exit "$fail"
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-validate-packages"
cp "$PROFILE/airootfs/usr/local/bin/lolios-validate-packages" "$PROFILE/lolios-validate-packages"
chmod +x "$PROFILE/lolios-validate-packages"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-setup-snapper" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

[ "${EUID:-$(id -u)}" -eq 0 ] || { echo "Run as root: sudo lolios-setup-snapper" >&2; exit 1; }

if ! findmnt -n -o FSTYPE / 2>/dev/null | grep -qx btrfs; then
    echo "Root filesystem is not Btrfs. Snapper root config skipped."
    exit 0
fi

if command -v snapper >/dev/null 2>&1; then
    snapper -c root create-config / 2>/dev/null || true
    systemctl enable --now snapper-timeline.timer 2>/dev/null || true
    systemctl enable --now snapper-cleanup.timer 2>/dev/null || true
fi

if systemctl list-unit-files 2>/dev/null | grep -q '^grub-btrfsd.service'; then
    systemctl enable --now grub-btrfsd.service 2>/dev/null || true
fi

if command -v grub-mkconfig >/dev/null 2>&1 && [ -d /boot/grub ]; then
    grub-mkconfig -o /boot/grub/grub.cfg || true
fi

echo "Snapper/rollback setup finished."
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-setup-snapper"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-first-run" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

STATE_DIR="$HOME/.local/share/lolios"
DONE_FILE="$STATE_DIR/first-run.done"
mkdir -p "$STATE_DIR"

is_live_iso() {
    grep -qw archiso /proc/cmdline 2>/dev/null || \
    [ -d /run/archiso ] || \
    [ -d /run/archiso/bootmnt ] || \
    [ -f /etc/lolios-live ] || \
    { [ "${USER:-}" = "live" ] && [ "$(cat /etc/hostname 2>/dev/null || true)" = "lolios" ]; }
}

if is_live_iso; then
    exit 0
fi
[ -f "$DONE_FILE" ] && exit 0

has_gui() { command -v kdialog >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; }

yesno() {
    local question="$1" default="${2:-yes}"
    if has_gui; then
        kdialog --yesno "$question" 2>/dev/null
        return $?
    fi
    local prompt="y/N"
    [ "$default" = "yes" ] && prompt="Y/n"
    read -r -p "$question [$prompt]: " ans
    ans="${ans:-$default}"
    case "$ans" in y|Y|yes|YES|tak|TAK|Tak) return 0 ;; *) return 1 ;; esac
}

msg() { if has_gui; then kdialog --msgbox "$1" 2>/dev/null || true; else echo "$1"; fi; }

run_term() {
    local title="$1"; shift
    if command -v konsole >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
        konsole --new-tab -p tabtitle="$title" -e "$@" &
    elif command -v xterm >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
        xterm -T "$title" -e "$@" &
    else
        "$@"
    fi
}

msg "Witaj w LoliOS. Ten kreator skonfiguruje podstawowe elementy gamingowe po pierwszym starcie."
yesno "Zastosować automatyczny profil GPU?" "yes" && command -v lolios-gpu-profile >/dev/null 2>&1 && run_term "GPU profile" sudo lolios-gpu-profile auto || true
yesno "Uruchomić diagnostykę Gaming Doctor?" "yes" && command -v lolios-gaming-doctor >/dev/null 2>&1 && run_term "Gaming Doctor" lolios-gaming-doctor || true
yesno "Skonfigurować Snapper/rollback, jeśli system jest na Btrfs?" "yes" && run_term "Snapper setup" sudo /usr/local/bin/lolios-setup-snapper || true
yesno "Otworzyć LoliOS Gaming Center?" "yes" && command -v lolios-gaming-center >/dev/null 2>&1 && lolios-gaming-center &

touch "$DONE_FILE"
msg "Pierwsza konfiguracja zakończona. Możesz uruchomić ją ponownie komendą: rm ~/.local/share/lolios/first-run.done && lolios-first-run"
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-first-run"

cat > "$PROFILE/airootfs/etc/xdg/autostart/lolios-first-run.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=LoliOS First Run
Comment=Configure LoliOS after first login
Exec=/usr/local/bin/lolios-first-run
Icon=system-run
Categories=System;
Terminal=false
OnlyShowIn=KDE;
X-KDE-autostart-after=panel
EOF

cat > "$PROFILE/airootfs/usr/share/applications/lolios-first-run.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=LoliOS First Run
Comment=Run first-time configuration wizard
Exec=/usr/local/bin/lolios-first-run
Icon=system-run
Categories=System;
Terminal=false
StartupNotify=true
EOF

cat > "$PROFILE/airootfs/usr/local/bin/lolios-collect-logs" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

OUTDIR="${1:-$HOME/lolios-debug-$(date +%Y%m%d-%H%M%S)}"
ARCHIVE="$OUTDIR.tar.zst"
mkdir -p "$OUTDIR"

run() {
    local name="$1"; shift
    echo "[collect] $name"
    { echo "### $name"; echo "Command: $*"; echo; "$@"; } > "$OUTDIR/$name.txt" 2>&1 || true
}

copy_if_exists() {
    local src="$1" dst="$2"
    [ -e "$src" ] || return 0
    mkdir -p "$(dirname "$OUTDIR/$dst")"
    cp -a "$src" "$OUTDIR/$dst" 2>/dev/null || true
}

run uname uname -a
run os-release cat /etc/os-release
run fastfetch bash -lc 'command -v fastfetch >/dev/null && fastfetch || true'
run inxi bash -lc 'command -v inxi >/dev/null && inxi -Fazy || true'
run lspci lspci -nnk
run lsusb lsusb
run lsblk lsblk -f
run mount findmnt
run vulkaninfo bash -lc 'command -v vulkaninfo >/dev/null && vulkaninfo --summary || true'
run glxinfo bash -lc 'command -v glxinfo >/dev/null && glxinfo -B || true'
run dkms bash -lc 'command -v dkms >/dev/null && dkms status || true'
run pacman-Q pacman -Q
run pacman-Qm pacman -Qm
run systemctl-failed systemctl --failed
run journal-current journalctl -b --no-pager
run sddm-journal journalctl -b -u sddm --no-pager
run networkmanager-journal journalctl -b -u NetworkManager --no-pager
run dmesg dmesg
run gaming-doctor bash -lc 'command -v lolios-gaming-doctor >/dev/null && lolios-gaming-doctor || true'
run snapper bash -lc 'command -v snapper >/dev/null && snapper list || true'

copy_if_exists /var/log/Xorg.0.log var-log/Xorg.0.log
copy_if_exists "$HOME/.local/share/lolios/exe-launcher" home-lolios/exe-launcher
copy_if_exists /tmp/lolios-gaming-doctor.log tmp/lolios-gaming-doctor.log
copy_if_exists /tmp/lolios-installer.log tmp/lolios-installer.log

find "$OUTDIR" -type f -name '*.txt' -print0 | while IFS= read -r -d '' file; do
    sed -i -E 's/(password|passwd|token|secret|apikey|api_key)=([^[:space:]]+)/REDACTED_KEY=REDACTED/Ig' "$file" || true
done

tar --zstd -cf "$ARCHIVE" -C "$(dirname "$OUTDIR")" "$(basename "$OUTDIR")"
echo "Created: $ARCHIVE"
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-collect-logs"

cat > "$PROFILE/airootfs/usr/share/applications/lolios-collect-logs.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=LoliOS Collect Logs
Comment=Collect diagnostic logs for troubleshooting
Exec=konsole -e /usr/local/bin/lolios-collect-logs
Icon=utilities-log-viewer
Categories=System;
Terminal=false
StartupNotify=true
EOF

cat > "$PROFILE/airootfs/usr/share/doc/lolios/index.html" <<'EOF'
<!doctype html>
<html lang="pl">
<head>
  <meta charset="utf-8">
  <title>LoliOS Help</title>
  <style>
    body { font-family: sans-serif; max-width: 980px; margin: 40px auto; line-height: 1.55; padding: 0 20px; }
    code, pre { background: #eee; padding: 2px 5px; border-radius: 4px; }
    pre { padding: 12px; overflow: auto; }
    h1, h2 { color: #8b2bbf; }
  </style>
</head>
<body>
  <h1>LoliOS Personal Gaming Workstation</h1>
  <p>System zawiera narzędzia do gamingu, Wine/Proton, diagnostyki GPU, aktualizacji z snapshotami oraz naprawy systemu.</p>
  <h2>Najważniejsze komendy</h2>
  <pre>lolios-gaming-center
lolios-gaming-doctor
lolios-exe-launcher plik.exe
lolios-prefix-manager
sudo lolios-update
sudo lolios-gpu-profile auto
sudo lolios-setup-snapper
lolios-collect-logs</pre>
  <h2>EXE Launcher</h2>
  <p>Dwuklik na .exe otwiera LoliOS EXE Launcher. Detektor sugeruje DXVK, VKD3D, PhysX, vcrun2019 i d3dx9.</p>
  <h2>Aktualizacje</h2>
  <pre>sudo lolios-update</pre>
  <h2>Rollback</h2>
  <pre>sudo lolios-setup-snapper
snapper list</pre>
  <h2>Naprawa systemu z live ISO</h2>
  <pre>sudo lolios-repair-installed-system</pre>
  <h2>Logi diagnostyczne</h2>
  <pre>lolios-collect-logs</pre>
</body>
</html>
EOF

cat > "$PROFILE/airootfs/usr/share/applications/lolios-help.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=LoliOS Help
Comment=Open local LoliOS documentation
Exec=xdg-open /usr/share/doc/lolios/index.html
Icon=help-browser
Categories=Documentation;System;
Terminal=false
StartupNotify=true
EOF

cp "$PROFILE/airootfs/usr/share/applications/lolios-help.desktop" "$PROFILE/airootfs/etc/skel/Desktop/lolios-help.desktop"
cp "$PROFILE/airootfs/usr/share/applications/lolios-help.desktop" "$PROFILE/airootfs/root/Desktop/lolios-help.desktop"
chmod +x "$PROFILE/airootfs/etc/skel/Desktop/lolios-help.desktop" "$PROFILE/airootfs/root/Desktop/lolios-help.desktop"

GC="$PROFILE/airootfs/usr/local/bin/lolios-gaming-center"
if [ -f "$GC" ] && ! grep -q 'first-run "Run first-run wizard"' "$GC"; then
    python3 - "$GC" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
s = s.replace('logs "Open /tmp logs" \
            quit "Exit"', 'logs "Open /tmp logs" \
            first-run "Run first-run wizard" \
            collect-logs "Collect diagnostic logs" \
            help "Open offline help" \
            quit "Exit"')
s = s.replace('logs) xdg-open /tmp 2>/dev/null || true ;;', '''logs) xdg-open /tmp 2>/dev/null || true ;;
        first-run) /usr/local/bin/lolios-first-run & ;;
        collect-logs) run_terminal "Collect Logs" /usr/local/bin/lolios-collect-logs ;;
        help) xdg-open /usr/share/doc/lolios/index.html 2>/dev/null || true ;;''')
p.write_text(s)
PY
fi

cat > "$PROFILE/build-lolios-repo.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="${REPO_DIR:-$PWD/lolios-repo}"
BUILD_DIR="${BUILD_DIR:-$PWD/aur-build}"
REPO_NAME="${REPO_NAME:-lolios-local}"
REPO_SIGN="${REPO_SIGN:-0}"
GPG_KEY_ID="${GPG_KEY_ID:-}"

AUR_PKGS=(
    calamares
    brave-bin
    rustdesk-bin
    pycharm-community-jre
    protonup-qt-bin
    yay
    proton-ge-custom-bin
    ttf-ms-fonts
    onlyoffice-bin
    heroic-games-launcher-bin
)

log() { echo; echo "[LOLIOS REPO] $*"; }
die() { echo "[ERROR] $*" >&2; exit 1; }

[ "${EUID:-$(id -u)}" -ne 0 ] || die "Do not run as root."
command -v makepkg >/dev/null 2>&1 || die "makepkg missing. Install base-devel."
command -v repo-add >/dev/null 2>&1 || die "repo-add missing. Install pacman-contrib."

mkdir -p "$REPO_DIR" "$BUILD_DIR"

build_game_devices_pkg() {
    log "Building lolios-game-devices-udev without AUR PGP/source verification"
    local work="$BUILD_DIR/lolios-game-devices-udev"
    rm -rf "$work"
    mkdir -p "$work/src/game-devices-udev" "$REPO_DIR"

    if git clone --depth=1 https://codeberg.org/fabiscafe/game-devices-udev.git "$work/upstream" || \
       git clone --depth=1 https://gitlab.com/fabiscafe/game-devices-udev.git "$work/upstream"; then
        cp -a "$work/upstream"/. "$work/src/game-devices-udev"/
    else
        mkdir -p "$work/src/game-devices-udev/rules"
        cat > "$work/src/game-devices-udev/rules/70-lolios-game-devices.rules" <<'RULESEOF'
KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", TAG+="uaccess"
SUBSYSTEM=="input", GROUP="input", MODE="0660"
RULESEOF
    fi

    cat > "$work/PKGBUILD" <<'PKGEOF'
pkgname=lolios-game-devices-udev
pkgver=0.25.lolios
pkgrel=1
pkgdesc="LoliOS packaged game controller udev rules"
arch=('any')
license=('MIT')
provides=('game-devices-udev')
conflicts=('game-devices-udev')
package() {
    install -d "$pkgdir/usr/lib/udev/rules.d"
    find "$srcdir/game-devices-udev" -type f -name '*.rules' -exec install -Dm644 '{}' "$pkgdir/usr/lib/udev/rules.d/" \;
}
PKGEOF

    (cd "$work" && makepkg --force --nodeps --noconfirm)
    cp "$work"/*.pkg.tar.zst "$REPO_DIR/"
}

build_pkg() {
    local pkg="$1"
    log "Building $pkg"
    cd "$BUILD_DIR"
    rm -rf "$pkg"
    git clone --depth=1 "https://aur.archlinux.org/${pkg}.git"
    cd "$pkg"
    makepkg -s --noconfirm --needed --cleanbuild
    cp ./*.pkg.tar.zst "$REPO_DIR/"
}

FAILED=()
for pkg in "${AUR_PKGS[@]}"; do
    build_pkg "$pkg" || FAILED+=("$pkg")
done
build_game_devices_pkg || FAILED+=("lolios-game-devices-udev")

cd "$REPO_DIR"
shopt -s nullglob
PKG_FILES=( ./*.pkg.tar.zst )
shopt -u nullglob
[ "${#PKG_FILES[@]}" -gt 0 ] || die "No packages were built; cannot create repo database."
rm -f "$REPO_NAME".db* "$REPO_NAME".files*
repo-add "$REPO_NAME".db.tar.gz "${PKG_FILES[@]}"
ln -sf "$REPO_NAME".db.tar.gz "$REPO_NAME".db
ln -sf "$REPO_NAME".files.tar.gz "$REPO_NAME".files

if [ "$REPO_SIGN" = "1" ]; then
    [ -n "$GPG_KEY_ID" ] || die "REPO_SIGN=1 requires GPG_KEY_ID"
    for artifact in ./*.pkg.tar.zst "$REPO_NAME".db.tar.gz "$REPO_NAME".files.tar.gz; do
        [ -f "$artifact" ] || continue
        gpg --batch --yes --local-user "$GPG_KEY_ID" --detach-sign --use-agent "$artifact"
    done
fi

sha256sum "${PKG_FILES[@]}" > SHA256SUMS
printf '%s
' "${AUR_PKGS[@]}" > MANIFEST.packages

if [ "${#FAILED[@]}" -gt 0 ]; then
    echo "Failed packages: ${FAILED[*]}" >&2
    exit 1
fi

log "Repo ready: $REPO_DIR"
EOF
chmod +x "$PROFILE/build-lolios-repo.sh"

cat > "$PROFILE/airootfs/usr/share/applications/lolios-validate-packages.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=LoliOS Validate Packages
Comment=Validate ArchISO package list
Exec=konsole -e /usr/local/bin/lolios-validate-packages
Icon=dialog-ok-apply
Categories=System;
Terminal=false
StartupNotify=true
EOF

for app in lolios-first-run.desktop lolios-gaming-center.desktop lolios-collect-logs.desktop lolios-help.desktop; do
    [ -f "$PROFILE/airootfs/usr/share/applications/$app" ] || continue
    cp "$PROFILE/airootfs/usr/share/applications/$app" "$PROFILE/airootfs/etc/skel/Desktop/$app" || true
    chmod +x "$PROFILE/airootfs/etc/skel/Desktop/$app" || true
    cp "$PROFILE/airootfs/usr/share/applications/$app" "$PROFILE/airootfs/root/Desktop/$app" || true
    chmod +x "$PROFILE/airootfs/root/Desktop/$app" || true
done

# ------------------------------------------------------------
