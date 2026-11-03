"""Exact source-alpha culling for the case's full-canvas proof masks.

This changes diagnostic work only. Runtime meshes/textures stay untouched.
Triangles whose complete UV bounds contain no opaque texel cannot contribute.
The one-texel guard includes all nearest-sampling boundary ties.
"""
import numpy as np
from cutout_pipeline.cases import read_json
from humanoid_cutout.cpu_pose import CpuPose as FullPose, mesh_map, mapped, sprite_transform
from maquette_motion import pixels

CULL_GUARD_TEXELS = 1


def opaque_triangles(mesh, image):
    uv = np.asarray(mesh['uvs'])[np.asarray(mesh['triangles'])]
    lo = np.floor(uv.min(axis=1) - CULL_GUARD_TEXELS).astype(int)
    hi = np.ceil(uv.max(axis=1) + CULL_GUARD_TEXELS + 1).astype(int)
    size = np.array([image.shape[1], image.shape[0]])
    lo, hi = np.clip(lo, 0, size), np.clip(hi, 0, size)
    sums = np.pad((image[..., 3] > 0).astype(int), ((1, 0), (1, 0))).cumsum(0).cumsum(1)
    count = sums[hi[:, 1], hi[:, 0]] - sums[lo[:, 1], hi[:, 0]] - sums[hi[:, 1], lo[:, 0]] + sums[lo[:, 1], lo[:, 0]]
    return dict(mesh, triangles=np.asarray(mesh['triangles'])[count > 0].tolist())


class CpuPose(FullPose):
    def masks(self, pose, records, maps):
        result = []
        for record in records:
            image = self.image(record['file'])
            if 'mesh_template' in record:
                path = record['mesh_template']
                if path not in self.templates:
                    self.templates[path] = opaque_triangles(read_json(self.case / path), image)
                mesh = self.templates[path]
                key = 'culled:' + path
                if key not in maps: maps[key] = mesh_map(self.layout, pose, mesh)
                posed = mapped(image, maps[key])
            else:
                part = {'bone': record['bone'], 'offset': [0, 0]}
                posed = pixels.render(image, sprite_transform(self.layout, pose, part))
            result.append(posed[..., 3] > 0)
        return result
