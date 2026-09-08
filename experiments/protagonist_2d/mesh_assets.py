"""Build source-preserving, welded joint bands for painted cutout limbs.

Only sleeve/trouser segments deform. The body, boots, hands, and sword keep
their rigid images. Every segment in a limb uses the SAME source-space grid
and weight field, so their shared pixels cannot peel apart as bones rotate.
The overlap with a rigid body/boot/hand is pinned to that rigid piece's bone.

Godot's internal vertices / explicit triangles avoid uncontrolled bend fans:
https://docs.godotengine.org/en/stable/tutorials/animation/2d_skeletons.html
Matching positions and weights across meshes follows the weld principle:
https://esotericsoftware.com/spine-weights#Weld
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageChops


FAMILIES = (
    ('leg_r', 'hips', 'thigh_r', 'shin_r', 'foot_r'),
    ('leg_l', 'hips', 'thigh_l', 'shin_l', 'foot_l'),
    ('arm_r', 'torso', 'arm_r', 'forearm_r', 'sword_hand_r'),
    ('arm_l', 'torso', 'arm_l', 'forearm_l', 'hand_l'),
)


def _unit(start, end):
    dx, dy = end[0] - start[0], end[1] - start[1]
    length = math.hypot(dx, dy)
    if length < 1e-6:
        raise ValueError('A joint band needs distinct joint positions')
    return dx / length, dy / length


def _projection(point, origin, axis):
    return sum((point[i] - origin[i]) * axis[i] for i in (0, 1))


def _ease(value, low, high):
    t = max(0.0, min(1.0, (value - low) / (high - low)))
    return t * t * (3.0 - 2.0 * t)


def _overlap_extent(first, second, origin, axis, default):
    """Include pixel corners, since deformation interpolates between vertices."""
    shared = ImageChops.multiply(first, second)
    bounds = shared.getbbox()
    if not bounds:
        return default, default, 0
    values = []
    for y in range(bounds[1], bounds[3]):
        for x in range(bounds[0], bounds[2]):
            if shared.getpixel((x, y)):
                values.extend(_projection((x + ox, y + oy), origin, axis)
                              for ox, oy in ((0, 0), (1, 0), (0, 1), (1, 1)))
    return min(values), max(values), len(values) // 4


def _overlap_grid_vertices(first, second, step):
    """Return every grid vertex able to interpolate a shared opaque pixel."""
    shared = ImageChops.multiply(first, second)
    bounds = shared.getbbox()
    vertices = set()
    if bounds:
        for y in range(bounds[1], bounds[3]):
            for x in range(bounds[0], bounds[2]):
                if shared.getpixel((x, y)):
                    gx, gy = (x // step) * step, (y // step) * step
                    vertices.update((gx + dx, gy + dy)
                                    for dx, dy in ((0, 0), (step, 0), (0, step), (step, step)))
    return vertices


def _pin_strength(point, vertices, falloff):
    if not vertices:
        return 0.0
    distance = math.sqrt(min((point[0] - x) ** 2 + (point[1] - y) ** 2 for x, y in vertices))
    return 1.0 - _ease(distance, 0.0, falloff)


def build_joint_meshes(source, masks, joints, parts, output_dir, file_prefix,
                       *, grid_step=2, blend_width=4.0, bend_half_width=5.0):
    """Return layout ``joint_meshes`` descriptors and write their RGBA textures.

    ``masks`` are full-source L images INCLUDING source-only overlap pixels;
    ``parts`` are existing part dictionaries with name/bone/z_index. Call after
    saving the rigid parts. ``file_prefix`` is their layout-relative folder,
    e.g. ``assets/rear``. Missing / fully occluded limb families are skipped.

    All mesh image RGB/alpha values are copied from ``source`` without paint,
    filtering, or resampling. The grid has common bounds and triangulation for
    each upper/lower pair. Texture padding avoids clamped crop-edge smearing.
    """
    if grid_step < 1 or blend_width <= 0 or bend_half_width <= 0:
        raise ValueError('Joint mesh spacing and blend widths must be positive')
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    part_by_name = {part['name']: part for part in parts}
    result = []
    for family, parent_part, upper_part, lower_part, terminal_part in FAMILIES:
        names = (parent_part, upper_part, lower_part, terminal_part)
        if any(name not in masks or name not in part_by_name for name in names):
            continue
        bone_names = [part_by_name[name]['bone'] for name in names]
        if any(name not in joints for name in bone_names):
            raise ValueError('Missing joint for limb family: ' + family)
        _, upper, lower, terminal = [joints[name]['position'] for name in bone_names]
        upper_axis = _unit(upper, lower)
        lower_axis = _unit(lower, terminal)
        # Average the incoming/outgoing directions for a bend cross-section.
        bend_axis = _unit((0, 0), (upper_axis[0] + lower_axis[0],
                                   upper_axis[1] + lower_axis[1]))
        _, collar_max, collar_pixels = _overlap_extent(
            masks[parent_part], masks[upper_part], upper, upper_axis, 0.0)
        cuff_min, _, cuff_pixels = _overlap_extent(
            masks[lower_part], masks[terminal_part], terminal, lower_axis, 0.0)
        # Cover the whole grid cell touching a shared pixel. This makes even
        # raster interpolation over that overlap exactly follow the rigid bone.
        margin = grid_step * (abs(upper_axis[0]) + abs(upper_axis[1]))
        collar_end = max(0.0, collar_max) + margin
        margin = grid_step * (abs(lower_axis[0]) + abs(lower_axis[1]))
        cuff_start = min(0.0, cuff_min) - margin
        # Short sleeves need the wrist pin to follow the actual overlap shape.
        # Pinning an entire cross-section at its earliest overlapping pixel
        # folds the opposite elbow edge when the sword is raised. Local pin
        # neighborhoods preserve the same exact weld while leaving that cloth
        # room to turn. The concealed front left shoulder has no source collar.
        local_pins = family.startswith('arm_') and collar_pixels > 0
        collar_vertices = _overlap_grid_vertices(masks[parent_part], masks[upper_part], grid_step)
        cuff_vertices = _overlap_grid_vertices(masks[lower_part], masks[terminal_part], grid_step)
        short_sleeve = min(math.dist(upper, lower), math.dist(lower, terminal)) < 20.0
        pin_falloff = 8.0 if short_sleeve else 16.0
        sleeve_collar_width = 8.0 if short_sleeve else 12.0
        sleeve_bend_half_width = 16.0
        family_mask = ImageChops.lighter(masks[upper_part], masks[lower_part])
        bbox = family_mask.getbbox()
        if bbox is None:
            continue
        x0, y0 = ((bbox[i] // grid_step - 1) * grid_step for i in (0, 1))
        x1, y1 = ((math.ceil(bbox[i] / grid_step) + 1) * grid_step for i in (2, 3))
        xs, ys = list(range(x0, x1 + 1, grid_step)), list(range(y0, y1 + 1, grid_step))
        vertices, uvs = [], []
        weights = {bone: [] for bone in bone_names}
        for y in ys:
            for x in xs:
                vertices.append([x, y])
                uvs.append([x - x0, y - y0])
                if local_pins:
                    t0 = _ease(_projection((x, y), upper, upper_axis), 0.0, sleeve_collar_width)
                    t1 = _ease(_projection((x, y), lower, bend_axis),
                               -sleeve_bend_half_width, sleeve_bend_half_width)
                    t2 = _ease(_projection((x, y), terminal, lower_axis), -2.0, 2.0)
                else:
                    t0 = _ease(_projection((x, y), upper, upper_axis),
                               collar_end, collar_end + blend_width)
                    t1 = _ease(_projection((x, y), lower, bend_axis),
                               -bend_half_width, bend_half_width)
                    t2 = _ease(_projection((x, y), terminal, lower_axis),
                               cuff_start - blend_width, cuff_start)
                # The terminal override pins every shared boot/hand pixel even
                # on very short shins. Interior vertices share identical values
                # across both meshes; rigid armor cores use one dominant bone.
                values = [(1 - t0) * (1 - t1) * (1 - t2),
                          t0 * (1 - t1) * (1 - t2),
                          t1 * (1 - t2), t2]
                if local_pins:
                    collar_pin = _pin_strength((x, y), collar_vertices, pin_falloff)
                    cuff_pin = _pin_strength((x, y), cuff_vertices, pin_falloff)
                    values = [value * (1 - collar_pin) for value in values]
                    values[0] += collar_pin
                    values = [value * (1 - cuff_pin) for value in values]
                    values[-1] += cuff_pin
                    # The falloff neighborhoods may touch on a short sleeve;
                    # exact shared cells still belong exclusively to their cap.
                    if (x, y) in collar_vertices:
                        values = [1.0, 0.0, 0.0, 0.0]
                    if (x, y) in cuff_vertices:
                        values = [0.0, 0.0, 0.0, 1.0]
                for bone, value in zip(bone_names, values):
                    weights[bone].append(value)
        triangles = []
        for row in range(len(ys) - 1):
            for col in range(len(xs) - 1):
                k = row * len(xs) + col
                triangles.extend(([k, k + 1, k + len(xs) + 1],
                                  [k, k + len(xs) + 1, k + len(xs)]))
        for part_name in (upper_part, lower_part):
            image = Image.composite(source, Image.new('RGBA', source.size), masks[part_name])
            image = image.crop((x0, y0, x1, y1))
            filename = part_name + '_skin.png'
            image.save(output_dir / filename)
            result.append({
                'name': part_name + '_skin', 'replaces_part': part_name,
                'family': family, 'file': file_prefix.rstrip('/') + '/' + filename,
                'offset': [x0, y0], 'bbox': [x0, y0, x1, y1],
                'vertices': vertices, 'uvs': uvs, 'triangles': triangles,
                'weights': weights, 'z_index': part_by_name[part_name]['z_index'],
                'coordinate_space': 'source pixels; UVs are crop-local pixels',
                'joint_bands': {
                    'rigid_parent': bone_names[0], 'rigid_terminal': bone_names[-1],
                    'collar_end': collar_end, 'cuff_start': cuff_start,
                    'blend_width': blend_width, 'bend_half_width': bend_half_width,
                    'collar_shared_pixels': collar_pixels, 'cuff_shared_pixels': cuff_pixels,
                    'grid_step': grid_step,
                    'endpoint_mode': 'local_shared_cells' if local_pins else 'cross_section',
                    'pin_falloff': pin_falloff if local_pins else 0.0,
                    'sleeve_bend_half_width': sleeve_bend_half_width if local_pins else 0.0,
                },
            })
    return result
