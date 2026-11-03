"""CPU diagnostic requested for rr-13 feedback 3; never native GPU evidence.

Pose the authored triangles from the sampled, snapped Bone2D transforms. The
existing rigid quad raster and exact fixed-subpixel edge rule are reused.
"""
from dataclasses import dataclass

import numpy as np
from PIL import Image

from cutout_pipeline.cases import read_json
from maquette_motion import pixels
from maquette_motion.raster import SUBPIXEL_SCALE, SUBTEXEL_TIE_EPSILON, QuadSamples
from .gates import matrix
from .anatomy import load


@dataclass
class MeshSamples:
    pixels: np.ndarray
    texels: np.ndarray
    alternatives: tuple = ()
    ties: np.ndarray = None

def mask_mesh(mesh, alpha):
    """Conservative UV bounds for a proof mask, including nearest-UV ties.

    This is only for rendering the mask itself. Production surfaces and
    missing-fill domain transport retain their complete triangle mappings.
    """
    indices=np.asarray(mesh['triangles'],dtype=int)
    uv=np.asarray(mesh['uvs'])[indices]
    low=np.floor(uv.min(axis=1)).astype(int)-1
    high=np.ceil(uv.max(axis=1)).astype(int)+1
    height,width=alpha.shape
    low=np.clip(low,[0,0],[width,height]);high=np.clip(high,[0,0],[width,height])
    summed=np.pad(np.asarray(alpha,dtype=np.int64),((1,0),(1,0))).cumsum(0).cumsum(1)
    x0,y0=low.T;x1,y1=high.T
    active=summed[y1,x1]-summed[y0,x1]-summed[y1,x0]+summed[y0,x0]>0
    return dict(mesh,triangles=[row for row,keep in zip(mesh['triangles'],active) if keep])


def presentation_part(layout,pose,part):
    if layout.get('painted_node_transforms') and part['name'] in pose.get('parts',{}):
        return dict(part,z_index=pose['parts'][part['name']].get('z_index',part['z_index']))
    return part


def sprite_transform(layout, pose, part):
    bone = matrix(pose['bones'][part['bone']]['global'])
    bind = np.asarray(layout['joints'][part['bone']]['position'])
    anchor = np.asarray(part.get('presentation_anchor', part['offset']))
    local = np.eye(3)
    local[:2, 2] = anchor - bind
    final = pixels.snapped(bone @ local)
    local[:2, 2] = np.asarray(part['offset']) - anchor
    result=final @ local
    attachment=layout.get('held_items',{}).get(part.get('name'),{})
    if attachment.get('presentation_grip_part') and pose['phase']<attachment.get('presentation_release_at',{}).get(pose['clip'],float('inf')):
        hand=next(p for p in layout['parts'] if p['name']==attachment['presentation_grip_part'])
        grip=np.asarray(attachment['source_grip'])
        target=(sprite_transform(layout,pose,hand)@np.append(grip-hand['offset'],1))[:2]
        result[:2,2]=target-result[:2,:2]@(grip-part['offset'])
    return result


