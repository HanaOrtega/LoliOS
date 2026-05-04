# Sourced by ../build.sh; advanced compatibility suite helpers

log "Writing LoliOS advanced EXE compatibility suite"

mkdir -p "$PROFILE/airootfs/usr/local/bin" "$PROFILE/airootfs/usr/share/lolios/compat"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-compat-doctor" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

echo "== LoliOS compatibility doctor =="

echo "-- core tools --"
for cmd in wine winetricks protontricks gamescope gamemoderun mangohud lolios-exe-launcher lolios-profile; do
    if command -v "$cmd" >/dev/null 2>&1; then
        printf 'OK  %s -> %s\n' "$cmd" "$(command -v "$cmd")"
    else
        printf 'BAD %s missing\n' "$cmd"
    fi
done

echo "-- 32-bit/runtime packages --"
for pkg in wine winetricks protontricks gamescope gamemode lib32-gamemode mangohud lib32-mangohud; do
    pacman -Q "$pkg" >/dev/null 2>&1 && echo "OK  package: $pkg" || echo "WARN package missing: $pkg"
done

echo "-- LoliOS profile dirs --"
for dir in "$HOME/.local/share/lolios/exe-launcher/apps" "$HOME/Games/LoliOS"; do
    [ -d "$dir" ] && echo "OK  dir: $dir" || echo "WARN missing dir: $dir"
done
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-compat-doctor"

cat > "$PROFILE/airootfs/usr/share/lolios/compat/advanced-suite.json" <<'EOF'
{
  "id": "lolios-advanced-compat-suite",
  "version": 1,
  "tools": [
    "lolios-exe-launcher",
    "lolios-profile",
    "lolios-compat-doctor"
  ],
  "purpose": "Diagnostics and compatibility helpers for Windows games and applications."
}
EOF

# ------------------------------------------------------------
