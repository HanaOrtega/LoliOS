#!/usr/bin/env python3
"""Static optimization and hygiene audit for LoliOS shell/Python scripts.

This is intentionally conservative: it reports patterns that usually caused
regressions in this repo without trying to auto-rewrite code.
"""
from __future__ import annotations

import json
import re
import stat
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT_DIRS = [ROOT / "stages", ROOT / "scripts", ROOT / "src" / "bin", ROOT / "src" / "lib", ROOT / "tests"]
WARN_ONLY_PATTERNS = [
    (re.compile(r"cat\s+>\s+\"?\$PROFILE/airootfs/usr/local/bin/lolios-(exe-launcher|profile|gaming-center|app-center)"), "generated-canonical-tool"),
    (re.compile(r"rm\s+-rf\s+/"), "dangerous-rm-root"),
    (re.compile(r"chmod\s+-R\s+777"), "chmod-777"),
    (re.compile(r"curl\s+[^|;]*\|\s*(sudo\s+)?bash"), "curl-pipe-bash"),
    (re.compile(r"wget\s+[^|;]*\|\s*(sudo\s+)?bash"), "wget-pipe-bash"),
    (re.compile(r"pacman\s+-S[^\n]*--noconfirm(?![^\n]*(--needed))"), "pacman-without-needed"),
    (re.compile(r"for\s+.*;\s+do\s+.*(pacman|repo-add|mkarchiso)"), "heavy-command-in-loop"),
]

CANONICAL_BINARIES = {
    "lolios-exe-launcher",
    "lolios-profile",
    "lolios-gaming-center",
    "lolios-app-center",
}

REQUIRED_SOURCE_FILES = [
    ROOT / "src" / "bin" / "lolios-exe-launcher",
    ROOT / "src" / "bin" / "lolios-profile",
    ROOT / "src" / "bin" / "lolios-gaming-center",
    ROOT / "src" / "bin" / "lolios-app-center",
    ROOT / "src" / "lib" / "lolios_guard.py",
]


def iter_files() -> list[Path]:
    files: list[Path] = []
    for directory in SCRIPT_DIRS:
        if not directory.exists():
            continue
        for path in directory.rglob("*"):
            if path.is_file() and not path.name.endswith((".pyc", ".png", ".jpg", ".svg", ".tar", ".zst")):
                files.append(path)
    files.append(ROOT / "build.sh")
    return sorted(set(files))


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT))


def run(cmd: list[str]) -> tuple[bool, str]:
    proc = subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    return proc.returncode == 0, proc.stdout.strip()


def check_required_files() -> list[dict]:
    issues = []
    for path in REQUIRED_SOURCE_FILES:
        if not path.exists():
            issues.append({"severity": "error", "kind": "missing-required-source", "file": rel(path)})
    return issues


def check_syntax(files: list[Path]) -> list[dict]:
    issues = []
    for path in files:
        text = path.read_text(errors="ignore")
        if path.suffix == ".sh" or text.startswith("#!/usr/bin/env bash") or text.startswith("#!/bin/bash"):
            ok, out = run(["bash", "-n", str(path)])
            if not ok:
                issues.append({"severity": "error", "kind": "bash-syntax", "file": rel(path), "detail": out})
        elif text.startswith("#!/usr/bin/env python3") or path.suffix == ".py" or rel(path).startswith("src/lib/"):
            ok, out = run([sys.executable, "-m", "py_compile", str(path)])
            if not ok:
                issues.append({"severity": "error", "kind": "python-syntax", "file": rel(path), "detail": out})
    return issues


def check_build_targets() -> list[dict]:
    issues = []
    build = (ROOT / "build.sh").read_text(errors="ignore")
    refs = re.findall(r"stages/[^\"]+\.sh", build)
    counts = Counter(refs)
    for item, count in counts.items():
        if count > 1:
            issues.append({"severity": "error", "kind": "duplicate-stage-ref", "file": "build.sh", "detail": f"{item} referenced {count} times"})
    for item in refs:
        if not (ROOT / item).exists():
            issues.append({"severity": "error", "kind": "missing-stage", "file": "build.sh", "detail": item})
    return issues


def check_patterns(files: list[Path]) -> list[dict]:
    issues = []
    writers: dict[str, list[str]] = defaultdict(list)
    for path in files:
        text = path.read_text(errors="ignore")
        for pattern, kind in WARN_ONLY_PATTERNS:
            for match in pattern.finditer(text):
                line = text[: match.start()].count("\n") + 1
                issues.append({"severity": "warning", "kind": kind, "file": rel(path), "line": line})
        for binary in CANONICAL_BINARIES:
            if re.search(rf"/usr/local/bin/{re.escape(binary)}\b", text) or re.search(rf"\b{re.escape(binary)}\"?\s*<<'EOF'", text):
                writers[binary].append(rel(path))
    for binary, paths in writers.items():
        unique = sorted(set(paths))
        allowed = {f"src/bin/{binary}", "stages/17z-install-src-gaming-tools.sh", "stages/21-audit.sh", "tests/test-gaming-tools.sh"}
        unexpected = [p for p in unique if p not in allowed]
        if unexpected:
            issues.append({"severity": "warning", "kind": "possible-canonical-binary-overlap", "file": binary, "detail": unexpected})
    return issues


def check_executable_bits(files: list[Path]) -> list[dict]:
    issues = []
    for path in files:
        r = rel(path)
        if r.startswith(("src/bin/", "scripts/")) and path.name.endswith((".py", ".sh")):
            mode = path.stat().st_mode
            if not mode & stat.S_IXUSR:
                issues.append({"severity": "warning", "kind": "not-executable", "file": r})
    return issues


def check_guard_imports() -> list[dict]:
    issues = []
    for tool, guard_name in [("lolios-gaming-center", "LoliOS Game Center"), ("lolios-app-center", "LoliOS App Center")]:
        path = ROOT / "src" / "bin" / tool
        if not path.exists():
            continue
        text = path.read_text(errors="ignore")
        if "require_lolios" not in text or guard_name not in text:
            issues.append({"severity": "error", "kind": "missing-lolios-guard", "file": rel(path), "detail": guard_name})
    return issues


def main() -> int:
    files = iter_files()
    issues = []
    issues.extend(check_required_files())
    issues.extend(check_syntax(files))
    issues.extend(check_build_targets())
    issues.extend(check_patterns(files))
    issues.extend(check_executable_bits(files))
    issues.extend(check_guard_imports())

    errors = [i for i in issues if i["severity"] == "error"]
    warnings = [i for i in issues if i["severity"] == "warning"]
    summary = {
        "files_checked": len(files),
        "errors": len(errors),
        "warnings": len(warnings),
        "issues": issues,
    }
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
