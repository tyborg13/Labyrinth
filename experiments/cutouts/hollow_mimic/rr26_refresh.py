"""Refresh consolidation evidence through existing headless unit entrypoints."""
import argparse
import os
from pathlib import Path
import subprocess
import sys

from case import ROOT, CASE, read_json, write_json, digest
from rest_space_proof import RIGS

LOG = CASE / 'proof/logs/rr26f3'
PYTHON = sys.executable
TASK_ID = 'rr-26'
SCRIPTS = {'seer': 'rr10', 'thrall': 'rr11', 'mirror': 'rr18', 'mimic': 'rr20',
           'weaver': 'rr21', 'mortar': 'rr22', 'capacitor': 'rr17'}
GATES = {'seer': 'hoarfrost_seer/rr10_gates.py', 'thrall': 'arc_thrall/rr11_gates.py',
         'mirror': 'glacial_mirror/rr18_gates.py', 'mimic': 'hollow_mimic/gates.py',
         'weaver': 'briar_weaver/rr21_gates.py', 'mortar': 'slag_mortar/rr22_gates.py',
         'capacitor': 'storm_capacitor/rr17_gates.py'}


def godot(script, *args):
    return [PYTHON, 'tools/godot_task_runner.py', '--task-id', TASK_ID, '--stream', '--',
            'godot', '--headless', '--path', '.', '--script', script, '--', *map(str, args)]


def commands(stage, rig):
    case = ROOT / 'experiments/cutouts' / RIGS[rig]
    rr = SCRIPTS[rig]
    if stage == 'samples':
        script = 'action_direction.gd' if rig in ('thrall', 'mirror') else 'samples.gd'
        relative = {'weaver': 'logs/samples.json', 'mortar': 'logs/samples_full.json'}.get(rig, 'samples.json')
        result = [godot(f'tests/{rr}/{script}', '--case', case, '--output', case / 'proof' / relative)]
        if rig == 'weaver': result.append([PYTHON, '-B', 'experiments/cutouts/briar_weaver/rr21_evidence.py'])
        if rig == 'mortar': result.append([PYTHON, '-B', 'experiments/cutouts/slag_mortar/rr22_records.py', 'samples'])
        return result
    if stage == 'gates':
        return [[PYTHON, '-B', 'experiments/cutouts/' + GATES[rig], *(['headless'] if rig == 'capacitor' else [])]]
    if stage == 'census':
        relative = {'weaver': 'logs/samples.json', 'mortar': 'logs/samples_full.json',
                    'mimic': 'logs/samples.full.json'}.get(rig, 'samples.json')
        return [[PYTHON, '-u', '-B', 'experiments/cutouts/hollow_mimic/rest_space_proof.py',
                 '--rig', rig, '--samples', str(case / 'proof' / relative)]]
    if stage == 'production':
        unit = RIGS[rig].split('/')[0]
        result = []
        for view in (('front',) if rig in ('seer', 'capacitor') else ('front', 'rear')):
            cards = ('whirlwind_slash', 'quick_stab', 'hurl_spear') if rig == 'mimic' else ('',)
            for card in cards:
                flags = []
                output = case / f'proof/logs/rr26f3_production_{view}'
                if rig in ('thrall', 'mirror', 'mimic'): flags += ['--view', view]
                if rig == 'weaver':
                    output = case / 'proof/logs/production' / view
                    if view == 'rear': flags += ['--rear']
                if rig == 'mortar':
                    output = case / ('proof/logs/production_logic' + ('_rear' if view == 'rear' else ''))
                    if view == 'rear': flags += ['--opposite']
                if rig == 'thrall' and view == 'front': output = case / 'proof/production_logic'
                if rig == 'capacitor': output = case / 'proof/production_logic'
                if rig == 'mimic':
                    output = case / 'proof/production_logic' / view / card
                    flags += ['--mirror-card', card]
                result.append(godot(f'tests/{rr}/production_capture.gd', '--type', unit,
                                    '--output', output, '--logic-only', *flags))
        if rig == 'mortar': result.append([PYTHON, '-B', 'experiments/cutouts/slag_mortar/rr22_records.py', 'production'])
        return result
    raise ValueError(stage)


def coverage():
    from gates import COVERAGE_PREFIXES, COVERAGE_FILES
    result = {}
    for name, expected in read_json(CASE / 'protected_inputs.json').items():
        current = digest(ROOT / name)
        if current == expected: continue
        if not (name in COVERAGE_FILES or name.startswith(COVERAGE_PREFIXES)):
            raise ValueError('Unapproved protected path: ' + name)
        result[name] = {'before_sha256': expected, 'after_sha256': current}
    write_json(CASE / 'rr26_source_coverage.json', result)
    print('RR26 EXACT AUTHORIZED COVERAGE: %d fixed before/after hashes; original ledger unchanged' % len(result))


def policy_bindings():
    path = ROOT / 'experiments/cutouts/arc_thrall/rr11/rr24_policy.json'
    record = read_json(path)
    owned = {'experiments/cutouts/arc_thrall/rr24_check.py',
             'experiments/cutouts/arc_thrall/rr24_native_gates.py'}
    changed = []
    for name, expected in record['implementation_sha256'].items():
        current = digest(ROOT / name)
        if current == expected: continue
        if name not in owned: raise ValueError('Unexpected policy implementation change: ' + name)
        record['implementation_sha256'][name] = current
        changed.append(name)
    write_json(path, record)
    print('RR26 THRALL POLICY BINDINGS: %d implementation digests refreshed; policy values unchanged' % len(changed))


def run(stage, rig):
    LOG.mkdir(parents=True, exist_ok=True)
    environment = dict(os.environ, LABYRINTH_TASK_ID=TASK_ID, OPENBLAS_NUM_THREADS='1', VECLIB_MAXIMUM_THREADS='1')
    environment['PYTHONPATH'] = str(ROOT / 'tools')
    rows = []
    with (LOG / f'{stage}_{rig}.log').open('w') as log:
        for command in commands(stage, rig):
            print('RR26 COMMAND: ' + ' '.join(command), flush=True)
            process = subprocess.Popen(command, cwd=ROOT, env=environment, stdout=subprocess.PIPE,
                                       stderr=subprocess.STDOUT, text=True)
            for line in process.stdout:
                log.write(line)
                print(line, end='', flush=True)
            code = process.wait()
            rows.append({'command': command, 'exit_code': code})
            if code: break
    write_json(LOG / f'{stage}_{rig}.json', rows)
    code = rows[-1]['exit_code']
    print('RR26 REFRESH %s %s: %s' % (stage.upper(), rig.upper(), 'FAIL' if code else 'PASS'), flush=True)
    return code


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage', choices=('samples', 'gates', 'production', 'census', 'coverage', 'policy-bindings'))
    parser.add_argument('--rig', choices=RIGS)
    args = parser.parse_args()
    if args.stage == 'coverage': coverage()
    elif args.stage == 'policy-bindings': policy_bindings()
    else:
        if not args.rig: parser.error('--rig is required')
        raise SystemExit(run(args.stage, args.rig))
