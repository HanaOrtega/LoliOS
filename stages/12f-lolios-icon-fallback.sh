# Sourced by ../build.sh; copy Breeze Dark icons from host and expose them as LoliOS icon theme

# 12F. LoliOS icon export and fallback
# ------------------------------------------------------------

log "Exporting host Breeze Dark icon theme as LoliOS icon theme"

ICON_THEME_DIR="$PROFILE/airootfs/usr/share/icons/LoliOS"
ICON_INDEX="$ICON_THEME_DIR/index.theme"
ICON_CACHE_ROOT="${LOLIOS_ICON_CACHE_ROOT:-$WORKROOT/cache/icons}"
HOST_ICON_ROOTS=(
  "${LOLIOS_HOST_ICON_ROOT:-/home/Hana/.local/share/icons}"
  "/home/Hana/.icons"
  "/usr/share/icons"
)
HOST_ICON_NAME="${LOLIOS_HOST_ICON_NAME:-breeze-dark}"
HOST_ICON_SOURCE=""

find_icon_theme_source() {
    local name="$1"
    local root
    [ -n "$name" ] || return 1
    for root in "${HOST_ICON_ROOTS[@]}"; do
        [ -d "$root/$name" ] && { printf '%s\n' "$root/$name"; return 0; }
    done
    return 1
}

icon_theme_signature() {
    local src="$1"
    [ -d "$src" ] || return 1
    if command -v find >/dev/null 2>&1 && command -v sha256sum >/dev/null 2>&1; then
        {
            printf 'source=%s\n' "$src"
            printf 'name=%s\n' "$HOST_ICON_NAME"
            find "$src" -xdev -type f \( -iname '*.svg' -o -iname '*.svgz' -o -iname '*.png' -o -iname '*.xpm' -o -iname 'index.theme' \) \
                -printf '%P\t%s\t%T@\n' 2>/dev/null | LC_ALL=C sort
        } | sha256sum | awk '{print $1}'
    else
        printf '%s-%s\n' "$src" "$(stat -c '%Y-%s' "$src" 2>/dev/null || date +%s)" | sha256sum | awk '{print $1}'
    fi
}

copy_icon_theme_deref() {
    local src="$1"
    local dest="$2"
    local sig cache_dir manifest
    [ -d "$src" ] || return 0
    mkdir -p "$ICON_CACHE_ROOT"
    sig="$(icon_theme_signature "$src")"
    cache_dir="$ICON_CACHE_ROOT/$sig"
    manifest="$cache_dir/.lolios-icon-cache-manifest"

    if [ ! -f "$manifest" ]; then
        log "Creating icon cache for $(basename "$src")"
        rm -rf "$cache_dir.tmp"
        mkdir -p "$cache_dir.tmp"
        if command -v rsync >/dev/null 2>&1; then
            rsync -aL --delete "$src"/ "$cache_dir.tmp"/
        else
            cp -aL "$src"/. "$cache_dir.tmp"/
        fi
        printf 'source=%s\nsignature=%s\ncreated=%s\n' "$src" "$sig" "$(date -Iseconds 2>/dev/null || date)" > "$cache_dir.tmp/.lolios-icon-cache-manifest"
        rm -rf "$cache_dir"
        mv "$cache_dir.tmp" "$cache_dir"
    else
        log "Using cached icon theme for $(basename "$src"): $sig"
    fi

    rm -rf "$dest"
    mkdir -p "$dest"
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --delete "$cache_dir"/ "$dest"/
    else
        cp -a "$cache_dir"/. "$dest"/
    fi
}

read_icon_inherits() {
    local index="$1"
    [ -f "$index" ] || return 0
    awk -F= '
        /^\[Icon Theme\]$/ { in_theme=1; next }
        /^\[/ && $0 != "[Icon Theme]" { in_theme=0 }
        in_theme && $1 == "Inherits" { print $2; exit }
    ' "$index" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' || true
}

is_packaged_icon_theme() {
    case "$1" in
        LoliOS|loliOS|lolios|breeze|breeze-dark|hicolor|Adwaita|gnome) return 0 ;;
        *) return 1 ;;
    esac
}

