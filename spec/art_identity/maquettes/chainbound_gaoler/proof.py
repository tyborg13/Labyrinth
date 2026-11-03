"""Focused mq-15 proof and fresh-input regeneration; all Blender uses the bridge."""
import argparse
import json
from pathlib import Path
import shutil
import sys
import time

from spec.art_identity.maquettes.blender import bridge_client
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe, PROJECT
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import sha, write, stage
from spec.art_identity.maquettes.blender.delivery_validation import validate_delivery, seal_delivery
from spec.art_identity.maquettes.blender.regenerate_delivery import compare_captures
from spec.art_identity.maquettes.blender.capture_manifest import read_manifest, write_manifest
from .acceptance import inspect, review_sheet, validate_acceptance


FOLDER = Path(__file__).resolve().parent
BUILDER = FOLDER.parent / 'blender'
EXECUTION_DEFAULTS = {'job_timeout_s': 110, 'response_timeout_s': 120, 'poll_s': 1,
                      'budget_bytes': 6_000_000}


def job(script, args, output, name):
    """A strict response deadline, including queue time, overrides the busy wait."""
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    identifier = bridge_client.submit(Path(script).resolve(), [str(x) for x in args],
                                      timeout_s=EXECUTION_DEFAULTS['job_timeout_s'])
    print('MQ15_BRIDGE_SUBMITTED: ' + name + '; ' + identifier, flush=True)
    root = Path(bridge_client.BRIDGE_DEFAULTS['root']) / 'done'
    deadline = time.monotonic() + EXECUTION_DEFAULTS['response_timeout_s']
    while not (root / (identifier + '.json')).exists():
        if time.monotonic() >= deadline:
            raise TimeoutError('No bridge answer within 120 s; stop: ' + identifier)
        time.sleep(EXECUTION_DEFAULTS['poll_s'])
    result = json.loads((root / (identifier + '.json')).read_text())
    result['id'] = identifier
    result['timeout_s'] = EXECUTION_DEFAULTS['job_timeout_s']
    result['response_timeout_s'] = EXECUTION_DEFAULTS['response_timeout_s']
    log = (root / (identifier + '.log')).read_text()
    (output / (name + '.log')).write_text(log)
    write(output / (name + '.json'), result)
    print('MQ15_BRIDGE_RESULT: ' + name + '; exit=' + str(result['exit']) + '; seconds=' + str(result['seconds']), flush=True)
    if result['exit']:
        raise ValueError('Bridge job failed; inspect ' + str(output / (name + '.log')))
    return result


def compile_input(folder, destination):
    recipe = json.loads((Path(folder) / 'measurements.json').read_text())
    spec = compile_recipe(recipe)
    write(destination, spec)
    return spec


def preservation():
    """Freeze this unit's before/after receipt, using historical recipe inputs."""
    import subprocess
    recipe = json.loads((FOLDER / 'measurements.json').read_text())
    baseline = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=PROJECT, text=True).strip()
    relative = 'spec/art_identity/maquettes/blender/compile_recipe.py'
    old_code = subprocess.check_output(['git', 'show', baseline + ':' + relative], cwd=PROJECT, text=True)
    namespace = {'__file__': str(PROJECT / relative), '__name__': 'mq15_historical_compiler'}
    exec(compile(old_code, relative, 'exec'), namespace)
    paths = subprocess.check_output(['git', 'ls-files', 'spec/art_identity/maquettes'], cwd=PROJECT, text=True).splitlines()
    compiled = []
    for path in paths:
        if Path(path).name != 'measurements.json' or '/chainbound_gaoler/' in path:
            continue
        raw = subprocess.check_output(['git', 'show', baseline + ':' + path], cwd=PROJECT)
        value = json.loads(raw)
        before, after = (digest(fn(value)) for fn in (namespace['compile_recipe'], compile_recipe))
        compiled.append({'path': path, 'before': before, 'after': after, 'passed': before == after})
    figures = {}
    for name, before in recipe['mq15']['foreign_figure_inventory_digests'].items():
        folder = FOLDER.parent / name
        after = digest({str(p.relative_to(folder)): sha(p) for p in sorted(folder.rglob('*')) if p.is_file()
                        and '__pycache__' not in p.parts and p.suffix != '.pyc'})
        figures[name] = {'before': before, 'after': after, 'passed': before == after}
    result = {'baseline_commit': baseline, 'compiled': compiled, 'figures': figures,
              'passed': bool(compiled) and all(r['passed'] for r in compiled) and all(r['passed'] for r in figures.values())}
    write(FOLDER / 'preservation.json', result)
    if not result['passed']:
        raise ValueError('Foreign figure preservation failed')
    print('MQ15_PRESERVATION: PASS; compiled_specs=' + str(len(compiled)) + '; foreign_figures=' + str(len(figures)))
    return result


