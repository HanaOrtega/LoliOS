# Sourced by ../build.sh; LoliOS KDE theme defaults for live + installed users

log "Writing LoliOS Dark KDE theme overlay"

WALL_DIR="$PROFILE/airootfs/usr/share/wallpapers/LoliOS"
WALL_TARGET="$PROFILE/airootfs$WALL_ISO"
LOLIOS_LNF_DIR="$PROFILE/airootfs/usr/share/plasma/look-and-feel/org.lolios.desktop"
LOLIOS_DESKTOPTHEME_DIR="$PROFILE/airootfs/usr/share/plasma/desktoptheme/LoliOS"
LOLIOS_SDDM_DIR="$PROFILE/airootfs/usr/share/sddm/themes/lolios"
LOLIOS_ICONS_DIR="$PROFILE/airootfs/usr/share/icons/LoliOS"
HOST_LNF_ROOT="${LOLIOS_HOST_LNF_ROOT:-/home/Hana/.local/share/plasma/look-and-feel}"
HOST_LNF_NAME="${LOLIOS_HOST_LNF_NAME:-}"
HOST_LNF_SOURCE=""
HOST_ICON_ROOTS=(
  "${LOLIOS_HOST_ICON_ROOT:-/home/Hana/.local/share/icons}"
  "/home/Hana/.icons"
  "/usr/share/icons"
)
HOST_ICON_NAME="${LOLIOS_HOST_ICON_NAME:-}"
HOST_ICON_SOURCE=""

