"""Director feedback 2: extend the rear trouser seam from its own row texels.

The measured round-0 gap supplies the source band, not posed destination paint.
Rest and idle retain the approved silhouette. All action clips use the same
source continuation on the existing skin, with exact same-piece row donors.
"""
import numpy as np
from humanoid_cutout.gait_continuations import nearest_donors
from humanoid_cutout.covered_surfaces import row_outline
from maquette_motion.features import source_pixels
from cutout_pipeline.cases import read_json, write_json, digest
from rr38_case import CASE

CASE_CONFIG=CASE.parent/'rr38_feedback2_continuations.json'


def bounds_for(view,name,image,bounds=None):
    points=read_json(CASE_CONFIG)['targets'].get(view,{}).get(name,[])
    if not points:return bounds
    if bounds is None:
        y,x=np.nonzero(image[...,3]);bounds=[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)]
    x0,y0,x1,y1=bounds
    # Whole two-pixel mesh cells retain the original triangle lattice.
    grid_px=2
    for x,y in points:
        x0-=max(0,int(np.ceil((x0-x)/grid_px)))*grid_px
        y0-=max(0,int(np.ceil((y0-y)/grid_px)))*grid_px
        x1+=max(0,int(np.ceil((x+1-x1)/grid_px)))*grid_px
        y1+=max(0,int(np.ceil((y+1-y1)/grid_px)))*grid_px
    return [x0,y0,x1,y1]


def add(case, layout, clips):
    config=read_json(case.parent/'rr38_feedback2_continuations.json')
    if layout['facing'] != 'rear':
        add_measured(case,layout,clips,config)
        return
    evidence = read_json(case/'proof/feedback1_native_fixture.json')
    measured = evidence['seam']['sampled_source_background_xy']
    part = next(p for p in layout['parts'] if p['name'] == 'hidden_leg_near')
    trouser = next(p for p in layout['parts'] if p['name'] == 'leg_near')
    visible, hidden = [source_pixels(case, p) for p in (trouser, part)]
    outline = (visible[..., 3] > 0) | (hidden[..., 3] > 0)
    for x, y in measured:
        outline[y, x] = True
    required = row_outline(outline)
    first, last = min(y for _, y in measured), max(y for _, y in measured)
    required[:first] = False
    required[last+1:] = False
    required &= (visible[..., 3] == 0) & (hidden[..., 3] == 0)
    y, x = np.nonzero(required)
    targets = set(zip(x-part['offset'][0], y-part['offset'][1]))
    part['continuation_interior_margin_px'] = 2  # Binding brief §1/§2.
    part['continuation_donor_rule'] = 'same_row'
    recipe = nearest_donors(case, layout, part, targets)
    recipe['clips'] = [name for name in clips if name not in ('idle', 'rest')]
    layout.setdefault('gait_continuations', {})[part['name']] = recipe
    write_json(case/'proof/feedback2_seam.json', {
        'rule': 'director feedback 2; exact own-interior same-row trouser texels',
        'source_fixture': 'feedback1_native_fixture.json',
        'source_fixture_sha256': digest(case/'proof/feedback1_native_fixture.json'),
        'view': 'rear', 'piece': part['name'], 'donor': trouser['name'],
        'source_rows': [first, last], 'target_pixels': len(targets),
        'source_targets': [[int(a), int(b)] for a,b in zip(x,y)],
        'clips': recipe['clips'], 'rest_and_idle_unchanged': True})
    add_measured(case,layout,clips,config)


def add_measured(case,layout,clips,config):
    for name,points in config['targets'].get(layout['facing'],{}).items():
        part=next(p for p in layout['parts'] if p['name']==name)
        part['continuation_interior_margin_px']=2
        part['continuation_donor_rule']='same_row'
        targets={(x-part['offset'][0],y-part['offset'][1]) for x,y in points}
        recipe=nearest_donors(case,layout,part,targets)
        recipe['clips']=[name for name in clips if name not in ('idle','rest')]
        layout.setdefault('gait_continuations',{})[name]=recipe
