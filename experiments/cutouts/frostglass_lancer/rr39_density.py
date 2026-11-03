"""Bind the Lancer's exact director partition to its prior production paint."""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import numpy as np
from PIL import Image
from rr37_case import PROJECT, CASE, ASSETS
from rr39_fixture import TARGET
from rr39_underlay import DIRECTOR, inputs
from cutout_pipeline.cases import read_json, write_json, digest
from maquette_motion.features import source_pixels

SURFACES = ('torso', 'cape_far', 'foot_far')
REPORT = CASE/'proof/density_partition.json'


def declarations(layouts):
    original = read_json(TARGET/'case/layouts/front.json')
    previous = {p['name']: p for p in original['parts']}
    path = DIRECTOR/'front_far_footprint_mask.png'
    expected = read_json(DIRECTOR/'provenance.json')['files'][path.name]
    if digest(path) != expected: raise ValueError('Changed director footprint')
    mask = {'path': str(path.relative_to(PROJECT)), 'sha256': expected}
    result = {}
    for part in layouts['front']['parts']:
        if not part.get('hidden_material') or part['logical_part'] not in SURFACES: continue
        recipe = {'mask': mask, 'source_offset': part['offset']}
        if part['name'] in previous:
            old = previous[part['name']]
            baseline = TARGET/'case'/old['file']
            expected = original['proof_layers'][part['name']]['source_sha256']
            if digest(baseline) != expected: raise ValueError('Changed rr-37 production baseline: '+part['name'])
            recipe['outside'] = {'path': str(baseline.relative_to(PROJECT)),
                                 'sha256': expected, 'offset': old['offset']}
        target = ASSETS/'humanoid_v2/front'/Path(part['file']).name
        result[str(target.relative_to(PROJECT))] = recipe
    return result


def composed(root, layout):
    result = Image.new('RGBA', (255, 255))
    for part in sorted(layout['parts'], key=lambda p:p['z_index']):
        result.alpha_composite(Image.fromarray(source_pixels(root, part)))
    return result


def verify(report=REPORT):
    paint, footprint = inputs()
    from rr41_underlay import inputs as leg_inputs
    _, leg_footprint = leg_inputs()
    production = ASSETS/'humanoid_v2'
    layout = read_json(production/'front.json')
    previous = read_json(TARGET/'case/layouts/front.json')
    old_parts = {p['name']:p for p in previous['parts']}
    raw = read_json(CASE/'layouts/front.json')
    raw_parts = {p['name']:p for p in raw['parts']}
    outside = np.zeros(footprint.shape, bool)
    supplied = np.zeros_like(paint)
    inside_changes = 0
    per_part = {}
    for part in layout['parts']:
        image = source_pixels(production, part)
        baseline = source_pixels(TARGET/'case', old_parts[part['name']]) if part['name'] in old_parts else np.zeros_like(image)
        from rr43_spear import prior_partition, TRANSFER_PARTS
        if part['name'] in TRANSFER_PARTS:
            baseline = prior_partition('production')[part['name']]
        allowed = footprint | leg_footprint
        if part['name'] in ('hidden_cape_near','hidden_cape_far'):
            from rr41_density import new_edge_domain
            from rr41_underlay import extensions
            logical = part['logical_part']
            allowed = allowed | new_edge_domain(logical=logical) | extensions()[logical]
        changed = np.any(image != baseline, axis=-1) & ~allowed
        outside |= changed
        per_part[part['name']] = int(changed.sum())
        if part.get('hidden_material') and part['logical_part'] in SURFACES:
            source = source_pixels(CASE, raw_parts[part['name']])
            inside_changes += int(np.any(image[footprint] != source[footprint], axis=-1).sum())
        if part['name'].startswith('covered_'):
            supplied[image[..., 3] > 0] = image[image[..., 3] > 0]
    underlay_changes = int(np.any(supplied[footprint] != paint[footprint], axis=-1).sum())
    rests = {}
    for view in ('front', 'rear'):
        source_layout = read_json(CASE/f'layouts/{view}.json')
        source = np.asarray(composed(CASE, source_layout))
        approved = np.asarray(Image.open(CASE/source_layout['rest_source']).convert('RGBA'))
        current = read_json(production/(view+'.json'))
        rest = composed(production, current)
        stored = Image.open(production/current['rest_source']).convert('RGBA')
        rests[view] = {'source_mismatch_pixels': int(np.any(source != approved, axis=-1).sum()),
            'production_assembly_mismatch_pixels': int(np.any(np.asarray(rest) != np.asarray(stored), axis=-1).sum()),
            'production_rest_sha256': digest(production/current['rest_source'])}
    result = {'native_pixels': False, 'outside_changed_texels': int(outside.sum()),
        'per_part_outside_changed_texels': per_part, 'inside_changed_texels': inside_changes,
        'underlay_changed_texels': underlay_changes, 'rests': rests}
    result['ok'] = not (result['outside_changed_texels'] or inside_changes or underlay_changes or
        any(r['source_mismatch_pixels'] or r['production_assembly_mismatch_pixels'] for r in rests.values()))
    write_json(report, result)
    print('RR39 DENSITY PARTITION: %s (%d changed production texels outside footprint; %d inside; %d underlay)' %
          ('PASS' if result['ok'] else 'FAIL', result['outside_changed_texels'], inside_changes, underlay_changes))
    for view, row in rests.items():
        print('RR39 %s REST: source=%dpx production-assembly=%dpx (not native capture)' %
              (view.upper(), row['source_mismatch_pixels'], row['production_assembly_mismatch_pixels']))
    return result


