"""Exact brief constraints, using mq-17 lengths and its body-space axes.

+X faces the board viewer, +Y is near. No tuning, camera fit or mesh caliper
changes occur here. The two-circle hip solution preserves both leg lengths;
the solution nearest the inherited hips preserves the construction branch.
Conflicting gates remain visible in the report, never silently relaxed.
"""
import math
import numpy as np

SOLVER_DEFAULTS = {'epsilon': 1e-10, 'root_iterations': 80,
                   'near_swing_search_degrees': [-89., 89.]}


def unit(v):
    v = np.asarray(v, float)
    length = np.linalg.norm(v)
    if length <= SOLVER_DEFAULTS['epsilon']:
        raise ValueError('Undefined pose direction')
    return v / length


def rotation(axis, degrees):
    x, y, z = unit(axis); a = math.radians(degrees); c, s = math.cos(a), math.sin(a)
    skew = np.array([[0, -z, y], [z, 0, -x], [-y, x, 0]])
    return c*np.eye(3)+(1-c)*np.outer([x,y,z], [x,y,z])+s*skew


def alignment(before, after):
    a, b = unit(before), unit(after); cross = np.cross(a, b)
    if np.linalg.norm(cross) < SOLVER_DEFAULTS['epsilon']:
        if a@b < 0:
            raise ValueError('Antiparallel attachment needs a director axis')
        return np.eye(3)
    return rotation(cross, math.degrees(math.acos(float(np.clip(a@b, -1, 1)))))


def joint_lengths(j, side, chain):
    a, b, c = (j[k+'_'+side] for k in chain)
    return np.linalg.norm(b-a), np.linalg.norm(c-b)


def two_bone(a, target, lengths, pole):
    a, target = np.asarray(a), np.asarray(target)
    upper, lower = lengths; distance = np.linalg.norm(target-a)
    if not abs(upper-lower) < distance < upper+lower:
        raise ValueError('Director target outside inherited two-bone reach')
    axis = unit(target-a); bend = unit(pole-axis*(pole@axis))
    along = (upper**2-lower**2+distance**2)/(2*distance)
    return a+along*axis+math.sqrt(max(0., upper**2-along**2))*bend


def hips(old, ankles, pelvis_rotation, p, resolution=None):
    """Intersect Y/Z reach circles with inherited hip X placement fixed."""
    original_centre = (old['hip_near']+old['hip_far'])/2
    centre = original_centre.copy()
    if isinstance(resolution,dict) and 'hip_centre_x_over_L' in resolution:
        centre[0] = resolution['hip_centre_x_over_L']
    offsets = {s: pelvis_rotation@(old['hip_'+s]-original_centre) for s in ('near','far')}
    circles = []
    for side in ('near','far'):
        a, b = joint_lengths(old, side, ('hip','knee','ankle'))
        reach2 = a*a+b*b+2*a*b*math.cos(math.radians(p[side+'_knee_degrees']))
        dx = centre[0]+offsets[side][0]-ankles[side][0]
        radius2 = reach2-dx*dx
        if radius2 <= 0:
            raise ValueError('Leg cannot reach directed step')
        circles.append((ankles[side][1:]-offsets[side][1:], math.sqrt(radius2)))
    (a, ra), (b, rb) = circles; direction = unit(b-a); distance = np.linalg.norm(b-a)
    along = (ra*ra-rb*rb+distance*distance)/(2*distance)
    height2 = ra*ra-along*along
    if height2 < 0:
        raise ValueError('Directed pelvis tilt, knees and stance have no hip solution')
    perpendicular = np.array([-direction[1], direction[0]])
    options = [a+along*direction+sign*math.sqrt(height2)*perpendicular for sign in (-1,1)]
    yz = min(options, key=lambda v: np.linalg.norm(v-centre[1:]))
    solved = np.array([centre[0], *yz])
    return solved, offsets, original_centre


