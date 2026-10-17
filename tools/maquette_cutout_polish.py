#!/usr/bin/env python3
"""rr-05 feature derivation and stepped-pixel gates. No art generation."""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from types import SimpleNamespace
from unittest.mock import patch
from cutout_pipeline.cases import CutoutError, baseline, digest, read_json, write_json
from maquette_motion import features, pixels, silhouette, joint_seams, seam_pose
from maquette_motion.gates import input_bindings


def derive(case, task_id='rr-05'):
    """Rebuild from approved source in isolation; reject unresolved design first."""
    for view in features.VIEWS:
        features.declarations(case, view)
    import maquette_cutout as builder
    from maquette_cutout_build import registration, bind_layout
    from maquette_motion.feature_builder import ownership_adapter, extract_nodes, record_partition
    from maquette_motion import continuity
    from maquette_motion.continuity_limits import unfillable_hole, unfillable_holes
    old = read_json(case / 'hidden_fills/index.json')
    for relative, expected in old['protected_inputs'].items():
        if digest(case / relative) != expected:
            raise CutoutError('Preserve manually changed source: ' + relative)
    for record in old['requests']:
        for output in record.get('outputs', []):
            if digest(case / output['output']) != output['output_sha256']:
                raise CutoutError('Preserve manually changed hidden paint: ' + output['output'])
    # Feedback 8 changes support nodes only. Rebuilding existing material would
    # discard the accepted selective 1,376-texel bleed and its stable anchors.
    proof_path = case / 'proof/continuity.json'
    same_features = read_json(case / 'proof/feature_derivation.json').get('features_sha256') == digest(case / 'features.json')
    if same_features and proof_path.exists() and ('feedback7' in read_json(proof_path) or (case / 'seams.json').exists()):
        from maquette_motion.seam_builder import derive as derive_seams
        return derive_seams(case, task_id)
    with tempfile.TemporaryDirectory(dir=case.parent, prefix='rr05-derive-') as temporary:
        work = Path(temporary) / 'case'
        shutil.copytree(case, work)
        (work / 'hidden_fills/index.json').unlink()
        config = read_json(work / 'cutout.json')
        config['sources'] = [p for p in config['sources'] if p != 'hidden_fills/index.json']
        config.pop('hidden_fill', None)
        write_json(work / 'cutout.json', config)
        recipe = read_json(work / 'recipes/rig.json')
        recipe['features'] = 'features.json'
        write_json(work / 'recipes/rig.json', recipe)
        spec = read_json(work / 'source/spec.json')
        palette = read_json(work / 'source/label_palette.json')
        requests = []
        with patch.object(builder, 'registration', registration), patch.object(builder, 'bind_layout', bind_layout), ownership_adapter(builder, work) as state:
            for view in features.VIEWS:
                state['view'] = view
                shutil.rmtree(work / f'segmented/{view}')
                result = builder.build_view(work, spec, view, palette, recipe, False)
                extract_nodes(work, view, recipe['parts'])
                requests.extend(result['requests'])
                path = work / f'layouts/{view}.json'
                layout = read_json(path)
                layout['motion_data'] = read_json(case / f'layouts/{view}.json')['motion_data']
                write_json(path, layout)
            index = read_json(work / 'hidden_requests/index.json')
            index['requests'] = requests
            index['exposure_basis'] = 'rr-05 ownership rebuilt; resample after feature adoption'
            write_json(work / 'hidden_requests/index.json', index)
            report = builder.fill_hidden(SimpleNamespace(case=work, cross_view_fallback=False))
        if not report['ok'] or report['pending_design']:
            raise CutoutError('Feature-derived hidden support is incomplete')
        transfers = continuity.prepare(work)
        attempts, design = [], []
        # Choose the smallest integral source overlap satisfying the pose gate.
        # The finite bound is the approved source width, not a motion/taste value.
        for margin in range(read_json(work / 'cutout.json')['source_size'][0] + 1):
            supports = continuity.underlays(work, margin)
            sample_path = work / 'proof/continuity_samples.json'
            command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', task_id, '--stream', '--',
                       'godot', '--headless', '--path', '.', '--script', 'tests/maquette_cutout/pixel_samples.gd',
                       '--', '--case', str(work), '--output', str(sample_path)]
            sampled = subprocess.run(command, cwd=Path(__file__).resolve().parents[1], capture_output=True, text=True)
            if sampled.returncode:
                raise CutoutError('Continuity sampler failed: ' + sampled.stdout + sampled.stderr)
            pose_samples = read_json(sample_path)
            poses = silhouette.pose_report(work, pose_samples, legacy_hole_gate=True)
            attempts.append({'margin': margin, 'errors': len(poses['errors']),
                             'max_detached_pixels': max(r['detached_pixels'] for r in poses['poses']),
                             'max_new_hole_pixels': max(r['new_hole_pixels'] for r in poses['poses'])})
            print('MAQUETTE CONTINUITY SEARCH: ' + str(attempts[-1]), flush=True)
            if not any(r['islands'] or r['new_holes'] for r in poses['poses']):
                break
            if not any(r['islands'] for r in poses['poses']):
                limitation = unfillable_hole(work, pose_samples, poses)
                if limitation:
                    design.append(limitation)
                    break
        else:
            raise CutoutError('TODO_DESIGN_silhouette_support: no whole pose within approved rest support domain')
        bleed = None
        if read_json(work / 'cutout.json')['character_id'] == 'shale_bloomer':
            from maquette_motion.seam_support import repair
            bleed = repair(work, pose_samples)
        joint_seams.install(work, pose_samples)
        sampled = subprocess.run(command, cwd=Path(__file__).resolve().parents[1], capture_output=True, text=True)
        if sampled.returncode:
            raise CutoutError('Seam sampler failed: ' + sampled.stdout + sampled.stderr)
        pose_samples = read_json(sample_path)
        poses = silhouette.pose_report(work, pose_samples)
        seams = seam_pose.report(work, pose_samples)
        design = read_json(work / 'seams.json')['TODO_DESIGN'] + seam_pose.design_issues(seams)
        for view in features.VIEWS:
            record_partition(work, view, read_json(work / f'layouts/{view}.json'))
        continuity.seal(work, transfers, supports, margin, bleed)
        continuity_proof = read_json(work / 'proof/continuity.json')
        continuity_proof.update(poses=poses, attempts=attempts, TODO_DESIGN=design, bleed=bleed,
                                seams=seams, ok=poses['ok'] and seams['ok'] and not design)
        write_json(work / 'proof/continuity.json', continuity_proof)
        report['rest_identity'] = builder.rest_identity(work)
        if not report['rest_identity']['ok']:
            raise CutoutError('Continuity changed approved rest RGBA')
        config = read_json(work / 'cutout.json')
        write_json(work / 'proof/feature_derivation.json', {'tool_sha256': digest(Path(__file__)),
                   'adapter_sha256': digest(Path(__file__).parent / 'maquette_motion/feature_builder.py'),
                   'features_sha256': digest(work / 'features.json')})
        config['sources'] = sorted(set(config['sources']) | {'features.json'} |
                                   {'proof/feature_derivation.json', 'proof/continuity.json'} |
                                   {f['mask'] for item in read_json(work / 'features.json')['features'] for f in item['views'].values()})
        write_json(work / 'cutout.json', config)
        baseline(work)
        shutil.rmtree(case / 'backing', ignore_errors=True)
        (case / 'backing.json').unlink(missing_ok=True)
        shutil.rmtree(case / 'seams', ignore_errors=True)
        for folder in ('registered', 'segmented', 'hidden', 'hidden_requests', 'hidden_fills', 'layouts', 'recipes', 'proof', 'seams'):
            shutil.copytree(work / folder, case / folder, dirs_exist_ok=True)
        for name in ('cutout.json', 'baseline.sha256.json', 'seams.json'):
            shutil.copyfile(work / name, case / name)
    return {'ok': True, 'rest_identity': report['rest_identity'], 'parts': continuity_proof['part_gate'],
            'silhouette': poses, 'seams': seams, 'pose_accepted': poses['ok'] and seams['ok'] and not design,
            'TODO_DESIGN': design, 'joint_overlap_margin_px': margin}


