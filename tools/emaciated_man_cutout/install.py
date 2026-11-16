#!/usr/bin/env python3
"""Install emac-02's filled case and record its exact art/density provenance.

Does not certify native rests, run a windowed renderer, approve or publish art.
Use --refresh-identity after the director's native density rest rebake.
"""
from pathlib import Path
import sys
import shutil
import argparse
import hashlib
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from cutout_pipeline.cases import read_json,write_json
from art_identity_gate import pixel_digest,measure,recorded_ref_digests
from pixel_density import metrics,strength
CASE=ROOT/'experiments/cutouts/emaciated_man/emac02'
BASE=ROOT/'assets/units/emaciated_man_cutout'
JOB=ROOT/'spec/art_identity/jobs/emaciated_man/mq_front'

def identity():
    path=BASE/'front/rest.png'
    bounds=Image.open(path).getbbox()
    if bounds is None or bounds[3]-bounds[1]!=194 or bounds[3]!=254:
        raise ValueError('Director round 3 requires native rest height 194 and ground 254: '+str(bounds))
    kit=read_json(JOB/'kit.json');processed=read_json(JOB/'processed.json')
    registration=read_json(JOB/'registration.json')
    transform=lambda p:(np.array(p)*np.array(registration['maquette_scale'])+np.array(registration['maquette_offset'])).tolist()
    landmarks={'far':transform(read_json(JOB/'joints_px.json')['front']['shoulder_far']),
               'near':transform(read_json(JOB/'joints_px.json')['front']['shoulder_near'])}
    entry=dict(id='emaciated_man',path=str(path.relative_to(ROOT)),entry_kind='kit',kind='creature',anatomy='biped',facing='front',art_scale=1.0,boss=False,size_class='medium',
        job_id=kit['job_id'],kit_path=str((JOB/'kit.json').relative_to(ROOT)),kit_version=kit['kit_version'],
        prompt_path=str((JOB/'prompt.md').relative_to(ROOT)),prompt_sha256=kit['prompt_sha256'],ref_pixel_sha256=recorded_ref_digests(kit),
        raw_pixel_sha256=processed['raw_pixel_sha256'],source_path=str((JOB/'processed.png').relative_to(ROOT)),source_pixel_sha256=processed['pixel_sha256'],
        post_steps=processed.get('post_steps', []),
        pixel_sha256=pixel_digest(Image.open(path).convert('RGBA')),sheet_path=str((JOB/'sheet.png').relative_to(ROOT)),
        judge={'verdict':'PASS','date':'2026-11-15','note':'director judged 2026-11-15: approved take 1'},
        owner_approval='pending — inbox post',landmarks=landmarks,
        exceptions=[])
    entry['metrics']=measure(path,1.0,'creature','biped')
    registry=read_json(ROOT/'spec/art_identity/registry.json')
    registry['entries']=[e for e in registry['entries'] if e['id']!='emaciated_man']+[entry]
    write_json(ROOT/'spec/art_identity/registry.json',registry)
    write_json(JOB/'landmarks_pair.json',{'front':landmarks})

def refresh_pins():
    """Refresh only this unit's closure after the native rest/layout rebake."""
    path=ROOT/'tests/approved_asset_pins.json'; manifest=read_json(path)
    for section in ['files','images']:
        manifest[section]={k:v for k,v in manifest[section].items() if not k.startswith(str(BASE.relative_to(ROOT))+'/')}
    for file in sorted(BASE.rglob('*')):
        if file.suffix not in ('.png','.json'): continue
        relative=str(file.relative_to(ROOT)); data=file.read_bytes()
        manifest['files'][relative]=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
        if file.suffix=='.png':
            image=Image.open(file).convert('RGBA')
            manifest['images'][relative]={'size':list(image.size),'alpha_bounds':list(image.getchannel('A').getbbox() or ())}
    write_json(path,manifest)

