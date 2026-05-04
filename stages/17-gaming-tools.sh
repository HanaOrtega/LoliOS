# Sourced by ../build.sh; original section: 17. EXE runner / Gaming Center / update / GPU profiles / repair tools

# 17. EXE runner / Gaming Center / update / GPU profiles / repair tools
# ------------------------------------------------------------

log "Writing compatibility tooling"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-detect-exe-runtime" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

EXE="${1:-}"
LOG_FILE="${2:-}"

if [ -z "$EXE" ] || [ ! -f "$EXE" ]; then
    echo "Usage: lolios-detect-exe-runtime /path/to/file.exe [wine-log]" >&2
    exit 2
fi

lower() { tr '[:upper:]' '[:lower:]'; }

MODE_GUESS="run"
ARCH_GUESS="win64"
CONFIDENCE="low"

BASE="$(basename "$EXE" | lower)"
DIR="$(dirname "$EXE")"

case "$BASE" in
    *setup*.exe|*install*.exe|*installer*.exe) MODE_GUESS="install" ;;
    *patch*.exe|*update*.exe|*hotfix*.exe|*mod*.exe) MODE_GUESS="patch" ;;
    *redist*.exe|*vcredist*.exe|*vc_redist*.exe|*dxsetup*.exe|*physx*.exe|*runtime*.exe|*ue4prereq*.exe) MODE_GUESS="runtime" ;;
    *) MODE_GUESS="run" ;;
esac

FILE_OUT="$(file "$EXE" 2>/dev/null || true)"
if echo "$FILE_OUT" | grep -qi 'PE32+'; then
    ARCH_GUESS="win64"
elif echo "$FILE_OUT" | grep -qi 'PE32'; then
    ARCH_GUESS="win32-compatible"
fi

IMPORT_TEXT=""
if command -v winedump >/dev/null 2>&1; then
    IMPORT_TEXT="$(winedump -j import "$EXE" 2>/dev/null || true)"
elif command -v objdump >/dev/null 2>&1; then
    IMPORT_TEXT="$(objdump -p "$EXE" 2>/dev/null || true)"
elif command -v llvm-objdump >/dev/null 2>&1; then
    IMPORT_TEXT="$(llvm-objdump -p "$EXE" 2>/dev/null || true)"
fi

DLL_TEXT="$(printf '%s
' "$IMPORT_TEXT" | grep -Eio '[A-Za-z0-9_.-]+\.dll' | lower | sort -u || true)"

if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then
    LOG_DLLS="$(grep -Eio 'Library [A-Za-z0-9_.-]+\.dll not found|[A-Za-z0-9_.-]+\.dll' "$LOG_FILE" 2>/dev/null | grep -Eio '[A-Za-z0-9_.-]+\.dll' | lower | sort -u || true)"
    DLL_TEXT="$(printf '%s
%s
' "$DLL_TEXT" "$LOG_DLLS" | sort -u)"
fi

FOLDER_HINTS=""
if [ -d "$DIR" ]; then
    FOLDER_HINTS="$(find "$DIR" -maxdepth 4 \( \
        -iname '*redist*' -o \
        -iname '*vcredist*' -o \
        -iname '*vc_redist*' -o \
        -iname '*dxsetup*' -o \
        -iname '*directx*' -o \
        -iname '*physx*' -o \
        -iname '*ue4prereq*' -o \
        -iname '*dotnet*' -o \
        -iname '*xnafx*' \
    \) 2>/dev/null | head -100 | lower || true)"
fi

RECOMMENDED_WINETRICKS=()
RECOMMENDED_CUSTOM=()
DETECTED_HINTS=()

