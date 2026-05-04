# Sourced by ../build.sh; advanced LoliOS gaming core tools

log "Writing advanced LoliOS gaming core tools"

mkdir -p "$PROFILE/airootfs/usr/local/bin" "$PROFILE/airootfs/usr/share/lolios-gaming/plugins"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-runtime-cache" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
CACHE="${LOLIOS_RUNTIME_CACHE:-$HOME/.cache/lolios/windows-runtimes}"
mkdir -p "$CACHE"
case "${1:-}" in
 list) find "$CACHE" -maxdepth 1 -type f -printf '%f\n' | sort ;;
 add) [ -f "${2:-}" ] || { echo "Usage: lolios-runtime-cache add FILE" >&2; exit 2; }; cp -f "$2" "$CACHE/"; echo "$CACHE/$(basename "$2")" ;;
 path) echo "$CACHE" ;;
 *) echo "Usage: lolios-runtime-cache list|add FILE|path" ;;
esac
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-runtime-cache"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-gaming-advanced" <<'EOF'
#!/usr/bin/env python3
import json, os, pathlib, re, shutil, subprocess, sys
from datetime import datetime
HOME=pathlib.Path.home()
STATE=pathlib.Path(os.environ.get('LOLIOS_EXE_STATE_DIR', HOME/'.local/share/lolios/exe-launcher'))
APPS=STATE/'apps'
BASE=pathlib.Path(os.environ.get('LOLIOS_PREFIX_BASE', HOME/'Games/LoliOS'))
CACHE=pathlib.Path(os.environ.get('LOLIOS_RUNTIME_CACHE', HOME/'.cache/lolios/windows-runtimes'))
for p in (APPS,BASE,CACHE): p.mkdir(parents=True,exist_ok=True)
def safe(s): return re.sub(r'[^A-Za-z0-9._-]+','_',s).strip('_') or 'windows-app'
def pf(name): return APPS/safe(name)/'profile.json'
def load(p): return json.load(open(p,encoding='utf-8'))
def save(p,j): p.parent.mkdir(parents=True,exist_ok=True); json.dump(j,open(p,'w',encoding='utf-8'),indent=2,ensure_ascii=False)
def profiles():
 out=[]
 for p in sorted(APPS.glob('*/profile.json')):
  try:
   j=load(p); j['_profile_path']=str(p); j['_logs_dir']=str(p.parent/'logs'); out.append(j)
  except Exception as e: out.append({'name':p.parent.name,'error':str(e)})
 return out
def ensure(j):
 j.setdefault('schema_version',3); j.setdefault('features',{}); j.setdefault('env',{}); j.setdefault('winetricks',[]); j.setdefault('custom_runtimes',[])
 j.setdefault('performance_preset','Balanced'); j.setdefault('engine','unknown')
 j.setdefault('launch_profiles',{'Normal':{'arguments':j.get('arguments',''),'env':{},'features':{}},'Safe mode':{'arguments':'-safe','env':{'WINEDEBUG':'+seh'},'features':{'mangohud':False,'gamescope':False}},'DX11':{'arguments':'-dx11','env':{},'features':{'vkd3d':False}},'DX12':{'arguments':'-dx12','env':{},'features':{'vkd3d':True}},'Debug':{'arguments':'','env':{'WINEDEBUG':'+seh,+loaddll'},'features':{'mangohud':False}}})
 return j
def desktop(n,d):
 f=HOME/'.local/share/applications'/f'lolios-{safe(n)}.desktop'; f.parent.mkdir(parents=True,exist_ok=True)
 f.write_text(f'[Desktop Entry]\nType=Application\nName={d}\nExec=/usr/local/bin/lolios-exe-launcher --profile {safe(n)}\nIcon=wine\nCategories=Game;Utility;\nTerminal=false\nStartupNotify=true\nPrefersNonDefaultGPU=true\nX-KDE-RunOnDiscreteGpu=true\n',encoding='utf-8'); os.chmod(f,0o755)