def solve(baseline, p, resolution=None):
    old = {k: np.asarray(v, float) for k,v in baseline['joints'].items()}
    j = {k: v.copy() for k,v in old.items()}; gauge = baseline['mq17']
    H, L = gauge['height_m'], gauge['leg_length_m']
    width = abs(old['shoulder_near'][1]-old['shoulder_far'][1])
    pelvis_rotation = rotation([1,0,0], -p['pelvis_down_near_degrees'])
    # Preserve the stance centre and sole plane; change only directed span/step.
    ankle_centre = (old['ankle_near']+old['ankle_far'])/2
    ankles = {s: ankle_centre+np.array([sign*p['near_step_over_L']*L/2,
        sign*p['ankle_span_over_shoulders']*width/2, 0]) for s,sign in [('near',1),('far',-1)]}
    hip_centre, offsets, old_centre = hips(old, ankles, pelvis_rotation, p, resolution)
    j['pelvis'] = hip_centre+pelvis_rotation@(old['pelvis']-old_centre)
    # The upper body lean starts at the hips, independent of the pelvic roll.
    yaw = rotation([0,0,1], p['chest_yaw_toward_viewer_degrees'])
    chest_rotation = yaw@rotation([0,1,0], p['forward_lean_degrees'])
    if isinstance(resolution,dict):
        chest_rotation = chest_rotation@rotation([1,0,0],resolution.get('chest_roll_degrees',0))
    head_rotation = yaw@rotation([0,1,0], p['head_down_degrees'])
    for key in ('torso','head','shoulder_near','shoulder_far','bell_hook'):
        j[key] = hip_centre+chest_rotation@(old[key]-old_centre)
    j['head_tip'] = j['head']+head_rotation@(old['head_tip']-old['head'])
    if isinstance(resolution,dict):
        for name in ('shoulder_near','shoulder_far'):
            if name+'_over_H' in resolution:
                j[name] = np.asarray(resolution[name+'_over_H'],float)*H
    for side in ('near','far'):
        j['hip_'+side] = hip_centre+offsets[side]
        j['ankle_'+side] = ankles[side]
        j['knee_'+side] = two_bone(j['hip_'+side], ankles[side],
            joint_lengths(old, side, ('hip','knee','ankle')), np.array([1.,0,0]))
        j['foot_tip_'+side] = old['foot_tip_'+side]+ankles[side]-old['ankle_'+side]
    j['hand_far'] = j['shoulder_far']+np.array([p['fist_forward_over_L']*L, -p['fist_outward_over_L']*L, 0])
    j['hand_far'][2] = p['fist_height_over_H']*H
    a = math.radians(p['far_elbow_outward_degrees'])
    j['elbow_far'] = two_bone(j['shoulder_far'], j['hand_far'],
        joint_lengths(old,'far',('shoulder','elbow','hand')), np.array([0.,-math.sin(a),-math.cos(a)]))
    # The previous shoulder-pendulum swing is replaced by the unique swing
    # satisfying the directed wrist/thigh clearance on the same forward branch.
    delta = alignment(old['knee_near']-old['hip_near'], j['knee_near']-j['hip_near'])
    thigh = next(x for x in baseline['pieces'] if x['id']=='thigh_plate_near')
    thigh_points = j['hip_near']+np.einsum('nj,kj->nk',np.asarray(thigh['vertices'])-old['hip_near'],delta)
    target_x = thigh_points[:,0].max()+p['near_wrist_ahead_over_L']*L
    upper_length, fore_length = joint_lengths(old,'near',('shoulder','elbow','hand'))
    out, bend = map(math.radians, (p['near_upper_out_degrees'],p['near_elbow_degrees']))
    def near_arm(swing):
        a = math.radians(swing)
        down = np.array([math.sin(a),0,-math.cos(a)])
        forward = np.array([math.cos(a),0,math.sin(a)])
        upper = math.cos(out)*down+np.array([0,math.sin(out),0])
        fore = math.cos(bend)*upper+math.sin(bend)*forward
        elbow = j['shoulder_near']+chest_rotation@upper*upper_length
        return elbow, elbow+chest_rotation@fore*fore_length
    lo, hi = SOLVER_DEFAULTS['near_swing_search_degrees']
    if not near_arm(lo)[1][0] <= target_x <= near_arm(hi)[1][0]:
        raise ValueError('Near wrist clearance outside directed arm swing')
    for _ in range(SOLVER_DEFAULTS['root_iterations']):
        mid = (lo+hi)/2
        if near_arm(mid)[1][0] < target_x: lo = mid
        else: hi = mid
    j['elbow_near'], j['hand_near'] = near_arm((lo+hi)/2)
    for side in ('near','far'):
        j['hand_tip_'+side] = j['hand_'+side]+chest_rotation@(old['hand_tip_'+side]-old['hand_'+side])
    return j, {'pelvis':pelvis_rotation, 'torso':chest_rotation, 'head':head_rotation}, thigh_points


def staff_frame(p):
    """12° total tilt and 4° sagittal tilt; outward is the negative Y side."""
    forward = math.tan(math.radians(p['staff_forward_degrees']))
    total = math.tan(math.radians(p['staff_from_vertical_degrees']))
    if abs(forward) > total:
        raise ValueError('Staff forward tilt exceeds total inclination')
    up = unit([forward, -math.sqrt(total*total-forward*forward), 1])
    # Preserve the fork/pennant plane while inclining the entire held item.
    return alignment([0,0,1], up)
