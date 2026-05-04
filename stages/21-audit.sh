# Sourced by ../build.sh; original section: 21. Audit

# 21. Audit
# ------------------------------------------------------------

log "Running project audit"

FAIL=0

audit_ok() { echo "OK: $*"; }
audit_bad() { echo "BAD: $*"; FAIL=1; }
audit_pkg_present() { local pkg="$1"; grep -qxF "$pkg" "$PROFILE/packages.x86_64" && audit_ok "package present: $pkg" || audit_bad "package missing: $pkg"; }
audit_pkg_absent() { local pkg="$1"; grep -qxF "$pkg" "$PROFILE/packages.x86_64" && audit_bad "unwanted package present: $pkg" || audit_ok "package absent: $pkg"; }
audit_file() { local file="$1"; [ -f "$file" ] && audit_ok "file exists: $file" || audit_bad "file missing: $file"; }
audit_dir() { local dir="$1"; [ -d "$dir" ] && audit_ok "directory exists: $dir" || audit_bad "directory missing: $dir"; }
audit_exec() { local file="$1"; [ -x "$file" ] && audit_ok "executable: $file" || audit_bad "not executable: $file"; }
audit_grep() { local pattern="$1" file="$2" label="$3"; grep -q -- "$pattern" "$file" 2>/dev/null && audit_ok "$label" || audit_bad "$label"; }
audit_not_grep() { local pattern="$1" file="$2" label="$3"; grep -q -- "$pattern" "$file" 2>/dev/null && audit_bad "$label" || audit_ok "$label"; }

if [ -f "$LOLIOS_PROJECT_ROOT/tests/test-gaming-tools.sh" ]; then
    if bash "$LOLIOS_PROJECT_ROOT/tests/test-gaming-tools.sh"; then audit_ok "gaming/app tools repository tests passed"; else audit_bad "gaming/app tools repository tests failed"; fi
else
    audit_bad "gaming/app tools repository test script missing"
fi

for pkg in linux-zen nvidia-utils lib32-nvidia-utils plasma-workspace sddm systemsettings steam lutris bottles protontricks gamescope gamemode lib32-gamemode mangohud lib32-mangohud; do audit_pkg_present "$pkg"; done
if [ "${LOLIOS_FLAVOR:-full}" = "full" ]; then for pkg in linux-zen-headers linux-lts linux-lts-headers nvidia-dkms; do audit_pkg_present "$pkg"; done; fi
if local_repo_has_pkg bottles; then audit_ok "local-repo package present: bottles"; else audit_bad "local-repo package missing: bottles"; fi
if [ -n "$PREBUILT_REPO_DIR" ] || [ "$USE_AUR_FALLBACK" = "1" ]; then
    for pkg in heroic-games-launcher-bin protonup-qt-bin proton-ge-custom-bin pycharm-community-jre rustdesk-bin onlyoffice-bin yay; do grep -qxF "$pkg" "$PROFILE/packages.x86_64" && audit_ok "local-repo package present: $pkg" || warn "local-repo package not present: $pkg"; done
else
    audit_ok "AUR-only optional packages may be intentionally removed"
fi
for pkg in nvidia wine-staging wine-ge-custom archiso-calamares-config calamares-settings-arch plasma-wayland-session mintstick flatpak flatpak-kcm game-devices-udev input-remapper lact plasma-workspace-lolios; do audit_pkg_absent "$pkg"; done

audit_dir "$PROFILE/airootfs/usr/share/plasma/look-and-feel/org.lolios.desktop"
audit_file "$PROFILE/airootfs/usr/share/plasma/look-and-feel/org.lolios.desktop/metadata.json"
audit_file "$PROFILE/airootfs/usr/share/plasma/look-and-feel/org.lolios.desktop/contents/defaults"
audit_file "$PROFILE/airootfs/usr/share/plasma/desktoptheme/LoliOS/metadata.json"
audit_file "$PROFILE/airootfs/usr/share/color-schemes/LoliOSCandy.colors"
audit_file "$PROFILE/airootfs/usr/share/icons/LoliOS/index.theme"
audit_file "$PROFILE/airootfs/etc/skel/.config/kdeglobals"
audit_file "$PROFILE/airootfs/root/.config/kdeglobals"
audit_file "$PROFILE/airootfs/etc/sddm.conf.d/10-lolios-theme.conf"

