"""Report observed clean heights and source-registered hidden-fill requests.

Every height clamp is reported; no paint is manufactured. Native-clean budgets remain pending
until the director supplies the fresh native capture and superset audit.
"""
import argparse
from collections import defaultdict
from pathlib import Path
import numpy as np
from PIL import Image
from rr48_build import CASE, VIEWS
from rr48_joint_budget import nearest_joint
from rr48_raised_motion import TARGETS
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.gates import matrix, bindings
from humanoid_cutout.canvas import for_case


def export_requests(samples, sweep, output):
    """Export measured findings; the caller validates the retained pose inputs."""
    rows = {(r['view'],r['clip'],r['frame']):r for r in samples['samples']}
    findings = defaultdict(list)
    for record in sweep['remaining_tears']+sweep['accepted_short_tears']:
        findings[record['view'],record['clip'],record['frame']].append(record)
    for record in sweep['errors']:
        key = record['view'],record['clip'],record['frame']
        for component in record['unmatched_components']:
            with for_case(CASE):joint=nearest_joint(rows[key],component['bbox'])
            findings[key].append({'joint':joint, 'bbox':component['bbox'],
                                  'request_padding_px':read_json(CASE/'anatomy.json')['joint_continuations']['depth_px'],
                                  'kind':'unmatched_detached_paint','pixel_count':component['pixel_count']})
    masks = defaultdict(lambda:np.zeros((255,255),bool)); witnesses = defaultdict(list)
    for key, records in findings.items():
        row = rows[key]; view, clip, frame = key
        # Same source-space recipient/reference as rr48_gates.footprint_requests.
        # A request is a conservative region, never permission to fill authored air.
        bind = np.asarray(read_json(CASE/f'layouts/{view}.json')['joints']['torso']['position'])
        reference = matrix(row['bones']['torso']['global']); reference[:2,2] -= reference[:2,:2]@bind
        inverse = np.linalg.inv(reference)
        for record in records:
            x,y,r,b = record['bbox'];padding=record.get('request_padding_px',0)
            yy,xx = np.mgrid[y-padding:b+padding,x-padding:r+padding]
            points = np.column_stack((xx.ravel()+.5-192,yy.ravel()+.5-192,np.ones(xx.size)))
            uv = np.floor(points@inverse.T).astype(int)[:,:2]
            uv = uv[(uv[:,0]>=0)&(uv[:,0]<255)&(uv[:,1]>=0)&(uv[:,1]<255)]
            name = view,clip,record['joint']; masks[name][uv[:,1],uv[:,0]] = True
            witnesses[name].append({'frame':frame,'phase':row['phase'],'posed_bbox':record['bbox'],
                                    'kind':record.get('kind','paint_mapped_hole'),'pixel_count':record['pixel_count'],
                                    'request_padding_px':padding})
    target = output/'underlay_requests'; target.mkdir(parents=True,exist_ok=True); requests = []
    for (view,clip,joint),mask in sorted(masks.items()):
        name = f'{view}_{clip}_{joint}.png'; Image.fromarray(mask.astype('uint8')*255).save(target/name)
        requests.append({'view':view,'region':clip+'_'+joint,'mask':name,'source_size':[255,255],
                         'source_frame':'torso recipient, same registration as rr48 vacated-footprint requests',
                         'uncovered_pixels':int(mask.sum()),'sampled_frames':len(witnesses[view,clip,joint]),
                         'painting_must_continue':'Director to identify the covered surface/air; diagnostic bounds include adjacent paint. Do not fill authored negative space.',
                         'status':f'TODO_DESIGN_hidden_fill_{view}_{clip}_{joint}', 'witnesses':witnesses[view,clip,joint]})
    write_json(target/'index.json',{'native_pixels':False,'scope':'New attack excursions; conservative source-registered finding bounds; no synthesized paint',
                                  'compiled_sha256':sweep['compiled_sha256'],'regions':requests})
    return requests


def report(samples, sweep, output):
    if samples['compiled_sha256'] != digest(CASE/'compiled_motion.json') or sweep['inputs'] != bindings(CASE):
        raise ValueError('Stale attack budget inputs')
    budget_path=CASE/'rr57/front_guard_budget.json'
    clamps=[read_json(budget_path)] if budget_path.exists() else []
    rows = {(r['view'],r['clip'],r['frame']):r for r in samples['samples']}
    requests=export_requests(samples,sweep,output)
    heights = []
    for view in VIEWS:
        for clip in TARGETS:
            checked = [r for r in sweep['frames'] if r['view']==view and r['clip']==clip]
            # Strict clean observations exclude even temporally accepted holes.
            clean = [r for r in checked if not r['kinds'] and not r['holes']]
            measured = []
            for result in clean:
                row = rows[view,clip,result['frame']]; bones = row['bones']
                measured.append({'frame':result['frame'],'phase':row['phase'],
                                 'hand_below_shoulder_px':bones['hand_far']['global'][5]-bones['upper_far']['global'][5]})
            highest = min(measured,key=lambda r:r['hand_below_shoulder_px']) if measured else None
            heights.append({'view':view,'clip':clip,'frames':len(checked),'strict_clean_frames':len(clean),
                            'highest_observed_cpu_clean_pose':highest,
                            'native_clean_height':None,'native_status':'pending director native capture and superset audit',
                            'full_target_kept':not any(r['view']==view and r['clip']==clip for r in clamps)})
    result = {'native_pixels':False,'cpu_ok':sweep['ok'],'height_observations':heights,'requests':requests,
              'clamps':clamps,'compiled_sha256':digest(CASE/'compiled_motion.json'),
              'budget_status':'CPU observations only; no native-clean budget certified'}
    write_json(output/'joint_budgets.json',result)
    print('RR57 BUDGET/REQUESTS:',len(sweep['frames']),'frames;',len(requests),'hidden-fill masks;',len(clamps),'reported height clamps; native-clean heights PENDING')
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--samples',type=Path,required=True); parser.add_argument('--sweep',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True); args = parser.parse_args()
    report(read_json(args.samples),read_json(args.sweep),args.output)
