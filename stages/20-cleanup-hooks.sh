# Sourced by ../build.sh; original section: 20. Remove duplicate/deprecated autostarts and old hooks

# 20. Remove duplicate/deprecated autostarts and old hooks
# ------------------------------------------------------------

log "Removing duplicate autostarts and deprecated hooks"

rm -f "$PROFILE/airootfs/root/customize_airootfs.sh"

for autostart_dir in \
    "$PROFILE/airootfs/etc/xdg/autostart" \
    "$PROFILE/airootfs/etc/skel/.config/autostart" \
    "$PROFILE/airootfs/root/.config/autostart"
 do
    [ -d "$autostart_dir" ] || continue
    rm -f \
        "$autostart_dir/calamares.desktop" \
        "$autostart_dir/loli-installer.desktop" \
        "$autostart_dir/lolios-installer.desktop" \
        "$autostart_dir/lolios-first-run.desktop" \
        "$autostart_dir/lolios-wallpaper.desktop" \
        "$autostart_dir/lolios-force-wallpaper.desktop" \
        "$autostart_dir/lolios-set-wallpaper.desktop" \
        "$autostart_dir/lolios-apply-kde-theme.desktop"
 done

# Keep exactly one KDE session initializer in XDG autostart; systemd --user also
# runs the same script, but this desktop file is a fallback for sessions where the
# user manager is delayed or disabled.
if [ -f "$PROFILE/airootfs/etc/xdg/autostart/lolios-activate-kde-theme.desktop" ]; then
    mkdir -p "$PROFILE/airootfs/etc/skel/.config/autostart" "$PROFILE/airootfs/root/.config/autostart"
    cp -f "$PROFILE/airootfs/etc/xdg/autostart/lolios-activate-kde-theme.desktop" "$PROFILE/airootfs/etc/skel/.config/autostart/lolios-activate-kde-theme.desktop"
    cp -f "$PROFILE/airootfs/etc/xdg/autostart/lolios-activate-kde-theme.desktop" "$PROFILE/airootfs/root/.config/autostart/lolios-activate-kde-theme.desktop"
fi

# ------------------------------------------------------------
