"""Dispatch an inventoried native proof command. No window is opened with --dry-run."""
import argparse
import json
import os
from pathlib import Path
import shlex
import subprocess

BASE = Path(__file__).resolve().parents[1]
ROOT = Path(__file__).resolve().parents[5]

def main():
    inventory = json.loads((BASE / 'inventory.json').read_text())
    cases = inventory['windowed_commands']
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', required=True, choices=['all', *cases])
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    names = list(cases) if args.case == 'all' else [args.case]
    for name in names:
        item = cases[name]
        words = shlex.split(item['command'])
        if words[:3] != ['cd', str(ROOT), '&&']:
            raise ValueError('Unexpected proof worktree prefix: ' + name)
        words = words[3:]
        environment = os.environ.copy()
        while words and words[0].startswith('QA52_') and '=' in words[0]:
            key, value = words.pop(0).split('=', 1)
            environment[key] = value
        if 'tools/visual_probe_runner.py' not in words or '--no-headless' not in words:
            raise ValueError('Native proofs must use the visual runner: ' + name)
        print('\nQA52 NATIVE CASE: ' + name, flush=True)
        print(item['recipe'], flush=True)
        print(item['command'], flush=True)
        if not args.dry_run:
            result = subprocess.run(words, cwd=ROOT, env=environment)
            if result.returncode:
                return result.returncode
    print('QA52 NATIVE DISPATCH %s: %d commands; windows_opened=%s' % ('DRY RUN' if args.dry_run else 'COMPLETE', len(names), '0' if args.dry_run else 'see manifests'), flush=True)
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
