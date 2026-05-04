# Sourced by ../build.sh; fix SDDM autologin semantics for Live and installed systems

log "Fixing SDDM autologin and greeter semantics"

mkdir -p "$PROFILE/airootfs/etc/sddm.conf.d" "$PROFILE/airootfs/usr/share/sddm/themes/lolios"

# Live ISO must autologin to live. Installed systems remove this file in postinstall
# and replace it with an autologin config for the Calamares-created user.
cat > "$PROFILE/airootfs/etc/sddm.conf.d/90-lolios-live-autologin.conf" <<'EOF'
[Autologin]
User=live
Session=plasma.desktop
Relogin=false
EOF

# Make /etc/sddm.conf agree with the Live fragment. This prevents a fallback
# login screen being shown because the main file has an empty autologin user.
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
User=live
Relogin=false
EOF

# The greeter must never hardcode or display "live". If it ever appears, it is
# only a fallback screen and should say that autologin is starting.
cat > "$PROFILE/airootfs/usr/share/sddm/themes/lolios/Main.qml" <<'EOF'
import QtQuick 2.15
import SddmComponents 2.0

Rectangle {
    id: root
    color: "#090912"

    property int loginSession: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property string selectedUser: userModel.lastIndex >= 0 ? userModel.data(userModel.index(0, 0), Qt.DisplayRole) : ""

    function doLogin() {
        if (selectedUser.length > 0) {
            sddm.login(selectedUser, "", loginSession)
        }
    }

    Image {
        anchors.fill: parent
        source: "/usr/share/wallpapers/LoliOS/contents/lolios-dark.png"
        fillMode: Image.PreserveAspectCrop
    }

    Rectangle { anchors.fill: parent; color: "#aa090912" }

    Column {
        anchors.centerIn: parent
        spacing: 14
        width: 420

        Text {
            text: "LoliOS"
            color: "#f5e9ff"
            font.pixelSize: 44
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
        }

        Text {
            text: "Starting session…"
            color: "#dfc9ff"
            font.pixelSize: 18
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
        }

        Rectangle {
            width: parent.width
            height: 46
            radius: 8
            color: buttonMouse.pressed ? "#8b1ed1" : "#b52cff"
            Text {
                anchors.centerIn: parent
                text: "Start Session"
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
            text: "Autologin is enabled. This fallback screen should disappear automatically."
            color: "#c9b8da"
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            width: parent.width
        }
    }

    Timer {
        interval: 700
        running: true
        repeat: false
        onTriggered: root.doLogin()
    }
}
EOF
