# Sourced by ../build.sh; original section: 3. Fresh profile

# 3. Fresh profile
# ------------------------------------------------------------

log "Creating fresh ArchISO profile"

if [ "$USE_EXISTING_PROFILE" = "1" ]; then
    require_dir "$PROFILE"
    require_dir "$PROFILE/airootfs"
    warn "USE_EXISTING_PROFILE=1: preserving existing profile and manual airootfs changes: $PROFILE"
else
    if [ "$KEEP_WORK" != "1" ]; then
        kill_archiso_processes
        force_unmount_archiso
        # Do not delete the whole WORKROOT here: logging, lockfile, repo cache,
        # and manifests are already initialized under WORKROOT. Removing it after
        # acquiring the lock silently deletes the active lock/log and makes concurrent
        # or failed builds hard to diagnose. Refresh only the generated profile.
        sudo rm -rf "$PROFILE" "$AURBUILD"
    fi

    mkdir -p "$WORKROOT"
    cp -a /usr/share/archiso/configs/releng "$PROFILE"
fi

mkdir -p "$CUSTOMREPO" "$AURBUILD" "$REPO_DIR" "$LOG_DIR" "$CACHE_DIR" "$MANIFEST_DIR"

# ------------------------------------------------------------
