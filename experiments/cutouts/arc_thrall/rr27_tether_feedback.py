"""Director feedback-1 candidate compilation, 60fps gates and 3x strips.

Candidate author/compiled files are render-only evidence. A pair is eligible
only when both specified intervals pass; no authoring file is edited here.
"""
import argparse
from copy import deepcopy
import math

import numpy as np
from PIL import Image, ImageDraw

from rr27_build import CASE, PROJECT, RECIPE
from rr27_tether_sheets import (axis_crosses, transformed_point, SOURCE_ORIGIN,
    CELL_SIZE, LABEL_HEIGHT_PX, LABEL_FONT_SIZE_PX, CROP_MARGIN_PX, BACKGROUND, ZOOM)
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.compiler import compile_motion
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.gates import bindings

DIRECTOR = PROJECT / 'spec/peer_benchmark/staged/rr-11/motion_tracks.json'
STUDY = RECIPE / 'tether_study/feedback1'
CANDIDATES = {'F10_L110': [10,110], 'F0_L90': [0,90], 'F20_L130': [20,130]}
RAISE_PHASES = [0., .05, .1, .15, .2, .25, .3, .35]
LOWER_PHASES = [.8, .85, .9, .95, 1.]
FPS = 60
SAMPLE_EPSILON = 1e-9  # JSON phase roundoff only, not a motion tolerance.
BEND_EPSILON = 1e-6  # Existing normalized bone-contract collinearity tolerance.


def channels(pair):
    forward, lift = pair
    return {'tube_tip.forward_px': [[0,0],[.2,forward],[.35,65],[.8,65],[.9,forward],[1,0]],
            'tube_tip.lift_px': [[0,0],[.2,lift],[.35,153],[.8,153],[.9,lift],[1,0]]}


def prepare():
    source = read_json(DIRECTOR)
    previous = read_json(CASE / 'compiled_motion.json')
    layouts = {view: read_json(CASE / f'layouts/{view}.json') for view in previous['view_tracks']}
    count = math.floor(previous['clips']['tether']['seconds'] * FPS + .5)
    presented = [frame / (count-1) for frame in range(count)]
    phases = sorted(set(presented + RAISE_PHASES + LOWER_PHASES + [.5]))
    for name, pair in CANDIDATES.items():
        candidate = deepcopy(source)
        candidate['arc_thrall']['clips']['tether']['view_keys']['rear'] = channels(pair)
        path = STUDY / (name + '_author.json')
        write_json(path, candidate)
        compiled = compile_motion(path, 'arc_thrall', layouts, previous['projection'])
        # Prove only the two permitted rear channels differ, before sampling.
        if compiled['view_tracks']['front'] != previous['view_tracks']['front']:
            raise ValueError('Candidate changed front channels')
        for clip, tracks in previous['view_tracks']['rear'].items():
            if clip != 'tether' and compiled['view_tracks']['rear'][clip] != tracks:
                raise ValueError('Candidate changed another clip: ' + clip)
        write_json(STUDY / (name + '_compiled.json'), compiled)
    write_json(STUDY / 'request.json', {'candidates': CANDIDATES, 'phases': phases,
        'presented_phases': presented, 'raise_phases': RAISE_PHASES, 'lower_phases': LOWER_PHASES,
        'director_sha256': digest(DIRECTOR), 'inputs': bindings(CASE), 'fps': FPS,
        'compiled_sha256':{name:digest(STUDY/(name+'_compiled.json')) for name in CANDIDATES},
        'author_sha256':{name:digest(STUDY/(name+'_author.json')) for name in CANDIDATES}})
    print(f'RR27 TETHER FEEDBACK CANDIDATES: PASS (3 prescribed pairs; {count} 60fps frames plus exact strip phases)')


def cross(a, b):
    return float(a[0]*b[1]-a[1]*b[0])


def bend_side(pose, field):
    shoulder, elbow, tip = [np.asarray(pose[field][name]['global'][4:])
                            for name in ('upper_near','fore_near','tube_tip')]
    upper, target = elbow-shoulder, tip-shoulder
    normalized = cross(target,upper) / max(np.linalg.norm(target)*np.linalg.norm(upper), BEND_EPSILON)
    return 0 if abs(normalized) <= BEND_EPSILON else int(np.sign(normalized))


