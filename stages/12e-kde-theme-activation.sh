# Sourced by ../build.sh; activate LoliOS KDE theme automatically

# 12E. KDE session initialization
# ------------------------------------------------------------

log "Writing automatic LoliOS KDE session initialization"

THEME_ROOT="$PROFILE/airootfs"

mkdir -p \
  "$THEME_ROOT/etc/xdg" \
  "$THEME_ROOT/etc/xdg/autostart" \
  "$THEME_ROOT/etc/skel/.config/autostart" \
  "$THEME_ROOT/root/.config/autostart" \
  "$THEME_ROOT/usr/local/bin" \
  "$THEME_ROOT/usr/lib/systemd/user" \
  "$THEME_ROOT/etc/systemd/user/default.target.wants"

cat > "$THEME_ROOT/etc/xdg/kdeglobals" <<'EOF_KDEGLOBALS'
[General]
ColorScheme=LoliOSCandy
Name=LoliOS Candy
AccentColor=226,64,255
font=Noto Sans,10,-1,5,50,0,0,0,0,0
menuFont=Noto Sans,10,-1,5,50,0,0,0,0,0
smallestReadableFont=Noto Sans,8,-1,5,50,0,0,0,0,0
toolBarFont=Noto Sans,10,-1,5,50,0,0,0,0,0
fixed=Hack,10,-1,5,50,0,0,0,0,0

[KDE]
LookAndFeelPackage=org.lolios.desktop
SingleClick=false
contrast=7
widgetStyle=Breeze

[Icons]
Theme=LoliOS

[WM]
activeBackground=20,16,30
activeForeground=255,255,255
inactiveBackground=14,13,22
inactiveForeground=168,154,184
EOF_KDEGLOBALS

cat > "$THEME_ROOT/etc/xdg/plasmarc" <<'EOF_PLASMARC'
[Theme]
name=LoliOS

[Wallpapers]
usersWallpapers=/usr/share/wallpapers/LoliOS/contents/lolios-dark.png
EOF_PLASMARC

cat > "$THEME_ROOT/etc/xdg/ksplashrc" <<'EOF_KSPLASH'
[KSplash]
Theme=org.lolios.desktop
EOF_KSPLASH

cat > "$THEME_ROOT/etc/xdg/kscreenlockerrc" <<'EOF_LOCK'
[Greeter][Wallpaper][org.kde.image][General]
Image=file:///usr/share/wallpapers/LoliOS/contents/lolios-dark.png
FillMode=2
EOF_LOCK

cat > "$THEME_ROOT/usr/local/bin/lolios-session-init" <<'EOF_SESSION'
#!/usr/bin/env bash
set -u

[ "${EUID:-$(id -u)}" -eq 0 ] && exit 0

LOG="$HOME/.cache/lolios-session-init.log"
WALL="/usr/share/wallpapers/LoliOS/contents/lolios-dark.png"
FIRST_LAYOUT_MARKER="$HOME/.config/lolios/desktop-layout-applied"
mkdir -p "$HOME/.cache" "$HOME/.config/lolios" "$HOME/.local/share/color-schemes"

write_theme_config() {
  [ -f /usr/share/color-schemes/LoliOSCandy.colors ] && \
    cp -f /usr/share/color-schemes/LoliOSCandy.colors "$HOME/.local/share/color-schemes/LoliOSCandy.colors" || true

  if command -v kwriteconfig6 >/dev/null 2>&1; then
    kwriteconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage org.lolios.desktop || true
    kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle Breeze || true
    kwriteconfig6 --file kdeglobals --group General --key ColorScheme LoliOSCandy || true
    kwriteconfig6 --file kdeglobals --group General --key Name "LoliOS Candy" || true
    kwriteconfig6 --file kdeglobals --group General --key AccentColor "226,64,255" || true
    kwriteconfig6 --file kdeglobals --group Icons --key Theme LoliOS || true
    kwriteconfig6 --file plasmarc --group Theme --key name LoliOS || true
    kwriteconfig6 --file ksplashrc --group KSplash --key Theme org.lolios.desktop || true
    kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image "file://$WALL" || true
    kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key FillMode 2 || true
  else
    mkdir -p "$HOME/.config"
    cat > "$HOME/.config/kdeglobals" <<'EOF_KDE'
[General]
ColorScheme=LoliOSCandy
Name=LoliOS Candy
AccentColor=226,64,255

[KDE]
LookAndFeelPackage=org.lolios.desktop
SingleClick=false
contrast=7
widgetStyle=Breeze

[Icons]
Theme=LoliOS
EOF_KDE
    cat > "$HOME/.config/plasmarc" <<'EOF_PLASMA'
[Theme]
name=LoliOS
EOF_PLASMA
    cat > "$HOME/.config/ksplashrc" <<'EOF_SPLASH'
[KSplash]
Theme=org.lolios.desktop
EOF_SPLASH
  fi
}

