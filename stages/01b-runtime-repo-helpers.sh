# Sourced by ../build.sh; original section: 1B. v2 production locking, logs, snapshot mirror, repo stage helpers

# 1B. v2 production locking, logs, snapshot mirror, repo stage helpers
# ------------------------------------------------------------

init_v2_runtime() {
    mkdir -p "$WORKROOT" "$LOG_DIR" "$CACHE_DIR" "$MANIFEST_DIR" "$REPO_DIR" "$AUR_ROOT" "$AUR_SRC_DIR"
    if [ "${LOLIOS_LOG_TEE_ENABLED:-0}" != "1" ]; then
        export LOLIOS_LOG_TEE_ENABLED=1
        exec > >(tee -a "$MAIN_LOG") 2>&1
    fi
}

cleanup_mounts_v2() {
    force_unmount_archiso || true
}

cleanup_v2() {
    local status=$?
    if [ "$status" -ne 0 ]; then
        warn "Build failed with status $status. Log: $MAIN_LOG"
    fi

    # Forced unmounting on every EXIT can disturb the host desktop/KIO when a file
    # manager or terminal is browsing the work tree. Do it only after failures or
    # when explicitly requested.
    if [ "$status" -ne 0 ] || [ "${LOLIOS_FORCE_UNMOUNT_ON_EXIT:-0}" = "1" ]; then
        cleanup_mounts_v2 || true
    else
        warn "Normal exit: skipping forced unmount cleanup. Set LOLIOS_FORCE_UNMOUNT_ON_EXIT=1 if needed."
    fi

    rm -f "$LOCKFILE" || true
}

acquire_lock() {
    mkdir -p "$(dirname "$LOCKFILE")"
    if [ -e "$LOCKFILE" ]; then
        local oldpid
        oldpid="$(cat "$LOCKFILE" 2>/dev/null || true)"
        if [ -n "$oldpid" ] && kill -0 "$oldpid" 2>/dev/null; then
            die "Inny build już działa: PID $oldpid"
        fi
        warn "Usuwam stary lockfile: $LOCKFILE"
        rm -f "$LOCKFILE"
    fi
    echo "$$" > "$LOCKFILE"
}

write_snapshot_mirrorlist_if_needed() {
    [ -n "$ARCH_SNAPSHOT_DATE" ] || return 0
    log "Using Arch Linux Archive snapshot: $ARCH_SNAPSHOT_DATE"
    mkdir -p "$WORKROOT/snapshot-pacman.d"
    cat > "$WORKROOT/snapshot-pacman.d/mirrorlist" <<EOF
Server = https://archive.archlinux.org/repos/$ARCH_SNAPSHOT_DATE/\$repo/os/\$arch
EOF
}

apply_snapshot_to_profile_pacman_conf() {
    [ -n "$ARCH_SNAPSHOT_DATE" ] || return 0
    [ -f "$PROFILE/pacman.conf" ] || return 0
    mkdir -p "$PROFILE/pacman.d"
    cat > "$PROFILE/pacman.d/mirrorlist" <<EOF
Server = https://archive.archlinux.org/repos/$ARCH_SNAPSHOT_DATE/\$repo/os/\$arch
EOF
    sed -i 's#Include = /etc/pacman.d/mirrorlist#Include = pacman.d/mirrorlist#g' "$PROFILE/pacman.conf"
}

