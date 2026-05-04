# Sourced by ../build.sh; offline diagnostics for systems without internet

log "Writing LoliOS offline diagnostics"

mkdir -p "$PROFILE/airootfs/usr/local/bin" "$PROFILE/airootfs/usr/share/applications"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-check-game-center-offline" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

echo "[LOLIOS] Game Center offline check"
echo

echo "== binaries =="
for bin in lolios-gaming-center lolios-app-center lolios-exe-launcher lolios-profile lolios-guard-status; do
    if command -v "$bin" >/dev/null 2>&1; then
        path="$(command -v "$bin")"
        printf 'OK %-28s %s\n' "$bin" "$path"
        ls -l "$path" || true
    else
        printf 'BAD missing %s\n' "$bin"
    fi
done

echo
echo "== LoliOS guard =="
if command -v lolios-guard-status >/dev/null 2>&1; then
    lolios-guard-status || true
else
    echo "BAD: lolios-guard-status missing"
fi

echo
echo "== tkinter / libtk =="
if python3 - <<'PY'
import tkinter
print("tkinter OK")
PY
then
    echo "OK: Game Center GUI dependency is available."
else
    echo "BAD: tkinter/libtk missing. Game Center will fall back to CLI."
    echo "Offline fix is possible only if package files for tcl/tk exist locally."
fi

echo
echo "== offline package files =="
for pkg in tcl tk; do
    found=""
    for dir in /opt/lolios/repo /run/archiso/bootmnt/lolios/repo /run/archiso/bootmnt/repo /var/cache/pacman/pkg; do
        [ -d "$dir" ] || continue
        item="$(find "$dir" -maxdepth 1 -type f \( -name "${pkg}-*.pkg.tar.zst" -o -name "${pkg}-*.pkg.tar.xz" \) 2>/dev/null | sort -V | tail -n1 || true)"
        if [ -n "$item" ]; then
            found="$item"
            break
        fi
    done
    if [ -n "$found" ]; then
        echo "FOUND $pkg: $found"
    else
        echo "MISSING $pkg package file"
    fi
done

echo
echo "== profiles =="
lolios-exe-launcher --list-json --category game 2>/dev/null || true

echo
echo "If tcl/tk package files are missing and there is no internet, use a newer LoliOS ISO with tk built in."
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-check-game-center-offline"

cat > "$PROFILE/airootfs/usr/share/applications/lolios-check-game-center-offline.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=LoliOS Check Game Center Offline
Comment=Diagnose Game Center without internet
Exec=konsole -e /usr/local/bin/lolios-check-game-center-offline
Icon=applications-games
Categories=System;Game;
Terminal=false
StartupNotify=true
EOF

# ------------------------------------------------------------