apply_theme_once() {
  if ! command -v plasma-apply-lookandfeel >/dev/null 2>&1; then
    return 0
  fi

  if [ ! -e "$FIRST_LAYOUT_MARKER" ]; then
    echo "first run: applying LoliOS appearance plus desktop/window layout"
    plasma-apply-lookandfeel --apply org.lolios.desktop --resetLayout || \
      plasma-apply-lookandfeel -a org.lolios.desktop --resetLayout || \
      plasma-apply-lookandfeel -a org.lolios.desktop || true
    touch "$FIRST_LAYOUT_MARKER"
  else
    plasma-apply-lookandfeel --apply org.lolios.desktop || \
      plasma-apply-lookandfeel -a org.lolios.desktop || true
  fi
}

ensure_wallpaper() {
  [ -f "$WALL" ] || return 0
  command -v plasma-apply-wallpaperimage >/dev/null 2>&1 && plasma-apply-wallpaperimage "$WALL" || true
}

ensure_panel_config() {
  local config="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
  grep -q 'plugin=org.kde.panel' "$config" 2>/dev/null && grep -q 'org.kde.plasma.kickoff' "$config" 2>/dev/null && return 0
  command -v lolios-ensure-plasma-panel >/dev/null 2>&1 && lolios-ensure-plasma-panel || true
}

{
  echo "[$(date -Iseconds)] LoliOS KDE session init"
  write_theme_config
  apply_theme_once
  command -v plasma-apply-colorscheme >/dev/null 2>&1 && plasma-apply-colorscheme LoliOSCandy || true
  command -v plasma-apply-desktoptheme >/dev/null 2>&1 && plasma-apply-desktoptheme LoliOS || true
  ensure_wallpaper
  ensure_panel_config
  command -v kbuildsycoca6 >/dev/null 2>&1 && kbuildsycoca6 --noincremental || true
  touch "$HOME/.config/lolios/theme-activated"
} >>"$LOG" 2>&1
EOF_SESSION
chmod +x "$THEME_ROOT/usr/local/bin/lolios-session-init"

# Compatibility wrappers for older audit checks and desktop entries.
cat > "$THEME_ROOT/usr/local/bin/lolios-activate-kde-theme" <<'EOF_ACTIVATE'
#!/usr/bin/env bash
exec /usr/local/bin/lolios-session-init "$@"
EOF_ACTIVATE
chmod +x "$THEME_ROOT/usr/local/bin/lolios-activate-kde-theme"

cat > "$THEME_ROOT/usr/local/bin/lolios-apply-kde-theme" <<'EOF_APPLY'
#!/usr/bin/env bash
exec /usr/local/bin/lolios-session-init "$@"
EOF_APPLY
chmod +x "$THEME_ROOT/usr/local/bin/lolios-apply-kde-theme"

cat > "$THEME_ROOT/usr/lib/systemd/user/lolios-session-init.service" <<'EOF_SERVICE'
[Unit]
Description=Initialize LoliOS KDE session for this user
After=plasma-ksplash-ready.service
ConditionEnvironment=XDG_CURRENT_DESKTOP=KDE

[Service]
Type=oneshot
ExecStart=/usr/local/bin/lolios-session-init

[Install]
WantedBy=default.target
EOF_SERVICE
ln -sf /usr/lib/systemd/user/lolios-session-init.service \
  "$THEME_ROOT/etc/systemd/user/default.target.wants/lolios-session-init.service"

cat > "$THEME_ROOT/etc/xdg/autostart/lolios-activate-kde-theme.desktop" <<'EOF_AUTOSTART'
[Desktop Entry]
Type=Application
Name=Initialize LoliOS KDE Session
Exec=/usr/local/bin/lolios-session-init
OnlyShowIn=KDE;
X-KDE-autostart-before=panel
Terminal=false
EOF_AUTOSTART
cp -f "$THEME_ROOT/etc/xdg/autostart/lolios-activate-kde-theme.desktop" \
  "$THEME_ROOT/etc/skel/.config/autostart/lolios-activate-kde-theme.desktop"
cp -f "$THEME_ROOT/etc/xdg/autostart/lolios-activate-kde-theme.desktop" \
  "$THEME_ROOT/root/.config/autostart/lolios-activate-kde-theme.desktop"

rm -f "$THEME_ROOT/etc/xdg/autostart/lolios-set-wallpaper.desktop"
rm -f "$THEME_ROOT/etc/skel/.config/autostart/lolios-apply-kde-theme.desktop"
rm -f "$THEME_ROOT/root/.config/autostart/lolios-apply-kde-theme.desktop"

# ------------------------------------------------------------
