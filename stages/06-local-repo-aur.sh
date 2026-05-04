# Sourced by ../build.sh; original section: 6. Signed binary repository and optional AUR fallback

# 6. Signed binary repository and optional AUR fallback
# ------------------------------------------------------------

sign_repo_artifacts() {
    if [ "$REPO_SIGN" != "1" ]; then
        warn "REPO_SIGN=0: repo lokalne działa w trybie prototypowym bez podpisów."
        return 0
    fi

    [ -n "$GPG_KEY_ID" ] || die "REPO_SIGN=1 wymaga GPG_KEY_ID."
    require_cmd gpg

    (
        cd "$CUSTOMREPO"
        shopt -s nullglob
        local artifacts=( ./*.pkg.tar.zst "$REPO_NAME".db.tar.gz "$REPO_NAME".files.tar.gz )
        shopt -u nullglob

        for artifact in "${artifacts[@]}"; do
            [ -f "$artifact" ] || continue
            gpg --batch --yes --local-user "$GPG_KEY_ID" --detach-sign --use-agent "$artifact"
        done
    )
}

import_prebuilt_repo() {
    if [ -z "$PREBUILT_REPO_DIR" ]; then
        warn "Nie ustawiono PREBUILT_REPO_DIR."
        return 1
    fi

    [ -d "$PREBUILT_REPO_DIR" ] || die "PREBUILT_REPO_DIR nie istnieje: $PREBUILT_REPO_DIR"

    log "Importing prebuilt binary repo: $PREBUILT_REPO_DIR"
    mkdir -p "$CUSTOMREPO"

    shopt -s nullglob
    local pkgs=( "$PREBUILT_REPO_DIR"/*.pkg.tar.zst )
    local sigs=( "$PREBUILT_REPO_DIR"/*.pkg.tar.zst.sig )
    shopt -u nullglob

    [ "${#pkgs[@]}" -gt 0 ] || die "Brak paczek .pkg.tar.zst w PREBUILT_REPO_DIR=$PREBUILT_REPO_DIR"

    cp -f "${pkgs[@]}" "$CUSTOMREPO/"
    if [ "${#sigs[@]}" -gt 0 ]; then
        cp -f "${sigs[@]}" "$CUSTOMREPO/"
    fi
}

build_aur_pkg() {
    local pkg="$1"

    if [ "$SKIP_AUR" = "1" ]; then
        warn "SKIP_AUR=1: pomijam AUR package: $pkg"
        return 0
    fi

    log "Building AUR package: $pkg"
    mkdir -p "$AURBUILD" "$CUSTOMREPO"
    cd "$AURBUILD"

    rm -rf "$pkg"
    git clone --depth=1 "https://aur.archlinux.org/${pkg}.git"
    cd "$pkg"

    if [ ! -f PKGBUILD ]; then
        warn "AUR repo for $pkg has no PKGBUILD; package name may be obsolete or removed."
        return 1
    fi

    makepkg -s --noconfirm --needed --cleanbuild

    shopt -s nullglob
    local files=( ./*.pkg.tar.zst )
    shopt -u nullglob

    if [ "${#files[@]}" -eq 0 ]; then
        warn "Brak zbudowanej paczki dla: $pkg"
        return 1
    fi

    cp ./*.pkg.tar.zst "$CUSTOMREPO/"
}

build_lolios_game_devices_udev_pkg() {
    [ "$INCLUDE_GAME_DEVICES_UDEV" = "1" ] || return 0

    log "Building local package: $GAME_DEVICES_UDEV_PKGNAME"

    local pkgroot="$WORKROOT/$GAME_DEVICES_UDEV_PKGNAME-pkg"
    local srcrepo="$pkgroot/upstream"
    local srcdir="$pkgroot/src/game-devices-udev"
    mkdir -p "$CUSTOMREPO" "$REPO_DIR" "$LOG_DIR"
    rm -rf "$pkgroot"
    mkdir -p "$srcdir"

    local cloned=0
    local url
    for url in \
        "https://codeberg.org/fabiscafe/game-devices-udev.git" \
        "https://gitlab.com/fabiscafe/game-devices-udev.git"
    do
        rm -rf "$srcrepo"
        if [ -n "$GAME_DEVICES_UDEV_REF" ]; then
            if git clone --depth=1 --branch "$GAME_DEVICES_UDEV_REF" "$url" "$srcrepo" 2>"$LOG_DIR/game-devices-udev-clone-$BUILD_ID.log"; then
                cloned=1
                break
            fi
        fi
        rm -rf "$srcrepo"
        if git clone --depth=1 "$url" "$srcrepo" 2>>"$LOG_DIR/game-devices-udev-clone-$BUILD_ID.log"; then
            cloned=1
            break
        fi
    done

    if [ "$cloned" = "1" ]; then
        cp -a "$srcrepo"/. "$srcdir"/
    else
        warn "Nie udało się pobrać upstream game-devices-udev. Tworzę minimalny fallback udev dla kontrolerów/hidraw."
        mkdir -p "$srcdir/rules"
        cat > "$srcdir/rules/70-lolios-game-devices.rules" <<'RULESEOF'
# LoliOS fallback controller rules.
KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", TAG+="uaccess"
SUBSYSTEM=="input", GROUP="input", MODE="0660"
RULESEOF
    fi

    cat > "$pkgroot/PKGBUILD" <<'PKGEOF'
pkgname=lolios-game-devices-udev
pkgver=0.25.lolios
pkgrel=1
pkgdesc="LoliOS packaged game controller udev rules, replacing fragile game-devices-udev AUR dependency"
arch=('any')
url='https://codeberg.org/fabiscafe/game-devices-udev'
license=('MIT')
provides=('game-devices-udev')
conflicts=('game-devices-udev')
package() {
    install -d "$pkgdir/usr/lib/udev/rules.d"
    local found=0
    while IFS= read -r -d '' rule; do
        install -Dm644 "$rule" "$pkgdir/usr/lib/udev/rules.d/$(basename "$rule")"
        found=1
    done < <(find "$srcdir/game-devices-udev" -type f -name '*.rules' -print0)
    if [ "$found" -eq 0 ]; then
        echo "No .rules files found in game-devices-udev source" >&2
        return 1
    fi
}
PKGEOF

    (cd "$pkgroot" && makepkg --force --nodeps --noconfirm >"$LOG_DIR/$GAME_DEVICES_UDEV_PKGNAME-$BUILD_ID.log" 2>&1) || {
        warn "Budowa $GAME_DEVICES_UDEV_PKGNAME nie powiodła się. Log: $LOG_DIR/$GAME_DEVICES_UDEV_PKGNAME-$BUILD_ID.log"
        [ "$REQUIRE_GAME_DEVICES_UDEV" = "1" ] && die "$GAME_DEVICES_UDEV_PKGNAME jest wymagany, ale nie zbudował się."
        return 0
    }

    shopt -s nullglob
    local built=( "$pkgroot"/*.pkg.tar.zst )
    shopt -u nullglob
    if [ "${#built[@]}" -gt 0 ]; then
        cp -f "${built[@]}" "$CUSTOMREPO/"
        cp -f "${built[@]}" "$REPO_DIR/"
    else
        warn "Brak artefaktu $GAME_DEVICES_UDEV_PKGNAME po makepkg."
        [ "$REQUIRE_GAME_DEVICES_UDEV" = "1" ] && die "Brak artefaktu $GAME_DEVICES_UDEV_PKGNAME."
    fi
}

refresh_local_repo() {
    log "Refreshing local repo"
    mkdir -p "$CUSTOMREPO"

    (
        cd "$CUSTOMREPO"
        rm -f "$REPO_NAME".db* "$REPO_NAME".files*

        shopt -s nullglob
        local pkgs=( ./*.pkg.tar.zst )
        shopt -u nullglob

        if [ "${#pkgs[@]}" -gt 0 ]; then
            repo-add "$REPO_NAME".db.tar.gz ./*.pkg.tar.zst
            ln -sf "$REPO_NAME".db.tar.gz "$REPO_NAME".db
            ln -sf "$REPO_NAME".files.tar.gz "$REPO_NAME".files
            sign_repo_artifacts
        else
            warn "Brak paczek w customrepo — tworzę minimalną pustą bazę repo, żeby pacman.conf nie blokował mkarchiso."
            mkdir -p "$WORKROOT/empty-repo-pkg/pkg/empty-repo-placeholder/usr/share/lolios"
            mkdir -p "$WORKROOT/empty-repo-pkg/src"
            cat > "$WORKROOT/empty-repo-pkg/PKGBUILD" <<'PKGEOF'
pkgname=empty-repo-placeholder
pkgver=1
pkgrel=1
pkgdesc="Placeholder package for an otherwise empty LoliOS local repository"
arch=('any')
license=('custom')
package() {
    install -Dm644 /dev/null "$pkgdir/usr/share/lolios/empty-repo-placeholder"
}
PKGEOF
            (cd "$WORKROOT/empty-repo-pkg" && makepkg --force --nodeps --noconfirm >/dev/null)
            cp "$WORKROOT/empty-repo-pkg"/*.pkg.tar.zst "$CUSTOMREPO/"
            repo-add "$REPO_NAME".db.tar.gz ./*.pkg.tar.zst
            ln -sf "$REPO_NAME".db.tar.gz "$REPO_NAME".db
            ln -sf "$REPO_NAME".files.tar.gz "$REPO_NAME".files
        fi
    )
}

local_repo_has_pkg() {
    local pkg="$1"
    shopt -s nullglob
    local matches=(
        "$CUSTOMREPO"/"$pkg"-*.pkg.tar.zst
        "$REPO_DIR"/"$pkg"-*.pkg.tar.zst
    )
    shopt -u nullglob
    [ "${#matches[@]}" -gt 0 ]
}

prune_missing_local_repo_packages() {
    log "Checking local-repo-only packages"

    local optional_pkgs=(
        bottles
        brave-bin
        rustdesk-bin
        pycharm-community-jre
        protonup-qt-bin
        proton-ge-custom-bin
        heroic-games-launcher-bin
        onlyoffice-bin
        ttf-ms-fonts
        yay
    )

    local critical_pkgs=(
        calamares
        lolios-game-devices-udev
    )

    local pkg
    for pkg in "${critical_pkgs[@]}"; do
        if grep -qxF "$pkg" "$PROFILE/packages.x86_64" && ! local_repo_has_pkg "$pkg"; then
            if [ "$pkg" = "calamares" ] && [ "$ALLOW_INSTALLERLESS_ISO" = "1" ]; then
                warn "Missing critical local package $pkg, but ALLOW_INSTALLERLESS_ISO=1; removing it."
                remove_pkg "$pkg"
            else
                die "Missing critical local package: $pkg. Use USE_AUR_FALLBACK=1, PREBUILT_REPO_DIR, or set ALLOW_INSTALLERLESS_ISO=1 only for installerless test images."
            fi
        fi
    done

    for pkg in "${optional_pkgs[@]}"; do
        if grep -qxF "$pkg" "$PROFILE/packages.x86_64" && ! local_repo_has_pkg "$pkg"; then
            warn "Missing optional local package $pkg; removing it from ISO package list."
            remove_pkg "$pkg"
        fi
    done

    dedup_packages
}

log "Preparing local binary repo"

# Bottles is intentionally not in AUR_PKGS. It is built by stages/06b-bottles-github.sh
# directly from https://github.com/bottlesdevs/Bottles into lolios-local, so the
# builder does not need aur.archlinux.org for Bottles.
AUR_PKGS=(
    calamares
    brave-bin
    rustdesk-bin
    pycharm-community-jre
    protonup-qt-bin
    proton-ge-custom-bin
    heroic-games-launcher-bin
    onlyoffice-bin
    ttf-ms-fonts
    yay
)
AUR_FAILED=()

if [ "$ISO_STAGE" = "1" ] && [ -z "$PREBUILT_REPO_DIR" ] && [ "$USE_AUR_FALLBACK" != "1" ] && [ "$ALLOW_INSTALLERLESS_ISO" != "1" ]; then
    die "Calamares is not in official Arch repositories. Enable USE_AUR_FALLBACK=1, provide PREBUILT_REPO_DIR, or set ALLOW_INSTALLERLESS_ISO=1 for a live-only test image."
fi

run_repo_stage_v2
build_lolios_game_devices_udev_pkg
copy_repo_dir_to_customrepo
refresh_local_repo
copy_customrepo_to_repo_dir

sync_embedded_local_repo() {
    log "Embedding local repo into ISO and installed system"
    local embedded="$PROFILE/airootfs/opt/lolios/repo"
    mkdir -p "$embedded" "$PROFILE/airootfs/usr/local/bin" "$PROFILE/airootfs/etc/pacman.d"

    rm -rf "$embedded"/*

    local copied_any=0
    local src base dest source_dir
    local -A copied=()

    for source_dir in "$CUSTOMREPO" "$REPO_DIR"; do
        [ -d "$source_dir" ] || continue
        shopt -s nullglob
        local repo_files=(
            "$source_dir"/*.pkg.tar.zst
            "$source_dir"/*.pkg.tar.zst.sig
            "$source_dir"/"$REPO_NAME".db*
            "$source_dir"/"$REPO_NAME".files*
        )
        shopt -u nullglob

        for src in "${repo_files[@]}"; do
            [ -e "$src" ] || continue
            base="$(basename "$src")"
            if [ -n "${copied[$base]:-}" ]; then
                continue
            fi
            dest="$embedded/$base"
            cp -af "$src" "$dest"
            copied[$base]=1
            copied_any=1
        done
    done

    [ "$copied_any" = "1" ] || warn "No local repo files to embed"

    cat > "$PROFILE/airootfs/etc/pacman.d/lolios-local.conf" <<EOF
[$REPO_NAME]
SigLevel = Optional TrustAll
Server = file:///opt/lolios/repo
EOF

    cat > "$PROFILE/airootfs/usr/local/bin/lolios-enable-local-repo" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
REPO_NAME="${REPO_NAME:-lolios-local}"
REPO_DIR="${REPO_DIR:-/opt/lolios/repo}"
PACMAN_CONF="${PACMAN_CONF:-/etc/pacman.conf}"
DO_SYNC=1
for arg in "$@"; do
    case "$arg" in
        --no-sync) DO_SYNC=0 ;;
    esac
done
[ "${LOLIOS_SKIP_PACMAN_SYNC:-0}" = "1" ] && DO_SYNC=0
[ "${EUID:-$(id -u)}" -eq 0 ] || { echo "Run as root" >&2; exit 1; }
[ -f "$PACMAN_CONF" ] || { echo "Missing $PACMAN_CONF" >&2; exit 1; }
if ! grep -q "^\[$REPO_NAME\]" "$PACMAN_CONF"; then
    cat >> "$PACMAN_CONF" <<EOC

[$REPO_NAME]
SigLevel = Optional TrustAll
Server = file://$REPO_DIR
EOC
fi
if [ "$DO_SYNC" = "1" ]; then
    pacman -Sy || true
fi
EOF
    chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-enable-local-repo"
}

sync_embedded_local_repo

# ------------------------------------------------------------
