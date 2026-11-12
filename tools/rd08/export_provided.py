"""Run the stock release exporter with approved variants and no art generation.

Only the refresh step is replaced. The stock inventory/currentness, sanitized
copy hashes, release-template export and packed-asset verification still run.
"""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
import export_game


def require_provided(project, if_stale=False):
    if not (project / 'cel_look_variants/manifest.json').is_file():
        raise ValueError('Approved existing cel variants are required; this worker cannot generate art')


if __name__ == '__main__':
    export_game.build = require_provided
    raise SystemExit(export_game.main())