def seal_equivalent_rests(record=True, proof_label='rr39', output_dir=None):
    """Record exact CPU/native-equivalent assemblies; keep GPU proof pending.

    The director explicitly requested this offline reseal in rr-39 feedback 1.
    Its evidence scope is stored with both rest records, never relabelled native.
    Verification tests pass output_dir to keep the report, partition diagnostics
    and fresh poses in a temporary copy, even when a byte comparison fails.
    """
    if record and output_dir is not None: raise ValueError('Recorded density evidence must use its canonical report path')
    if not verify(REPORT if output_dir is None else output_dir/'density_partition.json')['ok']:
        raise ValueError('Source/density partition is not exact')
    from rr37_proof_case import PROOF_CASE, build
    from rr37_raster import CpuPose
    from humanoid_cutout.canvas import for_case
    from maquette_motion import pixels
    import process_board_density as density
    build()
    log_name = 'rr39-feedback1' if proof_label == 'rr39' else proof_label+'-rests'
    folder = CASE/('proof/logs/'+log_name) if output_dir is None else output_dir
    folder.mkdir(parents=True, exist_ok=True)
    poses = folder/'rest_poses.json'
    subprocess.run([sys.executable, 'tools/godot_task_runner.py', '--task-id',
        os.environ.get('LABYRINTH_TASK_ID', 'rr-39'), '--stream', '--',
        'godot', '--headless', '--path', '.', '--script', 'tests/rr37/samples.gd', '--',
        '--production', '--rest-only', '--output', str(poses)], cwd=PROJECT, check=True)
    counts = {}
    with for_case(CASE):
        for pose in read_json(poses)['samples']:
            view = pose['view']
            layout = read_json(PROOF_CASE/f'layouts/{view}.json')
            model = CpuPose(PROOF_CASE, layout)
            layers, _ = model.layers(pose)
            actual = np.zeros_like(layers[0][1])
            for _, image, _ in sorted(layers, key=lambda r:r[0]['z_index']):
                actual[image[..., 3] > 0] = image[image[..., 3] > 0]
            expected = np.zeros_like(actual)
            offset = pixels.PROOF_DEFAULTS['source_offset']
            rest = np.asarray(Image.open(PROOF_CASE/layout['rest_source']).convert('RGBA'))
            expected[offset:offset+rest.shape[0], offset:offset+rest.shape[1]] = rest
            counts[view] = int(np.any(actual != expected, axis=-1).sum())
    if set(counts) != {'front', 'rear'} or any(counts.values()):
        raise ValueError('Production rest differs from fresh Godot rest poses: '+str(counts))
    report = CASE/'proof/rest_equivalence.json' if output_dir is None else output_dir/'rest_equivalence.json'
    write_json(report, {'native_pixels': False, 'method': 'CPU raster of fresh production Godot rest poses',
        'pose_sha256': digest(poses), 'mismatch_pixels': counts,
        'production_rest_sha256': {v:digest(ASSETS/f'humanoid_v2/{v}/rest.png') for v in counts},
        'native_capture': 'separate director evidence; this report verifies CPU equivalence only'})
    if not record:
        print(proof_label.upper()+' REST EQUIVALENCE: PASS (front=0px rear=0px; native rest records preserved)')
        return read_json(report)
    entry = next(e for e in density.load_registry()['entries'] if e['id'] == 'frostglass_lancer_cutout')
    manifest = read_json(density.MANIFEST)
    density.record_rests([entry], manifest)
    manifest = read_json(density.MANIFEST)
    evidence = {'native_pixels': False, 'method': 'native-equivalent CPU rest assembly',
        'report': str(report.relative_to(PROJECT)), 'report_sha256': digest(report)}
    for path in density.rest_paths(entry): manifest[path]['evidence'] = evidence
    write_json(density.MANIFEST, dict(sorted(manifest.items())))
    from rr37_density import seal
    seal()
    print(proof_label.upper()+' PRODUCTION REST SEAL: PASS (front=0px rear=0px; native-equivalent CPU; windowed proof pending)')
    return read_json(report)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seal-rests', action='store_true')
    parser.add_argument('--verify-rests', action='store_true')
    args = parser.parse_args()
    if args.verify_rests: seal_equivalent_rests(record=False)
    elif args.seal_rests: seal_equivalent_rests()
    else: raise SystemExit(not verify()['ok'])
