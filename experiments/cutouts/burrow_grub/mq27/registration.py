"""Derive mq27 floor, capsule, framing and rest-overrun reports from approved paint."""
import re
from prepare import *
from maquette_motion import pixels, silhouette

ART_SCALE = 0.64  # Owner decision, v2/README.md, 2026-11-01.
SHADOW_ALPHA = 0.62  # grb-01 / rr-55.
SHADOW_END_ALLOWANCE_PX = 6.0  # rr-55 maximum past painted ends.
BOARD_CANVAS_WIDTH_PER_TILE = 1.03  # CombatBoardView._unit_size, existing game geometry.
PROOF_TILE_WIDTH_PX = 144  # Diagnostic comparison to the director's ~85 columns.


def measured_views():
    result = {}
    for view in inputs.VIEWS:
        rgba = np.asarray(Image.open(CASE / f'source/{view}/processed.png').convert('RGBA'))
        mask = rgba[..., 3] > 0
        lower = np.array([[x + .5, np.flatnonzero(mask[:, x])[-1] + 1.0]
                          for x in range(mask.shape[1]) if mask[:, x].any()])
        slope, intercept = np.polyfit(lower[:, 0], lower[:, 1], 1)
        axis = np.array([1.0, slope]); axis /= np.linalg.norm(axis)
        normal = np.array([-axis[1], axis[0]])
        lower_along = lower[:, 0] * axis[0] + lower[:, 1] * axis[1]
        # Midpoint of the fitted line's occupied longitudinal interval, rather
        # than the canvas x midpoint (rounded caps bias that point head-ward).
        anchor = axis * ((lower_along.min() + lower_along.max()) / 2) + normal * (intercept * normal[1])
        yy, xx = np.nonzero(mask)
        body = np.c_[xx + .5, yy + .5]
        across = body[:, 0] * normal[0] + body[:, 1] * normal[1]
        along = body[:, 0] * axis[0] + body[:, 1] * axis[1]
        bins = np.floor(along).astype(int)
        thickness = [float(np.ptp(across[bins == b]) + 1) for b in np.unique(bins)]
        radius = float(np.median(thickness) / 2)
        start = axis * (along.min() + radius - SHADOW_END_ALLOWANCE_PX) + normal * (anchor @ normal)
        end = axis * (along.max() - radius + SHADOW_END_ALLOWANCE_PX) + normal * (anchor @ normal)
        # Enforce the end allowance in canvas x as well as along the body.
        # The oblique capsule's circular cap can otherwise overshoot the
        # painting's right edge despite satisfying its axial projection.
        left_edge, right_edge = float(xx.min()), float(xx.max()+1)
        start_x = max(float(start[0]), left_edge - SHADOW_END_ALLOWANCE_PX + radius)
        end_x = min(float(end[0]), right_edge + SHADOW_END_ALLOWANCE_PX - radius)
        start = np.array([start_x, slope * start_x + intercept])
        end = np.array([end_x, slope * end_x + intercept])
        offset = lower - anchor
        source_to_tile = ART_SCALE * BOARD_CANVAS_WIDTH_PER_TILE / 255
        outside = np.abs(offset[:, 0]) * source_to_tile + np.abs(offset[:, 1]) * source_to_tile * 2 > .5
        mirrored = lower.copy(); mirrored[:, 0] = 255 - mirrored[:, 0]
        mirrored_anchor = anchor.copy(); mirrored_anchor[0] = 255 - anchor[0]
        reflected_offset = mirrored - mirrored_anchor
        mirrored_outside = np.abs(reflected_offset[:, 0]) * source_to_tile + np.abs(reflected_offset[:, 1]) * source_to_tile * 2 > .5
        drawn_size = round(PROOF_TILE_WIDTH_PX * ART_SCALE * BOARD_CANVAS_WIDTH_PER_TILE)
        drawn = np.asarray(Image.fromarray(rgba).resize((drawn_size, drawn_size), Image.Resampling.NEAREST))
        drawn_lower = np.array([[x+.5,np.flatnonzero(drawn[:,x,3])[-1]+1.0]
                               for x in range(drawn_size) if drawn[:,x,3].any()])
        drawn_offset = drawn_lower - anchor * drawn_size / 255
        drawn_outside = np.abs(drawn_offset[:,0]) / (PROOF_TILE_WIDTH_PX/2) + np.abs(drawn_offset[:,1]) / (PROOF_TILE_WIDTH_PX/4) > 1
        result[view] = {'floor_anchor': anchor.tolist(), 'height': float(anchor[1] - yy.min()),
            'lower_line': {'slope': float(slope), 'intercept': float(intercept), 'columns': len(lower)},
            'outside_diamond_columns_source': int(outside.sum()),
            'mirrored_outside_diamond_columns_source': int(mirrored_outside.sum()),
            'board_comparison': {'tile_width_px': PROOF_TILE_WIDTH_PX, 'canvas_width_per_tile': BOARD_CANVAS_WIDTH_PER_TILE,
                'occupied_columns': len(drawn_lower), 'outside_columns': int(drawn_outside.sum()),
                'basis': 'Offline NEAREST sample; real board snapping remains director-rendered proof'},
            'shadow': {'from': start.tolist(), 'to': end.tolist(), 'half_width': radius, 'alpha': SHADOW_ALPHA},
            'shadow_axial_overrun_px': [float(along.min() - (start @ axis - radius)),
                                        float(end @ axis + radius - along.max())],
            'shadow_x_overrun_px': [float(left_edge-(start[0]-radius)),
                                     float(end[0]+radius-right_edge)],
            'body_median_normal_thickness_px': float(np.median(thickness))}
    return result


