# Sourced by ../build.sh; group all LoliOS launchers into one KDE menu folder

log "Writing LoliOS application menu folder"

APPDIR="$PROFILE/airootfs/usr/share/applications"
MENUDIR="$PROFILE/airootfs/etc/xdg/menus/applications-merged"
mkdir -p "$APPDIR" "$MENUDIR"

# KDE/xdg menu definition. Every desktop file with Category=LoliOS appears in
# one visible folder named LoliOS. This affects both Live ISO and installed system
# because the file is part of airootfs and is copied by Calamares unpackfs.
cat > "$MENUDIR/lolios.menu" <<'EOF'
<!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
 "http://www.freedesktop.org/standards/menu-spec/1.0/menu.dtd">
<Menu>
  <Name>Applications</Name>
  <Menu>
    <Name>LoliOS</Name>
    <Directory>lolios.directory</Directory>
    <Include>
      <Category>LoliOS</Category>
    </Include>
  </Menu>
</Menu>
EOF
chmod 0644 "$MENUDIR/lolios.menu"

mkdir -p "$PROFILE/airootfs/usr/share/desktop-directories"
cat > "$PROFILE/airootfs/usr/share/desktop-directories/lolios.directory" <<'EOF'
[Desktop Entry]
Type=Directory
Name=LoliOS
Comment=LoliOS tools and compatibility launchers
Icon=applications-games
EOF
chmod 0644 "$PROFILE/airootfs/usr/share/desktop-directories/lolios.directory"

# Normalize every LoliOS-related desktop file into the LoliOS category. This
# catches files named lolios-*.desktop and visible names containing LoliOS, plus
# compatibility entries such as "Run Windows Program" that launch LoliOS tools.
python3 - "$APPDIR" <<'PY'
from pathlib import Path
import re
import sys

appdir = Path(sys.argv[1])
if not appdir.exists():
    raise SystemExit(0)

lolios_exec_markers = (
    "lolios-",
    "/usr/local/bin/lolios-",
)

for path in sorted(appdir.glob("*.desktop")):
    text = path.read_text(errors="replace")
    lowered = (path.name + "\n" + text).lower()
    is_lolios = "lolios" in lowered or any(marker in lowered for marker in lolios_exec_markers)
    if not is_lolios:
        continue

    lines = text.splitlines()
    out = []
    seen_categories = False
    for line in lines:
        if line.startswith("Categories="):
            seen_categories = True
            cats = [c for c in line.split("=", 1)[1].split(";") if c]
            normalized = []
            for cat in ["LoliOS", *cats]:
                if cat not in normalized:
                    normalized.append(cat)
            out.append("Categories=" + ";".join(normalized) + ";")
        else:
            out.append(line)
    if not seen_categories:
        out.append("Categories=LoliOS;Utility;")
    new = "\n".join(out) + "\n"
    path.write_text(new)
    path.chmod(0o644)
PY

# Sanity: all lolios-related desktop files must carry the category.
while IFS= read -r desktop; do
    [ -f "$desktop" ] || continue
    if grep -Eiq 'lolios|/usr/local/bin/lolios-' "$desktop" || printf '%s\n' "$(basename "$desktop")" | grep -Eiq 'lolios'; then
        grep -q '^Categories=.*LoliOS' "$desktop" || die "LoliOS desktop entry is not in LoliOS menu category: $desktop"
    fi
done < <(find "$APPDIR" -maxdepth 1 -type f -name '*.desktop' 2>/dev/null | sort)

# ------------------------------------------------------------
