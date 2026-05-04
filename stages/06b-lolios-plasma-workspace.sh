# Sourced by ../build.sh; local plasma-workspace package without default KDE Global Themes

# 6B. LoliOS Plasma Workspace repack
# ------------------------------------------------------------

log "Building custom repo Plasma Workspace package without default KDE Global Themes"

LOLIOS_PLASMA_PKGNAME="${LOLIOS_PLASMA_PKGNAME:-plasma-workspace-lolios}"
LOLIOS_PLASMA_BUILD_DIR="$WORKROOT/$LOLIOS_PLASMA_PKGNAME-build"
LOLIOS_PLASMA_CACHE_DIR="$LOLIOS_PLASMA_BUILD_DIR/cache"
LOLIOS_PLASMA_EXTRACT_DIR="$LOLIOS_PLASMA_BUILD_DIR/pkgroot"

find_official_plasma_workspace_pkg() {
    shopt -s nullglob
    local candidates=(
        "$LOLIOS_PLASMA_CACHE_DIR"/plasma-workspace-*.pkg.tar.zst
        "$LOLIOS_PLASMA_CACHE_DIR"/plasma-workspace-*.pkg.tar.xz
        /var/cache/pacman/pkg/plasma-workspace-*.pkg.tar.zst
        /var/cache/pacman/pkg/plasma-workspace-*.pkg.tar.xz
    )
    shopt -u nullglob

    if [ "${#candidates[@]}" -gt 0 ]; then
        printf '%s\n' "${candidates[@]}" | sort -V | tail -n1
    fi
}