def prune_density_sources():
    """Drop only this unit's obsolete, unregistered part records after re-cutting."""
    layout=read_json(BASE/'front.json')
    expected={str((BASE/part['file']).relative_to(ROOT)) for part in layout['parts']}
    expected.add(str((BASE/'front/rest.png').relative_to(ROOT)))
    prefix=str(BASE.relative_to(ROOT))+'/'
    path=ROOT/'spec/assets/board_pixel_density/outputs.json'
    outputs=read_json(path)
    stale=[key for key in outputs if key.startswith(prefix) and key not in expected]
    for key in stale:
        del outputs[key]
        source=ROOT/'spec/assets/board_pixel_density/sources'/key
        if source.exists():source.unlink()
    write_json(path,outputs)

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--refresh-identity',action='store_true');a=p.parse_args()
    if a.refresh_identity:
        identity();refresh_pins();prune_density_sources()
        print('EMAC IDENTITY AND ASSET PINS: refreshed this unit only; owner approval remains pending')
        return
    report=read_json(CASE/'proof/hidden_fill_report.json')
    if not report['complete'] or not report['ok']: raise ValueError('Fill and validate the case first')
    config=read_json(CASE/'cutout.json');layout=read_json(CASE/config['layouts']['front'])
    BASE.mkdir(parents=True,exist_ok=True);(BASE/'front').mkdir(exist_ok=True)
    paths=[]
    expected={'rest.png'}|{part['name']+'.png' for part in layout['parts']}
    for stale in (BASE/'front').glob('*.png'):
        if stale.name not in expected:
            stale.unlink()
            sidecar=stale.with_suffix('.png.import')
            if sidecar.exists():sidecar.unlink()
    mapping={}
    for part in layout['parts']:
        old=part['file'];new='front/'+part['name']+'.png'
        shutil.copyfile(CASE/old,BASE/new);mapping[old]=new;part['file']=new
        paths.append(str((BASE/new).relative_to(ROOT)))
    for mesh in layout.get('joint_meshes',[]): mesh['file']=mapping[mesh['file']]
    rest=BASE/'front/rest.png';shutil.copyfile(CASE/'proof/front_rest.png',rest)
    layout['rest_source']='front/rest.png';layout['rest_source_sha256']=pixel_digest(Image.open(rest).convert('RGBA'))
    write_json(BASE/'front.json',layout)
    # Same NPC frame fitting, footing, art_scale and source-driven shadow path
    # as the Scavenger. The optional portrait field only changes this NPC.
    data=read_json(ROOT/'data/npcs.json');npc=data['emaciated_man']
    npc['art_path']='res://'+str(rest.relative_to(ROOT));npc['art_scale']=1.0
    npc.pop('idle_sheet_ping_pong',None)
    npc['cutout']='res://scripts/emaciated_man_cutout/rig.gd'
    hood=next(p for p in layout['parts'] if p['logical_part']=='head_hood' and not p.get('hidden_material'))
    bounds=Image.open(BASE/hood['file']).getbbox();width=1.9*layout['portrait_head_width']
    # Center on the measured painted eyes, not the asymmetric hood/drape bbox.
    face_x=read_json(JOB/'paint_landmarks.json')['face_center_x']
    npc['portrait_region']=[face_x-width/2,hood['offset'][1]+bounds[1]-6,width,width]
    write_json(ROOT/'data/npcs.json',data)
    m=metrics(Image.open(rest).convert('RGBA'));t=strength(m['orphan_share']);grid=round(t/1.0,2)
    density=dict(id='emaciated_man_cutout',unit_type='emaciated_man',kind='rig',dir=str(BASE.relative_to(ROOT)),rig_script='scripts/emaciated_man_cutout/rig.gd',paths=sorted(paths),frames=None,r=1.0,
        r_derivation={'path':'data/npcs.json','key':'emaciated_man.art_scale','expression':'NPC fitted 255-canvas art_scale / hero source pixel scale; director art_scale 1.0'},
        facings={'front':{'measurement_path':str(rest.relative_to(ROOT)),'orphan_share':m['orphan_share'],'t':t,'grid':grid,'mode':'regrid' if grid>=1.2 else 'clean'}},
        rest_paths={'front':[str(rest.relative_to(ROOT))]})
    reg=read_json(ROOT/'spec/assets/board_pixel_density/registry.json')
    reg['entries']=[e for e in reg['entries'] if e['id']!='emaciated_man_cutout']+[density]
    write_json(ROOT/'spec/assets/board_pixel_density/registry.json',reg)
    identity();prune_density_sources()
    print('EMAC INSTALL: PASS; parts=%d; native rest rebake and owner approval PENDING'%len(paths))

if __name__=='__main__':main()