has_dll() { printf '%s
' "$DLL_TEXT" | grep -qiE "^$1$"; }
has_dll_like() { printf '%s
' "$DLL_TEXT" | grep -qiE "$1"; }
has_hint_like() { printf '%s
' "$FOLDER_HINTS" | grep -qiE "$1"; }
add_trick() { RECOMMENDED_WINETRICKS+=("$1"); }
add_custom() { RECOMMENDED_CUSTOM+=("$1"); }
add_hint() { DETECTED_HINTS+=("$1"); }

has_dll_like '^d3dx9_[0-9]+\.dll$' && add_trick d3dx9
has_dll d3dcompiler_43.dll && add_trick d3dcompiler_43
has_dll d3dcompiler_47.dll && add_trick d3dcompiler_47
has_dll xinput1_3.dll && add_trick xinput
has_dll_like '^xaudio2_[0-9]+\.dll$' && add_trick xact
has_dll_like '^xapofx[0-9_]+\.dll$' && add_trick xact
has_dll x3daudio1_7.dll && add_trick xact

if has_dll msvcr100.dll || has_dll msvcp100.dll; then add_trick vcrun2010; fi
if has_dll msvcr110.dll || has_dll msvcp110.dll; then add_trick vcrun2012; fi
if has_dll msvcr120.dll || has_dll msvcp120.dll; then add_trick vcrun2013; fi
if has_dll vcruntime140.dll || has_dll vcruntime140_1.dll || has_dll msvcp140.dll || has_dll concrt140.dll || has_dll ucrtbase.dll; then add_trick vcrun2019; fi
if has_dll mscoree.dll || has_dll_like '^system\..*\.dll$' || has_hint_like 'dotnet|dotnetfx|netfx'; then add_trick dotnet48; fi
if has_dll physxloader.dll || has_dll physxcooking.dll || has_dll physxcore.dll || has_dll nxcharacter.dll || has_hint_like 'physx'; then add_custom physx; fi
has_dll openal32.dll && add_trick openal
has_hint_like 'xnafx|xna' && add_trick xna40
has_hint_like 'vcredist|vc_redist' && add_hint vcredist-folder
has_hint_like 'dxsetup|directx' && add_hint directx-redist-folder
has_hint_like 'ue4prereq' && add_hint unreal-prereq-folder
has_hint_like 'redist|_commonredist' && add_hint common-redist-folder

DXVK=yes
VKD3D=no
GAMEMODE=yes
MANGOHUD=no
GAMESCOPE=no

if has_dll d3d12.dll || has_dll dxgi.dll; then
    VKD3D=yes
fi

if has_dll ddraw.dll && ! has_dll_like '^d3d(9|10|11|12)\.dll$' && ! has_dll_like '^d3dx9_'; then
    DXVK=no
fi

if [ "${#RECOMMENDED_WINETRICKS[@]}" -gt 0 ] || [ "${#RECOMMENDED_CUSTOM[@]}" -gt 0 ]; then
    CONFIDENCE="medium"
fi
if [ -n "$DLL_TEXT" ] && [ "${#RECOMMENDED_WINETRICKS[@]}" -gt 1 ]; then
    CONFIDENCE="high"
fi

python3 - "$EXE" "$MODE_GUESS" "$ARCH_GUESS" "$CONFIDENCE" "$DXVK" "$VKD3D" "$GAMEMODE" "$MANGOHUD" "$GAMESCOPE" "${RECOMMENDED_WINETRICKS[@]}" -- "${RECOMMENDED_CUSTOM[@]}" --hints "${DETECTED_HINTS[@]}" --dlls $DLL_TEXT <<'PY'
import json, sys

exe, mode, arch, confidence, dxvk, vkd3d, gamemode, mangohud, gamescope = sys.argv[1:10]
rest = sys.argv[10:]

def split_until(marker, items):
    if marker in items:
        idx = items.index(marker)
        return items[:idx], items[idx+1:]
    return items, []

def dedup(items):
    out=[]
    seen=set()
    for item in items:
        if item and item not in seen and not item.startswith('--'):
            out.append(item)
            seen.add(item)
    return out

winetricks, rest = split_until('--', rest)
custom, rest = split_until('--hints', rest)
hints, rest = split_until('--dlls', rest)
dlls = rest

data = {
    "file": exe,
    "mode_guess": mode,
    "arch_guess": arch,
    "confidence": confidence,
    "detected_dlls": dedup(dlls),
    "detected_hints": dedup(hints),
    "recommended_winetricks": dedup(winetricks),
    "recommended_custom": dedup(custom),
    "recommended_features": {
        "dxvk": dxvk == "yes",
        "vkd3d": vkd3d == "yes",
        "gamemode": gamemode == "yes",
        "mangohud": mangohud == "yes",
        "gamescope": gamescope == "yes",
    },
}
print(json.dumps(data, indent=2, ensure_ascii=False))
PY
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-detect-exe-runtime"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-exe-launcher" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

ORIGINAL_EXE=""
PROFILE_NAME=""
ACTION=""

PREFIX_BASE="${LOLIOS_PREFIX_BASE:-$HOME/Games/LoliOS}"
STATE_DIR="${LOLIOS_EXE_STATE_DIR:-$HOME/.local/share/lolios/exe-launcher}"
APPS_DIR="$STATE_DIR/apps"
LOG_ROOT="$STATE_DIR/logs"

mkdir -p "$PREFIX_BASE" "$APPS_DIR" "$LOG_ROOT"

usage() {
    cat <<USAGE
Usage:
  lolios-exe-launcher <file.exe>
  lolios-exe-launcher --profile <profile-name>
  lolios-exe-launcher --manage
USAGE
}

notify_error() {
    local msg="$1"
    if command -v kdialog >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
        kdialog --error "$msg" 2>/dev/null || true
    else
        echo "ERROR: $msg" >&2
    fi
}

notify_info() {
    local msg="$1"
    if command -v kdialog >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
        kdialog --msgbox "$msg" 2>/dev/null || true
    else
        echo "$msg"
    fi
}

choose_menu() {
    local title="$1"
    shift
    if command -v kdialog >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
        kdialog --menu "$title" "$@" 2>/dev/null || true
    else
        local keys=()
        local i=1
        echo
        echo "$title"
        while [ "$#" -gt 0 ]; do
            keys+=("$1")
            echo "  $i) $2 [$1]"
            shift 2
            i=$((i + 1))
        done
        echo "  0) Anuluj"
        read -r -p "> " ans
        [ "${ans:-0}" = "0" ] && return 1
        local idx=$((ans - 1))
        printf '%s
' "${keys[$idx]:-}"
    fi
}

input_text() {
    local title="$1"
    local default="${2:-}"
    if command -v kdialog >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
        kdialog --inputbox "$title" "$default" 2>/dev/null || true
    else
        read -r -p "$title [$default]: " value
        printf '%s
' "${value:-$default}"
    fi
}

yesno() {
    local question="$1"
    local default="${2:-yes}"
    if command -v kdialog >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
        if kdialog --yesno "$question" 2>/dev/null; then
            return 0
        fi
        return 1
    fi

    local prompt="y/N"
    [ "$default" = "yes" ] && prompt="Y/n"
    read -r -p "$question [$prompt]: " ans
    ans="${ans:-$default}"
    case "$ans" in
        y|Y|yes|YES|Yes|tak|TAK|Tak) return 0 ;;
        *) return 1 ;;
    esac
}

sanitize_name() {
    printf '%s' "$1" | tr -cs 'A-Za-z0-9._-' '_' | sed 's/^_*//; s/_*$//'
}

write_profile() {
    local name="$1" exe="$2" prefix="$3" runner="$4" mode="$5" arch="$6"
    local dxvk="$7" vkd3d="$8" physx="$9" vcrun2019="${10}" d3dx9="${11}"
    local gamemode="${12}" mangohud="${13}" gamescope="${14}" prime="${15}" virtual_desktop="${16}"
    local args="${17}" gamescope_args="${18}"
    local dir="$APPS_DIR/$name"
    mkdir -p "$dir"

    python3 - "$dir/profile.json" <<PY
import json, sys
profile = {
    "name": ${name@Q},
    "exe": ${exe@Q},
    "prefix": ${prefix@Q},
    "runner": ${runner@Q},
    "mode": ${mode@Q},
    "arch": ${arch@Q},
    "dxvk": ${dxvk@Q} == "yes",
    "vkd3d": ${vkd3d@Q} == "yes",
    "physx": ${physx@Q} == "yes",
    "vcrun2019": ${vcrun2019@Q} == "yes",
    "d3dx9": ${d3dx9@Q} == "yes",
    "gamemode": ${gamemode@Q} == "yes",
    "mangohud": ${mangohud@Q} == "yes",
    "gamescope": ${gamescope@Q} == "yes",
    "prime": ${prime@Q} == "yes",
    "virtual_desktop": ${virtual_desktop@Q} == "yes",
    "arguments": ${args@Q},
    "gamescope_args": ${gamescope_args@Q},
}
with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump(profile, f, indent=2, ensure_ascii=False)
PY
}

read_profile_value() {
    local profile_file="$1" key="$2"
    python3 - "$profile_file" "$key" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
value = data.get(sys.argv[2], "")
if isinstance(value, bool):
    print("yes" if value else "no")
else:
    print(value)
PY
}

list_profiles() {
    find "$APPS_DIR" -mindepth 2 -maxdepth 2 -name profile.json -printf '%h
' 2>/dev/null | sort | while read -r dir; do
        basename "$dir"
    done
}

find_proton() {
    local p
    for p in \
        "$HOME/.steam/root/compatibilitytools.d"/*/proton \
        "$HOME/.steam/steam/compatibilitytools.d"/*/proton \
        "$HOME/.local/share/Steam/compatibilitytools.d"/*/proton \
        "$HOME/.steam/root/steamapps/common/Proton"*/proton \
        "$HOME/.local/share/Steam/steamapps/common/Proton"*/proton
    do
        [ -x "$p" ] && { printf '%s
' "$p"; return 0; }
    done
    return 1
}

choose_existing_profile() {
    local entries=()
    local p
    while IFS= read -r p; do
        entries+=("$p" "$p")
    done < <(list_profiles)
    [ "${#entries[@]}" -eq 0 ] && { notify_error "Brak zapisanych profili/prefixów."; return 1; }
    choose_menu "Wybierz prefix/profil" "${entries[@]}"
}

install_runtime_components() {
    local prefix="$1" dxvk="$2" vkd3d="$3" physx="$4" vcrun2019="$5" d3dx9="$6" log="$7"
    export WINEPREFIX="$prefix"

    echo "[LOLIOS] wineboot" | tee -a "$log"
    wineboot -u >> "$log" 2>&1 || true

    local tricks=()
    [ "$vcrun2019" = "yes" ] && tricks+=(vcrun2019)
    [ "$d3dx9" = "yes" ] && tricks+=(d3dx9)
    [ "$dxvk" = "yes" ] && tricks+=(dxvk)
    [ "$vkd3d" = "yes" ] && tricks+=(vkd3d)

    if [ "${#tricks[@]}" -gt 0 ] && command -v winetricks >/dev/null 2>&1; then
        echo "[LOLIOS] winetricks: ${tricks[*]}" | tee -a "$log"
        winetricks -q "${tricks[@]}" >> "$log" 2>&1 || true
    fi

    if [ "$physx" = "yes" ]; then
        if [ -f "/opt/lolios/windows-runtimes/NVIDIA-PhysX.exe" ]; then
            echo "[LOLIOS] Installing NVIDIA PhysX" | tee -a "$log"
            wine "/opt/lolios/windows-runtimes/NVIDIA-PhysX.exe" /quiet >> "$log" 2>&1 || \
            wine "/opt/lolios/windows-runtimes/NVIDIA-PhysX.exe" >> "$log" 2>&1 || true
        else
            echo "[WARN] PhysX requested, but installer is missing." | tee -a "$log"
        fi
    fi
}

build_command_array() {
    local runner="$1" exe="$2" prefix="$3" gamemode="$4" mangohud="$5" gamescope="$6" prime="$7" args="$8" gamescope_args="$9"
    export WINEPREFIX="$prefix"
    export WINEDEBUG="${WINEDEBUG:--all}"
    export DXVK_LOG_LEVEL="${DXVK_LOG_LEVEL:-none}"
    export VKD3D_DEBUG="${VKD3D_DEBUG:-none}"
    export WINEESYNC="${WINEESYNC:-1}"
    export WINEFSYNC="${WINEFSYNC:-1}"
    export PROTON_ENABLE_NVAPI="${PROTON_ENABLE_NVAPI:-1}"
    export DXVK_ENABLE_NVAPI="${DXVK_ENABLE_NVAPI:-1}"

    local cmd=()
    if [ "$gamescope" = "yes" ] && command -v gamescope >/dev/null 2>&1; then
        # shellcheck disable=SC2206
        local gs_extra=( $gamescope_args )
        cmd+=(gamescope "${gs_extra[@]}" --)
    fi
    [ "$gamemode" = "yes" ] && command -v gamemoderun >/dev/null 2>&1 && cmd+=(gamemoderun)
    [ "$mangohud" = "yes" ] && command -v mangohud >/dev/null 2>&1 && cmd+=(mangohud)
    if [ "$prime" = "yes" ] && command -v prime-run >/dev/null 2>&1; then
        cmd+=(prime-run)
    elif [ "$prime" = "yes" ]; then
        export __NV_PRIME_RENDER_OFFLOAD=1
        export __GLX_VENDOR_LIBRARY_NAME=nvidia
        export __VK_LAYER_NV_optimus=NVIDIA_only
    fi

    if [ "$runner" = "proton" ] || [ "$runner" = "auto" ]; then
        local proton_bin=""
        if proton_bin="$(find_proton)"; then
            export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.steam/root"
            [ -d "$STEAM_COMPAT_CLIENT_INSTALL_PATH" ] || export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/Steam"
            export STEAM_COMPAT_DATA_PATH="$(dirname "$prefix")/proton-data"
            mkdir -p "$STEAM_COMPAT_DATA_PATH"
            cmd+=("$proton_bin" run "$exe")
        else
            cmd+=(wine "$exe")
        fi
    else
        cmd+=(wine "$exe")
    fi

    if [ -n "$args" ]; then
        # shellcheck disable=SC2206
        local extra_args=( $args )
        cmd+=("${extra_args[@]}")
    fi
    printf '%s\0' "${cmd[@]}"
}

run_profile() {
    local name="$1"
    local profile_file="$APPS_DIR/$name/profile.json"
    [ -f "$profile_file" ] || { notify_error "Profil nie istnieje: $name"; exit 1; }

    local exe prefix runner mode arch dxvk vkd3d physx vcrun2019 d3dx9 gamemode mangohud gamescope prime virtual_desktop args gamescope_args
    exe="$(read_profile_value "$profile_file" exe)"
    prefix="$(read_profile_value "$profile_file" prefix)"
    runner="$(read_profile_value "$profile_file" runner)"
    mode="$(read_profile_value "$profile_file" mode)"
    arch="$(read_profile_value "$profile_file" arch)"
    dxvk="$(read_profile_value "$profile_file" dxvk)"
    vkd3d="$(read_profile_value "$profile_file" vkd3d)"
    physx="$(read_profile_value "$profile_file" physx)"
    vcrun2019="$(read_profile_value "$profile_file" vcrun2019)"
    d3dx9="$(read_profile_value "$profile_file" d3dx9)"
    gamemode="$(read_profile_value "$profile_file" gamemode)"
    mangohud="$(read_profile_value "$profile_file" mangohud)"
    gamescope="$(read_profile_value "$profile_file" gamescope)"
    prime="$(read_profile_value "$profile_file" prime)"
    virtual_desktop="$(read_profile_value "$profile_file" virtual_desktop)"
    args="$(read_profile_value "$profile_file" arguments)"
    gamescope_args="$(read_profile_value "$profile_file" gamescope_args)"

    [ -f "$exe" ] || { notify_error "Plik EXE z profilu nie istnieje:
$exe"; exit 1; }
    mkdir -p "$prefix" "$APPS_DIR/$name/logs"
    local log="$APPS_DIR/$name/logs/$(date +%Y%m%d-%H%M%S).log"

    {
        echo "=== LoliOS EXE profile run ==="
        echo "Date: $(date)"
        echo "Profile: $name"
        echo "Mode: $mode"
        echo "Runner: $runner"
        echo "EXE: $exe"
        echo "Prefix: $prefix"
        echo
    } >> "$log"

    if [ ! -f "$prefix/.lolios-ready" ]; then
        [ "$arch" = "win32" ] && export WINEARCH=win32 || export WINEARCH=win64
        install_runtime_components "$prefix" "$dxvk" "$vkd3d" "$physx" "$vcrun2019" "$d3dx9" "$log"
        touch "$prefix/.lolios-ready"
    fi

    local -a cmd
    mapfile -d '' -t cmd < <(build_command_array "$runner" "$exe" "$prefix" "$gamemode" "$mangohud" "$gamescope" "$prime" "$args" "$gamescope_args")
    echo "[LOLIOS] Command: ${cmd[*]}" >> "$log"

    if command -v kdialog >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
        (
            "${cmd[@]}" >> "$log" 2>&1
            status=$?
            if [ "$status" -ne 0 ]; then
                kdialog --title "LoliOS EXE Launcher" --warningyesno "Program zakończył się błędem.

Profil: $name
Kod: $status

Pokazać log?" 2>/dev/null && xdg-open "$log" 2>/dev/null || true
            fi
        ) &
    else
        "${cmd[@]}" 2>&1 | tee -a "$log"
    fi
}

scan_exes_in_prefix() {
    local prefix="$1"
    find "$prefix/drive_c" -type f -iname '*.exe' 2>/dev/null | \
        grep -Eiv 'unins|uninstall|crash|helper|redist|vcredist|dxsetup|installshield|setup' | \
        sort | head -100
}

create_desktop_entry() {
    local name="$1" display_name="$2"
    local desktop_dir="$HOME/.local/share/applications"
    mkdir -p "$desktop_dir"
    local desktop_file="$desktop_dir/lolios-${name}.desktop"
    cat > "$desktop_file" <<EOF_DESKTOP
[Desktop Entry]
Type=Application
Name=$display_name
Comment=Run with LoliOS EXE Launcher
Exec=/usr/local/bin/lolios-exe-launcher --profile $name
Icon=wine
Categories=Game;Utility;
Terminal=false
StartupNotify=true
EOF_DESKTOP
    chmod +x "$desktop_file"
    update-desktop-database "$desktop_dir" >/dev/null 2>&1 || true
}

configure_new_or_existing() {
    local exe="$1"
    local inferred="run"
    local detected_winetricks="" detected_custom="" detected_confidence="low" detected_arch="win64"
    local detected_dxvk="yes" detected_vkd3d="no"

    if command -v lolios-detect-exe-runtime >/dev/null 2>&1; then
        detection_json="$(lolios-detect-exe-runtime "$exe" 2>/dev/null || true)"
        if [ -n "${detection_json:-}" ]; then
            inferred="$(printf '%s' "$detection_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("mode_guess","run"))' 2>/dev/null || echo run)"
            detected_arch="$(printf '%s' "$detection_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("arch_guess","win64"))' 2>/dev/null || echo win64)"
            detected_confidence="$(printf '%s' "$detection_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("confidence","low"))' 2>/dev/null || echo low)"
            detected_winetricks="$(printf '%s' "$detection_json" | python3 -c 'import json,sys; print(" ".join(json.load(sys.stdin).get("recommended_winetricks",[])))' 2>/dev/null || true)"
            detected_custom="$(printf '%s' "$detection_json" | python3 -c 'import json,sys; print(" ".join(json.load(sys.stdin).get("recommended_custom",[])))' 2>/dev/null || true)"
            detected_dxvk="$(printf '%s' "$detection_json" | python3 -c 'import json,sys; print("yes" if json.load(sys.stdin).get("recommended_features",{}).get("dxvk", True) else "no")' 2>/dev/null || echo yes)"
            detected_vkd3d="$(printf '%s' "$detection_json" | python3 -c 'import json,sys; print("yes" if json.load(sys.stdin).get("recommended_features",{}).get("vkd3d", False) else "no")' 2>/dev/null || echo no)"
        fi
    fi

    if [ -n "${detection_json:-}" ] && command -v kdialog >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
        local summary
        summary="$(printf '%s' "$detection_json" | python3 -c '
import json,sys
j=json.load(sys.stdin)
print("Tryb: " + j.get("mode_guess","run"))
print("Architektura: " + j.get("arch_guess","unknown"))
print("Pewność: " + j.get("confidence","low"))
print("Winetricks: " + (", ".join(j.get("recommended_winetricks",[])) or "brak"))
print("Custom: " + (", ".join(j.get("recommended_custom",[])) or "brak"))
features=j.get("recommended_features",{})
print("DXVK: " + str(features.get("dxvk", True)))
print("VKD3D: " + str(features.get("vkd3d", False)))
' 2>/dev/null || true)"
        kdialog --title "LoliOS Runtime Detector" --msgbox "Wykryto prawdopodobne zależności:

$summary" 2>/dev/null || true
    fi

    local action_choice
    action_choice="$(choose_menu "LoliOS EXE Launcher
Plik: $(basename "$exe")
Wybierz tryb" \
        run "Uruchom program / portable EXE" \
        install "Zainstaluj program lub grę" \
        patch "Patch / update / mod do istniejącego prefixu" \
        runtime "Runtime / redist do istniejącego prefixu" \
        advanced "Zaawansowane: wybierz wszystko ręcznie" \
        cancel "Anuluj")" || exit 0
    [ "$action_choice" = "cancel" ] && exit 0
    [ "$action_choice" = "advanced" ] && action_choice="$inferred"

    local runner
    runner="$(choose_menu "Runner" \
        auto "Auto: Proton-GE jeśli dostępny, inaczej Wine" \
        wine "Wine" \
        proton "Proton-GE / Steam Proton" \
        cancel "Anuluj")" || exit 0
    [ "$runner" = "cancel" ] && exit 0

    local base_name safe_name display_name prefix profile_name arch
    base_name="$(basename "$exe")"
    display_name="${base_name%.*}"
    display_name="$(input_text "Nazwa profilu/aplikacji" "$display_name")"
    safe_name="$(sanitize_name "$display_name")"
    [ -n "$safe_name" ] || safe_name="windows-app"

    if [ "$action_choice" = "patch" ] || [ "$action_choice" = "runtime" ]; then
        profile_name="$(choose_existing_profile)" || exit 1
        local existing_profile="$APPS_DIR/$profile_name/profile.json"
        prefix="$(read_profile_value "$existing_profile" prefix)"
        display_name="$profile_name"
        safe_name="$profile_name"
    else
        profile_name="$safe_name"
        prefix="$PREFIX_BASE/$safe_name/prefix"
    fi

    arch="win64"
    if yesno "Użyć prefixu 32-bit? Tylko dla bardzo starych gier/programów." "no"; then
        arch="win32"
    fi

    local dxvk="$detected_dxvk" vkd3d="$detected_vkd3d" physx="no" vcrun2019="yes" d3dx9="yes" gamemode="yes" mangohud="no" gamescope="no" prime="auto" virtual_desktop="no"

    printf '%s
' "$detected_winetricks" | grep -qw d3dx9 && d3dx9="yes" || true
    printf '%s
' "$detected_winetricks" | grep -qw vcrun2019 && vcrun2019="yes" || true
    printf '%s
' "$detected_custom" | grep -qw physx && physx="yes" || true

    local args="" gamescope_args="-f -W 1920 -H 1080"

    # Runtime choices with detector suggestions as defaults.
    yesno "Włączyć DXVK? Detektor sugeruje: $dxvk" "$dxvk" && dxvk="yes" || dxvk="no"
    yesno "Włączyć VKD3D-Proton? Detektor sugeruje: $vkd3d" "$vkd3d" && vkd3d="yes" || vkd3d="no"
    yesno "Zainstalować NVIDIA PhysX w prefixie? Detektor sugeruje: $physx" "$physx" && physx="yes" || physx="no"
    yesno "Zainstalować vcrun2019?" "$vcrun2019" && vcrun2019="yes" || vcrun2019="no"
    yesno "Zainstalować d3dx9?" "$d3dx9" && d3dx9="yes" || d3dx9="no"
    yesno "Włączyć GameMode?" "yes" && gamemode="yes" || gamemode="no"
    yesno "Włączyć MangoHud?" "no" && mangohud="yes" || mangohud="no"
    yesno "Uruchamiać przez Gamescope?" "no" && gamescope="yes" || gamescope="no"

    local prime_choice
    prime_choice="$(choose_menu "GPU" \
        auto "Auto" \
        yes "Wymuś NVIDIA prime-run/offload" \
        no "Nie wymuszaj NVIDIA" \
        cancel "Anuluj")" || exit 0
    [ "$prime_choice" = "cancel" ] && exit 0
    if [ "$prime_choice" = "auto" ]; then
        if command -v prime-run >/dev/null 2>&1 || lspci 2>/dev/null | grep -qi NVIDIA; then
            prime="yes"
        else
            prime="no"
        fi
    else
        prime="$prime_choice"
    fi

    yesno "Wymusić wirtualny pulpit Wine?" "no" && virtual_desktop="yes" || virtual_desktop="no"
    args="$(input_text "Argumenty programu, puste jeśli brak" "")"
    [ "$gamescope" = "yes" ] && gamescope_args="$(input_text "Argumenty Gamescope" "$gamescope_args")"

    mkdir -p "$prefix" "$PREFIX_BASE/$safe_name/logs"
    local log="$PREFIX_BASE/$safe_name/logs/setup-$(date +%Y%m%d-%H%M%S).log"
    [ "$arch" = "win32" ] && export WINEARCH=win32 || export WINEARCH=win64
    install_runtime_components "$prefix" "$dxvk" "$vkd3d" "$physx" "$vcrun2019" "$d3dx9" "$log"

    local final_exe="$exe"
    if [ "$action_choice" = "install" ]; then
        notify_info "Teraz uruchomi się instalator. Po zakończeniu wybierzesz główny plik .exe gry/programu."
        export WINEPREFIX="$prefix"
        wine "$exe" >> "$log" 2>&1 || true
        local found=()
        while IFS= read -r candidate; do
            found+=("$candidate" "$(basename "$candidate")")
        done < <(scan_exes_in_prefix "$prefix")
        if [ "${#found[@]}" -gt 0 ]; then
            final_exe="$(choose_menu "Wybierz główny plik EXE do profilu" "${found[@]}")" || final_exe="$exe"
        fi
    elif [ "$action_choice" = "patch" ] || [ "$action_choice" = "runtime" ]; then
        notify_info "Plik zostanie uruchomiony w istniejącym prefixie: $profile_name"
        export WINEPREFIX="$prefix"
        wine "$exe" >> "$log" 2>&1 || true
        notify_info "Patch/runtime zakończony. Log: $log"
        exit 0
    fi

    write_profile "$safe_name" "$final_exe" "$prefix" "$runner" "$action_choice" "$arch" \
        "$dxvk" "$vkd3d" "$physx" "$vcrun2019" "$d3dx9" "$gamemode" "$mangohud" "$gamescope" "$prime" "$virtual_desktop" "$args" "$gamescope_args"

    yesno "Utworzyć skrót w menu KDE?" "yes" && create_desktop_entry "$safe_name" "$display_name"
    if yesno "Uruchomić teraz?" "yes"; then
        run_profile "$safe_name"
    else
        notify_info "Profil zapisany: $safe_name"
    fi
}

