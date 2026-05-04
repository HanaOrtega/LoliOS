# Sourced by ../build.sh; non-conflicting next generation gaming helpers
#
# Canonical user-facing tools are maintained in src/bin and installed by
# stages/17z-install-src-gaming-tools.sh.  This stage only installs helper
# utilities that are still unique here.

log "Writing LoliOS non-conflicting gaming helper tools"

mkdir -p "$PROFILE/airootfs/usr/local/bin"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-analyze-wine-log" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
LOG="${1:-}"
[ -n "$LOG" ] && [ -f "$LOG" ] || { echo "Usage: lolios-analyze-wine-log LOGFILE" >&2; exit 2; }
python3 - "$LOG" <<'PY'
import re, sys, json
text=open(sys.argv[1], errors='ignore').read().lower()
rules=[
 (r'msvcp140|vcruntime140|ucrtbase|concrt140','vcrun2019','Visual C++ 2015-2022 runtime'),
 (r'msvcr120|msvcp120','vcrun2013','Visual C++ 2013 runtime'),
 (r'msvcr110|msvcp110','vcrun2012','Visual C++ 2012 runtime'),
 (r'msvcr100|msvcp100','vcrun2010','Visual C++ 2010 runtime'),
 (r'd3dx9_\d+|d3dcompiler_43','d3dx9 d3dcompiler_43','DirectX 9 legacy components'),
 (r'd3dcompiler_47','d3dcompiler_47','D3D compiler 47'),
 (r'xinput1_3','xinput','XInput runtime'),
 (r'xaudio2|xapofx|x3daudio','xact','XAudio/XACT runtime'),
 (r'openal32','openal','OpenAL runtime'),
 (r'mscoree|\.net|dotnet','dotnet48','Microsoft .NET runtime'),
 (r'physx','physx','NVIDIA PhysX runtime'),
 (r'bad exe format|wrong architecture','arch-check','possible 32/64-bit mismatch'),
 (r'vulkan|dxvk.*failed|vkcreate','gpu-vulkan','Vulkan/GPU driver issue'),
]
out=[]; seen=set()
for pat, fix, msg in rules:
    if re.search(pat,text) and fix not in seen:
        out.append({'suggestion':fix,'reason':msg}); seen.add(fix)
print(json.dumps({'log':sys.argv[1], 'suggestions':out}, indent=2, ensure_ascii=False))
PY
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-analyze-wine-log"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-prefix-manager" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
BASE="${LOLIOS_PREFIX_BASE:-$HOME/Games/LoliOS}"
STATE="${LOLIOS_EXE_STATE_DIR:-$HOME/.local/share/lolios/exe-launcher}"
APPS="$STATE/apps"
mkdir -p "$BASE" "$APPS"
usage(){ cat <<USAGE
Usage:
  lolios-prefix-manager list
  lolios-prefix-manager create NAME [--arch win32|win64]
  lolios-prefix-manager repair NAME
  lolios-prefix-manager delete NAME
  lolios-prefix-manager clone OLD NEW
  lolios-prefix-manager backup NAME
  lolios-prefix-manager restore ARCHIVE
USAGE
}
san(){ printf '%s' "$1"|tr -cs 'A-Za-z0-9._-' '_'|sed 's/^_*//;s/_*$//'; }
profile(){ echo "$APPS/$1/profile.json"; }
prefix_of(){ python3 - "$1" <<'PY'
import json,sys
try:
 data=json.load(open(sys.argv[1])); print(data.get('wine_prefix') or data.get('prefix') or '')
except Exception: print('')
PY
}
case "${1:-}" in
 list)
  find "$APPS" -mindepth 2 -maxdepth 2 -name profile.json -print 2>/dev/null|while read -r f; do
   python3 - "$f" <<'PY'
import json,sys
j=json.load(open(sys.argv[1])); print(f"{j.get('name')}\t{j.get('runner','wine')}\t{j.get('main_exe') or j.get('exe','')}")
PY
  done ;;
 create)
  name="$(san "${2:-}")"; [ -n "$name" ] || { usage; exit 2; }
  arch="win64"; [ "${3:-}" = "--arch" ] && arch="${4:-win64}"
  dir="$APPS/$name"; pre="$BASE/$name/prefix"; mkdir -p "$dir" "$pre"
  python3 - "$dir/profile.json" "$name" "$pre" "$arch" <<'PY'
import json,sys,datetime
p={'schema_version':5,'name':sys.argv[2],'display_name':sys.argv[2],'runner':'wine','arch':sys.argv[4],'wine_prefix':sys.argv[3],'proton_compat_data':sys.argv[3].replace('/prefix','/compatdata'),'main_exe':'','installer_exe':'','winetricks':[],'custom_runtimes':[],'installed_runtimes':[],'features':{'dxvk':True,'vkd3d':False,'gamemode':True,'mangohud':False,'gamescope':False,'prime':'auto','gamescope_args':'-f'},'arguments':'','env':{'WINEESYNC':'1','WINEFSYNC':'1'},'created_at':datetime.datetime.utcnow().isoformat()+'Z'}
json.dump(p,open(sys.argv[1],'w'),indent=2,ensure_ascii=False)
PY
  command -v lolios-profile >/dev/null 2>&1 && lolios-profile migrate "$name" >/dev/null 2>&1 || true
  echo "Created: $name" ;;
 repair)
  name="$(san "${2:-}")"; [ -f "$(profile "$name")" ] || { echo "No profile: $name" >&2; exit 1; }
  lolios-exe-launcher --repair --profile "$name" ;;
 delete)
  name="$(san "${2:-}")"; pf="$(profile "$name")"; [ -f "$pf" ] || { echo "No profile: $name" >&2; exit 1; }
  pre="$(prefix_of "$pf")"; rm -rf "$APPS/$name"; echo "Removed profile: $name"; echo "Prefix left intact: $pre" ;;
 clone)
  old="$(san "${2:-}")"; new="$(san "${3:-}")"; [ -n "$old" ]&&[ -n "$new" ] || { usage; exit 2; }
  cp -a "$APPS/$old" "$APPS/$new"; python3 - "$APPS/$new/profile.json" "$new" <<'PY'
import json,sys
p=sys.argv[1]; j=json.load(open(p)); j['name']=sys.argv[2]; j['display_name']=sys.argv[2]; json.dump(j,open(p,'w'),indent=2,ensure_ascii=False)
PY
  command -v lolios-profile >/dev/null 2>&1 && lolios-profile migrate "$new" >/dev/null 2>&1 || true
  echo "Cloned: $old -> $new" ;;
 backup)
  name="$(san "${2:-}")"; out="$PWD/${name}.lolios-profile.tar.zst"; tar --zstd -cf "$out" -C "$APPS" "$name"; echo "$out" ;;
 restore)
  [ -f "${2:-}" ] || { usage; exit 2; }; tar --zstd -xf "$2" -C "$APPS"; echo "Restored." ;;
 *) usage; exit 2 ;;
esac
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-prefix-manager"
