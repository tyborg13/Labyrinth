"""Untracked timing history used only to schedule Python modules."""
import json
from pathlib import Path
import subprocess
import tempfile


def history_path(root):
    common = Path(subprocess.check_output(
        ['git', 'rev-parse', '--git-common-dir'], cwd=root, text=True).strip())
    return (Path(root) / common).resolve() / 'labyrinth-test-timings/python-suite.json'


def read_history(path):
    try:
        return json.loads(Path(path).read_text())
    except (OSError, ValueError):
        return {}


def write_history(path, record):
    previous = read_history(path)
    modules = previous.get('modules', {}) if isinstance(previous, dict) else {}
    if not isinstance(modules, dict):
        modules = {}
    # A filtered run supplies only selected modules. Keep learned costs for
    # skipped input groups so the next everything run still balances them.
    record = dict(record, modules={**modules, **record['modules']})
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, delete=False) as handle:
        temporary = Path(handle.name)
        json.dump(record, handle, sort_keys=True)
    try:
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)
