#!/usr/bin/env python3
"""Exhaustive LoliOS repository audit.

This script intentionally walks every Git-tracked file using `git ls-files`.
It is designed for local execution from scripts/check-project.sh or manually.
"""
from __future__ import annotations

import ast
import json
import os
import re
import stat
import subprocess
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]

TEXT_EXTS = {
    ".sh", ".bash", ".py", ".json", ".conf", ".desktop", ".service", ".timer",
    ".rules", ".preset", ".qml", ".md", ".txt", ".yaml", ".yml", ".toml", ".ini",
    ".theme", ".colors", ".xml", ".svg", ".css", ".rules", ".list",
}

BINARY_EXTS = {
    ".png", ".jpg", ".jpeg", ".webp", ".ico", ".gz", ".zst", ".xz", ".zip", ".iso", ".exe",
}

REQUIRED_BUILD_STAGE_RE = re.compile(r"stages/[^\"']+\.sh")
CONFLICT_MARKER_RE = re.compile(r"(?m)^(<<<<<<< .+|=======|>>>>>>> .+)$")


def run(cmd: list[str], *, cwd: Path = ROOT, check: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=check)


def git_files() -> list[Path]:
    proc = run(["git", "ls-files"], check=True)
    return [ROOT / line for line in proc.stdout.splitlines() if line.strip()]


def is_probably_text(path: Path) -> bool:
    if path.suffix.lower() in BINARY_EXTS:
        return False
    if path.suffix.lower() in TEXT_EXTS:
        return True
    try:
        data = path.read_bytes()[:4096]
    except OSError:
        return False
    return b"\0" not in data


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def add(report: dict[str, Any], severity: str, path: Path | str, message: str) -> None:
    report[severity].append({"file": str(path) if isinstance(path, str) else rel(path), "message": message})


def check_text_file(path: Path, text: str, report: dict[str, Any]) -> None:
    r = rel(path)
    if "\r\n" in text:
        add(report, "warnings", path, "CRLF line endings")
    if "\t" in text and path.suffix.lower() in {".py", ".yaml", ".yml"}:
        add(report, "warnings", path, "tabs present in indentation-sensitive file")
    if text and not text.endswith("\n"):
        add(report, "warnings", path, "missing final newline")
    if re.search(r"(?m)[ \t]+$", text):
        add(report, "warnings", path, "trailing whitespace")
    if CONFLICT_MARKER_RE.search(text):
        add(report, "errors", path, "merge conflict marker found")
    if re.search(r"(?i)(password|token|secret|apikey|api_key)\s*=\s*['\"][^'\"]{8,}", text):
        add(report, "warnings", path, "possible hardcoded secret-like assignment")
    if r.startswith("stages/") and path.suffix == ".sh" and "# Sourced by ../build.sh" not in text[:300]:
        add(report, "warnings", path, "stage file missing sourced-by header")
    if r.startswith("stages/") and path.suffix == ".sh" and re.search(r"\bexit\s+[0-9]", text):
        add(report, "warnings", path, "stage contains direct exit; sourced stages should usually use die/return")
    if r.startswith("stages/") and path.suffix == ".sh" and "sudo rm -rf /" in text:
        add(report, "errors", path, "dangerous sudo rm -rf / pattern")
    if path.name.endswith(".desktop"):
        for key in ("[Desktop Entry]", "Type=", "Name=", "Exec="):
            if key not in text:
                add(report, "errors", path, f"desktop file missing {key}")
    if path.suffix == ".json":
        try:
            json.loads(text)
        except Exception as exc:
            add(report, "errors", path, f"invalid JSON: {exc}")
    if path.suffix == ".py" or text.startswith("#!/usr/bin/env python3"):
        try:
            ast.parse(text, filename=r)
        except SyntaxError as exc:
            add(report, "errors", path, f"python syntax error: {exc}")


