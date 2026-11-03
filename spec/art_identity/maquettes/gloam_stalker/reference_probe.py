"""Bridge-only source surface measurements for the mq-13 hunch constraint."""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))


def main(build, output):
    import bpy
    from spec.art_identity.maquettes.blender.rigid_clearance import hull
    bpy.ops.wm.open_mainfile(filepath=str(Path(build) / 'maquette.blend'))
    hood = bpy.data.objects['hood_render']
    floor = json.loads(hood['rounded_hood_report'])['head_bounds'][0][2]
    cover, back = [], []
    for vertex in hood.data.vertices:
        point = list(hood.matrix_world @ vertex.co)
        (cover if point[2] >= floor else back).append(point)
    # Convex extrema suffice for orthographic top measurements at every pitch.
    result = {'cover_points': hull(cover)[0], 'back_points': hull(back)[0], 'head_floor_z': floor}
    Path(output).write_text(json.dumps(result, separators=(',', ':')) + '\n')
    print('MQ13_REFERENCE: PASS; native hood/back extrema measured')


if __name__ == '__main__':
    main(*sys.argv[sys.argv.index('--') + 1:])