audit_not_grep '^NoExtract = usr/share/plasma/look-and-feel/org.kde\.\*' "$PROFILE/pacman.conf" "pacman does not block upstream KDE Global Themes"
audit_not_grep '^NoExtract = usr/share/plasma/desktoptheme/breeze/' "$PROFILE/pacman.conf" "pacman does not block Breeze desktop theme"
audit_not_grep '^NoExtract = usr/share/sddm/themes/breeze/' "$PROFILE/pacman.conf" "pacman does not block Breeze SDDM theme"
if find "$PROFILE/airootfs/usr/share/plasma/look-and-feel" -mindepth 1 -maxdepth 1 -type d -name 'org.kde.*' 2>/dev/null | grep -q .; then audit_ok "upstream KDE Global Theme folders are allowed in airootfs overlay"; else warn "upstream KDE Global Theme folders not present in overlay; they may still be package-owned in final airootfs"; fi
for packaged_icon_theme in breeze breeze-dark hicolor Adwaita gnome; do [ -e "$PROFILE/airootfs/usr/share/icons/$packaged_icon_theme" ] && audit_ok "package-owned icon theme allowed in overlay: /usr/share/icons/$packaged_icon_theme" || warn "package-owned icon theme not present in overlay: /usr/share/icons/$packaged_icon_theme"; done

audit_grep '^Inherits=.*breeze-dark.*breeze.*hicolor' "$PROFILE/airootfs/usr/share/icons/LoliOS/index.theme" "LoliOS icon theme inherits Breeze fallback"
audit_grep '^Theme=LoliOS' "$PROFILE/airootfs/etc/skel/.config/kdeglobals" "skel KDE icon theme is LoliOS"
audit_grep '^Theme=LoliOS' "$PROFILE/airootfs/root/.config/kdeglobals" "root KDE icon theme is LoliOS"
audit_grep '^Theme=LoliOS' "$PROFILE/airootfs/etc/xdg/kdeglobals" "system KDE icon theme is LoliOS"
ICON_FILE_COUNT="$(find "$PROFILE/airootfs/usr/share/icons/LoliOS" -type f \( -iname '*.svg' -o -iname '*.svgz' -o -iname '*.png' -o -iname '*.xpm' \) 2>/dev/null | wc -l)"
[ "$ICON_FILE_COUNT" -gt 0 ] && audit_ok "LoliOS icon theme contains icon files: $ICON_FILE_COUNT" || audit_bad "LoliOS icon theme contains no real icon files"

audit_file "$PROFILE/airootfs/etc/skel/.config/plasma-org.kde.plasma.desktop-appletsrc"
for marker in org.kde.plasma.kickoff org.kde.plasma.icontasks org.kde.plasma.systemtray org.kde.plasma.digitalclock; do audit_grep "$marker" "$PROFILE/airootfs/etc/skel/.config/plasma-org.kde.plasma.desktop-appletsrc" "Plasma layout contains $marker"; done

audit_exec "$PROFILE/airootfs/usr/local/bin/lolios-session-init"
audit_exec "$PROFILE/airootfs/usr/local/bin/lolios-activate-kde-theme"
audit_grep '--resetLayout' "$PROFILE/airootfs/usr/local/bin/lolios-session-init" "first-run session init resets desktop layout"
audit_grep 'lolios-ensure-plasma-panel' "$PROFILE/airootfs/usr/local/bin/lolios-session-init" "session init ensures Plasma panel"

