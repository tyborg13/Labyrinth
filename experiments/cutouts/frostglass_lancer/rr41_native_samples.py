"""Lancer proof candidates preserve Godot's recorded rigid-node transforms.

Reconstructing and re-snapping a sprite from Bone2D loses its actual float32
transform. Death 82's hand translation 151.999969482422 becomes 152.0 and
changes a nearest-UV choice after vertex-grid rounding. The phase was identical.
Use the existing sampled node matrix, without another presentation snap.
"""
from humanoid_cutout.cpu_pose import mesh_map, mapped, sprite_transform
from humanoid_cutout.gait_continuations import texture
from humanoid_cutout.gates import matrix
from maquette_motion import pixels


def rigid_transform(layout, pose, part):
    recorded = pose.get('parts', {}).get(part['name'])
    if recorded is not None: return matrix(recorded['transform'])
    # Historical rejection fixtures predate sampled painted-node transforms.
    return sprite_transform(layout, pose, part)


def candidates(model, pose):
    """Four nearest-UV choices for every piece, including rigid sprites."""
    choices, maps = {}, {}
    for part in model.layout['parts']:
        name = part['name']
        source = texture(model.case, model.layout, part, gait=pose['clip']=='move', clip=pose['clip'])
        if name in model.meshes:
            mapping = mesh_map(model.layout, pose, model.meshes[name], with_ties=True, native_skin=True)
            maps[name] = mapping
            samples = mapped(source, mapping, with_ties=True)
        else:
            samples = pixels.render(source, rigid_transform(model.layout, pose, part), with_ties=True)
        choices[name] = samples.candidates
    return choices, maps
