"""Numerical projection gates usable in host Python and Blender without Pillow."""
import numpy as np
from spec.art_identity.maquettes.raster import camera,project


def evaluate(spec,recorded,native):
    near,far=(recorded['front']['shoulder_'+s] for s in ('near','far'))
    expected=.15*abs(near[0]-far[0]);observed=near[1]-far[1]
    joints=native['observed_joints'];level=abs(joints['shoulder_near'][2]-joints['shoulder_far'][2])
    errors=[float(np.linalg.norm(np.subtract(project(spec,p,view,spec['mq19']['capture_px'])[:2],recorded[view][name])))
            for view in ('front','rear') for name,p in joints.items()]
    matrices={v:camera(spec,v)[0] for v in ('front','rear')}
    turn=matrices['rear'][:3,:3]@np.linalg.inv(matrices['front'][:3,:3])
    resolution=spec['mq19']['design'].get('pose_resolution')
    tolerance=resolution.get('level_tolerance_over_H',0)*spec['mq19']['gauge_H_m'] if isinstance(resolution,dict) else 1e-4
    limit=resolution.get('shoulder_rule_limit_px',10.) if isinstance(resolution,dict) else 10.
    checks={'shoulder_rule':abs(observed-expected)<=limit,'shoulders_level_3d':level<=tolerance,
        'native_joint_projection':max(errors)<=.02,
        'proper_true_turn':bool(np.allclose(turn,np.diag([-1,-1,1])) and abs(np.linalg.det(turn)-1)<1e-8),
        'same_camera_angles_and_scale':all(spec['view_transforms']['front'][k]==spec['view_transforms']['rear'][k]
            for k in ('azimuth_deg','elevation_deg','ortho_scale'))}
    for view in ('front','rear'):
        a=recorded[view]['hand_far'][0];b=recorded[view]['pelvis'][0]
        checks[view+'_staff_side']=a<b if view=='front' else a>b
    checks={k:bool(v) for k,v in checks.items()}
    return {'passed':all(checks.values()),'checks':checks,'shoulder_rise_px':float(observed),
        'target_shoulder_rise_px':float(expected),'shoulder_error_px':float(abs(observed-expected)),
        'shoulder_rule_limit_px':float(limit),'within_standard_10px':bool(abs(observed-expected)<=10.),
        'level_difference_m':float(level),'level_tolerance_m':tolerance,
        'maximum_joint_projection_error_px':max(errors),'rear_relative_matrix':turn.tolist(),
        'rear_determinant':float(np.linalg.det(turn))}