audit_file "$PROFILE/airootfs/etc/calamares/settings.conf"
audit_file "$PROFILE/airootfs/etc/calamares/modules/bootloader.conf"
audit_file "$PROFILE/airootfs/etc/calamares/modules/users.conf"
audit_file "$PROFILE/airootfs/etc/calamares/modules/welcome.conf"
audit_file "$PROFILE/airootfs/etc/calamares/modules/partition.conf"
audit_file "$PROFILE/airootfs/etc/calamares/modules/shellprocess.conf"
audit_exec "$PROFILE/airootfs/root/lolios-calamares-user-check.sh"
grep -q '/boot/vmlinuz-linux-zen' "$PROFILE/airootfs/etc/calamares/modules/bootloader.conf" && audit_ok "Calamares uses linux-zen kernel" || audit_bad "Calamares uses linux-zen kernel"
grep -q '/boot/initramfs-linux-zen.img' "$PROFILE/airootfs/etc/calamares/modules/bootloader.conf" && audit_ok "Calamares uses linux-zen initramfs" || audit_bad "Calamares uses linux-zen initramfs"
audit_grep '^[[:space:]]*requiredStorage:[[:space:]]*[0-9][0-9]*' "$PROFILE/airootfs/etc/calamares/modules/welcome.conf" "Calamares welcome storage requirement exists"
audit_grep '^[[:space:]]*requiredStorage:[[:space:]]*[0-9][0-9]*' "$PROFILE/airootfs/etc/calamares/modules/partition.conf" "Calamares partition storage requirement exists"
audit_grep '^allowEmptyPassword:[[:space:]]*false' "$PROFILE/airootfs/etc/calamares/modules/users.conf" "Calamares disallows empty user password"
audit_grep '^allowWeakPassword:[[:space:]]*false' "$PROFILE/airootfs/etc/calamares/modules/users.conf" "Calamares disallows weak user password"
audit_grep '^passwordRequired:[[:space:]]*true' "$PROFILE/airootfs/etc/calamares/modules/users.conf" "Calamares requires user password"
audit_grep '^requirePassword:[[:space:]]*true' "$PROFILE/airootfs/etc/calamares/modules/users.conf" "Calamares compatibility password requirement"
audit_grep '^doAutologin:[[:space:]]*false' "$PROFILE/airootfs/etc/calamares/modules/users.conf" "Calamares does not write its own autologin"
audit_grep '/bin/bash /root/lolios-calamares-user-check.sh' "$PROFILE/airootfs/etc/calamares/modules/shellprocess.conf" "Calamares validates installed user through bash before postinstall"
audit_grep '/bin/bash /root/postinstall.sh' "$PROFILE/airootfs/etc/calamares/modules/shellprocess.conf" "Calamares runs postinstall through bash"
python3 - "$PROFILE/airootfs/etc/calamares/modules/shellprocess.conf" <<'PY'
import sys
text=open(sys.argv[1], encoding='utf-8').read()
a=text.find('/bin/bash /root/lolios-calamares-user-check.sh')
b=text.find('/bin/bash /root/postinstall.sh')
raise SystemExit(0 if a != -1 and b != -1 and a < b else 1)
PY
[ "$?" -eq 0 ] && audit_ok "Calamares shellprocess order is user-check before postinstall" || audit_bad "Calamares shellprocess order is invalid"
audit_grep 'locked or empty password hash' "$PROFILE/airootfs/root/lolios-calamares-user-check.sh" "Calamares user check rejects empty password hashes"
audit_grep 'usermod -aG wheel' "$PROFILE/airootfs/root/lolios-calamares-user-check.sh" "Calamares user check ensures wheel membership"

grep -q 'rm -f /etc/sudoers.d/99-lolios-live' "$PROFILE/airootfs/root/postinstall.sh" && audit_ok "postinstall removes live sudo rules" || audit_bad "postinstall removes live sudo rules"
grep -q 'rm -f /etc/polkit-1/rules.d/49-lolios-live-admin.rules' "$PROFILE/airootfs/root/postinstall.sh" && audit_ok "postinstall removes live polkit rules" || audit_bad "postinstall removes live polkit rules"
audit_grep 'remove_legacy_lolios_kde_noextract' "$PROFILE/airootfs/root/postinstall.sh" "postinstall removes legacy KDE theme NoExtract rules"
audit_grep 'installed_sanity_check' "$PROFILE/airootfs/root/postinstall.sh" "postinstall has final installed sanity check"
audit_grep 'Final sanity: live user still exists' "$PROFILE/airootfs/root/postinstall.sh" "postinstall rejects remaining live user"
audit_grep 'Final sanity: /etc/lolios-live still exists' "$PROFILE/airootfs/root/postinstall.sh" "postinstall rejects remaining live marker"
audit_grep 'User=live' "$PROFILE/airootfs/root/postinstall.sh" "postinstall rejects SDDM User=live"
audit_grep 'cleanup_sddm_fragments' "$PROFILE/airootfs/root/postinstall.sh" "postinstall cleans SDDM fragments broadly"
audit_grep '\*calamares\*' "$PROFILE/airootfs/root/postinstall.sh" "postinstall removes Calamares SDDM fragments"
audit_grep '\*displaymanager\*' "$PROFILE/airootfs/root/postinstall.sh" "postinstall removes displaymanager SDDM fragments"
audit_grep 'is_valid_esp' "$PROFILE/airootfs/root/postinstall.sh" "postinstall validates ESP filesystem"
audit_grep 'FAT/vfat' "$PROFILE/airootfs/root/postinstall.sh" "postinstall requires FAT/vfat ESP"
audit_grep 'validate_mkinitcpio_presets' "$PROFILE/airootfs/root/postinstall.sh" "postinstall validates mkinitcpio presets"
audit_grep 'points to unreadable kernel' "$PROFILE/airootfs/root/postinstall.sh" "postinstall rejects unreadable mkinitcpio kernels"

