"""mq-08 native proof in bounded owner-bridge jobs; no Git operations.

Every receipt is retained. A missing, refused or failed bridge response stops
the workflow. --resume reuses only matching successful job receipts.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys

from spec.art_identity.maquettes.blender.bridge_client import run_job
from spec.art_identity.maquettes.blender.capture_manifest import read_manifest, write_manifest
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.compact_capture import compact_capture
from spec.art_identity.maquettes.blender.contract import digest, BUILD_DEFAULTS
from spec.art_identity.maquettes.blender.curate_delivery import write, stage, sha, discard_evidence, verify
from spec.art_identity.maquettes.blender.delivery_validation import seal_delivery
from spec.art_identity.maquettes.blender.regenerate_delivery import compare_captures
from spec.art_identity.maquettes.blender.solid_fit import write_fit

WORKFLOW_DEFAULTS = {'job_timeout_s': 90, 'solo_batch_size': 5, 'joint_error_m': 1e-4}
FIGURE = Path(__file__).resolve().parent
BUILDER = FIGURE.parent / 'blender'


def job(script, values, receipt, resume):
    receipt = Path(receipt)
    command = [str(Path(script).resolve()), *map(str, values)]
    input_paths = [Path(script), Path(str(values[0]))]
    if '--contacts' in values:
        input_paths.append(Path(values[values.index('--contacts') + 1]))
    inputs = {str(p): sha(p) for p in input_paths if p.is_file()}
    builder_revision = digest({p.name: sha(p) for p in sorted(BUILDER.glob('*.py'))})
    if resume and receipt.is_file():
        result = json.loads(receipt.read_text())
        if (result.get('requested') == command and result.get('exit') == 0 and
                result.get('input_sha256') == inputs and result.get('builder_revision') == builder_revision):
            return result
    result = run_job(script, values, timeout_s=WORKFLOW_DEFAULTS['job_timeout_s'])
    write(receipt, dict({k: v for k, v in result.items() if k != 'stdout'}, requested=command,
                        input_sha256=inputs, builder_revision=builder_revision))
    receipt.with_suffix('.log').write_text(result['stdout'])
    print('MQ08_BRIDGE: ' + receipt.stem + '; exit=' + str(result['exit']), flush=True)
    if result['exit'] or result.get('refused'):
        raise ValueError('Native job failed: ' + str(receipt))
    return result


def capture(spec_path, build, output, root, resume, preview=False):
    spec = json.loads(Path(spec_path).read_text())
    batches, receipts = [], root / 'bridge'
    receipts.mkdir(parents=True, exist_ok=True)
    for view in ('front', 'rear'):
        selections = [('preview', [])]
        if not preview:
            labels = list(spec['labels'])
            count = WORKFLOW_DEFAULTS['solo_batch_size']
            selections += [(str(i // count), ['--solos', *labels[i:i + count]]) for i in range(0, len(labels), count)]
        for name, selection in selections:
            folder = root / 'batches' / (view + '_' + name)
            values = [spec_path, build, folder, view, *selection]
            if preview:
                values.append('--comparison')
            job(FIGURE / 'native_proof.py', values, receipts / (view + '_' + name + '.json'), resume)
            check = json.loads((folder / 'batch_checks.json').read_text())
            built = json.loads((build / 'build_report.json').read_text())
            if (not check['passed'] or check['spec_hash'] != digest(spec) or
                    check['native_mesh_hash'] != built['combined_mesh_hash']):
                raise ValueError('Failed bounded capture: ' + str(folder))
            batches.append(folder)
    output.mkdir(parents=True, exist_ok=True)
    joints, coverage, images, checks = {}, {}, set(), []
    for folder in batches:
        manifest = read_manifest(folder, digest(spec), ('preview', 'ownership'))
        checks.append(json.loads((folder / 'batch_checks.json').read_text()))
        joints.update(json.loads((folder / 'joints_px.json').read_text()))
        for name in manifest['images']:
            if not preview and any(name == f'{v}_{kind}.png' for v in ('front', 'rear') for kind in ('body', 'head')):
                continue
            if name not in images:
                shutil.copyfile(folder / name, output / name)
                images.add(name)
        if (folder / 'solo_coverage.json').is_file():
            for view, counts in json.loads((folder / 'solo_coverage.json').read_text()).items():
                coverage.setdefault(view, {}).update(counts)
    write(output / 'joints_px.json', joints)
    report = json.loads((build / 'build_report.json').read_text())
    report['checks']['capture_geometry_unchanged'] = all(c['geometry_unchanged'] for c in checks)
    facing = json.loads((batches[0] / 'facing_report.json').read_text())
    report['checks']['rendered_torso_asymmetry'] = facing['passed']
    if not preview:
        from spec.art_identity.maquettes.blender.ownership import require_solos
        for view in ('front', 'rear'):
            require_solos(spec['labels'], coverage[view])
            if set(coverage[view]) != set(spec['labels']):
                raise ValueError('Incomplete bounded solo inventory: ' + view)
        report['checks']['required_solo_coverage'] = True
        write(output / 'solo_coverage.json', coverage)
        write(output / 'ownership_validation.json', {'passed': True, 'empty_required_solos': {'front': [], 'rear': []}})
    report['passed'] = all(report['checks'].values())
    write(output / 'build_report.json', report)
    write(output / 'facing_report.json', facing)
    write(output / 'capture_checks.json', {'passed': report['passed'], 'spec_hash': digest(spec),
        'geometry_unchanged': all(c['geometry_unchanged'] for c in checks),
        'geometry_checks': report['checks'], 'facing': facing})
    write(output / 'native_observations.json', checks[0])
    write_manifest(output, digest(spec), 'preview' if preview else 'full', images)
    return output


def clean_inputs(output, figure=FIGURE, recipe_path=None):
    project = output / 'clean_project'
    root = project / 'spec/art_identity/maquettes'
    root.mkdir(parents=True, exist_ok=True)
    for path in FIGURE.parent.glob('*.py'):
        shutil.copyfile(path, root / path.name)
    shutil.copytree(BUILDER, root / 'blender', ignore=shutil.ignore_patterns('__pycache__'), dirs_exist_ok=True)
    (root / 'frostglass_lancer').mkdir(exist_ok=True)
    shutil.copyfile(FIGURE.parent / 'frostglass_lancer/spec_r3.json', root / 'frostglass_lancer/spec_r3.json')
    target = root / figure.name
    target.mkdir(exist_ok=True)
    if (figure / 'measurements.json').is_file():
        shutil.copyfile(recipe_path or figure / 'measurements.json', target / 'measurements.json')
    else:
        shutil.copyfile(figure / 'spec_r3.json', target / 'spec_native.json')
    inventory = {str(p.relative_to(project)): sha(p) for p in sorted(project.rglob('*')) if p.is_file()}
    write(output / 'clean_input_sha256.json', inventory)
    if (target / 'measurements.json').is_file():
        subprocess.run([sys.executable, '-B', str(root / 'blender/compile_recipe.py'), str(target / 'measurements.json')], check=True)
    return target / 'spec_native.json'


def curate_revision():
    """Retain the unit's editable migration/proof tools and hash every discard."""
    report = FIGURE / 'delivery/review/mq08_gates.json'
    if not report.is_file() or not json.loads(report.read_text())['passed']:
        raise ValueError('Curation requires the completed shoulder gates and native comparison sheet')
    for name in ('glacial_mirror', 'hoarfrost_seer', 'gale_herald', 'arc_thrall', 'gloam_stalker',
                 'burrow_grub', 'ember_tick', 'frostglass_lancer'):
        path = FIGURE / 'delivery/validation/mq08/regeneration' / name / 'regeneration.json'
        if not path.is_file() or not json.loads(path.read_text())['passed']:
            raise ValueError('Missing regeneration: ' + name)
    archive = FIGURE / 'discarded_proof_sha256.json'
    manifest = FIGURE / 'COMMIT_MANIFEST.txt'
    keep = {p for p in (FIGURE / 'delivery').rglob('*') if p.is_file()}
    # These reports were replaced by the bound mq-08 evidence. Their old bytes
    # also occur in proof/before and are hashed before that baseline is removed.
    legacy = FIGURE / 'delivery/validation/bridge'
    keep -= {p for p in legacy.rglob('*') if p.is_file()}
    keep -= {p for p in (FIGURE / 'delivery/validation/regeneration').glob('*') if p.is_file()}
    keep -= {FIGURE / 'delivery/review' / name for name in
             ('mq08_shoulders.webp', 'front_clay_2x.webp', 'front_clay_2x.json')}
    keep |= {p for p in FIGURE.glob('*.py')}
    keep |= {p for p in FIGURE.glob('*.md')}
    keep |= {FIGURE / name for name in ('README.md', 'measurements.json', '.gdignore')}
    keep |= {archive, manifest}
    files = [p for p in FIGURE.rglob('*') if p.is_file()]
    discard_evidence(FIGURE, sorted(p for p in files if p not in keep), archive)
    manifest.write_text('# Paths relative to this figure. Shared builder: ../blender/render.py, ../blender/capture_manifest.py\n'
                        '# Canonical build specification: measurements.json; generated spec_native.json is omitted.\n' +
                        '\n'.join(sorted(str(p.relative_to(FIGURE)) for p in keep)) + '\n')
    for path in sorted(FIGURE.rglob('*'), key=lambda p: len(p.parts), reverse=True):
        if path.is_dir() and not any(path.iterdir()):
            path.rmdir()
    return verify(FIGURE)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('deliver', 'regenerate', 'baselines', 'curate'))
    parser.add_argument('--resume', action='store_true')
    args = parser.parse_args()
    if args.operation == 'curate':
        curate_revision()
        return
    spec_path = FIGURE / 'spec_native.json'
    spec = compile_recipe(json.loads((FIGURE / 'measurements.json').read_text()))
    write(spec_path, spec)
    proof = FIGURE / 'proof'
    receipts = proof / 'bridge'
    receipts.mkdir(parents=True, exist_ok=True)
    if args.operation == 'deliver':
        build = proof / 'native2'
        # Rebuild under a receipt even when an exploratory build already exists.
        job(BUILDER / 'build.py', [spec_path, build, '--build-only'], receipts / 'build.json', args.resume)
        native = capture(spec_path, build, proof / 'capture', proof / 'capture_jobs', args.resume)
        deterministic = proof / 'determinism'
        for name in ('cold', 'replay', 'independent_cold'):
            cache = deterministic / ('independent_cache' if name == 'independent_cold' else 'shared_cache')
            job(BUILDER / 'build.py', [spec_path, deterministic / name, '--build-only', '--cache', cache], receipts / (name + '.json'), args.resume)
        job(BUILDER / 'exact_native_replay.py', [deterministic, deterministic / 'exact_native_replay.json'], receipts / 'exact_replay.json', args.resume)
        reports = {n: json.loads((deterministic / n / 'build_report.json').read_text()) for n in ('cold', 'replay', 'independent_cold')}
        errors = json.loads((native / 'native_observations.json').read_text())['joint_errors_m']
        hashes = {n: r['combined_mesh_hash'] for n, r in reports.items()}
        identical = len(set(hashes.values())) == 1
        gates = {'fresh_and_replay_raw_hashes': identical,
                 'joint_endpoints': max(errors.values()) <= WORKFLOW_DEFAULTS['joint_error_m'],
                 'native_geometry': all(r['passed'] for r in reports.values())}
        write(native / 'recipe_proof.json', {'passed': all(gates.values()), 'checks': gates,
            'spec_hash': digest(spec), 'cache_revision': BUILD_DEFAULTS['cache_revision'],
            'raw_hashes_identical': identical, 'mesh_count': len(reports['cold']['mesh_hashes']),
            'joint_errors': errors, 'combined_mesh_hashes': hashes})
        shutil.copyfile(deterministic / 'exact_native_replay.json', native / 'exact_native_replay.json')
        job_file = proof / 'native_validation_job.json'
        write(job_file, [{'spec': str(spec_path), 'build': str(build)}])
        job(BUILDER / 'native_delivery_checks.py', [job_file, proof / 'native_validation.json'], receipts / 'native_mutations.json', args.resume)
        pairs = [[a, b] for a, b in (('head', 'torso'), ('torso', 'pelvis'))]
        for side in ('near', 'far'):
            pairs += [['torso', 'upper_' + side], ['upper_' + side, 'fore_' + side], ['fore_' + side, 'hand_' + side],
                      ['pelvis', 'thigh_' + side], ['thigh_' + side, 'shin_' + side], ['shin_' + side, 'foot_' + side]]
        write(proof / 'part_contact_pairs.json', pairs)
        job(BUILDER / 'inspect_mass_stacks.py', [build / 'maquette.blend', proof / 'all_part_contacts.json', '--contacts', proof / 'part_contact_pairs.json'], receipts / 'part_contacts.json', args.resume)
        if not json.loads((proof / 'all_part_contacts.json').read_text())['part_contacts']['passed']:
            raise ValueError('An anatomical part adjacency is detached')
        compact_capture(spec, native)
        fit, _ = write_fit(FIGURE, native)
        if not fit['passed']:
            raise ValueError('Approved original painting fit failed')
        seal_delivery(spec, native)
        stage(FIGURE, native)
        validation = FIGURE / 'delivery/validation/mq08'
        shutil.copytree(receipts, validation / 'bridge', dirs_exist_ok=True)
        for name in ('native_validation.json', 'part_contact_pairs.json', 'all_part_contacts.json'):
            shutil.copyfile(proof / name, validation / name)
            shutil.copyfile(proof / name, FIGURE / 'delivery/validation' / name)
        shutil.copyfile(native / 'native_observations.json', validation / 'native_observations.json')
        print('MQ08_NATIVE_DELIVERY: PASS', flush=True)
    else:
        names = ('glacial_mirror',) if args.operation == 'regenerate' else (
            'hoarfrost_seer', 'gale_herald', 'arc_thrall', 'gloam_stalker', 'burrow_grub', 'ember_tick', 'frostglass_lancer')
        for name in names:
            folder = FIGURE.parent / name
            output = proof / 'regeneration' / name
            fresh_spec = clean_inputs(output, folder)
            build = fresh_spec.parent / 'build'
            job(fresh_spec.parent.parent / 'blender/build.py', [fresh_spec, build, '--build-only'], output / 'build.json', args.resume)
            native = capture(fresh_spec, build, output / 'capture', output / 'capture_jobs', args.resume, preview=True)
            reference = folder / 'delivery'
            reference_parts = None
            if name == 'frostglass_lancer':
                reference = FIGURE.parent / 'gloam_stalker/delivery/reference/lancer_r3'
                reference_parts = FIGURE.parent / 'burrow_grub/delivery/validation/feedback_2/baselines/lancer_reference'
            per_view_sources = {}
            sources_path = reference / 'view_sources.json'
            if sources_path.is_file():
                # mq-06 Seer deliberately has a frozen front and a separately
                # posed rear. Regenerate each approved source, never compare
                # the obsolete base-recipe rear to its replacement delivery.
                from spec.art_identity.maquettes.blender.view_delivery import source_spec
                sources = json.loads(sources_path.read_text())
                for view, source in sources['overrides'].items():
                    approved = source_spec(reference, source)
                    override_root = output / ('source_' + view)
                    override_spec = clean_inputs(override_root, folder, folder / source['recipe'])
                    if digest(json.loads(override_spec.read_text())) != digest(approved):
                        raise ValueError('Clean per-view source differs from its approved recipe')
                    override_build = override_spec.parent / 'build'
                    job(override_spec.parent.parent / 'blender/build.py', [override_spec, override_build, '--build-only'],
                        override_root / 'build.json', args.resume)
                    override_capture = override_root / 'capture'
                    job(FIGURE / 'native_proof.py', [override_spec, override_build, override_capture, view, '--comparison'],
                        override_root / 'capture.json', args.resume)
                    # Comparison storage is explicitly separate from native
                    # certificates; no report is relabelled with another hash.
                    comparison = output / 'raster_comparison'
                    comparison.mkdir(exist_ok=True)
                    for source_view in ('front', 'rear'):
                        for kind in ('clay', 'parts'):
                            filename = source_view + '_' + kind + '.png'
                            origin = override_capture if source_view == view else native
                            shutil.copyfile(origin / filename, comparison / filename)
                    native = comparison
                    per_view_sources[view] = {'recipe': source['recipe'], 'recipe_sha256': source['recipe_sha256'],
                                              'spec_hash': digest(approved), 'clean_input_sha256': sha(override_root / 'clean_input_sha256.json')}
            views = compare_captures(native, reference, output, True, reference_parts)
            passed = all(r['passed'] for view in views.values() for r in view.values())
            fresh_report = json.loads((build / 'build_report.json').read_text())
            geometry = {'native_combined_mesh_hash': fresh_report['combined_mesh_hash'],
                        'compiled_spec_hash': digest(json.loads(fresh_spec.read_text())),
                        'input_spec_sha256': sha(fresh_spec)}
            if name == 'glacial_mirror':
                delivered_report = json.loads((reference / 'build_report.json').read_text())
                geometry['delivery_combined_mesh_hash'] = delivered_report['combined_mesh_hash']
                geometry['geometry_matches_delivery'] = fresh_report['combined_mesh_hash'] == delivered_report['combined_mesh_hash']
                passed &= geometry['geometry_matches_delivery']
            write(output / 'regeneration.json', {'passed': passed, 'figure': name, 'views': views,
                'cache_reused': False, 'input_inventory_sha256': sha(output / 'clean_input_sha256.json'),
                'per_view_sources': per_view_sources, **geometry})
            retained = FIGURE / 'delivery/validation/mq08/regeneration' / name
            retained.mkdir(parents=True, exist_ok=True)
            for filename in ('regeneration.json', 'clean_input_sha256.json', 'build.json', 'build.log'):
                shutil.copyfile(output / filename, retained / filename)
            shutil.copytree(output / 'capture_jobs/bridge', retained / 'bridge', dirs_exist_ok=True)
            for view in per_view_sources:
                source_root = output / ('source_' + view)
                for filename in ('clean_input_sha256.json', 'build.json', 'build.log', 'capture.json', 'capture.log'):
                    target = retained / ('source_' + view) / filename
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(source_root / filename, target)
            if name == 'glacial_mirror':
                shutil.copyfile(output / 'regeneration.json', FIGURE / 'delivery/regeneration.json')
                shutil.copyfile(output / 'regeneration.json', FIGURE / 'delivery/validation/regeneration/regeneration.json')
                shutil.copyfile(output / 'clean_input_sha256.json', FIGURE / 'delivery/validation/regeneration/clean_input_sha256.json')
            print('CLEAN_REGENERATION: ' + ('PASS' if passed else 'FAIL') + '; ' + name + '; canonical_png_sha256=true', flush=True)
            if not passed:
                raise ValueError('Regeneration differs: ' + name)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, TimeoutError, OSError) as error:
        print('MQ08_WORKFLOW_ERROR: ' + str(error), file=sys.stderr)
        raise SystemExit(2)