def mesh_map(layout, pose, mesh, with_ties=False, native_skin=False, triangle_batch_size=0):
    # Optional memory bound for folded full-canvas proof masks. Every source
    # triangle and every sample remains in its original draw order; nothing
    # is culled based on paint, so missing-fill reference domains stay strict.
    if triangle_batch_size and len(mesh['triangles'])>triangle_batch_size:
        chunks=[mesh_map(layout,pose,dict(mesh,triangles=mesh['triangles'][start:start+triangle_batch_size]),
            with_ties=with_ties,native_skin=native_skin)
            for start in range(0,len(mesh['triangles']),triangle_batch_size)]
        alternatives=tuple(np.concatenate([chunk.alternatives[index] for chunk in chunks]) for index in range(3)) if with_ties else ()
        return MeshSamples(np.concatenate([chunk.pixels for chunk in chunks]),
            np.concatenate([chunk.texels for chunk in chunks]),alternatives,
            np.concatenate([chunk.ties for chunk in chunks]) if with_ties else None)
    vertices = np.asarray(mesh['vertices'], dtype=float)
    xy = np.zeros_like(vertices)
    for name, weights in mesh['weights'].items():
        bone = cap_source_bone(layout,pose,name) if mesh.get('rigid_source_alignment') else matrix(pose['bones'][name]['global'])
        bind = np.asarray(layout['joints'][name]['position'])
        delta = vertices - bind
        posed = np.column_stack((delta[:, 0] * bone[0, 0] + delta[:, 1] * bone[0, 1] + bone[0, 2],
                                 delta[:, 0] * bone[1, 0] + delta[:, 1] * bone[1, 1] + bone[1, 2]))
        xy += np.asarray(weights, dtype=np.float32)[:, None] * posed
    if layout.get('stable_source_raster'):
        from .stable_paint import vertices as stable_vertices
        xy = stable_vertices(layout,pose,mesh)
    elif native_skin:
        from .native_mesh import vertices as native_vertices
        xy = native_vertices(layout,pose,mesh)
    xy += pixels.PROOF_DEFAULTS['source_offset']
    fixed = np.floor(xy * SUBPIXEL_SCALE + .5).astype(np.int64)
    indices = np.asarray(mesh['triangles'])
    triangle = fixed[indices].copy()
    uv = np.asarray(mesh['uvs'])[indices].copy()
    def cross(a, b):
        return a[..., 0] * b[..., 1] - a[..., 1] * b[..., 0]
    area = cross(triangle[:, 1] - triangle[:, 0], triangle[:, 2] - triangle[:, 0])
    reverse = area < 0
    triangle[reverse] = triangle[reverse][:, [0, 2, 1]]
    uv[reverse] = uv[reverse][:, [0, 2, 1]]
    area = np.abs(area)
    low = np.floor_divide(triangle.min(axis=1), SUBPIXEL_SCALE)
    high = -np.floor_divide(-triangle.max(axis=1), SUBPIXEL_SCALE)
    width, height = np.max(high - low, axis=0)
    dy, dx = np.mgrid[:height, :width]
    points = low[:, None, :] + np.column_stack((dx.ravel(), dy.ravel()))[None, :, :]
    centres = points * SUBPIXEL_SCALE + SUBPIXEL_SCALE // 2
    inside = np.broadcast_to((area > 0)[:, None], points.shape[:2]).copy()
    for index in range(3):
        start = triangle[:, index]
        delta = triangle[:, (index + 1) % 3] - start
        edge = cross(delta[:, None], centres - start[:, None])
        top_left = (delta[:, 1] < 0) | ((delta[:, 1] == 0) & (delta[:, 0] > 0))
        inside &= (edge > 0) | ((edge == 0) & top_left[:, None])
    safe_area = np.maximum(area, 1)[:, None]
    b = cross(centres - triangle[:, 0, None], (triangle[:, 2] - triangle[:, 0])[:, None]) / safe_area
    c = cross((triangle[:, 1] - triangle[:, 0])[:, None], centres - triangle[:, 0, None]) / safe_area
    texture = uv[:, 0, None] + b[..., None] * (uv[:, 1] - uv[:, 0])[:, None] + c[..., None] * (uv[:, 2] - uv[:, 0])[:, None]
    texels = np.rint(texture.astype(np.float32) - .5).astype(int)
    size = pixels.PROOF_DEFAULTS['canvas_size']
    inside &= (points[..., 0] >= 0) & (points[..., 0] < size) & (points[..., 1] >= 0) & (points[..., 1] < size)
    # Retain every triangle fragment in draw order. A transparent texel from
    # a later, folded triangle must not erase an earlier opaque fragment.
    if not with_ties: return MeshSamples(points[inside], texels[inside])
    # The same real-source, independent-axis UV candidates as nearest_quad.
    # This is opt-in: the deterministic CPU diagnostic is unchanged.
    raw = texture[inside]
    integer = np.rint(raw).astype(int)
    ties = np.abs(raw-integer) <= SUBTEXEL_TIE_EPSILON
    default = texels[inside]
    other = np.where(ties, np.where(default == integer-1, integer, integer-1), default)
    return MeshSamples(points[inside], default,
        (np.column_stack((other[:,0], default[:,1])),
         np.column_stack((default[:,0], other[:,1])), other), ties)


def cap_source_bone(layout,pose,name):
    replaced={m['replaces_part'] for m in layout.get('joint_meshes',[])}
    part=next((p for p in layout['parts'] if p['name']==p['bone']==name and name not in replaced),None)
    if part is None:return matrix(pose['bones'][name]['global'])
    if name in pose.get('cap_bones',{}):return matrix(pose['cap_bones'][name])
    attachment=layout.get('held_items',{}).get(name,{})
    if attachment.get('cap_release_parent') and pose['phase']>=attachment.get('presentation_release_at',{}).get(pose['clip'],float('inf')):
        part=next(p for p in layout['parts'] if p['name']==attachment['cap_release_parent'])
    source=part['name']
    final=(matrix(pose['parts'][source]['transform']) if source in pose.get('parts',{}) else sprite_transform(layout,pose,part))
    result=final.copy();result[:2,2]+=result[:2,:2]@(np.asarray(layout['joints'][name]['position'])-part['offset'])
    return result


def mapped(image, mapping, with_ties=False):
    if with_ties:
        height, width = image.shape[:2]
        limits = np.array([width-1,height-1])
        default = np.where(mapping.ties, np.clip(mapping.texels,0,limits), mapping.texels)
        def surface(texels):
            # A texture edge has one real neighbour, never invented air.
            valid = (texels>=0) & (texels<=limits)
            texels = np.where(valid,texels,default)
            return mapped(image,MeshSamples(mapping.pixels,texels))
        variants = [surface(default)] + [surface(t) for t in mapping.alternatives]
        tie_mask = np.zeros(variants[0].shape[:2],bool)
        valid = np.all((default>=0)&(default<=limits),axis=-1) & mapping.ties.any(axis=-1)
        x,y = mapping.pixels[valid].T
        tie_mask[y,x] = True
        return QuadSamples(variants[0],variants[3],variants[1],variants[2],tie_mask)
    height, width = image.shape[:2]
    u, v = mapping.texels.T
    valid = (u >= 0) & (v >= 0) & (u < width) & (v < height)
    samples = image[v[valid], u[valid]]
    if np.any((samples[:, 3] != 0) & (samples[:, 3] != 255)):
        raise ValueError('CPU diagnostic expects the existing binary-alpha cutout textures')
    occupied = samples[:, 3] > 0
    x, y = mapping.pixels[valid][occupied].T
    result = np.zeros((pixels.PROOF_DEFAULTS['canvas_size'],) * 2 + (4,), dtype=np.uint8)
    result[y, x] = samples[occupied]
    return result


