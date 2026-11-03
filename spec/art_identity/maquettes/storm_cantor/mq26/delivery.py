"""Native capture acceptance, the director's contact sheet and source seals."""
import csv
import io
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

from spec.art_identity.maquettes.blender.capture_manifest import read_manifest
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import sha, write
from spec.art_identity.maquettes.blender.backend import load_render
from spec.art_identity.maquettes.blender.pixel_coverage import part_coverage
from ..acceptance import OCCLUSIONS
from ..mq19.checks import captured_pose_gates
from ..recipe import FOLDER as BASE, PROJECT
from .hand_capture import near_gate, far_gate

DELIVERY_DEFAULTS = {'tile_px': 1088, 'height_px': 1248, 'sole_px': 1164, 'background_rgba': [24, 24, 24, 255],
                     'budget_bytes': 6_000_000, 'alpha_threshold': 128, 'caption_padding_px': 8, 'webp_method': 6,
                     'bell_visible_pixels': 150}
TAKE_TWO = BASE / 'mq19/feedback3_delivery/delivery'
# Parts fully hidden in one view of the take-three figure, each with its occluder.
MQ26_OCCLUSIONS = {'front': dict(OCCLUSIONS['front']), 'rear': dict(OCCLUSIONS['rear'])}
MQ26_OCCLUSIONS['rear'].update({'tabard': 'The cloak and pelvis plate hide the front panel.',
                                'hand_near': 'The near hand falls behind the cloak after the true turn.',
                                'thigh_near': 'The full back cloak covers the near thigh in the true rear turn; its native solo is retained.'})
EXPECTED_MUTATIONS = {'elbow_cop_swapped_for_ball', 'knee_cop_swapped_for_ball', 'ribs_turned_to_face_camera',
                      'ribs_flattened_to_face_on_bars', 'near_fingers_fused', 'far_fingers_unwrapped', 'detached_staff',
                      'tines_shrunk_to_stubs', 'ribs_without_droop', 'bell_pushed_out_of_cage', 'mantle_back_humped',
                      'hood_crown_rounded_off', 'far_top_lame_closed_into_a_can'}


def numeric_contract(spec, report):
    """Reject omitted rows, altered targets and summary-only success."""
    names = {'near_knee_degrees', 'far_knee_degrees', 'pelvis_down_near_degrees', 'forward_lean_degrees',
             'chest_yaw_toward_viewer_degrees', 'head_down_degrees', 'head_matches_chest_yaw', 'ankle_span_over_shoulders',
             'near_step_over_L', 'fist_height_over_H', 'fist_forward_over_L', 'fist_outward_over_L',
             'staff_from_vertical_degrees', 'staff_forward_degrees', 'staff_butt_sole_over_H', 'staff_grip_axis_distance_over_L',
             'far_elbow_outward_degrees', 'near_upper_out_degrees', 'near_elbow_degrees', 'near_wrist_ahead_over_L'}
    rows = report.get('pose_values', [])
    if {r.get('name') for r in rows} != names or len(rows) != len(names): return False
    pose = spec['mq19']['design']['pose']
    for r in rows:
        target = 0 if r['name'] in ('head_matches_chest_yaw', 'staff_butt_sole_over_H', 'staff_grip_axis_distance_over_L') else pose[r['name']]
        if r.get('target') != target or r.get('passed') is not True or abs(r['measured'] - target) > r['tolerance']: return False
    return True


