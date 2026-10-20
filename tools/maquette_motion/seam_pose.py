"""Report-only seam measurements; native/model agreement remains blocking.

Director feedback 9 replaces tear/protrusion acceptance with native MP4 review.
No measurement is suppressed or clamped when reporting a successful gate.
"""
import numpy as np
from PIL import Image
from cutout_pipeline.cases import read_json
from maquette_motion import pixels, silhouette
from maquette_motion.bleed import source_transform
from humanoid_cutout.native_frames import load_frame

INTERIOR_EROSION_PX = 1
# RendererCanvasCull::_cull_canvas_item skips inherited modulate.a < 0.007,
# before vertex-colour packing (Godot 4.5, servers/rendering/renderer_canvas_cull.cpp).
CANVAS_ITEM_ALPHA_CULL_THRESHOLD = 0.007


def native_reference_matches(actual, expected, row):
    """An entirely culled presentation requires an empty native reference.

    Check every part, including children with their own alpha. A visible part
    keeps the ordinary source-mask comparison; transform checks remain blocking
    in either case. Do not infer invisibility from an empty captured surface.
    """
    if row['parts'] and all(np.float32(p['alpha']) < CANVAS_ITEM_ALPHA_CULL_THRESHOLD
                            for p in row['parts'].values()):
        return not actual.any()
    a, b = (np.repeat(m[..., None], 4, axis=-1).astype(np.uint8) * 255 for m in (actual, expected))
    return pixels.native_frame_matches(a, b)


def summary(report):
    """Keep reproducible per-clip maxima in the case, full poses in output/."""
    return {**{k: v for k, v in report.items() if k != 'poses'}, 'sampled_poses': len(report['poses'])}


def body_part(layout):
    """Common body ancestor accounts for global translation, scale and fade."""
    parts = [p for p in layout['parts'] if not p.get('seam_underlay')]
    chains = []
    for part in parts:
        chain, bone = [], part['bone']
        while bone is not None:
            chain.append(bone)
            bone = layout['joints'][bone]['parent']
        chains.append(chain)
    common = set.intersection(*(set(c) for c in chains))
    bone = next(b for b in chains[0] if b in common)
    return next(p for p in parts if p['name'] == bone)


def reference_images(case, layout):
    rest = np.array(load_frame(case / layout['rest_source']).convert('RGBA'))[..., 3] > 0
    eroded = ~silhouette.dilate(~np.pad(rest, INTERIOR_EROSION_PX), INTERIOR_EROSION_PX,
                               grid_distance=True)[INTERIOR_EROSION_PX:-INTERIOR_EROSION_PX,
                                                   INTERIOR_EROSION_PX:-INTERIOR_EROSION_PX]
    result = []
    for mask in (rest, eroded):
        image = np.zeros((*mask.shape, 4), dtype=np.uint8)
        image[mask] = 255
        result.append(Image.fromarray(image))
    return result


def pose_reference(images, row, owner):
    matrix = source_transform(row, owner)
    alpha = row['parts'][owner['name']]['alpha']
    return [pixels.modulated_alpha(pixels.render(image, matrix)[..., 3], alpha) > 0 for image in images]


def extent(parts, underlays):
    """One-sided outward extent: farthest exposed texel centre to posed paint.

    Report the exact nearest-centre distance without rounding or clamping.
    """
    outside = underlays & ~parts
    if not outside.any():
        return 0., outside
    ys, xs = np.nonzero(outside)
    source_y, source_x = np.nonzero(parts)
    if not len(source_y):
        return float(max(parts.shape)), outside
    # Only boundary pixels can be a nearest neighbour of an exterior pixel.
    interior = ~silhouette.dilate(~np.pad(parts, 1), 1, grid_distance=True)[1:-1, 1:-1]
    source_y, source_x = np.nonzero(parts & ~interior)
    maximum = 0
    for y, x in zip(ys, xs):
        maximum = max(maximum, int(np.min((source_y - y) ** 2 + (source_x - x) ** 2)))
    return float(np.sqrt(maximum)), outside


