"""Lancer-only all-frame proof: vacated leg pixels require actual painting."""
import numpy as np
from maquette_motion import pixels
from maquette_motion.features import source_pixels
from humanoid_cutout.cpu_pose import mapped, mesh_map, sprite_transform
from humanoid_cutout.gait_continuations import texture
from rr41_underlay import inputs, paint_mask, painted_domains, EXPOSURE_REPAIRS
from cutout_pipeline.cases import digest
from rr41_native_samples import rigid_transform

LEGS = ('leg_near', 'foot_near', 'leg_far', 'foot_far')
METRIC = 'uncovered_procedural_leg_texels'


class NativeMasks:
    """Use the same exact native RGBA/UV choice for paint and boolean masks.

    No match falls back to the independent geometric mask. A required mask
    containing missing source paint also falls back, so clearing paint cannot
    certify its own disappearance. Only the existing four nearest-UV choices
    and the existing registered/packed weight families are considered, with
    source RGBA and masks always from the same family. There is no error budget.
    """
    def __init__(self, gate, pose, layers):
        self.gate,self.pose=gate,pose
        self.actual={p['name']:image for p,image,_ in layers}
        self.cache={}

    def transport(self, name, mask):
        part=self.gate.parts[name];model=self.gate.model;pose=self.pose
        x0,y0,x1,y1=part['bbox'];local=mask[y0:y1,x0:x1]
        source=texture(model.case,model.layout,part,gait=pose['clip']=='move',clip=pose['clip'])
        if np.any(local & (source[...,3]==0)): return None
        if name not in self.cache:
            if name in model.meshes:
                renderers=[]
                for packed in (True,False):
                    mapping=mesh_map(model.layout,pose,model.meshes[name],with_ties=True,native_skin=packed)
                    renderers.append(lambda image,mapping=mapping:mapped(image,mapping,with_ties=True).candidates)
            else:
                transform=rigid_transform(model.layout,pose,part)
                renderers=[lambda image:pixels.render(image,transform,with_ties=True).candidates]
            actual=self.actual[name];occupied=actual[...,3]>0
            yy,xx=np.indices(source.shape[:2])
            uv=np.stack((xx+1,yy+1,np.zeros_like(xx),source[...,3]),axis=-1).astype(np.uint8)
            opaque=uv.copy();opaque[...,3]=255
            choices=[]
            for render in renderers:
                family=[]
                for image,painted_uv,empty_uv in zip(render(source),render(uv),render(opaque)):
                    match=(image[...,3]==actual[...,3]) & (~occupied | np.all(image==actual,axis=-1))
                    coords=np.where(occupied[...,None],painted_uv,empty_uv)
                    family.append((match,coords))
                choices += family
                # Prefer the known packed format when it explains the entire
                # isolated layer. The registered reference is only needed for
                # samples not explained by that native family.
                if np.logical_or.reduce([match for match,_ in family]).all(): break
            self.cache[name]=choices
        shape=self.actual[name].shape[:2]
        result=np.zeros(shape,bool);matched=np.zeros(shape,bool)
        for match,coords in self.cache[name]:
            valid=match & (coords[...,3]>0)
            y,x=np.nonzero(valid)
            u,v=(coords[y,x,:2].astype(int)-1).T
            result[y,x] |= local[v,u]
            matched |= match
        # Outside exact matches the caller retains its independent mask.
        return result,matched


class LegPaint:
    def __init__(self, gate):
        self.gate = gate
        bound = gate.case/'rr41_exposure_repairs.json'
        if not bound.exists() or digest(bound) != digest(EXPOSURE_REPAIRS):
            raise ValueError('Stale/missing bound rr-41 exposure repair certificate')
        _, self.footprint = inputs()
        self.reference = np.zeros((*self.footprint.shape, 4), np.uint8)
        self.reference[self.footprint] = 255
        self.required = painted_domains()
        self.sources = {}
        self.approved = {}
        self.clip_labels = {}
        for name, part in gate.parts.items():
            image = source_pixels(gate.model.case, part)
            # No palette membership or procedural donor may certify paint.
            # Hidden surfaces must match a protected director texel exactly.
            approved = paint_mask(gate.model.case, gate.model.layout, part) if part.get('hidden_material') else image[..., 3] > 0
            self.approved[name] = approved
            image[~approved] = 0
            x0, y0, x1, y1 = part['bbox']
            self.sources[name] = image[y0:y1, x0:x1]

    def vacated(self, pose, layers):
        """Independent rest/posed footprint; no receiving crop or alpha owns it."""
        moving = np.zeros(layers[0][1].shape[:2], bool)
        for part, image, _ in layers:
            if part['logical_part'] in LEGS: moving |= image[..., 3] > 0
        region = moving.copy()
        # Root carries the rest footprint; torso carries its posed/folded
        # counterpart. Include both before excluding the complete posed legs.
        for bone in ('root', 'torso'):
            transform = sprite_transform(self.gate.model.layout, pose, {'bone':bone, 'offset':[0, 0]})
            region |= pixels.render(self.reference, transform)[..., 3] > 0
        return region & ~moving

    def measure(self, pose, layers):
        gate = self.gate
        size = layers[0][1].shape[:2]
        invalid = np.zeros(size, bool)
        self.last_painted = np.zeros(size, bool)
        moving = np.zeros(size, bool)
        visible = np.full(size, '', object)
        for part, image, _ in sorted(layers, key=lambda r:r[0]['z_index']):
            alpha = image[..., 3] > 0
            visible[alpha] = part['name']
            # A leg's existing joint tucks travel with that leg. The vacated
            # footprint excludes the complete posed leg, as the arm gate does.
            if part['logical_part'] in LEGS:
                moving |= alpha
        independent = self.vacated(pose, layers)
        self.last_vacated = independent
        for part, actual, _ in layers:
            name = part['name']
            exposed = (visible == name) & ~moving
            if not exposed.any(): continue
            exposed &= independent | gate.transport(name, self.footprint, pose)
            if not exposed.any(): continue
            if gate.native_masks is not None:
                painted,matched=gate.native_masks.transport(name,self.approved[name])
                bad=exposed & ~(painted & matched)
            else:
                key=(name,pose['clip'])
                if key not in self.clip_labels:
                    source=texture(gate.model.case,gate.model.layout,part,gait=pose['clip']=='move',clip=pose['clip'])
                    label=np.zeros_like(source);label[...,3]=source[...,3]
                    x0,y0,x1,y1=part['bbox']
                    label[self.approved[name][y0:y1,x0:x1],0]=255
                    self.clip_labels[key]=label
                if name in gate.model.meshes:
                    expected=mapped(self.sources[name],gate.mapping_cache[name])
                    labelled=mapped(self.clip_labels[key],gate.mapping_cache[name])
                else:
                    transform=sprite_transform(gate.model.layout,pose,part)
                    expected=pixels.render(self.sources[name],transform)
                    labelled=pixels.render(self.clip_labels[key],transform)
                # Label alpha follows all source fragments, so an occluded
                # painted fragment cannot certify a later procedural one.
                bad=exposed & ((labelled[...,0]==0) | np.any(actual!=expected,axis=-1))
            invalid |= bad
            self.last_painted |= exposed & ~bad
        return invalid

    def missing(self, pose, layers):
        occupied = np.zeros(layers[0][1].shape[:2], bool)
        for _, image, _ in layers: occupied |= image[..., 3] > 0
        required = np.zeros(occupied.shape, bool)
        for name, mask in self.required.items():
            if mask.any(): required |= self.gate.transport('hidden_'+name, mask, pose)
        return required & ~occupied
