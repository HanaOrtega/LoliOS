# Sourced by ../build.sh; final permission hardening for LoliOS tools

log "Hardening LoliOS tool executable permissions"

mkdir -p "$PROFILE/airootfs/usr/local/bin"

LOLIOS_EXEC_TOOLS=(
  lolios-exe-launcher
  lolios-profile
  lolios-gaming-center
  lolios-app-center
  lolios-guard-status
  lolios-verify-src-gaming-tools
  lolios-compat-doctor
  lolios-compat-manager
  lolios-check-game-center-offline
  lolios-installer
  lolios-exe-runner
  lolios-gaming-doctor
  lolios-gpu-profile
  lolios-update
  lolios-repair-installed-system
  lolios-set-wallpaper
  lolios-apply-kde-theme
  lolios-start-center
  lolios-live-doctor
  lolios-installed-doctor
  lolios-first-login-setup
  lolios-session-mode
  lolios-fix-pacman-conf-sections
  lolios-calamares-diagnose
)

# Live ISO hardening: make tools executable in airootfs before mkarchiso packs them.
for tool in "${LOLIOS_EXEC_TOOLS[@]}"; do
    file="$PROFILE/airootfs/usr/local/bin/$tool"
    [ -e "$file" ] || continue
    chmod 0755 "$file"
    [ -x "$file" ] || die "LoliOS tool is not executable after chmod: $file"
done

cat > "$PROFILE/airootfs/usr/local/bin/lolios-repair-tool-permissions" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "Run as root: sudo lolios-repair-tool-permissions" >&2
    exit 1
fi

TOOLS=(
  lolios-exe-launcher
  lolios-profile
  lolios-gaming-center
  lolios-app-center
  lolios-guard-status
  lolios-verify-src-gaming-tools
  lolios-compat-doctor
  lolios-compat-manager
  lolios-check-game-center-offline
  lolios-installer
  lolios-exe-runner
  lolios-gaming-doctor
  lolios-gpu-profile
  lolios-update
  lolios-repair-installed-system
  lolios-set-wallpaper
  lolios-apply-kde-theme
  lolios-start-center
  lolios-live-doctor
  lolios-installed-doctor
  lolios-first-login-setup
  lolios-session-mode
  lolios-fix-pacman-conf-sections
  lolios-calamares-diagnose
)

for tool in "${TOOLS[@]}"; do
    file="/usr/local/bin/$tool"
    [ -e "$file" ] || continue
    chmod 0755 "$file"
    [ -x "$file" ] || { echo "BAD not executable after chmod: $file" >&2; exit 1; }
    echo "OK chmod 0755 $file"
done

echo "LoliOS tool permission repair complete."
EOF
chmod 0755 "$PROFILE/airootfs/usr/local/bin/lolios-repair-tool-permissions"

# Installed-system hardening: Calamares unpackfs should preserve executable bits,
# but postinstall runs this again so installed systems cannot keep stale 0644 tools.
POSTINSTALL="$PROFILE/airootfs/root/postinstall.sh"
if [ -f "$POSTINSTALL" ] && ! grep -q 'lolios-repair-tool-permissions' "$POSTINSTALL"; then
    python3 - "$POSTINSTALL" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text()
call = 'command -v lolios-repair-tool-permissions >/dev/null 2>&1 && lolios-repair-tool-permissions || true\n'
marker = 'configure_offline_local_repo\n'
if marker in text:
    text = text.replace(marker, marker + call, 1)
else:
    text = text.replace('echo "[LOLIOS] postinstall started"\n', 'echo "[LOLIOS] postinstall started"\n' + call, 1)
path.write_text(text)
PY
fi

# Harden desktop launchers to stay regular readable .desktop files.
for desktop in \
    "$PROFILE/airootfs/usr/share/applications/lolios-app-center.desktop" \
    "$PROFILE/airootfs/usr/share/applications/lolios-game-center.desktop" \
    "$PROFILE/airootfs/usr/share/applications/lolios-check-game-center-offline.desktop"; do
    [ -e "$desktop" ] || continue
    chmod 0644 "$desktop"
done

# Re-check the user-visible tools that caused KDE launch failures.
for critical in lolios-app-center lolios-gaming-center lolios-exe-launcher lolios-profile lolios-guard-status; do
    file="$PROFILE/airootfs/usr/local/bin/$critical"
    [ -e "$file" ] || die "Critical LoliOS tool missing: $file"
    [ -x "$file" ] || die "Critical LoliOS tool is not executable: $file"
done

# ------------------------------------------------------------
