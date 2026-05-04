# Sourced by ../build.sh; last-resort removal of KDE default Global Themes

log "Purging all KDE default Global Theme packages from live and installed systems"

THEME_ROOT="$PROFILE/airootfs"
FINALIZER="$THEME_ROOT/usr/local/bin/lolios-purge-kde-default-global-themes"

mkdir -p \
  "$THEME_ROOT/usr/local/bin" \
  "$THEME_ROOT/etc/systemd/system/sysinit.target.wants" \
  "$THEME_ROOT/etc/systemd/system/multi-user.target.wants" \
  "$THEME_ROOT/etc/xdg/autostart" \
  "$THEME_ROOT/etc/skel/.config/autostart"

cat > "$FINALIZER" <<'EOF_FINALIZER'
#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="${1:-/}"
root_path() {
  local p="$1"
  printf '%s/%s' "${ROOT%/}" "${p#/}"
}

purge_global_themes() {
  local lnf desktoptheme sddm
  lnf="$(root_path /usr/share/plasma/look-and-feel)"
  desktoptheme="$(root_path /usr/share/plasma/desktoptheme)"
  sddm="$(root_path /usr/share/sddm/themes)"

  # KDE System Settings lists Global Theme entries from these KPackage folders.
  # Remove every upstream KDE global theme, not just a hand-written subset.
  if [ -d "$lnf" ]; then
    find "$lnf" -mindepth 1 -maxdepth 1 -type d -name 'org.kde.*' -exec rm -rf {} +
  fi

  rm -rf \
    "$desktoptheme/breeze" \
    "$desktoptheme/breeze-dark" \
    "$desktoptheme/oxygen" \
    "$sddm/breeze" || true
}

write_lolios_dark_theme() {
  mkdir -p \
    "$(root_path /usr/share/plasma/look-and-feel/org.lolios.desktop/contents)" \
    "$(root_path /usr/share/plasma/desktoptheme/LoliOS)" \
    "$(root_path /usr/share/icons/LoliOS)" \
    "$(root_path /etc/sddm.conf.d)"

  cat > "$(root_path /usr/share/plasma/look-and-feel/org.lolios.desktop/metadata.json)" <<'JSON'
{
  "KPackageStructure": "Plasma/LookAndFeel",
  "KPlugin": {
    "Id": "org.lolios.desktop",
    "Name": "LoliOS Dark",
    "Description": "Dark LoliOS Plasma global theme",
    "Version": "1.0",
    "Category": "Plasma Look And Feel",
    "EnabledByDefault": true
  },
  "X-KDE-PluginInfo-Name": "org.lolios.desktop",
  "X-Plasma-MainScript": "defaults"
}
JSON

  cat > "$(root_path /usr/share/plasma/look-and-feel/org.lolios.desktop/contents/defaults)" <<'EOF_DEFAULTS'
[kdeglobals][General]
ColorScheme=LoliOSCandy
Name=LoliOS Candy
AccentColor=226,64,255

[kdeglobals][KDE]
LookAndFeelPackage=org.lolios.desktop
SingleClick=false
contrast=7
widgetStyle=Breeze

[kdeglobals][Icons]
Theme=LoliOS

[plasmarc][Theme]
name=LoliOS

[ksplashrc][KSplash]
Theme=org.lolios.desktop
EOF_DEFAULTS

  cat > "$(root_path /usr/share/plasma/desktoptheme/LoliOS/metadata.json)" <<'JSON'
{
  "KPackageStructure": "Plasma/Theme",
  "KPlugin": {
    "Id": "LoliOS",
    "Name": "LoliOS Dark",
    "Description": "Dark LoliOS Plasma desktop theme",
    "Version": "1.0",
    "Category": "Plasma Theme",
    "EnabledByDefault": true
  },
  "X-KDE-PluginInfo-Name": "LoliOS"
}
JSON

  cat > "$(root_path /usr/share/icons/LoliOS/index.theme)" <<'EOF_ICONS'
[Icon Theme]
Name=LoliOS
Comment=LoliOS icon theme alias
Inherits=breeze-dark,breeze,hicolor
Directories=
EOF_ICONS

  cat > "$(root_path /etc/sddm.conf.d/10-lolios-theme.conf)" <<'EOF_SDDM'
[Theme]
Current=lolios
CursorTheme=LoliOS
Font=Noto Sans,10,-1,5,50,0,0,0,0,0
EOF_SDDM
}

