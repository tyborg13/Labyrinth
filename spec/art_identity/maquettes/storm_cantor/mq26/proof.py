"""Owner-run bridge proof for mq-26: prove, regenerate, stage, verify.

No direct Blender invocation or window-server use; every native job goes
through the director's bridge with mq-17's 110 s execution / 120 s response limits.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import sha, write
from spec.art_identity.maquettes.blender.delivery_validation import seal_delivery, validate_delivery
from spec.art_identity.maquettes.blender.compact_capture import compact_capture
from spec.art_identity.maquettes.blender.regenerate_delivery import compare_captures
from ..bridge import job
from ..mq19.capture_workflow import capture
from ..mq19.proof import input_inventory as mq19_inventory
from ..recipe import PROJECT, FOLDER as BASE
from .recipe import FOLDER, compile_spec
from .checks import observe
from .delivery import inspect, review_sheet, DELIVERY_DEFAULTS, SHEETS

BUILDER = BASE.parent / 'blender'
GENERIC = ('faceted_forms.py', 'plate_cop.py', 'hand_v3.py', 'joint_sphericity.py')
DELIVERY = FOLDER / 'delivery'
BUNDLE_EXCLUDE = ('_raw_png',)


def input_inventory():
    paths = {PROJECT / name for name in mq19_inventory()} | set(FOLDER.glob('*.py')) | {FOLDER / 'design.json'}
    paths |= {BUILDER / name for name in GENERIC}
    return {str(p.relative_to(PROJECT)): sha(p) for p in sorted(paths)}


def fresh(output):
    output = Path(output).resolve()
    if output.exists() and any(output.iterdir()): raise ValueError('Proof requires a fresh empty output directory')
    output.mkdir(parents=True, exist_ok=True)
    return output


def portable_report(spec):
    points = {p['id'] + '_render': p['vertices'] for p in spec['pieces']}
    faces = {p['id'] + '_render': p['faces'] for p in spec['pieces']}
    return observe(spec, points, spec['joints'], spec['mq19']['bone_forward'], faces)


def build_capture(spec_path, output, local=FOLDER):
    job(local / 'native.py', ['build', spec_path, output / 'native', '--build-only'], output / 'bridge', 'build')
    job(local / 'native.py', ['audit', spec_path, output / 'native', output / 'native/mq26_native.json'], output / 'bridge', 'native_audit')
    result = capture(spec_path, output, local)
    shutil.copyfile(output / 'native/mq26_native.json', result / 'mq26_native.json')
    return result


def prove(output):
    spec = compile_spec(); inventory = input_inventory()
    portable = portable_report(spec)
    if not portable['passed']:
        raise ValueError('mq-26 portable acceptance failed: ' + str([k for k, v in portable['checks'].items() if not v]))
    output = fresh(output)
    path = output / 'spec_native.json'; write(path, spec)
    write(output / 'portable_acceptance.json', portable)
    result = build_capture(path, output)
    if not inspect(spec, result)['passed']: raise ValueError('mq-26 native acceptance failed')
    job(FOLDER / 'native.py', ['determinism', path, output / 'determinism'], output / 'bridge', 'determinism')
    job(BUILDER / 'exact_native_replay.py', [output / 'determinism', result / 'exact_native_replay.json'], output / 'bridge', 'exact_replay')
    shutil.copyfile(output / 'determinism/recipe_proof.json', result / 'recipe_proof.json')
    if inventory != input_inventory(): raise ValueError('Sources changed during proof')
    write(output / 'input_sha256.json', inventory); review_sheet(result)
    compact_capture(spec, result); inspect(spec, result); seal_delivery(spec, result); validate_delivery(spec, result)
    print('MQ26_NATIVE_DELIVERY: PASS; ' + str(result))


def regenerate(reference, output):
    """Copied inputs only, a fresh build and empty caches; clays and maps must match."""
    spec = compile_spec(); reference = Path(reference).resolve()
    validate_delivery(spec, reference)
    inventory = input_inventory(); output = Path(output).resolve()
    if not output.is_relative_to(BASE.parent.resolve()):
        raise ValueError('Clean bridge scripts must stay under the worktree maquette root; use mq26/proof/<run>')
    output = fresh(output); project = output / 'clean_project'
    for name in inventory:
        target = project / name; target.parent.mkdir(parents=True, exist_ok=True); shutil.copyfile(PROJECT / name, target)
    copied = {str(p.relative_to(project)): sha(p) for p in project.rglob('*') if p.is_file()}
    if copied != inventory: raise ValueError('Clean input copy differs')
    local = project / FOLDER.relative_to(PROJECT); path = output / 'spec_native.json'
    command = [sys.executable, '-B', '-m', 'spec.art_identity.maquettes.storm_cantor.mq26.recipe', '--out', str(path)]
    process = subprocess.run(command, cwd=project, text=True, capture_output=True)
    (output / 'compile.log').write_text(process.stdout + process.stderr)
    if process.returncode: raise ValueError('Clean copied compiler failed')
    if json.loads(path.read_text()) != spec: raise ValueError('Clean compiler differs')
    result = build_capture(path, output, local)
    compared = compare_captures(result, reference, output, True)
    receipt = {'passed': all(v['passed'] for r in compared.values() for v in r.values()),
               'spec_hash': digest(spec), 'input_sha256': inventory, 'views': compared,
               'cache_reused': False, 'saved_model_reused': False, 'compile_returncode': process.returncode,
               'native_probe_sha256': sha(result / 'mq26_native.json'), 'native_manifest_sha256': sha(result / 'capture_manifest.json')}
    write(output / 'regeneration.json', receipt)
    if not receipt['passed']: raise ValueError('Fresh mq-26 regeneration differs')
    if inventory != input_inventory(): raise ValueError('Source inventory changed during regeneration')
    print('MQ26_CLEAN_REGENERATION: PASS; clays=2/2; part_maps=2/2; cache_reused=false')


def stage(reference, regeneration):
    """Copy the sealed capture into mq26/delivery with an explicit hash inventory."""
    spec = compile_spec(); reference = Path(reference); regeneration = Path(regeneration)
    validate_delivery(spec, reference)
    if not inspect(spec, reference, False)['passed']: raise ValueError('Failed native acceptance')
    receipt = json.loads((regeneration / 'regeneration.json').read_text()); inventory = input_inventory()
    if (receipt['input_sha256'] != inventory or receipt['spec_hash'] != digest(spec) or receipt['passed'] is not True or
            receipt['cache_reused'] is not False or receipt['saved_model_reused'] is not False):
        raise ValueError('Stale or incomplete regeneration receipt')
    expected = compare_captures(regeneration / 'capture', reference, regeneration, True)
    if expected != receipt['views']: raise ValueError('Regeneration comparison no longer binds current delivery')
    files = {p.name: p.read_bytes() for p in reference.iterdir() if p.is_file()}
    files['regeneration.json'] = (regeneration / 'regeneration.json').read_bytes()
    files['clean_input_sha256.json'] = (json.dumps(inventory, sort_keys=True) + '\n').encode()
    files['bundle_sha256.json'] = (json.dumps({n: hashlib.sha256(d).hexdigest() for n, d in sorted(files.items())}, sort_keys=True) + '\n').encode()
    size = sum(len(d) for d in files.values())
    if size > DELIVERY_DEFAULTS['budget_bytes']: raise ValueError('Curated delivery exceeds 6 MB: ' + str(size))
    if DELIVERY.exists(): shutil.rmtree(DELIVERY)
    DELIVERY.mkdir()
    for name, data in files.items(): (DELIVERY / name).write_bytes(data)
    manifest = '# mq-26 curated delivery; native clays byte-copied; no model/cache; 6,000,000-byte maximum.\n' + \
        '\n'.join(sorted('delivery/' + n for n in files)) + '\n'
    (FOLDER / 'COMMIT_MANIFEST.txt').write_text(manifest + '\n'.join(sorted(str(p.relative_to(FOLDER)) for p in FOLDER.iterdir()
                                                                          if p.is_file() and p.name != 'COMMIT_MANIFEST.txt' and p.suffix in ('.py', '.json', '.md'))) + '\nCOMMIT_MANIFEST.txt\n')
    print('MQ26_CURATED_DELIVERY: PASS; bytes=' + str(size) + '; files=' + str(len(files)))


def verify():
    """Read-only: delivery bytes, seals, native acceptance and current guards."""
    spec = compile_spec(); bundle = DELIVERY
    hashes = json.loads((bundle / 'bundle_sha256.json').read_text())
    names = {p.name for p in bundle.iterdir() if p.is_file()}
    if names != set(hashes) | {'bundle_sha256.json'}: raise ValueError('mq-26 delivery inventory differs')
    if any(sha(bundle / n) != v for n, v in hashes.items()): raise ValueError('mq-26 delivery bytes changed')
    size = sum((bundle / n).stat().st_size for n in names)
    if size > DELIVERY_DEFAULTS['budget_bytes']: raise ValueError('mq-26 delivery exceeds 6 MB')
    listed = {l[len('delivery/'):] for l in (FOLDER / 'COMMIT_MANIFEST.txt').read_text().splitlines() if l.startswith('delivery/')}
    if listed != names: raise ValueError('mq-26 commit manifest differs from the delivery')
    validate_delivery(spec, bundle)
    accepted = inspect(spec, bundle, False)
    if not accepted['passed']: raise ValueError('mq-26 retained native acceptance failed')
    for stem in SHEETS:
        sheet = json.loads((bundle / (stem + '.json')).read_text())
        if sha(bundle / (stem + '.webp')) != sheet['sheet_sha256']: raise ValueError('Stale mq-26 contact sheet: ' + stem)
        for item in sheet['inputs']:
            path = bundle / item['path'] if Path(item['path']).parent == Path('.') else PROJECT / item['path']
            if sha(path) != item['sha256']: raise ValueError('Stale mq-26 review source: ' + str(path))
    receipt = json.loads((bundle / 'regeneration.json').read_text())
    if (receipt['passed'] is not True or receipt['spec_hash'] != digest(spec) or receipt['cache_reused'] is not False or
            receipt['input_sha256'] != input_inventory() or receipt['native_probe_sha256'] != sha(bundle / 'mq26_native.json')):
        raise ValueError('Stale or failed mq-26 regeneration')
    report = portable_report(spec)
    if not report['passed']: raise ValueError('mq-26 current geometry guards failed')
    print('MQ26_DELIVERY_VERIFY: PASS; files=' + str(len(names)) + '; bytes=' + str(size) + '; accepted=true; director_accepted_rows=' +
          ','.join(report['director_accepted_rows']), flush=True)
    return accepted


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('prove', 'regenerate', 'stage', 'verify'))
    parser.add_argument('--out', type=Path); parser.add_argument('--capture', type=Path); parser.add_argument('--regeneration', type=Path)
    args = parser.parse_args()
    if args.operation == 'verify': verify(); return
    if args.operation == 'prove':
        if args.out is None: parser.error('--out is required')
        prove(args.out)
    elif args.operation == 'regenerate':
        if args.out is None or args.capture is None: parser.error('--out and --capture are required')
        regenerate(args.capture, args.out)
    else:
        if args.capture is None or args.regeneration is None: parser.error('--capture and --regeneration are required')
        stage(args.capture, args.regeneration)


if __name__ == '__main__': main()
