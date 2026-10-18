"""Opt-in camera pan with fixed scale/direction and measured pixel margins."""
import numpy as np

from ..raster import camera, project

FRAME_DEFAULTS = {'pixel_correction_passes': 4}


def minimum_pan(bounds, size, margin):
    bounds = np.asarray(bounds, float)
    lower = margin - bounds[0]
    upper = size - 1 - margin - bounds[1]
    if np.any(lower > upper):
        raise ValueError('Figure cannot fit the required canvas margin with pan only: ' + str(bounds.tolist()))
    return np.minimum(np.maximum(np.zeros(2), lower), upper)


def target_for_pan(spec, view, offset, size):
    _, target, basis, scale = camera(spec, view)
    return target + (-offset[0] * basis[0] + offset[1] * basis[1]) * scale / size


def pan_capture(spec, view, objects, scene, cam, capture, output, size):
    """Do not alter the root turn, camera orientation, scale or front capture."""
    from pathlib import Path
    import json
    import bpy
    from mathutils import Vector
    from .view_states import active_in_view
    config = spec.get('rear_capture') if view == 'rear' else None
    if not config:
        return
    points = [list(obj.matrix_basis @ obj.data.vertices[index].co)
              for obj in objects if active_in_view(obj, view)
              for index in sorted({i for face in obj.data.polygons for i in face.vertices})]
    projected = project(spec, points, view, size)[:, :2]
    bounds = np.array([projected.min(axis=0), projected.max(axis=0)])
    margin = config['edge_margin_px']
    offset = minimum_pan(bounds, size, margin)
    original_location = cam.location.copy()
    original_rotation = cam.rotation_euler.copy()
    original_scale = cam.data.ortho_scale
    for _ in range(FRAME_DEFAULTS['pixel_correction_passes']):
        target = target_for_pan(spec, view, offset, size)
        cam.location = original_location + Vector(target - camera(spec, view)[1])
        bpy.context.view_layer.update()
        capture(view, 'clay')
        image = bpy.data.images.load(str(Path(output) / f'{view}_clay.png'), check_existing=False)
        pixels = np.array(image.pixels[:]).reshape(size, size, 4)[::-1, :, 3]
        bpy.data.images.remove(image)
        occupied = np.argwhere(pixels > 0)
        if not len(occupied):
            raise ValueError('Cannot frame an empty rear')
        pixel_bounds = np.array([occupied.min(axis=0)[::-1], occupied.max(axis=0)[::-1]])
        correction = minimum_pan(pixel_bounds, size, margin)
        if not np.any(correction):
            break
        offset += correction
    else:
        raise ValueError('Rear pan did not achieve the required native pixel margin')
    margins = [int(pixel_bounds[0, 0]), int(pixel_bounds[0, 1]),
               int(size - 1 - pixel_bounds[1, 0]), int(size - 1 - pixel_bounds[1, 1])]
    report = {'passed': min(margins) >= margin and cam.rotation_euler == original_rotation and
                        cam.data.ortho_scale == original_scale,
              'bounds_probe': 'native clay alpha at the existing render sample count', 'pan_px': offset.tolist(), 'original_target': camera(spec, view)[1].tolist(),
              'target': target.tolist(), 'ortho_scale': original_scale,
              'camera_rotation_unchanged': cam.rotation_euler == original_rotation,
              'geometry_bounds_before_pan_px': bounds.tolist(), 'pixel_bounds': pixel_bounds.tolist(),
              'edge_margins_px_left_top_right_bottom': margins, 'required_margin_px': margin}
    (Path(output) / 'capture_frame.json').write_text(json.dumps({view: report}, indent=2) + '\n')
    if not report['passed']:
        raise ValueError('Rear pan changed scale or camera orientation')
