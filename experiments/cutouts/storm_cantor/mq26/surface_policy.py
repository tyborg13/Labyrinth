"""Exact approved-source material and underlay-air policy, shared by CPU/native."""
import numpy as np
from PIL import Image
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.cpu_pose import CpuPose, mesh_map, mask_mesh, mapped
from humanoid_cutout.gates import matrix, clean_metrics
from maquette_motion import pixels
from maquette_motion.silhouette import holes
from maquette_motion.material_palette import outline_class, rules

def box(mask):
    y,x=np.nonzero(mask)
    return [int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)] if len(x) else None

def model(case,view):
    layout=read_json(case/f'layouts/{view}.json');m=CpuPose(case,layout,native_skin=True,triangle_batch_size=128)
    for name,mesh in m.meshes.items():
        alpha=m.image(next(p['file'] for p in layout['parts'] if p['name']==name))[...,3]>0
        selected=mask_mesh(mesh,alpha)
        if selected['triangles']:m.meshes[name]=selected
    return m

class SourcePolicy:
    def __init__(self,m):
        self.model=m;self.layout=m.layout;self.view=m.layout['facing'];self.definition=rules(m.case,self.view)
        self.parts={p['name']:p for p in m.layout['parts']};self.outline_records=[];self.pockets=[]
        self.underlay=np.asarray(Image.open(m.case/f'source/{self.view}/body_underlay.png').convert('RGBA'))
        self.reference_meshes={mesh['name']:mesh for mesh in self.layout['joint_meshes']}
        from air_references import References
        self.air_references=References(m)
        self.domains={}
        for name,part in self.parts.items():
            record=part.get('underlay_domain')
            if record:
                if digest(m.case/record['file'])!=record['sha256']:raise ValueError('Changed receiver domain: '+name)
                self.domains[name]=np.asarray(Image.open(m.case/record['file']).convert('L'))>0

    def metrics(self,layers,row,maps,native=False):
        metric=clean_metrics(layers,self.definition);occupied=np.zeros(layers[0][1].shape[:2],bool);rejected=0
        for part,im,checks in sorted(layers,key=lambda r:r[0]['z_index'],reverse=True):
            alpha=im[...,3]>0;dark=alpha&~occupied&(checks[...,1]>0)&outline_class(im,self.definition);occupied|=alpha
            if not dark.any():continue
            name=part['name'];registered=self.parts[name];source=self.model.image(registered['file'])
            if name in self.model.meshes:
                mapping=mesh_map(self.layout,row,self.model.meshes[name],with_ties=native,native_skin=True,triangle_batch_size=128) if native else maps[name]
                result=mapped(source,mapping,with_ties=native);candidates=result.candidates if native else [result]
            else:
                result=pixels.render(source,matrix(row['parts'][name]['transform']),with_ties=native);candidates=result.candidates if native else [result]
            certified=np.logical_or.reduce([(expected[...,3]>0)&np.all(expected==im,axis=-1) for expected in candidates])
            count=int((dark&~certified).sum());rejected+=count
            self.outline_records.append({'view':self.view,'clip':row['clip'],'frame':row['frame'],'part':name,'bbox':box(dark),
                                         'pixels':int(dark.sum()),'rejected_pixels':count})
        metric['exposed_outline_pixels']=rejected
        return metric

    def space(self,occupied,row,tears=()):
        # Transport complete immutable paint/tuck masks using the actual skin.
        # Enclosed air stays air when no approved receiver paints those UVs.
        painted=np.zeros_like(occupied)
        for name,part in self.parts.items():
            if not part.get('hidden_material'):continue
            x,y,r,b=part['bbox'];source=self.underlay[y:b,x:r].copy()
            if name in self.domains:source[~self.domains[name][y:b,x:r]]=0
            if name in self.reference_meshes:
                mesh=mask_mesh(self.reference_meshes[name],source[...,3]>0)
                if not mesh['triangles']:continue
                mapping=mesh_map(self.layout,row,mesh,native_skin=True,triangle_batch_size=128)
                reference=mapped(source,mapping)
            else:reference=pixels.render(source,matrix(row['parts'][name]['transform']))
            painted|=reference[...,3]>0
        failures=[];air=[];tear_bounds={tuple(t['bbox']) for t in tears}
        references=self.air_references.posed(row) if tears else [];used=set()
        for mask in holes(occupied):
            record={'view':self.view,'clip':row['clip'],'frame':row['frame'],'bbox':box(mask),'pixel_count':int(mask.sum()),
                    'painted_or_tuck_pixels':int((mask&painted).sum()),'joint_tear':tuple(box(mask)) in tear_bounds}
            if record['joint_tear']:
                ids=set(int(i) for ref in references for i in np.unique(ref[mask]))-{0}-used
                if ids:
                    identity=min(ids);used.add(identity);record.update(joint_tear=False,transported_rest_air=identity)
            (failures if record['joint_tear'] or (mask&painted).any() else air).append(record)
        self.pockets+=failures
        return {'failures':failures,'air_pockets':air}

class NativePolicy:
    def __init__(self,case,layout):
        self.model=model(case,layout['facing']);self.policy=SourcePolicy(self.model)
        self.rows={(r['view'],r['clip'],r['frame']):r for r in read_json(case/'proof/raster_samples.json')['samples']}
    def row(self,pose):return self.rows[pose['view'],pose['clip'],pose['frame']]
    def metrics(self,layers,pose,metric):
        self.layers=layers
        row=self.row(pose)
        result=self.policy.metrics(layers,row,{},native=True)
        return dict(metric,exposed_outline_pixels=result['exposed_outline_pixels'])
    def space(self,occupied,pose):
        from humanoid_cutout.silhouette_gates import posed_owners,joint_holes
        from humanoid_cutout.anatomy import load
        row=self.row(pose);maps={}
        # CpuPose.masks reuses a mesh's map when its seam has identical
        # vertices. Supply those maps even when metrics needed no paint map.
        for record in self.model.layout.get('proof_joint_seams',[]):
            owner=record['owner']
            if owner in self.model.meshes and owner not in maps:
                maps[owner]=mesh_map(self.model.layout,row,self.model.meshes[owner],native_skin=True,triangle_batch_size=128)
        seams=self.model.masks(row,self.model.layout.get('proof_joint_seams',[]),maps)
        seam=np.logical_or.reduce(seams) if seams else np.zeros_like(occupied)
        owners=posed_owners(self.layers,self.model.layout['parts'],row['bones'],pixels.PROOF_DEFAULTS['source_offset'],load(self.model.case)['ownership'])
        tears=joint_holes(occupied,seam,owners,pocket_details=True)
        return self.policy.space(occupied,row,tears)
    def finish(self):
        write_json(self.model.case/f'proof/native_outline_{self.model.layout["facing"]}.json',self.policy.outline_records)
        return []
