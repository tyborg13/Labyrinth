"""Director feedback 2: named, case-only torn-cloth component exemption.

Only a complete visible composite component owned exclusively by cloak or
front cloth can qualify. Idle and hit are zero tolerance. Distance is Euclidean
source-pixel nearest-edge distance to that same cloth part's largest isolated component in this
frame; neither a neighbouring limb nor another shred supplies the reference.
"""
import numpy as np
from humanoid_cutout.held_release import ComponentPolicy
from maquette_motion.silhouette import components,dilate

POLICY_NAME='rr56_director_torn_cloth_6px_within_8px'
CLOTH_PARTS=frozenset(('cloak','tabard'))
MAX_PIXELS=6
MAX_DISTANCE_PX=8
ZERO_TOLERANCE_CLIPS=frozenset(('idle','hit'))


def accepted(layout,layers,clip):
    if clip in ZERO_TOLERANCE_CLIPS:return [],[]
    parts={p['name']:p for p in layout['parts']};names=list(parts);ids={n:i+1 for i,n in enumerate(names)}
    owner=np.zeros(layers[0][1].shape[:2],np.uint16);occupied=np.zeros_like(owner,bool);cloth={n:np.zeros_like(owner,bool) for n in CLOTH_PARTS}
    for row,image,_ in sorted(layers,key=lambda r:r[0]['z_index']):
        alpha=image[...,3]>0;occupied|=alpha;owner[alpha]=ids[row['name']]
        logical=parts[row['name']]['logical_part']
        if logical in cloth:cloth[logical]|=alpha
    main={};body={}
    for name,mask in cloth.items():
        labels,groups=components(mask,8)
        body[name]=labels==groups[0][0] if groups else np.zeros_like(mask)
        main[name]=dilate(body[name],MAX_DISTANCE_PX)
    labels,groups=components(occupied,8);masks=[];records=[]
    for label,size in groups[1:]:
        if size>MAX_PIXELS:continue
        mask=labels==label
        logical={parts[names[i-1]]['logical_part'] for i in np.unique(owner[mask]) if i}
        if len(logical)!=1:continue
        name=next(iter(logical))
        if name not in CLOTH_PARTS or not (main[name]&mask).any():continue
        # A detached part's own main body cannot authorize itself.
        if np.any(mask&body[name]):continue
        yy,xx=np.nonzero(mask);masks.append(mask)
        records.append({'policy':POLICY_NAME,'part':name,'pixel_count':int(size),
                        'bbox':[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)]})
    return masks,records


class RagComponentPolicy(ComponentPolicy):
    def __init__(self,case,anatomy,motion,layout,rest_components):
        super().__init__(anatomy,motion,layout,rest_components);self.layout=layout;self.cleared=[]

    def report(self,occupied,layers,clip,phase,pose=None,cpu_model=None):
        result=super().report(occupied,layers,clip,phase)
        masks,records=accepted(self.layout,layers,clip)
        if masks and cpu_model is not None:
            uncertain,cloth=uncertainty(cpu_model,pose,layers)
            keep=[i for i,(m,r) in enumerate(zip(masks,records)) if r['part'] not in cloth and not (dilate(m,1)&uncertain).any()]
            masks=[masks[i] for i in keep];records=[records[i] for i in keep]
        self.cleared.extend(dict(view=self.view,clip=clip,phase=phase,**r) for r in records)
        result['errors']=[e for e in result['errors'] if not e.startswith('floating pieces:')]
        if result['components']>self.baseline+len(result['masks'])+len(masks):
            result['errors'].append(f"floating pieces: {result['components']} components > rest {self.baseline} + released {len(result['masks'])} + director cloth {len(masks)}")
        result['masks']+=masks
        result['released_components']+=records
        result['director_cloth_components']=records
        return result


def uncertainty(model,pose,layers):
    """CPU never grants a cloth exception on an ambiguous nearest-UV edge.

    Native evaluates its actual pixels. CPU keeps the finding if any legal UV
    tie can change the cloth main body or touch/grow a candidate component.
    """
    from humanoid_cutout.cpu_pose import mesh_map,mapped
    from humanoid_cutout.gates import matrix
    from maquette_motion import pixels
    union=np.zeros(layers[0][1].shape[:2],bool);cloth=set()
    for part,image,_ in layers:
        name=part['name'];source=model.image(part['file'])
        if name in model.meshes:
            mapping=mesh_map(model.layout,pose,model.meshes[name],with_ties=True,native_skin=True,triangle_batch_size=128)
            variants=mapped(source,mapping,with_ties=True).candidates
        else:variants=pixels.render(source,matrix(pose['parts'][name]['transform']),with_ties=True).candidates
        alpha=image[...,3]>0
        ambiguous=np.logical_or.reduce([(v[...,3]>0)!=alpha for v in variants])
        union|=ambiguous
        if ambiguous.any() and part['logical_part'] in CLOTH_PARTS:cloth.add(part['logical_part'])
    return union,cloth
