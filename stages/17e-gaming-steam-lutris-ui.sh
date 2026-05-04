# Sourced by ../build.sh; Steam-like + Lutris-like LoliOS Gaming Center and EXE file association

log "Writing Steam-like/Lutris-like Gaming Center and EXE double-click integration"

mkdir -p \
  "$PROFILE/airootfs/usr/local/bin" \
  "$PROFILE/airootfs/usr/share/applications" \
  "$PROFILE/airootfs/usr/share/mime/packages" \
  "$PROFILE/airootfs/etc/xdg/lolios"

cat > "$PROFILE/airootfs/usr/local/bin/lolios-exe-open" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
EXE="${1:-}"
[ -n "$EXE" ] && [ -f "$EXE" ] || { kdialog --error "Nie znaleziono pliku EXE: $EXE" 2>/dev/null || echo "Missing EXE: $EXE" >&2; exit 1; }
MODE="run"
if command -v lolios-detect-exe-runtime >/dev/null 2>&1; then
  MODE="$(lolios-detect-exe-runtime "$EXE" 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get("mode_guess","run"))' 2>/dev/null || echo run)"
fi
if command -v kdialog >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
  CHOICE="$(kdialog --title "LoliOS EXE" --menu "$(basename "$EXE")\nWybierz akcję" \
    auto "Auto: instaluj jeśli instalator, inaczej uruchom" \
    run "Uruchom / utwórz profil" \
    install "Instaluj jako aplikację/grę" \
    patch "Patch/update do istniejącego profilu" \
    runtime "Runtime/redist do istniejącego profilu" \
    cancel "Anuluj" 2>/dev/null || true)"
  [ -z "$CHOICE" ] || [ "$CHOICE" = cancel ] && exit 0
else
  CHOICE="auto"
fi
case "$CHOICE" in
  auto) [ "$MODE" = install ] && exec /usr/local/bin/lolios-exe-launcher install "$EXE" || exec /usr/local/bin/lolios-exe-launcher "$EXE" ;;
  run) exec /usr/local/bin/lolios-exe-launcher "$EXE" ;;
  install) exec /usr/local/bin/lolios-exe-launcher install "$EXE" ;;
  patch|runtime)
    PROF="$(/usr/local/bin/lolios-prefix-manager list | awk '{print $1}' | kdialog --combobox "Wybierz profil" 2>/dev/null || true)"
    [ -n "$PROF" ] && exec /usr/local/bin/lolios-exe-launcher "$CHOICE" "$EXE" --profile "$PROF"
    ;;
esac
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-exe-open"

cat > "$PROFILE/airootfs/usr/share/applications/lolios-exe-open.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=LoliOS EXE Launcher
Comment=Open Windows EXE files with LoliOS
Exec=/usr/local/bin/lolios-exe-open %f
Icon=wine
MimeType=application/x-ms-dos-executable;application/x-msdownload;application/vnd.microsoft.portable-executable;
Categories=Game;Utility;
Terminal=false
StartupNotify=true
NoDisplay=true
EOF

cat > "$PROFILE/airootfs/usr/share/mime/packages/lolios-exe.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="application/vnd.microsoft.portable-executable">
    <comment>Windows Portable Executable</comment>
    <glob pattern="*.exe"/>
  </mime-type>
</mime-info>
EOF

cat > "$PROFILE/airootfs/usr/local/bin/lolios-register-exe-handler" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
update-mime-database "$HOME/.local/share/mime" >/dev/null 2>&1 || true
xdg-mime default lolios-exe-open.desktop application/x-ms-dos-executable || true
xdg-mime default lolios-exe-open.desktop application/x-msdownload || true
xdg-mime default lolios-exe-open.desktop application/vnd.microsoft.portable-executable || true
update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
echo "LoliOS EXE double-click handler registered."
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-register-exe-handler"