class CpuPose:
    def __init__(self, case, layout, *, triangle_batch_size=0, native_skin=False):
        self.case, self.layout = case, layout
        self.triangle_batch_size = triangle_batch_size
        self.native_skin = native_skin
        self.images = {}
        self.templates = {}
        ownership = load(case)['ownership']
        for part in layout['parts']:
            part['proof_ownership'] = ownership
        self.meshes = {m['name']: m for m in layout['joint_meshes']}

    def image(self, path):
        if path not in self.images:
            with Image.open(self.case / path) as image:
                self.images[path] = np.asarray(image.convert('RGBA')).copy()
        return self.images[path]

    def layers(self, pose, source_overrides=None):
        maps, result = {}, []
        for part in self.layout['parts']:
            name = part['name']
            source = self.image(part['file']) if source_overrides is None else source_overrides[name]
            check = self.image(self.layout['proof_layers'][name]['mask'])
            from .gait_continuations import active_recipe
            if active_recipe(self.layout, name, gait=pose['clip'] == 'move', clip=pose['clip']) is not None:
                from .gait_continuations import texture
                if source_overrides is None:
                    source = texture(self.case, self.layout, part, gait=pose['clip'] == 'move', clip=pose['clip'])
                check = texture(self.case, self.layout, part, gait=pose['clip'] == 'move', clip=pose['clip'], checks=True)
            if name in self.meshes:
                mapping = mesh_map(self.layout, pose, self.meshes[name],triangle_batch_size=self.triangle_batch_size,native_skin=self.native_skin)
                maps[name] = mapping
                image, checks = mapped(source, mapping), mapped(check, mapping)
            else:
                # Opt-in native ground truth: retain the complete recorded
                # painted-node transform. Re-snapping it from Bone2D changes
                # half-step origins. Independent bone/grip gates remain the
                # oracle for whether the recorded node pose is attached.
                transform = (matrix(pose['parts'][name]['transform']) if self.layout.get('painted_node_transforms') else
                             sprite_transform(self.layout, pose, part))
                if self.layout.get("stable_source_raster"): transform=transform.astype(np.float32).astype(np.float64)
                image = pixels.render(source, transform)
                checks = pixels.render(check, transform)
            result.append((presentation_part(self.layout,pose,part), image, checks))
        return result, maps

    def masks(self, pose, records, maps):
        result = []
        for record in records:
            image = self.image(record['file'])
            if 'mesh_template' in record:
                path = record['mesh_template']
                if path not in self.templates:
                    self.templates[path] = read_json(self.case / path)
                mesh = self.templates[path]
                owner = record['owner']
                if self.layout.get('stable_source_raster'):
                    part=next(p for p in self.layout['parts'] if p['name']==owner)
                    mesh=dict(mesh,logical_part=part['logical_part'],name=owner)
                if mesh.get('vertices') == self.meshes[owner]['vertices']:
                    mapping = maps[owner]
                else:
                    # Full-canvas joint references are mostly transparent.
                    # A template may serve several masks: use their union,
                    # and key the cache by that exact reference inventory.
                    references=tuple(sorted(r['file'] for r in records if r.get('mesh_template')==path))
                    key=(path,references) if self.triangle_batch_size else path
                    if key not in maps:
                        selected=mesh
                        if self.triangle_batch_size:
                            alpha=np.logical_or.reduce([self.image(file)[...,3]>0 for file in references])
                            selected=mask_mesh(mesh,alpha)
                        maps[key]=(MeshSamples(np.empty((0,2),dtype=int),np.empty((0,2),dtype=int))
                            if self.triangle_batch_size and not selected['triangles'] else
                            mesh_map(self.layout,pose,selected,triangle_batch_size=self.triangle_batch_size,native_skin=self.native_skin))
                    mapping = maps[key]
                posed = mapped(image, mapping)
            else:
                owner=next((p for p in self.layout['parts'] if p['name']==record.get('owner')),None)
                if self.layout.get('painted_reference_space') and owner is not None and owner['name'] in pose.get('parts',{}):
                    transform=matrix(pose['parts'][owner['name']]['transform']).copy()
                    transform[:2,2]-=transform[:2,:2]@np.asarray(owner['offset'])
                    posed=pixels.render(image,transform)
                else:
                    part = {'bone': record['bone'], 'offset': [0, 0]}
                    if record.get('match_presentation_anchor', False):
                        part['presentation_anchor'] = record['presentation_anchor']
                    posed = pixels.render(image, sprite_transform(self.layout, pose, part))
            result.append(posed[..., 3] > 0)
        return result