manage_profiles() {
    local entries=()
    local p
    while IFS= read -r p; do entries+=("$p" "$p"); done < <(list_profiles)
    [ "${#entries[@]}" -eq 0 ] && { notify_info "Brak profili. Kliknij plik .exe, aby utworzyć pierwszy profil."; exit 0; }
    local pchoice action profile_file prefix
    pchoice="$(choose_menu "LoliOS EXE Profile Manager" "${entries[@]}")" || exit 0
    action="$(choose_menu "Profil: $pchoice" \
        run "Uruchom" \
        folder "Otwórz folder prefixu" \
        logs "Otwórz logi" \
        shortcut "Utwórz/odśwież skrót w menu" \
        delete "Usuń profil i prefix" \
        cancel "Anuluj")" || exit 0
    profile_file="$APPS_DIR/$pchoice/profile.json"
    prefix="$(read_profile_value "$profile_file" prefix)"
    case "$action" in
        run) run_profile "$pchoice" ;;
        folder) xdg-open "$(dirname "$prefix")" 2>/dev/null || true ;;
        logs) xdg-open "$APPS_DIR/$pchoice/logs" 2>/dev/null || true ;;
        shortcut) create_desktop_entry "$pchoice" "$pchoice" ;;
        delete)
            if yesno "Usunąć profil i cały prefix?