cat > "$PROFILE/airootfs/etc/xdg/autostart/lolios-register-exe-handler.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=LoliOS Register EXE Handler
Exec=/usr/local/bin/lolios-register-exe-handler
Icon=wine
Terminal=false
NoDisplay=true
X-KDE-autostart-after=panel
EOF

cat > "$PROFILE/airootfs/usr/local/bin/lolios-gaming-center-pro" <<'EOF'
#!/usr/bin/env python3
import json, os, pathlib, subprocess, tkinter as tk
from tkinter import ttk, filedialog, messagebox
LAUNCHER='/usr/local/bin/lolios-exe-launcher'
ADV='/usr/local/bin/lolios-gaming-advanced'
FIX='/usr/local/bin/lolios-gaming-auto-fix'
PM='/usr/local/bin/lolios-prefix-manager'
STATE=pathlib.Path(os.environ.get('LOLIOS_EXE_STATE_DIR', pathlib.Path.home()/'.local/share/lolios/exe-launcher'))
APPS=STATE/'apps'
class Pro(tk.Tk):
    def __init__(self):
        super().__init__(); self.title('LoliOS Gaming Center Pro'); self.geometry('1280x760'); self.profiles=[]; self.filtered=[]; self.build(); self.refresh()
    def cp(self,*a): return subprocess.run(a,text=True,capture_output=True)
    def build(self):
        top=ttk.Frame(self); top.pack(fill=tk.X,padx=10,pady=8)
        ttk.Label(top,text='LoliOS Gaming Center Pro',font=('Sans',16,'bold')).pack(side=tk.LEFT)
        self.search=tk.StringVar(); ttk.Entry(top,textvariable=self.search,width=32).pack(side=tk.LEFT,padx=16); self.search.trace_add('write',lambda *_:self.apply_filter())
        for t,c in [('Import',self.import_all),('Dodaj EXE',self.add_exe),('Instaluj EXE',self.install_exe),('Odśwież',self.refresh)]: ttk.Button(top,text=t,command=c).pack(side=tk.RIGHT,padx=3)
        root=ttk.Panedwindow(self,orient=tk.HORIZONTAL); root.pack(fill=tk.BOTH,expand=True,padx=10,pady=8)
        left=ttk.Frame(root); right=ttk.Frame(root); root.add(left,weight=2); root.add(right,weight=3)
        self.grid=tk.Canvas(left,bg='#202020',highlightthickness=0); self.grid.pack(fill=tk.BOTH,expand=True)
        self.grid.bind('<Configure>',lambda e:self.draw_grid())
        self.grid.bind('<Button-1>',self.click_grid)
        bar=ttk.Frame(left); bar.pack(fill=tk.X,pady=6)
        ttk.Button(bar,text='Uruchom',command=self.run).pack(side=tk.LEFT)
        ttk.Button(bar,text='Auto-fix',command=self.autofix).pack(side=tk.LEFT,padx=4)
        ttk.Button(bar,text='Snapshot',command=self.snapshot).pack(side=tk.LEFT)
        ttk.Button(bar,text='Rollback',command=self.rollback).pack(side=tk.LEFT,padx=4)
        self.sel=None
        details=ttk.Notebook(right); details.pack(fill=tk.BOTH,expand=True)
        tab1=ttk.Frame(details); tab2=ttk.Frame(details); tab3=ttk.Frame(details); tab4=ttk.Frame(details)
        details.add(tab1,text='Profil'); details.add(tab2,text='Wydajność'); details.add(tab3,text='Runtime/Logi'); details.add(tab4,text='JSON')
        self.vars={}
        for i,k in enumerate(['display_name','runner','arch','main_exe','arguments']):
            ttk.Label(tab1,text=k).grid(row=i,column=0,sticky='w',padx=6,pady=4)
            v=tk.StringVar(); self.vars[k]=v; ttk.Entry(tab1,textvariable=v,width=80).grid(row=i,column=1,sticky='we',padx=6,pady=4)
        ttk.Button(tab1,text='Wybierz main_exe',command=self.pick_exe).grid(row=2,column=2,padx=4)
        ttk.Button(tab1,text='Zapisz profil',command=self.save_basic).grid(row=8,column=1,sticky='e',pady=8)
        tab1.columnconfigure(1,weight=1)
        self.preset=tk.StringVar(value='Balanced')
        for p in ['Low-end','Balanced','High performance','DX12 optimized']: ttk.Radiobutton(tab2,text=p,value=p,variable=self.preset).pack(anchor='w',padx=10,pady=4)
        ttk.Button(tab2,text='Zastosuj preset',command=self.apply_preset).pack(anchor='w',padx=10,pady=8)
        self.bools={}
        for k in ['dxvk','vkd3d','gamemode','mangohud','gamescope']:
            b=tk.BooleanVar(); self.bools[k]=b; ttk.Checkbutton(tab2,text=k.upper(),variable=b).pack(anchor='w',padx=10)
        self.launch=tk.StringVar(value='Normal')
        ttk.Label(tab2,text='Launch profile').pack(anchor='w',padx=10,pady=(18,2))
        ttk.Combobox(tab2,textvariable=self.launch,values=['Normal','Safe mode','DX11','DX12','Debug']).pack(anchor='w',padx=10)
        ttk.Button(tab2,text='Uruchom launch profile',command=self.run).pack(anchor='w',padx=10,pady=8)
        self.runtime=tk.Text(tab3,height=8); self.runtime.pack(fill=tk.X,padx=8,pady=8)
        ttk.Button(tab3,text='Plugin scan',command=self.plugin).pack(side=tk.LEFT,padx=8)
        ttk.Button(tab3,text='Otwórz logi',command=self.logs).pack(side=tk.LEFT)
        ttk.Button(tab3,text='Otwórz prefix',command=self.open_prefix).pack(side=tk.LEFT,padx=8)
        self.json=tk.Text(tab4); self.json.pack(fill=tk.BOTH,expand=True)
    def refresh(self):
        cp=self.cp(LAUNCHER,'--list-json')
        try: self.profiles=json.loads(cp.stdout or '[]')
        except Exception: self.profiles=[]
        self.apply_filter()
    def apply_filter(self):
        q=self.search.get().lower(); self.filtered=[p for p in self.profiles if q in (p.get('display_name') or p.get('name','')).lower() or q in p.get('source','').lower()]
        self.draw_grid()
    def draw_grid(self):
        self.grid.delete('all'); w=max(self.grid.winfo_width(),600); cardw=210; cardh=120; pad=14; cols=max(1,w//(cardw+pad)); self.cards=[]
        for i,p in enumerate(self.filtered):
            x=pad+(i%cols)*(cardw+pad); y=pad+(i//cols)*(cardh+pad); name=p.get('display_name') or p.get('name'); runner=p.get('runner','auto'); src=p.get('source','manual')
            fill='#6a3fb5' if self.sel and p.get('name')==self.sel.get('name') else '#333333'
            self.grid.create_rectangle(x,y,x+cardw,y+cardh,fill=fill,outline='#777777',width=2)
            self.grid.create_text(x+12,y+16,text=name,anchor='nw',fill='white',font=('Sans',12,'bold'),width=cardw-24)
            self.grid.create_text(x+12,y+55,text=f'{runner} • {src}',anchor='nw',fill='#dddddd')
            self.grid.create_text(x+12,y+82,text=(p.get('engine') or 'unknown'),anchor='nw',fill='#bbbbbb')
            self.cards.append((x,y,x+cardw,y+cardh,p))
        self.grid.configure(scrollregion=self.grid.bbox('all'))
    def click_grid(self,e):
        for x1,y1,x2,y2,p in getattr(self,'cards',[]):
            if x1<=e.x<=x2 and y1<=e.y<=y2: self.sel=p; self.load_details(); self.draw_grid(); return
    def load_details(self):
        p=self.sel
        if not p: return
        for k,v in self.vars.items(): v.set(str(p.get(k,'')))
        f=p.get('features',{})
        for k,b in self.bools.items(): b.set(bool(f.get(k,False)))
        self.preset.set(p.get('performance_preset','Balanced'))
        self.runtime.delete('1.0',tk.END); self.runtime.insert(tk.END,'Winetricks: '+json.dumps(p.get('winetricks',[]),ensure_ascii=False)+'\nCustom: '+json.dumps(p.get('custom_runtimes',[]),ensure_ascii=False)+'\nEngine: '+str(p.get('engine','unknown')))
        self.json.delete('1.0',tk.END); self.json.insert(tk.END,json.dumps(p,indent=2,ensure_ascii=False))
    def cur(self):
        if not self.sel: messagebox.showwarning('LoliOS','Wybierz grę/profil'); return None
        return self.sel
    def run(self):
        p=self.cur();
        if p: subprocess.Popen([LAUNCHER,'--profile',p['name']])
    def import_all(self): self.cp(ADV,'import'); self.refresh()
    def add_exe(self):
        f=filedialog.askopenfilename(filetypes=[('EXE','*.exe'),('All','*')]);
        if f: subprocess.Popen([LAUNCHER,f])
    def install_exe(self):
        f=filedialog.askopenfilename(filetypes=[('EXE','*.exe'),('All','*')]);
        if f: subprocess.Popen([LAUNCHER,'install',f])
    def save_basic(self):
        p=self.cur();
        if not p: return
        for k in ['runner','arch','main_exe','arguments']: subprocess.run([LAUNCHER,'--set',p['name'],k,self.vars[k].get()])
        for k,b in self.bools.items(): subprocess.run([LAUNCHER,'--set',p['name'],k,'true' if b.get() else 'false'])
        self.refresh()
    def apply_preset(self):
        p=self.cur();
        if p: self.cp(ADV,'preset',p['name'],self.preset.get()); self.refresh()
    def autofix(self):
        p=self.cur();
        if p: subprocess.Popen([FIX,p['name']])
    def snapshot(self):
        p=self.cur();
        if p: messagebox.showinfo('Snapshot',self.cp(ADV,'snapshot',p['name']).stdout.strip())
    def rollback(self):
        p=self.cur();
        if p and messagebox.askyesno('Rollback','Przywrócić ostatni snapshot prefixu?'): messagebox.showinfo('Rollback',self.cp(ADV,'rollback',p['name']).stdout.strip())
    def plugin(self):
        p=self.cur();
        if p: self.cp(ADV,'plugin-scan',p['name']); self.refresh()
    def logs(self):
        p=self.cur();
        if p: subprocess.Popen(['xdg-open',p.get('_logs_dir') or str(APPS/p['name']/ 'logs')])
    def open_prefix(self):
        p=self.cur();
        if p and p.get('wine_prefix'): subprocess.Popen(['xdg-open',p['wine_prefix']])
    def pick_exe(self):
        f=filedialog.askopenfilename(filetypes=[('EXE','*.exe'),('All','*')]);
        if f: self.vars['main_exe'].set(f)
if __name__=='__main__': Pro().mainloop()
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-gaming-center-pro"

cat > "$PROFILE/airootfs/usr/share/applications/lolios-game-center-pro.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=LoliOS Gaming Center Pro
Comment=Steam-like and Lutris-like game library for LoliOS
Exec=/usr/local/bin/lolios-gaming-center-pro
Icon=applications-games
Categories=Game;Utility;
Terminal=false
StartupNotify=true
EOF

cat > "$PROFILE/airootfs/usr/share/applications/lolios-game-center.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=LoliOS Game Center
Comment=Steam-like and Lutris-like game library for LoliOS
Exec=/usr/local/bin/lolios-gaming-center-pro
Icon=applications-games
Categories=Game;Utility;
Terminal=false
StartupNotify=true
EOF