write_user_dark_defaults() {
  local home="$1"
  mkdir -p "$(root_path "$home/.config")" "$(root_path "$home/.local/share/color-schemes")"
  [ -f "$(root_path /usr/share/color-schemes/LoliOSCandy.colors)" ] && cp -f "$(root_path /usr/share/color-schemes/LoliOSCandy.colors)" "$(root_path "$home/.local/share/color-schemes/LoliOSCandy.colors")"

  cat > "$(root_path "$home/.config/kdeglobals")" <<'EOF_KDEGLOBALS'
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
EOF_KDEGLOBALS

  cat > "$(root_path "$home/.config/plasmarc")" <<'EOF_PLASMARC'
[Theme]
name=LoliOS

[Wallpapers]
usersWallpapers=/usr/share/wallpapers/LoliOS/contents/lolios-dark.png
EOF_PLASMARC

  cat > "$(root_path "$home/.config/ksplashrc")" <<'EOF_KSPLASH'
[KSplash]
Theme=org.lolios.desktop
EOF_KSPLASH
}

clear_kde_caches() {
  rm -f "$(root_path /root)"/.cache/ksycoca* 2>/dev/null || true
  rm -f "$(root_path /var/tmp)"/kdecache-*/ksycoca* 2>/dev/null || true
  for home in /home/* /etc/skel; do
    [ -d "$(root_path "$home")" ] || continue
    rm -f "$(root_path "$home")"/.cache/ksycoca* 2>/dev/null || true
    rm -f "$(root_path "$home")"/.cache/icon-cache.kcache 2>/dev/null || true
    rm -rf "$(root_path "$home")"/.cache/plasma_theme_* 2>/dev/null || true
  done
}

write_lolios_dark_theme
purge_global_themes
write_user_dark_defaults /etc/skel
write_user_dark_defaults /root
for home in /home/*; do
  [ -d "$(root_path "$home")" ] || continue
  write_user_dark_defaults "$home"
done
clear_kde_caches

if [ -d "$(root_path /usr/share/plasma/look-and-feel)" ] && find "$(root_path /usr/share/plasma/look-and-feel)" -mindepth 1 -maxdepth 1 -type d -name 'org.kde.*' | grep -q .; then
  echo "[ERROR] KDE default Global Theme folders still exist:" >&2
  find "$(root_path /usr/share/plasma/look-and-feel)" -mindepth 1 -maxdepth 1 -type d -name 'org.kde.*' >&2
  exit 1
fi
EOF_FINALIZER
chmod +x "$FINALIZER"

# Run in the generated profile immediately.
"$FINALIZER" "$THEME_ROOT"

cat > "$THEME_ROOT/etc/systemd/system/lolios-purge-kde-default-global-themes.service" <<'EOF_SERVICE'
[Unit]
Description=Purge KDE default Global Themes and keep LoliOS Dark as the only Global Theme
DefaultDependencies=no
After=local-fs.target systemd-tmpfiles-setup.service
Before=display-manager.service sddm.service graphical.target multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/lolios-purge-kde-default-global-themes /
RemainAfterExit=yes

[Install]
WantedBy=sysinit.target
WantedBy=multi-user.target
EOF_SERVICE
ln -sf /etc/systemd/system/lolios-purge-kde-default-global-themes.service "$THEME_ROOT/etc/systemd/system/sysinit.target.wants/lolios-purge-kde-default-global-themes.service"
ln -sf /etc/systemd/system/lolios-purge-kde-default-global-themes.service "$THEME_ROOT/etc/systemd/system/multi-user.target.wants/lolios-purge-kde-default-global-themes.service"

cat > "$THEME_ROOT/etc/xdg/autostart/lolios-purge-kde-default-global-themes.desktop" <<'EOF_AUTOSTART'
[Desktop Entry]
Type=Application
Name=Purge KDE Default Global Themes
Exec=sh -c 'sudo -n /usr/local/bin/lolios-purge-kde-default-global-themes / 2>/dev/null || /usr/local/bin/lolios-apply-kde-theme || true'
OnlyShowIn=KDE;
X-KDE-autostart-after=panel
Terminal=false
EOF_AUTOSTART
cp -f "$THEME_ROOT/etc/xdg/autostart/lolios-purge-kde-default-global-themes.desktop" "$THEME_ROOT/etc/skel/.config/autostart/lolios-purge-kde-default-global-themes.desktop"

# Build-time hard fail for the generated overlay. Runtime service repeats the same
# purge after package extraction, which is where the default themes can reappear.
if [ -d "$THEME_ROOT/usr/share/plasma/look-and-feel" ] && find "$THEME_ROOT/usr/share/plasma/look-and-feel" -mindepth 1 -maxdepth 1 -type d -name 'org.kde.*' | grep -q .; then
  find "$THEME_ROOT/usr/share/plasma/look-and-feel" -mindepth 1 -maxdepth 1 -type d -name 'org.kde.*' >&2
  die "KDE default Global Theme folders remain in generated profile"
fi