$pchoice
$prefix" "no"; then
                rm -rf "$APPS_DIR/$pchoice" "$(dirname "$prefix")"
                notify_info "Usunięto: $pchoice"
            fi
            ;;
        *) exit 0 ;;
    esac
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --profile) PROFILE_NAME="${2:-}"; shift 2 ;;
        --manage) ACTION="manage"; shift ;;
        --help|-h) usage; exit 0 ;;
        *) ORIGINAL_EXE="$1"; shift ;;
    esac
done

if [ -n "$PROFILE_NAME" ]; then run_profile "$PROFILE_NAME"; exit 0; fi
if [ "$ACTION" = "manage" ]; then manage_profiles; exit 0; fi
[ -n "$ORIGINAL_EXE" ] || { usage; exit 1; }
[ -f "$ORIGINAL_EXE" ] || { notify_error "Plik nie istnieje:
$ORIGINAL_EXE"; exit 1; }
configure_new_or_existing "$ORIGINAL_EXE"
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-exe-launcher"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-exe-runner" <<'EOF'
#!/usr/bin/env bash
exec /usr/local/bin/lolios-exe-launcher "$@"
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-exe-runner"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-prefix-manager" <<'EOF'
#!/usr/bin/env bash
exec /usr/local/bin/lolios-exe-launcher --manage
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-prefix-manager"

mkdir -p "$PROFILE/airootfs/opt/lolios/windows-runtimes"
if [ -n "$PHYSX_EXE" ]; then
    [ -f "$PHYSX_EXE" ] || die "PHYSX_EXE wskazuje nieistniejący plik: $PHYSX_EXE"
    cp "$PHYSX_EXE" "$PROFILE/airootfs/opt/lolios/windows-runtimes/NVIDIA-PhysX.exe"
else
    warn "Nie podano PHYSX_EXE. Obsługa PhysX istnieje, ale bez instalatora."
fi

cat > "$PROFILE/airootfs/usr/local/bin/lolios-install-physx" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

PHYSX="/opt/lolios/windows-runtimes/NVIDIA-PhysX.exe"
PREFIX="$HOME/.local/share/lolios/wineprefixes/physx"

mkdir -p "$PREFIX"
export WINEPREFIX="$PREFIX"

if [ ! -f "$PHYSX" ]; then
    kdialog --error "Brak NVIDIA PhysX installer: $PHYSX" 2>/dev/null || echo "Brak: $PHYSX"
    exit 1
fi

wineboot -u || true
exec wine "$PHYSX"
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-install-physx"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-install-dotnet-wine" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
PREFIX="${1:-$HOME/.local/share/lolios/wineprefixes/dotnet}"
MODE="${2:-modern}"
mkdir -p "$PREFIX"
export WINEPREFIX="$PREFIX"
wineboot -u || true
command -v winetricks >/dev/null 2>&1 || { echo "winetricks missing" >&2; exit 1; }
case "$MODE" in
    legacy) winetricks -q dotnet20sp2 dotnet35sp1 ;;
    modern) winetricks -q dotnet48 ;;
    full|all) winetricks -q dotnet20sp2 dotnet35sp1 dotnet40 dotnet48 ;;
    *) echo "Usage: lolios-install-dotnet-wine [prefix] [legacy|modern|full]" >&2; exit 2 ;;
