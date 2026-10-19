"""Same CPU raster, excluding triangles whose source footprint is transparent.

Full-canvas transported hole masks otherwise rasterize thousands of transparent
triangles. Their far-away vertices can span large boxes when an arm folds.
Only the conservative UV support test changes; skinning/raster/ties do not.
"""
import numpy as np
from humanoid_cutout.cpu_pose import CpuPose, mesh_map, mapped, sprite_transform
from humanoid_cutout.gait_continuations import texture
from maquette_motion import pixels
from cutout_pipeline.cases import read_json

CPU_UV_GUARD_PX = 1  # Conservative proof-only support margin; never adds paint.


def supported(mesh, occupied):
    triangles = np.asarray(mesh['triangles'], dtype=int)
    uv = np.asarray(mesh['uvs'])[triangles]
    low = np.floor(uv.min(1) - CPU_UV_GUARD_PX).astype(int)
    high = np.ceil(uv.max(1) + CPU_UV_GUARD_PX).astype(int) + 1
    size = np.array([occupied.shape[1], occupied.shape[0]])
    low, high = np.clip(low, 0, size), np.clip(high, 0, size)
    integral = np.pad(occupied.astype(np.int32), ((1, 0), (1, 0))).cumsum(0).cumsum(1)
    amounts = (integral[high[:, 1], high[:, 0]] - integral[low[:, 1], high[:, 0]] -
               integral[high[:, 1], low[:, 0]] + integral[low[:, 1], low[:, 0]])
    retained = triangles[amounts > 0]
    # An entirely transparent image still maps to transparency. Retaining one
    # triangle keeps the shared raster's nonempty-grid precondition unchanged.
    if not len(retained): retained = triangles[:1]
    return dict(mesh, triangles=retained.tolist())


class CoveragePose(CpuPose):
    def __init__(self, case, layout):
        super().__init__(case, layout)
        self.full_meshes = self.meshes.copy()

    def layers(self, pose, source_overrides=None):
        for part in self.layout['parts']:
            name = part['name']
            if name not in self.full_meshes: continue
            source = self.image(part['file']) if source_overrides is None else source_overrides[name]
            checks = self.image(self.layout['proof_layers'][name]['mask'])
            if name in self.layout.get('gait_continuations', {}):
                if source_overrides is None:
                    source = texture(self.case, self.layout, part, gait=pose['clip'] == 'move', clip=pose['clip'])
                checks = texture(self.case, self.layout, part, gait=pose['clip'] == 'move', clip=pose['clip'], checks=True)
            self.meshes[name] = supported(self.full_meshes[name], (source[..., 3] > 0) | (checks[..., 3] > 0))
        return super().layers(pose, source_overrides)

    def masks(self, pose, records, maps):
        result = []
        for record in records:
            image = self.image(record['file'])
            if 'mesh_template' in record:
                path = record['mesh_template']
                if path not in self.templates: self.templates[path] = read_json(self.case / path)
                mesh = supported(self.templates[path], image[..., 3] > 0)
                posed = mapped(image, mesh_map(self.layout, pose, mesh))
            else:
                posed = pixels.render(image, sprite_transform(self.layout, pose, dict(bone=record['bone'], offset=[0, 0])))
            result.append(posed[..., 3] > 0)
        return result
