# Sourced by ../build.sh; group all LoliOS launchers in KDE application menu

log "Writing LoiliOS application menu folder"

APPDIR="$PROFILE/airootfs/usr/share/applications"
MENUDIR="$PROFILE/airootfs/etc/xdg/menus/applications-merged"
DIRDIR="$PROFILE/airootfs/usr/share/desktop-directories"

mkdir -p "$APPDIR" "$MENUDIR" "$DIRDIR"

cat > "$DIRDIR/lolios.directory" <<'EOF'
[Desktop Entry]
Type=Directory
Name=LoiliOS
Comment=LoliOS system tools, compatibility centers and Windows launchers
Icon=applications-games
EOF
chmod 0644 "$DIRDIR/lolios.directory"

cat > "$MENUDIR/lolios-applications.menu" <<'EOF'
<!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN" "http://www.freedesktop.org/standards/menu-spec/1.0/menu.dtd">
<Menu>
  <Name>Applications</Name>
  <Menu>
    <Name>LoiliOS</Name>
    <Directory>lolios.directory</Directory>
    <Include>
      <Category>X-LoiliOS</Category>
    </Include>
  </Menu>
</Menu>
EOF
chmod 0644 "$MENUDIR/lolios-applications.menu"

python3 - "$APPDIR" <<'PY'
from __future__ import annotations
import re
import sys
from pathlib import Path

appdir = Path(sys.argv[1])

# Anything LoliOS-related should be grouped under the LoiliOS folder in KDE menu.
# This includes entries whose visible Name is generic, e.g. "Run Windows Program",
# but whose Exec line calls a lolios-* helper.
def is_lolios_desktop(text: str, path: Path) -> bool:
    lower_text = text.lower()
    lower_name = path.name.lower()
    if "lolios" in lower_text or "loli" in lower_name:
        return True
    if re.search(r"(?im)^exec=.*\blolios[-a-z0-9_]*\b", text):
        return True
    if re.search(r"(?im)^comment=.*loli", text):
        return True
    return False

for desktop in sorted(appdir.glob("*.desktop")):
    try:
        text = desktop.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        text = desktop.read_text(encoding="utf-8", errors="replace")
    if not is_lolios_desktop(text, desktop):
        continue

    lines = text.splitlines()
    out: list[str] = []
    saw_categories = False
    in_desktop_entry = False
    inserted_categories = False

    for line in lines:
        if line.strip() == "[Desktop Entry]":
            in_desktop_entry = True
            out.append(line)
            continue
        if line.startswith("[") and line.endswith("]") and line.strip() != "[Desktop Entry]":
            if in_desktop_entry and not saw_categories and not inserted_categories:
                out.append("Categories=X-LoiliOS;Utility;System;")
                inserted_categories = True
            in_desktop_entry = False
            out.append(line)
            continue
        if in_desktop_entry and line.startswith("Categories="):
            saw_categories = True
            raw = line.split("=", 1)[1]
            cats = [c for c in raw.split(";") if c]
            new = []
            for cat in ["X-LoiliOS", *cats, "Utility"]:
                if cat and cat not in new:
                    new.append(cat)
            out.append("Categories=" + ";".join(new) + ";")
            continue
        out.append(line)

    if in_desktop_entry and not saw_categories and not inserted_categories:
        out.append("Categories=X-LoiliOS;Utility;System;")

    desktop.write_text("\n".join(out).rstrip() + "\n", encoding="utf-8")
    desktop.chmod(0o644)
PY

# Hard checks for user-visible launchers from the menu screenshots.
found=0
while IFS= read -r desktop; do
    if grep -Eq '^(Name=.*LoliOS|Name=Run Windows Program|Exec=.*lolios)' "$desktop" 2>/dev/null; then
        found=$((found + 1))
        grep -q '^Categories=.*X-LoiliOS' "$desktop" || die "LoliOS desktop entry is not in LoiliOS menu category: $desktop"
    fi
done < <(find "$APPDIR" -maxdepth 1 -type f -name '*.desktop' | sort)

[ "$found" -gt 0 ] || die "No LoliOS desktop launchers found to group in LoiliOS menu"

# ------------------------------------------------------------
