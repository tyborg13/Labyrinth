"""Director feedback 1: source-space sword guard outside the front body line.

Only front hand/blade channels strictly before contact are replaced. Rear and
contact-on tracks come from the approved feedback-1 snapshot, not a rebuild of
the earlier exploratory pose. No paint or shared-runtime changes.
"""
from copy import deepcopy
import json
import math
from pathlib import Path
import subprocess
import sys
from rr48_build import CASE, ROOT
from cutout_pipeline.cases import read_json, write_json

CONSTRAINTS = {'hand_outside_shoulder_px': 4, 'fall_outward_deg': 10}
NUMERICS = {'knots_per_unit_phase': 120, 'straight_target_overshoot_px': 1,
            'candidate_step_deg': .25, 'candidate_steps_each_side': 12}


def value_at(keys, phase):
    for a, b in zip(keys, keys[1:]):
        if a[0] <= phase <= b[0]:
            t = (phase-a[0])/(b[0]-a[0]); t = t*t*(3-2*t)
            return a[1]+(b[1]-a[1])*t
    return keys[-1][1]


def author(use_solution=True):
    source = read_json(CASE/'rr57/feedback1_baseline_director.json')
    compiled = read_json(CASE/'rr57/feedback1_baseline_compiled.json')
    layout = read_json(CASE/'layouts/front.json'); joints = layout['joints']
    shoulder = joints['upper_far']['position']; elbow = joints['fore_far']['position']; hand = joints['hand_far']['position']
    reach = math.dist(shoulder, elbow)+math.dist(elbow, hand)
    projection = compiled['projection']['front']; fx, fy = projection['forward']; lean_sign = projection['lean_sign']
    peaks = {'rake': (.25,12), 'sweep': (.28,0), 'fall': (.30,-12)}
    budget_path=CASE/'rr57/front_guard_budget.json'
    if budget_path.exists():peaks['fall']=(.30,read_json(budget_path)['effective_hand_below_shoulder_px'])
    for clip, (peak, below) in peaks.items():
        definition = source['ashen_reaver']['clips'][clip]
        if clip == 'rake': continue # Measured by the same front gate; retain unless it fails.
        keys = definition['keys']; contact = definition['contact']
        torso = next(t['keys'] for t in compiled['view_tracks']['front'][clip] if t['source']=='torso.lean_deg')
        torso = [[k['at'],k['value']] for k in torso]
        def ray(at):
            f = value_at(keys['hand_far.forward_px'],at); lift = value_at(keys['hand_far.lift_px'],at)
            a = math.radians(value_at(torso,at))
            x,y = hand[0]-shoulder[0]+fx*f,hand[1]-shoulder[1]+fy*f-lift
            return math.cos(a)*x-math.sin(a)*y,math.sin(a)*x+math.cos(a)*y
        start = ray(0); end = ray(contact)
        peak_x = -20 if clip == 'sweep' or below>-12 else -math.sqrt(reach*reach-below*below)
        targets = {0:start,peak:(peak_x,below),contact:end}
        def channels(x,y,at):
            a = math.radians(value_at(torso,at))
            local_x,local_y = math.cos(a)*x+math.sin(a)*y,-math.sin(a)*x+math.cos(a)*y
            f = (local_x-hand[0]+shoulder[0])/fx
            return f, hand[1]-shoulder[1]+fy*f-local_y
        count = round(contact*NUMERICS['knots_per_unit_phase'])
        frames = round(definition['seconds']*60)
        phases = sorted({i/count*contact for i in range(count)}|{peak}|
                        {i/(frames-1) for i in range(frames) if i/(frames-1)<contact})
        generated = {'hand_far.forward_px':[], 'hand_far.lift_px':[]}
        for at in phases:
            left,right = (0,peak) if at<=peak else (peak,contact)
            t = (at-left)/(right-left); t=t*t*(3-2*t)
            x0,y0=targets[left];x1,y1=targets[right]
            a0=math.atan2(y0,x0)%(2*math.pi);a1=math.atan2(y1,x1)%(2*math.pi)
            angle=a0+(a1-a0)*t
            radius=math.hypot(x0,y0)*(1-t)+math.hypot(x1,y1)*t
            if clip=='fall' and below<=-12 and at not in (0,peak): radius=max(radius,reach+NUMERICS['straight_target_overshoot_px'])
            x,y=radius*math.cos(angle),radius*math.sin(angle)
            f,lift=channels(x,y,at)
            if at==0: f,lift=0,0
            generated['hand_far.forward_px'].append([at,round(f,9)])
            generated['hand_far.lift_px'].append([at,round(lift,9)])
        for name, rows in generated.items(): keys[name]=rows+[k for k in keys[name] if k[0]>=contact]
        if clip=='fall':
            attachment=layout['held_items']['falchion'];tip=attachment['floor_end'];grip=attachment['source_grip']
            rest=math.degrees(math.atan2(tip[1]-grip[1],tip[0]-grip[0]))
            desired=-90-CONSTRAINTS['fall_outward_deg']
            rotation=(desired-rest+180)%360-180
            angle=rotation/(lean_sign*attachment.get('angle_sign',1))
            for row in keys['falchion.angle_deg']:
                if row[0]==peak:row[1]=round(angle,9)
    solution=CASE/'rr57/front_guard_solution.json'
    if use_solution and solution.exists() and read_json(solution).get('fall_hand_below_shoulder_px',-12)==peaks['fall'][1]:
        for clip,channels in read_json(solution)['channels'].items():
            keys=source['ashen_reaver']['clips'][clip]['keys'];contact=source['ashen_reaver']['clips'][clip]['contact']
            for name,rows in channels.items():keys[name]=rows+[k for k in keys[name] if k[0]>=contact]
    return source


