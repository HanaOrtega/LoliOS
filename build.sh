#!/usr/bin/env bash
set -Eeuo pipefail

# LoliOS Builder split wrapper.
# Run this file from anywhere; all stages are sourced from this project directory.
PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export LOLIOS_PROJECT_ROOT="$PROJECT_ROOT"

STAGES=(
  "$PROJECT_ROOT/stages/00-global-config.sh"
  "$PROJECT_ROOT/stages/01-common-helpers.sh"
  "$PROJECT_ROOT/stages/01b-runtime-repo-helpers.sh"
  "$PROJECT_ROOT/stages/01c-runtime-repo-overrides.sh"
  "$PROJECT_ROOT/stages/02-preflight.sh"
  "$PROJECT_ROOT/stages/03-fresh-profile.sh"
  "$PROJECT_ROOT/stages/04-profiledef.sh"
  "$PROJECT_ROOT/stages/05-pacman-conf.sh"
  "$PROJECT_ROOT/stages/06-local-repo-aur.sh"
  "$PROJECT_ROOT/stages/06b-bottles-github.sh"
  "$PROJECT_ROOT/stages/07-packages.sh"
  "$PROJECT_ROOT/stages/07b-feature-packages.sh"
  "$PROJECT_ROOT/stages/08-identity.sh"
  "$PROJECT_ROOT/stages/09-mkinitcpio.sh"
  "$PROJECT_ROOT/stages/10-live-user.sh"
  "$PROJECT_ROOT/stages/11-live-sudo-polkit.sh"
  "$PROJECT_ROOT/stages/12-sddm-services.sh"
  "$PROJECT_ROOT/stages/12z-sddm-autologin-fix.sh"
  "$PROJECT_ROOT/stages/12b-kde-theme.sh"
  "$PROJECT_ROOT/stages/12d-plasma-panel-layout.sh"
  "$PROJECT_ROOT/stages/12e-kde-theme-activation.sh"
  "$PROJECT_ROOT/stages/12f-lolios-icon-fallback.sh"
  "$PROJECT_ROOT/stages/13-calamares.sh"
  "$PROJECT_ROOT/stages/13b-calamares-install-hardening.sh"
  "$PROJECT_ROOT/stages/13c-calamares-shellprocess-bash.sh"
  "$PROJECT_ROOT/stages/14-postinstall.sh"
  "$PROJECT_ROOT/stages/14d-calamares-postinstall-safety.sh"
  "$PROJECT_ROOT/stages/14d-installed-pacman-conf-fix.sh"
  "$PROJECT_ROOT/stages/14e-remove-installer-from-installed-system.sh"
  "$PROJECT_ROOT/stages/14f-arch-update-policy.sh"
  "$PROJECT_ROOT/stages/14b-installed-firstboot.sh"
  "$PROJECT_ROOT/stages/14c-installed-autologin-user.sh"
  "$PROJECT_ROOT/stages/15-wallpaper-kde-defaults.sh"
  "$PROJECT_ROOT/stages/12c-lolios-theme-audit.sh"
  "$PROJECT_ROOT/stages/16-installer-launcher.sh"
  "$PROJECT_ROOT/stages/16b-live-installed-ux.sh"
  "$PROJECT_ROOT/stages/17-gaming-tools.sh"
  "$PROJECT_ROOT/stages/17b-extra-feature-tools.sh"
  "$PROJECT_ROOT/stages/17c-gaming-nextgen.sh"
  "$PROJECT_ROOT/stages/17d-exe-launcher-logic.sh"
  "$PROJECT_ROOT/stages/17e-exe-launcher-pro-features.sh"
  "$PROJECT_ROOT/stages/17f-advanced-compat-suite.sh"
  "$PROJECT_ROOT/stages/17g-next-compat-managers.sh"
  "$PROJECT_ROOT/stages/17x-offline-repair-tools.sh"
  "$PROJECT_ROOT/stages/17y-physx-runtime.sh"
  "$PROJECT_ROOT/stages/17z-install-src-gaming-tools.sh"
  "$PROJECT_ROOT/stages/17zy-lolios-menu-folder.sh"
  "$PROJECT_ROOT/stages/17zz-tool-permission-hardening.sh"
  "$PROJECT_ROOT/stages/18-gaming-system-config.sh"
  "$PROJECT_ROOT/stages/19-boot-menu.sh"
  "$PROJECT_ROOT/stages/20-cleanup-hooks.sh"
  "$PROJECT_ROOT/stages/07z-packages-finalize.sh"
  "$PROJECT_ROOT/stages/21-audit.sh"
  "$PROJECT_ROOT/stages/22-qemu-smoke-test.sh"
  "$PROJECT_ROOT/stages/23-build-iso.sh"
 )

for stage in "${STAGES[@]}"; do
    if [ ! -f "$stage" ]; then
        echo "[ERROR] Missing stage: $stage" >&2
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$stage"
done