def create(name,exe='',source='manual',runner='auto'):
 n=safe(name); wine=BASE/n/'prefix'; compat=BASE/n/'compatdata'; wine.mkdir(parents=True,exist_ok=True); compat.mkdir(parents=True,exist_ok=True)
 j=ensure({'schema_version':3,'name':n,'display_name':name,'runner':runner,'arch':'win64','source':source,'main_exe':exe,'installer_exe':'','wine_prefix':str(wine),'proton_compat_data':str(compat),'arguments':'','created_at':datetime.utcnow().isoformat()+'Z','features':{'dxvk':True,'vkd3d':False,'gamemode':True,'mangohud':False,'gamescope':False,'prime':'auto','gamescope_args':'-f -W 1920 -H 1080'},'env':{'WINEESYNC':'1','WINEFSYNC':'1'},'winetricks':['vcrun2019'],'custom_runtimes':[],'installed_runtimes':[]})
 save(pf(n),j); desktop(n,name); return j
def import_steam():
 out=[]; roots=[HOME/'.steam/root/steamapps',HOME/'.local/share/Steam/steamapps']
 for r in list(roots):
  lib=r/'libraryfolders.vdf'
  if lib.exists():
   for p in re.findall(r'"path"\s+"([^"]+)"',lib.read_text(errors='ignore')): roots.append(pathlib.Path(p.replace('\\\\','/'))/'steamapps')
  for a in r.glob('appmanifest_*.acf'):
   t=a.read_text(errors='ignore'); nm=re.search(r'"name"\s+"([^"]+)"',t); inst=re.search(r'"installdir"\s+"([^"]+)"',t)
   if nm: out.append(create(nm.group(1),'','steam','proton'))
 return out
def import_simple(root,source):
 out=[]; root=pathlib.Path(root)
 if root.exists():
  for d in root.iterdir():
   if d.is_dir(): out.append(create(d.name,'',source,'auto'))
 return out
def auto_import(): return import_steam()+import_simple(HOME/'.local/share/bottles/bottles','bottles')+import_simple(HOME/'.var/app/com.usebottles.bottles/data/bottles/bottles','bottles')
def preset(name,val):
 p=pf(name); j=ensure(load(p)); presets={'Low-end':({'dxvk':True,'vkd3d':False,'gamemode':True,'mangohud':False,'gamescope':False},{'WINEESYNC':'1','WINEFSYNC':'0'}),'Balanced':({'dxvk':True,'vkd3d':False,'gamemode':True,'mangohud':False,'gamescope':False},{'WINEESYNC':'1','WINEFSYNC':'1'}),'High performance':({'dxvk':True,'vkd3d':True,'gamemode':True,'mangohud':True,'gamescope':False},{'WINEESYNC':'1','WINEFSYNC':'1','DXVK_HUD':'compiler'}),'DX12 optimized':({'dxvk':True,'vkd3d':True,'gamemode':True,'mangohud':True,'gamescope':False},{'WINEESYNC':'1','WINEFSYNC':'1','VKD3D_CONFIG':'dxr'})}
 f,e=presets.get(val,presets['Balanced']); j['features'].update(f); j['env'].update(e); j['performance_preset']=val; save(p,j); return j
def snapshot(name):
 j=load(pf(name)); pre=pathlib.Path(j.get('wine_prefix','')); out=APPS/safe(name)/'snapshots'; out.mkdir(parents=True,exist_ok=True); arch=out/(datetime.now().strftime('%Y%m%d-%H%M%S')+'.tar.zst')
 if pre.exists(): subprocess.run(['tar','--zstd','-cf',str(arch),'-C',str(pre.parent),pre.name],check=False)
 return str(arch)
def rollback(name):
 j=load(pf(name)); pre=pathlib.Path(j.get('wine_prefix','')); snaps=sorted((APPS/safe(name)/'snapshots').glob('*.tar.zst'))
 if not snaps: raise SystemExit('No snapshot')
 if pre.exists(): shutil.rmtree(pre)
 pre.parent.mkdir(parents=True,exist_ok=True); subprocess.run(['tar','--zstd','-xf',str(snaps[-1]),'-C',str(pre.parent)],check=False); return str(snaps[-1])