build_lolios_plasma_workspace_pkg() {
    require_cmd pacman
    require_cmd bsdtar
    require_cmd repo-add
    require_cmd zstd

    mkdir -p "$CUSTOMREPO" "$REPO_DIR" "$LOLIOS_PLASMA_CACHE_DIR" "$LOG_DIR"
    rm -rf "$LOLIOS_PLASMA_EXTRACT_DIR" "$LOLIOS_PLASMA_BUILD_DIR/src" "$LOLIOS_PLASMA_BUILD_DIR/pkg"
    mkdir -p "$LOLIOS_PLASMA_EXTRACT_DIR" "$LOLIOS_PLASMA_BUILD_DIR/src"
    chmod 755 "$LOLIOS_PLASMA_CACHE_DIR"

    local official_pkg=""
    local download_log="$LOG_DIR/$LOLIOS_PLASMA_PKGNAME-download-$BUILD_ID.log"
    local build_log="$LOG_DIR/$LOLIOS_PLASMA_PKGNAME-$BUILD_ID.log"

    official_pkg="$(find_official_plasma_workspace_pkg || true)"

    if [ -z "$official_pkg" ] || [ ! -f "$official_pkg" ]; then
        rm -f "$LOLIOS_PLASMA_CACHE_DIR"/plasma-workspace-*.pkg.tar.* || true
        if sudo pacman -Syw --noconfirm --cachedir "$LOLIOS_PLASMA_CACHE_DIR" plasma-workspace >"$download_log" 2>&1; then
            sudo chown -R "$(id -u):$(id -g)" "$LOLIOS_PLASMA_CACHE_DIR" 2>/dev/null || true
            official_pkg="$(find_official_plasma_workspace_pkg || true)"
        fi
    fi

    if [ -z "$official_pkg" ] || [ ! -f "$official_pkg" ]; then
        cat >>"$download_log" <<EOF_LOG

[LOLIOS] Fallback lookup failed too.
Checked:
  $LOLIOS_PLASMA_CACHE_DIR/plasma-workspace-*.pkg.tar.*
  /var/cache/pacman/pkg/plasma-workspace-*.pkg.tar.*
EOF_LOG
        die "Nie udało się pobrać ani znaleźć oficjalnego plasma-workspace. Log: $download_log"
    fi

    echo "Using official package: $official_pkg" >"$build_log"
    bsdtar -xpf "$official_pkg" -C "$LOLIOS_PLASMA_EXTRACT_DIR" >>"$build_log" 2>&1

    [ -f "$LOLIOS_PLASMA_EXTRACT_DIR/.PKGINFO" ] || die "Oficjalna paczka plasma-workspace nie zawiera .PKGINFO: $official_pkg"

    local upstream_pkgver upstream_arch installed_size outpkg
    upstream_pkgver="$(awk -F' = ' '$1 == "pkgver" {print $2; exit}' "$LOLIOS_PLASMA_EXTRACT_DIR/.PKGINFO")"
    upstream_arch="$(awk -F' = ' '$1 == "arch" {print $2; exit}' "$LOLIOS_PLASMA_EXTRACT_DIR/.PKGINFO")"
    [ -n "$upstream_pkgver" ] || die "Nie udało się odczytać pkgver z .PKGINFO oficjalnego plasma-workspace"
    [ -n "$upstream_arch" ] || upstream_arch="x86_64"

    # Remove upstream KDE Global Theme packages from the payload. The LoliOS theme
    # itself is supplied by later airootfs overlay stages, not by this package, so
    # pacman does not conflict with pre-existing overlay files during mkarchiso.
    if [ -d "$LOLIOS_PLASMA_EXTRACT_DIR/usr/share/plasma/look-and-feel" ]; then
        find "$LOLIOS_PLASMA_EXTRACT_DIR/usr/share/plasma/look-and-feel" \
            -mindepth 1 -maxdepth 1 -type d -name 'org.kde.*' -exec rm -rf {} +
    fi
    rm -rf \
        "$LOLIOS_PLASMA_EXTRACT_DIR/usr/share/plasma/desktoptheme/breeze" \
        "$LOLIOS_PLASMA_EXTRACT_DIR/usr/share/plasma/desktoptheme/breeze-dark" \
        "$LOLIOS_PLASMA_EXTRACT_DIR/usr/share/plasma/desktoptheme/oxygen" \
        "$LOLIOS_PLASMA_EXTRACT_DIR/usr/share/sddm/themes/breeze" \
        "$LOLIOS_PLASMA_EXTRACT_DIR/usr/share/plasma/look-and-feel/org.lolios.desktop" \
        "$LOLIOS_PLASMA_EXTRACT_DIR/usr/share/plasma/desktoptheme/LoliOS" \
        "$LOLIOS_PLASMA_EXTRACT_DIR/usr/share/icons/LoliOS" \
        "$LOLIOS_PLASMA_EXTRACT_DIR/etc/sddm.conf.d/10-lolios-theme.conf" || true

    if [ -d "$LOLIOS_PLASMA_EXTRACT_DIR/usr/share/plasma/look-and-feel" ] && \
       find "$LOLIOS_PLASMA_EXTRACT_DIR/usr/share/plasma/look-and-feel" -mindepth 1 -maxdepth 1 -type d -name 'org.kde.*' | grep -q .; then
        find "$LOLIOS_PLASMA_EXTRACT_DIR/usr/share/plasma/look-and-feel" -mindepth 1 -maxdepth 1 -type d -name 'org.kde.*' >&2
        die "$LOLIOS_PLASMA_PKGNAME nadal zawiera defaultowe KDE Global Themes przed spakowaniem"
    fi

    # Rebuild package metadata directly. This avoids makepkg parser failures caused
    # by upstream metadata values while still producing a valid pacman package.
    rm -f "$LOLIOS_PLASMA_EXTRACT_DIR/.BUILDINFO" "$LOLIOS_PLASMA_EXTRACT_DIR/.MTREE" "$LOLIOS_PLASMA_EXTRACT_DIR/.PKGINFO"
    installed_size="$(du -sb "$LOLIOS_PLASMA_EXTRACT_DIR" | awk '{print $1}')"

    {
        echo "pkgname = $LOLIOS_PLASMA_PKGNAME"
        echo "pkgbase = $LOLIOS_PLASMA_PKGNAME"
        echo "pkgver = $upstream_pkgver"
        echo "pkgdesc = LoliOS Plasma Workspace repack without default KDE Global Themes"
        echo "url = https://github.com/HanaOrtega/LoliOS"
        echo "builddate = $(date +%s)"
        echo "packager = LoliOS Builder"
        echo "size = $installed_size"
        echo "arch = $upstream_arch"
        bsdtar -xOf "$official_pkg" .PKGINFO | grep -E '^(license|depend|optdepend|backup) = ' || true
        echo "provides = plasma-workspace"
        echo "provides = plasma-workspace=$upstream_pkgver"
        echo "conflict = plasma-workspace"
        echo "replaces = plasma-workspace"
    } > "$LOLIOS_PLASMA_EXTRACT_DIR/.PKGINFO"

    outpkg="$LOLIOS_PLASMA_BUILD_DIR/${LOLIOS_PLASMA_PKGNAME}-${upstream_pkgver}-${upstream_arch}.pkg.tar.zst"
    rm -f "$outpkg"
    (
        cd "$LOLIOS_PLASMA_EXTRACT_DIR"
        find . -mindepth 1 -printf '%P\0' | LC_ALL=C sort -z | bsdtar --null -T - --zstd -cf "$outpkg"
    ) >>"$build_log" 2>&1

    [ -f "$outpkg" ] || die "Nie udało się utworzyć paczki $LOLIOS_PLASMA_PKGNAME. Log: $build_log"

    cp -f "$outpkg" "$CUSTOMREPO/"
    cp -f "$outpkg" "$REPO_DIR/"

    (
        cd "$CUSTOMREPO"
        rm -f "$REPO_NAME".db* "$REPO_NAME".files*
        repo-add "$REPO_NAME".db.tar.gz ./*.pkg.tar.zst
        ln -sf "$REPO_NAME".db.tar.gz "$REPO_NAME".db
        ln -sf "$REPO_NAME".files.tar.gz "$REPO_NAME".files
    )

    if bsdtar -tf "$outpkg" | grep -qE '^usr/share/plasma/look-and-feel/org\.kde\.'; then
        die "$LOLIOS_PLASMA_PKGNAME nadal zawiera defaultowe KDE Global Themes"
    fi
    if bsdtar -tf "$outpkg" | grep -qE '^(etc/sddm\.conf\.d/10-lolios-theme\.conf|usr/share/icons/LoliOS/|usr/share/plasma/(desktoptheme/LoliOS|look-and-feel/org\.lolios\.desktop)/)'; then
        die "$LOLIOS_PLASMA_PKGNAME zawiera pliki LoliOS dostarczane przez overlay i spowoduje konflikt pacmana"
    fi

    # 06-local-repo-aur.sh embedded the repo before this stage existed, so refresh
    # the embedded /opt/lolios/repo copy after adding plasma-workspace-lolios.
    if declare -F sync_embedded_local_repo >/dev/null 2>&1; then
        sync_embedded_local_repo
    fi

    log "Built local package: $(basename "$outpkg")"
}

build_lolios_plasma_workspace_pkg

# ------------------------------------------------------------