for file in \
    "$PROFILE/airootfs/usr/local/bin/lolios-installer" "$PROFILE/airootfs/usr/local/bin/lolios-exe-runner" "$PROFILE/airootfs/usr/local/bin/lolios-exe-launcher" "$PROFILE/airootfs/usr/local/bin/lolios-profile" "$PROFILE/airootfs/usr/local/bin/lolios-gaming-center" "$PROFILE/airootfs/usr/local/bin/lolios-app-center" "$PROFILE/airootfs/usr/local/bin/lolios-guard-status" "$PROFILE/airootfs/usr/local/bin/lolios-gaming-doctor" "$PROFILE/airootfs/usr/local/bin/lolios-gpu-profile" "$PROFILE/airootfs/usr/local/bin/lolios-update" "$PROFILE/airootfs/usr/local/bin/lolios-repair-installed-system" "$PROFILE/airootfs/usr/local/bin/lolios-set-wallpaper" "$PROFILE/airootfs/usr/local/bin/lolios-apply-kde-theme" "$PROFILE/airootfs/usr/local/bin/lolios-start-center" "$PROFILE/airootfs/usr/local/bin/lolios-live-doctor" "$PROFILE/airootfs/usr/local/bin/lolios-installed-doctor" "$PROFILE/airootfs/usr/local/bin/lolios-first-login-setup" "$PROFILE/airootfs/usr/local/bin/lolios-session-mode" "$PROFILE/airootfs/usr/local/bin/lolios-repair-tool-permissions" "$PROFILE/airootfs/root/postinstall.sh"
 do audit_exec "$file"; done

audit_file "$PROFILE/airootfs/usr/lib/lolios/lolios_guard.py"
audit_file "$PROFILE/airootfs/usr/share/lolios/product.json"
audit_grep '"id": "lolios"' "$PROFILE/airootfs/usr/share/lolios/product.json" "LoliOS product marker id"
audit_grep '"name": "LoliOS"' "$PROFILE/airootfs/usr/share/lolios/product.json" "LoliOS product marker name"
audit_grep 'lolios-gaming-center' "$PROFILE/airootfs/usr/share/lolios/product.json" "LoliOS product marker lists Game Center"
audit_grep 'lolios-app-center' "$PROFILE/airootfs/usr/share/lolios/product.json" "LoliOS product marker lists App Center"
LOLIOS_ROOT="$PROFILE/airootfs" PYTHONPATH="$PROFILE/airootfs/usr/lib/lolios" python3 "$PROFILE/airootfs/usr/lib/lolios/lolios_guard.py" >/dev/null 2>&1 && audit_ok "LoliOS guard status passes in ISO profile" || audit_bad "LoliOS guard status fails in ISO profile"

[ -f "$PROFILE/airootfs$WALL_ISO" ] && audit_ok "wallpaper present" || audit_bad "wallpaper missing"
if find "$PROFILE/airootfs/etc/xdg/autostart" -maxdepth 1 -type f 2>/dev/null | grep -Ei 'calamares|installer'; then audit_bad "installer autostart exists"; else audit_ok "no installer autostart"; fi
ALLOWED_LOLIOS_AUTOSTARTS='^(lolios-activate-kde-theme|lolios-ensure-plasma-panel|lolios-start-center|lolios-first-login-setup)\.desktop$'
while IFS= read -r autostart; do
    base="$(basename "$autostart")"
    if printf '%s\n' "$base" | grep -Eq "$ALLOWED_LOLIOS_AUTOSTARTS"; then audit_ok "allowed LoliOS autostart: $base"; elif printf '%s\n' "$base" | grep -Eiq 'lolios|loli|calamares|installer|wallpaper|theme|panel'; then audit_bad "unexpected LoliOS-related autostart: $base"; fi
done < <(find "$PROFILE/airootfs/etc/xdg/autostart" -maxdepth 1 -type f -name '*.desktop' 2>/dev/null | sort)
COUNT_WALL="$(find "$PROFILE/airootfs/etc/xdg/autostart" -maxdepth 1 -type f -name '*wallpaper*.desktop' 2>/dev/null | wc -l)"
[ "$COUNT_WALL" -eq 0 ] && audit_ok "wallpaper autostart disabled; session init owns wallpaper" || audit_bad "wallpaper autostart should not exist: count=$COUNT_WALL"

if [ "${#AUR_FAILED[@]}" -gt 0 ]; then warn "Niektóre AUR paczki nie zbudowały się: ${AUR_FAILED[*]}"; warn "Jeśli są wymagane w packages.x86_64, mkarchiso może nie przejść."; fi
[ "$FAIL" -eq 0 ] || die "Audit failed"
log "Audit passed"
write_build_manifest_v2

# ------------------------------------------------------------
