# Sourced by ../build.sh; remove Live installer components from installed systems

log "Writing installed-system Calamares removal"

POSTINSTALL="$PROFILE/airootfs/root/postinstall.sh"
[ -f "$POSTINSTALL" ] || die "postinstall.sh missing before Calamares removal hardening"

python3 - "$POSTINSTALL" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()

function = r'''
remove_live_installer_from_installed_system() {
    echo "[LOLIOS] removing Calamares and Live installer components from installed system"

    # Calamares is needed in Live ISO only. The installed system must not keep
    # the installer package, its configuration, or installer launchers.
    if command -v pacman >/dev/null 2>&1 && pacman -Q calamares >/dev/null 2>&1; then
        pacman -Rns --noconfirm calamares 2>/dev/null || pacman -Rdd --noconfirm calamares 2>/dev/null || true
    fi

    rm -rf \
        /etc/calamares \
        /usr/share/calamares \
        /usr/lib/calamares \
        /var/log/calamares \
        2>/dev/null || true

    rm -f \
        /usr/bin/calamares \
        /usr/local/bin/lolios-installer \
        /usr/share/applications/calamares.desktop \
        /usr/share/applications/lolios-installer.desktop \
        /etc/xdg/autostart/calamares.desktop \
        /etc/xdg/autostart/lolios-installer.desktop \
        2>/dev/null || true

    find /home /root /etc/skel -maxdepth 4 -type f \
        \( -name 'calamares.desktop' -o -name 'lolios-installer.desktop' \) \
        -delete 2>/dev/null || true
}
'''

if "remove_live_installer_from_installed_system()" not in text:
    marker = "cleanup_live_only_files() {\n"
    idx = text.find(marker)
    if idx == -1:
        raise SystemExit("cleanup_live_only_files function not found")
    text = text[:idx] + function + "\n" + text[idx:]

call = "remove_live_installer_from_installed_system\n"
if call not in text:
    marker = "cleanup_live_only_files\n"
    if marker in text:
        text = text.replace(marker, marker + call, 1)
    else:
        marker = "configure_offline_local_repo\n"
        if marker not in text:
            raise SystemExit("postinstall call site not found")
        text = text.replace(marker, marker + call, 1)

# Strengthen final sanity check without replacing the whole generated postinstall.
sanities = {
    'pacman -Q calamares': 'pacman -Q calamares >/dev/null 2>&1 && fail "Final sanity: Calamares package is still installed."\n',
    '[ ! -e /etc/calamares ]': '[ ! -e /etc/calamares ] || fail "Final sanity: /etc/calamares still exists."\n',
    '[ ! -e /usr/bin/calamares ]': '[ ! -e /usr/bin/calamares ] || fail "Final sanity: /usr/bin/calamares still exists."\n',
    '[ ! -e /usr/share/applications/lolios-installer.desktop ]': '[ ! -e /usr/share/applications/lolios-installer.desktop ] || fail "Final sanity: lolios-installer.desktop still exists."\n',
}
insert_after = '    [ -s /boot/grub/grub.cfg ] || fail "Final sanity: grub.cfg missing or empty."\n'
if insert_after in text:
    extra = "".join(line for key, line in sanities.items() if key not in text)
    text = text.replace(insert_after, insert_after + extra, 1)

path.write_text(text)
PY

# ------------------------------------------------------------
