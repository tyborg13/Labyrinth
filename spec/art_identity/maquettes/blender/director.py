#!/usr/bin/env python3
"""Print/run mq-03 Blender proof commands, without retries or windowed fallbacks."""
import argparse
import hashlib
import json
from pathlib import Path
import shlex
import subprocess
import sys

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))
from spec.art_identity.maquettes.blender.backend import DEFAULT_BLENDER, command
from spec.art_identity.maquettes.blender.contract import digest, todos


PROOF_DEFAULTS = {'out': '/private/tmp/labyrinth_codex/mq-03/director',
                  'timeout_seconds': 3600, 'size': [1024, 1024]}


def commands(spec, output, blender, bundle=None):
    source = PROJECT / json.loads(spec.read_text())['fit']['source']
    integration = [sys.executable, str(Path(__file__).with_name('bridge_client.py')),
                   str(Path(__file__).with_name('integration.py')), '--', str(output / 'integration')]
    fit_tool = [sys.executable, str(PROJECT / 'tools/maquette_fit.py')]
    common = ['--spec', str(spec), '--source', str(source)]
    fit = fit_tool + ['fit', *common, '--out', str(output / 'fit'), '--blender', str(blender)]
    if bundle:
        fit += ['--bundle', str(bundle)]
    fitted = output / 'fit/spec_fit.json'
    return [integration,
            command(spec, output / 'lancer_r3', blender, bundle, gallery=True),
            fit_tool + ['measure', *common, '--renders', str(output / 'lancer_r3'), '--out', str(output / 'measure'), '--require-gate'],
            fit,
            command(fitted, output / 'lancer_r3_fit', blender, bundle, gallery=True),
            fit_tool + ['measure', '--spec', str(fitted), '--source', str(source), '--renders', str(output / 'lancer_r3_fit'),
                        '--out', str(output / 'measure_fit'), '--require-gate']]


def proof_contract(spec, output):
    images = [f'{view}_{mode}.png' for view in ('front', 'rear') for mode in ('parts', 'clay', 'silhouette')]
    images += ['front_torso.png', 'front_torso_frontal_control.png']
    images += [f'{view}_solo_{part}.png' for view in ('front', 'rear') for part in spec['labels']]
    images += [f'piece_gallery/{view}_{kind}.png' for view in ('front', 'rear')
               for kind in ('plate', 'lames', 'cloth', 'curve', 'crystal', 'gem')]
    return {'spec_hash': digest(spec), 'size': PROOF_DEFAULTS['size'],
            'required_images': images, 'required_json': ['joints_px.json', 'build_report.json', 'facing_report.json'],
            'inspection': 'Source overlay, front/rear ownership and clay, per-type gallery; no game scene fixture applies',
            'output': str(output)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--print-only', action='store_true')
    parser.add_argument('--blender', default=DEFAULT_BLENDER)
    parser.add_argument('--bundle', type=Path)
    parser.add_argument('--out', type=Path, default=Path(PROOF_DEFAULTS['out']))
    parser.add_argument('--spec', type=Path, default=PROJECT / 'spec/art_identity/maquettes/frostglass_lancer/spec_r3.json')
    args = parser.parse_args()
    spec = json.loads(args.spec.read_text())
    cmds = commands(args.spec.resolve(), args.out.resolve(), args.blender, args.bundle)
    for cmd in cmds:
        print(f'cd {shlex.quote(str(PROJECT))} && {shlex.join(cmd)}', flush=True)
    if args.print_only:
        return 0
    args.out.mkdir(parents=True, exist_ok=True)
    contract = proof_contract(spec, args.out / 'lancer_r3')
    (args.out / 'proof_contract.json').write_text(json.dumps(contract, indent=2) + '\n')
    results = []
    if todos(spec):
        print('MQ03_PROOF: BLOCKED by unresolved design fields', file=sys.stderr)
        (args.out / 'unresolved_design.json').write_text(json.dumps(todos(spec), indent=2) + '\n')
        return 2
    for i, cmd in enumerate(cmds):
        try:
            result = subprocess.run(cmd, cwd=PROJECT, text=True, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, timeout=PROOF_DEFAULTS['timeout_seconds'])
            code, log = result.returncode, result.stdout
        except (OSError, subprocess.TimeoutExpired) as error:
            code, log = 2, str(error)
        (args.out / f'command_{i}.log').write_text(log)
        results.append({'command': cmd, 'returncode': code})
        # The initial proportion gate is diagnostic: still attempt the fitter.
        if code and i != 2:
            break
    captures = {}
    from PIL import Image
    for relative in contract['required_images']:
        path = args.out / 'lancer_r3' / relative
        if not path.is_file():
            continue
        with Image.open(path) as image:
            if list(image.size) != contract['size']:
                raise ValueError('Wrong proof dimensions: ' + str(path))
        captures[relative] = hashlib.sha256(path.read_bytes()).hexdigest()
    passed = len(results) == len(cmds) and all(r['returncode'] == 0 for i, r in enumerate(results) if i != 2)
    passed &= len(captures) == len(contract['required_images'])
    (args.out / 'proof_manifest.json').write_text(json.dumps({'passed': passed, 'commands': results,
        'capture_sha256': captures, 'contract': contract}, indent=2) + '\n')
    print('MQ03_PROOF: ' + ('PASS' if passed else 'FAIL'))
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