def inspect(spec, capture, write_outputs=True):
    capture = Path(capture); read_manifest(capture, digest(spec), ('full',))
    native = json.loads((capture / 'mq26_native.json').read_text())
    build = json.loads((capture / 'build_report.json').read_text())
    if native.get('spec_hash') != digest(spec) or native.get('native_mesh_hash') != build['combined_mesh_hash']:
        raise ValueError('Stale mq-26 opened native observations')
    coverage = {}; missing = []; table = io.StringIO(); writer = csv.writer(table, lineterminator='\n')
    writer.writerow(['view', 'part', 'solo_pixels', 'pure_owner_pixels', 'explicit_occlusion'])
    rasters = {}
    for view in ('front', 'rear'):
        raster = load_render(spec, capture, view); rasters[view] = raster
        rgba = np.asarray(Image.open(capture / (view + '_parts.png')).convert('RGBA'))
        coverage[view] = part_coverage(spec, raster, rgba)
        for name, row in coverage[view].items():
            occlusion = MQ26_OCCLUSIONS[view].get(name) if row['pure_owner_pixels'] == 0 else ''
            row['explicit_occlusion'] = occlusion
            if not row['solo_pixels'] or row['clipped_at_canvas'] or (not row['pure_owner_pixels'] and not occlusion):
                missing.append(view + ':' + name)
            writer.writerow([view, name, row['solo_pixels'], row['pure_owner_pixels'], occlusion])
    clay = np.asarray(Image.open(capture / 'front_clay.png').convert('L')).astype(float)
    points = {}
    for piece in spec['pieces']:
        if piece['id'].startswith(('finger_', 'thumb_')): points[piece['id'] + '_render'] = piece['vertices']
    labels = list(spec['labels'])
    hands = {'near': near_gate(spec, points, rasters['front'].owners, clay, labels),
             'far': far_gate(spec, points, rasters['front'].owners, labels)}
    joint_gates = captured_pose_gates(spec, json.loads((capture / 'joints_px.json').read_text()), native)
    joint_gates['checks'] = {k: bool(v) for k, v in joint_gates['checks'].items()}
    checks = {'native_joints_match_capture': joint_gates['passed'], 'all_pose_rows': numeric_contract(spec, native),
              'opened_native': native.get('passed') is True and all(native.get('checks', {}).values()),
              'complete_labels': not missing,
              'near_hand_four_separated_fingers_and_thumb_in_capture': hands['near']['passed'],
              'far_hand_wraps_shaft_in_capture': hands['far']['passed'],
              'native_mutations': set(native.get('mutations', {})) == EXPECTED_MUTATIONS and all(m['caught'] for m in native['mutations'].values()),
              # The bell hangs inside: it must still show between the ribs in the front capture.
              'bell_visible_between_ribs_in_capture': coverage['front']['bell']['pure_owner_pixels'] >= DELIVERY_DEFAULTS['bell_visible_pixels']}
    result = {'passed': all(checks.values()), 'checks': checks, 'spec_hash': digest(spec),
              'native_mesh_hash': build['combined_mesh_hash'], 'native_probe_sha256': sha(capture / 'mq26_native.json'),
              'capture_manifest_sha256': sha(capture / 'capture_manifest.json'), 'per_part_coverage': coverage,
              'unexplained_parts': missing, 'hand_capture_gates': hands, 'pose_values': native['pose_values'],
              'proportion_rows': native['proportion_rows'], 'director_accepted_rows': native['director_accepted_rows'],
              'staff_top_over_H': native['staff_top_over_H'], 'shoulder_and_turn': native['shoulder_and_turn'],
              'capture_joint_gates': joint_gates}
    if write_outputs:
        (capture / 'per_part_coverage.csv').write_text(table.getvalue())
        lines = ['| Requirement | Value | Target | Native | Tolerance | Result |', '|---|---|---:|---:|---:|---|']
        for r in native['pose_values']:
            lines.append(f"| {r['requirement']} | {r['name']} | {r['target']:.9f} | {r['measured']:.9f} | {r['tolerance']} | {'PASS' if r['passed'] else 'FAIL'} |")
        lines += ['', f"Top staff tine / H: {native['staff_top_over_H']:.6f}.", '', native['definition'], '',
                  json.dumps(native['shoulder_and_turn'], sort_keys=True)]
        (capture / 'pose_table.md').write_text('\n'.join(lines) + '\n')
        lines = ['| Proportion (sprite-style, front capture) | Original / H | Take three / H | Error | Result |', '|---|---:|---:|---:|---|']
        for name, row in native['proportion_rows'].items():
            verdict = 'PASS' if row['within_10_percent'] else (
                'ACCEPTED AS BUILT (%.3f H, %+.1f%%)' % (row['director_accepted_over_H'], 100 * row['error_vs_accepted'])
                if row.get('within_10_percent_of_accepted') else 'FAIL')
            lines.append(f"| {name} | {row['original_over_H']:.4f} | {row['measured_over_H']:.4f} | {row['relative_error']:+.1%} | {verdict} |")
        lines += ['', native['proportions']['definition'],
                  f"Own sole-to-taller-tine height on the capture: {native['proportions']['own_height_over_H']:.4f} H."]
        (capture / 'proportion_table.md').write_text('\n'.join(lines) + '\n')
        result['proof_text_sha256'] = {n: sha(capture / n) for n in ('pose_table.md', 'proportion_table.md', 'per_part_coverage.csv')}
        write(capture / 'mq26_acceptance.json', result)
    return result


