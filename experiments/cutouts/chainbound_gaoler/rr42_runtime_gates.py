"""rr-42 gate bundle: runtime contracts plus authoritative source backing."""
import argparse
from pathlib import Path
from rr42_underlay import CASE, ASSETS
from rr42_gates import source_report
from rr38_gates import knee_policy_report
from rr38_acceptance import draw_order_errors, chain_errors, native_components, native_draw_order, hook_contact_errors
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.gates import structure_errors,bone_errors,bindings,native_errors
from humanoid_cutout.action_direction import report as direction_report
from humanoid_cutout.walk_gates import report as walk_report,support_report
from humanoid_cutout.reach import report as reach_report


def evaluate(case,native=None):
    data=read_json(case/'compiled_motion.json'); samples=read_json(case/'proof/logs/samples.json'); current=bindings(case)
    build=read_json(case/'proof/build.json');source=source_report();errors=source['errors'].copy();views={}
    for view in data['view_tracks']:
        layout=read_json(case/f'layouts/{view}.json')
        rows=structure_errors(layout,build)+bone_errors(layout,data,samples,current)
        rows+=direction_report(layout,data,samples,current,require_presented=True)['errors']
        rows+=walk_report(layout,data,samples)['errors']+support_report(layout,data,samples)['errors']
        rows+=reach_report(layout,data,step_distance_px=samples['step_distance_px'],screen_pixel_scale=samples['screen_pixel_scale'])['errors']
        rows+=chain_errors(layout,data,samples)+draw_order_errors(layout,samples)+knee_policy_report(layout)['errors']
        errors+=rows;views[view]={'errors':rows}
    sweep_path=case/'proof/logs/rr42_sweep.json'
    sweep=read_json(sweep_path) if sweep_path.exists() else None
    if sweep is None: errors.append('Full calibrated/painted exposure sweep has not run')
    else:
        from rr42_sweep import diagnostic_bindings
        expected=sum(round(d['seconds']*60) for d in data['clips'].values())*len(data['view_tracks'])
        if (len(sweep['frames'])!=expected or sweep['samples_sha256']!=digest(case/'proof/logs/samples.json')
                or sweep.get('inputs')!=current or sweep.get('diagnostic_inputs')!=diagnostic_bindings()):
            errors.append('Calibrated sweep incomplete/stale')
        if any(r['view']=='front' and 'uncovered_procedural_texels' not in r['metrics'] for r in sweep['frames']):
            errors.append('All-rounding front painted exposure sweep incomplete')
        errors += [f"{r['view']}/{r['clip']}/{r['frame']}: {','.join(r['kinds'])}" for r in sweep['errors']]
    if native:
        manifest=read_json(native/'frames.json')
        from rr42_retained import verify
        retained={}
        valid=bool(manifest.get('native_pixels'))
        if valid and manifest['inputs']!=current:
            try:retained=verify(manifest['inputs'],current,native)
            except ValueError as error:errors.append('Native proof is stale: '+str(error));valid=False
        if not valid:errors.append('Native proof is missing or stale')
        else:
            errors+=native_errors(case,native,failure_output=case/'proof/logs/native_failures',retained_binding_validator=verify)
            errors+=native_components(case,native,manifest)['errors']+hook_contact_errors(case,native,manifest)
            for view in data['view_tracks']: errors+=native_draw_order(read_json(case/f'layouts/{view}.json'),manifest)
            from rr42_native_checks import report as painted_report
            errors+=painted_report(case,native)['errors']
    result={'ok':not errors,'errors':errors,'views':views,'native_pixels':bool(native),'production_ready':bool(native) and not errors,
            'source_authority':source,'sweep_sha256':digest(sweep_path) if sweep else None}
    if native:result['retained_analysis_only_deltas']=retained
    name='native_gates' if native else 'gates';write_json(case/f'proof/logs/{name}.json',result)
    write_json(case/f'proof/{name}.json',{**result,'errors':errors[:20],'error_count':len(errors)})
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--case',type=Path,default=CASE/'proof/production_case');parser.add_argument('--native',type=Path)
    args=parser.parse_args();result=evaluate(args.case,args.native)
    print('RR42 ALL GATES: %s (%d errors; native=%s)'%('PASS' if result['ok'] else 'FAIL',len(result['errors']),bool(args.native)))
    for error in result['errors'][:12]:print(error)
    raise SystemExit(not result['ok'])
