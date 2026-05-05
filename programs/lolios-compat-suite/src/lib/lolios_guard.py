#!/usr/bin/env python3
"""Runtime guard for LoliOS-only user tools.

This is not DRM. It is a distro-boundary guard: LoliOS-branded centers should
not accidentally run on unsupported distributions. The compatibility backend can
remain testable, but Game Center and App Center require LoliOS markers.

Developer override for repository testing:
    LOLIOS_DEV_ALLOW_NON_LOLIOS=1 lolios-gaming-center --json

Staged ISO audit override:
    LOLIOS_ROOT=/path/to/airootfs python3 /path/to/lolios_guard.py
"""
from __future__ import annotations

import json
import os
import pathlib
import sys
from typing import Any

REQUIRED_ID = 'lolios'
REQUIRED_NAME = 'LoliOS'


def _root() -> pathlib.Path:
    raw = os.environ.get('LOLIOS_ROOT', '/') or '/'
    root = pathlib.Path(raw)
    return root if root.is_absolute() else pathlib.Path('/') / root


def _inside_root(path: str) -> pathlib.Path:
    root = _root()
    rel = path.lstrip('/')
    return root / rel


def _os_release_paths() -> list[pathlib.Path]:
    return [_inside_root('/etc/os-release'), _inside_root('/usr/lib/os-release')]


def _product_file() -> pathlib.Path:
    return _inside_root('/usr/share/lolios/product.json')


def _live_marker() -> pathlib.Path:
    return _inside_root('/etc/lolios-live')


def _parse_os_release() -> dict[str, str]:
    data: dict[str, str] = {}
    for path in _os_release_paths():
        if not path.exists():
            continue
        for raw in path.read_text(errors='ignore').splitlines():
            line = raw.strip()
            if not line or line.startswith('#') or '=' not in line:
                continue
            key, value = line.split('=', 1)
            data[key] = value.strip().strip('"')
        if data:
            break
    return data


def _read_product() -> dict[str, Any]:
    product_file = _product_file()
    if not product_file.exists():
        return {}
    try:
        data = json.loads(product_file.read_text(encoding='utf-8'))
    except Exception:
        return {}
    return data if isinstance(data, dict) else {}


def _product_is_valid(product: dict[str, Any]) -> bool:
    if product.get('id') != REQUIRED_ID:
        return False
    name = str(product.get('name', ''))
    if name != REQUIRED_NAME:
        return False
    exclusive = product.get('exclusive_tools', [])
    if exclusive and not isinstance(exclusive, list):
        return False
    return True


def _os_release_is_lolios(osr: dict[str, str]) -> bool:
    ids = {osr.get('ID', '').lower()}
    ids.update(x.lower() for x in osr.get('ID_LIKE', '').split())
    name = osr.get('NAME', '').lower()
    pretty = osr.get('PRETTY_NAME', '').lower()
    return REQUIRED_ID in ids or 'lolios' in name or 'lolios' in pretty


def is_lolios() -> bool:
    if os.environ.get('LOLIOS_DEV_ALLOW_NON_LOLIOS') == '1':
        return True

    product = _read_product()
    valid_product = _product_is_valid(product)

    # Live ISO is allowed only when the LoliOS product marker is also valid. This
    # prevents a random system from passing the check just by creating /etc/lolios-live.
    if _live_marker().exists() and valid_product:
        return True

    # Installed LoliOS and staged airootfs audits: product marker is authoritative.
    if valid_product:
        return True

    return False


def guard_status() -> dict[str, Any]:
    osr = _parse_os_release()
    product = _read_product()
    product_file = _product_file()
    live_marker = _live_marker()
    return {
        'ok': is_lolios(),
        'root': str(_root()),
        'dev_override': os.environ.get('LOLIOS_DEV_ALLOW_NON_LOLIOS') == '1',
        'live_marker': live_marker.exists(),
        'live_marker_path': str(live_marker),
        'product_file': str(product_file),
        'product_exists': product_file.exists(),
        'product_valid': _product_is_valid(product),
        'product': product,
        'os_release_is_lolios': _os_release_is_lolios(osr),
        'os_release': {
            'ID': osr.get('ID', ''),
            'ID_LIKE': osr.get('ID_LIKE', ''),
            'NAME': osr.get('NAME', ''),
            'PRETTY_NAME': osr.get('PRETTY_NAME', ''),
        },
    }


def require_lolios(tool_name: str = 'LoliOS tool') -> None:
    if is_lolios():
        return
    status = guard_status()
    msg = (
        f'{tool_name} is only supported on LoliOS.\n'
        f'Missing or invalid product marker: {status["product_file"]}\n'
        f'Expected product id={REQUIRED_ID!r}, name={REQUIRED_NAME!r}.\n'
        'For repository development/testing only, run with LOLIOS_DEV_ALLOW_NON_LOLIOS=1.\n'
        f'Detected status: root={status["root"]}, product_exists={status["product_exists"]}, '
        f'product_valid={status["product_valid"]}, live_marker={status["live_marker"]}, '
        f'os_release_is_lolios={status["os_release_is_lolios"]}'
    )
    print(msg, file=sys.stderr)
    raise SystemExit(72)


if __name__ == '__main__':
    print(json.dumps(guard_status(), indent=2, ensure_ascii=False))
    raise SystemExit(0 if is_lolios() else 72)
