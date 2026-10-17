"""Fixed-frame native cloth simulation and content-addressed baked mesh cache."""
import json
from pathlib import Path
import tempfile

import bpy

from .contract import BUILD_DEFAULTS, digest, mesh_hash, pattern_mesh
from .pieces import mesh_object, place
from .rig import active, evaluated_mesh

from .cloth_contacts import collision_report, inside, mesh_payload, prune_pattern, stabilise_collision


def cloth(piece, spec, body, cache, context_key):
    key = digest({'context': context_key, 'piece': piece, 'blender': bpy.app.version_string,
                  'cache_revision': BUILD_DEFAULTS['cache_revision']})
    path = Path(cache) / (key + '.json')
    if path.exists():
        payload = json.loads(path.read_text())
        if payload['mesh_hash'] != mesh_hash(payload['vertices'], payload['faces']):
            raise ValueError('Corrupt cloth cache: ' + str(path))
        obj = mesh_object(piece['id'], payload['vertices'], payload['faces'])
        obj['part'] = piece['part']
        obj['piece_type'] = 'cloth'
        obj['piece_id'] = piece['id']
    else:
        bpy.context.scene.frame_set(1)
        vertices, faces = pattern_mesh(piece['pattern'], piece['rag'])
        obj = place(mesh_object(piece['id'], vertices, faces), piece, spec)
        active(obj)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        pins = prune_pattern(obj, piece['pattern']['pins'])
        group = obj.vertex_groups.new(name=piece['pin_group'])
        group.add(pins, 1, 'REPLACE')
        modifier = obj.modifiers.new('native_cloth', 'CLOTH')
        settings = modifier.settings
        settings.vertex_group_mass = group.name
        # No taste defaults: physical stiffness, mass, damping and quality are data.
        for name, value in piece['stiffness'].items():
            if not hasattr(settings, name):
                raise ValueError('Unknown Blender cloth setting: ' + name)
            setattr(settings, name, value)
        collision = modifier.collision_settings
        collision.use_collision = True
        collision.distance_min = piece.get('solver_margin', piece['collision_margin'])
        collision.use_self_collision = piece['self_collision']
        collision.self_distance_min = piece['collision_margin']
        modifier.point_cache.frame_start = 1
        modifier.point_cache.frame_end = piece['frames']
        wind = None
        if piece.get('wind'):
            bpy.ops.object.effector_add(type='WIND', location=piece['wind']['location'])
            wind = bpy.context.object
            wind.rotation_euler = piece['wind']['rot']
            wind.field.strength = piece['wind']['strength']
            wind.field.noise = 0
        scene = bpy.context.scene
        scene.frame_end = piece['frames']
        scene.render.threads_mode = 'FIXED'
        scene.render.threads = 1
        for frame in range(1, piece['frames'] + 1):
            scene.frame_set(frame)
            bpy.context.view_layer.update()
            # Force dependency graph evaluation at every step, including background mode.
            evaluated = evaluated_mesh(obj)
            bpy.data.meshes.remove(evaluated)
        baked = evaluated_mesh(obj)
        obj.modifiers.clear()
        old = obj.data
        obj.data = baked
        bpy.data.meshes.remove(old)
        if wind:
            bpy.data.objects.remove(wind, do_unlink=True)
        stabilise_collision(obj, body, piece)
        baked = obj.data
        payload = {'vertices': [list(v.co) for v in baked.vertices],
                   'faces': [list(p.vertices) for p in baked.polygons]}
        payload['mesh_hash'] = mesh_hash(payload['vertices'], payload['faces'])
        path.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, suffix='.tmp', delete=False) as handle:
            json.dump(payload, handle, allow_nan=False)
            temporary = Path(handle.name)
        temporary.replace(path)
    solid = obj.modifiers.new('cloth_thickness', 'SOLIDIFY')
    solid.thickness = piece['thick']
    solid.offset = piece['solidify_offset']
    obj['cloth_kind'] = piece['kind']
    obj['cache_key'] = key
    obj['collision_report'] = json.dumps(collision_report(obj, body, piece['collision_margin']))
    return obj
