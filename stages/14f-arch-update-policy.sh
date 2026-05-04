# Sourced by ../build.sh; keep installed LoliOS on normal Arch update channels

log "Writing installed-system Arch update policy"

POSTINSTALL="$PROFILE/airootfs/root/postinstall.sh"
[ -f "$POSTINSTALL" ] || die "postinstall.sh missing before Arch update policy hardening"

python3 - "$POSTINSTALL" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()

function = r'''
remove_lolios_local_repo_from_pacman_conf() {
    echo "[LOLIOS] enforcing Arch update policy in pacman.conf"
    local conf="/etc/pacman.conf" tmp
    [ -f "$conf" ] || return 0
    tmp="$(mktemp)"
    awk '
BEGIN { in_lolios=0 }
/^\[lolios-local\]$/ { in_lolios=1; next }
in_lolios && /^\[/ { in_lolios=0; print; next }
in_lolios { next }
{ print }
' "$conf" > "$tmp"
    install -m 0644 "$tmp" "$conf"
    rm -f "$tmp"

    # Keep a disabled helper snippet for manual offline rescue only. It must not
    # be included by pacman.conf during normal installed-system updates.
    mkdir -p /etc/pacman.d
    cat > /etc/pacman.d/lolios-local.conf.disabled <<'EOF_DISABLED'
# Manual offline rescue repository for LoliOS images.
# Do not include this file for normal system updates.
[lolios-local]
SigLevel = Optional TrustAll
Server = file:///opt/lolios/repo
EOF_DISABLED
}
'''

if "remove_lolios_local_repo_from_pacman_conf()" not in text:
    marker = "remove_legacy_lolios_kde_noextract() {\n"
    idx = text.find(marker)
    if idx == -1:
        raise SystemExit("remove_legacy_lolios_kde_noextract function not found")
    text = text[:idx] + function + "\n" + text[idx:]

call = "remove_lolios_local_repo_from_pacman_conf\n"
if call not in text:
    marker = "remove_legacy_lolios_kde_noextract\n"
    if marker in text:
        text = text.replace(marker, marker + call, 1)
    else:
        marker = "configure_offline_local_repo\n"
        if marker not in text:
            raise SystemExit("postinstall call site not found")
        text = text.replace(marker, marker + call, 1)

sanity = '    ! grep -q "^\\[lolios-local\\]" /etc/pacman.conf 2>/dev/null || fail "Final sanity: lolios-local repo is still enabled in installed pacman.conf."\n'
insert_after = '    ! grep -R \'^NoExtract = usr/share/plasma/look-and-feel/org\\.kde\\.\\*\' /etc/pacman.conf 2>/dev/null || fail "Final sanity: legacy KDE theme NoExtract still blocks upstream KDE themes."\n'
if "lolios-local repo is still enabled" not in text:
    if insert_after in text:
        text = text.replace(insert_after, insert_after + sanity, 1)
    else:
        marker = '    echo "[LOLIOS] final installed-system sanity check passed"\n'
        text = text.replace(marker, sanity + marker, 1)

path.write_text(text)
PY

# ------------------------------------------------------------
