"""rr-57 attack-only compile; production walk-01 is the protected baseline.

The director authorized peak key selection from source-pixel constraints. Solve
hand targets in the torso frame rather than guessing a lift from the canvas.
No paint or unowned motion is rebuilt by this command.
"""
from copy import deepcopy
import json
import math
import shutil
from rr48_build import ROOT, CASE, ASSETS, DIRECTOR, VIEWS
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.compiler import compile_motion
from rr48_motion import clamp_limits

BASE = CASE/'rr57'
CHOSEN_DEFAULTS = {'arc_knots_per_unit_phase': 120}
TARGETS = {'rake': {'peak': .25, 'hand_below_shoulder_px': 12},
           'sweep': {'peak': .28, 'hand_below_shoulder_px': 0},
           'fall': {'peak': .30, 'hand_below_shoulder_px': -12}}


def value_at(keys, phase):
    for a, b in zip(keys, keys[1:]):
        if a[0] <= phase <= b[0]:
            t = (phase-a[0])/(b[0]-a[0]); t = t*t*(3-2*t)
            return a[1]+(b[1]-a[1])*t
    return keys[-1][1]


def elbow_safe_arc(keys, layout, projection, peak, contact):
    """The chord of a raised wind-up folds through the shoulder. Follow the
    reachable outer arc instead, retaining the exact keyed endpoints. These
    source channels still use the ordinary runtime IK and elbow policy.
    """
    joints = layout['joints']; sx, sy = joints['upper_far']['position']; hx, hy = joints['hand_far']['position']
    fx, fy = projection['forward']; sign = projection['lean_sign']
    def ray(at):
        f = value_at(keys['hand_far.forward_px'], at); lift = value_at(keys['hand_far.lift_px'], at)
        a = math.radians(value_at(keys['torso.lean_deg'], at)*sign)
        x, y = hx-sx+fx*f, hy-sy+fy*f-lift
        return math.cos(a)*x-math.sin(a)*y, math.sin(a)*x+math.cos(a)*y
    endpoints = {at: ray(at) for at in (0,peak,contact)}
    added = {name: [] for name in ('hand_far.forward_px','hand_far.lift_px')}
    # Numerical arc resolution; proof also checks native frames/key midpoints.
    count = round(contact*CHOSEN_DEFAULTS['arc_knots_per_unit_phase'])
    phases = {i/count * contact for i in range(1,count)}
    phases -= set(at for at,_ in keys['hand_far.forward_px'])
    for at in sorted(phases):
        start, end = (0,peak) if at < peak else (peak,contact)
        t = (at-start)/(end-start); t = t*t*(3-2*t)
        x0,y0 = endpoints[start]; x1,y1 = endpoints[end]
        angle = math.atan2(y0,x0)*(1-t)+math.atan2(y1,x1)*t
        radius = math.hypot(x0,y0)*(1-t)+math.hypot(x1,y1)*t
        x,y = radius*math.cos(angle),radius*math.sin(angle)
        # After contact the legacy 4-degree compiled limit is untouched;
        # match that existing limit as the wind-up converges on contact.
        lean = value_at(keys['torso.lean_deg'], at)
        a = math.radians(lean*sign)
        local_x,local_y = math.cos(a)*x+math.sin(a)*y,-math.sin(a)*x+math.cos(a)*y
        f = (local_x-hx+sx)/fx; lift = hy-sy+fy*f-local_y
        added['hand_far.forward_px'].append([at,round(f,9)])
        added['hand_far.lift_px'].append([at,round(lift,9)])
    for name, rows in added.items(): keys[name] = sorted(keys[name]+rows)


def replace_key(keys, phase, value):
    for row in keys:
        if row[0] == phase:
            row[1] = round(value, 9)
            return
    raise ValueError('Missing owned key at '+str(phase))


