#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0

check_py() {
  local file="$1"
  python3 -m py_compile "$file" && echo "OK py $file" || { echo "BAD py $file"; fail=1; }
}

check_bash() {
  local file="$1"
  bash -n "$file" && echo "OK bash $file" || { echo "BAD bash $file"; fail=1; }
}

check_py "$ROOT/src/bin/lolios-exe-launcher"
check_py "$ROOT/src/bin/lolios-profile"
check_py "$ROOT/src/bin/lolios-gaming-center"
check_py "$ROOT/src/bin/lolios-app-center"
check_py "$ROOT/src/lib/lolios_guard.py"
check_py "$ROOT/scripts/audit-scripts.py"
check_py "$ROOT/scripts/stage-report.py"

for f in "$ROOT"/stages/17*.sh; do
  check_bash "$f"
done
check_bash "$ROOT/build.sh"
check_bash "$ROOT/scripts/check-project.sh"

python3 - "$ROOT" <<'PY' || fail=1
import json, pathlib, sys
root=pathlib.Path(sys.argv[1])
for path in list((root/'src').glob('**/*.json')) + list((root/'stages').glob('*.json')):
    try:
        json.load(open(path, encoding='utf-8'))
        print('OK json', path)
    except Exception as exc:
        print('BAD json', path, exc)
        raise SystemExit(1)
PY

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

python3 "$ROOT/src/bin/lolios-profile" migrate TestGame >/dev/null
python3 "$ROOT/src/bin/lolios-profile" migrate TestApp >/dev/null
python3 "$ROOT/src/bin/lolios-profile" validate TestGame | grep -q '"ok": true' || { echo "BAD profile validate game"; fail=1; }
python3 "$ROOT/src/bin/lolios-profile" validate TestApp | grep -q '"ok": true' || { echo "BAD profile validate app"; fail=1; }
python3 "$ROOT/src/bin/lolios-profile" set-category TestApp game >/dev/null
python3 "$ROOT/src/bin/lolios-profile" validate TestApp | grep -q '"category": "game"' || { echo "BAD set-category game"; fail=1; }
python3 "$ROOT/src/bin/lolios-profile" set-category TestApp app >/dev/null
python3 "$ROOT/src/bin/lolios-profile" validate TestApp | grep -q '"category": "app"' || { echo "BAD set-category app"; fail=1; }

python3 "$ROOT/src/bin/lolios-exe-launcher" --list-json >/dev/null || { echo "BAD launcher list"; fail=1; }
python3 "$ROOT/src/bin/lolios-exe-launcher" --list-json --category game | grep -q 'TestGame' || { echo "BAD category game list"; fail=1; }
python3 "$ROOT/src/bin/lolios-exe-launcher" --list-json --category app | grep -q 'TestApp' || { echo "BAD category app list"; fail=1; }
python3 "$ROOT/src/bin/lolios-exe-launcher" --help >/dev/null || { echo "BAD launcher help"; fail=1; }
python3 "$ROOT/src/bin/lolios-profile" --help >/dev/null || { echo "BAD profile help"; fail=1; }
PYTHONPATH="$ROOT/src/lib" python3 "$ROOT/src/lib/lolios_guard.py" >/dev/null || { echo "BAD guard status with dev override"; fail=1; }
PYTHONPATH="$ROOT/src/lib" python3 "$ROOT/src/bin/lolios-gaming-center" --json >/dev/null || { echo "BAD gaming center json"; fail=1; }
PYTHONPATH="$ROOT/src/lib" python3 "$ROOT/src/bin/lolios-app-center" --json >/dev/null || { echo "BAD app center json"; fail=1; }

unset LOLIOS_DEV_ALLOW_NON_LOLIOS
if PYTHONPATH="$ROOT/src/lib" python3 "$ROOT/src/bin/lolios-gaming-center" --json >/dev/null 2>&1; then
  echo "BAD guard should block gaming center without LoliOS marker"
  fail=1
else
  echo "OK guard blocks gaming center outside LoliOS"
fi

exit "$fail"
