#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

printf '[check] project root: %s\n' "$PROJECT_ROOT"

bash -n build.sh
printf '[check] bash -n build.sh: OK\n'

for file in "$PROJECT_ROOT"/stages/*.sh; do
    bash -n "$file"
done
printf '[check] bash -n stages/*.sh: OK\n'

for file in "$PROJECT_ROOT"/src/bin/* "$PROJECT_ROOT"/src/lib/*; do
    [ -f "$file" ] || continue
    if head -n1 "$file" | grep -q 'python3' || [ "${file##*.}" = py ]; then
        python3 -m py_compile "$file"
    elif head -n1 "$file" | grep -Eq 'bash|sh'; then
        bash -n "$file"
    fi
done
printf '[check] src/bin and src/lib syntax: OK\n'

for required in \
    src/bin/lolios-exe-launcher \
    src/bin/lolios-profile \
    src/bin/lolios-gaming-center \
    src/bin/lolios-app-center \
    src/lib/lolios_guard.py \
    tests/test-gaming-tools.sh \
    scripts/full-repo-audit.py
 do
    [ -f "$required" ] || { echo "[check] missing required file: $required" >&2; exit 1; }
done
printf '[check] required source-managed tools exist: OK\n'

grep -q 'require_lolios("LoliOS Game Center")' src/bin/lolios-gaming-center
grep -q 'require_lolios("LoliOS App Center")' src/bin/lolios-app-center
grep -q 'LOLIOS_DEV_ALLOW_NON_LOLIOS' src/lib/lolios_guard.py
printf '[check] LoliOS-only guards are wired: OK\n'

missing=0
while IFS= read -r rel; do
    [ -f "$PROJECT_ROOT/$rel" ] || { echo "[check] missing source target: $rel" >&2; missing=1; }
done < <(grep -o 'stages/[^\"]*\.sh' build.sh)
[ "$missing" -eq 0 ]
printf '[check] build.sh source targets exist: OK\n'

grep -R --quiet '01c-runtime-repo-overrides.sh' build.sh
grep -R --quiet 'PROFILE="${PROFILE:-$WORKROOT/profile}"' stages/00-global-config.sh
grep -R --quiet 'CUSTOMREPO="$PROFILE/customrepo"' stages/00-global-config.sh
grep -R --quiet 'USE_EXISTING_PROFILE' stages/03-fresh-profile.sh
grep -R --quiet 'ABS_WORKDIR' stages/23-build-iso.sh
grep -R --quiet 'ABS_OUTDIR' stages/23-build-iso.sh
grep -R --quiet 'ABS_PROFILE' stages/23-build-iso.sh
grep -R --quiet 'mkarchiso -v -w "$ABS_WORKDIR" -o "$ABS_OUTDIR" "$ABS_PROFILE"' stages/23-build-iso.sh
printf '[check] critical path invariants: OK\n'

# KDE/theme invariants that prevent the regressions seen during ISO testing.
grep -R --quiet 'NoExtract = usr/share/plasma/look-and-feel/org.kde\.\*' stages/05-pacman-conf.sh
grep -R --quiet 'lolios-session-init' stages/12e-kde-theme-activation.sh
grep -R --quiet -- '--resetLayout' stages/12e-kde-theme-activation.sh
grep -R --quiet 'org.kde.plasma.kickoff' stages/12d-plasma-panel-layout.sh
grep -R --quiet 'org.kde.plasma.systemtray' stages/12d-plasma-panel-layout.sh
grep -R --quiet 'package-owned icon theme exists in overlay' stages/21-audit.sh
grep -R --quiet 'breeze-dark,breeze,hicolor' stages/12f-lolios-icon-fallback.sh
grep -R --quiet 'wallpaper autostart should not exist' stages/21-audit.sh
printf '[check] KDE/theme invariants: OK\n'

# Package flow invariant: finalizer must run after late stages that may add packages
# and before audit/mkarchiso. mkarchiso stage must not mutate packages.
finalizer_line="$(grep -n '07z-packages-finalize.sh' build.sh | cut -d: -f1 | head -1)"
audit_line="$(grep -n '21-audit.sh' build.sh | cut -d: -f1 | head -1)"
kde_icon_line="$(grep -n '12f-lolios-icon-fallback.sh' build.sh | cut -d: -f1 | head -1)"
[ "$kde_icon_line" -lt "$finalizer_line" ] || { echo '[check] finalizer must run after 12f icons' >&2; exit 1; }
[ "$finalizer_line" -lt "$audit_line" ] || { echo '[check] finalizer must run before audit' >&2; exit 1; }
! grep -Eq 'prune_(unavailable|slim|missing)|refresh_local_repo' stages/23-build-iso.sh || { echo '[check] mkarchiso stage must not mutate packages/repo' >&2; exit 1; }
! grep -qx 'plasma-meta' stages/07-packages.sh || { echo '[check] plasma-meta must not be used' >&2; exit 1; }
! grep -qx 'kde-system-meta' stages/07-packages.sh || { echo '[check] kde-system-meta must not be used' >&2; exit 1; }
grep -qx 'plasma-desktop' stages/07-packages.sh
grep -qx 'kwin' stages/07-packages.sh
printf '[check] package flow invariants: OK\n'

python3 scripts/audit-scripts.py >/tmp/lolios-script-audit.json
python3 - <<'PY'
import json
p='/tmp/lolios-script-audit.json'
data=json.load(open(p))
print(f"[check] script audit: files={data['files_checked']} errors={data['errors']} warnings={data['warnings']}")
if data['errors']:
    print(open(p).read())
    raise SystemExit(1)
PY

python3 scripts/full-repo-audit.py >/tmp/lolios-full-repo-audit.json
python3 - <<'PY'
import json
p='/tmp/lolios-full-repo-audit.json'
data=json.load(open(p))
print(f"[check] full repo audit: files={data['files_checked']} text={data['text_files_checked']} binary={data['binary_files_checked']} errors={len(data['errors'])} warnings={len(data['warnings'])}")
if data['errors']:
    print(open(p).read())
    raise SystemExit(1)
PY

printf '[check] all checks passed.\n'