select_host_lnf_source() {
  [ -d "$HOST_LNF_ROOT" ] || return 0

  if [ -n "$HOST_LNF_NAME" ] && [ -d "$HOST_LNF_ROOT/$HOST_LNF_NAME" ]; then
    HOST_LNF_SOURCE="$HOST_LNF_ROOT/$HOST_LNF_NAME"
    return 0
  fi

  local candidate
  shopt -s nullglob
  for candidate in "$HOST_LNF_ROOT"/*; do
    [ -d "$candidate" ] || continue
    case "$(basename "$candidate" | tr '[:upper:]' '[:lower:]')" in
      *lolios*|*loli*)
        HOST_LNF_SOURCE="$candidate"
        shopt -u nullglob
        return 0
        ;;
    esac
  done

  for candidate in "$HOST_LNF_ROOT"/*; do
    [ -d "$candidate" ] || continue
    case "$(basename "$candidate")" in
      org.kde.*) continue ;;
    esac
    HOST_LNF_SOURCE="$candidate"
    shopt -u nullglob
    return 0
  done
  shopt -u nullglob
}

select_host_icon_source() {
  local root candidate

  if [ -n "$HOST_ICON_NAME" ]; then
    for root in "${HOST_ICON_ROOTS[@]}"; do
      [ -d "$root/$HOST_ICON_NAME" ] || continue
      HOST_ICON_SOURCE="$root/$HOST_ICON_NAME"
      return 0
    done
  fi

  for root in "${HOST_ICON_ROOTS[@]}"; do
    [ -d "$root" ] || continue
    shopt -s nullglob
    for candidate in "$root"/*; do
      [ -d "$candidate" ] || continue
      [ -f "$candidate/index.theme" ] || continue
      case "$(basename "$candidate" | tr '[:upper:]' '[:lower:]')" in
        *lolios*|*loli*)
          HOST_ICON_SOURCE="$candidate"
          shopt -u nullglob
          return 0
          ;;
      esac
    done
    shopt -u nullglob
  done
}

write_lolios_sddm_theme() {
  mkdir -p "$LOLIOS_SDDM_DIR"
  cat > "$LOLIOS_SDDM_DIR/metadata.desktop" <<'EOF_SDDM_META'
[SddmGreeterTheme]
Name=LoliOS Dark
Description=LoliOS dark SDDM theme
Type=sddm-theme
Version=1.0
MainScript=Main.qml
ConfigFile=theme.conf
Theme-Id=lolios
Theme-API=2.0
EOF_SDDM_META

  cat > "$LOLIOS_SDDM_DIR/theme.conf" <<'EOF_SDDM_THEME'
[General]
background=/usr/share/wallpapers/LoliOS/contents/lolios-dark.png
type=image
EOF_SDDM_THEME

  cat > "$LOLIOS_SDDM_DIR/Main.qml" <<'EOF_SDDM_QML'
import QtQuick 2.15
import SddmComponents 2.0

Rectangle {
    id: root
    color: "#090912"

    Image {
        anchors.fill: parent
        source: "/usr/share/wallpapers/LoliOS/contents/lolios-dark.png"
        fillMode: Image.PreserveAspectCrop
    }
    Rectangle { anchors.fill: parent; color: "#aa090912" }

    Column {
        anchors.centerIn: parent
        spacing: 14
        width: 320

        Text {
            text: "LoliOS"
            color: "#f5e9ff"
            font.pixelSize: 44
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
        }

        Text {
            text: userModel.lastUser.length > 0 ? userModel.lastUser : "live"
            color: "#dfc9ff"
            font.pixelSize: 18
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
        }

        Rectangle {
            width: parent.width
            height: 44
            radius: 8
            color: "#22172d"
            border.color: "#d040ff"
            TextInput {
                id: password
                anchors.fill: parent
                anchors.margins: 10
                color: "#ffffff"
                echoMode: TextInput.Password
                focus: true
                verticalAlignment: TextInput.AlignVCenter
                Keys.onReturnPressed: sddm.login(userModel.lastUser.length > 0 ? userModel.lastUser : "live", password.text, sessionModel.lastIndex)
                Keys.onEnterPressed: sddm.login(userModel.lastUser.length > 0 ? userModel.lastUser : "live", password.text, sessionModel.lastIndex)
            }
        }

        Rectangle {
            width: parent.width
            height: 44
            radius: 8
            color: "#b52cff"
            Text { anchors.centerIn: parent; text: "Login"; color: "white"; font.pixelSize: 16; font.bold: true }
            MouseArea { anchors.fill: parent; onClicked: sddm.login(userModel.lastUser.length > 0 ? userModel.lastUser : "live", password.text, sessionModel.lastIndex) }
        }

        Text {
            text: "Autologin enabled for live session"
            color: "#c9b8da"
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
        }
    }

    Component.onCompleted: password.forceActiveFocus()
}
EOF_SDDM_QML
}

mkdir -p \
  "$WALL_DIR/contents/images" \
  "$PROFILE/airootfs/etc/skel/.config/autostart" \
  "$PROFILE/airootfs/etc/skel/.local/share/color-schemes" \
  "$PROFILE/airootfs/root/.config" \
  "$PROFILE/airootfs/root/.local/share/color-schemes" \
  "$PROFILE/airootfs/usr/share/color-schemes" \
  "$PROFILE/airootfs/usr/local/bin" \
  "$PROFILE/airootfs/etc/sddm.conf.d" \
  "$PROFILE/airootfs/usr/share/plasma/look-and-feel" \
  "$PROFILE/airootfs/usr/share/icons" \
  "$LOLIOS_DESKTOPTHEME_DIR" \
  "$LOLIOS_SDDM_DIR"

select_host_lnf_source
if [ -n "$HOST_LNF_SOURCE" ]; then
  log "Importing host Plasma look-and-feel theme: $HOST_LNF_SOURCE"
  rm -rf "$LOLIOS_LNF_DIR"
  mkdir -p "$LOLIOS_LNF_DIR"
  cp -a "$HOST_LNF_SOURCE"/. "$LOLIOS_LNF_DIR"/
else
  warn "No host LoliOS look-and-feel theme found in $HOST_LNF_ROOT; creating minimal fallback theme"
  mkdir -p "$LOLIOS_LNF_DIR/contents"
fi

select_host_icon_source
if [ -n "$HOST_ICON_SOURCE" ]; then
  log "Importing host icon theme: $HOST_ICON_SOURCE"
  rm -rf "$LOLIOS_ICONS_DIR"
  mkdir -p "$LOLIOS_ICONS_DIR"
  cp -a "$HOST_ICON_SOURCE"/. "$LOLIOS_ICONS_DIR"/
else
  warn "No host LoliOS icon theme found; creating LoliOS icon alias to breeze-dark"
  mkdir -p "$LOLIOS_ICONS_DIR"
fi

cp "$WALL_SRC" "$WALL_TARGET"
cp "$WALL_SRC" "$WALL_DIR/contents/images/lolios-dark.png"
cp "$WALL_SRC" "$WALL_DIR/contents/images/1920x1080.png"
cp "$WALL_SRC" "$WALL_DIR/contents/images/2560x1440.png"
cp "$WALL_SRC" "$WALL_DIR/contents/images/3840x2160.png"

cat > "$WALL_DIR/metadata.json" <<'JSON'
{
  "KPlugin": {
    "Id": "LoliOS",
    "Name": "LoliOS Dark",
    "Description": "LoliOS dark wallpaper",
    "Version": "1.0"
  }
}
JSON

cat > "$PROFILE/airootfs/usr/share/color-schemes/LoliOSCandy.colors" <<'EOF_CANDY'
[General]
ColorScheme=LoliOSCandy
Name=LoliOS Candy
shadeSortColumn=true

[KDE]
contrast=7

[Colors:Window]
BackgroundNormal=12,12,20
ForegroundNormal=238,232,246
DecorationFocus=226,64,255
DecorationHover=255,72,196

[Colors:View]
BackgroundNormal=14,13,22
ForegroundNormal=238,232,246
DecorationFocus=226,64,255
DecorationHover=255,72,196

[Colors:Button]
BackgroundNormal=28,24,38
ForegroundNormal=238,232,246
DecorationFocus=226,64,255
DecorationHover=255,72,196

[Colors:Selection]
BackgroundNormal=206,64,255
ForegroundNormal=255,255,255

[Colors:Tooltip]
BackgroundNormal=18,17,26
ForegroundNormal=240,235,248

[WM]
activeBackground=20,16,30
activeForeground=255,255,255
inactiveBackground=14,13,22
inactiveForeground=168,154,184
EOF_CANDY

mkdir -p "$LOLIOS_LNF_DIR/contents"
cat > "$LOLIOS_LNF_DIR/metadata.json" <<'JSON'
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

cat > "$LOLIOS_LNF_DIR/contents/defaults" <<'EOF_DEFAULTS'
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

mkdir -p "$LOLIOS_LNF_DIR/contents/previews"
if ! find "$LOLIOS_LNF_DIR/contents/previews" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) 2>/dev/null | grep -q .; then
  cp "$WALL_SRC" "$LOLIOS_LNF_DIR/contents/previews/fullscreenpreview.png"
  cp "$WALL_SRC" "$LOLIOS_LNF_DIR/contents/previews/preview.png"
fi

cat > "$LOLIOS_DESKTOPTHEME_DIR/metadata.json" <<'JSON'
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

cat > "$LOLIOS_ICONS_DIR/index.theme" <<'EOF_ICONS'
[Icon Theme]
Name=LoliOS
Comment=LoliOS icon theme
Inherits=breeze-dark,breeze,hicolor
Directories=
EOF_ICONS

if [ -n "$HOST_ICON_SOURCE" ] && [ -f "$HOST_ICON_SOURCE/index.theme" ]; then
  awk '
    BEGIN { in_header=0 }
    /^\[Icon Theme\]$/ { print; print "Name=LoliOS"; print "Comment=LoliOS icon theme"; in_header=1; next }
    /^\[/ && $0 != "[Icon Theme]" { in_header=0; print; next }
    in_header && /^(Name|Comment)=/ { next }
    { print }
  ' "$HOST_ICON_SOURCE/index.theme" > "$LOLIOS_ICONS_DIR/index.theme.tmp" && \
    mv "$LOLIOS_ICONS_DIR/index.theme.tmp" "$LOLIOS_ICONS_DIR/index.theme"
fi

write_lolios_sddm_theme

cat > "$PROFILE/airootfs/etc/sddm.conf.d/10-lolios-theme.conf" <<'EOF_SDDM'
[Theme]
Current=lolios
CursorTheme=LoliOS
Font=Noto Sans,10,-1,5,50,0,0,0,0,0
EOF_SDDM

write_lolios_kde_user_config() {
  local dir="$1"
  mkdir -p "$dir/.config" "$dir/.local/share/color-schemes"
  cp "$PROFILE/airootfs/usr/share/color-schemes/LoliOSCandy.colors" "$dir/.local/share/color-schemes/LoliOSCandy.colors"

  cat > "$dir/.config/kdeglobals" <<'EOF_KDE'
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
EOF_KDE

  cat > "$dir/.config/plasmarc" <<'EOF_PLASMA'
[Theme]
name=LoliOS

[Wallpapers]
usersWallpapers=/usr/share/wallpapers/LoliOS/contents/lolios-dark.png
EOF_PLASMA

  cat > "$dir/.config/ksplashrc" <<'EOF_SPLASH'
[KSplash]
Theme=org.lolios.desktop
EOF_SPLASH

  cat > "$dir/.config/plasma-org.kde.plasma.desktop-appletsrc" <<EOF_WALL
[Containments][1][Wallpaper][org.kde.image][General]
Image=file://$WALL_ISO
FillMode=2
EOF_WALL
}

write_lolios_kde_user_config "$PROFILE/airootfs/etc/skel"
write_lolios_kde_user_config "$PROFILE/airootfs/root"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-apply-kde-theme" <<'EOF_THEME'
#!/usr/bin/env bash
set -u
[ "${EUID:-$(id -u)}" -eq 0 ] && exit 0
WALL="/usr/share/wallpapers/LoliOS/contents/lolios-dark.png"
LOG="$HOME/.cache/lolios-theme.log"
mkdir -p "$HOME/.cache" "$HOME/.config/lolios"
{
  command -v kwriteconfig6 >/dev/null 2>&1 && {
    kwriteconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage org.lolios.desktop || true
    kwriteconfig6 --file kdeglobals --group General --key ColorScheme LoliOSCandy || true
    kwriteconfig6 --file kdeglobals --group Icons --key Theme LoliOS || true
    kwriteconfig6 --file plasmarc --group Theme --key name LoliOS || true
  }
  command -v plasma-apply-lookandfeel >/dev/null 2>&1 && plasma-apply-lookandfeel -a org.lolios.desktop || true
  command -v plasma-apply-colorscheme >/dev/null 2>&1 && plasma-apply-colorscheme LoliOSCandy || true
  command -v plasma-apply-desktoptheme >/dev/null 2>&1 && plasma-apply-desktoptheme LoliOS || true
  command -v plasma-apply-wallpaperimage >/dev/null 2>&1 && [ -f "$WALL" ] && plasma-apply-wallpaperimage "$WALL" || true
  touch "$HOME/.config/lolios/theme-applied"
} >>"$LOG" 2>&1
EOF_THEME
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-apply-kde-theme"

cat > "$PROFILE/airootfs/etc/skel/.config/autostart/lolios-apply-kde-theme.desktop" <<'EOF_AUTOSTART'
[Desktop Entry]
Type=Application
Name=Apply LoliOS Dark Theme
Exec=/usr/local/bin/lolios-apply-kde-theme
OnlyShowIn=KDE;
X-KDE-autostart-after=panel
Terminal=false
EOF_AUTOSTART

add_pkg breeze
add_pkg breeze-icons
add_pkg plasma-workspace
add_pkg sddm
add_pkg konsole
add_pkg dolphin
add_pkg noto-fonts
add_pkg noto-fonts-emoji
add_pkg ttf-hack
