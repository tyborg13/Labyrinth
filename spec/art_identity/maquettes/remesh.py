"""Deterministic voxel union and welded isosurface without extra dependencies."""
from itertools import product

import numpy as np

from .geometry import MESH_DEFAULTS, Mesh, welded
from .raster import triangle_samples


def voxel_union(meshes, voxel):
    if not np.isfinite(voxel) or voxel <= 0:
        raise ValueError('smooth parts require an explicit positive voxel size')
    vertices = np.concatenate([mesh.vertices for mesh in meshes])
    origin = np.floor(vertices.min(0) / voxel) * voxel - voxel * 2
    dimensions = np.ceil((vertices.max(0) - origin) / voxel).astype(int) + 3
    if np.prod(dimensions, dtype=np.int64) > MESH_DEFAULTS['remesh_max_cells']:
        raise ValueError('Voxel remesh exceeds remesh_max_cells; increase voxel size')
    nx, ny, nz = dimensions
    occupied = np.zeros((nx, ny, nz), dtype=bool)
    # A tiny fixed ray offset avoids double-counting shared edges/vertices.
    ray_offset = np.array([1.234567e-7, 3.456789e-7, 0])
    for mesh in meshes:
        inside = np.zeros_like(occupied)
        coords = (mesh.vertices - origin) / voxel - ray_offset
        for triangle in coords[mesh.faces]:
            sample = triangle_samples(triangle, nx, ny)
            if sample is None:
                continue
            y, x, bary = sample
            z = np.sum(bary * triangle[:, 2], axis=1)
            inside[x, y] ^= np.arange(nz)[None, :] + 0.5 < z[:, None]
        occupied |= inside
    # Occupancies live at voxel centres. Marching tetrahedra interpolates the
    # binary field at 0.5, avoiding a block-face approximation of the union.
    corners = np.array(list(product((0, 1), repeat=3)))
    tetrahedra = [(0, 1, 3, 7), (0, 3, 2, 7), (0, 2, 6, 7),
                  (0, 6, 4, 7), (0, 4, 5, 7), (0, 5, 1, 7)]
    values = np.stack([occupied[x:nx - 1 + x, y:ny - 1 + y, z:nz - 1 + z] for x, y, z in corners], -1)
    cells = np.argwhere(values.any(-1) & ~values.all(-1))
    triangles = []
    for ids in tetrahedra:
        ids = np.array(ids)
        state = values[tuple(cells.T)][:, ids]
        for bits in range(1, 15):
            pattern = np.array([bool(bits & (1 << i)) for i in range(4)])
            selected = cells[np.all(state == pattern, axis=1)]
            if not len(selected):
                continue
            inner, outer = np.flatnonzero(pattern), np.flatnonzero(~pattern)
            edges = [(i, j) for i in inner for j in outer]
            # K2,2 requires cyclic order around the section quadrilateral.
            if len(edges) == 4:
                edges = [edges[i] for i in (0, 1, 3, 2)]
            ps = np.array([(corners[ids[i]] + corners[ids[j]]) / 2 for i, j in edges])
            for indices in [(0, 1, 2)] + ([(0, 2, 3)] if len(ps) == 4 else []):
                tri = ps[list(indices)].copy()
                outward = corners[ids[outer]].mean(0) - corners[ids[inner]].mean(0)
                if np.dot(np.cross(tri[1] - tri[0], tri[2] - tri[0]), outward) < 0:
                    tri = tri[::-1]
                triangles.append((selected[:, None, :] + tri[None, :, :] + 0.5) * voxel + origin)
    if not triangles:
        raise ValueError('voxel size erased the part')
    triangles = np.concatenate(triangles)
    mesh = welded(Mesh(triangles.reshape(-1, 3), np.arange(triangles.size // 3).reshape(-1, 3)))
    edges = np.unique(np.sort(np.concatenate([mesh.faces[:, [0, 1]], mesh.faces[:, [1, 2]], mesh.faces[:, [2, 0]]]), axis=1), axis=0)
    degree = np.bincount(edges.ravel(), minlength=len(mesh.vertices))
    for _ in range(MESH_DEFAULTS['remesh_relax_steps']):
        total = np.zeros_like(mesh.vertices)
        np.add.at(total, edges[:, 0], mesh.vertices[edges[:, 1]])
        np.add.at(total, edges[:, 1], mesh.vertices[edges[:, 0]])
        weight = MESH_DEFAULTS['remesh_relax_weight']
        mesh.vertices = mesh.vertices * (1 - weight) + total / np.maximum(degree[:, None], 1) * weight
    return mesh
