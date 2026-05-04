# Sourced by ../build.sh; harden postinstall edge cases discovered during Calamares review

log "Hardening Calamares postinstall edge cases"

POSTINSTALL="$PROFILE/airootfs/root/postinstall.sh"
[ -f "$POSTINSTALL" ] || die "postinstall missing before Calamares safety hardening: $POSTINSTALL"

python3 - "$POSTINSTALL" <<'PY'
from pathlib import Path
import re
import sys
path = Path(sys.argv[1])
text = path.read_text()

# mount_esp_from_fstab/find_efi_dir may run inside command substitutions.
# Any discovery log must go to stderr; otherwise variables such as efi_dir can
# receive log text instead of only the selected mount path.
text = re.sub(
    r'(echo "\[LOLIOS\] mounting [^"]*ESP from fstab at \$mp")(?!\s*>\&2)',
    r'\1 >&2',
    text,
)
path.write_text(text)
PY

# Fail only if an ESP mount discovery echo still writes to stdout. The exact log
# wording has changed over time, so use a pattern instead of a brittle full string.
if grep -Eq 'echo "\[LOLIOS\] mounting [^"]*ESP from fstab at \$mp"[[:space:]]*$' "$POSTINSTALL"; then
    die "postinstall still logs ESP mount discovery to stdout; this breaks find_efi_dir"
fi

if grep -Eq 'echo "\[LOLIOS\] mounting [^"]*ESP from fstab at \$mp"[[:space:]]*>&2' "$POSTINSTALL" || \
   grep -Eq 'echo "\[LOLIOS\] mounting [^"]*ESP from fstab at \$mp"[[:space:]]*>\&2' "$POSTINSTALL"; then
    :
else
    warn "postinstall has no ESP mount discovery log to redirect; continuing"
fi

cat > "$PROFILE/airootfs/usr/local/bin/lolios-calamares-diagnose" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

echo "== LoliOS Calamares installed-system diagnostics =="
echo "-- users --"
awk -F: '$3 >= 1000 && $3 < 60000 {print $1 ":uid=" $3 ":home=" $6 ":shell=" $7}' /etc/passwd || true

echo "-- live remnants --"
getent passwd live || true
find /etc/sddm.conf.d -maxdepth 1 -type f -print 2>/dev/null | sort || true
grep -R "live\|Autologin\|User=" /etc/sddm.conf /etc/sddm.conf.d 2>/dev/null || true

echo "-- calamares logs --"
for log in /var/log/lolios-calamares-user-check.log /var/log/lolios-postinstall.log /var/log/calamares/calamares.log; do
  [ -f "$log" ] && echo "present: $log" || echo "missing: $log"
done

echo "-- boot --"
findmnt /boot 2>/dev/null || true
findmnt /boot/efi 2>/dev/null || true
findmnt /efi 2>/dev/null || true
ls -la /boot 2>/dev/null || true
ls -la /boot/EFI /boot/efi/EFI /efi/EFI 2>/dev/null || true

echo "-- mkinitcpio --"
ls -la /etc/mkinitcpio.d 2>/dev/null || true
ls -la /boot/initramfs-* /boot/vmlinuz-* 2>/dev/null || true
EOF
chmod +x "$PROFILE/airootfs/usr/local/bin/lolios-calamares-diagnose"

# ------------------------------------------------------------
