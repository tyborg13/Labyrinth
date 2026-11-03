"""Director feedback 1: exact paint provenance and inverse receiver-underlay air."""
from collections import defaultdict
import numpy as np
from PIL import Image
from rr52_build import ROOT,ASSETS
from humanoid_cutout.gates import matrix,clean_metrics
from humanoid_cutout.cpu_pose import CpuPose,mask_mesh,mesh_map,mapped
from maquette_motion import pixels
from maquette_motion.silhouette import holes
from maquette_motion.material_palette import outline_class,rules
from cutout_pipeline.cases import read_json,write_json,digest


def box(mask):
    y,x=np.nonzero(mask)
    return [int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)] if len(x) else None


def temporal(records):
    groups=defaultdict(list);accepted=[];failures=[]
    for row in records:groups[row['view'],row['clip'],row['joint']].append(row)
    for rows in groups.values():
        runs=[]
        for f in sorted({r['frame'] for r in rows}):
            if runs and f==runs[-1][-1]+1:runs[-1].append(f)
            else:runs.append([f])
        for run in runs:
            selected=[r for r in rows if r['frame'] in run]
            size=lambda r:r.get('source_space',r)['pixel_count']
            (accepted if len(run)<=2 and all(size(r)<3 for r in selected) else failures).extend(selected)
    return failures,accepted


