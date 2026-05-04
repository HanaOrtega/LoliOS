#!/usr/bin/env python3
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STAGES = ROOT / 'stages'
CANONICAL = ['lolios-exe-launcher', 'lolios-profile', 'lolios-gaming-center', 'lolios-app-center']


def analyze(path: Path) -> dict:
    text = path.read_text(errors='ignore')
    lines = text.count('\n') + 1
    heredocs = len(re.findall(r"<<['\"]?[A-Z0-9_ -]+['\"]?", text))
    installed_bins = sorted(set(re.findall(r"/usr/local/bin/([A-Za-z0-9._-]+)", text)))
    canonical_refs = [b for b in CANONICAL if b in text]
    cat_writes = len(re.findall(r"cat\s+>\s+", text))
    install_writes = len(re.findall(r"\binstall\s+-D", text))
    rm_rf = len(re.findall(r"\brm\s+-rf\b", text))
    repo_ops = len(re.findall(r"\b(repo-add|refresh_local_repo|makepkg|pacman)\b", text))
    return {
        'stage': str(path.relative_to(ROOT)),
        'lines': lines,
        'heredocs': heredocs,
        'cat_writes': cat_writes,
        'install_writes': install_writes,
        'rm_rf': rm_rf,
        'repo_ops': repo_ops,
        'installed_bins': installed_bins,
        'canonical_refs': canonical_refs,
    }


def main() -> int:
    rows = [analyze(p) for p in sorted(STAGES.glob('*.sh'))]
    rows_sorted = sorted(rows, key=lambda r: (r['lines'], r['heredocs']), reverse=True)
    print(json.dumps({
        'stage_count': len(rows),
        'largest_stages': rows_sorted[:15],
        'canonical_refs': [r for r in rows if r['canonical_refs']],
        'heavy_repo_ops': [r for r in rows if r['repo_ops'] > 0],
    }, indent=2, ensure_ascii=False))
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