def hand_keys(layout, forward, lean, below, *, behind=False, old_forward=0, clip=''):
    joints = layout['joints']
    sx, sy = joints['upper_far']['position']
    hx, hy = joints['hand_far']['position']
    angle = math.radians(lean)
    # The sweep draws the guard's horizontal shoulder/wrist separation back
    # over that shoulder. Other clips retain their existing draw-back channel.
    f = old_forward
    if behind:
        dx = -math.copysign(abs(hx-sx), forward[0])
        # The existing facing-side IK branch cannot fold an upper arm back
        # through its shoulder. Keep its elbow legal without changing the
        # shared solver; the report names the rear sweep's draw-back limit.
        if layout['facing'] == 'rear': dx = abs(hx-sx)
        f = (math.cos(angle)*dx + math.sin(angle)*below - (hx-sx))/forward[0]
    if layout['facing'] == 'front' and clip in ('sweep', 'fall'):
        ex, ey = joints['fore_far']['position']
        reach = math.hypot(ex-sx, ey-sy)+math.hypot(hx-ex, hy-ey)
        # Leave the native one-pixel rounding lattice inside full extension.
        dx = math.sqrt((reach-(.5 if clip == 'fall' else 1))**2-below**2)
        f = (math.cos(angle)*dx + math.sin(angle)*below - (hx-sx))/forward[0]
    lift = hy-sy + forward[1]*f + math.tan(angle)*(hx-sx+forward[0]*f) - below/math.cos(angle)
    return f, lift


def author_round_zero():
    source = read_json(BASE/'baseline_director.json')
    projection = read_json(BASE/'baseline_compiled.json')['projection']
    for clip, target in TARGETS.items():
        definition = source['ashen_reaver']['clips'][clip]
        phase = target['peak']
        lean = next(k[1] for k in definition['keys']['torso.lean_deg'] if k[0] == phase)-2
        replace_key(definition['keys']['torso.lean_deg'], phase, lean)
        definition['windup_torso_limit_deg'] = abs(lean)
        definition['view_keys'] = {}
        for view in VIEWS:
            layout = read_json(CASE/f'layouts/{view}.json')
            keys = deepcopy(definition['keys'])
            old_forward = next(k[1] for k in keys['hand_far.forward_px'] if k[0] == phase)
            f, lift = hand_keys(layout, projection[view]['forward'], lean*projection[view]['lean_sign'],
                                target['hand_below_shoulder_px'], behind=clip == 'sweep', old_forward=old_forward, clip=clip)
            replace_key(keys['hand_far.forward_px'], phase, f)
            replace_key(keys['hand_far.lift_px'], phase, lift)
            attachment = layout['held_items']['falchion']
            grip = attachment['source_grip']; tip = attachment['floor_end']
            rest_angle = math.degrees(math.atan2(tip[1]-grip[1], tip[0]-grip[0]))
            # Fall is vertical. Rake/sweep keep their existing positive
            # draw-back angle, now measured back from upright, not hanging.
            back_angle = 0 if clip == 'fall' else next(k[1] for k in keys['falchion.angle_deg'] if k[0] == phase)
            if clip == 'sweep': back_angle = min(back_angle, 28.5)
            desired = -90 + (-math.copysign(back_angle, projection[view]['forward'][0]))
            rotation = (desired-rest_angle+180)%360-180
            angle = rotation/(projection[view]['lean_sign']*attachment.get('angle_sign', 1))
            replace_key(keys['falchion.angle_deg'], phase, angle)
            if view == 'front' and clip in ('sweep','fall'):
                # Arc transport must use the compiled torso contact endpoint.
                compiled_torso = deepcopy(keys['torso.lean_deg'])
                for row in compiled_torso:
                    if row[0] >= definition['contact']: row[1] = max(-4,min(4,row[1]))
                saved_torso = keys['torso.lean_deg']; keys['torso.lean_deg'] = compiled_torso
                elbow_safe_arc(keys, layout, projection[view], phase, definition['contact'])
                keys['torso.lean_deg'] = saved_torso
            if clip == 'sweep':
                # The far-side forward keys and low blade remain authored;
                # lower only the follow-through wrist to its own far knee.
                for at in (.6, .75):
                    forward = next(k[1] for k in keys['hand_far.forward_px'] if k[0] == at)
                    measured = read_json(BASE/'baseline_follow.json')[view][str(at)]
                    torso = measured['torso']; knee = measured['shin_far'][4:]
                    hand = layout['joints']['hand_far']['position']
                    bind = layout['joints']['torso']['position']
                    dx, dy = knee[0]-torso[4], knee[1]-torso[5]
                    x, y = torso[0]*dx+torso[1]*dy, torso[2]*dx+torso[3]*dy
                    forward = (x-hand[0]+bind[0])/projection[view]['forward'][0]
                    lift = hand[1]-bind[1]+projection[view]['forward'][1]*forward-y
                    replace_key(keys['hand_far.forward_px'], at, forward)
                    replace_key(keys['hand_far.lift_px'], at, lift)
            definition['view_keys'][view] = {name: keys[name] for name in
                ('hand_far.forward_px', 'hand_far.lift_px', 'falchion.angle_deg')}
        # The base channels are the front view; the rear replaces whole tracks.
        definition['keys'].update(definition['view_keys'].pop('front'))
    return source