def solve(output):
    source=author(use_solution=False);data=read_json(CASE/'compiled_motion.json')
    layout=read_json(CASE/'layouts/front.json');j=layout['joints'];sx,sy=j['upper_far']['position'];hx,hy=j['hand_far']['position']
    fx,fy=data['projection']['front']['forward'];requests=[]
    clip='fall';keys=source['ashen_reaver']['clips'][clip]['keys'];contact=source['ashen_reaver']['clips'][clip]['contact']
    torso=next(t['keys'] for t in data['view_tracks']['front'][clip] if t['source']=='torso.lean_deg')
    torso=[[k['at'],k['value']] for k in torso]
    for at,f in keys['hand_far.forward_px']:
        if at>=contact:continue
        lift=value_at(keys['hand_far.lift_px'],at);a=math.radians(value_at(torso,at))
        lx,ly=hx-sx+fx*f,hy-sy+fy*f-lift;x,y=math.cos(a)*lx-math.sin(a)*ly,math.sin(a)*lx+math.cos(a)*ly
        offsets=[0] if at in (0,.3) else [0]+[sign*n*NUMERICS['candidate_step_deg'] for n in range(1,NUMERICS['candidate_steps_each_side']+1) for sign in (-1,1)]
        candidates=[]
        for offset in offsets:
            angle=math.radians(offset);rx,ry=math.cos(angle)*x-math.sin(angle)*y,math.sin(angle)*x+math.cos(angle)*y
            local_x,local_y=math.cos(a)*rx+math.sin(a)*ry,-math.sin(a)*rx+math.cos(a)*ry
            forward=(local_x-hx+sx)/fx;lifted=hy-sy+fy*forward-local_y
            candidates.append({'forward_px':forward,'lift_px':lifted,'angle_adjustment_deg':offset})
        requests.append({'clip':clip,'phase':at,'candidates':candidates})
    output.mkdir(parents=True,exist_ok=True);request=output/'guard_request.json';result=output/'guard_solution.json'
    write_json(request,{'poses':requests})
    subprocess.run([sys.executable,'tools/godot_task_runner.py','--task-id','rr-57','--stream','--','godot','--headless','--path','.',
                    '--script','tests/rr48/front_guard_solver.gd','--','--request',str(request),'--output',str(result)],cwd=ROOT,check=True)
    chosen=read_json(result)
    if chosen['errors']:raise ValueError('No legal sideward guard candidates: '+str(chosen['errors']))
    channels={clip:{name:[] for name in ('hand_far.forward_px','hand_far.lift_px')}}
    for row in chosen['poses']:
        for name,field in [('hand_far.forward_px','forward_px'),('hand_far.lift_px','lift_px')]:
            channels[clip][name].append([row['phase'],round(row['candidate'][field],9)])
    budget_path=CASE/'rr57/front_guard_budget.json'
    below=read_json(budget_path)['effective_hand_below_shoulder_px'] if budget_path.exists() else -12
    write_json(CASE/'rr57/front_guard_solution.json',{'channels':channels,'fall_hand_below_shoulder_px':below,'method':'Nearest sideward angle satisfying the existing authored/presented elbow and hand-boundary gates',
                'numerics':NUMERICS,'measurements':chosen['poses']})
    print('RR57 SIDEWARD GUARD SOLVE: PASS (%d constrained knots)'%len(chosen['poses']))


if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--solve',type=Path,required=True);args=parser.parse_args();solve(args.solve)
