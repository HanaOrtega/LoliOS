# Sourced by ../build.sh; install source-managed game/app tools after generated helper stages

log "Installing source-managed LoliOS game and app tools"

SRC_ROOT="${LOLIOS_PROJECT_ROOT:-$(pwd)}/src"

mkdir -p "$PROFILE/airootfs/usr/local/bin" "$PROFILE/airootfs/usr/share/applications" "$PROFILE/airootfs/usr/lib/lolios" "$PROFILE/airootfs/usr/share/lolios"

for tool in lolios-exe-launcher lolios-profile lolios-gaming-center lolios-app-center; do
    src="$SRC_ROOT/bin/$tool"
    dst="$PROFILE/airootfs/usr/local/bin/$tool"
    if [ ! -f "$src" ]; then
        die "Missing source-managed tool: $src"
    fi
    install -Dm755 "$src" "$dst"
done

if [ ! -f "$SRC_ROOT/lib/lolios_guard.py" ]; then
    die "Missing LoliOS guard library: $SRC_ROOT/lib/lolios_guard.py"
fi
install -Dm644 "$SRC_ROOT/lib/lolios_guard.py" "$PROFILE/airootfs/usr/lib/lolios/lolios_guard.py"
cat > "$PROFILE/airootfs/usr/share/lolios/product.json" <<EOF
{
  "id": "lolios",
  "name": "LoliOS",
  "version": "${PRODUCT_VERSION:-rolling}",
  "exclusive_tools": ["lolios-gaming-center", "lolios-app-center"]
}
EOF

cat > "$PROFILE/airootfs/usr/local/bin/lolios-guard-status" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
PYTHONPATH=/usr/lib/lolios python3 /usr/lib/lolios/lolios_guard.py
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-guard-status"

cat > "$PROFILE/airootfs/usr/share/applications/lolios-app-center.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=LoliOS App Center
Comment=Manage Windows applications, installers and portable EXE profiles
Exec=/usr/local/bin/lolios-app-center
Icon=applications-office
Categories=Utility;System;
Terminal=false
StartupNotify=true
EOF

cat > "$PROFILE/airootfs/usr/share/applications/lolios-game-center.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=LoliOS Game Center
Comment=Manage Windows game profiles and compatibility settings
Exec=/usr/local/bin/lolios-gaming-center
Icon=applications-games
Categories=Game;Utility;
Terminal=false
StartupNotify=true
EOF

cat > "$PROFILE/airootfs/usr/local/bin/lolios-verify-src-gaming-tools" <<'EOF'
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
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-verify-src-gaming-tools"
