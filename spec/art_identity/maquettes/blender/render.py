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


def render(spec, objects, output, engine='cycles', silhouettes_only=False, gallery=False, fit_only=False, preview=False):
    from bpy_extras.object_utils import world_to_camera_view
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
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
    owners = {o.name: [p.material_index for p in o.data.polygons] for o in objects}
    joints = {}

    def capture(view, mode, part=None, piece_type=None, included_parts=None, object_names=None):
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
            obj.data.materials.clear()
            for mat in (parts if mode == 'parts' else [overrides.get(obj.name, clay) if mode == 'clay' else white]):
                obj.data.materials.append(mat)
            for polygon, owner in zip(obj.data.polygons, owners[obj.name]):
                polygon.material_index = owner if mode == 'parts' else 0
        scene.render.filepath = str(output / f'{view}_{mode}.png')
        shading = scene.display.shading
        shading.color_type = 'MATERIAL' if mode in ('parts', 'clay') else 'SINGLE'
        shading.single_color = RENDER_DEFAULTS['clay_colour'] if mode == 'clay' else (1, 1, 1)
        shading.light = 'STUDIO' if mode == 'clay' else 'FLAT'
        shading.show_cavity = mode == 'clay'
        bpy.ops.render.render(write_still=True)

    for view in ('front', 'rear'):
        matrix, target, basis, scale = camera(spec, view)
        root.matrix_world = Matrix(matrix.tolist())
        cam.location = Vector(target) + Vector(basis[2]) * RENDER_DEFAULTS['distance']
        cam.rotation_euler = (Vector(target) - cam.location).to_track_quat('-Z', 'Y').to_euler()
        cam_data.ortho_scale = scale
        bpy.context.view_layer.update()
        if view == 'front':
            from .facing_probe import probe
            facing = probe(spec, objects, output, root, cam, capture)
        if fit_only and view == 'front':
            capture(view, 'silhouette')
            capture(view, 'silhouette', included_parts=set(spec['labels']) - set(spec['fit']['weapon_parts']))
            (output / 'front_silhouette.png').replace(output / 'front_body.png')
            capture(view, 'silhouette', part=spec['fit'].get('head_part', 'head'))
            (output / 'front_silhouette.png').replace(output / 'front_head.png')
            capture(view, 'silhouette')
        if not fit_only:
            for mode in (('silhouette',) if silhouettes_only else ('parts', 'clay', 'silhouette')):
                capture(view, mode)
            if preview and view == 'front' and 'fit' in spec:
                capture(view, 'silhouette', included_parts=set(spec['labels']) - set(spec['fit']['weapon_parts']))
                (output / 'front_silhouette.png').replace(output / 'front_body.png')
                capture(view, 'silhouette', part=spec['fit'].get('head_part', 'head'))
                (output / 'front_silhouette.png').replace(output / 'front_head.png')
                capture(view, 'silhouette')
        # Body is split by weight region before rendering: solos retain hidden anatomy.
            if not preview:
                for part in spec['labels']:
                    capture(view, 'silhouette', part)
                    (output / f'{view}_silhouette.png').replace(output / f'{view}_solo_{part}.png')
                capture(view, 'silhouette')
        if gallery and not fit_only:
            gallery_dir = output / 'piece_gallery'
            gallery_dir.mkdir(exist_ok=True)
            for kind in sorted({o.get('piece_type') for o in objects} - {'body'}):
                capture(view, 'clay', piece_type=kind)
                (output / f'{view}_clay.png').replace(gallery_dir / f'{view}_{kind}.png')
            if not silhouettes_only:
                capture(view, 'clay')
        joints[view] = {}
        for name, p in spec['joints'].items():
            co = world_to_camera_view(scene, cam, root.matrix_world @ Vector(p))
            joints[view][name] = [round(co.x * RENDER_DEFAULTS['size'], 2), round((1 - co.y) * RENDER_DEFAULTS['size'], 2)]
    for obj in objects:
        obj.hide_render = False
    (output / 'joints_px.json').write_text(json.dumps(joints, indent=2) + '\n')
    return facing
