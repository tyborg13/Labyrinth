"""Exact director provenance and underlay-air classification, case-owned."""
from collections import defaultdict
import numpy as np
from rr48_build import MESHES
from rr48_feedback2_source import source_plan
from rr48_feedback3_source import domains,RECEIVERS
from rr48_feedback1 import inputs
from rr48_feedback3_cpu import box
from rr48_joint_budget import nearest_joint
from humanoid_cutout.gates import matrix,clean_metrics
from humanoid_cutout.cpu_pose import mapped,mesh_map,mask_mesh
from maquette_motion import pixels
from maquette_motion.silhouette import holes
from maquette_motion.material_palette import outline_class,rules

class DirectorPolicy:
 def __init__(self,model):
  self.model=model;self.layout=model.layout;self.view=self.layout['facing'];self.domains=domains(self.view);self.plans=source_plan(self.view)
  self.definition=rules(model.case,self.view)
  self.underlay=inputs(self.view)
  self.parts={p['name']:p for p in self.layout['parts']};self.outline_records=[];self.pockets=[]
  self.references={};self.reference_cache={}
  for mesh in self.layout['joint_meshes']:
   name=mesh['name'].removeprefix('hidden_')
   if not mesh['name'].startswith('hidden_') or name not in self.domains:continue
   part=self.parts[mesh['name']];x,y,r,b=part['bbox'];source=self.underlay[y:b,x:r].copy()
   self.references[name]=(mask_mesh(mesh,source[...,3]>0),source)

 def metrics(self,layers,row,maps,native=False):
  metric=clean_metrics(layers,self.definition);occupied=np.zeros(layers[0][1].shape[:2],bool);rejected=0
  for part,im,checks in sorted(layers,key=lambda r:r[0]['z_index'],reverse=True):
   alpha=im[...,3]>0;dark=alpha&~occupied&(checks[...,1]>0)&outline_class(im,self.definition);occupied|=alpha
   if not dark.any():continue
   expected=np.zeros_like(im);candidates=[expected];name=part['name']
   if name in self.plans:
    registered=self.parts[name];x,y,r,b=registered['bbox'];source=self.plans[name]['image'][y:b,x:r].copy();actual=self.model.image(registered['file']);source[np.any(actual!=source,axis=-1)]=0
    if name in maps:
     if native:
      mapping=mesh_map(self.layout,row,self.model.meshes[name],with_ties=True,native_skin=True,triangle_batch_size=self.model.triangle_batch_size);candidates=mapped(source,mapping,with_ties=True).candidates
     else:candidates=[mapped(source,maps[name])]
    else:
     rendered=pixels.render(source,matrix(row['parts'][name]['transform']),with_ties=native)
     candidates=rendered.candidates if native else [rendered]
   certified=np.logical_or.reduce([(e[...,3]>0)&np.all(e==im,axis=-1) for e in candidates]);approved=dark&certified;bad=dark&~approved;rejected+=int(bad.sum())
   self.outline_records.append({'view':self.view,'clip':row['clip'],'frame':row['frame'],'part':name,'approved_pixels':int(approved.sum()),'rejected_pixels':int(bad.sum()),'bbox':box(dark)})
  metric['exposed_outline_pixels']=rejected
  return metric

 def painted(self,mask,row):
  y,x=np.nonzero(mask);blocked=np.zeros(len(x),bool);traces={}
  for name in RECEIVERS:
   part=self.parts['hidden_'+name];painted=np.zeros(len(x),bool)
   if name in MESHES:
    # Inverting each bone separately invents source hits in the other limb's
    # negative space. Invert the actual receiving skin through its native UV
    # triangles; this reference never depends on possibly missing actual paint.
    mesh,source=self.references[name];key=(name,tuple(tuple(row['bones'][b]['global']) for b in mesh['weights']))
    if key not in self.reference_cache:
     self.reference_cache={k:v for k,v in self.reference_cache.items() if k[0]!=name}
     mapping=mesh_map(self.layout,row,mesh,native_skin=True,triangle_batch_size=self.model.triangle_batch_size)
     self.reference_cache[key]=mapped(source,mapping)[...,3]>0
    painted=self.reference_cache[key][y,x]
   else:
    key=(name,tuple(row['parts'][part['name']]['transform']))
    if key not in self.reference_cache:
     self.reference_cache={k:v for k,v in self.reference_cache.items() if k[0]!=name}
     a,b,r,d=part['bbox'];source=self.underlay[b:d,a:r]
     # The quad raster is the exact inverse-UV lookup, including its fixed
     # subpixel vertex rule; a raw float64 inverse can pick a different texel.
     self.reference_cache[key]=pixels.render(source,matrix(row['parts'][part['name']]['transform']))[...,3]>0
    painted=self.reference_cache[key][y,x]
   traces[name]=int(painted.sum());blocked|=painted
  return blocked,traces

 def space(self,occupied,row):
  failures=[];air=[]
  for mask in holes(occupied):
   blocked,traces=self.painted(mask,row);record={'view':self.view,'clip':row['clip'],'frame':row['frame'],'joint':nearest_joint(row,box(mask)),'bbox':box(mask),'pixel_count':int(mask.sum()),'painted_pixels':int(blocked.sum()),'receivers':traces}
   if not blocked.any():air.append(record)
   else:self.pockets.append(record);failures.append(record)
  return {'failures':failures,'air_pockets':air}

 def validate_negative_space(self,mask,row):
  blocked,_=self.painted(mask,row)
  return [] if not blocked.any() else ['Natural-negative-space claim maps to director underlay paint']

def temporal(records):
 """Only the director's <=4 px, <=3 consecutive frame rule accepts a tear."""
 groups=defaultdict(list)
 for r in records:groups[r['view'],r['clip'],r['joint']].append(r)
 accepted=[];failures=[]
 for rows in groups.values():
  frames=sorted({r['frame'] for r in rows});runs=[]
  for f in frames:
   if runs and f==runs[-1][-1]+1:runs[-1].append(f)
   else:runs.append([f])
  for run in runs:
   selected=[r for r in rows if r['frame'] in run];ok=len(run)<=3 and all(r['pixel_count']<=4 for r in selected)
   (accepted if ok else failures).extend(selected)
 return failures,accepted