def compose(capture, refs, stem):
    d = DELIVERY_DEFAULTS; size = d['tile_px']
    canvas = Image.new('RGBA', (len(refs) * size, d['height_px']), tuple(d['background_rgba']))
    draw = ImageDraw.Draw(canvas); inputs = []
    for k, (title, path, scale) in enumerate(refs):
        im = Image.open(path).convert('RGBA')
        if scale != 1: im = im.resize((im.width * scale, im.height * scale), Image.Resampling.NEAREST)
        edge = int(np.argwhere(np.asarray(im)[:, :, 3] >= d['alpha_threshold'])[:, 0].max()) + 1
        y = d['sole_px'] - edge
        if y < 32 or y + im.height > canvas.height: raise ValueError('Comparison sheet clips its source')
        canvas.alpha_composite(im, (k * size + (size - im.width) // 2, y))
        draw.text((k * size + d['caption_padding_px'], d['caption_padding_px']), title, fill='white')
        inputs.append({'path': str(path.resolve().relative_to(PROJECT)) if path.resolve().is_relative_to(PROJECT) else path.name,
                       'sha256': sha(path), 'display_scale': scale, 'y_px': y})
    canvas.save(capture / (stem + '.webp'), lossless=True, exact=True, method=d['webp_method'])
    if not np.array_equal(np.asarray(canvas), np.asarray(Image.open(capture / (stem + '.webp')).convert('RGBA'))):
        raise ValueError('Contact-sheet codec changed pixels')
    write(capture / (stem + '.json'), {'inputs': inputs, 'sheet_sha256': sha(capture / (stem + '.webp')),
        'registration': 'Native clays 1:1 (full size) on the inherited mq-17 scale; original art 4x nearest. Common sole baseline; translation only.'})


SHEETS = ('contact_sheet', 'contact_sheet_take_three')


def review_sheet(capture):
    """Front clay beside the original (4x) and take two, then both rears; and the
    take-three front and rear at full size beside the original. One sole line."""
    capture = Path(capture); original = ('Original art (4x)', PROJECT / 'assets/units/storm_cantor.png', 4)
    compose(capture, [original, ('Take two front (mq-19)', TAKE_TWO / 'front_clay.png', 1),
                      ('Take three front (mq-26)', capture / 'front_clay.png', 1),
                      ('Take two rear (mq-19)', TAKE_TWO / 'rear_clay.png', 1),
                      ('Take three rear (mq-26)', capture / 'rear_clay.png', 1)], SHEETS[0])
    compose(capture, [original, ('Take three front (mq-26), full size', capture / 'front_clay.png', 1),
                      ('Take three rear (mq-26), full size', capture / 'rear_clay.png', 1)], SHEETS[1])