def evaluate(*, native=False):
    request = read_json(STUDY / 'request.json')
    capture = STUDY / ('native' if native else 'cpu')
    report = read_json(capture / 'samples.json')
    current = bindings(CASE)
    if (not report['ok'] or report['native_pixels'] != native or report['inputs'] != current
            or request['inputs'] != current or digest(DIRECTOR) != request['director_sha256']
            or report['candidates'] != CANDIDATES or len(report['phases']) != len(request['phases'])
            or any(abs(a-b)>SAMPLE_EPSILON for a,b in zip(report['phases'],request['phases']))):
        raise ValueError('Fresh feedback-1 samples and candidate inputs required')
    if (report.get('candidate_compiled_sha256') != request['compiled_sha256'] or
            any(digest(STUDY/(name+'_compiled.json')) != request['compiled_sha256'][name] or
                digest(STUDY/(name+'_author.json')) != request['author_sha256'][name] for name in CANDIDATES)):
        raise ValueError('Feedback-1 candidate motion changed after compilation/sampling')
    layout = read_json(CASE / 'layouts/rear.json')
    parts = {part['name']: part for part in layout['parts']}
    model = CpuPose(CASE, layout)
    records, frames = [], {}
    for pose in report['samples']:
        name, phase = pose['candidate'], pose['phase']
        if native:
            for field in ('file','torso_file','upper_near_file','tube_file'):
                path = (capture / pose[field]).resolve()
                sha = 'sha256' if field == 'file' else field.replace('_file','_sha256')
                if not path.is_relative_to(capture.resolve()) or not path.is_file() or digest(path) != pose[sha]:
                    raise ValueError('Changed native study image: ' + str(path))
            image = Image.open(capture / pose['file']).convert('RGBA')
            masks = {n:np.asarray(Image.open(capture / pose[n+'_file']).convert('RGBA'))[...,3]>0
                     for n in ('torso','upper_near','tube')}
        else:
            layers, _ = model.layers(pose)
            image = Image.new('RGBA',(512,512))
            for _, pixels, _ in sorted(layers,key=lambda r:r[0]['z_index']):
                image.alpha_composite(Image.fromarray(pixels))
            masks = {part['name']:pixels[...,3]>0 for part,pixels,_ in layers}
        cap = transformed_point(layout,pose,parts['tube'],layout['joints']['tube_tip']['position'])
        shoulder = np.asarray(pose['bones']['upper_near']['global'][4:])+SOURCE_ORIGIN
        elbow = np.asarray(pose['bones']['fore_near']['global'][4:])+SOURCE_ORIGIN
        frame = next((i for i,p in enumerate(request['presented_phases']) if abs(p-phase)<=SAMPLE_EPSILON),None)
        records.append({'candidate':name,'phase':phase,'presented_frame':frame,
            'cap_presented_pixel':np.floor(cap).astype(int).tolist(),'elbow_position':elbow.tolist(),
            'shoulder_position':shoulder.tolist(),'authored_bend_side':bend_side(pose,'direction_bones'),
            'presented_bend_side':bend_side(pose,'bones'),
            'upper_arm_crosses_torso':axis_crosses(masks['torso'],shoulder,elbow),
            'tube_crosses_torso':axis_crosses(masks['torso'],elbow,cap),
            'upper_arm_torso_overlap_px':int((masks['upper_near'] & masks['torso']).sum()),
            'tube_torso_overlap_px':int((masks['tube'] & masks['torso']).sum())})
        if phase in RAISE_PHASES + LOWER_PHASES:
            frames[name,phase] = image
    expected = [(name,p) for name in CANDIDATES for p in request['phases']]
    if len(records)!=len(expected) or any(r['candidate']!=name or abs(r['phase']-phase)>SAMPLE_EPSILON
                                        for r,(name,phase) in zip(records,expected)):
        raise ValueError('Incomplete candidate/phase inventory')
    results = {}
    for name,pair in CANDIDATES.items():
        intervals = {}
        for label,start,end in [('raise',0.,.35),('lower',.8,1.)]:
            selected = [r for r in records if r['candidate']==name and start<=r['phase']<=end]
            consecutive = [r for r in selected if r['presented_frame'] is not None]
            flips = []
            for previous,row in zip(consecutive,consecutive[1:]):
                if any(previous[k]*row[k]<0 for k in ('authored_bend_side','presented_bend_side')):
                    flips.append([previous['presented_frame'],row['presented_frame']])
            crossings = [r for r in selected if r['upper_arm_crosses_torso'] or r['tube_crosses_torso']]
            steps = [float(np.linalg.norm(np.asarray(b['elbow_position'])-a['elbow_position']))
                     for a,b in zip(consecutive,consecutive[1:])]
            intervals[label] = {'bend_direction_flips':flips,'crossing_samples':crossings,
                'maximum_consecutive_elbow_step_px':max(steps,default=0.),
                'presented_frames':len(consecutive),'samples':len(selected),
                'continuous_bend_side':not flips,'no_torso_crossing':not crossings}
        ok = all(r['continuous_bend_side'] and r['no_torso_crossing'] for r in intervals.values())
        results[name] = {'pair':pair,'qualifies':ok,'intervals':intervals}
        print(f'RR27 TETHER PAIR {pair}: {"PASS" if ok else "FAIL"} '
              f'(raise/lower crossing samples {len(intervals["raise"]["crossing_samples"])}/{len(intervals["lower"]["crossing_samples"])}; '
              f'bend flips {len(intervals["raise"]["bend_direction_flips"])}/{len(intervals["lower"]["bend_direction_flips"])})',flush=True)
    chosen = next((name for name,row in results.items() if row['qualifies']),None)
    output = STUDY / ('native_sheets' if native else 'cpu_sheets')
    sheets(frames,records,output,native=native)
    result = {'ok':chosen is not None,'chosen':chosen,'chosen_pair':CANDIDATES.get(chosen),
        'native_pixels':native,'inputs':current,'candidates':results,'rows':records,
        'crossing_measurement':'Same as initial study: interior 10-90% centreline against isolated torso alpha; separate full alpha overlap counts',
        'continuity_measurement':'Consecutive actual 60fps frames: authored and presented normalized signed IK bend side; maximum elbow step reported without an invented acceptance threshold',
        'director_file_edited':False,'scope':'CPU estimates; native validation pending' if not native else 'native isolated silhouettes'}
    result['design_placeholders'] = ({} if chosen is not None else {
        'TODO_DESIGN_REAR_TETHER_PATH':'All three prescribed intermediate pairs fail the supplied conditions. No other value was selected and the director motion file is unchanged.'})
    if bindings(CASE) != current:
        raise ValueError('Inputs changed during candidate evaluation')
    write_json(output / 'result.json',result)
    print('RR27 TETHER FEEDBACK SELECTION: ' + ('NONE (all prescribed pairs fail; director data retained)' if chosen is None else chosen))
    return result