esac
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-install-dotnet-wine"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-photoshop-installer" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
INSTALLER="${1:-}"
PREFIX="${LOLIOS_ADOBE_PREFIX:-$HOME/Games/LoliOS/AdobePhotoshop/prefix}"
ADOBE_WINE="${LOLIOS_ADOBE_WINE:-/opt/lolios/wine-adobe/bin/wine}"
LOGDIR="$HOME/Games/LoliOS/AdobePhotoshop/logs"
LOG="$LOGDIR/install-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$PREFIX" "$LOGDIR"
[ -n "$INSTALLER" ] && [ -f "$INSTALLER" ] || { echo "Usage: lolios-photoshop-installer /path/to/official/AdobeCreativeCloudInstaller.exe" >&2; exit 2; }
[ -x "$ADOBE_WINE" ] || { echo "Missing patched Adobe Wine: $ADOBE_WINE" >&2; exit 1; }
export WINEPREFIX="$PREFIX" WINEARCH=win64 WINEESYNC=1 WINEFSYNC=1 WINEDLLOVERRIDES="mscoree,mshtml,msxml3,msxml6=n,b"
{ echo "=== LoliOS Photoshop / Adobe CC installer ==="; echo "Date: $(date)"; echo "Installer: $INSTALLER"; echo "Prefix: $PREFIX"; echo "Wine: $ADOBE_WINE"; echo; } >> "$LOG"
"$ADOBE_WINE" wineboot -u >> "$LOG" 2>&1 || true
if command -v winetricks >/dev/null 2>&1; then WINE="$ADOBE_WINE" winetricks -q corefonts gdiplus msxml3 msxml6 vcrun2019 dotnet48 >> "$LOG" 2>&1 || true; fi
exec "$ADOBE_WINE" "$INSTALLER" >> "$LOG" 2>&1
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-photoshop-installer"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-gaming-doctor" <<'EOF'
#!/usr/bin/env bash
set -u

