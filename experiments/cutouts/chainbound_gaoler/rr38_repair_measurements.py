"""Measure same-piece source continuations for confirmed native joint pockets.

Only source UVs of transparent samples in the existing hidden skin are added.
The adjoining root limb owns a limb seam; torso/pelvis own their covered joins.
No posed bitmap is patched and no new colour is generated.
"""
import argparse
import collections
from pathlib import Path
import numpy as np
from rr38_triage import Evidence
from rr38_case import CASE
from rr38_surfaces import interior
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.cpu_pose import CpuPose, mesh_map, sprite_transform
from humanoid_cutout.mesh import grid, weights_for
from humanoid_cutout.canvas import for_case
from humanoid_cutout.anatomy import owner_ids, load
from humanoid_cutout.silhouette_gates import posed_owners
from maquette_motion.features import source_pixels
from maquette_motion.material_palette import rules
from maquette_motion.silhouette import holes, dilate


def measure(case, treated, native, retained, records, output, start=0, count=4):
    evidence=Evidence(case,native,retained)
    samples=read_json(case/'proof/logs/samples.json')['samples']
    poses={(r['view'],r['clip'],r['frame']):r for r in samples if r['kind']=='presented'}
    models={v:CpuPose(case,read_json(case/f'layouts/{v}.json'),triangle_batch_size=128) for v in ('front','rear')}
    targets=collections.defaultdict(set);rows=[]
    keys=sorted({(r['view'],r['clip'],r['frame']) for r in records if r['kind']=='gate' and r['classification']=='a_native' and r.get('native_joint_pockets')})[start:start+count]
    with for_case(case):
        for key in keys:
            pose=poses[key];model=models[key[0]]
            actual,layers,pockets,frame=evidence.frame(pose,model)
            anatomy=load(case);ownership=anatomy['ownership']
            owners=posed_owners(layers,model.layout['parts'],pose['bones'],192,ownership)
            names={value:name for name,value in owner_ids(ownership).items()}
            roots={n:logical for logical,r in ownership['segments'].items() for n in r['owners']}
            parts={p['name']:p for p in model.layout['parts']}
            all_holes=holes(actual[...,3]>0)
            for pocket in pockets:
                mask=next(m for m in all_holes if [int(np.nonzero(m)[1].min()),int(np.nonzero(m)[0].min()),int(np.nonzero(m)[1].max()+1),int(np.nonzero(m)[0].max()+1)]==pocket['bbox'])
                rim=dilate(mask,1)&(actual[...,3]>0)
                counts=collections.Counter(roots.get(names[int(n)],names[int(n)]) for n in owners[rim])
                # The long root surface continues under its rigid end/cover.
                candidates=[n for n in counts if n.startswith(('leg_','arm_'))]
                if not candidates:candidates=[n for n in ('torso','pelvis') if n in counts]
                if not candidates and set(counts)<=set(('chain','hand_far')):candidates=['hand_far']
                logical=max(candidates,key=lambda n:(counts[n],n)) if candidates else None
                row={'view':key[0],'clip':key[1],'frame':key[2],**pocket,'boundary':dict(counts),'piece':logical,'native_frame_sha256':frame['sha256']}
                name='hidden_'+str(logical)
                if name not in parts:
                    row['unresolved']='No existing hidden skin for this join';rows.append(row);continue
                part=parts[name];source=source_pixels(case,part)
                seed=interior(source_pixels(case,parts[logical]),rules(case,key[0]))
                if name not in model.meshes:
                    y,x=np.nonzero(mask)
                    points=np.column_stack((x+.5-192,y+.5-192,np.ones(len(x))))
                    uv=(np.linalg.inv(sprite_transform(model.layout,pose,part))@points.T).T[:,:2]
                    uv=np.floor(uv).astype(int)+part['offset']
                    selected={(int(x),int(y)) for x,y in uv if 0<=x<255 and 0<=y<255
                        and not source[y,x,3] and not source_pixels(case,parts[logical])[y,x,3] and seed[y,:,3].any()}
                    targets[key[0],name].update(selected)
                    row['source_targets']=[list(p) for p in sorted(selected,key=lambda p:(p[1],p[0]))]
                    if not selected:row['unresolved']='No same-row glove continuation at the captured grip opening'
                    rows.append(row);continue
                mesh=model.meshes[name]
                # Include the existing 3px joint tuck outside a tight crop.
                # Expand by whole grid cells so every old triangle stays put.
                depth=anatomy['tucks']['pieces'][logical]['depth_px']
                cells=int(np.ceil(depth/mesh['grid_px']))*mesh['grid_px']
                x0,y0,x1,y1=part['bbox']
                expanded=[max(0,x0-cells),max(0,y0-cells),min(255,x1+cells),min(255,y1+cells)]
                vertices,uvs,triangles=grid(expanded)
                full=dict(mesh,vertices=vertices,uvs=uvs,triangles=triangles,
                    weights=weights_for(vertices,mesh['weight_bounds'],model.layout['joints'],anatomy['meshes'][logical]))
                mapping=mesh_map(model.layout,pose,full,with_ties=True,native_skin=True,triangle_batch_size=128)
                xy=mapping.pixels;inside=mask[xy[:,1],xy[:,0]]
                selected=[]
                for uv in (mapping.texels,)+mapping.alternatives:
                    for u,v in uv[inside]:
                        x,y=int(u+expanded[0]),int(v+expanded[1])
                        if not (0<=y<255 and 0<=x<255) or source[y,x,3]:continue
                        if not seed[y,:,3].any():continue
                        if source_pixels(case,parts[logical])[y,x,3]:continue
                        selected.append((x,y))
                selected=set(selected)
                targets[key[0],name].update(selected)
                row['source_targets']=[list(p) for p in sorted(selected,key=lambda p:(p[1],p[0]))]
                if not selected:row['unresolved']='No transparent same-row sample in the existing own-piece skin; requires native follow-up'
                rows.append(row)
    result={'targets':{view:{name:[list(p) for p in sorted(points,key=lambda p:(p[1],p[0]))] for (v,name),points in targets.items() if v==view} for view in models},'pockets':rows}
    write_json(output,result)
    print(f'RR38 REPAIR MEASUREMENTS: {len(rows)} native pockets; {sum(len(p) for p in targets.values())} source targets; {sum("unresolved" in r for r in rows)} unresolved',flush=True)
    return result


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('case','treated-case','native','retained','triage','output'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--start',type=int,default=0);p.add_argument('--count',type=int,default=4)
    a=p.parse_args()
    if not 1<=a.count<=4:p.error('Use measurement shards of at most four frames')
    measure(a.case,a.treated_case,a.native,a.retained,read_json(a.triage)['records'],a.output,a.start,a.count)
