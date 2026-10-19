"""Unrelaxed shared gates plus both-leg rigid boulder knee/support evidence."""
import argparse
from pathlib import Path
from rr18_case import CASE, DIRECTOR, ASSETS
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.gates import structure_errors, source_errors, bone_errors, native_errors, bindings
from humanoid_cutout.action_direction import report as direction_report
from humanoid_cutout.reach import report as reach_report
from rr18_checks import knee_report, support_report, production_rest_report
from rr18_seams import report as seam_report
from rr18_materials import continuation_errors
from maquette_motion.features import source_pixels
from maquette_motion.material_palette import rules
from humanoid_cutout.anatomy import load
from rr18_source_stage import raw_identity, visible_errors
from humanoid_cutout.walk_gates import write_reports as write_walk_reports


def run(native=None):
    data,build,samples = [read_json(CASE/p) for p in ('compiled_motion.json','proof/build.json','proof/samples.json')]
    errors,source = [],[]
    if (CASE/'director_motion.json').read_bytes()!=DIRECTOR.read_bytes(): errors.append('protected director tracks changed')
    current = bindings(CASE)
    reports = {name:{} for name in ('knees','supports','directions','reach','production_rest','seams','materials','raw_identity')}
    for view in data['view_tracks']:
        layout = read_json(CASE/f'layouts/{view}.json')
        source += structure_errors(layout,build)+source_errors(CASE,layout,build)
        errors += bone_errors(layout,data,samples,current)
        reports['seams'][view] = seam_report(layout,samples,True)
        visible={p['logical_part']:source_pixels(CASE,p) for p in layout['parts'] if not p.get('hidden_material')}
        hidden={p['logical_part']:source_pixels(CASE,p) for p in layout['parts'] if p.get('hidden_material')}
        reports['raw_identity'][view]=raw_identity(view)
        depths={p['logical_part']:p['z_index'] for p in layout['parts'] if not p.get('hidden_material')}
        material=continuation_errors(visible,hidden,load(CASE),rules(CASE,view))
        material+=visible_errors(visible,depths,view,load(CASE)['material_policy']['green_dominance_margin'])
        reports['materials'][view]={'ok':not material,'errors':material,'scope':'exact nearest own-surface provenance and hidden green residue'}
        reports['production_rest'][view] = production_rest_report(layout,CASE,ASSETS)
        reports['knees'][view] = knee_report(layout,data,samples)
        reports['supports'][view] = support_report(layout,data,samples)
        walk = reports['knees'][view]
        print('GAIT %s: %s (maximum fit %.6f px; total drop %.6f px; rigid air %.6f px)' %
              (view.upper(), 'PASS' if walk['ok'] else 'FAIL', walk['maximum_fit_px'],
               walk['maximum_total_pelvis_drop_px'], walk['maximum_rigid_air_px']))
        reports['directions'][view] = direction_report(layout,data,samples,current,require_presented=True)
        reports['reach'][view] = reach_report(layout,data,step_distance_px=samples['step_distance_px'],screen_pixel_scale=samples['screen_pixel_scale'])
        for name,views in reports.items():
            result = views[view]; errors+=result['errors']
            print(f'RR18 {view.upper()} {name.upper()}: {"PASS" if result["ok"] else "FAIL"} ({len(result["errors"])} errors)')
    errors+=source
    if native: errors+=native_errors(CASE,native)
    for name,report in reports.items():
        if name in ('knees','supports'):
            write_walk_reports(CASE,name,report)
            continue
        if name=='directions': report={v:{k:x for k,x in r.items() if k!='rows'} for v,r in report.items()}
        write_json(CASE/f'proof/{name}.json',report)
    placeholders=read_json(CASE/'inputs.json')['design_placeholders']
    result={'ok':not errors,'errors':sorted(set(errors)),'production_ready':not errors and not placeholders and bool(native),
            'design_placeholders':placeholders,'scope':'native windowed proof' if native else 'headless source/Bone2D evidence; native pixels pending'}
    write_json(CASE/('proof/native_gates.json' if native else 'proof/gates.json'),result)
    print(f'RR18 SOURCE/CUT GATES: {"FAIL" if source else "PASS"} ({len(source)} errors; both views)')
    print(f'RR18 ALL GATES: {"FAIL" if errors else "PASS"} ({len(result["errors"])} unique errors)')
    for error in result['errors'][:30]: print(error)
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--native',type=Path)
    raise SystemExit(int(not run(parser.parse_args().native)['ok']))
