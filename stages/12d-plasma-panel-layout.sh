# Sourced by ../build.sh; default Plasma desktop and panel layout

# 12D. Plasma panel layout
# ------------------------------------------------------------

log "Writing default Plasma desktop and panel layout"

THEME_ROOT="$PROFILE/airootfs"
LOLIOS_LNF_DIR="$THEME_ROOT/usr/share/plasma/look-and-feel/org.lolios.desktop"

mkdir -p "$LOLIOS_LNF_DIR/contents/layouts"

# Global Theme layout script. Plasma can use this when applying org.lolios.desktop.
cat > "$LOLIOS_LNF_DIR/contents/layouts/org.kde.plasma.desktop-layout.js" <<'EOF_LAYOUT_JS'
var allDesktops = desktops();
for (var i = 0; i < allDesktops.length; i++) {
    var desktop = allDesktops[i];
    desktop.wallpaperPlugin = "org.kde.image";
    desktop.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    desktop.writeConfig("Image", "file:///usr/share/wallpapers/LoliOS/contents/lolios-dark.png");
    desktop.writeConfig("FillMode", "2");
}

var panel = new Panel;
panel.location = "bottom";
panel.height = gridUnit * 2;
panel.addWidget("org.kde.plasma.kickoff");
panel.addWidget("org.kde.plasma.icontasks");
panel.addWidget("org.kde.plasma.marginsseparator");
panel.addWidget("org.kde.plasma.systemtray");
panel.addWidget("org.kde.plasma.digitalclock");
panel.addWidget("org.kde.plasma.showdesktop");
EOF_LAYOUT_JS

write_plasma_panel_config() {
    local dir="$1"
    mkdir -p "$dir/.config"

    cat > "$dir/.config/plasma-org.kde.plasma.desktop-appletsrc" <<'EOF_PLASMA_LAYOUT'
[ActionPlugins][0]
RightButton;NoModifier=org.kde.contextmenu

[Containments][1]
activityId=
formfactor=0
immutability=1
lastScreen=0
location=0
plugin=org.kde.plasma.folder
wallpaperplugin=org.kde.image

[Containments][1][ConfigDialog]
DialogHeight=540
DialogWidth=720

[Containments][1][General]
ToolBoxButtonState=topcenter

[Containments][1][Wallpaper][org.kde.image][General]
FillMode=2
Image=file:///usr/share/wallpapers/LoliOS/contents/lolios-dark.png

[Containments][2]
activityId=
formfactor=2
immutability=1
lastScreen=0
location=4
plugin=org.kde.panel
wallpaperplugin=org.kde.image

[Containments][2][Applets][3]
immutability=1
plugin=org.kde.plasma.kickoff

[Containments][2][Applets][3][Configuration]
PreloadWeight=100

[Containments][2][Applets][4]
immutability=1
plugin=org.kde.plasma.icontasks

[Containments][2][Applets][4][Configuration]
PreloadWeight=100

[Containments][2][Applets][4][Configuration][General]
launchers=applications:org.kde.dolphin.desktop,applications:org.kde.konsole.desktop,applications:brave-browser.desktop

[Containments][2][Applets][5]
immutability=1
plugin=org.kde.plasma.marginsseparator

[Containments][2][Applets][6]
immutability=1
plugin=org.kde.plasma.systemtray

[Containments][2][Applets][6][Configuration]
PreloadWeight=100
SystrayContainmentId=7

[Containments][2][Applets][8]
immutability=1
plugin=org.kde.plasma.digitalclock

[Containments][2][Applets][8][Configuration]
PreloadWeight=100

[Containments][2][Applets][9]
immutability=1
plugin=org.kde.plasma.showdesktop

[Containments][2][ConfigDialog]
DialogHeight=540
DialogWidth=720

[Containments][2][General]
AppletOrder=3;4;5;6;8;9

[Containments][7]
activityId=
formfactor=2
immutability=1
lastScreen=0
location=4
plugin=org.kde.plasma.private.systemtray
wallpaperplugin=org.kde.image

[Containments][7][Applets][10]
immutability=1
plugin=org.kde.plasma.manage-inputmethod

[Containments][7][Applets][11]
immutability=1
plugin=org.kde.plasma.notifications

[Containments][7][Applets][12]
immutability=1
plugin=org.kde.plasma.devicenotifier

[Containments][7][Applets][13]
immutability=1
plugin=org.kde.plasma.networkmanagement

[Containments][7][Applets][14]
immutability=1
plugin=org.kde.plasma.volume

[Containments][7][General]
extraItems=org.kde.plasma.manage-inputmethod,org.kde.plasma.notifications,org.kde.plasma.devicenotifier,org.kde.plasma.networkmanagement,org.kde.plasma.volume
knownItems=org.kde.plasma.manage-inputmethod,org.kde.plasma.notifications,org.kde.plasma.devicenotifier,org.kde.plasma.networkmanagement,org.kde.plasma.volume

[ScreenMapping]
itemsOnDisabledScreens=
screenMapping=desktop:/org.kde.plasma.folder/1,0,panel:/org.kde.panel/2,0
EOF_PLASMA_LAYOUT
}

