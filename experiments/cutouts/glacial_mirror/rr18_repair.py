"""Repair the accepted closure with tuck-depth padding for rigid UV coverage."""
import subprocess
import sys
import numpy as np
from PIL import Image
from rr18_case import PROJECT, CASE, ASSETS
from rr18_materials import continue_surfaces
from rr18_source_stage import raw_cut, clean_visible, raw_identity
from cutout_pipeline.cases import read_json, write_json, digest
from maquette_motion.features import source_pixels
from maquette_motion.material_palette import rules, outline_class
from maquette_motion.pixels import rest_identity
from humanoid_cutout.integration import record


def repair():
    anatomy=read_json(CASE/'anatomy.json');reports={};changed=[]
    for view in ('front','rear'):
        layout=read_json(CASE/f'layouts/{view}.json')
        shipped=read_json(ASSETS/'humanoid_v2'/(view+'.json'))
        visible={p['logical_part']:source_pixels(CASE,p) for p in layout['parts'] if not p.get('hidden_material')}
        hidden={p['logical_part']:source_pixels(CASE,p) for p in layout['parts'] if p.get('hidden_material')}
        depths={p['logical_part']:p['z_index'] for p in layout['parts'] if not p.get('hidden_material')}
        visible=raw_cut(visible,depths,view)
        visible,corrections=clean_visible(visible,anatomy['material_policy']['green_dominance_margin'])
        definition=rules(CASE,view)
        reports[view]=continue_surfaces(visible,hidden,anatomy,view,definition)
        recipes=read_json(CASE/'joint_continuations.json').get(view,{})
        for part in layout['parts']:
            name=part['logical_part']
            image=hidden[name] if part.get('hidden_material') else visible[name]
            original=part.get('continuation_source_bbox',part['bbox'])
            padding=anatomy['joint_continuations']['depth_px'] if name in recipes else 0
            left,top,right,bottom=[original[0]-padding,original[1]-padding,original[2]+padding,original[3]+padding]
            if padding:
                part['continuation_source_bbox']=original
                part['continuation_quad_padding_px']=padding
            part['bbox']=[left,top,right,bottom];part['offset']=[left,top]
            outside=image.copy();outside[top:bottom,left:right]=0
            if outside[...,3].any():raise ValueError('Continuation exceeds covered padded quad: '+part['name'])
            local=image[top:bottom,left:right]
            Image.fromarray(local).save(CASE/part['file'])
            check=layout['proof_layers'][part['name']]
            mask=np.zeros_like(local);occupied=local[...,3]>0
            mask[occupied]=[255,255 if part.get('hidden_material') else 0,0,255]
            mask[occupied & outline_class(local,definition),2]=255
            Image.fromarray(mask).save(CASE/check['mask'])
            check['mask_offset']=[left,top]
            check['source_sha256']=digest(CASE/part['file'])
            shipped_part=next(p for p in shipped['parts'] if p['name']==part['name'])
            target=ASSETS/'humanoid_v2'/shipped_part['file']
            shipped_part.update({k:v for k,v in part.items() if k!='file'})
            target.write_bytes((CASE/part['file']).read_bytes())
            changed.append(str(target.relative_to(PROJECT)))
        write_json(ASSETS/'humanoid_v2'/(view+'.json'),shipped)
        owning=read_json(ASSETS/(view+'.json'))
        for part in owning['parts']:
            source=next(p for p in shipped['parts'] if p['name']==part['name'])
            part.update({k:v for k,v in source.items() if k!='file'})
        write_json(ASSETS/(view+'.json'),owning)
        layout['rest_source']=f'source/{view}/continued.png'
        layout['raw_rest_source']=f'source/{view}/processed.png'
        expected=Image.new('RGBA',(255,255));rest=Image.new('RGBA',(255,255))
        for part in sorted(layout['parts'],key=lambda p:p['z_index']):
            image=hidden[part['logical_part']] if part.get('hidden_material') else visible[part['logical_part']]
            expected.alpha_composite(Image.fromarray(image))
            rest.alpha_composite(Image.fromarray(source_pixels(CASE,part)))
        if expected.tobytes()!=rest.tobytes():raise ValueError('Stored cut differs from prescribed material processing')
        expected.save(CASE/layout['rest_source'])
        raw=np.asarray(Image.open(CASE/f'source/{view}/processed.png').convert('RGBA'))
        delta=int(np.any(np.asarray(rest)!=raw,axis=-1).sum())
        reports[view]={'continuations':reports[view],'visible_green_corrections':corrections,'raw_identity':raw_identity(view),'presentation_delta_pixels':delta}
        write_json(CASE/f'layouts/{view}.json',layout)
    if not rest_identity(CASE)['ok']:raise ValueError('Presentation reference differs from the derived cut')
    if any(not reports[v]['raw_identity']['ok'] for v in reports):raise ValueError('Raw authoring identity changed')
    subprocess.run([sys.executable,'tools/process_board_density.py','--adopt',*changed,'--force-adopt'],cwd=PROJECT,check=True)
    subprocess.run([sys.executable,'tools/process_board_density.py','--only','glacial_mirror_cutout'],cwd=PROJECT,check=True)
    record(PROJECT,CASE,ASSETS)
    write_json(CASE/'proof/repair.json',{'scope':'nearest own-surface, non-green continuation repair; fixed accepted quads','views':reports})
    print('RR18 CONTINUATION REPAIR: PASS (tuck-depth padded quads; own surface; rounded covered extension; raw authoring 0 px; derived presentation rest 0 px)')


if __name__=='__main__':repair()