class SurfacePolicy:
    def __init__(self,model):
        self.model=model;self.layout=model.layout;self.definition=rules(model.case,self.layout['facing'])
        self.underlay=np.asarray(Image.open(ROOT/f"spec/peer_benchmark/staged/rr-52/{self.layout['facing']}_body_underlay.png").convert('RGBA'))
        self.painting=np.asarray(Image.open(model.case/self.layout['raw_rest_source']).convert('RGBA'))
        self.parts={p['name']:p for p in self.layout['parts']};self.references={};self.cache={};self.air=[];self.pockets=[];self.outlines=[];self.approved={};self.uv_cache={};self.cap_requests={}
        for part in self.layout['parts']:
            name=part['name'];x,y,r,b=part['bbox']
            if part.get('paint_sources'):
                if self.layout.get('density_treated_proof'):
                    # The case's certified density input is immutable. Reading
                    # live production PNGs here corrupts historical calibration
                    # as soon as a new coverage crop has a different size.
                    actual=model.image(part['file']);expected=self.layout['proof_layers'][name]['source_sha256']
                    self.approved[name]=actual.copy() if digest(model.case/part['file'])==expected else np.zeros_like(actual)
                else:
                    expected=np.zeros_like(self.underlay)
                    for kind,paint in [('underlay',self.underlay),('cap',self.painting)]:
                        mask=np.asarray(Image.open(model.case/part['paint_sources'][kind]).convert('L'))>0;expected[mask]=paint[mask]
                    self.approved[name]=expected[y:b,x:r]
            if not part.get('director_underlay'):continue
            source=self.underlay[y:b,x:r].copy()
            reference=self.layout.get('underlay_reference_bounds',{}).get(name)
            if reference:
                a0,b0,r0,d0=reference
                if not (x<=a0 and y<=b0 and r>=r0 and b>=d0):raise ValueError('Native-calibrated reference domain was clipped')
                fixed=np.zeros(self.underlay.shape[:2],bool);fixed[b0:d0,a0:r0]=True
                # Added source crops are storage, not newly discovered body.
                # Preserve ALL old reference UVs and independently registered
                # new painted/tuck UVs; never infer body from a growing bbox.
                if part.get('paint_sources'):
                    for kind in ('underlay','cap'):fixed|=np.asarray(Image.open(model.case/part['paint_sources'][kind]).convert('L'))>0
                source[~fixed[y:b,x:r]]=0
                if part.get('paint_sources'):
                    cap=np.asarray(Image.open(model.case/part['paint_sources']['cap']).convert('L'))[y:b,x:r]>0
                    source[cap]=self.painting[y:b,x:r][cap]
            if not (source[...,3]>0).any():continue
            mesh=next((m for m in self.layout['joint_meshes'] if m['name']==name),None)
            self.references[name]=(mask_mesh(mesh,source[...,3]>0) if mesh else None,source)

    def metrics(self,layers,row,maps,native=False):
        metric=clean_metrics(layers,self.definition);occupied=np.zeros(layers[0][1].shape[:2],bool);rejected=0
        for part,image,checks in sorted(layers,key=lambda r:r[0]['z_index'],reverse=True):
            alpha=image[...,3]>0;dark=alpha&~occupied&(checks[...,1]>0)&outline_class(image,self.definition);occupied|=alpha
            if not dark.any():continue
            name=part['name'];certified=np.zeros_like(dark)
            if name in self.approved:
                source=self.approved[name].copy();actual=self.model.image(self.parts[name]['file']);source[np.any(actual!=source,axis=-1)]=0
                if name in maps:
                    candidates=[mapped(source,maps[name])]
                    if native:
                        mapping=mesh_map(self.layout,row,self.model.meshes[name],with_ties=True,native_skin=True,triangle_batch_size=128);candidates=mapped(source,mapping,with_ties=True).candidates
                else:
                    rendered=pixels.render(source,matrix(row['parts'][name]['transform']),with_ties=native);candidates=rendered.candidates if native else [rendered]
                certified=np.logical_or.reduce([(candidate[...,3]>0)&np.all(candidate==image,axis=-1) for candidate in candidates])
            bad=dark&~certified;rejected+=int(bad.sum())
            self.outlines.append({'view':row['view'],'clip':row['clip'],'frame':row['frame'],'part':name,'approved_pixels':int((dark&certified).sum()),'rejected_pixels':int(bad.sum()),'bbox':box(dark)})
        metric['exposed_outline_pixels']=rejected
        return metric

    def painted(self,mask,row):
        y,x=np.nonzero(mask);blocked=np.zeros(len(x),bool);traces={}
        for name,(mesh,source) in self.references.items():
            if mesh:
                key=(name,tuple(tuple(row['bones'][bone]['global']) for bone in mesh['weights']))
                if key not in self.cache:
                    self.cache={k:v for k,v in self.cache.items() if k[0]!=name}
                    x0,y0,_,_=self.parts[name]['bbox'];yy,xx=np.indices(source.shape[:2]);encoded=np.zeros_like(source);encoded[...,0]=xx+x0;encoded[...,1]=yy+y0;encoded[...,3]=source[...,3]
                    self.uv_cache[name]=mapped(encoded,mesh_map(self.layout,row,mesh,native_skin=True,triangle_batch_size=128))
                    self.cache[key]=self.uv_cache[name][...,3]>0
            else:
                key=(name,tuple(row['parts'][name]['transform']))
                if key not in self.cache:
                    self.cache={k:v for k,v in self.cache.items() if k[0]!=name}
                    x0,y0,_,_=self.parts[name]['bbox'];yy,xx=np.indices(source.shape[:2]);encoded=np.zeros_like(source);encoded[...,0]=xx+x0;encoded[...,1]=yy+y0;encoded[...,3]=source[...,3]
                    self.uv_cache[name]=pixels.render(encoded,matrix(row['parts'][name]['transform']))
                    self.cache[key]=self.uv_cache[name][...,3]>0
            painted=self.cache[key][y,x];traces[name]=int(painted.sum());blocked|=painted
        return blocked,traces

    def space(self,occupied,row,*unused):
        from rr52_joint_budget import nearest_joint
        failures=[];air=[]
        for mask in holes(occupied):
            blocked,traces=self.painted(mask,row)
            record={'view':row['view'],'clip':row['clip'],'frame':row['frame'],'joint':nearest_joint(row,box(mask)),'bbox':box(mask),'pixel_count':int(mask.sum()),'painted_pixels':int(blocked.sum()),'receivers':traces}
            (failures if blocked.any() else air).append(record)
            if blocked.any():
                yy,xx=np.nonzero(mask)
                for name,count in traces.items():
                    if not count:continue
                    encoded=self.uv_cache[name];hit=encoded[yy,xx,3]>0
                    for u,v in np.unique(encoded[yy[hit],xx[hit],:2],axis=0):
                        u,v=int(u),int(v);a,b,_,_=self.parts[name]['bbox'];actual=self.model.image(self.parts[name]['file'])
                        if actual[v-b,u-a,3]:continue
                        self.cap_requests.setdefault((name,u,v),{'view':row['view'],'part':name,'uv':[u,v],'clip':row['clip'],'frame':row['frame']})
        self.air+=air;self.pockets+=failures
        return {'failures':failures,'air_pockets':air}


class NativeSurface:
    def __init__(self,case,layout,capture):
        self.model=CpuPose(case,layout,native_skin=True,triangle_batch_size=128);self.policy=SurfacePolicy(self.model)
        self.rows={(r['view'],r['clip'],r['frame']):r for r in read_json(case/'proof/raster_samples.json')['samples']}

    def metrics(self,layers,pose,metric):
        row=self.rows[pose['view'],pose['clip'],pose['frame']];_,maps=self.model.layers(row)
        return dict(metric,exposed_outline_pixels=self.policy.metrics(layers,row,maps,native=True)['exposed_outline_pixels'])

    def space(self,occupied,pose):
        space=self.policy.space(occupied,self.rows[pose['view'],pose['clip'],pose['frame']])
        return dict(space,failures=[r for r in space['failures'] if r['pixel_count']>=3])

    def finish(self):
        failures,accepted=temporal(self.policy.pockets)
        write_json(self.model.case/f"proof/native_air_{self.model.layout['facing']}.json",{'natural_negative_space':self.policy.air,'remaining_tears':failures,'accepted_short_tears':accepted,'outline':self.policy.outlines})
        return [f'{r["view"]}/{r["clip"]}/{r["frame"]}: persistent director-underlay hole {r["bbox"]}' for r in failures if r['pixel_count']<3]
