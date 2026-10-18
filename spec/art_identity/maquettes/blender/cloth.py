"""Fixed-frame native cloth simulation and content-addressed baked mesh cache."""
import json
from pathlib import Path
import tempfile
from copy import deepcopy

import bpy

from .contract import BUILD_DEFAULTS, digest, mesh_hash, pattern_mesh
from .pieces import mesh_object, place
from .rig import active, evaluated_mesh

from .cloth_contacts import collision_report, inside, mesh_payload, prune_pattern, stabilise_collision
from .cloth_cache import cache_key, read_cache
from .cloth_topology import snapshot, restore

CLOTH_LOG_DEFAULTS = {'frame_interval': 8}
CONTACT_STABILITY_DEFAULTS = {'clearance_multiplier': 4}


def cloth(piece, spec, body, cache, context_key):
    key = cache_key(context_key, piece, bpy.app.version_string)
    path = Path(cache) / (key + '.json')
    if path.exists():
        payload = read_cache(path)
        obj = restore(piece['id'], payload)
        obj['part'] = piece['part']
        obj['piece_type'] = 'cloth'
        obj['piece_id'] = piece['id']
    else:
        bpy.context.scene.frame_set(1)
        vertices, faces = pattern_mesh(piece['pattern'], piece['rag'])
        source_pins = piece['pattern']['pins']
        obj = place(mesh_object(piece['id'], vertices, faces), piece, spec)
        if 'explicit' in piece['pattern']:
            from .sewn_garment import SEWN_DEFAULTS
            attribute = obj.data.attributes.new(SEWN_DEFAULTS['owner_attribute'], 'INT', 'FACE')
            attribute.data.foreach_set('value', piece['pattern']['explicit']['owners'])
            import bmesh
            topology = bmesh.new()
            topology.from_mesh(obj.data)
            bmesh.ops.recalc_face_normals(topology, faces=list(topology.faces))
            topology.to_mesh(obj.data)
            topology.free()
        bpy.context.view_layer.update()
        active(obj)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        if piece.get('drape', {}).get('native_hood'):
            from .rounded_hood import make as rounded_hood
            source_pins = rounded_hood(obj, body, piece, spec)
            if piece['drape']['native_hood'].get('mask_piece'):
                from .masked_hood import aperture
                source_pins = aperture(obj, source_pins, piece, spec)
        if piece.get('drape', {}).get('back_sheet'):
            from .back_sheet import make as back_sheet
            source_pins = back_sheet(obj, body, piece, spec)
        if piece.get('drape', {}).get('native_rest'):
            from .native_garment import make
            source_pins = make(obj, body, piece, spec)
        if piece.get('drape', {}).get('cutout_regions'):
            from .cloth_cutouts import fitted_armholes
            source_pins = fitted_armholes(obj, body, piece, source_pins)
        pins = prune_pattern(obj, source_pins)
        solver = None
        if piece.get('drape'):
            from .drape_collision import prepare
            native_piece = deepcopy(piece)
            native_piece['_native_pins'] = pins
            solver = prepare(obj, body, native_piece, spec)
            if piece['drape'].get('weld_tolerance'):
                from .cloth_weld import weld
                pins, targets = weld(obj, pins, solver[2], piece['drape']['weld_tolerance'])
                solver = solver[0], solver[1], targets
        initial = [v.co.copy() for v in obj.data.vertices]
        print('CLOTH_PATTERN: ' + piece['id'] + '; vertices=' + str(len(initial)) + '; pins=' + str(len(pins)), flush=True)
        if solver and solver[2] and piece['drape'].get('gather_frames'):
            from .cloth_attachment import animate_pins
            animate_pins(obj, solver[2], piece['drape']['gather_frames'])
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
        collision.self_distance_min = piece.get('drape', {}).get('self_distance_min', piece['collision_margin'])
        if solver:
            collision.collection = solver[0]
            collision.collision_quality = piece['drape']['collision_quality']
        modifier.point_cache.frame_start = 1
        modifier.point_cache.frame_end = piece['frames']
        wind = None
        if piece.get('wind'):
            bpy.ops.object.effector_add(type='WIND', location=piece['wind']['location'])
            wind = bpy.context.object
            if 'direction' in piece['wind']:
                from mathutils import Vector
                wind.rotation_euler = Vector(piece['wind']['direction']).to_track_quat('Z', 'Y').to_euler()
            else:
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
            if frame % CLOTH_LOG_DEFAULTS['frame_interval'] == 0 or frame == piece['frames']:
                print('CLOTH_FRAME: ' + piece['id'] + '; ' + str(frame) + '/' + str(piece['frames']), flush=True)
        baked = evaluated_mesh(obj)
        from mathutils.bvhtree import BVHTree
        reference_tree = BVHTree.FromPolygons([v.co.copy() for v in baked.vertices], [list(p.vertices) for p in baked.polygons])
        pinned = set(pins)
        simulation_report = {'frames': piece['frames'], 'vertices': len(initial),
            'pins': len(pins), 'free_vertices': len(initial) - len(pins),
            'maximum_solver_displacement': max((v.co - p).length for v, p in zip(baked.vertices, initial)),
            'maximum_free_solver_displacement': max(((v.co - p).length for i, (v, p) in enumerate(zip(baked.vertices, initial)) if i not in pinned), default=0),
            'maximum_pin_error': max((baked.vertices[i].co - (solver[2].get(i, initial[i]) if solver else initial[i])).length for i in pins)}
        obj.modifiers.clear()
        old = obj.data
        obj.data = baked
        bpy.data.meshes.remove(old)
        if wind:
            bpy.data.objects.remove(wind, do_unlink=True)
        if solver:
            # Refine contact against the same watertight solver skin, avoiding
            # a different regional projection after the native simulation.
            stabilise_collision(obj, solver[1], piece)
            from .drape_collision import regional_contacts
            regional_contacts(obj, solver[1], body, piece)
            # Keep the same enclosing support after simulation. Reprojecting
            # onto the unclosed source skin can push a point through an
            # adjacent finger or arm even when the solver contact was clear.
            from .drape_collision import finish
            finish(*solver)
        else:
            stabilise_collision(obj, body, piece)
        if piece.get('drape', {}).get('smooth_normals'):
            for polygon in obj.data.polygons:
                polygon.use_smooth = True
        if piece.get('drape'):
            from .drape_collision import COLLIDER_DEFAULTS
            simulation_report['maximum_contact_displacement'] = max(reference_tree.find_nearest(v.co)[3] for v in obj.data.vertices)
            simulation_report['maximum_contact_displacement_allowed'] = CONTACT_STABILITY_DEFAULTS['clearance_multiplier'] * (piece.get('solver_margin', piece['collision_margin']) + COLLIDER_DEFAULTS['surface_allowance'] + piece['thick'] / 2)
        baked = obj.data
        payload = snapshot(baked)
        payload['simulation_report'] = simulation_report
        for report_name in ('sewn_rest_report', 'rounded_hood_report', 'back_sheet_report', 'attachment_report'):
            if report_name in obj:
                payload[report_name] = json.loads(obj[report_name])
        path.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, suffix='.tmp', delete=False) as handle:
            json.dump(payload, handle, allow_nan=False)
            temporary = Path(handle.name)
        temporary.replace(path)
    solid = obj.modifiers.new('cloth_thickness', 'SOLIDIFY')
    solid.thickness = piece['thick']
    solid.offset = piece['solidify_offset']
    obj['cloth_kind'] = piece['kind']
    if 'capture_view' in piece:
        obj['capture_view'] = piece['capture_view']
    if 'ownership_mode' in piece:
        obj['ownership_mode'] = piece['ownership_mode']
    if 'side_parts' in piece:
        obj['side_parts'] = list(piece['side_parts'])
    for key in ('joint_parts', 'joint_chain', 'sewn_parts'):
        if key in piece:
            obj[key] = list(piece[key])
    obj['cache_key'] = key
    for report_name in ('sewn_rest_report', 'rounded_hood_report', 'back_sheet_report', 'attachment_report'):
        if report_name in payload:
            obj[report_name] = json.dumps(payload[report_name])
    if 'simulation_report' in payload:
        obj['simulation_report'] = json.dumps(payload['simulation_report'])
    obj['collision_report'] = json.dumps(collision_report(obj, body, piece['collision_margin']))
    return obj