def engine(name):
 p=pf(name); j=ensure(load(p)); exe=pathlib.Path(j.get('main_exe','')); root=exe.parent if exe else pathlib.Path('.')
 names=' '.join(x.name.lower() for x in list(root.glob('*'))[:200]) if root.exists() else ''
 eng='unity' if 'unityplayer.dll' in names else ('unreal' if 'ue4' in names or any(root.glob('*.uproject')) else ('emulator' if re.search('rpcs3|pcsx2|yuzu|dolphin',exe.name,re.I) else 'unknown'))
 j['engine']=eng
 if eng=='unity':
  for x in ['vcrun2019','d3dcompiler_47']:
   if x not in j['winetricks']: j['winetricks'].append(x)
 if eng=='unreal':
  for x in ['vcrun2019','d3dcompiler_47']:
   if x not in j['winetricks']: j['winetricks'].append(x)
  j['features']['vkd3d']=True
 if eng=='emulator': j['features'].update({'gamemode':True,'mangohud':True})
 save(p,j); return j
def main(a):
 cmd=a[1] if len(a)>1 else 'help'
 if cmd=='list': print(json.dumps(profiles(),indent=2,ensure_ascii=False))
 elif cmd=='import': print(json.dumps(auto_import(),indent=2,ensure_ascii=False))
 elif cmd=='preset': print(json.dumps(preset(a[2],a[3]),indent=2,ensure_ascii=False))
 elif cmd=='snapshot': print(snapshot(a[2]))
 elif cmd=='rollback': print(rollback(a[2]))
 elif cmd=='plugin-scan': print(json.dumps(engine(a[2]),indent=2,ensure_ascii=False))
 elif cmd=='cache-runtime': print(shutil.copy2(a[2],CACHE/pathlib.Path(a[2]).name))
 else: print('lolios-gaming-advanced list|import|preset NAME PRESET|snapshot NAME|rollback NAME|plugin-scan NAME|cache-runtime FILE')
if __name__=='__main__': main(sys.argv)
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-gaming-advanced"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-gaming-auto-fix" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
NAME="${1:-}"
[ -n "$NAME" ] || { echo "Usage: lolios-gaming-auto-fix PROFILE" >&2; exit 2; }
LOG="$(/usr/local/bin/lolios-exe-launcher --latest-log "$NAME" 2>/dev/null || true)"
[ -f "$LOG" ] || { echo "No log for $NAME" >&2; exit 1; }
SUG="$(/usr/local/bin/lolios-analyze-wine-log "$LOG")"
python3 - "$NAME" "$SUG" <<'PY'
import json,pathlib,sys
name=sys.argv[1]; sug=json.loads(sys.argv[2]).get('suggestions',[])
p=pathlib.Path.home()/'.local/share/lolios/exe-launcher/apps'/name/'profile.json'
j=json.load(open(p))
for s in sug:
 for t in s['suggestion'].split():
  if t=='physx':
   if t not in j.setdefault('custom_runtimes',[]): j['custom_runtimes'].append(t)
  elif t not in ('arch-check','gpu-vulkan'):
   if t not in j.setdefault('winetricks',[]): j['winetricks'].append(t)
json.dump(j,open(p,'w'),indent=2,ensure_ascii=False)
print(json.dumps({'profile':name,'applied':sug},indent=2,ensure_ascii=False))
PY
/usr/local/bin/lolios-exe-launcher --repair --profile "$NAME"
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-gaming-auto-fix"

cat > "$PROFILE/airootfs/usr/share/lolios-gaming/plugins/unity.py" <<'EOF'
ENGINE='unity'
WINETRICKS=['d3dcompiler_47','vcrun2019']
FEATURES={'dxvk': True, 'vkd3d': False}
EOF
cat > "$PROFILE/airootfs/usr/share/lolios-gaming/plugins/unreal.py" <<'EOF'
ENGINE='unreal'
WINETRICKS=['vcrun2019','d3dcompiler_47']
FEATURES={'dxvk': True, 'vkd3d': True}
EOF
cat > "$PROFILE/airootfs/usr/share/lolios-gaming/plugins/emulators.py" <<'EOF'
ENGINE='emulator'
WINETRICKS=[]
FEATURES={'gamemode': True, 'mangohud': True}
EOF
