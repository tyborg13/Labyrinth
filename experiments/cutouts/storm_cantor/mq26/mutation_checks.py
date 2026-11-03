"""On-demand feedback-1 negative controls, outside the permanent test suite."""
import numpy as np
from PIL import Image
from build import CASE,STAGED,VIEWS,partition
from cutout_pipeline.cases import read_json,write_json
from humanoid_cutout.canvas import for_case
from humanoid_cutout.gates import bindings
from humanoid_cutout.source_space import DetachedSource
from maquette_motion.silhouette import components
from surface_policy import model
from cpu_sweep import pose_layers
from reach_acceptance import ACCEPTED,report as accepted_reach


def run():
    data=read_json(CASE/'compiled_motion.json');samples=read_json(CASE/'proof/raster_samples.json');checks=0
    assert samples['inputs']==bindings(CASE),'stale mutation poses'
    assert (CASE/'director_motion.json').read_bytes()==(STAGED/'motion_tracks.json').read_bytes();checks+=1
    assert not read_json(CASE/'inputs.json')['design_placeholders'];checks+=1
    for view in VIEWS:
        _,paint,images,_=partition(view)
        rebuilt=np.zeros_like(paint)
        for image in images.values():rebuilt[image[...,3]>0]=image[image[...,3]>0]
        assert np.array_equal(rebuilt,paint);checks+=1
        staff=np.asarray(Image.open(CASE/f'pieces/{view}/staff.png').convert('RGBA'))
        assert len(components(staff[...,3]>0,8)[1])==1;checks+=1
        layout=read_json(CASE/f'layouts/{view}.json')
        mask=np.zeros((255,255),bool)
        for part in layout['parts']:
            if part.get('hidden_material'):
                domain=part['underlay_domain'];mask|=np.asarray(Image.open(CASE/domain['file']).convert('L'))>0
        under=np.asarray(Image.open(STAGED/f'{view}_body_underlay.png').convert('RGBA'))
        assert np.array_equal(mask,under[...,3]>0);checks+=1
    # Removing approved material must fail even though source air can pass.
    with for_case(CASE):
        m=model(CASE,'front');row=next(r for r in samples['samples'] if r['view']=='front' and r['clip']=='idle' and r['frame']==0)
        layers,_=pose_layers(m,row,data);occupied=np.logical_or.reduce([image[...,3]>0 for _,image,_ in layers])
        from surface_policy import SourcePolicy
        target=next(image[...,3]>0 for part,image,_ in layers if part['name']=='hidden_torso')
        selected=None
        for y,x in zip(*np.nonzero(target)):
            if 0<y<638 and 0<x<638 and np.all(occupied[y-1:y+3,x-1:x+3]) and np.all(target[y:y+2,x:x+2]):selected=(x,y);break
        assert selected is not None
        x,y=selected;changed=occupied.copy();changed[y:y+2,x:x+2]=False
        findings=SourcePolicy(m).space(changed,row)['failures']
        assert any(r['bbox']==[x,y,x+2,y+2] and r['painted_or_tuck_pixels']==4 for r in findings),'missing material was waived';checks+=1
    # The allowlist is exact. Re-labelling the same short limb makes it fail.
    from unittest.mock import patch
    import reach_acceptance
    approved='/'.join(('rear','peal','hand_near'))+': minimum reach 1 px < 7 px'
    unlisted='rear/call_the_spark/hand_near: minimum reach 1 px < 7 px'
    nonfinite='rear/peal/hand_near: nonfinite reach'
    with patch.object(reach_acceptance,'reach',return_value={'errors':[approved,unlisted,nonfinite]}):
        r=accepted_reach({},{});assert r['errors']==[unlisted,nonfinite];checks+=1
    write_json(CASE/'proof/mutations.json',{'ok':True,'checks':checks,'native_pixels':False,
               'controls':['exact source rest','whole director alpha','one connected reconstructed staff','missing opaque material rejected','only five named finite reach exceptions']})
    print(f'RR56 FEEDBACK MUTATIONS: PASS ({checks} checks; missing material and unlisted reach rejected)')

if __name__=='__main__':run()
