"""mq-12 bridge-only pose proof. Failed gates cannot replace delivery.

Run from the project root with ``python3 -B -m
spec.art_identity.maquettes.gale_herald.shoulder_workflow FIGURE OPERATION``.
The original mq-04 delivery remains authoritative until all gates pass.
"""
import argparse
import json
from pathlib import Path
import shutil

from spec.art_identity.maquettes.blender.bridge_client import run_job
from spec.art_identity.maquettes.blender.capture_manifest import read_manifest, write_manifest
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.contract import digest, BUILD_DEFAULTS
from spec.art_identity.maquettes.blender.curate_delivery import sha, write
from spec.art_identity.maquettes.blender.regenerate_delivery import compare_captures
from spec.art_identity.maquettes.glacial_mirror.regeneration_inputs import clean_inputs, input_builder

ROOT = Path(__file__).resolve().parent.parent
BUILDER = ROOT / 'blender'
PROBE = Path(__file__).with_name('native_probe.py')
WORKFLOW_DEFAULTS = {'timeout_s': 110, 'solo_batch_size': 5, 'joint_error_m': 1e-4}


def job(script, args, receipt, resume=False, diagnostic=False):
    receipt = Path(receipt)
    command = [str(Path(script).resolve()), *map(str, args)]
    inputs = {str(p): sha(p) for p in [Path(script), Path(args[0])] if p.is_file()}
    revision = digest({str(p.relative_to(BUILDER)): sha(p) for p in sorted(BUILDER.rglob('*.py'))})
    if resume and receipt.is_file():
        prior = json.loads(receipt.read_text())
        if (prior['requested'] == command and prior['input_sha256'] == inputs and
                prior['builder_revision'] == revision and prior['exit'] == 0):
            return prior
    result = run_job(script, args, timeout_s=WORKFLOW_DEFAULTS['timeout_s'])
    write(receipt, {**{k: v for k, v in result.items() if k != 'stdout'},
                    'requested': command, 'input_sha256': inputs, 'builder_revision': revision})
    receipt.with_suffix('.log').write_text(result['stdout'])
    print('MQ12_BRIDGE: ' + receipt.stem + '; exit=' + str(result['exit']), flush=True)
    if result.get('refused') or result['exit'] not in ((0, 1) if diagnostic else (0,)):
        raise ValueError('Bridge job failed: ' + str(receipt))
    return result


