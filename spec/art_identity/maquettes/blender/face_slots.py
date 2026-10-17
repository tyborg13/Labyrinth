"""Real Boolean slit channels in the face plate, with separate accent inlays."""
import bpy


def cut_slots(obj, piece, spec):
    from .pieces import curve
    from .rig import evaluated_mesh
    for slot in piece.get('slots', []):
        cutter_spec = {**slot, 'id': piece['id'] + '_' + slot['id'], 'part': piece['part'],
                       'type': 'curve', 'at': 'root', 'offset': [0, 0, 0], 'rot': [0, 0, 0],
                       'spline': 'POLY', 'closed': False, 'resolution': 8, 'bevel_resolution': 2,
                       'conforming': True, 'taper': [1] * len(slot['path'])}
        source = curve(cutter_spec, spec)
        cutter = bpy.data.objects.new(source.name + '_boolean', evaluated_mesh(source))
        bpy.context.scene.collection.objects.link(cutter)
        cutter.matrix_world = source.matrix_world.copy()
        cutter.hide_render = True
        cutter.hide_set(True)
        cutter['native_source'] = True
        source.hide_render = True
        source.hide_set(True)
        source['native_source'] = True
        modifier = obj.modifiers.new('recess_' + slot['id'], 'BOOLEAN')
        modifier.operation = 'DIFFERENCE'
        modifier.solver = 'EXACT'
        modifier.object = cutter
