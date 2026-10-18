"""Validate an explicitly scoped fixed-offset fit, without changing defaults."""
from copy import deepcopy
import hashlib
import struct

import numpy as np
from PIL import Image

from ..fitting import FIT_DEFAULTS, keyed_mask, normalise_points, warp_mask
from .backend import load_render
from .compile_recipe import PROJECT
from .pixel_coverage import part_coverage


def fixed_iou(mask, source_mask, definition, source_frame):
    extents = []
    for pixels, frame in ((mask, definition), (source_mask, source_frame)):
        y, x = np.nonzero(pixels)
        extents += [normalise_points([x.min(), y.min()], frame), normalise_points([x.max()+1, y.max()+1], frame)]
    bounds = [np.min(extents, axis=0), np.max(extents, axis=0)]
    a = warp_mask(mask, definition, bounds, FIT_DEFAULTS['normalised_height'])
    b = warp_mask(source_mask, source_frame, bounds, FIT_DEFAULTS['normalised_height'])
    return float((a & b).sum() / (a | b).sum())


def validate_pixels(spec, recipe, folder, certificate, policy, fit, frame):
    if policy['method'] != 'fixed_original_mq04':
        raise ValueError('Unsupported explicitly scoped registration method')
    camera = frame['rear']
    scale = struct.unpack('f', struct.pack('f', spec['ortho_scale']))[0]
    margin = spec['rear_capture']['edge_margin_px']
    if (camera.get('passed') is not True or camera.get('camera_rotation_unchanged') is not True or
            camera.get('ortho_scale') != scale or camera.get('required_margin_px') != margin or
            min(camera['edge_margins_px_left_top_right_bottom']) < margin):
        raise ValueError('Rear framing failed its fixed camera and pan-only margin gate')
    definition = deepcopy(policy['fixed_maquette_frame_before_pan'])
    definition['ground_x'] += camera['pan_px'][0]
    for name in ('head_top', 'sole_bottom'):
        definition[name] += camera['pan_px'][1]
    if definition != fit['maquette_frame'] or policy['fixed_source_frame'] != fit['source_frame']:
        raise ValueError('Fixed original registration offset changed')
    painting = PROJECT / recipe['sources']['rear']
    if hashlib.sha256(painting.read_bytes()).hexdigest() != recipe['source_sha256']['rear']:
        raise ValueError('Protected approved rear painting changed')
    raster = load_render(spec, certificate, 'rear', image_folder=folder)
    measured = fixed_iou(raster.silhouette, keyed_mask(Image.open(painting)), definition, policy['fixed_source_frame'])
    if measured != fit['iou'] or measured < policy['iou_min']:
        raise ValueError('Staged rear pixels fail the fixed original fit gate')
    coverage = part_coverage(spec, raster, Image.open(folder / 'rear_parts.png').convert('RGBA'))
    for name, row in coverage.items():
        stated = fit['per_part_coverage'][name]
        if (row['pure_owner_pixels'] != stated['pure_owner_pixels'] or row['solo_pixels'] != stated['solo_pixels'] or
                not row['solo_pixels'] or not (row['pure_owner_pixels'] or stated.get('recorded_occlusion'))):
            raise ValueError('Staged rear part-colour coverage differs: ' + name)
    for path in folder.glob('rear_*.png'):
        y, x = np.nonzero(np.asarray(Image.open(path).convert('RGBA'))[..., 3])
        width, height = Image.open(path).size
        if len(x) and min(x.min(), y.min(), width - 1 - x.max(), height - 1 - y.max()) < margin:
            raise ValueError('A staged rear pixel violates the canvas margin: ' + path.name)