copy_local_inherited_themes() {
    local src_index="$1"
    local inherited theme_src theme_name dest
    inherited="$(read_icon_inherits "$src_index" || true)"
    [ -n "$inherited" ] || return 0

    while IFS= read -r theme_name; do
        [ -n "$theme_name" ] || continue
        if is_packaged_icon_theme "$theme_name"; then
            continue
        fi
        theme_src="$(find_icon_theme_source "$theme_name" || true)"
        [ -n "$theme_src" ] || continue
        dest="$PROFILE/airootfs/usr/share/icons/$theme_name"
        [ "$dest" = "$ICON_THEME_DIR" ] && continue
        log "Copying inherited host icon theme: $theme_name from $theme_src"
        copy_icon_theme_deref "$theme_src" "$dest"
    done <<< "$inherited"
}

HOST_ICON_SOURCE="$(find_icon_theme_source "$HOST_ICON_NAME" || true)"
if [ -z "$HOST_ICON_SOURCE" ] && [ "$HOST_ICON_NAME" != "breeze-dark" ]; then
    warn "Requested icon theme '$HOST_ICON_NAME' not found; falling back to host breeze-dark"
    HOST_ICON_SOURCE="$(find_icon_theme_source "breeze-dark" || true)"
fi
if [ -z "$HOST_ICON_SOURCE" ]; then
    warn "Host breeze-dark icon theme not found; trying breeze"
    HOST_ICON_SOURCE="$(find_icon_theme_source "breeze" || true)"
fi

if [ -n "$HOST_ICON_SOURCE" ]; then
    log "Copying host icon theme as LoliOS: $HOST_ICON_SOURCE"
    copy_icon_theme_deref "$HOST_ICON_SOURCE" "$ICON_THEME_DIR"
    copy_local_inherited_themes "$HOST_ICON_SOURCE/index.theme"
else
    warn "No host breeze-dark/breeze icon theme found; creating metadata-only LoliOS icon theme"
    rm -rf "$ICON_THEME_DIR"
    mkdir -p "$ICON_THEME_DIR"
fi

# Never ship package-owned fallback icon directories as overlay files. Pacman owns
# these through breeze-icons/hicolor-icon-theme; leaving them in airootfs before
# package installation causes 'exists in filesystem' transaction failures.
rm -rf \
    "$PROFILE/airootfs/usr/share/icons/breeze" \
    "$PROFILE/airootfs/usr/share/icons/breeze-dark" \
    "$PROFILE/airootfs/usr/share/icons/hicolor" \
    "$PROFILE/airootfs/usr/share/icons/Adwaita" \
    "$PROFILE/airootfs/usr/share/icons/gnome" || true