def measure(parts, underlays, rest, interior):
    composed = parts | underlays
    tears = interior & ~composed
    negative = np.zeros_like(parts)
    existing = np.zeros_like(parts)
    for hole in silhouette.holes(rest):
        existing |= hole
    for hole in silhouette.holes(composed):
        negative |= hole & ~rest & ~existing
    width, protrusion = extent(parts, underlays)
    return {'interior_tear_pixels': int(tears.sum()),
            'natural_negative_space_pixels': int(negative.sum()),
            'underlay_protrusion_pixels': int(protrusion.sum()),
            'underlay_protrusion_width_px': width}, tears, negative, protrusion


def native_consistency_errors(layers, composed):
    errors = []
    frames = {(r['view'], r['clip'], r['frame']): r for r in composed['frames']}
    size = (pixels.PROOF_DEFAULTS['canvas_size'],) * 2
    for row in layers['frames']:
        key = (row['view'], row['clip'], row['frame'])
        if key not in frames:
            errors.append(str(key) + ': missing composed native frame')
            continue
        images = [np.array(load_frame(layers['directory'] / row[k + '_file']).convert('RGBA'))[..., 3] > 0
                  for k in ('parts', 'seams')]
        actual = np.array(load_frame(composed['directory'] / frames[key]['file']).convert('RGBA'))[..., 3] > 0
        if any(image.shape != size for image in [*images, actual]):
            errors.append(str(key) + ': wrong native seam layer dimensions')
        elif not np.array_equal(images[0] | images[1], actual):
            errors.append(str(key) + ': native layers differ from composed body alpha')
    return errors