def rest_overrun():
    report = {}
    for view in inputs.VIEWS:
        layout = read_json(CASE / f'layouts/{view}.json')
        paint = Image.open(CASE / f'source/{view}/processed.png').convert('RGBA')
        composed = Image.new('RGBA', paint.size)
        for part in sorted(layout['parts'], key=lambda p: p['z_index']):
            composed.alpha_composite(Image.open(CASE / part['file']).convert('RGBA'), tuple(part['offset']))
        actual, approved = np.asarray(composed), np.asarray(paint)
        outside = (actual[..., 3] > 0) & (approved[..., 3] == 0)
        crop = actual.copy()
        crop[outside] = [255, 64, 192, 255]  # Diagnostic only.
        path = CASE / f'proof/{view}_rest_outside_4x.png'
        box = paint.getbbox()
        Image.fromarray(crop).crop(box).resize(((box[2]-box[0])*4, (box[3]-box[1])*4), Image.Resampling.NEAREST).save(path)
        report[view] = {'outside_paint_texels': int(outside.sum()),
            'different_rgba_pixels': int(np.any(actual != approved, axis=2).sum()),
            'crop_4x': str(path.relative_to(CASE))}
    write_json(CASE / 'proof/rest_overrun.json', report)
    return report


def action_bounds(views):
    samples = read_json(CASE / 'proof/continuity_samples.json')
    data = read_json(CASE / 'compiled_motion.json')
    low, high = np.full(2, np.inf), np.full(2, -np.inf)
    for view in inputs.VIEWS:
        layout = read_json(CASE / f'layouts/{view}.json')
        root = np.asarray(layout['joints']['root']['position'])
        anchor = np.asarray(views[view]['floor_anchor'])
        shapes = {}
        for p in layout['parts']:
            yy, xx = np.nonzero(np.asarray(Image.open(CASE / p['file']).convert('RGBA'))[..., 3])
            shapes[p['name']] = bounds.hull(np.c_[xx, yy])
        for row in samples['samples']:
            if row['view'] != view: continue
            travel = np.zeros(2)
            if row['clip'] == 'move':
                travel = bounds.expected_bones(data, layout, view, 'move', row['presented_phase'], samples['step_distance_px'])['root']['global'][:2, 2] - root
            for name, part in row['parts'].items():
                if part['alpha'] <= 0: continue
                transform = pixels.unpack(part['transform'])
                pts = shapes[name] @ transform[:2, :2].T + transform[:2, 2] - anchor - travel
                extent = np.abs(transform[:2, :2]).sum(axis=1) * .5
                a, b = np.floor(pts.min(0) - extent), np.ceil(pts.max(0) + extent)
                low = np.minimum(low, [-max(abs(a[0]), abs(b[0])), a[1]])
                high = np.maximum(high, [max(abs(a[0]), abs(b[0])), b[1]])
    return [*low.tolist(), *(high-low).tolist()]


def install():
    views = measured_views()
    rect = action_bounds(views)
    path = PROJECT / 'scripts/actor_presentation.gd'
    code = path.read_text()
    for view, values in views.items():
        s = values['shadow']
        line = '\t\t"%s": {"from": Vector2(%.8f, %.8f), "to": Vector2(%.8f, %.8f), "half_width": %.8f, "alpha": 0.62},' % (view, *s['from'], *s['to'], s['half_width'])
        head, tail = code.split('const PROFILES:', 1)
        head = re.sub(r'\t\t"' + view + r'": \{[^\n]+', line, head)
        code = head + 'const PROFILES:' + tail
    line = '\t"burrow_grub": {"front": Vector2(%.8f, %.8f), "rear": Vector2(%.8f, %.8f), "height": Vector2(%.8f, %.8f)},' % (*views['front']['floor_anchor'], *views['rear']['floor_anchor'], views['front']['height'], views['rear']['height'])
    code = re.sub(r'\t"burrow_grub": \{"front": Vector2[^\n]+', line, code)
    code = re.sub(r'\t"burrow_grub": Rect2\([^\n]+', '\t"burrow_grub": Rect2(%s),' % ', '.join(map(str, rect)), code)
    path.write_text(code)
    data_path = PROJECT / 'data/enemies.json'
    text = data_path.read_text()
    start = text.index('"burrow_grub":')
    prefix, rest = text[:start], text[start:]
    rest = re.sub(r'"art_scale": [\d.]+', '"art_scale": 0.64', rest, count=1)
    data_path.write_text(prefix + rest)
    result = {'art_scale': ART_SCALE, 'views': views, 'action_bounds': rect,
        'basis': 'Least-squares lower silhouette line, midpoint of occupied projection interval along that line; texel-edge bottom; exact 255px canvas',
        'bounds_basis': 'rr12 convex texel-square hull method; every sampled transform; floor-relative; both reflections; root travel subtracted once',
        'rest': rest_overrun()}
    write_json(CASE / 'proof/registration.json', result)
    print('MQ27 REGISTRATION:', result)
    return result


if __name__ == '__main__': install()
