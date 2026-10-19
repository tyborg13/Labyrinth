"""CPU diagnostic requested for rr-13 feedback 3; never native GPU evidence.

Pose the authored triangles from the sampled, snapped Bone2D transforms. The
existing rigid quad raster and exact fixed-subpixel edge rule are reused.
"""
from dataclasses import dataclass

import numpy as np
from PIL import Image

from cutout_pipeline.cases import read_json
from maquette_motion import pixels
from maquette_motion.raster import SUBPIXEL_SCALE
from .gates import matrix
from .anatomy import load


@dataclass
class MeshSamples:
    pixels: np.ndarray
    texels: np.ndarray


def sprite_transform(layout, pose, part):
    bone = matrix(pose['bones'][part['bone']]['global'])
    bind = np.asarray(layout['joints'][part['bone']]['position'])
    anchor = np.asarray(part.get('presentation_anchor', part['offset']))
    local = np.eye(3)
    local[:2, 2] = anchor - bind
    final = pixels.snapped(bone @ local)
    local[:2, 2] = np.asarray(part['offset']) - anchor
    return final @ local


def mesh_map(layout, pose, mesh):
    vertices = np.asarray(mesh['vertices'], dtype=float)
    xy = np.zeros_like(vertices)
    for name, weights in mesh['weights'].items():
        bone = matrix(pose['bones'][name]['global'])
        bind = np.asarray(layout['joints'][name]['position'])
        delta = vertices - bind
        posed = np.column_stack((delta[:, 0] * bone[0, 0] + delta[:, 1] * bone[0, 1] + bone[0, 2],
                                 delta[:, 0] * bone[1, 0] + delta[:, 1] * bone[1, 1] + bone[1, 2]))
        xy += np.asarray(weights, dtype=np.float32)[:, None] * posed
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
    return MeshSamples(points[inside], texels[inside])


def mapped(image, mapping):
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
    def __init__(self, case, layout):
        self.case, self.layout = case, layout
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
            if pose['clip'] == 'move' and name in self.layout.get('gait_continuations', {}):
                from .gait_continuations import texture
                if source_overrides is None:
                    source = texture(self.case, self.layout, part, gait=True)
                check = texture(self.case, self.layout, part, gait=True, checks=True)
            if name in self.meshes:
                mapping = mesh_map(self.layout, pose, self.meshes[name])
                maps[name] = mapping
                image, checks = mapped(source, mapping), mapped(check, mapping)
            else:
                transform = sprite_transform(self.layout, pose, part)
                image = pixels.render(source, transform)
                checks = pixels.render(check, transform)
            result.append((part, image, checks))
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
                if mesh.get('vertices') == self.meshes[owner]['vertices']:
                    mapping = maps[owner]
                else:
                    if path not in maps:
                        maps[path] = mesh_map(self.layout, pose, mesh)
                    mapping = maps[path]
                posed = mapped(image, mapping)
            else:
                part = {'bone': record['bone'], 'offset': [0, 0]}
                posed = pixels.render(image, sprite_transform(self.layout, pose, part))
            result.append(posed[..., 3] > 0)
        return result