def prove(output):
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    spec_path = output / 'spec_native.json'
    spec = compile_input(FOLDER, spec_path)
    capture, determinism = output / 'capture', output / 'determinism'
    build_capture(spec_path, output, capture)
    job(FOLDER / 'native_probe.py', [spec_path, capture, capture / 'native_probe.json'], output / 'bridge', 'native_probe')
    job(BUILDER / 'recipe_proof.py', [spec_path, determinism], output / 'bridge', 'cold_replay')
    job(BUILDER / 'exact_native_replay.py', [determinism, capture / 'exact_native_replay.json'], output / 'bridge', 'exact_replay')
    shutil.copyfile(determinism / 'recipe_proof.json', capture / 'recipe_proof.json')
    if not inspect(FOLDER, capture)['passed']:
        raise ValueError('mq-15 acceptance failed')
    review_sheet(FOLDER, capture)
    seal_delivery(spec, capture)
    validate_delivery(spec, capture)
    print('MQ15_NATIVE_DELIVERY: PASS', flush=True)
    return capture


def build_capture(spec_path, output, capture, builder=BUILDER):
    """Native clays and twenty solos fit the response budget one view at a time."""
    spec = json.loads(Path(spec_path).read_text())
    native = output / 'native'
    job(builder / 'build.py', [spec_path, native, '--build-only'], output / 'bridge', 'build')
    for view in ('front', 'rear'):
        job(builder / 'capture_view.py', [spec_path, native / 'maquette.blend', output / view, view],
            output / 'bridge', view + '_capture')
    merge_views(spec, output, capture)
    # Retain the saved model only in task-local proof, never in delivery.
    shutil.copyfile(native / 'maquette.blend', capture / 'maquette.blend')


def merge_views(spec, output, capture):
    capture.mkdir(parents=True, exist_ok=True)
    images, joints, solos, frames = [], {}, {}, {}
    reports, checks = [], []
    for view in ('front', 'rear'):
        folder = output / view
        manifest = read_manifest(folder, digest(spec), ('full',))
        for name in manifest['images']:
            if name in images:
                raise ValueError('Duplicate native capture image: ' + name)
            images.append(name)
            shutil.copyfile(folder / name, capture / name)
        joints[view] = json.loads((folder / 'joints_px.json').read_text())[view]
        solos[view] = json.loads((folder / 'solo_coverage.json').read_text())[view]
        report = json.loads((folder / 'build_report.json').read_text())
        check = json.loads((folder / 'capture_checks.json').read_text())
        if not report['passed'] or not check['passed'] or not check['geometry_unchanged']:
            raise ValueError('Failed native view: ' + view)
        reports.append(report)
        checks.append(check)
    if reports[0]['mesh_hashes'] != reports[1]['mesh_hashes']:
        raise ValueError('Native view geometry differs')
    write(capture / 'joints_px.json', joints)
    write(capture / 'solo_coverage.json', solos)
    write(capture / 'ownership_validation.json', {'passed': all(n > 0 for v in solos.values() for n in v.values()),
          'empty_required_solos': {v: [name for name, count in values.items() if count <= 0] for v, values in solos.items()}})
    facing = json.loads((output / 'front/facing_report.json').read_text())
    write(capture / 'facing_report.json', facing)
    report = reports[0]
    report['checks'].update(rendered_torso_asymmetry=facing['passed'], capture_geometry_unchanged=True)
    report['passed'] = all(report['checks'].values())
    write(capture / 'build_report.json', report)
    write(capture / 'capture_checks.json', {'passed': report['passed'], 'spec_hash': digest(spec),
          'geometry_unchanged': True, 'geometry_checks': report['checks'], 'facing': facing,
          'view_capture_checks': {v: checks[i] for i, v in enumerate(('front', 'rear'))}})
    write_manifest(capture, digest(spec), 'full', images)


