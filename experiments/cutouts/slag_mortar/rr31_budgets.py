"""Conservative, two-sided joint budgets measured on isolated rendered channels.

A budget is the contiguous passing prefix from zero, never a later passing
island. Resolution is 0.25 source pixels/degrees through 16, then explicit
coarse search samples. Censored limits are lower bounds, not inferred maxima.
The all-clip image gate separately checks combinations and gait operation.
"""
import argparse
from rr30_case import CASE, DIRECTOR
from rr31_images import OUTPUT, ImageGate, verification_bindings
from rr30_joint_gate import JointSurfaceGate
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.compiler import keys_for_view
from humanoid_cutout.gates import bindings
from humanoid_cutout.gait_continuations import active_recipe

GRID_STEP = .25  # Proof resolution in source px/degrees; no motion tuning.
FINE_EXTENT = 16.0
COARSE_EXTENTS = [24., 32., 48., 64., 90., 128.]


def requests():
    data = read_json(CASE/'compiled_motion.json')
    samples = read_json(CASE/'proof/logs/samples_full.json')
    step = samples['step_distance_px']/samples['screen_pixel_scale']
    rows = []
    for view, clips in data['view_tracks'].items():
        tracks = {t['source']:t for tracks in clips.values() for t in tracks}
        for source, track in sorted(tracks.items()):
            scale = step if track['channel']=='forward_px' and track['forward_mode'] in ('world_step','fraction_of_step') else 1.
            sign = data['projection'][view]['lean_sign'] if track['channel'] in ('lean_deg','angle_deg','swing_deg') else 1.
            amounts = [i*GRID_STEP for i in range(1,round(FINE_EXTENT/GRID_STEP)+1)] + COARSE_EXTENTS
            values = [0.] + [direction*value/scale*sign for direction in (1,-1) for value in amounts]
            rows.append(dict(view=view, track=track, values=values, source_sign=sign,
                             source_units_per_pixel=1./scale))
    result = dict(requests=rows, step_distance_px=samples['step_distance_px'],
                  screen_pixel_scale=samples['screen_pixel_scale'])
    write_json(OUTPUT/'proof/logs/joint_requests.json', result)
    print(f'RR31 JOINT REQUESTS: {len(rows)} channels/views; {sum(len(r["values"]) for r in rows)} poses')


def sweep():
    request_path = OUTPUT/'proof/logs/joint_requests.json'
    raw = read_json(OUTPUT/'proof/logs/joint_samples.json')
    request = read_json(request_path)
    if not raw['ok'] or raw['errors'] or raw['requests_sha256'] != digest(request_path) or raw['inputs'] != bindings(CASE):
        raise ValueError('Stale/incomplete isolated joint samples')
    poses = {(p['view'],p['channel'],round(p['value'],12)):p for p in raw['samples']}
    result, evidence = {}, []
    for view in ('front','rear'):
        layout = read_json(CASE/f'layouts/{view}.json')
        gate, surface = ImageGate(CASE,layout), JointSurfaceGate(CASE,layout)
        signatures, material_clips = set(), []
        for clip in ('joint_budget','lob','death','move'):
            signature = tuple(p['name'] for p in layout['parts'] if active_recipe(
                layout,p['name'],gait=clip=='move',clip=clip) is not None)
            if signature not in signatures:
                signatures.add(signature)
                material_clips.append(clip)
        result[view] = {}
        for row in request['requests']:
            if row['view'] != view: continue
            source, sign = row['track']['source'], row['source_sign']
            channel_poses = [p for p in raw['samples'] if p['view']==view and p['channel']==source]
            if len(channel_poses)!=len(row['values']): raise ValueError('Incomplete isolated channel: '+source)
            if all(p['parts']==channel_poses[0]['parts'] for p in channel_poses):
                raise ValueError('Isolated channel did not move any part: '+view+'/'+source)
            checked = {}
            def check(value):
                if value not in checked:
                    pose = poses[(view,source,round(value,12))]
                    # Every distinct production material state participates.
                    # Motion is isolated, but action-only covers are real art.
                    states = []
                    for clip in material_clips:
                        posed = dict(pose,clip=clip)
                        layers = gate.layers(posed)
                        report = gate.frame(posed,layers)
                        report['surfaces'] = surface.frame(posed,layers)
                        report['ok'] &= report['surfaces']['ok']
                        states.append(report)
                    checked[value] = dict(value=value/sign, ok=all(s['ok'] for s in states), states=states)
                    evidence.append(dict(view=view,channel=source,**checked[value]))
                return checked[value]
            baseline = check(0.)
            limits = {}
            for direction,name in ((1,'positive'),(-1,'negative')):
                passing, failing = 0., None
                for value in sorted((v for v in row['values'] if v/sign*direction>0), key=abs):
                    if not check(value)['ok']:
                        failing = abs(value/sign)
                        break
                    passing = abs(value/sign)
                limits[name] = dict(maximum_passing=passing if baseline['ok'] else None, first_failing=failing,
                    censored=failing is None, rest_passes=baseline['ok'])
            result[view][source] = limits
            print(f'RR31 BUDGET {view}/{source}: {limits}',flush=True)
    write_json(OUTPUT/'proof/logs/joint_sweep_full.json', dict(rows=evidence,inputs=raw['inputs']))
    report = dict(schema_version=1, policy='contiguous passing prefix from rest; signed director units',
        grid_step=GRID_STEP, fine_extent=FINE_EXTENT, coarse_extents=COARSE_EXTENTS,
        material_states=['all distinct production continuation states'], source_sha256=digest(DIRECTOR),
        verification_inputs=verification_bindings(),
        samples_sha256=digest(OUTPUT/'proof/logs/joint_samples.json'), inputs=raw['inputs'], views=result)
    write_json(OUTPUT/'joint_budgets.json',report)
    return report


def validate(budgets, director=None):
    director = read_json(DIRECTOR)['slag_mortar'] if director is None else director
    errors, keys = {}, 0
    for view, limits in budgets['views'].items():
        for clip,definition in director['clips'].items():
            for channel,rows in keys_for_view(definition,view,budgets['views']).items():
                if not isinstance(rows,list): continue
                for phase,value,*_ in rows:
                    keys += 1
                    limit = limits.get(channel,{}).get('positive' if value>=0 else 'negative')
                    if limit is None or not limit['rest_passes'] or abs(value)>limit['maximum_passing']:
                        name = 'TODO_DESIGN_budget_'+clip+'_'+channel.replace('.','_')
                        errors.setdefault(name,[]).append(dict(view=view,phase=phase,value=value,
                            measured_limit=None if limit is None else limit['maximum_passing'],
                            first_failing=None if limit is None else limit['first_failing'],
                            rest_passes=None if limit is None else limit['rest_passes']))
    return dict(ok=not errors,keys_checked=keys,TODO_DESIGN=errors)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode',choices=['requests','sweep','validate'])
    args = parser.parse_args()
    if args.mode=='requests': requests()
    else:
        budgets = sweep() if args.mode=='sweep' else read_json(OUTPUT/'joint_budgets.json')
        if (budgets['inputs'] != bindings(CASE) or budgets['source_sha256']!=digest(DIRECTOR)
                or budgets['verification_inputs']!=verification_bindings()):
            raise ValueError('Stale joint budgets')
        result = validate(budgets)
        write_json(OUTPUT/'proof/budget_validation.json',result)
        print(f'RR31 DIRECTOR BUDGETS: {"PASS" if result["ok"] else "FAIL"} ({result["keys_checked"]} keys; {len(result["TODO_DESIGN"])} TODO_DESIGN)')
        raise SystemExit(not result['ok'])