def sheets(frames,records,output,*,native):
    output.mkdir(parents=True,exist_ok=True)
    boxes = [image.getbbox() for image in frames.values()]
    crop = [min(b[0] for b in boxes)-CROP_MARGIN_PX,min(b[1] for b in boxes)-CROP_MARGIN_PX,
            max(b[2] for b in boxes)+CROP_MARGIN_PX,max(b[3] for b in boxes)+CROP_MARGIN_PX]
    size = ((crop[2]-crop[0])*ZOOM,(crop[3]-crop[1])*ZOOM)
    if size[0]>CELL_SIZE[0] or size[1]>CELL_SIZE[1]-LABEL_HEIGHT_PX:
        raise ValueError('Feedback strip exceeds the fixed proof cell')
    for name,pair in CANDIDATES.items():
        for label,phases in [('raise',RAISE_PHASES),('lower',LOWER_PHASES)]:
            strip = Image.new('RGB',(CELL_SIZE[0]*len(phases),CELL_SIZE[1]),BACKGROUND)
            draw = ImageDraw.Draw(strip)
            for index,phase in enumerate(phases):
                x = index*CELL_SIZE[0]
                image = frames[name,phase].crop(crop).resize(size,Image.Resampling.NEAREST)
                strip.paste(image,(x+(CELL_SIZE[0]-size[0])//2,0),image)
                row = next(r for r in records if r['candidate']==name and r['phase']==phase)
                cap,elbow = row['cap_presented_pixel'],row['elbow_position']
                lines = [f'{pair} phase {phase:g} | {"NATIVE" if native else "CPU ESTIMATE"} 3x',
                    f'cap ({cap[0]},{cap[1]}); elbow ({elbow[0]:.2f},{elbow[1]:.2f})',
                    f'torso axis crossing: arm {row["upper_arm_crosses_torso"]}; tube {row["tube_crosses_torso"]}',
                    f'alpha overlap: arm {row["upper_arm_torso_overlap_px"]}px; tube {row["tube_torso_overlap_px"]}px']
                for line,text in enumerate(lines):
                    draw.text((x+8,CELL_SIZE[1]-LABEL_HEIGHT_PX+24*line),text,fill='white',font_size=LABEL_FONT_SIZE_PX)
            strip.save(output / f'{name}_{label}_3x.png')
    write_json(output / 'sheets.json',{'zoom':ZOOM,'crop_bounds':crop,
        'native_pixels':native,'files':{p.name:digest(p) for p in sorted(output.glob('*.png'))}})


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage',choices=('prepare','evaluate'))
    parser.add_argument('--native',action='store_true')
    args = parser.parse_args()
    if args.stage == 'prepare':prepare()
    else:raise SystemExit(int(not evaluate(native=args.native)['ok']))