def check_shell(path: Path, report: dict[str, Any]) -> None:
    proc = run(["bash", "-n", str(path)])
    if proc.returncode != 0:
        add(report, "errors", path, "bash -n failed: " + proc.stderr.strip())


def check_python_compile(path: Path, report: dict[str, Any]) -> None:
    proc = run([sys.executable, "-m", "py_compile", str(path)])
    if proc.returncode != 0:
        add(report, "errors", path, "py_compile failed: " + proc.stderr.strip())


def check_executable_policy(path: Path, text: str, report: dict[str, Any]) -> None:
    mode = path.stat().st_mode
    executable = bool(mode & stat.S_IXUSR)
    has_shebang = text.startswith("#!")
    r = rel(path)
    if has_shebang and r.startswith(("src/bin/", "scripts/")) and not executable:
        add(report, "warnings", path, "shebang file is not executable")
    if executable and not has_shebang and path.suffix.lower() in TEXT_EXTS:
        add(report, "warnings", path, "text file is executable but has no shebang")


def check_build_stage_references(report: dict[str, Any]) -> None:
    build = ROOT / "build.sh"
    if not build.exists():
        add(report, "errors", "build.sh", "missing build.sh")
        return
    text = build.read_text(errors="replace")
    refs = sorted(set(REQUIRED_BUILD_STAGE_RE.findall(text)))
    for ref in refs:
        if not (ROOT / ref).is_file():
            add(report, "errors", ref, "stage referenced by build.sh is missing")
    stage_files = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / "stages").glob("*.sh")) if (ROOT / "stages").is_dir() else []
    unused = [p for p in stage_files if p not in refs]
    for item in unused:
        add(report, "warnings", item, "stage file exists but is not referenced by build.sh")


def check_required_project_files(report: dict[str, Any]) -> None:
    required = [
        "build.sh",
        "scripts/check-project.sh",
        "scripts/audit-scripts.py",
        "tests/test-gaming-tools.sh",
        "src/bin/lolios-exe-launcher",
        "src/bin/lolios-profile",
        "src/bin/lolios-gaming-center",
        "src/bin/lolios-app-center",
        "src/lib/lolios_guard.py",
    ]
    for item in required:
        if not (ROOT / item).is_file():
            add(report, "errors", item, "required project file missing")


def main() -> int:
    report: dict[str, Any] = {
        "root": str(ROOT),
        "files_checked": 0,
        "text_files_checked": 0,
        "binary_files_checked": 0,
        "errors": [],
        "warnings": [],
        "files": [],
    }

    try:
        files = git_files()
    except Exception as exc:
        add(report, "errors", "git", f"git ls-files failed: {exc}")
        print(json.dumps(report, indent=2, ensure_ascii=False))
        return 2

    check_required_project_files(report)
    check_build_stage_references(report)

    for path in files:
        report["files_checked"] += 1
        report["files"].append(rel(path))
        if not path.exists():
            add(report, "errors", path, "git-tracked file missing from working tree")
            continue
        if path.is_symlink():
            target = os.readlink(path)
            if target.startswith("/") or ".." in Path(target).parts:
                add(report, "warnings", path, f"suspicious symlink target: {target}")
            continue
        if not path.is_file():
            add(report, "warnings", path, "git-tracked entry is not a regular file")
            continue
        if not is_probably_text(path):
            report["binary_files_checked"] += 1
            if path.stat().st_size == 0:
                add(report, "warnings", path, "empty binary/non-text file")
            continue
        report["text_files_checked"] += 1
        text = path.read_text(errors="replace")
        check_text_file(path, text, report)
        check_executable_policy(path, text, report)
        if path.suffix == ".sh" or text.startswith("#!/usr/bin/env bash") or text.startswith("#!/bin/bash"):
            check_shell(path, report)
        if path.suffix == ".py" or text.startswith("#!/usr/bin/env python3"):
            check_python_compile(path, report)

    print(json.dumps(report, indent=2, ensure_ascii=False, sort_keys=True))
    return 1 if report["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
