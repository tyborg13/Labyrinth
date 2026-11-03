"""Exact rigid-source release proof for a chain's separated painted links.

One rigid item can rasterize to several alpha components. Each exempted
component must be the entire unoccluded transported source component. A
count, colour range, size or frame whitelist cannot establish that proof.
"""
import numpy as np
from humanoid_cutout.held_release import ComponentPolicy
from humanoid_cutout.gates import matrix
from humanoid_cutout.gait_continuations import texture
from maquette_motion import pixels
from maquette_motion.silhouette import components
from rr44_case import DEFAULTS


class RigidSourcePolicy(ComponentPolicy):
    def __init__(self,case,anatomy,motion,layout,rest_components):
        super().__init__(anatomy,motion,layout,rest_components)
        self.case,self.layout=case,layout
        self.held_exact=[n for n,a in layout.get('held_items',{}).items() if a.get('component_provenance')=='rigid_source_rgba']
        self.exact=[n for n,a in layout.get('held_items',{}).items() if a.get('release_provenance')=='rigid_source_rgba' or n in self.held_exact]
        self.pose=None

    def boundary_ownership(self,ownership,clip,phase):
        # A released item no longer has an anatomical grip joint. Retire
        # only that pair: a nearby real body-joint tear still fails.
        retired={frozenset((item,a['presentation_grip_part'])) for item,a in self.layout.get('held_items',{}).items()
                 if a.get('presentation_grip_part') and phase>=self.release_at(clip).get(item,float('inf'))}
        if not retired:return ownership
        return dict(ownership,joint_pairs=[pair for pair in ownership['joint_pairs'] if frozenset(pair) not in retired])

    def report(self,occupied,layers,clip,phase,*,pose=None):
        released_items=[r['item'] for r in self.declarations if r['clip']==clip and
                phase>=self.release_at(clip)[r['item']] and r['item'] in self.exact]
        held_items=[n for n in self.held_exact if phase<self.release_at(clip).get(n,float('inf'))]
        active=released_items+held_items
        if not active:return super().report(occupied,layers,clip,phase)
        if len(active)!=1:raise ValueError('Exactly one rigid held/released source is required')
        item=active[0];pose=pose or self.pose
        held=item in held_items
        labels,groups=components(occupied,8);actual=np.zeros((*occupied.shape,4),np.uint8);other=np.zeros_like(occupied)
        part=self.parts[item];errors=[];released=[];attached=[];masks=[]
        if held:
            if pose is None or not {'bones','parts','kind','view','clip','phase'}<=set(pose):
                errors.append('held source has no independent attachment pose')
            else:
                from rr38_acceptance import chain_errors
                errors+=chain_errors(self.layout,self.motion,dict(samples=[pose]))
        for row,image,_ in sorted(layers,key=lambda r:r[0]['z_index']):
            if self.parts[row['name']].get('logical_part',row['name'])==item:
                if row['name']!=item and image[...,3].any():errors.append('released rigid source has additional painted surfaces')
                mask=image[...,3]>0;actual[mask]=image[mask]
            else:other|=image[...,3]>0
        if pose is None:errors.append('released rigid source has no independent pose')
        else:
            transform=matrix(pose['parts'][item]['transform'])
            rigid=np.allclose(transform[:2,:2].T@transform[:2,:2],np.eye(2),atol=DEFAULTS['matrix_tolerance'],rtol=0)
            source=texture(self.case,self.layout,part,gait=clip=='move',clip=clip)
            from rr42_raster import rigid as source_raster
            from maquette_motion.native_ties import select
            expected=source_raster(source,self.layout,pose,part,with_ties=True)
            chosen,_=select(actual,expected)
            if not rigid or pixels.changed(actual,chosen).any():
                errors.append('released held item '+item+': differs from exact rigid source RGBA')
        item_labels,item_groups=components(actual[...,3]>0,8)
        if not item_groups:errors.append('released rigid source is empty')
        if not errors:
            for label,_ in item_groups:
                component=item_labels==label;body_label=labels[component][0]
                if body_label and np.array_equal(labels==body_label,component) and not (component&other).any():
                    masks.append(component)
                    record=dict(item=item,clip=clip,proof='exact rigid source RGBA and grip attachment' if held else 'exact rigid source RGBA')
                    if held:attached.append(record)
                    else:released.append(dict(record,release_at=self.release_at(clip)[item]))
        if held and self.layout['held_items'][item].get('presentation_grip_part'):
            masks=[];attached=[]
        if len(groups)>self.baseline+len(masks):
            errors.append(f'floating pieces: {len(groups)} components > rest {self.baseline} + released {len(masks)}')
        return dict(errors=errors,components=len(groups),rest_components=self.baseline,released_components=released,held_components=attached,masks=masks)