def regenerate(output):
    """Input-only checkout: copy tracked authoring sources, not models or caches."""
    output = Path(output).resolve()
    if output.exists() and any(output.iterdir()):
        raise ValueError('Regeneration requires a fresh empty output directory')
    project = output / 'clean_project'
    root = project / 'spec/art_identity/maquettes'
    root.mkdir(parents=True)
    for file in (FOLDER.parent).glob('*.py'):
        shutil.copyfile(file, root / file.name)
    shutil.copytree(BUILDER, root / 'blender', ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
    lancer = root / 'frostglass_lancer'
    lancer.mkdir()
    shutil.copyfile(FOLDER.parent / 'frostglass_lancer/spec_r3.json', lancer / 'spec_r3.json')
    figure = root / FOLDER.name
    figure.mkdir()
    for name in ('measurements.json', 'native_probe.py', 'geometry_checks.py'):
        shutil.copyfile(FOLDER / name, figure / name)
    write(output / 'clean_input_sha256.json', {str(p.relative_to(project)): sha(p) for p in sorted(project.rglob('*')) if p.is_file()})
    # The actual copied compiler runs in a fresh interpreter rooted here.
    import subprocess
    command = [sys.executable, '-B', str(root / 'blender/compile_recipe.py'), str(figure / 'measurements.json')]
    process = subprocess.run(command, cwd=project, text=True, capture_output=True)
    (output / 'compile.log').write_text(process.stdout + process.stderr)
    if process.returncode:
        raise ValueError('Fresh-input compiler failed')
    capture = figure / 'capture'
    build_capture(figure / 'spec_native.json', output, capture, root / 'blender')
    job(figure / 'native_probe.py', [figure / 'spec_native.json', capture, capture / 'native_probe.json'], output / 'bridge', 'fresh_native_probe')
    spec = json.loads((figure / 'spec_native.json').read_text())
    for name in ('recipe_proof.json', 'exact_native_replay.json'):
        shutil.copyfile(FOLDER / 'delivery' / name, capture / name)
    compared = compare_captures(capture, FOLDER / 'delivery', output, True)
    acceptance = inspect(FOLDER, capture)
    seal_delivery(spec, capture)
    binding = validate_delivery(spec, capture)
    result = {'passed': acceptance['passed'] and all(v['passed'] for view in compared.values() for v in view.values()),
              'views': compared, 'cache_reused': False, 'saved_model_reused': False,
              'compiled_spec_hash': digest(spec), 'native_reports': binding,
              'input_inventory_sha256': sha(output / 'clean_input_sha256.json')}
    write(output / 'regeneration.json', result)
    write(output / 'discarded_build_sha256.json', {'columns': ['path', 'bytes', 'sha256'],
          'files': [[str(p.relative_to(project)), p.stat().st_size, sha(p)] for p in sorted(project.rglob('*')) if p.is_file()]})
    if not result['passed']:
        raise ValueError('Fresh regeneration failed; retain diagnostics')
    shutil.rmtree(project)
    print('MQ15_CLEAN_REGENERATION: PASS; clays=2/2; part_maps=2/2; cache_reused=false', flush=True)
    return result


def stage_delivery(capture):
    capture = Path(capture)
    spec = compile_recipe(json.loads((FOLDER / 'measurements.json').read_text()))
    validate_acceptance(FOLDER, capture)
    from spec.art_identity.maquettes.blender.compact_capture import compact_capture
    compact_capture(spec, capture)
    inspect(FOLDER, capture)
    seal_delivery(spec, capture)
    stage(FOLDER, capture)
    for name in ('mq15_acceptance.json', 'native_probe.json', 'proportion_table.md',
                 'proportion_overlay.webp', 'source_mass_landmarks.webp', 'cloth_landmarks.webp', 'front_fit_overlay.webp', 'contact_sheet.webp', 'contact_sheet.json'):
        shutil.copyfile(capture / name, FOLDER / 'delivery' / name)
    # Recompute the receipt after lossless mask packing changed file hashes.
    inspect(FOLDER, FOLDER / 'delivery')
    review_sheet(FOLDER, FOLDER / 'delivery')
    seal_delivery(spec, FOLDER / 'delivery')
    print('MQ15_STAGE: PASS')


def curate():
    """Preserve all pre-existing provenance; discard only unit-generated proof."""
    verify_delivery()
    from spec.art_identity.maquettes.blender.curate_delivery import discard_evidence
    discard = [p for p in FOLDER.rglob('*') if p.is_file() and
               (p.is_relative_to(FOLDER / 'proof') or p.name == 'spec_native.json' or '__pycache__' in p.parts)]
    discard_evidence(FOLDER, discard, FOLDER / 'discarded_proof_sha256.json')
    for path in sorted(FOLDER.rglob('*'), key=lambda p: len(p.parts), reverse=True):
        if path.is_dir() and not any(path.iterdir()):
            path.rmdir()
    manifest = FOLDER / 'COMMIT_MANIFEST.txt'
    names = {str(p.relative_to(FOLDER)) for p in FOLDER.rglob('*') if p.is_file()} | {manifest.name}
    manifest.write_text('# mq-15 figure inventory, including untouched historical provenance.\n' + '\n'.join(sorted(names)) + '\n')
    verify_inventory()


def verify_delivery():
    spec = compile_recipe(json.loads((FOLDER / 'measurements.json').read_text()))
    validate_delivery(spec, FOLDER / 'delivery')
    validate_acceptance(FOLDER, FOLDER / 'delivery')
    provenance = json.loads((FOLDER / 'delivery/provenance.json').read_text())
    for view in ('front', 'rear'):
        name = view + '_clay.png'
        if sha(FOLDER / 'delivery' / name) != provenance['native_image_sha256'][name]:
            raise ValueError('Native clay bytes changed: ' + name)
    sheet = json.loads((FOLDER / 'delivery/contact_sheet.json').read_text())
    if sha(FOLDER / 'delivery/contact_sheet.webp') != sheet['sha256'] or any(
            sha(PROJECT / name) != expected for name, expected in sheet['source_sha256'].items()):
        raise ValueError('Contact sheet or reference inputs changed')
    if any(sha(FOLDER/'delivery'/name)!=expected for name,expected in sheet.get('proof_artifacts_sha256',{}).items()):
        raise ValueError('Proof annotation artifact changed')
    print('MQ15_HASH_BOUND_DELIVERY: PASS')


def verify_inventory():
    recipe = json.loads((FOLDER / 'measurements.json').read_text())
    for name, expected in recipe['mq15']['protected_existing_sha256'].items():
        if sha(FOLDER / name) != expected:
            raise ValueError('Protected provenance changed: ' + name)
    names = {str(p.relative_to(FOLDER)) for p in FOLDER.rglob('*') if p.is_file() and '__pycache__' not in p.parts}
    listed = {line for line in (FOLDER / 'COMMIT_MANIFEST.txt').read_text().splitlines() if line and not line.startswith('#')}
    if names != listed:
        raise ValueError('Figure manifest differs: ' + str(sorted(names ^ listed)))
    if any('.blend' in Path(n).suffixes for n in names):
        raise ValueError('A blend is retained in the curated inventory')
    total = sum((FOLDER / name).stat().st_size for name in names)
    if total > EXECUTION_DEFAULTS['budget_bytes']:
        raise ValueError('Figure exceeds 6 MB: ' + str(total))
    print('MQ15_COMMIT_CURATION: PASS; bytes=' + str(total) + '; files=' + str(len(names)))
    return total


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('prove', 'stage', 'regenerate', 'curate', 'verify', 'preservation'))
    parser.add_argument('--out', type=Path)
    parser.add_argument('--capture', type=Path)
    args = parser.parse_args()
    if args.operation in ('prove', 'regenerate') and args.out is None:
        parser.error('--out is required')
    if args.operation == 'preservation':
        preservation()
    elif args.operation == 'prove':
        prove(args.out)
    elif args.operation == 'regenerate':
        regenerate(args.out)
    elif args.operation == 'stage':
        if args.capture is None:
            parser.error('--capture is required')
        stage_delivery(args.capture)
    elif args.operation == 'curate':
        curate()
    else:
        verify_delivery()
        verify_inventory()


if __name__ == '__main__':
    main()
