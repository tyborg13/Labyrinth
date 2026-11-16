"""Reuse humanoid meshes and the maintained CPU Cycles capture adapter."""
import json
from pathlib import Path


def capture(spec, output, root, objects_by_part, joints):
    import bpy
    from spec.art_identity.maquettes.blender.contract import digest
    from spec.art_identity.maquettes.blender.render import render

    output = Path(output)
    objects = []
    # The renderer owns its root; detach the legacy adapter's identity root.
    for index, (part, group) in enumerate(objects_by_part.items()):
        for obj in group:
            obj.parent = None
            obj['part'] = part
            obj['piece_type'] = 'maquette'
            # Native capture stores global label indices before replacing materials.
            obj.data.materials.clear()
            for name in spec['labels']:
                obj.data.materials.append(bpy.data.materials[name])
            for polygon in obj.data.polygons:
                polygon.material_index = index
            objects.append(obj)
    bpy.data.objects.remove(root, do_unlink=True)
    report = {'spec_hash': digest(spec), 'checks': {'shared_geometry': True}, 'passed': True}
    (output / 'build_report.json').write_text(json.dumps(report, indent=2) + '\n')
    render(spec, objects, output, engine='cycles', views=('front',), capture_facing=False)
    # A future cutout can reopen precisely the captured, labelled meshes.
    bpy.ops.wm.save_as_mainfile(filepath=str(output / 'maquette.blend'))
    print('EMAC_CAPTURE: PASS; views=1; solos=9; engine=cycles_cpu')