LOG="${1:-/tmp/lolios-gaming-doctor.log}"

check() {
    local label="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        printf 'OK:   %s\n' "$label"
    else
        printf 'WARN: %s\n' "$label"
    fi
}

{
    echo "=== LoliOS Gaming Doctor ==="
    echo "Date: $(date)"
    echo

    echo "--- System ---"
    uname -a || true
    cat /etc/os-release 2>/dev/null || true
    echo

    echo "--- GPU ---"
    lspci | grep -Ei 'vga|3d|display' || true
    echo

    echo "--- Checks ---"
    check "Vulkan loader" command -v vulkaninfo
    check "Vulkan works" vulkaninfo --summary
    check "Steam" command -v steam
    check "Lutris" command -v lutris
    check "Heroic" command -v heroic
    check "Bottles" command -v bottles
    check "Wine" command -v wine
    check "Winetricks" command -v winetricks
    check "Protontricks" command -v protontricks
    check "GameMode daemon" command -v gamemoded
    check "MangoHud" command -v mangohud
    check "Gamescope" command -v gamescope
    check "NVIDIA settings" command -v nvidia-settings
    check "PipeWire" command -v pipewire
    check "Bluetooth tools" command -v bluetoothctl
    echo

    echo "--- Kernel modules ---"
    lsmod | grep -Ei 'nvidia|amdgpu|i915' || true
    echo

    echo "--- Limits ---"
    ulimit -n || true
    echo

    echo "--- sysctl ---"
    sysctl vm.max_map_count 2>/dev/null || true
} | tee "$LOG"

if command -v kdialog >/dev/null 2>&1; then
    kdialog --textbox "$LOG" 1000 750 2>/dev/null || true
fi
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-gaming-doctor"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-gaming-center" <<'EOF'
#!/usr/bin/env bash
set -u

run_terminal() {
    local title="$1"
    shift
    if command -v konsole >/dev/null 2>&1; then
        konsole --new-tab --workdir "$HOME" -p tabtitle="$title" -e "$@" &
    elif command -v xterm >/dev/null 2>&1; then
        xterm -T "$title" -e "$@" &
    else
        "$@"
    fi
}

while true; do
    if command -v kdialog >/dev/null 2>&1; then
        CHOICE="$(kdialog --menu "LoliOS Gaming Center" \
            doctor "Gaming Doctor: GPU/Vulkan/Wine/Proton diagnostics" \
            gpu-auto "Apply automatic GPU profile" \
            gpu-nvidia-desktop "Apply NVIDIA desktop profile" \
            gpu-nvidia-laptop "Apply NVIDIA laptop hybrid profile" \
            gpu-amd "Apply AMD profile" \
            gpu-intel "Apply Intel profile" \
            update "Run safe system update with snapshot/DKMS checks" \
            snapshots "Open Snapper snapshot list" \
            repair "Open installed-system recovery tool" \
            physx "Install NVIDIA PhysX into Wine prefix" \
            prefixes "Open LoliOS game prefixes folder" \
            logs "Open /tmp logs" \
            quit "Exit" 2>/dev/null || true)"
    else
        echo "LoliOS Gaming Center"
        echo "1) doctor"
        echo "2) gpu-auto"
        echo "3) update"
        echo "4) repair"
        echo "5) quit"
        read -r -p "> " CHOICE
        case "$CHOICE" in
            1) CHOICE=doctor ;;
            2) CHOICE=gpu-auto ;;
            3) CHOICE=update ;;
            4) CHOICE=repair ;;
            *) CHOICE=quit ;;
        esac
    fi

    case "${CHOICE:-quit}" in
        doctor) run_terminal "Gaming Doctor" /usr/local/bin/lolios-gaming-doctor ;;
        gpu-auto) run_terminal "GPU Auto" sudo /usr/local/bin/lolios-gpu-profile auto ;;
        gpu-nvidia-desktop) run_terminal "NVIDIA Desktop" sudo /usr/local/bin/lolios-gpu-profile nvidia-desktop ;;
        gpu-nvidia-laptop) run_terminal "NVIDIA Laptop" sudo /usr/local/bin/lolios-gpu-profile nvidia-laptop ;;
        gpu-amd) run_terminal "AMD Profile" sudo /usr/local/bin/lolios-gpu-profile amd ;;
        gpu-intel) run_terminal "Intel Profile" sudo /usr/local/bin/lolios-gpu-profile intel ;;
        update) run_terminal "LoliOS Update" sudo /usr/local/bin/lolios-update ;;
        snapshots) run_terminal "Snapper" bash -lc 'sudo snapper list; echo; read -r -p "Enter to close..." _' ;;
        repair) run_terminal "LoliOS Repair" sudo /usr/local/bin/lolios-repair-installed-system ;;
        physx) /usr/local/bin/lolios-install-physx & ;;
        prefixes) mkdir -p "$HOME/Games/LoliOS"; xdg-open "$HOME/Games/LoliOS" 2>/dev/null || true ;;
        logs) xdg-open /tmp 2>/dev/null || true ;;
        quit|*) exit 0 ;;
    esac
done
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-gaming-center"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-compat-center" <<'EOF'
#!/usr/bin/env bash
exec /usr/local/bin/lolios-gaming-center
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-compat-center"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-gpu-profile" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