def report(case, samples, native=None, historical_reference_model=False):
    errors, results, maxima = [], [], {}
    native_rows = {} if native is None else {(r['view'], r['clip'], r['frame']): r for r in native['frames']}
    for view in ('front', 'rear'):
        layout = read_json(case / f'layouts/{view}.json')
        owner = body_part(layout)
        references = reference_images(case, layout)
        layers = {kind: dict(layout, parts=[p for p in layout['parts'] if bool(p.get('seam_underlay')) == flag])
                  for kind, flag in (('parts', False), ('seams', True))}
        images = {p['name']: load_frame(case / p['file']).convert('RGBA') for p in layout['parts']}
        from maquette_motion.joint_seams import boundary, material_parts, rest_regions
        parts = material_parts(layout)
        regions = rest_regions(case, layout)
        joints = []
        for index, a in enumerate(parts):
            for b in parts[index + 1:]:
                edges = boundary(regions[a['name']], regions[b['name']])
                if len(edges) >= 3:
                    joints.append((a, '|'.join((a['name'], b['name'])),
                                   np.c_[edges.mean(axis=1), np.ones(len(edges))].T))
        cache = {}
        for row in (r for r in samples['samples'] if r['view'] == view):
            key = view, row['clip'], row['frame']
            signature = tuple((name, tuple(p['transform']), p['alpha']) for name, p in row['parts'].items())
            if native is not None:
                if key not in native_rows:
                    errors.append('/'.join(map(str, key)) + ': missing native seam layers')
                    continue
                frame = native_rows[key]
                reference = frame.get('reference')
                if reference is None:
                    errors.append('/'.join(map(str, key)) + ': missing actual native reference transform')
                    continue
                expected = row['parts'][owner['name']]
                if reference['bone'] != owner['bone'] or not np.allclose(reference['transform'], expected['transform'],
                        atol=pixels.PROOF_DEFAULTS['transform_tolerance'], rtol=0) or reference['alpha'] != expected['alpha']:
                    errors.append('/'.join(map(str, key)) + ': native reference differs from sampled body transform')
                if not historical_reference_model:
                    if 'reference_transform' not in frame or any(k + '_file' not in frame for k in ('rest', 'interior')):
                        errors.append('/'.join(map(str, key)) + ': missing actual native reference masks')
                        continue
                    matrix = pixels.unpack(frame['reference_transform'])
                    if not np.allclose(matrix, source_transform(row, owner), atol=pixels.PROOF_DEFAULTS['transform_tolerance'], rtol=0):
                        errors.append('/'.join(map(str, key)) + ': independently moved native reference mask')
                    native_references = [np.asarray(load_frame(native['directory'] / frame[k + '_file']).convert('RGBA'))[..., 3] > 0
                                         for k in ('rest', 'interior')]
                    if any(m.shape != (pixels.PROOF_DEFAULTS['canvas_size'],) * 2 for m in native_references):
                        errors.append('/'.join(map(str, key)) + ': wrong native reference dimensions')
                        continue
                    expected_masks = [pixels.modulated_alpha(pixels.render(image, matrix)[..., 3], reference['alpha']) > 0 for image in references]
                    # The pre-existing native source-transform tolerances also
                    # apply to these source masks. Seam metrics are report-only.
                    for kind, actual, expected_mask in zip(('rest', 'interior'), native_references, expected_masks):
                        if not native_reference_matches(actual, expected_mask, row):
                            errors.append('/'.join(map(str, key)) + ': native ' + kind + ' reference differs from source transform')
                masks = [np.array(load_frame(native['directory'] / frame[k + '_file']).convert('RGBA'))[..., 3] > 0
                         for k in ('parts', 'seams')]
                if any(m.shape != (pixels.PROOF_DEFAULTS['canvas_size'],) * 2 for m in masks):
                    errors.append('/'.join(map(str, key)) + ': wrong native seam dimensions')
                    continue
                signature = (signature, frame['parts_sha256'], frame['seams_sha256'],
                             frame.get('rest_sha256'), frame.get('interior_sha256'))
            if signature not in cache:
                if native is None:
                    masks = [silhouette.compose(case, layers[k], row, images) for k in ('parts', 'seams')]
                reference_row = row if native is None else dict(row, parts={**row['parts'], owner['name']: reference})
                target = pose_reference(references, reference_row, owner) if native is None or historical_reference_model else native_references
                metric, tears, _, _ = measure(*masks, *target)
                # Exact coordinates keep an unfillable pose reviewable. Attribute
                # each tear to the closest posed rest joint, without changing it.
                joint_counts = {}
                if tears.any():
                    centres, names = [], []
                    for a, name, points in joints:
                        posed = (source_transform(row, a) @ points)[:2].T + pixels.PROOF_DEFAULTS['source_offset']
                        centres.extend(posed.tolist())
                        names.extend([name] * len(posed))
                    centres = np.asarray(centres)
                    for y, x in np.argwhere(tears):
                        distances = np.sum((centres - [x + .5, y + .5]) ** 2, axis=1) if names else []
                        name = names[int(distances.argmin())] if names else 'no adjacent joint'
                        joint_counts[name] = joint_counts.get(name, 0) + 1
                cache[signature] = dict(metric, tear_joints=joint_counts)
            result = dict(view=view, clip=row['clip'], frame=row['frame'], **cache[signature])
            results.append(result)
            clip = view + '_' + row['clip']
            clip_max = maxima.setdefault(clip, {})
            for field in ('interior_tear_pixels', 'natural_negative_space_pixels',
                          'underlay_protrusion_pixels', 'underlay_protrusion_width_px'):
                if field not in clip_max or result[field] > clip_max[field][field]:
                    clip_max[field] = result
    return {'ok': not errors, 'errors': errors, 'native_pixels': native is not None,
            'interior_erosion_px': INTERIOR_EROSION_PX,
            'acceptance': 'report-only: interior tears, natural negative space and underlay protrusion; director judges native MP4',
            'blocking_checks': 'native coverage, dimensions, reference transform and source-mask agreement',
            'reference_frame': 'approved rest silhouette projected through common body bone, including alpha; square 1px erosion before projection',
            'protrusion_metric': 'max Euclidean texel-centre distance of underlay outside posed material union to that union',
            'natural_negative_space': 'enclosed background outside projected uneroded rest silhouette; report only',
            'native_reference': 'historical CPU replay' if historical_reference_model else 'native captured rest/interior alpha' if native else None,
            'poses': results, 'max_by_clip': maxima}
