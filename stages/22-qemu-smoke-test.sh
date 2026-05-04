# Sourced by ../build.sh; original section: 22. QEMU smoke test helper

# 22. QEMU smoke test helper
# ------------------------------------------------------------

qemu_smoke_test_iso() {
    local iso="$1"

    if [ "$QEMU_SMOKE_TEST" != "1" ] && [ "${QEMU_GUI_TEST:-0}" != "1" ]; then
        warn "QEMU_SMOKE_TEST=0 and QEMU_GUI_TEST=0: pomijam smoke test ISO."
        return 0
    fi

    if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
        warn "Brak qemu-system-x86_64 — pomijam smoke test."
        return 0
    fi

    log "Running QEMU smoke test"
    local disk="$WORKROOT/qemu-smoke.qcow2"
    rm -f "$disk"
    qemu-img create -f qcow2 "$disk" 32G >/dev/null

    local display_args=()
    if [ "${QEMU_GUI_TEST:-0}" = "1" ]; then
        # Graphical mode is useful for validating SDDM/Plasma/KDE theme issues.
        display_args=(-display gtk)
    else
        display_args=(-display none -serial stdio)
    fi

    timeout "$QEMU_TIMEOUT" qemu-system-x86_64 \
        -enable-kvm \
        -m "$QEMU_MEMORY" \
        -smp "$QEMU_CPUS" \
        -cpu host \
        -drive file="$disk",format=qcow2,if=virtio \
        -cdrom "$iso" \
        -boot d \
        "${display_args[@]}" \
        -no-reboot || true

    rm -f "$disk"
    log "QEMU smoke test finished"
}

# ------------------------------------------------------------