def capture(spec_path, build, output, resume=False, preview=False):
    spec = json.loads(spec_path.read_text())
    batches = []
    for view in ('front', 'rear'):
        selections = [('preview', [])]
        if not preview:
            labels, count = list(spec['labels']), WORKFLOW_DEFAULTS['solo_batch_size']
            selections += [(str(i // count), ['--solos', *labels[i:i + count]])
                           for i in range(0, len(labels), count)]
        for name, flags in selections:
            folder = output.parent / (output.name + '_jobs') / (view + '_' + name)
            args = [spec_path, build, folder, view, '--diagnostic', '--comparison', *flags]
            job(PROBE, args, folder.with_suffix('.json'), resume)
            report = json.loads((folder / 'batch_checks.json').read_text())
            if report['spec_hash'] != digest(spec) or not report['geometry_unchanged']:
                raise ValueError('Capture changed geometry or used stale input')
            batches.append(folder)
    output.mkdir(parents=True, exist_ok=True)
    joints, counts, images, checks = {}, {}, set(), []
    cloak, view_owners = None, {}
    for batch in batches:
        manifest = read_manifest(batch, digest(spec), ('preview', 'ownership'))
        checks.append(json.loads((batch / 'batch_checks.json').read_text()))
        if (batch / 'cloak_side.json').exists():
            side = json.loads((batch / 'cloak_side.json').read_text())
            if cloak is not None and cloak != side['pieces']:
                raise ValueError('Body-space cloth ownership changed between capture batches')
            cloak = side['pieces']
            for view, owners in side['view_owner_hashes'].items():
                if view in view_owners and view_owners[view] != owners:
                    raise ValueError('View cloth ownership changed between capture batches')
                view_owners[view] = owners
        joints.update(json.loads((batch / 'joints_px.json').read_text()))
        for name in manifest['images']:
            if name not in images:
                shutil.copyfile(batch / name, output / name)
                images.add(name)
        if (batch / 'solo_coverage.json').exists():
            for view, values in json.loads((batch / 'solo_coverage.json').read_text()).items():
                counts.setdefault(view, {}).update(values)
    report = json.loads((build / 'build_report.json').read_text())
    facing = json.loads((batches[0] / 'facing_report.json').read_text())
    report['checks'].update(capture_geometry_unchanged=all(c['geometry_unchanged'] for c in checks),
                            rendered_torso_asymmetry=facing['passed'])
    if cloak is not None:
        identical_owners = view_owners.get('front') == view_owners.get('rear')
        report['checks']['two_view_cloth_ownership_unchanged'] = identical_owners
        write(output / 'cloak_side.json', {'rule': 'body_sagittal_plane', 'pieces': cloak,
                                         'view_owner_hashes': view_owners})
    if not preview:
        from spec.art_identity.maquettes.blender.ownership import require_solos
        for view in ('front', 'rear'):
            require_solos(spec['labels'], counts[view])
            if set(counts[view]) != set(spec['labels']):
                raise ValueError('Incomplete solo inventory')
        report['checks']['required_solo_coverage'] = True
        write(output / 'solo_coverage.json', counts)
        write(output / 'ownership_validation.json', {'passed': True, 'empty_required_solos': {'front': [], 'rear': []}})
    report['passed'] = all(report['checks'].values())
    write(output / 'build_report.json', report)
    write(output / 'joints_px.json', joints)
    write(output / 'facing_report.json', facing)
    write(output / 'capture_checks.json', {'passed': report['passed'], 'spec_hash': digest(spec),
        'geometry_unchanged': True, 'geometry_checks': report['checks'], 'facing': facing})
    write(output / 'native_observations.json', checks[0])
    write_manifest(output, digest(spec), 'preview' if preview else 'full', images)
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('figure', choices=('gale_herald', 'gloam_stalker'))
    parser.add_argument('operation', choices=('build', 'capture', 'regenerate', 'proof', 'round0-front', 'isolated-near'))
    parser.add_argument('--resume', action='store_true')
    parser.add_argument('--feedback1', action='store_true')
    args = parser.parse_args()
    figure = ROOT / args.figure
    recipe_path = figure / 'r2/measurements.json'
    if not recipe_path.exists():
        recipe_path = figure / 'measurements.json'
    spec = compile_recipe(json.loads(recipe_path.read_text()))
    root = figure / ('proof/feedback1/native' if args.feedback1 else 'proof/mq12')
    spec_path = root / 'spec_native.json'
    write(spec_path, spec)
    if args.operation == 'build':
        # The source-shape comparison is rebuilt from its own input, never
        # inferred from a report or a renamed old .blend.
        before = figure / ('proof/feedback1/before' if args.feedback1 else 'proof/mq12_before')
        if not (before / 'spec_native.json').exists():
            old_recipe = figure / 'r2/review/mq12_before_recipe.json'
            before.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(old_recipe, before / 'measurements.json')
            original = figure / 'proof/feedback1/original_delivery' if args.feedback1 else figure / 'delivery'
            if original.exists():
                shutil.copytree(original, before / 'delivery', dirs_exist_ok=True)
            write(before / 'spec_native.json', compile_recipe(json.loads(old_recipe.read_text())))
        job(BUILDER / 'build.py', [before / 'spec_native.json', before / 'build', '--build-only'],
            before / 'build.json', args.resume)
        if args.feedback1:
            source = figure / 'proof/feedback1'
            if not (source / 'original_delivery').exists():
                baseline = capture(before / 'spec_native.json', before / 'build', before / 'delivery', args.resume)
                shutil.copytree(baseline, source / 'original_delivery')
            round0 = source / 'round0'
            round0.mkdir(exist_ok=True)
            if not (round0 / 'measurements.json').exists():
                shutil.copyfile(figure / 'r2/review/mq12_round0_recipe.json', round0 / 'measurements.json')
            old_spec = source / 'round0_spec.json'
            if not old_spec.exists():
                write(old_spec, compile_recipe(json.loads((round0 / 'measurements.json').read_text())))
            if not (source / 'round0_build/maquette.blend').exists():
                job(BUILDER / 'build.py', [old_spec, source / 'round0_build', '--build-only'],
                    source / 'round0_build.json', args.resume, diagnostic=True)
        for name in ('cold', 'replay', 'independent_cold'):
            cache = root / ('independent_cache' if name == 'independent_cold' else 'shared_cache')
            job(BUILDER / 'build.py', [spec_path, root / name, '--build-only', '--cache', cache],
                root / 'bridge' / (name + '.json'), args.resume, diagnostic=True)
        job(BUILDER / 'exact_native_replay.py', [root, root / 'exact_native_replay.json'],
            root / 'bridge/exact_native_replay.json', args.resume)
        if args.feedback1:
            job(Path(__file__).with_name('preservation_probe.py'),
                [spec_path, figure / 'proof/feedback1/round0_build', root / 'cold', root / 'preservation.json'],
                root / 'bridge/preservation.json', args.resume)
        return 0 if all(json.loads((root / n / 'build_report.json').read_text())['passed']
                        for n in ('cold', 'replay', 'independent_cold')) else 1
    elif args.operation == 'capture':
        native = capture(spec_path, root / 'cold', root / 'capture', args.resume)
        reports = {n: json.loads((root / n / 'build_report.json').read_text())
                   for n in ('cold', 'replay', 'independent_cold')}
        observations = json.loads((native / 'native_observations.json').read_text())
        hashes = {n: r['combined_mesh_hash'] for n, r in reports.items()}
        identical = len(set(hashes.values())) == 1
        checks = {'fresh_and_replay_raw_hashes': identical,
            'joint_endpoints': max(observations['joint_errors_m'].values()) <= WORKFLOW_DEFAULTS['joint_error_m'],
            'native_geometry': all(r['passed'] for r in reports.values())}
        write(native / 'recipe_proof.json', {'passed': all(checks.values()), 'checks': checks,
            'spec_hash': digest(spec), 'cache_revision': BUILD_DEFAULTS['cache_revision'],
            'raw_hashes_identical': identical, 'mesh_count': len(reports['cold']['mesh_hashes']),
            'joint_errors': observations['joint_errors_m'], 'combined_mesh_hashes': hashes})
        shutil.copyfile(root / 'exact_native_replay.json', native / 'exact_native_replay.json')
        return 0 if all(checks.values()) else 1
    elif args.operation == 'regenerate':
        output = figure / ('proof/feedback1/regeneration' if args.feedback1 else 'proof/mq12_regeneration')
        fresh = clean_inputs(output, figure, recipe_path, resume=args.resume)
        job(input_builder(fresh), [fresh, output / 'build', '--build-only'], output / 'build.json',
            args.resume, diagnostic=True)
        new = capture(fresh, output / 'build', output / 'capture', args.resume, preview=True)
        clean_inputs(output, figure, recipe_path, resume=True)
        views = compare_captures(new, root / 'capture', output)
        matched = all(row['passed'] for view in views.values() for row in view.values())
        built = json.loads((output / 'build/build_report.json').read_text())
        reference = json.loads((root / 'cold/build_report.json').read_text())
        geometry = built['combined_mesh_hash'] == reference['combined_mesh_hash']
        report = {'passed': matched and geometry and built['passed'], 'raster_matches': matched,
            'geometry_matches': geometry, 'native_geometry_passed': built['passed'],
            'views': views, 'compiled_spec_hash': digest(spec),
            'input_inventory_sha256': sha(output / 'clean_input_sha256.json'), 'cache_reused': False}
        write(output / 'regeneration.json', report)
        print('MQ12_REGENERATION: ' + ('PASS' if report['passed'] else 'FAIL') +
              '; raster_matches=' + str(matched) + '; geometry_matches=' + str(geometry), flush=True)
        return 0 if report['passed'] else 1
    elif args.operation == 'isolated-near':
        source = figure / 'proof/feedback1'
        for version, old_spec, build in (
            ('original', source / 'before/spec_native.json', source / 'before/build'),
            ('round0', source / 'round0_spec.json', source / 'round0_build'),
            ('feedback1', spec_path, root / 'cold')):
            job(Path(__file__).with_name('isolated_part_probe.py'),
                [old_spec, build, source / 'isolated_near' / version, 'cape_near'],
                source / 'isolated_near' / (version + '.json'), args.resume)
        return 0
    elif args.operation == 'round0-front':
        source = figure / 'proof/feedback1'
        round0 = source / 'round0_spec.json'
        labels = list(json.loads(round0.read_text())['labels'])
        count = WORKFLOW_DEFAULTS['solo_batch_size']
        target = source / 'round0_front'
        target.mkdir(exist_ok=True)
        for i in range(0, len(labels), count):
            folder = source / 'round0_solo_jobs' / str(i // count)
            job(PROBE, [round0, source / 'round0_build', folder, 'front', '--diagnostic', '--comparison',
                        '--solos', *labels[i:i + count]], folder.with_suffix('.json'), args.resume)
            for path in folder.glob('front_solo_*.png'):
                shutil.copyfile(path, target / path.name)
        return 0
    else:
        if args.feedback1:
            from .feedback_proof import proof
            return 0 if proof(figure)['passed'] else 1
        from .shoulder_proof import proof
        return 0 if proof(figure)['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
