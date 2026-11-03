"""Strict rr-37 gates; design conflicts remain failures, never exemptions."""
import argparse
from pathlib import Path
import sys
import numpy as np
from PIL import Image
from rr37_case import PROJECT, CASE, ASSETS, DIRECTOR
sys.path[:0] = [str(PROJECT / 'tools'), str(PROJECT)]
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.gates import structure_errors, source_errors, bone_errors, native_errors, bindings, matrix
from humanoid_cutout.action_direction import report as direction_report
from humanoid_cutout.reach import report as reach_report
from humanoid_cutout.walk_gates import report as walk_report, support_report, summary
from humanoid_cutout.walk_gates import apex_errors
from humanoid_cutout.anatomy import for_layout
from humanoid_cutout.bone_evidence import read_report
from rr37_acceptance import ownership_errors, draw_order_errors, spear_errors, native_components, native_draw_order, crystal_contact_errors


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
        spear = spear_errors(layout, data, samples)
        from rr43_spear import errors as rigid_spear_errors
        spear += rigid_spear_errors(case, layout, samples)
        policy = knee_policy_report(layout)
        facing = policy['errors']
        order = draw_order_errors(layout, samples)
        ownership = ownership_errors(case, layout)
        errors += order + ownership
        errors += cut + bone + direction['errors'] + reach['errors'] + walk['errors'] + supports['errors'] + spear + facing
        views[view] = {'cut_errors': cut, 'bone_errors': bone, 'direction': direction,
            'reach': reach, 'walk': walk, 'supports': supports, 'spear_errors': spear,
            'facing_errors': facing, 'knee_policy': policy, 'draw_order_errors': order,
            'ownership_errors': ownership}
    floating = None
    defects = None
    if native:
        native_joint_pockets=[]
        errors += native_errors(case, native, failure_output=case / 'proof/logs/native_failures',hole_details=native_joint_pockets)
        manifest = read_json(native / 'frames.json')
        from rr43_spear import native_gap_errors
        errors += native_gap_errors(case, native, manifest)
        from rr45_occlusion import native_report as shaft_occlusion_report
        shaft = shaft_occlusion_report(native,case,crops=case/'proof/logs/shaft_occlusion_crops')
        write_json(case/'proof/logs/shaft_occlusion.json',shaft)
        print('RR45 NATIVE SHAFT OCCLUSION: %s (%d frames; %d frame/piece findings)' %
            ('PASS' if shaft['ok'] else 'FAIL',len(shaft['frames']),len(shaft['findings'])))
        errors += [f'{r["view"]}/{r["clip"]}/{r["frame"]}: shaft draws over {r["piece"]}: {r["pixels"]}px'
            for r in shaft['findings']]
        for view in data['view_tracks']:
            errors += native_draw_order(read_json(case / f'layouts/{view}.json'), manifest)
        errors += crystal_contact_errors(case, native, manifest)
        floating = native_components(case, native, manifest)
        errors += floating['errors']
        from rr37_uncovered import native_report as uncovered_report
        uncovered=uncovered_report(native,case,joint_pockets=native_joint_pockets)
        errors += uncovered['errors']
        write_json(case/'proof/logs/uncovered_surfaces.json',uncovered)
        from rr37_native_checks import native_report
        defects = native_report(native,case)
        errors += defects['errors']
    result = {'ok': not errors, 'errors': sorted(set(errors)), 'views': views,
        'design_placeholders': read_json(case / 'inputs.json')['design_placeholders'],
        'floating_pieces': floating, 'rr37_native_defects': defects,
        'native_pixels': bool(native), 'production_ready': not errors and bool(native) and not read_json(case / 'inputs.json')['design_placeholders'],
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
    print('RR37 ALL GATES: %s (%d unique errors; native=%s)' % ('PASS' if result['ok'] else 'FAIL', len(result['errors']), bool(args.native)))
    for view, report in result['views'].items():
        print('RR37 %s: cut=%d bone=%d direction=%d walk=%d supports=%d spear=%d facing=%d reach=%d overreach=%d' %
            (view.upper(), len(report['cut_errors']), len(report['bone_errors']), len(report['direction']['errors']),
             len(report['walk']['errors']), len(report['supports']['errors']), len(report['spear_errors']),
             len(report['facing_errors']), len(report['reach']['errors']), len(report['reach']['overreach'])))
        for swing in report['walk']['swings']:
            layout = read_json(args.case / f'layouts/{view}.json')
            if not apex_errors(swing, for_layout(layout)['knee_policy'], view, swing['side']): continue
            phase = next(row['phase'] for row in report['walk']['frames']
                         if row['kind'] == 'presented' and row['frame'] == swing['apex_frame'])
            print('RR37 %s %s APEX: phase %.6f / frame %d; swing %.6f deg; stance %.6f deg' %
                (view.upper(), swing['side'], phase, swing['apex_frame'],
                 swing['apex_swing_bend_deg'], swing['apex_stance_bend_deg']))
    for error in result['errors'][:12]: print(error)
    raise SystemExit(int(not result['ok']))
