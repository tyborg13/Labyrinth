#!/usr/bin/env python3
"""Headless source-texel diagnostic. Native isolated groups remain mandatory."""
import sys,json,colorsys
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
from humanoid_cutout.gates import idle_pixel_errors,idle_group_offset
from maquette_motion.gates import unpack
from cutout_pipeline.cases import read_json
from round1_checks import green_count
CASE=ROOT/'experiments/cutouts/emaciated_man/emac02'

def main():
    config=read_json(CASE/'cutout.json');layout=read_json(CASE/config['layouts']['front']);anatomy={'idle_groups':layout['idle_groups']}
    rows=read_json(CASE/'proof/motion_samples.json')['samples'];parts=sorted(layout['parts'],key=lambda p:p['z_index'])
    counts={'upper':0,'lower':0};base={};offsets=set()
    for row in rows:
        for group in counts:
            canvas=Image.new('RGBA',(512,512))
            for p in parts:
                if (p['bone'] in layout['idle_groups'][group]['bones']) is False:continue
                t=unpack(row['bones'][p['bone']]['global']);basis=t[:2,:2];pivot=np.array(layout['joints'][p['bone']]['position'])
                origin=t[:2,2]+basis@(np.array(p['offset'])-pivot)+128
                inv=np.linalg.inv(basis);offset=-inv@origin
                im=Image.open(CASE/p['file']).convert('RGBA').transform((512,512),Image.Transform.AFFINE,(*inv[0],offset[0],*inv[1],offset[1]),Image.Resampling.NEAREST)
                canvas.alpha_composite(im)
            frame=np.array(canvas)
            assert green_count(canvas)==0
            if group not in base:base[group]=frame.copy()
            offset=idle_group_offset(layout,row['bones'],group,anatomy)
            assert np.allclose(offset,np.rint(offset),atol=.0001)
            for bone in layout['idle_groups'][group]['bones']:
                m=row['bones'][bone]['global']
                assert np.allclose(m[:4],[1,0,0,1],atol=.0001)
                assert np.allclose(np.array(m[4:])-layout['joints'][bone]['position'],offset,atol=.0001)
            counts[group]+=idle_pixel_errors(base[group],frame,offset)
            if group=='upper':offsets.add(int(round(offset[1])))
    assert counts=={'upper':0,'lower':0},counts
    assert offsets=={0,1,2},offsets
    for mesh in layout.get('joint_meshes',[]):
        groups={g for g,definition in layout['idle_groups'].items() for bone,weights in mesh['weights'].items() if max(weights)>0 and bone in definition['bones']}
        assert len(groups)==1,'Mesh crosses rigid groups'
    rest=Image.open(ROOT/'assets/units/emaciated_man_cutout/front/rest.png').convert('RGBA')
    assert rest.getbbox()==(42,60,244,254),rest.getbbox()
    assert all(green_count(Image.open(p))==0 for p in (ROOT/'assets/units/emaciated_man_cutout/front').glob('*.png'))
    assert layout['glow_min_saturation']==.75
    result={'ok':True,'basis':'CPU source texels and actual Godot bones; native mesh raster proof pending','samples':len(rows),'group_pixel_mismatches':counts,'upper_y_offsets':sorted(offsets),'green_pixels':0,'rest_bbox':list(rest.getbbox()),'height':194,'art_scale':1.0}
    (CASE/'proof/rigid_cpu.json').write_text(json.dumps(result,indent=2)+'\n')
    print('EMAC RIGID CPU: PASS; samples=%d; upper_mismatches=0; lower_mismatches=0; offsets=0,1,2; green_pixels=0'%len(rows))
if __name__=='__main__':main()
