"""Serial bridge workflow for explicit fitted-figure folders; no hidden roster.

A refused or unanswered bridge job stops the workflow. Answered diagnostic
failures are retained so the owner can inspect every failed acceptance gate.
"""
import argparse
import json
from pathlib import Path
import sys

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))

from spec.art_identity.maquettes.blender.bridge_client import run_job
from spec.art_identity.maquettes.blender.compile_recipe import main as compile_recipe

WORKFLOW_DEFAULTS = {'job_timeout_s': 900}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folders', nargs='+', type=Path)
    parser.add_argument('--stage', choices=('build', 'capture', 'proof', 'all'), default='all')
    args = parser.parse_args()
    passed = True
    for raw in args.folders:
        folder = raw.resolve()
        if not folder.is_relative_to(PROJECT / 'spec/art_identity/maquettes'):
            raise ValueError('Figure folder is outside this worktree')
        proof = folder / 'proof'
        proof.mkdir(parents=True, exist_ok=True)
        spec = folder / 'spec_native.json'
        stages = []
        if args.stage in ('build', 'all'):
            compile_recipe(folder / 'measurements.json')
            stages.append(('build', 'build.py', [str(spec), str(proof), '--build-only']))
        if args.stage in ('capture', 'all'):
            for view in ('front', 'rear'):
                stages.append((view, 'capture_view.py', [str(spec), str(proof / 'maquette.blend'),
                                                       str(proof / view), view, '--diagnostic']))
        if args.stage in ('proof', 'all'):
            stages.append(('determinism', 'recipe_proof.py', [str(spec), str(proof / 'determinism')]))
        receipts_path = proof / 'bridge_receipts.json'
        receipts = json.loads(receipts_path.read_text()) if receipts_path.exists() else {}
        for name, script, values in stages:
            result = run_job(Path(__file__).with_name(script), values,
                             timeout_s=WORKFLOW_DEFAULTS['job_timeout_s'])
            receipts[name] = {key: value for key, value in result.items() if key != 'stdout'}
            receipts[name]['command'] = [sys.executable, '-B', str(Path(__file__).with_name('bridge_client.py')),
                '--timeout', str(WORKFLOW_DEFAULTS['job_timeout_s']),
                str(Path(__file__).with_name(script)), '--', *values]
            receipts_path.write_text(json.dumps(receipts, indent=2) + '\n')
            (proof / (name + '_bridge.log')).write_text(result['stdout'])
            print('FITTED_WORKFLOW: ' + folder.name + '/' + name + '; exit=' + str(result['exit']), flush=True)
            if result.get('refused'):
                raise ValueError('Bridge refused job: ' + str(result['refused']))
            passed &= result['exit'] == 0
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
