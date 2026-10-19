"""1024-square ownership, solo, silhouette and cavity-lit clay passes."""
import json
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

from ..raster import camera


RENDER_DEFAULTS = {'size': 1024, 'cycles_samples': 32, 'distance': 30,
                   'seed': 0, 'threads': 8,
                   'clay_colour': [0.6, 0.6, 0.6], 'clay_roughness': 0.8,
                   'ao_distance': 0.15,
                   'studio_energy': 600, 'studio_size': 5,
                   'studio_location': [4, -3, 6]}


def material(name, colour, mode):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*colour, 1)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    output = nodes.new('ShaderNodeOutputMaterial')
    if mode == 'parts':
        shader = nodes.new('ShaderNodeEmission')
        shader.inputs['Color'].default_value = (*colour, 1)
    else:
        shader = nodes.new('ShaderNodeBsdfPrincipled')
        shader.inputs['Base Color'].default_value = (*colour, 1)
        shader.inputs['Roughness'].default_value = RENDER_DEFAULTS['clay_roughness']
        cavity = nodes.new('ShaderNodeAmbientOcclusion')
        cavity.inputs['Color'].default_value = (*colour, 1)
        cavity.inputs['Distance'].default_value = RENDER_DEFAULTS['ao_distance']
        mat.node_tree.links.new(cavity.outputs['Color'], shader.inputs['Base Color'])
    mat.node_tree.links.new(shader.outputs[0], output.inputs['Surface'])
    return mat


