"""Twelve native board-scale move frames per view, enlarged 3x nearest."""
import argparse
from pathlib import Path

from PIL import Image, ImageDraw
import numpy as np

from cutout_pipeline.cases import read_json, write_json, digest
from .gates import bindings
from .action_direction import pose_values
from .bone_contracts import fk_world
from .gait import schedule
from humanoid_cutout.native_frames import load_frame, frame_digest

FRAME_COUNT = 12
ZOOM = 3
PROOF_MARGIN_PX = 5
PROOF_LABEL_HEIGHT_PX = 44
PROOF_MARKER_RADIUS_PX = 2
PROOF_PLANTED_COLOUR = '#00ff00'
PROOF_SWING_COLOUR = '#ffa500'
PROOF_BACKGROUND = '#1e1e24'


def compose(case, capture, output):
    manifest = read_json(capture/'frames.json')
    if not manifest.get('ok') or not manifest.get('native_pixels') or manifest['inputs'] != bindings(case):
        raise ValueError('Fresh native move capture required')
    if manifest['size'] != [1920,1080] or manifest['ui_scale'] != 1.: raise ValueError('1920x1080 / 100% required')
    data = read_json(case/'compiled_motion.json')
    views = list(data['view_tracks'])
    cells, details, boxes = {}, [], []
    for view in views:
        rows = sorted([r for r in manifest['frames'] if r['view']==view],key=lambda r:r['frame'])
        if len(rows)!=FRAME_COUNT or {r['frame'] for r in rows}!=set(range(FRAME_COUNT)): raise ValueError('Incomplete move sheet')
        layout = read_json(case/f'layouts/{view}.json')
        forward = np.asarray(data['projection'][view]['forward'])
        for row in rows:
            if abs(row['phase']-row['frame']/(FRAME_COUNT-1)) > 1e-6: raise ValueError('Uneven move phases')
            path = capture/row['file']
            if frame_digest(path)!=row['sha256']: raise ValueError('Changed native frame')
            image = load_frame(path).convert('RGBA')
            if image.size!=(1920,1080): raise ValueError('Wrong native dimensions')
            values,modes = pose_values(data,view,'move',row['phase'])
            fk = fk_world(layout,values,modes,forward,manifest['step_distance_px']/row['scale'])
            # Camera follows the root; use the captured transform for markers.
            origin = np.asarray(row['origin'])
            draw = ImageDraw.Draw(image)
            scales = {}
            for side in ('near','far'):
                foot = 'foot_'+side
                a,b,c = [np.asarray(layout['joints'][n+'_'+side]['position']) for n in ('thigh','shin','foot')]
                v=values[foot]
                ground=c+[v['lane_px'],0.]+forward*v['forward_px']*manifest['step_distance_px']/row['scale']
                target=ground-[0.,v['lift_px']]
                x,y=origin+target*row['scale']
                planted=not any(s['side']==side and s['start']<row['phase']<s['end'] for s in schedule(data['clips']['move']['gait']))
                radius=PROOF_MARKER_RADIUS_PX
                draw.ellipse((x-radius,y-radius,x+radius,y+radius),fill=PROOF_PLANTED_COLOUR if planted else PROOF_SWING_COLOUR)
                scales[side]=float(np.clip(1+(ground[1]-c[1])/(np.linalg.norm(b-a)+np.linalg.norm(c-b))-forward[1]*row['phase']*manifest['step_distance_px']/row['scale']/(np.linalg.norm(b-a)+np.linalg.norm(c-b)),.78,data['clips']['move']['gait'].get('leg_scale_max',1.22)))
            drop=float(fk['pelvis'][1,2]-layout['joints']['pelvis']['position'][1]-forward[1]*row['phase']*manifest['step_distance_px']/row['scale'])
            details.append({'view':view,'frame':row['frame'],'phase':row['phase'],'pelvis_drop_px':drop,'leg_scales':scales})
            box=image.getchannel("A").getbbox()
            boxes.append(box)
            cells[view,row['frame']]=image
    bounds=(min(b[0] for b in boxes)-PROOF_MARGIN_PX,min(b[1] for b in boxes)-PROOF_MARGIN_PX,
            max(b[2] for b in boxes)+PROOF_MARGIN_PX,max(b[3] for b in boxes)+PROOF_MARGIN_PX)
    width,height=(bounds[2]-bounds[0])*ZOOM,(bounds[3]-bounds[1])*ZOOM
    sheet=Image.new('RGB',(width*FRAME_COUNT,(height+PROOF_LABEL_HEIGHT_PX)*len(views)),PROOF_BACKGROUND)
    draw=ImageDraw.Draw(sheet)
    for detail in details:
        x=detail['frame']*width;y=views.index(detail['view'])*(height+PROOF_LABEL_HEIGHT_PX)
        cell=cells[detail['view'],detail['frame']].crop(bounds).resize((width,height),Image.Resampling.NEAREST)
        sheet.paste(cell,(x,y),cell)
        draw.text((x,y+height),f'{detail["view"]} {detail["phase"]:.4f}\ndrop {detail["pelvis_drop_px"]:.3f} px\nlegs N {detail["leg_scales"]["near"]:.4f} F {detail["leg_scales"]["far"]:.4f}',fill='white')
    output.parent.mkdir(parents=True,exist_ok=True)
    sheet.save(output)
    write_json(output.with_suffix('.json'),{'ok':True,'native_manifest_sha256':digest(capture/'frames.json'),'inputs':manifest['inputs'],'frames':details,'zoom':ZOOM,'board_scale':manifest['board_scale']})
    print(f'GAIT MOVE SHEET: PASS (24 frames; {output})')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ('case','capture','output'): parser.add_argument('--'+name,type=Path,required=True)
    compose(**vars(parser.parse_args()))