copy_repo_dir_to_customrepo() {
    mkdir -p "$CUSTOMREPO"
    shopt -s nullglob
    local repo_files=( "$REPO_DIR"/*.pkg.tar.zst "$REPO_DIR"/*.pkg.tar.zst.sig "$REPO_DIR"/"$REPO_NAME".db* "$REPO_DIR"/"$REPO_NAME".files* )
    shopt -u nullglob
    if [ "${#repo_files[@]}" -gt 0 ]; then
        cp -af "${repo_files[@]}" "$CUSTOMREPO/"
    fi
}

copy_customrepo_to_repo_dir() {
    mkdir -p "$REPO_DIR"
    shopt -s nullglob
    local repo_files=(
        "$CUSTOMREPO"/*.pkg.tar.zst
        "$CUSTOMREPO"/*.pkg.tar.zst.sig
        "$CUSTOMREPO"/"$REPO_NAME".db*
        "$CUSTOMREPO"/"$REPO_NAME".files*
    )
    shopt -u nullglob

    local src dst
    for src in "${repo_files[@]}"; do
        [ -e "$src" ] || continue
        dst="$REPO_DIR/$(basename "$src")"
        if [ "$(readlink -f "$src")" = "$(readlink -f "$dst" 2>/dev/null || printf '%s' "$dst")" ]; then
            continue
        fi
        cp -af "$src" "$REPO_DIR/"
    done
}

refresh_repo_dir_db() {
    log "Refreshing v2 repo dir: $REPO_DIR"
    mkdir -p "$REPO_DIR"
    cd "$REPO_DIR"
    rm -f "$REPO_NAME".db* "$REPO_NAME".files*
    shopt -s nullglob
    local pkgs=( ./*.pkg.tar.zst )
    shopt -u nullglob
    if [ "${#pkgs[@]}" -eq 0 ]; then
        warn "REPO_DIR is empty: $REPO_DIR"
        return 1
    fi
    repo-add "$REPO_NAME".db.tar.gz ./*.pkg.tar.zst
    ln -sf "$REPO_NAME".db.tar.gz "$REPO_NAME".db
    ln -sf "$REPO_NAME".files.tar.gz "$REPO_NAME".files
    if [ "$REPO_SIGN" = "1" ]; then
        [ -n "$GPG_KEY_ID" ] || die "REPO_SIGN=1 wymaga GPG_KEY_ID."
        for artifact in ./*.pkg.tar.zst "$REPO_NAME".db.tar.gz "$REPO_NAME".files.tar.gz; do
            [ -f "$artifact" ] || continue
            gpg --batch --yes --local-user "$GPG_KEY_ID" --detach-sign --use-agent "$artifact"
        done
    fi
    sha256sum ./*.pkg.tar.zst > SHA256SUMS
    ls -1 ./*.pkg.tar.zst | sed 's#^./##' > "$MANIFEST_DIR/repo-packages-$BUILD_ID.txt"
}

build_aur_pkg_v2() {
    local pkgbase="$1"
    local logf="$LOG_DIR/aur-${pkgbase}-$BUILD_ID.log"
    log "AUR v2 build: $pkgbase"
    mkdir -p "$AUR_SRC_DIR" "$REPO_DIR"
    cd "$AUR_SRC_DIR"
    rm -rf "$pkgbase"
    if ! git clone --depth=1 "https://aur.archlinux.org/${pkgbase}.git" "$pkgbase"; then
        warn "Nie udało się sklonować AUR: $pkgbase"
        return 1
    fi
    if [ ! -d "$pkgbase" ]; then
        warn "Brak katalogu po git clone: $pkgbase"
        return 1
    fi
    cd "$pkgbase"
    [ -f PKGBUILD ] || { warn "Brak PKGBUILD: $pkgbase"; return 1; }
    if makepkg -s --noconfirm --needed --cleanbuild >"$logf" 2>&1; then
        shopt -s nullglob
        local built=( ./*.pkg.tar.zst )
        shopt -u nullglob
        [ "${#built[@]}" -gt 0 ] || return 1
        cp -f ./*.pkg.tar.zst "$REPO_DIR/"
        return 0
    fi
    warn "AUR build failed: $pkgbase; log: $logf"
    return 1
}

build_aur_pkg_clean_chroot_v2() {
    local pkgbase="$1"
    local logf="$LOG_DIR/aur-chroot-${pkgbase}-$BUILD_ID.log"
    command -v mkarchroot >/dev/null 2>&1 || { warn "mkarchroot missing; fallback host build"; build_aur_pkg_v2 "$pkgbase"; return $?; }
    command -v makechrootpkg >/dev/null 2>&1 || { warn "makechrootpkg missing; fallback host build"; build_aur_pkg_v2 "$pkgbase"; return $?; }
    log "AUR clean-chroot build: $pkgbase"
    mkdir -p "$AUR_SRC_DIR" "$REPO_DIR" "$CLEAN_CHROOT_DIR"
    if [ ! -d "$CLEAN_CHROOT_DIR/root" ]; then
        sudo mkarchroot "$CLEAN_CHROOT_DIR/root" base-devel git sudo pacman-contrib >"$LOG_DIR/mkarchroot-$BUILD_ID.log" 2>&1
    fi
    cd "$AUR_SRC_DIR"
    rm -rf "$pkgbase"
    if ! git clone --depth=1 "https://aur.archlinux.org/${pkgbase}.git" "$pkgbase"; then
        warn "Nie udało się sklonować AUR: $pkgbase"
        return 1
    fi
    if [ ! -d "$pkgbase" ]; then
        warn "Brak katalogu po git clone: $pkgbase"
        return 1
    fi
    cd "$pkgbase"
    [ -f PKGBUILD ] || { warn "Brak PKGBUILD: $pkgbase"; return 1; }
    if makechrootpkg -c -r "$CLEAN_CHROOT_DIR" >"$logf" 2>&1; then
        shopt -s nullglob
        local built=( ./*.pkg.tar.zst )
        shopt -u nullglob
        [ "${#built[@]}" -gt 0 ] || return 1
        cp -f ./*.pkg.tar.zst "$REPO_DIR/"
        return 0
    fi
    warn "AUR clean-chroot build failed: $pkgbase; log: $logf"
    return 1
}

run_repo_stage_v2() {
    [ "$REPO_STAGE" = "1" ] || { warn "REPO_STAGE=0: używam istniejącego repo: $REPO_DIR / $CUSTOMREPO"; copy_repo_dir_to_customrepo; return 0; }
    log "Repo stage v2"
    mkdir -p "$REPO_DIR" "$AUR_SRC_DIR" "$LOG_DIR" "$MANIFEST_DIR"
    if [ "$FORCE_REPO_REBUILD" = "1" ]; then
        rm -f "$REPO_DIR"/*.pkg.tar.zst "$REPO_DIR"/*.pkg.tar.zst.sig "$REPO_DIR"/*.db* "$REPO_DIR"/*.files* || true
    fi
    if [ -n "$PREBUILT_REPO_DIR" ]; then
        mkdir -p "$REPO_DIR"
        shopt -s nullglob
        local prebuilt=( "$PREBUILT_REPO_DIR"/*.pkg.tar.zst "$PREBUILT_REPO_DIR"/*.pkg.tar.zst.sig )
        shopt -u nullglob
        [ "${#prebuilt[@]}" -gt 0 ] && cp -af "${prebuilt[@]}" "$REPO_DIR/"
    fi
    local failed=()
    local pkg
    if [ "$USE_AUR_FALLBACK" = "1" ]; then
        for pkg in "${AUR_PKGS[@]}"; do
            if [ "$FORCE_REPO_REBUILD" != "1" ] && ls "$REPO_DIR"/${pkg}-*.pkg.tar.zst >/dev/null 2>&1; then
                log "Repo already has artifact for $pkg; skipping"
                continue
            fi
            if [ "$AUR_BUILD_MODE" = "clean-chroot" ]; then
                build_aur_pkg_clean_chroot_v2 "$pkg" || failed+=("$pkg")
            else
                build_aur_pkg_v2 "$pkg" || failed+=("$pkg")
            fi
        done
    else
        warn "USE_AUR_FALLBACK=0: repo stage nie buduje AUR; użyj PREBUILT_REPO_DIR albo istniejącego REPO_DIR."
    fi
    if refresh_repo_dir_db; then
        copy_repo_dir_to_customrepo
    else
        warn "Repo dir nie odświeżone; fallback do dotychczasowego customrepo."
    fi
    if [ "${#failed[@]}" -gt 0 ]; then
        warn "AUR failed: ${failed[*]}"
        printf '%s\n' "${failed[@]}" > "$MANIFEST_DIR/aur-failed-$BUILD_ID.txt"
    fi
}

write_build_manifest_v2() {
    mkdir -p "$MANIFEST_DIR"
    {
        echo "BUILD_ID=$BUILD_ID"
        echo "PRODUCT_VERSION=$PRODUCT_VERSION"
        echo "DATE=$(date -Iseconds)"
        echo "WORKROOT=$WORKROOT"
        echo "PROFILE=$PROFILE"
        echo "REPO_DIR=$REPO_DIR"
        echo "CUSTOMREPO=$CUSTOMREPO"
        echo "REPO_STAGE=$REPO_STAGE"
        echo "ISO_STAGE=$ISO_STAGE"
        echo "AUR_BUILD_MODE=$AUR_BUILD_MODE"
        echo "ARCH_SNAPSHOT_DATE=$ARCH_SNAPSHOT_DATE"
        echo "MAIN_LOG=$MAIN_LOG"
    } > "$MANIFEST_DIR/build-$BUILD_ID.env"
    [ -f "$PROFILE/packages.x86_64" ] && cp "$PROFILE/packages.x86_64" "$MANIFEST_DIR/packages-$BUILD_ID.x86_64" || true
}

# ------------------------------------------------------------