write_plasma_panel_config "$THEME_ROOT/etc/skel"
write_plasma_panel_config "$THEME_ROOT/root"

# Ensure existing live user home created by archiso also receives the panel layout
# when /etc/skel has already been copied before Plasma first starts.
mkdir -p "$THEME_ROOT/etc/xdg/autostart"
cat > "$THEME_ROOT/etc/xdg/autostart/lolios-ensure-plasma-panel.desktop" <<'EOF_AUTOSTART'
[Desktop Entry]
Type=Application
Name=Ensure LoliOS Plasma Panel
Exec=/usr/local/bin/lolios-ensure-plasma-panel
OnlyShowIn=KDE;
X-KDE-autostart-before=panel
Terminal=false
EOF_AUTOSTART

cat > "$THEME_ROOT/usr/local/bin/lolios-ensure-plasma-panel" <<'EOF_PANEL_SCRIPT'
#!/usr/bin/env bash
set -u

CONFIG="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
MARKER="$HOME/.config/lolios/panel-layout-applied"
mkdir -p "$HOME/.config/lolios"

if grep -q 'plugin=org.kde.panel' "$CONFIG" 2>/dev/null && grep -q 'org.kde.plasma.kickoff' "$CONFIG" 2>/dev/null; then
    touch "$MARKER"
    exit 0
fi

mkdir -p "$HOME/.config"
cat > "$CONFIG" <<'EOF_PLASMA_LAYOUT'
[Containments][1]
activityId=
formfactor=0
immutability=1
lastScreen=0
location=0
plugin=org.kde.plasma.folder
wallpaperplugin=org.kde.image

[Containments][1][Wallpaper][org.kde.image][General]
FillMode=2
Image=file:///usr/share/wallpapers/LoliOS/contents/lolios-dark.png

[Containments][2]
activityId=
formfactor=2
immutability=1
lastScreen=0
location=4
plugin=org.kde.panel
wallpaperplugin=org.kde.image

[Containments][2][Applets][3]
immutability=1
plugin=org.kde.plasma.kickoff

[Containments][2][Applets][4]
immutability=1
plugin=org.kde.plasma.icontasks

[Containments][2][Applets][5]
immutability=1
plugin=org.kde.plasma.marginsseparator

[Containments][2][Applets][6]
immutability=1
plugin=org.kde.plasma.systemtray

[Containments][2][Applets][6][Configuration]
SystrayContainmentId=7

[Containments][2][Applets][8]
immutability=1
plugin=org.kde.plasma.digitalclock

[Containments][2][Applets][9]
immutability=1
plugin=org.kde.plasma.showdesktop

[Containments][2][General]
AppletOrder=3;4;5;6;8;9

[Containments][7]
activityId=
formfactor=2
immutability=1
lastScreen=0
location=4
plugin=org.kde.plasma.private.systemtray
wallpaperplugin=org.kde.image

[ScreenMapping]
screenMapping=desktop:/org.kde.plasma.folder/1,0,panel:/org.kde.panel/2,0
EOF_PLASMA_LAYOUT

touch "$MARKER"
# Restart only if plasmashell is already running; otherwise it will read the file on first start.
if pgrep -x plasmashell >/dev/null 2>&1; then
    kquitapp6 plasmashell >/dev/null 2>&1 || true
    nohup plasmashell >/dev/null 2>&1 &
fi
EOF_PANEL_SCRIPT
chmod +x "$THEME_ROOT/usr/local/bin/lolios-ensure-plasma-panel"

# ------------------------------------------------------------
