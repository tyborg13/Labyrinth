"""Independent all-footprint painted exposure gate, including UV rounding.

Certification is exact registered director RGBA, never palette membership or a
procedural donor. Each label uses the same fragment order as its RGBA so an
opaque procedural fragment cannot borrow certification from one beneath it.
"""
import numpy as np
from maquette_motion import pixels
from maquette_motion.features import source_pixels
from humanoid_cutout.cpu_pose import mapped, mesh_map, sprite_transform,presentation_part
from humanoid_cutout.gait_continuations import texture
from rr42_underlay import inputs, certificates, FOOTPRINTS
from rr42_raster import pose_families,rigid


class PaintedExposure:
    def __init__(self, model, *, supplied=None, footprint_parts=None, packed_footprints=False):
        self.model=model
        self.paint,self.footprints,self.required = supplied if supplied is not None else (*inputs(), certificates())
        self.footprint_parts = FOOTPRINTS if footprint_parts is None else footprint_parts
        self.packed_footprints=packed_footprints
        self.label_policy=None
        self.required_policy=None
        if packed_footprints:
            from rr44_footprint_bits import encode
            self.footprint_bits=encode(self.footprints)
        self.sources={}; self.labels={}
        for part in model.layout['parts']:
            source=source_pixels(model.case,part); name=part['name']
            approved=source[...,3]>0
            if part.get('hidden_material'):
                certificate=self.required.get(name,np.zeros(self.paint.shape[:2],bool))
                approved &= certificate & np.all(source==self.paint,axis=-1)
            x,y,x1,y1=part['bbox']; self.sources[name]=source[y:y1,x:x1]
            self.labels[name]=approved[y:y1,x:x1]

    def measure(self, pose, *, all_rounding=True, collect_texels=False):
        invalid=[];missing=[];rows=[];texels=set()
        for context in pose_families(pose):
            self._measure(context,all_rounding=all_rounding,collect_texels=collect_texels)
            invalid.append(self.last_invalid);missing.append(self.last_missing)
            rows+=self.last_rows;texels.update(self.last_texels)
        self.last_invalid=np.logical_or.reduce(invalid);self.last_missing=np.logical_or.reduce(missing)
        self.last_rows=rows;self.last_texels=texels
        return {'uncovered_procedural_texels':int(self.last_invalid.sum()),'painted_missing_texels':int(self.last_missing.sum())}

    def _measure(self, pose, *, all_rounding=True, collect_texels=False):
        shape=(pixels.PROOF_DEFAULTS['canvas_size'],)*2
        failures=np.zeros(shape,bool); missing=np.zeros(shape,bool)
        self.last_rows=[]
        self.last_texels=set()
        families=(True,False) if all_rounding else (True,)
        def choices(result):
            return result.candidates if all_rounding else (result,)
        # Independent references never inherit a receiving crop or paint alpha.
        areas={}
        for footprint,mask in ({} if self.packed_footprints else self.footprints).items():
            reference=np.zeros((255,255,4),np.uint8); reference[mask]=255
            area=np.zeros(shape,bool)
            for bone in ('root','torso','pelvis'):
                transform=sprite_transform(self.model.layout,pose,{'bone':bone,'offset':[0,0]})
                area |= np.logical_or.reduce([im[...,3]>0 for im in choices(pixels.render(reference,transform,with_ties=all_rounding))])
            areas[footprint]=area
        if self.packed_footprints:
            from rr44_footprint_bits import decode
            frames=[]
            for bone in ('root','torso','pelvis'):
                transform=sprite_transform(self.model.layout,pose,{'bone':bone,'offset':[0,0]})
                frames.extend(choices(pixels.render(self.footprint_bits,transform,with_ties=all_rounding)))
            areas=decode(frames,self.footprints)
        for native_skin in families:
            rendered=[]
            unfilled={}
            for part in self.model.layout['parts']:
                name=part['name']; source=texture(self.model.case,self.model.layout,part,gait=pose['clip']=='move',clip=pose['clip'])
                if (self.packed_footprints and not source[...,3].any() and
                    not self.required.get(name,np.zeros((1,1),bool)).any()):continue
                certified=self.labels[name]
                if self.label_policy is not None:certified=certified | self.label_policy(pose,part,source)
                label=np.zeros_like(source); label[...,3]=source[...,3]; label[certified,0]=255
                if name in self.model.meshes:
                    mapping=mesh_map(self.model.layout,pose,self.model.meshes[name],with_ties=all_rounding,native_skin=native_skin,triangle_batch_size=128)
                    render=lambda image: mapped(image,mapping,with_ties=all_rounding)
                else:
                    render=lambda image: rigid(image,self.model.layout,pose,part,with_ties=all_rounding)
                rgba,labels=choices(render(source)),choices(render(label))
                x,y,x1,y1=part['bbox']
                local_areas={}
                for footprint,mask in ({} if self.packed_footprints else self.footprints).items():
                    reference=np.zeros_like(source); reference[mask[y:y1,x:x1]]=255
                    local_areas[footprint]=np.logical_or.reduce([im[...,3]>0 for im in choices(render(reference))])
                if self.packed_footprints:
                    from rr44_footprint_bits import transport
                    reference=self.footprint_bits[y:y1,x:x1]
                    local_areas=(transport(reference,mapping,self.footprints,all_rounding) if name in self.model.meshes else
                                 decode(choices(render(reference)),self.footprints))
                wanted=self.required.get(name,np.zeros((255,255),bool))
                if self.required_policy is not None:wanted=wanted | self.required_policy(pose,part)
                if part.get('hidden_material') and (name in self.required or wanted.any()):
                    reference=np.zeros_like(source); reference[wanted[y:y1,x:x1]]=255
                    # A requirement and its own layer alpha share a UV choice.
                    # Mixing requirement A with alpha B invents a hole even
                    # when the supplied paint is present in every real choice.
                    required=choices(render(reference))
                    unfilled[name]=np.logical_or.reduce([(want[...,3]>0)&(actual[...,3]==0)
                                                        for want,actual in zip(required,rgba)])
                uv_choices=None
                if collect_texels and part.get('hidden_material'):
                    yy,xx=np.indices(source.shape[:2]);uv=np.zeros_like(source)
                    uv[...,0]=xx+1;uv[...,1]=yy+1;uv[...,3]=source[...,3]
                    uv_choices=choices(render(uv))
                rendered.append((presentation_part(self.model.layout,pose,part),rgba,labels,local_areas,uv_choices))
            moving={key:np.zeros(shape,bool) for key in self.footprint_parts}
            always_by_name={}
            occupied_count=np.zeros(shape,np.uint16)
            for part,frames,_,_,_ in rendered:
                always=np.logical_and.reduce([im[...,3]>0 for im in frames])
                always_by_name[part['name']]=always;occupied_count+=always
                for key,occluders in self.footprint_parts.items():
                    if part['logical_part'] in occluders: moving[key] |= always
            for name,unfilled_choices in unfilled.items():
                # Every other layer can choose its rounding independently.
                # Only coverage present in all of that layer's choices can
                # guarantee that a missing required texel stays occluded.
                other_coverage=occupied_count>always_by_name[name].astype(np.uint16)
                missing |= unfilled_choices & ~other_coverage
            always_above=np.zeros(shape,bool)
            for part,images,labels,local_areas,uv_choices in sorted(rendered,key=lambda r:r[0]['z_index'],reverse=True):
                for choice,(actual,label) in enumerate(zip(images,labels)):
                    exposed=(actual[...,3]>0)&~always_above
                    for key,occluders in self.footprint_parts.items():
                        if part['logical_part'] not in occluders:
                            bad=exposed & (areas[key]|local_areas[key]) & ~moving[key] & (label[...,0]==0)
                            failures |= bad
                            if bad.any():
                                yy,xx=np.nonzero(bad)
                                if uv_choices is not None:
                                    uv=uv_choices[choice][yy,xx]
                                    valid=uv[...,3]>0
                                    ox,oy=part['offset']
                                    self.last_texels.update((part['name'],int(u)-1+ox,int(v)-1+oy) for u,v in uv[valid,:2])
                                self.last_rows.append({'part':part['name'],'packed_skin':native_skin,'footprint':key,
                                    'pixels':int(bad.sum()),'bbox':[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)]})
                always_above |= np.logical_and.reduce([im[...,3]>0 for im in images])
        self.last_invalid=failures; self.last_missing=missing
        return {'uncovered_procedural_texels':int(failures.sum()),'painted_missing_texels':int(missing.sum())}