# Rename the copied original icon theme to LoliOS icon while keeping its directory
# sections. Folder name remains LoliOS because KDE uses the folder/id in configs.
if [ -f "$ICON_INDEX" ]; then
    awk '
        /^\[Icon Theme\]$/ {
            print
            print "Name=LoliOS icon"
            print "Comment=LoliOS icon theme based on Breeze Dark"
            print "Inherits=breeze-dark,breeze,hicolor"
            in_icon_theme=1
            next
        }
        /^\[/ && $0 != "[Icon Theme]" {
            in_icon_theme=0
            print
            next
        }
        in_icon_theme && /^(Name|Comment|Inherits|Example)=/ { next }
        { print }
    ' "$ICON_INDEX" > "$ICON_INDEX.tmp"
    mv "$ICON_INDEX.tmp" "$ICON_INDEX"
else
    cat > "$ICON_INDEX" <<'EOF_ICONS'
[Icon Theme]
Name=LoliOS icon
Comment=LoliOS icon theme based on Breeze Dark
Inherits=breeze-dark,breeze,hicolor
Directories=
EOF_ICONS
fi

# Generate Directories= if the host index was incomplete after copying.
if ! grep -q '^Directories=' "$ICON_INDEX"; then
    dirs="$(find "$ICON_THEME_DIR" -mindepth 2 -maxdepth 2 -type d \
        ! -path '*/.*' \
        -printf '%P\n' 2>/dev/null | LC_ALL=C sort | paste -sd, -)"
    printf 'Directories=%s\n' "$dirs" >> "$ICON_INDEX"
fi
sed -i 's/^Inherits=$/Inherits=breeze-dark,breeze,hicolor/' "$ICON_INDEX"

# Integrate the icon theme with LoliOS Global Theme defaults.
LNF_DEFAULTS="$PROFILE/airootfs/usr/share/plasma/look-and-feel/org.lolios.desktop/contents/defaults"
if [ -f "$LNF_DEFAULTS" ]; then
    if grep -q '^\[kdeglobals\]\[Icons\]' "$LNF_DEFAULTS"; then
        if grep -A20 '^\[kdeglobals\]\[Icons\]' "$LNF_DEFAULTS" | grep -q '^Theme='; then
            sed -i '/^\[kdeglobals\]\[Icons\]/,/^\[/ s/^Theme=.*/Theme=LoliOS/' "$LNF_DEFAULTS"
        else
            sed -i '/^\[kdeglobals\]\[Icons\]/a Theme=LoliOS' "$LNF_DEFAULTS"
        fi
    else
        cat >> "$LNF_DEFAULTS" <<'EOF_DEFAULTS'

[kdeglobals][Icons]
Theme=LoliOS
EOF_DEFAULTS
    fi
fi

# Build icon cache inside the profile when possible. Pacman hooks will refresh it
# again during mkarchiso, but having it here helps manual profile testing.
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t "$ICON_THEME_DIR" >/dev/null 2>&1 || true
fi

# Plasma/KIconLoader needs these fallback packages in the image.
add_pkg breeze-icons
add_pkg hicolor-icon-theme

# Keep user and system defaults explicit.
for cfg in \
    "$PROFILE/airootfs/etc/skel/.config/kdeglobals" \
    "$PROFILE/airootfs/root/.config/kdeglobals" \
    "$PROFILE/airootfs/etc/xdg/kdeglobals"
 do
    [ -f "$cfg" ] || continue
    if grep -q '^\[Icons\]' "$cfg"; then
        if grep -A20 '^\[Icons\]' "$cfg" | grep -q '^Theme='; then
            sed -i '/^\[Icons\]/,/^\[/ s/^Theme=.*/Theme=LoliOS/' "$cfg"
        else
            sed -i '/^\[Icons\]/a Theme=LoliOS' "$cfg"
        fi
    else
        cat >> "$cfg" <<'EOF_CFG'

[Icons]
Theme=LoliOS
EOF_CFG
    fi
 done

ICON_FILE_COUNT="$(find "$ICON_THEME_DIR" -type f \( -iname '*.svg' -o -iname '*.svgz' -o -iname '*.png' -o -iname '*.xpm' \) 2>/dev/null | wc -l)"
if [ "$ICON_FILE_COUNT" -eq 0 ]; then
    warn "LoliOS icon theme contains no icon files. Check host /usr/share/icons/breeze-dark and LOLIOS_HOST_ICON_NAME."
else
    log "LoliOS icon files exported from $(basename "${HOST_ICON_SOURCE:-metadata-only}"): $ICON_FILE_COUNT"
fi

# Hard guard: package-owned fallback themes must not exist in airootfs overlay.
for packaged_theme in breeze breeze-dark hicolor Adwaita gnome; do
    if [ -e "$PROFILE/airootfs/usr/share/icons/$packaged_theme" ]; then
        die "Package-owned icon theme exists in airootfs overlay and would conflict with pacman: /usr/share/icons/$packaged_theme"
    fi
done

# ------------------------------------------------------------
