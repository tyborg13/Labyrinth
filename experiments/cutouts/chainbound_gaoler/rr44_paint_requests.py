"""Collect exact uncovered source coordinates and source/native-context crops.

No paint is invented and no finding is accepted. The director supplies paint or
an explicit clear decision for each remaining source-space review region.
"""
import argparse
from collections import defaultdict
from pathlib import Path
import numpy as np
from PIL import Image
from rr44_case import CASE,DEFAULTS
from cutout_pipeline.cases import read_json,write_json,digest
from maquette_motion.features import source_pixels


def collect(case):
    sweep=read_json(case/'proof/logs/rr44_sweep.json');groups=defaultdict(set);frames=defaultdict(list)
    for row in sweep['frames']:
        for record in row.get('uncertified_source_texels',[]):
            key=row['view'],record['part'];groups[key].add(tuple(record['uv']))
            if row.get('crop') not in frames[key]:frames[key].append(row.get('crop'))
    output=CASE/'proof/paint_requests';output.mkdir(parents=True,exist_ok=True);requests=[]
    for (view,name),texels in sorted(groups.items()):
        coordinates=np.array(sorted(texels));lo=coordinates.min(0);hi=coordinates.max(0)+1
        layout=read_json(case/f'layouts/{view}.json');part=next(p for p in layout['parts'] if p['name']==name)
        paint=source_pixels(case,part);box=(*np.maximum(0,lo-DEFAULTS['crop_context_px']),*np.minimum(255,hi+DEFAULTS['crop_context_px']))
        image=Image.fromarray(paint).crop(tuple(map(int,box)));zoom=DEFAULTS['crop_zoom'];path=output/f'{view}_{name}_source_4x.png'
        image.resize((image.width*zoom,image.height*zoom),Image.Resampling.NEAREST).save(path)
        requests.append(dict(field=f'TODO_DESIGN_painted_backing_{view}_{name}',value='Director paint or justified clear required',
            view=view,part=name,source_texels=coordinates.tolist(),source_crop=str(path.relative_to(CASE)),crop_sha256=digest(path),
            posed_crops=frames[view,name],status='flagged; not accepted or synthesized'))
    flats=[dict(view=r['view'],clip=r['clip'],frame=r['frame'],regions=r['flat_regions']) for r in sweep['frames'] if r.get('flat_regions')]
    result=dict(native_pixels=False,sweep_sha256=digest(case/'proof/logs/rr44_sweep.json'),requests=requests,flat_regions=flats,
        rear_striped_panel_frames=[dict(view=r['view'],clip=r['clip'],frame=r['frame'],texels=r['rear_striped_panel_texels']) for r in sweep['frames'] if r.get('rear_striped_panel_texels')])
    from rr44_joint_requests import collect as joints
    result['joint_requests']=joints(case,sweep)
    if result['rear_striped_panel_frames']:
        result['TODO_DESIGN_rear_underlay_strip']='Director judgment or replacement paint required; exposed strip remains flagged'
    write_json(output/'requests.json',result)
    print(f'RR44 DIRECTOR PAINT REVIEW: {len(requests)} source regions; {len(flats)} frames with flat regions; {len(result["rear_striped_panel_frames"])} rear-strip frames; all remain flagged')
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--case',type=Path,default=CASE/'proof/production_case');collect(p.parse_args().case)