def author():
    from rr48_front_windup import author as front_author
    return front_author()


def compiled(source_path=DIRECTOR):
    baseline = read_json(BASE/'baseline_compiled.json')
    layouts = {v: read_json(CASE/f'layouts/{v}.json') for v in VIEWS}
    fresh = clamp_limits(compile_motion(source_path, 'ashen_reaver', layouts, baseline['projection']))
    result = deepcopy(baseline)
    result['director_sha256'] = digest(source_path)
    for clip in TARGETS:
        result['clips'][clip] = fresh['clips'][clip]
        for view in VIEWS: result['view_tracks'][view][clip] = fresh['view_tracks'][view][clip]
    result['budget_clamps'] = fresh.get('budget_clamps', [])
    return result


def apply():
    # Keep the director's one-space serialization so protected clip sections
    # remain byte-identical, in addition to preserving every authored value.
    DIRECTOR.write_text(json.dumps(author(), indent=1)+'\n')
    for folder in (CASE, ASSETS/'humanoid_v2'):
        shutil.copyfile(DIRECTOR, folder/'director_motion.json')
        write_json(folder/'compiled_motion.json', compiled())
    cutout = read_json(CASE/'cutout.json')
    cutout['clips'] = read_json(CASE/'compiled_motion.json')['clips']
    write_json(CASE/'cutout.json', cutout)
    provenance = read_json(DIRECTOR.parent/'provenance.json')
    provenance['files']['motion_tracks.json'] = digest(DIRECTOR)
    (DIRECTOR.parent/'provenance.json').write_text(json.dumps(provenance, indent=1)+'\n')
    integration = read_json(ASSETS/'integration.json')
    integration['director_sha256'] = digest(DIRECTOR)
    for name in ('compiled_motion.json', 'director_motion.json'):
        integration['files']['humanoid_v2/'+name] = digest(ASSETS/'humanoid_v2'/name)
    write_json(ASSETS/'integration.json', integration)
    pins_path = ROOT/'tests/approved_asset_pins.json'; pins = read_json(pins_path)
    import hashlib
    for path in (ASSETS/'integration.json', ASSETS/'humanoid_v2/compiled_motion.json', ASSETS/'humanoid_v2/director_motion.json'):
        content = path.read_bytes()
        pins['files'][str(path.relative_to(ROOT))] = hashlib.sha1(b'blob '+str(len(content)).encode()+b'\0'+content).hexdigest()
    write_json(pins_path, pins)
    print('RR57 COMPILE: PASS (attack keys only; walk-01 source synchronized)')


if __name__ == '__main__': apply()