def render(spec, objects, output, engine='cycles', silhouettes_only=False, gallery=False, fit_only=False, preview=False, views=('front', 'rear'), ownership_only=False, solo_parts=None):
    from bpy_extras.object_utils import world_to_camera_view
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    from .capture_manifest import write_manifest, prepare_capture
    from .capture_manifest import selected_solos
    solo_labels = selected_solos(spec['labels'], solo_parts)
    from .ownership import assign_materials, materials_match, cloak_owners, require_solos, sagittal_normal, ARMATURE_UP_AXIS, uses_body_side_ownership
    generated = set()
    prepare_capture(output, 'fit' if fit_only else 'preview' if preview else 'full')
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES' if engine == 'cycles' else 'BLENDER_WORKBENCH'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = RENDER_DEFAULTS['cycles_samples']
    scene.cycles.seed = RENDER_DEFAULTS['seed']
    scene.cycles.use_animated_seed = False
    scene.render.threads_mode = 'FIXED'
    scene.render.threads = RENDER_DEFAULTS['threads']
    scene.render.resolution_x = scene.render.resolution_y = RENDER_DEFAULTS['size']
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.film_transparent = True
    scene.view_settings.view_transform = 'Standard'
    scene.view_settings.look = 'None'
    scene.view_settings.exposure = 0
    scene.view_settings.gamma = 1
    root = bpy.data.objects.new('render_root', None)
    scene.collection.objects.link(root)
    for obj in objects:
        obj.parent = root
    cam_data = bpy.data.cameras.new('board_camera')
    cam_data.type = 'ORTHO'
    cam = bpy.data.objects.new('board_camera', cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    light_data = bpy.data.lights.new('studio', 'AREA')
    light_data.energy = RENDER_DEFAULTS['studio_energy']
    light_data.shape = 'DISK'
    light_data.size = RENDER_DEFAULTS['studio_size']
    light = bpy.data.objects.new('studio', light_data)
    scene.collection.objects.link(light)
    light.location = RENDER_DEFAULTS['studio_location']
    light.rotation_euler = (Vector(spec['target']) - light.location).to_track_quat('-Z', 'Y').to_euler()
    parts = [material(name, colour, 'parts') for name, colour in spec['labels'].items()]
    clay = material('clay', RENDER_DEFAULTS['clay_colour'], 'clay')
    overrides = {o.name: material(o.name + '_clay', o['clay_colour'], 'clay')
                 for o in objects if 'clay_colour' in o}
    overrides.update({o.name: material(o.name + '_accent', o['accent_colour'], 'parts')
                      for o in objects if 'accent_colour' in o})
    white = material('silhouette', [1, 1, 1], 'parts')
    invisible = bpy.data.materials.new('solo_excluded_faces')
    invisible.diffuse_color = (0, 0, 0, 0)
    invisible.use_nodes = True
    nodes = invisible.node_tree.nodes
    nodes.clear()
    transparent = nodes.new('ShaderNodeBsdfTransparent')
    surface = nodes.new('ShaderNodeOutputMaterial')
    invisible.node_tree.links.new(transparent.outputs[0], surface.inputs['Surface'])
    owners = {o.name: [p.material_index for p in o.data.polygons] for o in objects}
    # Classify once in armature body space, before either camera turn.
    body_side_report = {}
    if {'cape_near', 'cape_far'} <= set(spec['labels']) or any('side_parts' in o for o in objects):
        from .contract import digest
        rig = bpy.data.objects['maquette_armature']
        spine = next(b for b in spec['armature']['bones'] if b['region'] == 'torso')
        bone = rig.pose.bones[spine['name']]
        midpoint = (bone.head + bone.tail) / 2
        forward = list(rig['posed_forward'])
        up = ARMATURE_UP_AXIS
        near, far = (spec['joints']['shoulder_' + side] for side in ('near', 'far'))
        normal = sagittal_normal(list(midpoint), forward, up, near, far)
        inverse = rig.matrix_world.inverted()
        for obj in objects:
            if uses_body_side_ownership(obj):
                centroids = [list(inverse @ obj.matrix_world @ p.center) for p in obj.data.polygons]
                labels = cloak_owners(centroids, list(midpoint), forward, up, near, far)
                pair = list(obj.get('side_parts', ['cape_near', 'cape_far']))
                labels = [pair[0] if label == 'cape_near' else pair[1] for label in labels]
                owners[obj.name] = [list(spec['labels']).index(label) for label in labels]
                body_side_report[obj.name] = {
                    'torso_midpoint_body': list(midpoint), 'normal_toward_shoulder_near': normal.tolist(),
                    'forward_body': forward, 'up_body': up, 'shoulder_near_body': near, 'shoulder_far_body': far,
                    'face_owner_hash': digest(owners[obj.name]),
                    'faces': {label: labels.count(label) for label in pair}}
    joints = {}

    def capture(view, mode, part=None, piece_type=None, included_parts=None, object_names=None):
        from .view_states import active_in_view
        scene.cycles.samples = RENDER_DEFAULTS['cycles_samples'] if mode == 'clay' else 1
        for obj in objects:
            obj.hide_render = part is not None and not any(
                list(spec['labels'])[i] == part for i in owners[obj.name])
            if piece_type is not None:
                obj.hide_render = obj.get('piece_type') != piece_type
            if included_parts is not None:
                obj.hide_render = obj.get('part') not in included_parts
            if object_names is not None:
                obj.hide_render = obj.name not in object_names
            obj.hide_render |= not active_in_view(obj, view)
            obj.data.materials.clear()
            for mat in (parts if mode == 'parts' else [overrides.get(obj.name, clay) if mode == 'clay' else white]):
                obj.data.materials.append(mat)
            expected = owners[obj.name] if mode == 'parts' else [0] * len(obj.data.polygons)
            if part is not None:
                obj.data.materials.append(invisible)
                expected = [0 if list(spec['labels'])[owner] == part else 1 for owner in owners[obj.name]]
            assign_materials(obj, expected)
            if not materials_match(obj, expected):
                raise ValueError('Polygon material ownership differs from expected winner: ' + obj.name)
        scene.render.filepath = str(output / f'{view}_{mode}.png')
        shading = scene.display.shading
        shading.color_type = 'MATERIAL' if mode in ('parts', 'clay') else 'SINGLE'
        shading.single_color = RENDER_DEFAULTS['clay_colour'] if mode == 'clay' else (1, 1, 1)
        shading.light = 'STUDIO' if mode == 'clay' else 'FLAT'
        shading.show_cavity = mode == 'clay'
        bpy.ops.render.render(write_still=True)
        generated.add(f'{view}_{mode}.png')

    def move_capture(source, destination):
        (output / source).replace(output / destination)
        generated.discard(source)
        generated.add(destination)

    facing = None
    solo_counts = {}
    view_owner_hashes = {}
    for view in views:
        matrix, target, basis, scale = camera(spec, view)
        root.matrix_world = Matrix(matrix.tolist())
        cam.location = Vector(target) + Vector(basis[2]) * RENDER_DEFAULTS['distance']
        cam.rotation_euler = (Vector(target) - cam.location).to_track_quat('-Z', 'Y').to_euler()
        cam_data.ortho_scale = scale
        bpy.context.view_layer.update()
        if body_side_report:
            view_owner_hashes[view] = {name: digest(owners[name]) for name in body_side_report}
        if view == 'rear' and spec.get('rear_capture'):
            from .capture_frame import pan_capture
            pan_capture(spec, view, objects, scene, cam, capture, output, RENDER_DEFAULTS['size'])
        if view == 'front':
            from .facing_probe import probe
            facing = probe(spec, objects, output, root, cam, capture)
        if fit_only:
            capture(view, 'silhouette')
            capture(view, 'silhouette', included_parts=set(spec['labels']) - set(spec['fit']['weapon_parts']))
            move_capture(f'{view}_silhouette.png', f'{view}_body.png')
            capture(view, 'silhouette', part=spec['fit'].get('head_part', 'head'))
            move_capture(f'{view}_silhouette.png', f'{view}_head.png')
            capture(view, 'silhouette')
        if not fit_only:
            for mode in (('parts',) if ownership_only else (('silhouette',) if silhouettes_only else ('parts', 'clay', 'silhouette'))):
                capture(view, mode)
            if preview and 'fit' in spec:
                capture(view, 'silhouette', included_parts=set(spec['labels']) - set(spec['fit']['weapon_parts']))
                move_capture(f'{view}_silhouette.png', f'{view}_body.png')
                capture(view, 'silhouette', part=spec['fit'].get('head_part', 'head'))
                move_capture(f'{view}_silhouette.png', f'{view}_head.png')
                capture(view, 'silhouette')
        # Body is split by weight region before rendering: solos retain hidden anatomy.
            if not preview:
                for part in solo_labels:
                    capture(view, 'silhouette', part)
                    move_capture(f'{view}_silhouette.png', f'{view}_solo_{part}.png')
                solo_counts[view] = {}
                for part in solo_labels:
                    image = bpy.data.images.load(str(output / f'{view}_solo_{part}.png'), check_existing=False)
                    solo_counts[view][part] = sum(a >= .5 for a in image.pixels[3::4])
                    bpy.data.images.remove(image)
                capture(view, 'silhouette')
        if gallery and not fit_only:
            gallery_dir = output / 'piece_gallery'
            gallery_dir.mkdir(exist_ok=True)
            for kind in sorted({o.get('piece_type') for o in objects} - {'body'}):
                capture(view, 'clay', piece_type=kind)
                move_capture(f'{view}_clay.png', f'piece_gallery/{view}_{kind}.png')
            if not silhouettes_only:
                capture(view, 'clay')
        joints[view] = {}
        for name, p in spec['joints'].items():
            co = world_to_camera_view(scene, cam, root.matrix_world @ Vector(p))
            joints[view][name] = [round(co.x * RENDER_DEFAULTS['size'], 2), round((1 - co.y) * RENDER_DEFAULTS['size'], 2)]
    for obj in objects:
        obj.hide_render = False
    joint_path = output / 'joints_px.json'
    if joint_path.exists() and len(views) == 1:
        joints = {**json.loads(joint_path.read_text()), **joints}
    joint_path.write_text(json.dumps(joints, indent=2) + '\n')
    # A bounded batch cannot certify a full delivery. Its caller must combine
    # all independently hash-checked batches and validate the complete capture.
    mode = 'ownership' if ownership_only or solo_parts is not None else 'fit' if fit_only else 'preview' if preview else 'silhouettes' if silhouettes_only else 'full'
    if facing is not None:
        generated.update(('front_torso.png', 'front_torso_frontal_control.png'))
    report = json.loads((output / 'build_report.json').read_text())
    write_manifest(output, report['spec_hash'], mode, generated)
    if solo_counts:
        path = output / 'solo_coverage.json'
        previous = json.loads(path.read_text()) if path.exists() else {}
        path.write_text(json.dumps({**previous, **solo_counts}, indent=2) + '\n')
    if body_side_report:
        path = output / 'cloak_side.json'
        previous = json.loads(path.read_text()) if path.exists() else {}
        path.write_text(json.dumps({'rule': 'body_sagittal_plane', 'pieces': body_side_report,
            'view_owner_hashes': {**previous.get('view_owner_hashes', {}), **view_owner_hashes}}, indent=2) + '\n')
    if solo_counts:
        missing = {view: [name for name in solo_labels if counts.get(name, 0) <= 0]
                   for view, counts in solo_counts.items()}
        report['checks']['required_solo_coverage'] = not any(missing.values())
        report['passed'] = all(report['checks'].values())
        (output / 'build_report.json').write_text(json.dumps(report, indent=2) + '\n')
        (output / 'ownership_validation.json').write_text(json.dumps(
            {'passed': not any(missing.values()), 'empty_required_solos': missing}, indent=2) + '\n')
        # Retain diagnostic outputs, but never report a passing capture when a
        # required rig label is empty. The strict gate runs for every view.
        for counts in solo_counts.values():
            require_solos(solo_labels, counts)
    return facing
