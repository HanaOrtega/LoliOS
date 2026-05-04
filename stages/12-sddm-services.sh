# Sourced by ../build.sh; original section: 12. SDDM / services

# 12. SDDM / services
# ------------------------------------------------------------

log "Writing SDDM autologin, theme and service links"

mkdir -p "$PROFILE/airootfs/etc/systemd/system"
mkdir -p "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants"
mkdir -p "$PROFILE/airootfs/etc/systemd/system/sockets.target.wants"
mkdir -p "$PROFILE/airootfs/etc/sddm.conf.d"
mkdir -p "$PROFILE/airootfs/etc/pam.d"
mkdir -p "$PROFILE/airootfs/usr/share/sddm/themes/lolios"

cat > "$PROFILE/airootfs/etc/sddm.conf" <<'EOF'
[General]
DisplayServer=x11

[Theme]
Current=lolios
CursorTheme=LoliOS
Font=Noto Sans,10,-1,5,50,0,0,0,0,0

[Users]
MinimumUid=1000
MaximumUid=60513

[Autologin]
Session=plasma.desktop
User=
Relogin=false
EOF

cat > "$PROFILE/airootfs/etc/sddm.conf.d/10-lolios-theme.conf" <<'EOF'
[General]
DisplayServer=x11

[Theme]
Current=lolios
CursorTheme=LoliOS
Font=Noto Sans,10,-1,5,50,0,0,0,0,0

[Users]
MinimumUid=1000
MaximumUid=60513
EOF

rm -f "$PROFILE/airootfs/etc/sddm.conf.d/00-lolios-live-autologin.conf"
cat > "$PROFILE/airootfs/etc/sddm.conf.d/90-lolios-live-autologin.conf" <<'EOF'
[Autologin]
User=live
Session=plasma.desktop
Relogin=false
EOF

# Live ISO PAM policy: live belongs to autologin/nopasswdlogin and must not need a
# password. Installed systems remove the live/autologin SDDM fragments in postinstall.
cat > "$PROFILE/airootfs/etc/pam.d/sddm-autologin" <<'EOF'
#%PAM-1.0
auth      required  pam_succeed_if.so user ingroup autologin
auth      optional  pam_permit.so
account   include   system-local-login
password  include   system-local-login
session   include   system-local-login
EOF

cat > "$PROFILE/airootfs/etc/pam.d/sddm" <<'EOF'
#%PAM-1.0
auth      sufficient pam_succeed_if.so user = live
auth      sufficient pam_succeed_if.so user ingroup nopasswdlogin
auth      include    system-local-login
account   include    system-local-login
password  include    system-local-login
session   include    system-local-login
EOF

cat > "$PROFILE/airootfs/usr/share/sddm/themes/lolios/metadata.desktop" <<'EOF'
[SddmGreeterTheme]
Name=LoliOS Dark
Description=LoliOS dark SDDM theme
Type=sddm-theme
Version=1.0
MainScript=Main.qml
ConfigFile=theme.conf
Theme-Id=lolios
Theme-API=2.0
EOF
cat > "$PROFILE/airootfs/usr/share/sddm/themes/lolios/theme.conf" <<'EOF'
[General]
background=/usr/share/wallpapers/LoliOS/contents/lolios-dark.png
EOF
cat > "$PROFILE/airootfs/usr/share/sddm/themes/lolios/Main.qml" <<'EOF'
import QtQuick 2.15
import SddmComponents 2.0

Rectangle {
    id: root
    color: "#090912"

    property string loginUser: "live"
    property int loginSession: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0

    function doLogin() {
        sddm.login(loginUser, "", loginSession)
    }

    Image {
        anchors.fill: parent
        source: "/usr/share/wallpapers/LoliOS/contents/lolios-dark.png"
        fillMode: Image.PreserveAspectCrop
    }

    Rectangle { anchors.fill: parent; color: "#aa090912" }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onDoubleClicked: root.doLogin()
    }

    Column {
        id: loginBox
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
            text: "live"
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
            border.width: 1
            Text {
                anchors.centerIn: parent
                text: "No password required"
                color: "#c9b8da"
                font.pixelSize: 14
            }
        }

        Rectangle {
            id: loginButton
            width: parent.width
            height: 46
            radius: 8
            color: buttonMouse.pressed ? "#8b1ed1" : "#b52cff"
            Text {
                anchors.centerIn: parent
                text: "Start Live Session"
                color: "white"
                font.pixelSize: 16
                font.bold: true
            }
            MouseArea {
                id: buttonMouse
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                onClicked: root.doLogin()
            }
        }

        Text {
            text: "Autologin should start automatically; click if it does not."
            color: "#c9b8da"
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            width: parent.width
        }
    }

    Timer {
        interval: 1200
        running: true
        repeat: false
        onTriggered: root.doLogin()
    }
}
EOF

mkdir -p "$PROFILE/airootfs/usr/share/xsessions"
cat > "$PROFILE/airootfs/usr/share/xsessions/plasma.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Exec=startplasma-x11
TryExec=startplasma-x11
DesktopNames=KDE
Name=Plasma (X11)
Comment=Plasma by KDE
X-KDE-PluginInfo-Version=6.0
EOF

rm -f \
    "$PROFILE/airootfs/etc/systemd/system/lxdm.service" \
    "$PROFILE/airootfs/etc/systemd/system/display-manager.service"
ln -sf /usr/lib/systemd/system/sddm.service \
    "$PROFILE/airootfs/etc/systemd/system/display-manager.service"
for unit in lxdm.service lightdm.service gdm.service; do
    ln -sf /dev/null "$PROFILE/airootfs/etc/systemd/system/$unit"
done

for unit in \
    systemd-networkd.service \
    systemd-networkd.socket \
    systemd-networkd-persistent-storage.service \
    systemd-resolved.service \
    systemd-timesyncd.service \
    pcscd.socket
 do
    ln -sf /dev/null "$PROFILE/airootfs/etc/systemd/system/$unit"
    rm -f "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants/$unit" \
          "$PROFILE/airootfs/etc/systemd/system/sockets.target.wants/$unit"
done

for svc in \
    NetworkManager.service \
    bluetooth.service \
    cups.service \
    ufw.service \
    libvirtd.service
 do
    safe_ln_service "$svc" "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants"
done

if [ -e "$PROFILE/airootfs/usr/lib/systemd/system/avahi-daemon.service" ]; then
    safe_ln_service "avahi-daemon.service" "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants"
fi

# ------------------------------------------------------------
