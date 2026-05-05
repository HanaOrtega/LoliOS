# Sourced by ../build.sh; safe overrides for runtime repo helpers

# 1C. Runtime repo helper overrides
# ------------------------------------------------------------

# Keep these overrides small: 01b still owns the high-level repo model, but these
# functions must not leave the sourced build shell in a different working dir.

is_disabled_repo_pkg() {
    local pkgbase="$1"
    local disabled
    for disabled in ${DISABLED_LOCAL_REPO_PKGS[*]:-}; do
        [ "$pkgbase" = "$disabled" ] && return 0
    done
    case "$pkgbase" in
        heroic-games-launcher-bin) return 0 ;;
    esac
    return 1
}

purge_disabled_repo_pkg_artifacts_from_dir() {
    local dir="$1"
    [ -d "$dir" ] || return 0
    rm -f \
        "$dir"/heroic-games-launcher-bin-*.pkg.tar.zst \
        "$dir"/heroic-games-launcher-bin-*.pkg.tar.zst.sig \
        "$dir"/heroic-games-launcher-bin-*.pkg.tar.xz \
        "$dir"/heroic-games-launcher-bin-*.pkg.tar.xz.sig \
        2>/dev/null || true
}

refresh_repo_dir_db() {
    log "Refreshing v2 repo dir without cwd side effects: $REPO_DIR"
    mkdir -p "$REPO_DIR" "$MANIFEST_DIR"
    purge_disabled_repo_pkg_artifacts_from_dir "$REPO_DIR"
    (
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
            local artifact
            for artifact in ./*.pkg.tar.zst "$REPO_NAME".db.tar.gz "$REPO_NAME".files.tar.gz; do
                [ -f "$artifact" ] || continue
                gpg --batch --yes --local-user "$GPG_KEY_ID" --detach-sign --use-agent "$artifact"
            done
        fi
        sha256sum ./*.pkg.tar.zst > SHA256SUMS
        ls -1 ./*.pkg.tar.zst | sed 's#^./##' > "$MANIFEST_DIR/repo-packages-$BUILD_ID.txt"
    )
}

build_aur_pkg_v2() {
    local pkgbase="$1"
    local logf="$LOG_DIR/aur-${pkgbase}-$BUILD_ID.log"
    if is_disabled_repo_pkg "$pkgbase"; then
        warn "AUR package disabled by LoliOS policy; skipping: $pkgbase"
        purge_disabled_repo_pkg_artifacts_from_dir "$REPO_DIR"
        return 0
    fi
    log "AUR v2 build without cwd side effects: $pkgbase"
    mkdir -p "$AUR_SRC_DIR" "$REPO_DIR" "$LOG_DIR"
    : >"$logf"
    (
        cd "$AUR_SRC_DIR"
        rm -rf "$pkgbase"
        if ! git clone --depth=1 "https://aur.archlinux.org/${pkgbase}.git" "$pkgbase" >>"$logf" 2>&1; then
            echo "AUR clone failed for $pkgbase" >&2
            return 1
        fi
        if [ ! -d "$pkgbase" ]; then
            echo "AUR clone did not create directory: $pkgbase" >&2
            return 1
        fi
        cd "$pkgbase"
        [ -f PKGBUILD ] || { echo "Brak PKGBUILD: $pkgbase" >&2; return 1; }
        if ! makepkg -s --noconfirm --needed --cleanbuild >>"$logf" 2>&1; then
            echo "makepkg failed for $pkgbase" >&2
            return 1
        fi
        shopt -s nullglob
        local built=( ./*.pkg.tar.zst )
        shopt -u nullglob
        [ "${#built[@]}" -gt 0 ] || { echo "No package artifact produced for $pkgbase" >&2; return 1; }
        cp -f ./*.pkg.tar.zst "$REPO_DIR/"
    ) || { warn "AUR build failed: $pkgbase; log: $logf"; return 1; }
    purge_disabled_repo_pkg_artifacts_from_dir "$REPO_DIR"
}

build_aur_pkg_clean_chroot_v2() {
    local pkgbase="$1"
    local logf="$LOG_DIR/aur-chroot-${pkgbase}-$BUILD_ID.log"
    if is_disabled_repo_pkg "$pkgbase"; then
        warn "AUR package disabled by LoliOS policy; skipping: $pkgbase"
        purge_disabled_repo_pkg_artifacts_from_dir "$REPO_DIR"
        return 0
    fi
    command -v mkarchroot >/dev/null 2>&1 || { warn "mkarchroot missing; fallback host build"; build_aur_pkg_v2 "$pkgbase"; return $?; }
    command -v makechrootpkg >/dev/null 2>&1 || { warn "makechrootpkg missing; fallback host build"; build_aur_pkg_v2 "$pkgbase"; return $?; }
    log "AUR clean-chroot build without cwd side effects: $pkgbase"
    mkdir -p "$AUR_SRC_DIR" "$REPO_DIR" "$CLEAN_CHROOT_DIR" "$LOG_DIR"
    : >"$logf"
    [ -d "$CLEAN_CHROOT_DIR/root" ] || sudo mkarchroot "$CLEAN_CHROOT_DIR/root" base-devel git sudo pacman-contrib >"$LOG_DIR/mkarchroot-$BUILD_ID.log" 2>&1
    (
        cd "$AUR_SRC_DIR"
        rm -rf "$pkgbase"
        if ! git clone --depth=1 "https://aur.archlinux.org/${pkgbase}.git" "$pkgbase" >>"$logf" 2>&1; then
            echo "AUR clone failed for $pkgbase" >&2
            return 1
        fi
        if [ ! -d "$pkgbase" ]; then
            echo "AUR clone did not create directory: $pkgbase" >&2
            return 1
        fi
        cd "$pkgbase"
        [ -f PKGBUILD ] || { echo "Brak PKGBUILD: $pkgbase" >&2; return 1; }
        if ! makechrootpkg -c -r "$CLEAN_CHROOT_DIR" >>"$logf" 2>&1; then
            echo "makechrootpkg failed for $pkgbase" >&2
            return 1
        fi
        shopt -s nullglob
        local built=( ./*.pkg.tar.zst )
        shopt -u nullglob
        [ "${#built[@]}" -gt 0 ] || { echo "No package artifact produced for $pkgbase" >&2; return 1; }
        cp -f ./*.pkg.tar.zst "$REPO_DIR/"
    ) || { warn "AUR clean-chroot build failed: $pkgbase; log: $logf"; return 1; }
    purge_disabled_repo_pkg_artifacts_from_dir "$REPO_DIR"
}

# ------------------------------------------------------------
