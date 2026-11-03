"""Own-material coverage must remain non-outline after production density."""
import math
import numpy as np
from PIL import Image
from rr37_case import CASE
from rr37_coverage import donors
from cutout_pipeline.cases import write_json
from maquette_motion.bleed import edge_texels
from maquette_motion.features import source_pixels
from maquette_motion.material_palette import luma, OUTLINE_PERCENTILE
from pixel_density import metrics, strength, process
from humanoid_cutout.gait_continuations import nearest_donors

DENSITY_ROUNDING_GUARD = 1  # One encoded RGB unit bounds density rounding error.


def treat_coverage(layout, visible, hidden, paint, definition):
    view=layout['facing']
    grid=round(strength(metrics(Image.fromarray(paint))['orphan_share']),2)
    mode='regrid' if grid>=1.2 else 'clean'
    expected=Image.new('RGBA',(255,255))
    for part in sorted(layout['parts'],key=lambda p:p['z_index']):
        if part.get('hidden_material'): continue
        with Image.open(CASE/part['file']) as image:
            expected.alpha_composite(process(image,mode,grid),tuple(part['offset']))
    rgba=np.asarray(expected)
    cutoff=float(np.percentile(luma(rgba)[rgba[...,3]>0],OUTLINE_PERCENTILE))
    minimum=math.ceil(cutoff)+DENSITY_ROUNDING_GUARD
    # Carry source donor identity through density processing, whose colour
    # cleanup can change outline RGB without changing ownership or geometry.
    from rr37_surfaces import interior
    for part in layout['parts']:
        if part.get('hidden_material'):continue
        name=part['logical_part'];seed=interior(donors(visible[name],name),definition,visible[name])
        yy,xx=np.nonzero(seed[...,3])
        part['continuation_donor_uvs']=[[int(x-part['offset'][0]),int(y-part['offset'][1])] for y,x in zip(yy,xx)]
    for part in layout['parts']:
        part['continuation_min_luma']=minimum
        part['continuation_interior_margin_px']=2
        if not part.get('hidden_material'):continue
        name=part['logical_part'];seed=donors(visible[name],name)
        from rr37_surfaces import interior
        seed=interior(seed,definition,visible[name])
        seed[luma(seed)<minimum]=0
        target=source_pixels(CASE,part)[...,3]>0
        from rr41_underlay import surface
        authority, underlay = surface(view, name)
        target &= ~authority | (underlay[..., 3] > 0)
        procedural = target & ~authority
        if part['name'].startswith('covered_'):
            from rr37_surfaces import coherent_fill
            filled=coherent_fill(seed,procedural)
        else:filled=edge_texels(seed,procedural,definition)
        filled[target & authority] = underlay[target & authority]
        if part['name']=='hidden_'+name:hidden[name]=filled
        Image.fromarray(filled).crop(part['bbox']).save(CASE/part['file'])
    for table in [layout.get('gait_continuations',{})]+list(layout.get('clip_continuations',{}).values()):
        for name,recipe in list(table.items()):
            part=next(p for p in layout['parts'] if p['name']==name)
            targets={(x,y) for x,y,_,_ in recipe['texels']}
            if view=='rear' and part['logical_part'].startswith('cape_'):
                from rr37_surfaces import rear_cloak_outline
                outline=rear_cloak_outline(visible,paint)
                targets={(x,y) for x,y in targets if not 80<=y+part['offset'][1]<=180 or
                         outline[y+part['offset'][1],x+part['offset'][0]]}
            if view=='rear' and part['logical_part']=='spear':
                from rr37_surfaces import rear_shaft_core
                targets={(x,y) for x,y in targets if rear_shaft_core(x+part['offset'][0],y+part['offset'][1])}
            if view=='front' and part['logical_part']=='spear':
                targets={(x,y) for x,y in targets if y+part['offset'][1]<=224 and (y+part['offset'][1]<222 or x+part['offset'][0]<=76)}
            source=np.asarray(Image.open(CASE/part['file']).convert('RGBA'))
            h,w=source.shape[:2]
            targets={(x,y) for x,y in targets if 0<=x<w and 0<=y<h and source[y,x,3]==0}
            rebound=nearest_donors(CASE,layout,part,targets)
            if 'clips' in recipe:rebound['clips']=recipe['clips']
            table[name]=rebound
    return {'mode':mode,'grid':grid,'treated_outline_cutoff':cutoff,'continuation_min_luma':minimum,
            'derivation':'ceil(treated visible-rest outline percentile) + one encoded RGB rounding unit'}
