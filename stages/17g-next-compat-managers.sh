# Sourced by ../build.sh; next compatibility managers

log "Writing LoliOS next compatibility managers"

mkdir -p "$PROFILE/airootfs/usr/local/bin" "$PROFILE/airootfs/usr/share/lolios/compat"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-compat-manager" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

cmd="${1:-status}"
shift || true

apps_dir="${LOLIOS_APPS_DIR:-$HOME/.local/share/lolios/exe-launcher/apps}"

case "$cmd" in
    status)
        echo "== LoliOS compatibility manager =="
        echo "apps_dir=$apps_dir"
        echo
        echo "-- launchers --"
        for tool in lolios-exe-launcher lolios-profile lolios-compat-doctor lolios-gaming-center lolios-app-center; do
            if command -v "$tool" >/dev/null 2>&1; then
                echo "OK  $tool -> $(command -v "$tool")"
            else
                echo "BAD $tool missing"
            fi
        done
        echo
        echo "-- profile count --"
        if [ -d "$apps_dir" ]; then
            find "$apps_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l
        else
            echo 0
        fi
        ;;
    list)
        if command -v lolios-exe-launcher >/dev/null 2>&1; then
            lolios-exe-launcher --list-json "$@"
        else
            echo "lolios-exe-launcher missing" >&2
            exit 1
        fi
        ;;
    doctor)
        if command -v lolios-compat-doctor >/dev/null 2>&1; then
            lolios-compat-doctor "$@"
        else
            echo "lolios-compat-doctor missing" >&2
            exit 1
        fi
        ;;
    *)
        cat <<USAGE
Usage: lolios-compat-manager [status|list|doctor]

Commands:
  status   Show compatibility subsystem status
  list     Forward to lolios-exe-launcher --list-json
  doctor   Run lolios-compat-doctor
USAGE
        exit 2
        ;;
esac
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-compat-manager"

cat > "$PROFILE/airootfs/usr/share/lolios/compat/next-managers.json" <<'EOF'
{
  "id": "lolios-next-compat-managers",
  "version": 1,
  "tools": [
    "lolios-compat-manager",
    "lolios-compat-doctor",
    "lolios-exe-launcher",
    "lolios-profile"
  ],
  "purpose": "Unified status and management entrypoint for LoliOS compatibility profiles."
}
EOF

# ------------------------------------------------------------
