# Sourced by ../build.sh; lightweight KDE theme ownership check

# 12C. KDE theme check
# ------------------------------------------------------------

log "Checking LoliOS KDE theme overlay"

THEME_ROOT="$PROFILE/airootfs"

[ -d "$THEME_ROOT/usr/share/plasma/look-and-feel/org.lolios.desktop" ] || \
    die "Missing LoliOS Global Theme: /usr/share/plasma/look-and-feel/org.lolios.desktop"
[ -f "$THEME_ROOT/usr/share/plasma/look-and-feel/org.lolios.desktop/metadata.json" ] || \
    die "Missing LoliOS Global Theme metadata.json"
[ -f "$THEME_ROOT/usr/share/plasma/look-and-feel/org.lolios.desktop/contents/defaults" ] || \
    die "Missing LoliOS Global Theme defaults"
[ -f "$THEME_ROOT/usr/share/plasma/desktoptheme/LoliOS/metadata.json" ] || \
    die "Missing LoliOS Plasma desktop theme metadata.json"
[ -f "$THEME_ROOT/usr/share/color-schemes/LoliOSCandy.colors" ] || \
    die "Missing LoliOS color scheme"
[ -f "$THEME_ROOT/etc/skel/.config/kdeglobals" ] || \
    die "Missing /etc/skel KDE defaults"
[ -f "$THEME_ROOT/root/.config/kdeglobals" ] || \
    die "Missing /root KDE defaults"
[ -f "$THEME_ROOT/etc/sddm.conf.d/10-lolios-theme.conf" ] || \
    die "Missing LoliOS SDDM theme config"

if find "$THEME_ROOT/usr/share/plasma/look-and-feel" -mindepth 1 -maxdepth 1 -type d -name 'org.kde.*' 2>/dev/null | grep -q .; then
    find "$THEME_ROOT/usr/share/plasma/look-and-feel" -mindepth 1 -maxdepth 1 -type d -name 'org.kde.*' >&2
    die "KDE upstream Global Theme folders are present in airootfs overlay"
fi

if ! grep -q '^NoExtract = usr/share/plasma/look-and-feel/org.kde\.\*' "$PROFILE/pacman.conf"; then
    die "pacman.conf does not block upstream KDE Global Theme extraction"
fi

log "LoliOS KDE theme overlay check passed"

# ------------------------------------------------------------