def gate(case, sample_file, native=None):
    report = read_json(sample_file)
    errors = pixels.transform_errors(case, report)
    errors.extend(joint_seams.definition_errors(case, report))
    feature_errors, feature_results = [], []
    try:
        feature_report = features.integrity_report(case, report['samples'])
        feature_errors = feature_report['errors']
        feature_results = feature_report['features']
    except (CutoutError, OSError, KeyError, ValueError) as error:
        feature_errors.append(str(error))
    errors.extend(feature_errors)
    parts = silhouette.part_report(case)
    errors.extend(parts['errors'])
    continuity_path = case / 'proof/continuity.json'
    if not continuity_path.exists():
        errors.append('Missing derive-time continuity proof')
    else:
        errors.extend(item['name'] for item in read_json(continuity_path).get('TODO_DESIGN', []))
    cpu_silhouette = silhouette.pose_report(case, report)
    errors.extend(cpu_silhouette['errors'])
    cpu_seams = seam_pose.report(case, report)
    errors.extend(cpu_seams['errors'])
    native_seams = None
    native_silhouette = None
    native_report = None
    if native:
        native_report = read_json(native / 'pixel_frames.json')
        native_report['directory'] = native
        if not native_report.get('native_pixels') or native_report.get('inputs') != input_bindings(case):
            errors.append('Stale or incomplete native pixel inputs')
        merged = dict(report, samples=[r for r in report['samples'] if r['clip'] != 'idle'] + native_report.get('samples', []))
        errors.extend(pixels.transform_errors(case, merged))
        expected = {(r['view'], r['frame'], name) for r in report['samples'] if r['clip'] == 'idle' for name in r['parts']}
        observed = [(r['view'], r['frame'], r['part']) for r in native_report['frames']]
        if set(observed) != expected or len(observed) != len(expected):
            errors.append('Native isolated part coverage differs')
        for row in native_report['frames']:
            for kind in ('before', 'after'):
                path = native / row[kind]
                if not path.is_file() or digest(path) != row[kind + '_sha256']:
                    errors.append('Changed native part frame: ' + str(path))
        full_native = read_json(native / 'frames.json')
        if not full_native.get('ok') or not full_native.get('native_pixels') or full_native.get('inputs') != input_bindings(case):
            errors.append('Stale or incomplete native silhouette inputs')
        for row in full_native['frames']:
            if digest(native / row['file']) != row['sha256']:
                errors.append('Changed native silhouette: ' + row['file'])
        full_native['directory'] = native
        native_silhouette = silhouette.pose_report(case, report, full_native)
        errors.extend(native_silhouette['errors'])
        layers = read_json(native / 'seam_frames.json')
        if layers.get('inputs') != input_bindings(case) or not layers.get('native_pixels'):
            errors.append('Stale or incomplete native seam inputs')
        expected = {(r['view'], r['clip'], r['frame']) for r in report['samples']}
        observed = [(r['view'], r['clip'], r['frame']) for r in layers['frames']]
        if set(observed) != expected or len(observed) != len(expected):
            errors.append('Native seam layer coverage differs')
        for row in layers['frames']:
            for kind in ('parts', 'seams', 'rest', 'interior'):
                if digest(native / row[kind + '_file']) != row[kind + '_sha256']:
                    errors.append('Changed native seam layer: ' + row[kind + '_file'])
        layers['directory'] = native
        errors.extend(seam_pose.native_consistency_errors(layers, full_native))
        native_seams = seam_pose.report(case, report, layers)
        errors.extend(native_seams['errors'])
    shimmer_errors, metric = pixels.shimmer(case, report, native_report)
    errors.extend(shimmer_errors)
    return {'ok': not errors, 'errors': errors, 'feature_errors': feature_errors, 'features': feature_results, 'shimmer': metric,
            'silhouette': {'parts': parts, 'cpu': cpu_silhouette, 'native': native_silhouette},
            'seams': {'cpu': cpu_seams, 'native': native_seams},
            'inputs': report.get('inputs'), 'samples_sha256': digest(sample_file),
            'native_manifest_sha256': digest(native / 'pixel_frames.json') if native else None,
            'proof_basis': 'native isolated part pixels' if native else 'CPU diagnostic from real Godot transforms; native proof still required'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['derive', 'gate'])
    parser.add_argument('--case', type=Path, required=True)
    parser.add_argument('--samples', type=Path)
    parser.add_argument('--native', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--task-id', default='rr-05')
    args = parser.parse_args()
    try:
        report = derive(args.case.resolve(), args.task_id) if args.command == 'derive' else gate(args.case, args.samples, args.native)
    except (CutoutError, OSError, ValueError, KeyError) as error:
        report = {'ok': False, 'errors': [str(error)]}
    write_json(args.output, report)
    label = 'MAQUETTE DERIVATION' if args.command == 'derive' else 'MAQUETTE PIXEL GATES'
    print(label + ': ' + ('PASS' if report['ok'] else 'FAIL') + ' (' + str(len(report.get('errors', []))) + ' errors)')
    if args.command == 'derive' and 'pose_accepted' in report:
        print('MAQUETTE DERIVED POSES: ' + ('PASS' if report['pose_accepted'] else 'FAIL; see TODO_DESIGN and run the pixel gates'))
    for error in report.get('errors', [])[:10]:
        print(error)
    return int(not report['ok'])


if __name__ == '__main__':
    raise SystemExit(main())
