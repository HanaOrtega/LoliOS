#!/usr/bin/env bash
set -Eeuo pipefail

APP_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd -- "$APP_ROOT/../.." && pwd)"
fail=0

check_py() {
  local file="$1"
  python3 -m py_compile "$file" && echo "OK py $file" || { echo "BAD py $file"; fail=1; }
}

check_bash() {
  local file="$1"
  bash -n "$file" && echo "OK bash $file" || { echo "BAD bash $file"; fail=1; }
}

check_py "$APP_ROOT/src/bin/lolios-exe-launcher"
check_py "$APP_ROOT/src/bin/lolios-profile"
check_py "$APP_ROOT/src/bin/lolios-gaming-center"
check_py "$APP_ROOT/src/bin/lolios-app-center"
check_py "$APP_ROOT/src/lib/lolios_guard.py"
check_bash "$APP_ROOT/install-to-airootfs.sh"
check_bash "$REPO_ROOT/stages/17z-install-src-gaming-tools.sh"

TMP="$(mktemp -d)"
export LOLIOS_EXE_STATE_DIR="$TMP/state"
export LOLIOS_PREFIX_BASE="$TMP/games"
export LOLIOS_DEV_ALLOW_NON_LOLIOS=1
mkdir -p "$TMP/bin" "$LOLIOS_EXE_STATE_DIR/apps/TestGame" "$LOLIOS_EXE_STATE_DIR/apps/TestApp" "$LOLIOS_PREFIX_BASE/TestGame/prefix" "$LOLIOS_PREFIX_BASE/TestApp/prefix"
touch "$TMP/game.exe" "$TMP/app-setup.exe"
cat > "$LOLIOS_EXE_STATE_DIR/apps/TestGame/profile.json" <<JSON
{
  "schema_version": 1,
  "name": "TestGame",
  "exe": "$TMP/game.exe",
  "prefix": "$LOLIOS_PREFIX_BASE/TestGame/prefix",
  "runner": "auto",
  "category": "game",
  "features": {}
}
JSON
cat > "$LOLIOS_EXE_STATE_DIR/apps/TestApp/profile.json" <<JSON
{
  "schema_version": 1,
  "name": "TestApp",
  "exe": "$TMP/app-setup.exe",
  "prefix": "$LOLIOS_PREFIX_BASE/TestApp/prefix",
  "runner": "auto",
  "category": "app",
  "features": {}
}
JSON

python3 "$APP_ROOT/src/bin/lolios-profile" migrate TestGame >/dev/null
python3 "$APP_ROOT/src/bin/lolios-profile" migrate TestApp >/dev/null
python3 "$APP_ROOT/src/bin/lolios-profile" validate TestGame | grep -q '"ok": true' || { echo "BAD profile validate game"; fail=1; }
python3 "$APP_ROOT/src/bin/lolios-profile" validate TestApp | grep -q '"ok": true' || { echo "BAD profile validate app"; fail=1; }
python3 "$APP_ROOT/src/bin/lolios-profile" set-category TestApp game >/dev/null
python3 "$APP_ROOT/src/bin/lolios-profile" validate TestApp | grep -q '"category": "game"' || { echo "BAD set-category game"; fail=1; }
python3 "$APP_ROOT/src/bin/lolios-profile" set-category TestApp app >/dev/null
python3 "$APP_ROOT/src/bin/lolios-profile" validate TestApp | grep -q '"category": "app"' || { echo "BAD set-category app"; fail=1; }

python3 "$APP_ROOT/src/bin/lolios-exe-launcher" --list-json >/dev/null || { echo "BAD launcher list"; fail=1; }
python3 "$APP_ROOT/src/bin/lolios-exe-launcher" --list-json --category game | grep -q 'TestGame' || { echo "BAD category game list"; fail=1; }
python3 "$APP_ROOT/src/bin/lolios-exe-launcher" --list-json --category app | grep -q 'TestApp' || { echo "BAD category app list"; fail=1; }
python3 "$APP_ROOT/src/bin/lolios-exe-launcher" --help >/dev/null || { echo "BAD launcher help"; fail=1; }
python3 "$APP_ROOT/src/bin/lolios-profile" --help >/dev/null || { echo "BAD profile help"; fail=1; }
PYTHONPATH="$APP_ROOT/src/lib" python3 "$APP_ROOT/src/lib/lolios_guard.py" >/dev/null || { echo "BAD guard status with dev override"; fail=1; }
PATH="$APP_ROOT/src/bin:$PATH" PYTHONPATH="$APP_ROOT/src/lib" python3 "$APP_ROOT/src/bin/lolios-gaming-center" --json >/dev/null || { echo "BAD gaming center json"; fail=1; }
PATH="$APP_ROOT/src/bin:$PATH" PYTHONPATH="$APP_ROOT/src/lib" python3 "$APP_ROOT/src/bin/lolios-app-center" --json >/dev/null || { echo "BAD app center json"; fail=1; }

unset LOLIOS_DEV_ALLOW_NON_LOLIOS
if PYTHONPATH="$APP_ROOT/src/lib" python3 "$APP_ROOT/src/bin/lolios-gaming-center" --json >/dev/null 2>&1; then
  echo "BAD guard should block gaming center without LoliOS marker"
  fail=1
else
  echo "OK guard blocks gaming center outside LoliOS"
fi

AIROOTFS="$TMP/airootfs"
bash "$APP_ROOT/install-to-airootfs.sh" "$REPO_ROOT" "$AIROOTFS"
for tool in lolios-exe-launcher lolios-profile lolios-gaming-center lolios-app-center lolios-guard-status lolios-verify-compat-suite; do
  [ -x "$AIROOTFS/usr/local/bin/$tool" ] || { echo "BAD installed tool not executable: $tool"; fail=1; }
done
[ -f "$AIROOTFS/usr/lib/lolios/lolios_guard.py" ] || { echo "BAD installed guard missing"; fail=1; }
[ -f "$AIROOTFS/usr/share/lolios/product.json" ] || { echo "BAD installed product marker missing"; fail=1; }

exit "$fail"
