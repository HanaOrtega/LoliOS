#!/usr/bin/env bash
set -Eeuo pipefail

if [ "$#" -lt 2 ]; then
    echo "usage: $0 <repo-root> <airootfs>" >&2
    exit 2
fi

REPO_ROOT="$(cd -- "$1" && pwd)"
AIROOTFS="$2"
SRC_ROOT="$REPO_ROOT/src"

install_tool() {
    local tool="$1"
    local src="$SRC_ROOT/bin/$tool"
    local dst="$AIROOTFS/usr/local/bin/$tool"
    [ -f "$src" ] || { echo "missing source tool: $src" >&2; exit 1; }
    install -Dm755 "$src" "$dst"
}

mkdir -p \
    "$AIROOTFS/usr/local/bin" \
    "$AIROOTFS/usr/share/applications" \
    "$AIROOTFS/usr/lib/lolios" \
    "$AIROOTFS/usr/share/lolios" \
    "$AIROOTFS/usr/share/doc/lolios-compat-suite"

for tool in \
    lolios-exe-launcher \
    lolios-profile \
    lolios-gaming-center \
    lolios-app-center
 do
    install_tool "$tool"
done

[ -f "$SRC_ROOT/lib/lolios_guard.py" ] || { echo "missing LoliOS guard: $SRC_ROOT/lib/lolios_guard.py" >&2; exit 1; }
install -Dm644 "$SRC_ROOT/lib/lolios_guard.py" "$AIROOTFS/usr/lib/lolios/lolios_guard.py"

cat > "$AIROOTFS/usr/share/lolios/product.json" <<EOF
{
  "id": "lolios",
  "name": "LoliOS",
  "version": "${PRODUCT_VERSION:-rolling}",
  "exclusive_tools": [
    "lolios-gaming-center",
    "lolios-app-center",
    "lolios-exe-launcher",
    "lolios-profile"
  ]
}
EOF

cat > "$AIROOTFS/usr/local/bin/lolios-guard-status" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
PYTHONPATH=/usr/lib/lolios python3 /usr/lib/lolios/lolios_guard.py
EOF
chmod 0755 "$AIROOTFS/usr/local/bin/lolios-guard-status"

cat > "$AIROOTFS/usr/share/applications/lolios-app-center.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=LoliOS App Center
Comment=Manage Windows applications, installers and portable EXE profiles
Exec=/usr/local/bin/lolios-app-center
Icon=applications-office
Categories=LoliOS;Utility;System;
Terminal=false
StartupNotify=true
EOF
chmod 0644 "$AIROOTFS/usr/share/applications/lolios-app-center.desktop"

cat > "$AIROOTFS/usr/share/applications/lolios-game-center.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=LoliOS Game Center
Comment=Manage Windows game profiles and compatibility settings
Exec=/usr/local/bin/lolios-gaming-center
Icon=applications-games
Categories=LoliOS;Game;Utility;
Terminal=false
StartupNotify=true
EOF
chmod 0644 "$AIROOTFS/usr/share/applications/lolios-game-center.desktop"

cat > "$AIROOTFS/usr/local/bin/lolios-verify-compat-suite" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
fail=0
for tool in lolios-exe-launcher lolios-profile lolios-gaming-center lolios-app-center lolios-guard-status; do
  command -v "$tool" >/dev/null 2>&1 && echo "OK $tool" || { echo "BAD missing $tool"; fail=1; }
done
[ -f /usr/lib/lolios/lolios_guard.py ] && echo "OK lolios_guard" || { echo "BAD missing lolios_guard"; fail=1; }
[ -f /usr/share/lolios/product.json ] && echo "OK product marker" || { echo "BAD missing product marker"; fail=1; }
python3 -m py_compile /usr/local/bin/lolios-exe-launcher /usr/local/bin/lolios-profile /usr/local/bin/lolios-gaming-center /usr/local/bin/lolios-app-center /usr/lib/lolios/lolios_guard.py || fail=1
lolios-exe-launcher --help >/dev/null || fail=1
lolios-profile --help >/dev/null || fail=1
lolios-guard-status >/dev/null || fail=1
lolios-gaming-center --json >/dev/null || fail=1
lolios-app-center --json >/dev/null || fail=1
exit "$fail"
EOF
chmod 0755 "$AIROOTFS/usr/local/bin/lolios-verify-compat-suite"

cat > "$AIROOTFS/usr/local/bin/lolios-verify-src-gaming-tools" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
exec lolios-verify-compat-suite "$@"
EOF
chmod 0755 "$AIROOTFS/usr/local/bin/lolios-verify-src-gaming-tools"

cat > "$AIROOTFS/usr/share/doc/lolios-compat-suite/README" <<'EOF'
LoliOS Compatibility Suite

Standalone LoliOS program providing Game Center, App Center, EXE Launcher and profile management.
EOF

# Final local sanity for files installed into image root.
for critical in \
    lolios-exe-launcher \
    lolios-profile \
    lolios-gaming-center \
    lolios-app-center \
    lolios-guard-status \
    lolios-verify-compat-suite \
    lolios-verify-src-gaming-tools
 do
    file="$AIROOTFS/usr/local/bin/$critical"
    [ -x "$file" ] || { echo "not executable: $file" >&2; exit 1; }
done
