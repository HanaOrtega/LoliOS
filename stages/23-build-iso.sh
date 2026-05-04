# Sourced by ../build.sh; original section: 23. Build ISO

# 23. Build ISO
# ------------------------------------------------------------

if [ "$ISO_STAGE" != "1" ]; then
    log "ISO_STAGE=0: profile prepared, ISO build skipped"
    echo "[LOLIOS] Profile ready: $PROFILE"
    exit 0
fi

log "Preparing final ISO build environment"

# Package list finalization happens in stages/07z-packages-finalize.sh. This
# stage must not add/remove packages; otherwise audit would validate a different
# package set than mkarchiso actually builds.
ensure_local_repo_config

if [ -x "$PROFILE/lolios-validate-packages" ]; then
    "$PROFILE/lolios-validate-packages" "$PROFILE" || die "Package validation failed before mkarchiso"
else
    warn "Package validator missing; continuing without preflight validation."
fi

kill_archiso_processes

# Defensive cleanup: if previous runs happened from a wrong cwd, stale
# work/out trees may have been created under customrepo.
sudo rm -rf "$PROFILE/customrepo/work" "$PROFILE/customrepo/out"
clean_build_dirs

case "$PROFILE" in
    */customrepo/*)
        die "PROFILE points inside customrepo, aborting: $PROFILE"
        ;;
esac

case "$OUTDIR" in
    */customrepo/*)
        die "OUTDIR points inside customrepo, aborting: $OUTDIR"
        ;;
esac

case "$PWD" in
    */customrepo|*/customrepo/*)
        die "Current directory is inside customrepo before mkarchiso: $PWD"
        ;;
esac

[ ! -d "$PROFILE/customrepo/work" ] || die "Bad stale workdir still exists: $PROFILE/customrepo/work"
[ ! -d "$PROFILE/customrepo/out" ] || die "Bad stale outdir still exists: $PROFILE/customrepo/out"

ABS_PROFILE="$(readlink -f "$PROFILE")"
ABS_OUTDIR="$(readlink -f "$OUTDIR")"
ABS_WORKDIR="$(readlink -f "$PROFILE/work")"
ABS_PROJECT_ROOT="$(readlink -f "$LOLIOS_PROJECT_ROOT")"

log "mkarchiso path sanity"
echo "ABS_PROJECT_ROOT=$ABS_PROJECT_ROOT"
echo "ABS_PROFILE=$ABS_PROFILE"
echo "ABS_WORKDIR=$ABS_WORKDIR"
echo "ABS_OUTDIR=$ABS_OUTDIR"
echo "PWD=$(pwd)"

log "Building ISO"

set +e
(
    cd "$ABS_PROJECT_ROOT"
    sudo mkarchiso -v -w "$ABS_WORKDIR" -o "$ABS_OUTDIR" "$ABS_PROFILE"
) 2>&1 | tee "$LOG_DIR/mkarchiso-$BUILD_ID.log"
MKARCHISO_STATUS="${PIPESTATUS[0]}"
set -e

log "Checking output"

ls -lh "$PROFILE/out" || die "ISO output directory not found"
ISO="$(ls -t "$PROFILE"/out/*.iso 2>/dev/null | head -1 || true)"

if [ -z "$ISO" ] || [ ! -f "$ISO" ]; then
    die "ISO not found after mkarchiso. mkarchiso status=$MKARCHISO_STATUS"
fi

if [ "$MKARCHISO_STATUS" -ne 0 ]; then
    warn "mkarchiso returned status $MKARCHISO_STATUS, but ISO artifact exists: $ISO"
    warn "Treating build as usable; inspect $LOG_DIR/mkarchiso-$BUILD_ID.log for cleanup warnings."
fi

log "Build complete"
qemu_smoke_test_iso "$ISO"

sha256sum "$ISO" > "$ISO.sha256"
if [ "$REPO_SIGN" = "1" ] && [ -n "$GPG_KEY_ID" ]; then
    gpg --batch --yes --local-user "$GPG_KEY_ID" --detach-sign --armor "$ISO" || true
fi

echo "[LOLIOS] ISO ready: $ISO"
echo "[LOLIOS] SHA256: $ISO.sha256"
echo "[LOLIOS] Build log: $MAIN_LOG"
echo "[LOLIOS] mkarchiso log: $LOG_DIR/mkarchiso-$BUILD_ID.log"
echo "[LOLIOS] Manifest: $MANIFEST_DIR/build-$BUILD_ID.env"