PROFILE="${1:-auto}"

log() { echo "[LOLIOS GPU] $*"; }
write_file() { install -Dm644 /dev/stdin "$1"; }

GPU_INFO="$(lspci 2>/dev/null || true)"
IS_LAPTOP=0
[ -d /sys/class/power_supply ] && ls /sys/class/power_supply 2>/dev/null | grep -qiE '^BAT|BAT[0-9]' && IS_LAPTOP=1 || true

if [ "$PROFILE" = "auto" ]; then
    if echo "$GPU_INFO" | grep -qi NVIDIA && [ "$IS_LAPTOP" = "1" ]; then
        PROFILE="nvidia-laptop"
    elif echo "$GPU_INFO" | grep -qi NVIDIA; then
        PROFILE="nvidia-desktop"
    elif echo "$GPU_INFO" | grep -qiE 'AMD|ATI'; then
        PROFILE="amd"
    elif echo "$GPU_INFO" | grep -qi Intel; then
        PROFILE="intel"
    else
        PROFILE="generic"
    fi
fi

mkdir -p /etc/modprobe.d /etc/environment.d /etc/X11/xorg.conf.d /etc/sysctl.d

ensure_grub_nvidia_cmdline() {
    local grub_file="/etc/default/grub"
    [ -f "$grub_file" ] || { log "GRUB config not found, skipping NVIDIA kernel cmdline: $grub_file"; return 0; }

    python3 - "$grub_file" <<'PYGRUB'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8", errors="replace")
params = [
    "quiet",
    "splash",
    "nvidia-drm.modeset=1",
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1",
    "pcie_port_pm=off",
    "clearcpuid=hypervisor",
    "kvm.ignore_msrs=1",
]

pattern = re.compile(r'''^(GRUB_CMDLINE_LINUX_DEFAULT=)(["'])(.*?)(\2)\s*$''', re.M)
match = pattern.search(text)
if match:
    existing = match.group(3).split()
    merged = []
    seen = set()
    for item in existing + params:
        if item and item not in seen:
            merged.append(item)
            seen.add(item)
    replacement = f'{match.group(1)}"' + " ".join(merged) + '"'
    text = text[:match.start()] + replacement + text[match.end():]
else:
    text = text.rstrip() + '\nGRUB_CMDLINE_LINUX_DEFAULT="' + ' '.join(params) + '"\n'

if not re.search(r'^GRUB_CMDLINE_LINUX=', text, re.M):
    text = text.rstrip() + '\nGRUB_CMDLINE_LINUX=""\n'

path.write_text(text, encoding="utf-8")
PYGRUB

    log "NVIDIA GRUB kernel cmdline ensured in $grub_file"
}

case "$PROFILE" in
    nvidia-desktop)
        log "Applying NVIDIA desktop profile"
        ensure_grub_nvidia_cmdline
        cat > /etc/modprobe.d/nvidia-drm.conf <<'EONV'
options nvidia-drm modeset=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
EONV
        cat > /etc/environment.d/90-lolios-nvidia.conf <<'EONVENV'
__GLX_VENDOR_LIBRARY_NAME=nvidia
GBM_BACKEND=nvidia-drm
LIBVA_DRIVER_NAME=nvidia
EONVENV
        systemctl enable nvidia-persistenced.service 2>/dev/null || true
        systemctl enable nvidia-suspend.service 2>/dev/null || true
        systemctl enable nvidia-hibernate.service 2>/dev/null || true
        systemctl enable nvidia-resume.service 2>/dev/null || true
        ;;
    nvidia-laptop)
        log "Applying NVIDIA laptop hybrid/offload profile"
        ensure_grub_nvidia_cmdline
        cat > /etc/modprobe.d/nvidia-drm.conf <<'EONVL'
options nvidia-drm modeset=1
options nvidia NVreg_DynamicPowerManagement=0x02
options nvidia NVreg_PreserveVideoMemoryAllocations=1
EONVL
        cat > /etc/environment.d/90-lolios-nvidia-offload.conf <<'EONVLENV'
__NV_PRIME_RENDER_OFFLOAD=1
__GLX_VENDOR_LIBRARY_NAME=nvidia
__VK_LAYER_NV_optimus=NVIDIA_only
EONVLENV
        systemctl enable nvidia-persistenced.service 2>/dev/null || true
        systemctl enable nvidia-suspend.service 2>/dev/null || true
        systemctl enable nvidia-hibernate.service 2>/dev/null || true
        systemctl enable nvidia-resume.service 2>/dev/null || true
        ;;
    amd)
        log "Applying AMD profile"
        rm -f /etc/environment.d/90-lolios-nvidia.conf /etc/environment.d/90-lolios-nvidia-offload.conf || true
        cat > /etc/modprobe.d/amdgpu.conf <<'EOAMD'
options amdgpu si_support=1 cik_support=1
EOAMD
        ;;
    intel)
        log "Applying Intel profile"
        rm -f /etc/environment.d/90-lolios-nvidia.conf /etc/environment.d/90-lolios-nvidia-offload.conf || true
        cat > /etc/modprobe.d/i915.conf <<'EOINTEL'
options i915 enable_guc=3
EOINTEL
        ;;
    generic)
        log "Applying generic profile"
        ;;
    *)
        echo "Usage: lolios-gpu-profile [auto|nvidia-desktop|nvidia-laptop|amd|intel|generic]" >&2
        exit 2
        ;;
esac

cat > /etc/sysctl.d/90-lolios-gaming.conf <<'EOSYS'
vm.max_map_count = 2147483642
EOSYS

mkinitcpio -P || true
if command -v grub-mkconfig >/dev/null 2>&1 && [ -d /boot/grub ]; then
    grub-mkconfig -o /boot/grub/grub.cfg || true
fi

log "Profile applied: $PROFILE"
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-gpu-profile"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-update" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

log() { echo "[LOLIOS UPDATE] $*"; }

[ "${EUID:-$(id -u)}" -eq 0 ] || { echo "Run as root: sudo lolios-update" >&2; exit 1; }

log "Checking network"
ping -c1 -W3 archlinux.org >/dev/null 2>&1 || echo "[WARN] Network check failed; continuing anyway."

log "Checking free space"
df -h /

if command -v snapper >/dev/null 2>&1 && findmnt -n -o FSTYPE / 2>/dev/null | grep -qx btrfs; then
    log "Creating pre-update snapshot"
    snapper -c root create --description "LoliOS pre-update $(date -Iseconds)" --userdata important=yes 2>/dev/null || true
fi

log "Updating pacman packages"
pacman -Syu --needed


log "Checking DKMS"
if command -v dkms >/dev/null 2>&1; then
    dkms status || true
    dkms autoinstall || true
fi

log "Regenerating initramfs"
mkinitcpio -P || true

if command -v grub-mkconfig >/dev/null 2>&1 && [ -d /boot/grub ]; then
    log "Regenerating GRUB"
    grub-mkconfig -o /boot/grub/grub.cfg || true
fi

if command -v snapper >/dev/null 2>&1 && findmnt -n -o FSTYPE / 2>/dev/null | grep -qx btrfs; then
    log "Creating post-update snapshot"
    snapper -c root create --description "LoliOS post-update $(date -Iseconds)" 2>/dev/null || true
