"""Figure-agnostic uncovered-surface diagnostics (optional, additive)."""
import numpy as np
from .cpu_pose import mesh_map, mapped, sprite_transform
from .native_defects import packed
from maquette_motion import pixels
from maquette_motion.features import source_pixels
from maquette_motion.material_palette import outline_class
from maquette_motion.silhouette import components, dilate

class UncoveredSurface:
    """Optional gate; callers supply figure-owned masks and donor certificates.

    No creature identities, source dimensions, material boundaries or exceptions
    live here. Required paint and the vacated occluder footprint are separate:
    missing paint is measured only where required; colour/ink/island checks span
    the full footprint, including approved air outside receiving mesh support.
    """
    def __init__(self, model, *, owners, occluders, domains, part_palettes,
                 palettes, definition, forbidden=None, painted=None,
                 reference_bones=(), max_component_px=3, rest_epsilon=.0001,
                 visible_occluders_only=False):
        self.model = model
        self.parts = {p['name']: p for p in model.layout['parts']}
        self.owners, self.occluders, self.domains = owners, tuple(occluders), domains
        self.footprint = np.isin(owners, self.occluders)
        self.part_palettes, self.palettes = part_palettes, palettes
        self.definition = definition
        self.forbidden, self.painted = forbidden or {}, painted or {}
        self.reference_bones = reference_bones
        self.max_component_px, self.rest_epsilon = max_component_px, rest_epsilon
        self.visible_occluders_only = visible_occluders_only
        self.mapping_cache, self.support_cache = {}, {}
        self.bad_source = {}
        for name, part in self.parts.items():
            image = source_pixels(model.case, part)
            if part.get('hidden_material'):
                bad = (image[...,3]>0) & ~np.isin(packed(image), self.part_palettes[name])
            else:
                logical = part['logical_part']
                bad = (image[...,3]>0) & self.footprint & (self.owners != logical)
                if logical in self.occluders:
                    bad |= (image[...,3]>0) & (self.owners != logical)
            self.bad_source[name] = bad

    def vacated(self, pose, moving):
        source = np.zeros((*self.owners.shape, 4), np.uint8)
        source[self.footprint] = 255
        result = np.zeros(moving.shape, bool)
        # A full source-space reference never inherits a fill's crop, alpha,
        # mesh triangle culling or donor support.
        for bone in self.reference_bones:
            reference = {'bone': bone, 'offset': [0, 0]}
            result |= pixels.render(source, sprite_transform(self.model.layout, pose, reference))[...,3] > 0
        return result & ~moving

    def transport(self, name, mask, pose):
        part = self.parts[name]
        x0,y0,x1,y1 = part['bbox']
        source = np.zeros((y1-y0,x1-x0,4), np.uint8)
        source[mask[y0:y1,x0:x1]] = 255
        if name in self.model.meshes:
            if name not in self.mapping_cache:
                mesh=self.model.meshes[name]
                if not mesh['triangles']:return np.zeros((pixels.PROOF_DEFAULTS['canvas_size'],)*2,bool)
                self.mapping_cache[name]=mesh_map(self.model.layout,pose,mesh)
            return mapped(source,self.mapping_cache[name])[...,3]>0
        from .gates import matrix
        transform=(matrix(pose['parts'][name]['transform']) if self.model.layout.get('painted_node_transforms') else
                   sprite_transform(self.model.layout, pose, part))
        return pixels.render(source,transform)[...,3]>0

    def moved(self, pose):
        # Relative rest transforms, not clip/frame exceptions. A planted arm
        # beside a bobbing torso also uncovers its source footprint.
        from .gates import matrix
        for name,row in pose['bones'].items():
            bone = matrix(row['global'])
            rest = np.eye(3);rest[:2,2] = self.model.layout['joints'][name]['position']
            if not np.allclose(bone,rest,atol=self.rest_epsilon,rtol=0): return True
        return False

    def measure(self, pose, layers, maps=None):
        self.mapping_cache={} if maps is None else dict(maps)
        metrics = dict(uncovered_missing_pixels=0, uncovered_foreign_texels=0,
                       uncovered_outline_pixels=0, uncovered_tiny_components=0,
                       uncovered_outside_surface_pixels=0)
        self.last_masks = {}
        if not self.moved(pose): return metrics
        size = layers[0][1].shape[:2]
        visible = np.full(size, '', dtype=object)
        composite = np.zeros((*size,4),np.uint8)
        moving = np.zeros(size,bool)
        for part, image, _ in sorted(layers,key=lambda r:r[0]['z_index']):
            alpha = image[...,3]>0
            visible[alpha] = part['name'];composite[alpha] = image[alpha]
            if part['logical_part'] in self.occluders and not (
                    self.visible_occluders_only and part.get('hidden_material')):
                moving |= alpha
        occupied = composite[...,3]>0
        colours=packed(composite)
        area = np.zeros(size,bool)
        for logical, required in self.domains.items():
            name = next(n for n in ('covered_'+logical,'hidden_'+logical,logical) if n in self.parts)
            area |= self.transport(name, required, pose)
        area &= ~moving
        # Case-wide exposed underlaps, including gait/clip continuations: a
        # current visible texel whose rest coordinate belonged to another
        # piece has just uncovered that surface. Independent required domains
        # above additionally catch missing paint, including tears open to air.
        rest_painted=self.owners!=''
        for name,part in self.parts.items():
            exposed=visible==name
            if not exposed.any():continue
            underlap=rest_painted & (self.owners!=part['logical_part'])
            if underlap.any():area |= exposed & self.transport(name,underlap,pose)
        # Approved paint travelling with its own moving piece is the third
        # allowed category. This also resolves shared nearest-UV edge choices
        # where a transported mask overlaps the neighbouring painted texel.
        original_visible = np.zeros(size, bool)
        for name,part in self.parts.items():
            if part.get('hidden_material'):continue
            exposed=(visible==name)
            if exposed.any():
                original=self.transport(name,self.owners==part['logical_part'],pose)
                original_visible |= exposed & original
                area &= ~(exposed & original)
        required_area = area.copy()
        vacated = self.vacated(pose, moving)
        area |= vacated & ~original_visible
        metrics['uncovered_missing_pixels'] = int((required_area & ~occupied).sum())
        foreign = np.zeros(size,bool)
        for name, bad in self.bad_source.items():
            if not bad.any(): continue
            exposed = (visible==name)
            if self.parts[name].get('hidden_material'): exposed &= area
            if exposed.any(): foreign |= self.transport(name,bad,pose) & exposed
        # Verify actual native colours too: an isolated native layer cannot
        # earn provenance just because its source mask is nominally clean.
        for name, part in self.parts.items():
            exposed = (visible==name) & (area | vacated)
            if not exposed.any(): continue
            palette = np.union1d(self.part_palettes[name],self.palettes[part['logical_part']])
            foreign |= exposed & ~np.isin(colours,palette)
        metrics['uncovered_foreign_texels'] = int(foreign.sum())
        outside=np.zeros(size,bool)
        for name,mask in self.forbidden.items():
            exposed=visible==name
            if exposed.any():
                from humanoid_cutout.gait_continuations import texture
                part=self.parts[name];x0,y0,x1,y1=part['bbox']
                key=(name,pose['clip'])
                if key not in self.support_cache:self.support_cache[key]=texture(self.model.case,self.model.layout,part,clip=pose['clip'],gait=pose['clip']=='move')
                painted=np.zeros(self.owners.shape,bool);painted[y0:y1,x0:x1]=self.support_cache[key][...,3]>0
                illegal=mask & painted
                if illegal.any():outside |= exposed & self.transport(name,illegal,pose)
        metrics['uncovered_outside_surface_pixels']=int(outside.sum())
        background, _ = components(~occupied,4)
        outer = dilate(background==background[0,0],1) & occupied
        approved_ink = np.zeros(size, bool)
        for name, mask in self.painted.items():
            if mask.any():
                original = source_pixels(self.model.case, self.parts[name])
                ink = mask & outline_class(original, self.definition)
                approved_ink |= (visible == name) & self.transport(name, ink, pose)
        outline=area & occupied & outline_class(composite,self.definition) & ~outer & ~approved_ink
        metrics['uncovered_outline_pixels'] = int(outline.sum())
        self.last_masks={'area':area,'missing':required_area & ~occupied,'foreign':foreign,'outline':outline,'outside':outside}
        labels, groups = components(occupied,8)
        # Tiny components must also be checked over approved air and original
        # source paint in the full footprint, independent of fill support.
        component_area = area | vacated
        metrics['uncovered_tiny_components'] = sum(1 for label,n in groups if n<=self.max_component_px and (component_area & (labels==label)).any())
        return metrics

    def diagnostics(self):
        result={}
        for name,mask in self.last_masks.items():
            if name=='area' or not mask.any():continue
            y,x=np.nonzero(mask)
            result[name]={'pixels':int(mask.sum()),'bbox':[int(x.min()),int(y.min()),int(x.max())+1,int(y.max())+1]}
        return result

