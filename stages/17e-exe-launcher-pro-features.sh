# Sourced by ../build.sh; pro compatibility helpers
#
# Canonical runtime binaries are maintained in src/bin and installed by
# stages/17z-install-src-gaming-tools.sh.  This stage intentionally provides
# only data files and helper tools that are not owned by src/bin.

log "Writing LoliOS pro EXE compatibility helper data/tools"

mkdir -p "$PROFILE/airootfs/usr/local/bin" "$PROFILE/airootfs/etc/lolios" "$PROFILE/airootfs/usr/share/applications"

cat > "$PROFILE/airootfs/etc/lolios/gaming.conf" <<'EOF'
prefix_base=$HOME/Games/LoliOS
default_runner=auto
default_arch=win64
default_preset=modern
keep_logs_days=14
runtime_policy=missing-only
EOF

cat > "$PROFILE/airootfs/usr/local/bin/lolios-runner-manager" <<'EOF'
#!/usr/bin/env python3
import glob, json, os, shutil, sys

def rows():
    out=[]
    patterns=[
        '~/.steam/root/compatibilitytools.d/*/proton',
        '~/.steam/steam/compatibilitytools.d/*/proton',
        '~/.local/share/Steam/compatibilitytools.d/*/proton',
        '~/.steam/root/steamapps/common/Proton*/proton',
        '~/.local/share/Steam/steamapps/common/Proton*/proton',
    ]
    for pat in patterns:
        for p in glob.glob(os.path.expanduser(pat)):
            if os.access(p, os.X_OK):
                name=os.path.basename(os.path.dirname(p))
                score=150 if 'ge' in name.lower() else 125
                out.append({'type':'proton','name':name,'path':p,'score':score})
    for b,s in [('wine',100),('wine64',90)]:
        p=shutil.which(b)
        if p: out.append({'type':'wine','name':b,'path':p,'score':s})
    return sorted(out, key=lambda x:x['score'], reverse=True)

mode=sys.argv[1] if len(sys.argv)>1 else 'list'
r=rows()
if mode=='json': print(json.dumps(r,indent=2,ensure_ascii=False))
elif mode=='best':
    kind=sys.argv[2] if len(sys.argv)>2 else 'auto'
    filt=[x for x in r if kind=='auto' or x['type']==kind]
    print(json.dumps((filt or r or [{}])[0], ensure_ascii=False))
else:
    for x in r: print(f"{x['type']}\t{x['name']}\t{x['score']}\t{x['path']}")
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-runner-manager"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-compat-presets" <<'EOF'
#!/usr/bin/env python3
import json, sys
presets={
 'modern': {'runner':'auto','arch':'win64','winetricks':['vcrun2019'],'features':{'dxvk':True,'vkd3d':False,'gamemode':True,'mangohud':False,'gamescope':False},'env':{'WINEESYNC':'1','WINEFSYNC':'1'}},
 'dx12': {'runner':'auto','arch':'win64','winetricks':['vcrun2019','d3dcompiler_47'],'features':{'dxvk':True,'vkd3d':True,'gamemode':True,'mangohud':False,'gamescope':False},'env':{'WINEESYNC':'1','WINEFSYNC':'1'}},
 'legacy': {'runner':'wine','arch':'win32','winetricks':['vcrun2010','vcrun2012','vcrun2013','d3dx9','xact','xinput'],'features':{'dxvk':True,'vkd3d':False,'gamemode':True,'mangohud':False,'gamescope':False},'env':{'WINEESYNC':'0','WINEFSYNC':'0'}},
 'launcher': {'runner':'wine','arch':'win64','winetricks':['vcrun2019','dotnet48'],'features':{'dxvk':True,'vkd3d':False,'gamemode':False,'mangohud':False,'gamescope':False},'env':{'WINEESYNC':'1','WINEFSYNC':'1'}},
 'debug': {'runner':'wine','arch':'win64','winetricks':['vcrun2019'],'features':{'dxvk':True,'vkd3d':False,'gamemode':False,'mangohud':True,'gamescope':False},'env':{'WINEDEBUG':'warn+all','WINEESYNC':'1','WINEFSYNC':'1'}},
}
name=sys.argv[1] if len(sys.argv)>1 else 'list'
if name=='list': print('\n'.join(presets))
elif name in presets: print(json.dumps(presets[name],indent=2,ensure_ascii=False))
else:
    print('Unknown preset', file=sys.stderr); sys.exit(2)
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-compat-presets"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-exe-preflight" <<'EOF'
#!/usr/bin/env python3
import json, os, shutil, subprocess, sys
profile=''; exe=''
args=sys.argv[1:]
i=0
while i < len(args):
    if args[i]=='--profile' and i+1 < len(args): profile=args[i+1]; i+=2
    elif args[i]=='--exe' and i+1 < len(args): exe=args[i+1]; i+=2
    else: exe=args[i]; i+=1
checks=[]
def add(name, ok, detail=''): checks.append({'check':name,'ok':bool(ok),'detail':str(detail)})
for b in ['wine','winetricks','gamemoderun','mangohud','gamescope']:
    add(b, shutil.which(b), shutil.which(b) or 'missing/optional')
if exe: add('exe_exists', os.path.isfile(exe), exe)
if profile:
    pf=os.path.expanduser(f'~/.local/share/lolios/exe-launcher/apps/{profile}/profile.json')
    add('profile_exists', os.path.isfile(pf), pf)
    if os.path.isfile(pf):
        try:
            j=json.load(open(pf)); add('main_exe', os.path.isfile(j.get('main_exe','')), j.get('main_exe',''))
            add('wine_prefix', bool(j.get('wine_prefix') or j.get('prefix')), j.get('wine_prefix') or j.get('prefix'))
        except Exception as e: add('profile_json', False, e)
try:
    r=subprocess.run(['bash','-lc','command -v vulkaninfo >/dev/null && vulkaninfo --summary | head -20'],text=True,capture_output=True,timeout=8)
    add('vulkan', r.returncode==0, (r.stdout or r.stderr)[:400])
except Exception as e: add('vulkan', False, e)
print(json.dumps({'ok':all(c['ok'] or c['check'] in ['gamemoderun','mangohud','gamescope'] for c in checks),'checks':checks},indent=2,ensure_ascii=False))
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-exe-preflight"

cat > "$PROFILE/airootfs/usr/share/applications/lolios-runner-manager.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=LoliOS Runner Manager
Comment=List available Wine and Proton runners
Exec=konsole -e /usr/local/bin/lolios-runner-manager list
Icon=applications-games
Categories=Game;Utility;
Terminal=false
StartupNotify=true
EOF