fi

if command -v lolios-gaming-doctor >/dev/null 2>&1; then
    log "Running Gaming Doctor"
    lolios-gaming-doctor /tmp/lolios-update-gaming-doctor.log || true
fi

log "Update completed"
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-update"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-repair-installed-system" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

log() { echo "[LOLIOS REPAIR] $*"; }

[ "${EUID:-$(id -u)}" -eq 0 ] || { echo "Run as root: sudo lolios-repair-installed-system" >&2; exit 1; }

TARGET="${1:-}"
MNT="${MNT:-/mnt/lolios-repair}"

if [ -z "$TARGET" ]; then
    echo "Available block devices:"
    lsblk -f
    echo
    read -r -p "Root partition to repair, e.g. /dev/nvme0n1p2: " TARGET
fi

[ -b "$TARGET" ] || { echo "Not a block device: $TARGET" >&2; exit 1; }

mkdir -p "$MNT"
log "Mounting root: $TARGET -> $MNT"
mount "$TARGET" "$MNT"

if [ -d "$MNT/@" ] && findmnt -n -o FSTYPE "$MNT" | grep -qx btrfs; then
    log "Detected Btrfs @ subvolume; remounting it as root"
    umount "$MNT"
    mount -o subvol=@ "$TARGET" "$MNT"
fi

for dir in dev proc sys run; do
    mount --bind "/$dir" "$MNT/$dir"
done

if [ -d "$MNT/boot" ]; then
    BOOT_DEV=""
    lsblk -f
    echo
    read -r -p "Optional boot/EFI partition to mount, or Enter to skip: " BOOT_DEV
    if [ -n "$BOOT_DEV" ] && [ -b "$BOOT_DEV" ]; then
        mount "$BOOT_DEV" "$MNT/boot" || true
    fi
fi

log "Running repair commands in chroot"
arch-chroot "$MNT" /bin/bash -lc '
set -x
pacman-key --populate archlinux || true
pacman -Syu --needed linux-zen linux-zen-headers linux-lts linux-lts-headers nvidia-dkms nvidia-utils lib32-nvidia-utils grub efibootmgr || true
mkinitcpio -P || true
if [ -d /boot/grub ]; then grub-mkconfig -o /boot/grub/grub.cfg || true; fi
if command -v dkms >/dev/null 2>&1; then dkms autoinstall || true; dkms status || true; fi
if command -v lolios-gpu-profile >/dev/null 2>&1; then lolios-gpu-profile auto || true; fi
'

log "Unmounting"
umount -R "$MNT" || true
log "Repair finished"
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-repair-installed-system"

# Desktop files.
cat > "$PROFILE/airootfs/usr/share/applications/lolios-exe-launcher.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=LoliOS EXE Launcher
Comment=Run or install Windows EXE files with Wine/Proton profiles
Exec=/usr/local/bin/lolios-exe-launcher %f
Icon=wine
MimeType=application/x-ms-dos-executable;application/x-msdownload;application/vnd.microsoft.portable-executable;application/x-msi;
Categories=Game;Utility;
Terminal=false
NoDisplay=false
StartupNotify=true
EOF

cat > "$PROFILE/airootfs/usr/share/applications/lolios-exe-runner.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Run Windows Program
Comment=Compatibility wrapper for LoliOS EXE Launcher
Exec=/usr/local/bin/lolios-exe-runner %f
Icon=wine
MimeType=application/x-ms-dos-executable;application/x-msdownload;application/vnd.microsoft.portable-executable;application/x-msi;
Categories=Game;Utility;
Terminal=false
NoDisplay=false
StartupNotify=true
EOF

cat > "$PROFILE/airootfs/usr/share/applications/lolios-prefix-manager.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=LoliOS Prefix Manager
Comment=Manage Windows apps and game prefixes
Exec=/usr/local/bin/lolios-prefix-manager
Icon=wine
Categories=Game;Utility;System;
Terminal=false
StartupNotify=true
EOF

cat > "$PROFILE/airootfs/usr/share/applications/lolios-install-physx.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Install NVIDIA PhysX
Comment=Install NVIDIA PhysX runtime for older Windows games
Exec=/usr/local/bin/lolios-install-physx
Icon=wine
Categories=Game;System;
Terminal=false
StartupNotify=true
EOF

cat > "$PROFILE/airootfs/usr/share/applications/lolios-gaming-center.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=LoliOS Gaming Center
Comment=Manage gaming diagnostics, GPU profiles, updates, snapshots and repairs
Exec=/usr/local/bin/lolios-gaming-center
Icon=applications-games
Categories=Game;System;
Terminal=false
StartupNotify=true
EOF

cat > "$PROFILE/airootfs/usr/share/applications/lolios-gaming-doctor.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=LoliOS Gaming Doctor
Comment=Check Vulkan, GPU, Wine, Proton and gaming services
Exec=/usr/local/bin/lolios-gaming-doctor
Icon=applications-games
Categories=Game;System;
Terminal=false
StartupNotify=true
EOF

cat > "$PROFILE/airootfs/usr/share/applications/lolios-compat-center.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=LoliOS Compatibility Center
Comment=Check and repair gaming/application compatibility
Exec=/usr/local/bin/lolios-compat-center
Icon=applications-games
Categories=Game;System;
Terminal=false
StartupNotify=true
EOF

# MIME association for .exe.
mkdir -p "$PROFILE/airootfs/etc/xdg" "$PROFILE/airootfs/etc/skel/.config" "$PROFILE/airootfs/root/.config"
cat > "$PROFILE/airootfs/etc/xdg/mimeapps.list" <<'EOF'
[Default Applications]
application/x-ms-dos-executable=lolios-exe-launcher.desktop
application/x-msdownload=lolios-exe-launcher.desktop
application/vnd.microsoft.portable-executable=lolios-exe-launcher.desktop
application/x-msi=lolios-exe-launcher.desktop

[Added Associations]
application/x-ms-dos-executable=lolios-exe-launcher.desktop;
application/x-msdownload=lolios-exe-launcher.desktop;
application/vnd.microsoft.portable-executable=lolios-exe-launcher.desktop;
application/x-msi=lolios-exe-launcher.desktop;
EOF
cp "$PROFILE/airootfs/etc/xdg/mimeapps.list" "$PROFILE/airootfs/etc/skel/.config/mimeapps.list"
cp "$PROFILE/airootfs/etc/xdg/mimeapps.list" "$PROFILE/airootfs/root/.config/mimeapps.list"

cat > "$PROFILE/airootfs/etc/profile.d/lolios-mime.sh" <<'EOF'
#!/usr/bin/env bash
xdg-mime default lolios-exe-launcher.desktop application/x-ms-dos-executable 2>/dev/null || true
xdg-mime default lolios-exe-launcher.desktop application/x-msdownload 2>/dev/null || true
xdg-mime default lolios-exe-launcher.desktop application/vnd.microsoft.portable-executable 2>/dev/null || true
xdg-mime default lolios-exe-launcher.desktop application/x-msi 2>/dev/null || true
EOF
chmod +x "$PROFILE/airootfs/etc/profile.d/lolios-mime.sh"


# ------------------------------------------------------------
