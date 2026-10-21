"""Read-only source/pose proof and unmasked CPU exports for feedback 2.

Native-before / CPU-after details are labelled in the JSON, never presented as
new native captures. Immutable paintings, visible cuts and neutral rests are
checked byte for byte against the implementation turn's HEAD.
"""
import hashlib
import subprocess
from pathlib import Path
import numpy as np
from PIL import Image
from rr30_case import CASE,ASSETS,PROJECT,DIRECTOR
from rr31_images import OUTPUT,ImageGate,composite
from rr30_joint_gate import JointSurfaceGate
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.bone_evidence import read_report
from humanoid_cutout.gates import bindings,matrix
from humanoid_cutout.native_frames import load_frame,frame_digest
from maquette_motion import pixels

DETAIL_SCALE=4  # Proof only.
DETAIL_BACKGROUND_RGBA=(30,30,36,255)  # Existing proof matte; never game art.
DETAIL_CROPS={('front','brace',20):(175,255,245,325),
              ('front','lob',32):(265,210,325,280),
              ('front','death',78):(265,225,325,295)}
CPU_FRAMES={'front':{'lob':[32,33,67],'brace':[20],'scatter':[39],'death':[78]},
            'rear':{'lob':[59,60],'brace':[7,8,47,48,50]}}


def head_bytes(path):
    return subprocess.check_output(['git','show','HEAD:'+str(path.relative_to(PROJECT))],cwd=PROJECT)


def preservation():
    layouts={v:read_json(CASE/f'layouts/{v}.json') for v in ('front','rear')}
    paths=[DIRECTOR,CASE/'director_motion.json',CASE/'compiled_motion.json',
        ASSETS/'humanoid_v2/director_motion.json',ASSETS/'humanoid_v2/compiled_motion.json',
        PROJECT/'spec/art_identity/registry.json',PROJECT/'spec/assets/board_pixel_density/registry.json']
    for view,layout in layouts.items():
        paths += [CASE/f'layouts/{view}.json',ASSETS/f'humanoid_v2/{view}.json',ASSETS/f'{view}.json',
            ASSETS/f'humanoid_v2/{view}/rest.png']
        paths += list((CASE/f'source/{view}').glob('*.png'))
        for part in layout['parts']:
            if part['hidden_material']:continue
            paths += [CASE/part['file'],ASSETS/'humanoid_v2'/view/Path(part['file']).name]
    hashes={str(p.relative_to(PROJECT)):digest(p) for p in sorted(set(paths))}
    mismatches=[str(p.relative_to(PROJECT)) for p in paths if p.read_bytes()!=head_bytes(p)]
    if mismatches:raise ValueError('Protected state changed: '+str(mismatches))
    density_path=PROJECT/'spec/assets/board_pixel_density/outputs.json'
    import json
    before=json.loads(head_bytes(density_path));after=read_json(density_path)
    if before.keys()!=after.keys():raise ValueError('Density registry membership changed')
    changed={}
    for path,value in after.items():
        fields={key for key in value if value[key]!=before[path].get(key)}
        if fields:
            if not path.startswith('assets/units/slag_mortar_cutout/') or fields-{'pixel_sha256','source_pixel_sha256'}:
                raise ValueError('Density calibration or unrelated output changed: '+path)
            changed[path]=sorted(fields)
    alpha_matches=0
    for view,layout in layouts.items():
        for part in layout['parts']:
            source=np.asarray(Image.open(CASE/part['file']).convert('RGBA'))[...,3]
            production=np.asarray(Image.open(ASSETS/'humanoid_v2'/view/Path(part['file']).name).convert('RGBA'))[...,3]
            if not np.array_equal(source,production):raise ValueError('Production alpha differs: '+part['name'])
            alpha_matches+=1
    rests=pixels.rest_identity(CASE)
    if not rests['ok']:raise ValueError('Approved source rest changed')
    result=dict(ok=True,immutable_files=len(hashes),sha256=hashes,rests=rests,
        production_alpha_matches=alpha_matches,
        density=dict(calibration_unchanged=True,changed_hashes=changed),
        note='Source construction additions require the owner to refresh native source bindings, even though both rest PNGs remain byte-identical.')
    write_json(OUTPUT/'proof/feedback2_preservation.json',result)
    print(f'RR31 FEEDBACK2 PRESERVATION: PASS ({len(hashes)} immutable files; both rests 0px; density calibration unchanged)',flush=True)
    return result


