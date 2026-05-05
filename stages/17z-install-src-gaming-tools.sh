# Sourced by ../build.sh; install standalone LoliOS compatibility suite program

log "Installing standalone LoliOS Compatibility Suite"

PROGRAM_ROOT="${LOLIOS_PROJECT_ROOT:-$(pwd)}/programs/lolios-compat-suite"
INSTALLER="$PROGRAM_ROOT/install-to-airootfs.sh"

[ -x "$INSTALLER" ] || die "Missing or non-executable compatibility suite installer: $INSTALLER"

"$INSTALLER" "${LOLIOS_PROJECT_ROOT:-$(pwd)}" "$PROFILE/airootfs"

# Compatibility alias for older build/audit wording.
[ -x "$PROFILE/airootfs/usr/local/bin/lolios-verify-compat-suite" ] || die "LoliOS Compatibility Suite verifier missing"
[ -x "$PROFILE/airootfs/usr/local/bin/lolios-verify-src-gaming-tools" ] || die "Legacy verifier alias missing"

# ------------------------------------------------------------
