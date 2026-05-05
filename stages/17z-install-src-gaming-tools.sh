# Sourced by ../build.sh; install standalone LoliOS compatibility suite program

log "Installing standalone LoliOS Compatibility Suite"

PROGRAM_ROOT="${LOLIOS_PROJECT_ROOT:-$(pwd)}/programs/lolios-compat-suite"
INSTALLER="$PROGRAM_ROOT/install-to-airootfs.sh"

[ -f "$INSTALLER" ] || die "Missing compatibility suite installer: $INSTALLER"

bash "$INSTALLER" "${LOLIOS_PROJECT_ROOT:-$(pwd)}" "$PROFILE/airootfs"

# Compatibility alias for older build/audit wording.
[ -x "$PROFILE/airootfs/usr/local/bin/lolios-verify-compat-suite" ] || die "LoliOS Compatibility Suite verifier missing"
[ -x "$PROFILE/airootfs/usr/local/bin/lolios-verify-src-gaming-tools" ] || die "Legacy verifier alias missing"

# ------------------------------------------------------------
