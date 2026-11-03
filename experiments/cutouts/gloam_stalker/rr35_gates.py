"""Strict rr-35 gates; design conflicts remain failures, never exemptions."""
import argparse
from pathlib import Path
import sys
import numpy as np
from PIL import Image
from rr35_case import PROJECT, CASE, ASSETS, DIRECTOR
sys.path[:0] = [str(PROJECT / 'tools'), str(PROJECT)]
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.gates import structure_errors, source_errors, bone_errors, native_errors, bindings, matrix
from humanoid_cutout.action_direction import report as direction_report
from humanoid_cutout.reach import report as reach_report
from humanoid_cutout.walk_gates import report as walk_report, support_report, summary
from humanoid_cutout.walk_gates import apex_errors
from humanoid_cutout.anatomy import for_layout
from humanoid_cutout.bone_evidence import read_report
from rr35_acceptance import carapace_errors, draw_order_errors, slash_report, native_components, native_draw_order

WRIST_SNAPPING_TOLERANCE_PX = 2 ** .5  # Independent whole-pixel joint snaps.
ROTATION_HALF_STEP_RAD = np.deg2rad(.75)  # Half the binding 1.5-degree step.
EPSILON = 0.0001  # Shared serialized Bone2D tolerance.


def claw_errors(layout, samples):
    """Every rigid blade shares the solved forearm's basis and wrist origin."""
    errors = []
    parts = {p['name']: p for p in layout['parts']}
    meshes = {m['name'] for m in layout['joint_meshes']}
    for side in ('near', 'far'):
        name, fore = 'hand_' + side, 'fore_' + side
        if name in meshes or parts[name]['bone'] != name:
            errors.append('blade-claw must be a rigid hand: ' + name)
        for row in samples['samples']:
            if row['view'] != layout['facing']: continue
            hand = matrix(row['bones'][name]['global'])
            arm = matrix(row['bones'][fore]['global'])
            if not np.allclose(hand[:2, :2], arm[:2, :2], atol=EPSILON, rtol=0):
                errors.append(f'{row["view"]}/{row["clip"]}/{row["frame"]}: blade-claw forearm basis: {name}')
            rest_delta = np.asarray(layout['joints'][name]['position']) - layout['joints'][fore]['position']
            expected = arm @ np.append(rest_delta, 1)
            tolerance = (WRIST_SNAPPING_TOLERANCE_PX + 2 * np.linalg.norm(rest_delta) * np.sin(ROTATION_HALF_STEP_RAD / 2)) if row['kind'] == 'presented' else EPSILON
            if np.linalg.norm(hand[:2, 2] - expected[:2]) > tolerance:
                errors.append(f'{row["view"]}/{row["clip"]}/{row["frame"]}: blade-claw wrist detached: {name}')
            if name not in row['parts']:

                errors.append('missing actual rigid blade Sprite2D: ' + name)
                continue
            sprite = matrix(row['parts'][name]['transform'])
            if not np.allclose(sprite[:2, :2], hand[:2, :2], atol=EPSILON, rtol=0):
                errors.append('blade-claw sprite deformed: ' + name)
    return sorted(set(errors))


def knee_policy_report(layout):
    """Director feedback 1 / Thrall rule, measured from certified rest joints."""
    from humanoid_cutout.anatomy import for_layout
    anatomy = for_layout(layout)
    toward_facing = 1 if layout['facing'] == 'front' else -1
    rows, errors = {}, []
    for side in ('near', 'far'):
        a, b, c = [np.asarray(layout['joints'][name + '_' + side]['position'])
                   for name in ('thigh', 'shin', 'foot')]
        upper, lower = b - a, c - b
        cross = upper[0] * lower[1] - upper[1] * lower[0]
        bend = abs(float(np.rad2deg(np.arctan2(cross, upper @ lower))))
        ray, elbow = c - a, b - a
        rest_side = int(np.sign(ray[0] * elbow[1] - ray[1] * elbow[0]))
        straight = bend <= anatomy['knee_policy']['near_straight_deg']
        expected = toward_facing if straight else rest_side
        actual = anatomy['legs'][side][layout['facing']]['bend_side']
        rows[side] = {'rest_bend_deg': bend, 'rest_side': rest_side,
            'near_straight': straight, 'expected_side': expected, 'declared_side': actual}
        if actual != expected:
            errors.append(f'{layout["facing"]}/{side}: knee policy differs from ' +
                          ('facing for near-straight rest' if straight else 'native rest bend side'))
    return {'ok': not errors, 'errors': errors, **anatomy['knee_policy'], 'legs': rows}


def facing_errors(layout):
    return knee_policy_report(layout)['errors']


