"""Rigid rr30 CPU proof using the actual captured presented Sprite2D matrices.

Re-snapping float32 Bone2D rotations can cross a 1.5-degree tie and invent a
one-pixel tear. Coverage and its inverse source classifier must use the same
presented transform. Other figures keep their existing diagnostic renderer.
"""
from rr22_cpu import CoveragePose
from humanoid_cutout.cpu_pose import sprite_transform as reconstructed_transform
from humanoid_cutout.gates import matrix
from humanoid_cutout.gait_continuations import active_recipe,texture
from maquette_motion import pixels


def sprite_transform(layout,pose,part):
    captured=pose.get('parts',{}).get(part.get('name'))
    return matrix(captured['transform']) if captured else reconstructed_transform(layout,pose,part)


class CpuPose(CoveragePose):
    def layers(self,pose,source_overrides=None):
        if self.layout['joint_meshes']:raise ValueError('rr30 requires rigid source pieces')
        layers=[]
        for part in self.layout['parts']:
            name=part['name']
            source=self.image(part['file']) if source_overrides is None else source_overrides[name]
            checks=self.image(self.layout['proof_layers'][name]['mask'])
            if active_recipe(self.layout,name,gait=pose['clip']=='move',clip=pose['clip']) is not None:
                if source_overrides is None:
                    source=texture(self.case,self.layout,part,gait=pose['clip']=='move',clip=pose['clip'])
                checks=texture(self.case,self.layout,part,gait=pose['clip']=='move',clip=pose['clip'],checks=True)
            transform=sprite_transform(self.layout,pose,part)
            layers.append((part,pixels.render(source,transform),pixels.render(checks,transform)))
        return layers,{}
