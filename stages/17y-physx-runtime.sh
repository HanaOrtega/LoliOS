# Sourced by ../build.sh; copy NVIDIA PhysX runtime from host when available

log "Installing optional NVIDIA PhysX runtime if available"

mkdir -p "$PROFILE/airootfs/opt/lolios/windows-runtimes"

PHYSX_SOURCE="${PHYSX_EXE:-}"

if [ -z "$PHYSX_SOURCE" ]; then
    for candidate in \
        "$HOME/Pobrane/PhysX.exe" \
        "$HOME/Pobrane/physx.exe" \
        "$HOME/Downloads/PhysX.exe" \
        "$HOME/Downloads/physx.exe" \
        "$HOME/Pobrane"/*PhysX*.exe \
        "$HOME/Pobrane"/*physx*.exe \
        "$HOME/Downloads"/*PhysX*.exe \
        "$HOME/Downloads"/*physx*.exe
    do
        if [ -f "$candidate" ]; then
            PHYSX_SOURCE="$candidate"
            break
        fi
    done
fi

if [ -n "$PHYSX_SOURCE" ] && [ -f "$PHYSX_SOURCE" ]; then
    install -Dm644 "$PHYSX_SOURCE" "$PROFILE/airootfs/opt/lolios/windows-runtimes/NVIDIA-PhysX.exe"
    log "Copied NVIDIA PhysX runtime from: $PHYSX_SOURCE"
else
    warn "Nie znaleziono PhysX.exe. Jeśli chcesz dodać PhysX do ISO, ustaw PHYSX_EXE=/ścieżka/do/PhysX.exe albo umieść plik w ~/Pobrane/PhysX.exe lub ~/Downloads/PhysX.exe."
fi
