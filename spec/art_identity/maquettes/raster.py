"""Pixel-centre orthographic triangle rasterisation; NumPy only.

Depth increases toward the camera. Masks include both visible ownership and
unoccluded solos, so tiny/hidden parts are not silently dropped from proof.
"""
from __future__ import annotations

from dataclasses import dataclass
import math

import numpy as np

from .geometry import build_meshes, deform_width


RASTER_DEFAULTS = {"size": 1024, "edge_epsilon": 1e-9, "alpha_threshold": 128}


def camera(spec, view='front'):
    if 'view_transforms' in spec:
        data = spec['view_transforms'][view]
        matrix = np.asarray(data['object_to_world'], dtype=float)
        target = np.asarray(data['target'], dtype=float)
        az, el = math.radians(data['azimuth_deg']), math.radians(data['elevation_deg'])
        scale = data['ortho_scale']
    else:
        yaw = math.radians(spec.get('front_yaw', 0) + (180 if view == 'rear' else 0))
        matrix = np.array([[math.cos(yaw), -math.sin(yaw), 0, 0], [math.sin(yaw), math.cos(yaw), 0, 0],
                           [0, 0, 1, 0], [0, 0, 0, 1]])
        target = np.asarray(spec.get('target', [0, 0, 1.2]), dtype=float)
        az, el, scale = math.pi / 4, math.pi / 6, spec.get('ortho_scale', 3.4)
    if matrix.shape != (4, 4) or not np.isfinite(matrix).all() or not np.isfinite(target).all() or scale <= 0:
        raise ValueError('Invalid orthographic camera')
    right = np.array([-math.sin(az), math.cos(az), 0])
    up = np.array([-math.sin(el) * math.cos(az), -math.sin(el) * math.sin(az), math.cos(el)])
    toward = np.cross(right, up)
    return matrix, target, np.array([right, up, toward]), scale


def project(spec, points, view='front', size=1024):
    matrix, target, basis, scale = camera(spec, view)
    points = np.asarray(points, dtype=float)
    world = np.einsum('...i,ji->...j', points, matrix[:3, :3]) + matrix[:3, 3]
    coords = np.einsum('...i,ji->...j', world - target, basis)
    return np.stack([size * (0.5 + coords[..., 0] / scale),
                     size * (0.5 - coords[..., 1] / scale), coords[..., 2]], axis=-1)


def triangle_samples(triangle, width, height):
    """Return (y, x, barycentric weights) for centres inside a 2D triangle."""
    a, b, c = triangle[:, :2]
    lo = np.maximum(np.ceil(np.min(triangle[:, :2], axis=0) - 0.5).astype(int), 0)
    hi = np.minimum(np.floor(np.max(triangle[:, :2], axis=0) - 0.5).astype(int), [width - 1, height - 1])
    if np.any(lo > hi):
        return None
    den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
    if abs(den) < 1e-14:
        return None
    yy, xx = np.mgrid[lo[1]:hi[1] + 1, lo[0]:hi[0] + 1]
    x, y = xx + 0.5, yy + 0.5
    wa = ((b[1] - c[1]) * (x - c[0]) + (c[0] - b[0]) * (y - c[1])) / den
    wb = ((c[1] - a[1]) * (x - c[0]) + (a[0] - c[0]) * (y - c[1])) / den
    wc = 1 - wa - wb
    valid = (wa >= -RASTER_DEFAULTS['edge_epsilon']) & (wb >= -RASTER_DEFAULTS['edge_epsilon']) & (wc >= -RASTER_DEFAULTS['edge_epsilon'])
    return yy[valid], xx[valid], np.stack([wa[valid], wb[valid], wc[valid]], axis=-1)


@dataclass
class Raster:
    names: list
    owners: np.ndarray
    masks: dict
    joints: dict

    @property
    def silhouette(self):
        return self.owners >= 0

    def rgba(self, spec):
        result = np.zeros((*self.owners.shape, 4), dtype=np.uint8)
        for i, part in enumerate(self.names):
            # Workbench material colours are linear RGB; output PNG is sRGB.
            linear = np.asarray(spec['labels'][part])
            rgb = np.where(linear <= 0.0031308, linear * 12.92, 1.055 * linear ** (1 / 2.4) - 0.055)
            result[self.owners == i] = [*np.rint(rgb * 255).astype(np.uint8), 255]
        return result


def rasterise(spec, view='front', size=1024, meshes=None):
    meshes = build_meshes(spec) if meshes is None else meshes
    names = list(meshes)
    owners = np.full((size, size), -1, dtype=np.int16)
    depth = np.full((size, size), -np.inf)
    masks = {}
    for i, (part, mesh) in enumerate(meshes.items()):
        vertices = project(spec, mesh.vertices, view, size)
        mask = np.zeros((size, size), dtype=bool)
        for triangle in vertices[mesh.faces]:
            sample = triangle_samples(triangle, size, size)
            if sample is None:
                continue
            y, x, bary = sample
            z = np.sum(bary * triangle[:, 2], axis=1)
            mask[y, x] = True
            front = z > depth[y, x]
            depth[y[front], x[front]] = z[front]
            owners[y[front], x[front]] = i
        masks[part] = mask
    joints = {name: np.round(project(spec, deform_width(spec, point), view, size)[:2], 2).tolist() for name, point in spec['joints'].items()}
    return Raster(names, owners, masks, joints)
