"""Append approved anatomy, bind with Blender heat weights, then pose by joints."""
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

from .contract import label_faces

BIND_DEFAULTS = {'voxel_size': .025}


def active(obj):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def evaluated_mesh(obj):
    deps = bpy.context.evaluated_depsgraph_get()
    return bpy.data.meshes.new_from_object(obj.evaluated_get(deps), depsgraph=deps)


def append_body(spec, bundle):
    if not Path(bundle).is_file():
        raise ValueError('Approved base bundle missing: ' + str(bundle))
    asset = spec['base']['asset']
    # Bundle thumbnail identifiers are camera names. Resolve the anatomy object
    # explicitly, preserving the public asset name from the owner's brief.
    object_name = spec['base'].get('object', {'realistic_body_male': 'GEO-body_male_realistic'}.get(asset, asset))
    with bpy.data.libraries.load(str(bundle), link=False) as (source, target):
        if object_name in source.objects:
            target.objects = [object_name]
        elif asset in source.collections:
            target.collections = [asset]
        else:
            raise ValueError('Asset absent from approved bundle: ' + asset)
    objects = list(target.objects)
    if target.collections:
        for collection in target.collections:
            bpy.context.scene.collection.children.link(collection)
            objects.extend(collection.all_objects)
    meshes = [o for o in objects if o and o.type == 'MESH']
    if not meshes:
        raise ValueError('Approved asset contains no body mesh')
    for obj in objects:
        if obj and obj.type != 'MESH':
            obj.hide_render = True
    for obj in meshes:
        if not obj.users_collection:
            bpy.context.scene.collection.objects.link(obj)
        # Registration belongs to the asset recipe, never inferred from bounds.
        world = Matrix(spec['base']['matrix']) @ obj.matrix_world
        obj.parent = None
        obj.matrix_world = world
        obj.hide_set(False)
        obj.hide_render = False
        if 'subdivision_level' in spec['base']:
            for modifier in obj.modifiers:
                if modifier.type in ('MULTIRES', 'SUBSURF'):
                    modifier.levels = spec['base']['subdivision_level']
    active(meshes[0])
    for obj in meshes:
        obj.select_set(True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    body = bpy.context.object
    body.name = 'body'
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # Freeze any bundle subdivision before computing heat weights, so face
    # ownership and the posed collision mesh have exactly the same topology.
    data = evaluated_mesh(body)
    body.modifiers.clear()
    old = body.data
    body.data = data
    if not old.users:
        bpy.data.meshes.remove(old)
    body.vertex_groups.clear()
    body.data.materials.clear()
    return body


def bind_and_pose(spec, body):
    definition = spec['armature']
    arm = bpy.data.armatures.new('maquette_armature')
    rig = bpy.data.objects.new('maquette_armature', arm)
    bpy.context.scene.collection.objects.link(rig)
    active(rig)
    bpy.ops.object.mode_set(mode='EDIT')
    for b in definition['bones']:
        bone = arm.edit_bones.new(b['name'])
        bone.head = definition['rest_joints'][b['head']]
        bone.tail = definition['rest_joints'][b['tail']]
        bone.roll = b['roll']
        # Explicit anatomical forward; vertical edit bones otherwise retain
        # Blender's default roll, independent of the appended body's yaw.
        bone.align_roll(Vector((1, 0, 0)))
        bone.inherit_scale = 'NONE'
    for b in definition['bones']:
        if b.get('parent'):
            arm.edit_bones[b['name']].parent = arm.edit_bones[b['parent']]
    bpy.ops.object.mode_set(mode='OBJECT')
    active(rig)
    body.select_set(True)
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    if not any(m.type == 'ARMATURE' for m in body.modifiers):
        raise ValueError('Automatic armature binding failed')
    # Ownership uses heat weights, never proximity to an accessory or camera.
    regions = {b['name']: b['region'] for b in definition['bones']}
    def ownership():
        weights = [{body.vertex_groups[g.group].name: g.weight for g in v.groups} for v in body.data.vertices]
        return label_faces(body.data.vertices, [p.vertices[:] for p in body.data.polygons], weights, regions)
    try:
        owners = ownership()
    except ValueError:
        # Heat weighting can fail on the bundle's mouth/finger interior topology.
        # Bind a closed Blender voxel proxy automatically, then transfer its heat
        # weights with Blender's nearest-face interpolation to the untouched skin.
        print('BUILD_STAGE: automatic heat binding via closed voxel proxy', flush=True)
        proxy = bpy.data.objects.new('automatic_binding_proxy', body.data.copy())
        bpy.context.scene.collection.objects.link(proxy)
        remesh = proxy.modifiers.new('closed_heat_surface', 'REMESH')
        remesh.mode = 'VOXEL'
        remesh.voxel_size = definition.get('binding_voxel_size', BIND_DEFAULTS['voxel_size'])
        active(proxy)
        bpy.ops.object.modifier_apply(modifier=remesh.name)
        active(rig)
        proxy.select_set(True)
        bpy.ops.object.parent_set(type='ARMATURE_AUTO')
        body.vertex_groups.clear()
        for name in regions:
            body.vertex_groups.new(name=name)
        active(body)
        transfer = body.modifiers.new('automatic_weight_transfer', 'DATA_TRANSFER')
        transfer.object = proxy
        transfer.use_vert_data = True
        transfer.data_types_verts = {'VGROUP_WEIGHTS'}
        transfer.vert_mapping = 'POLYINTERP_NEAREST'
        transfer.layers_vgroup_select_src = 'ALL'
        transfer.layers_vgroup_select_dst = 'NAME'
        bpy.ops.object.modifier_apply(modifier=transfer.name)
        owners = ownership()
        bpy.data.objects.remove(proxy, do_unlink=True)
        body['automatic_binding'] = 'Blender heat weights on closed voxel proxy; native Data Transfer to original surface'
    pending = {b['name']: b for b in definition['bones']}
    done = set()
    while pending:
        for name, b in list(pending.items()):
            if b.get('parent') and b['parent'] not in done:
                continue
            rest = arm.bones[name]
            head, tail = (Vector(spec['joints'][b[k]]) for k in ('head', 'tail'))
            direction = tail - head
            rotation = (rest.tail_local - rest.head_local).rotation_difference(direction)
            basis = rotation.to_matrix() @ rest.matrix_local.to_3x3()
            if b['region'] in ('pelvis', 'torso', 'head'):
                # Keep the anatomical anterior axis +X even when the spine
                # leans; endpoint-only shortest rotations leave yaw undefined.
                y = direction.normalized()
                z = (Vector((1, 0, 0)) - y * y.x).normalized()
                x = y.cross(z).normalized()
                basis = Matrix((x, y, z)).transposed()
            transform = basis.to_4x4() @ Matrix.Diagonal((*[b['scale'][0], direction.length / rest.length, b['scale'][1]], 1))
            transform.translation = head
            rig.pose.bones[name].matrix = transform
            bpy.context.view_layer.update()
            done.add(name)
            del pending[name]
    bpy.context.view_layer.update()
    # Freeze the posed collision mesh. Keep the editable bound rig in the blend.
    data = evaluated_mesh(body)
    posed = bpy.data.objects.new('posed_body', data)
    bpy.context.scene.collection.objects.link(posed)
    posed.matrix_world = body.matrix_world.copy()
    body.hide_render = True
    body.hide_set(True)
    posed.modifiers.new('body_collision', 'COLLISION')
    posed.collision.thickness_outer = definition['collision_margin']
    rig['board_forward_rest'] = [1.0, 0.0, 0.0]
    spine = next((b for b in definition['bones'] if b['region'] == 'torso'), definition['bones'][0])
    rest_basis = arm.bones[spine['name']].matrix_local.to_3x3()
    deform = rig.pose.bones[spine['name']].matrix.to_3x3() @ rest_basis.inverted()
    rig['posed_forward'] = list((deform @ Vector((1, 0, 0))).normalized())
    return rig, posed, owners
