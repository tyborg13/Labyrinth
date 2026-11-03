"""Source-only director clearance sweep; never submits a bridge job.

The exact robe layout is separately compiled first. If that fails, the
clearance measurement still uses the complete requested lantern and iron
legs. Cloth is outside both clearance envelopes, so retaining the old wrap
for that diagnostic cannot change the measured gap. This is not delivery
acceptance and never relaxes the production compiler's geometry checks.
"""
import json
from collections import Counter
from copy import deepcopy
from .recipe import FOLDER,compile_spec
from .geometry import lantern_clearance
from spec.art_identity.maquettes.blender.contract import digest


def sweep():
    details=json.loads((FOLDER/'design_details.json').read_text())
    policy=details['TODO_DESIGN_lantern_leg_clearance_resolution']
    report={'scope':'source lantern and iron leg envelopes; no native build or capture',
            'design_details_sha256':digest(details),'required_minimum_over_H':policy['required_minimum_over_H'],
            'production_compile_error':None,'selected_fist_outward_over_L':None,'steps':[]}
    try:compile_spec()
    except ValueError as error:
        if not str(error).startswith('Overlapping or off-wrap strands'):raise
        report['production_compile_error']=str(error)
    diagnostic=deepcopy(details)
    if report['production_compile_error']:
        diagnostic['TODO_DESIGN_robe_layout']=None
        report['diagnostic_exclusion']='Requested robe cannot compile; retained wrap excluded from clearance envelopes.'
    start=policy['fist_outward_start_over_L'];step=policy['fist_outward_step_over_L'];end=policy['fist_outward_max_over_L']
    baseline_pose=None
    for i in range(round((end-start)/step)+1):
        value=round(start+i*step,12)
        spec=compile_spec(diagnostic,require_resolved=False,fist_outward_over_L=value)
        # A diagnostic spec explicitly retains its unresolved robe marker.
        # Validate the meshes actually used by this clearance measurement.
        for piece in spec['pieces']:
            if piece['part']=='lantern' or piece['part'].startswith(('thigh_','shin_','foot_')):
                edges=Counter(tuple(sorted((a,b))) for f in piece['faces'] for a,b in zip(f,f[1:]+f[:1]))
                if any(n!=2 for n in edges.values()):raise ValueError('Open clearance mesh: '+piece['id'])
        fixed_pose={k:v for k,v in spec['pose'].items() if k!='fist_outward_of_hip_over_L'}
        if baseline_pose is None:baseline_pose=fixed_pose
        elif baseline_pose!=fixed_pose:raise ValueError('Unexpected change to another pose control')
        clearance=lantern_clearance(spec,{p['id']:p['vertices'] for p in spec['pieces']},spec['mq18']['height_m'])
        gap=clearance['minimum_over_H'];passed=gap>=policy['required_minimum_over_H']
        report['steps'].append({'fist_outward_over_L':value,'minimum_over_H':gap,'passed':passed,
                                'spec_hash':digest(spec),'per_leg_piece_over_H':clearance['per_leg_piece_over_H']})
        print(f'MQ20_CLEARANCE_STEP: fist={value:.2f} L; gap={gap:.12f} H; '+('PASS' if passed else 'FAIL'),flush=True)
        if passed:
            report['selected_fist_outward_over_L']=value
            break
    report['other_pose_values_unchanged']=True
    report['clearance_meshes_closed']=True
    report['passed']=report['selected_fist_outward_over_L'] is not None
    report['stop_required']=not report['passed']
    return report


if __name__=='__main__':
    report=sweep()
    (FOLDER/'feedback1_clearance.json').write_text(json.dumps(report,indent=2)+'\n')
    print('MQ20_CLEARANCE_SWEEP: '+('PASS' if report['passed'] else 'FAIL; director stop condition reached'),flush=True)
    raise SystemExit(0 if report['passed'] else 1)