def exports():
    samples=read_report(CASE)
    if samples['inputs']!=bindings(CASE):raise ValueError('Refresh samples before CPU proof exports')
    manifest=read_json(CASE/'proof/native/frames.json')
    frames=[]
    for view,clips in CPU_FRAMES.items():
        gate=ImageGate(CASE,read_json(CASE/f'layouts/{view}.json'))
        for clip,indices in clips.items():
            for frame in indices:
                pose=next(p for p in samples['samples'] if
                    (p['view'],p['clip'],p['frame'],p['kind'])==(view,clip,frame,'presented'))
                image=Image.fromarray(composite(sorted(gate.layers(pose),key=lambda r:r[0]['z_index']))[0])
                path=OUTPUT/f'proof/feedback2_cpu/{view}_{clip}_{frame:04d}.png'
                path.parent.mkdir(parents=True,exist_ok=True);image.save(path)
                record=dict(view=view,clip=clip,frame=frame,file=str(path.relative_to(OUTPUT)),sha256=digest(path),native_pixels=False)
                key=(view,clip,frame)
                if key in DETAIL_CROPS:
                    row=next(r for r in manifest['frames'] if (r['view'],r['clip'],r['frame'])==key)
                    native=CASE/'proof/native'/row['file']
                    if frame_digest(native)!=row['sha256']:raise ValueError('Original native capture changed')
                    box=DETAIL_CROPS[key];size=((box[2]-box[0])*DETAIL_SCALE,(box[3]-box[1])*DETAIL_SCALE)
                    detail=Image.new('RGBA',(size[0]*2,size[1]),DETAIL_BACKGROUND_RGBA)
                    detail.alpha_composite(load_frame(native).convert('RGBA').crop(box).resize(size,Image.Resampling.NEAREST))
                    detail.alpha_composite(image.crop(box).resize(size,Image.Resampling.NEAREST),(size[0],0))
                    target=OUTPUT/f'proof/feedback2_{clip}_detail.png';detail.save(target)
                    record['detail']=dict(file=str(target.relative_to(OUTPUT)),left='unchanged round-1 native',
                        right='new source CPU render',crop=box,scale=DETAIL_SCALE,native_before_sha256=row['sha256'])
                frames.append(record)
    fixture=read_json(OUTPUT/'feedback2_native_targets.json')
    coverage=[]
    for row in fixture['targets']:
        layout=read_json(CASE/f'layouts/{row["view"]}.json')
        gate=ImageGate(CASE,layout);part=gate.parts[row['piece']]
        image=gate.model.image(part['file'])
        yy,xx=np.indices(image.shape[:2])
        uv=np.stack((xx,yy,np.ones_like(xx),np.full_like(xx,255)),axis=2).astype('uint8')
        mapped=pixels.render(uv,matrix(row['transform']),with_ties=True)
        paint=pixels.render(image,matrix(row['transform']),with_ties=True)
        x,y=row['destination']
        source_points=sorted({tuple(c[y,x,:2].astype(int)+part['offset']) for c in mapped.candidates})
        alpha=[int(c[y,x,3]) for c in paint.candidates]
        if alpha!=[255]*len(alpha):raise ValueError('A native hole still lacks source coverage')
        coverage.append(dict(row,source_choices=[list(map(int,p)) for p in source_points],alpha_choices=alpha))
    result=dict(native_pixels=False,frames=frames,native_pose_source_coverage=coverage,
        source_coverage_passed=len(coverage),source_coverage_total=7,
        native_acceptance='Pending director rerun; these are CPU source/pose checks, not a new native-gate pass.')
    write_json(OUTPUT/'proof/feedback2_cpu.json',result)
    print(f'RR31 FEEDBACK2 CPU EXPORTS: PASS ({len(frames)} unmasked frames; 7/7 native-pose source targets covered)',flush=True)


if __name__=='__main__':
    preservation()
    exports()
