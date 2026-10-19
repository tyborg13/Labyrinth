"""Both rigid legs: every authored swing, facing, and stationary floor supports."""
import math
import numpy as np
from rr18_case import PROJECT
import sys
sys.path.insert(0,str(PROJECT/'experiments/cutouts/arc_thrall'))
from rr11_knees import knee, swing_intervals, EPSILON, PRESENTED_TARGET_TOLERANCE_PX
from maquette_motion.compiler import evaluate


def knee_report(layout,data,samples):
    view = layout['facing']
    rows = [s for s in samples['samples'] if s['view']==view and s['clip']=='move' and s['kind']=='presented']
    errors,swings = [],[]
    frames = [{'frame':s['frame'],'phase':s['phase'], **{side:knee(s,side) for side in ('near','far')}} for s in rows]
    tracks = data['view_tracks'][view]['move']
    for side in ('near','far'):
        track = next(t for t in tracks if t['bone']=='foot_'+side and t['channel']=='lift_px')
        for row in frames:
            if row[side]['bend_deg'] > data['knee_policy']['near_straight_deg'] and not row[side]['facing_direction_ok']:
                errors.append(f'{view}/move/frame {row["frame"]}/{side}: knee bends against facing')
        for start,end in swing_intervals(track['keys']):
            candidates = [r for r in frames if start < r['phase'] < end and evaluate(track['keys'],r['phase'])>EPSILON]
            if not candidates:
                errors.append(f'{view}/{side}: missing swing frames'); continue
            peak = max(candidates,key=lambda r:r[side]['bend_deg'])
            apex = max(candidates,key=lambda r:evaluate(track['keys'],r['phase']))
            other = 'far' if side=='near' else 'near'
            record = {'side':side,'start':start,'end':end,'peak_frame':peak['frame'],'peak_bend_deg':peak[side]['bend_deg'],
                'apex_frame':apex['frame'],'apex_swing_bend_deg':apex[side]['bend_deg'],'apex_stance_bend_deg':apex[other]['bend_deg']}
            swings.append(record)
            if record['peak_bend_deg']+EPSILON < 15: errors.append(f'{view}/{side}: swing peak below 15 degrees')
            if record['apex_swing_bend_deg'] <= record['apex_stance_bend_deg']+EPSILON:
                errors.append(f'{view}/{side}: swing knee does not exceed stance knee at apex')
    if not rows: errors.append(view+': missing move evidence')
    return {'ok':not errors,'errors':errors,'swings':swings,'frames':frames}


def support_report(layout,data,samples):
    view = layout['facing']; errors,records = [],[]
    forward = np.asarray(data['projection'][view]['forward'])
    step = samples['step_distance_px']/samples['screen_pixel_scale']
    for clip in ('move','refraction','guard','hit'):
        tracks = data['view_tracks'][view][clip]
        for side in ('near','far'):
            foot = 'foot_'+side
            rest = np.asarray(layout['joints'][foot]['position'])
            lift = next((t for t in tracks if t['bone']==foot and t['channel']=='lift_px'),None)
            progress = next((t for t in tracks if t['bone']==foot and t['channel']=='forward_px'),None)
            previous = None
            for row in sorted([r for r in samples['samples'] if r['view']==view and r['clip']==clip and r['kind']=='presented'],key=lambda r:r['frame']):
                if lift and evaluate(lift['keys'],row['phase'])>EPSILON:
                    previous=None; continue
                target = rest + (forward*evaluate(progress['keys'],row['phase'])*step if progress and progress['forward_mode']=='world_step' else 0)
                actual = np.asarray(row['bones'][foot]['global'][4:])
                snapped = rest+np.rint(actual-rest)
                error = float(np.linalg.norm(snapped-target))
                change = float(np.linalg.norm(snapped-previous)) if previous is not None else 0.0
                records.append({'clip':clip,'side':side,'frame':row['frame'],'phase':row['phase'],'target_error_px':error,'frame_change_px':change})
                if error>PRESENTED_TARGET_TOLERANCE_PX: errors.append(f'{view}/{clip}/{side}/frame {row["frame"]}: support target error {error:.6f} px')
                if change!=0: errors.append(f'{view}/{clip}/{side}/frame {row["frame"]}: stance moved {change:.6f} px')
                previous=snapped
    if not records: errors.append(view+': missing support evidence')
    return {'ok':not errors,'errors':errors,'frames':records,'maximum_target_error_px':max((r['target_error_px'] for r in records),default=None),
            'maximum_frame_change_px':max((r['frame_change_px'] for r in records),default=None)}


def production_rest_report(layout, case, assets):
    """Compare the actual treated production assembly with its approved paint.

    Source identity cannot certify density-treated production paint. This is
    exact source-space compositing at rest, never native renderer evidence.
    """
    from PIL import Image
    from cutout_pipeline.cases import read_json
    view = layout['facing']
    shipped = read_json(assets/'humanoid_v2'/(view+'.json'))
    actual = Image.new('RGBA',tuple(shipped['canvas_size']))
    for part in sorted(shipped['parts'],key=lambda p:p['z_index']):
        actual.alpha_composite(Image.open(assets/'humanoid_v2'/part['file']).convert('RGBA'),tuple(part['offset']))
    expected = np.asarray(Image.open(case/layout['rest_source']).convert('RGBA'))
    mismatch = int(np.any(np.asarray(actual)!=expected,axis=-1).sum())
    errors = [f'{view}: treated production rest differs from approved painting by {mismatch} px; required 0'] if mismatch else []
    return {'ok':not errors,'errors':errors,'mismatch_pixels':mismatch,'scope':'exact source-space rest composition, not native pixels'}
