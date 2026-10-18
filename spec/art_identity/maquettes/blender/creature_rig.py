"""Native rigid chain armature for nonhumanoids; no humanoid geometry proxy."""


def bindings_match(pieces, objects, rig):
    """Audit editable sources independently of frozen ownership/render copies."""
    return all((source := objects.get(p['id'])) is not None and
               source.parent == rig and source.parent_type == 'BONE' and
               source.parent_bone == p['rig_bone']
               for p in pieces if p.get('rig_bone'))


def create(spec):
    import bpy
    from mathutils import Vector
    from .pieces import mesh_object
    from .rig import active

    definition = spec['armature']
    arm = bpy.data.armatures.new('maquette_armature')
    rig = bpy.data.objects.new('maquette_armature', arm)
    bpy.context.scene.collection.objects.link(rig)
    active(rig)
    bpy.ops.object.mode_set(mode='EDIT')
    for item in definition['bones']:
        bone = arm.edit_bones.new(item['name'])
        bone.head = definition['rest_joints'][item['head']]
        bone.tail = definition['rest_joints'][item['tail']]
        bone.align_roll(Vector((0, 0, 1)))
        bone.inherit_scale = 'NONE'
    for item in definition['bones']:
        if item.get('parent'):
            arm.edit_bones[item['name']].parent = arm.edit_bones[item['parent']]
    bpy.ops.object.mode_set(mode='OBJECT')
    rig['board_forward_rest'] = [1., 0., 0.]
    bpy.context.view_layer.update()
    core, head = (rig.pose.bones[name].head for name in spec['forward_bones'])
    forward = head - core
    forward.z = 0
    if not forward.length:
        raise ValueError('Creature has no measured anatomical heading')
    rig['posed_forward'] = list(forward.normalized())
    # The builder's anatomy interface is empty for creatures. All surfaces are
    # native source pieces, and each is rigidly bound to its own chain bone.
    body = mesh_object('body', [], [])
    posed = mesh_object('posed_body', [], [])
    body.hide_render = posed.hide_render = True
    body.hide_set(True)
    posed.hide_set(True)
    return rig, posed, []
