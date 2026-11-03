"""Reuse the mq-18 shoulder rule and IK; solve the two revised knees separately."""
import math
import numpy as np
from ..pose import solve as inherited_solve, bend_joint


def solve(c,p,H,L,u,d):
    controls=dict(p,knee_bend_degrees=p['knee_bend_near_degrees'])
    joints,shear=inherited_solve(c,controls,H,L,u,d)
    for side in ('near','far'):
        hip=np.asarray(joints['hip_'+side]);ankle=np.asarray(joints['ankle_'+side])
        segment=np.linalg.norm(ankle-hip)/(2*math.cos(math.radians(p['knee_bend_'+side+'_degrees']/2)))
        joints['knee_'+side]=bend_joint(hip,ankle,segment,segment,[1,0,0]).tolist()
    # The far wrist target depends on the actual far thigh. Reuse the same
    # solve with its 10-degree knee, taking only its free arm endpoints.
    far,_=inherited_solve(c,dict(p,knee_bend_degrees=p['knee_bend_far_degrees']),H,L,u,d)
    for name in ('elbow_far','hand_far','hand_tip_far'):joints[name]=far[name]
    root=np.asarray(joints['shoulder_near']);pole=math.radians(p['near_pole_outward_degrees'])
    from ..pose import NUMERICAL_DEFAULTS
    joints['pole_near_root']=root.tolist()
    joints['pole_near_tip']=(root+np.array([0,math.sin(pole),-math.cos(pole)])*L*NUMERICAL_DEFAULTS['pole_control_gauge_over_L']).tolist()
    return joints,shear