def evaluate(native=None, case=CASE):
    data, build = [read_json(case / p) for p in ('compiled_motion.json', 'proof/build.json')]
    samples, current = read_report(case), bindings(case)
    errors, views = [], {}
    for root in (case, ASSETS / 'humanoid_v2'):
        if (root / 'director_motion.json').read_bytes() != DIRECTOR.read_bytes(): errors.append('Protected director tracks differ')
    for view in data['view_tracks']:
        layout = read_json(case / f'layouts/{view}.json')
        cut = structure_errors(layout, build) + source_errors(case, layout, build)
        bone = bone_errors(layout, data, samples, current)
        direction = direction_report(layout, data, samples, current, require_presented=True)
        reach = reach_report(layout, data, step_distance_px=samples['step_distance_px'], screen_pixel_scale=samples['screen_pixel_scale'])
        walk, supports = walk_report(layout, data, samples), support_report(layout, data, samples)
        claws = claw_errors(layout, samples)
        policy = knee_policy_report(layout)
        facing = policy['errors']
        order = draw_order_errors(layout, samples)
        carapace = carapace_errors(case, layout)
        slash = slash_report(layout, data, samples)
        errors += order + carapace + slash['errors']
        errors += cut + bone + direction['errors'] + reach['errors'] + walk['errors'] + supports['errors'] + claws + facing
        views[view] = {'cut_errors': cut, 'bone_errors': bone, 'direction': direction,
            'reach': reach, 'walk': walk, 'supports': supports, 'claw_errors': claws,
            'facing_errors': facing, 'knee_policy': policy, 'draw_order_errors': order,
            'carapace_errors': carapace, 'slash_reach': slash}
    floating = None
    defects = None
    if native:
        errors += native_errors(case, native, failure_output=case / 'proof/logs/native_failures')
        manifest = read_json(native / 'frames.json')
        for view in data['view_tracks']:
            errors += native_draw_order(read_json(case / f'layouts/{view}.json'), manifest)
        floating = native_components(native, manifest)
        errors += floating['errors']
        from rr36_native_checks import native_report
        defects = native_report(native)
        errors += defects['errors']
    result = {'ok': not errors, 'errors': sorted(set(errors)), 'views': views,
        'design_placeholders': read_json(case / 'inputs.json')['design_placeholders'],
        'floating_pieces': floating, 'rr36_native_defects': defects,
        'native_pixels': bool(native), 'production_ready': not errors and bool(native),
        'reach_policy': '1000 intervals; overreach reported, minimum reach fails'}
    name = 'native_gates' if native else 'gates'
    write_json(case / f'proof/logs/{name}.json', result)
    compact = dict(result, views={}, errors=result['errors'][:20], error_count=len(result['errors']), full_diagnostics=f'logs/{name}.json')
    for view, report in views.items():
        compact['views'][view] = dict(report, direction={k: v for k, v in report['direction'].items() if k != 'rows'},
            walk=summary(report['walk']), supports=summary(report['supports']),
            bone_errors=report['bone_errors'][:12], bone_error_count=len(report['bone_errors']))
    write_json(case / f'proof/{name}.json', compact)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', type=Path, default=CASE)
    parser.add_argument('--native', type=Path)
    args = parser.parse_args()
    result = evaluate(args.native, args.case)
    print('RR35 ALL GATES: %s (%d unique errors; native=%s)' % ('PASS' if result['ok'] else 'FAIL', len(result['errors']), bool(args.native)))
    for view, report in result['views'].items():
        print('RR35 %s: cut=%d bone=%d direction=%d walk=%d supports=%d claws=%d facing=%d reach=%d overreach=%d' %
            (view.upper(), len(report['cut_errors']), len(report['bone_errors']), len(report['direction']['errors']),
             len(report['walk']['errors']), len(report['supports']['errors']), len(report['claw_errors']),
             len(report['facing_errors']), len(report['reach']['errors']), len(report['reach']['overreach'])))
        for swing in report['walk']['swings']:
            layout = read_json(args.case / f'layouts/{view}.json')
            if not apex_errors(swing, for_layout(layout)['knee_policy'], view, swing['side']): continue
            phase = next(row['phase'] for row in report['walk']['frames']
                         if row['kind'] == 'presented' and row['frame'] == swing['apex_frame'])
            print('RR35 %s %s APEX: phase %.6f / frame %d; swing %.6f deg; stance %.6f deg' %
                (view.upper(), swing['side'], phase, swing['apex_frame'],
                 swing['apex_swing_bend_deg'], swing['apex_stance_bend_deg']))
    for error in result['errors'][:12]: print(error)
    raise SystemExit(int(not result['ok']))
