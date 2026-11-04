"""All-frame CPU release regression sweep. Explicitly not native pixel proof."""
import argparse
import numpy as np
from PIL import Image, ImageDraw
from config import DEFAULTS, baseline_case, release, frame_count, read_json, write_json, digest
from partition import active
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.gates import matrix, clean_metrics
from humanoid_cutout.silhouette_gates import posed_owners, joint_holes
from humanoid_cutout.canvas import for_case
from maquette_motion import pixels
from maquette_motion.silhouette import components


def composite(layers):
    image = Image.new('RGBA', (pixels.PROOF_DEFAULTS['canvas_size'],) * 2)
    for part, paint, _ in sorted(layers, key=lambda r: r[0]['z_index']):
        image.alpha_composite(Image.fromarray(paint))
    return image


def release_layers(model, row, layers):
    result = []
    for part, image, checks in layers:
        selected = active(part, row['clip'], row['phase'])
        if selected != part:
            transform = matrix(row['parts'][part['name']]['transform']).copy()
            transform[:2, 2] += transform[:2, :2] @ (np.asarray(selected['offset']) - part['offset'])
            image = pixels.render(model.image(selected['file']), transform)
            checks = pixels.render(model.image(part['release_texture']['mask']), transform)
        result.append((part, image, checks))
    return result


def boundary_ownership(model, row):
    ownership = model.layout['parts'][0]['proof_ownership']
    if not any(a.get('presentation_grip_part') for a in model.layout.get('held_items', {}).values()):
        return ownership
    if not hasattr(model, '_rr58_release_policy'):
        # Use the existing Gaoler contract: after release its item/hand pair
        # is no longer an anatomical joint. Every body-joint pair survives.
        # No component exemption, pixel threshold or frame exception is added.
        import sys
        sys.path.append(str(baseline_case('chainbound_gaoler').parent))
        from rr44_release import RigidSourcePolicy
        from humanoid_cutout.anatomy import load
        model._rr58_release_policy = RigidSourcePolicy(model.case, load(model.case),
            read_json(model.case / 'compiled_motion.json'), model.layout, None)
    return model._rr58_release_policy.boundary_ownership(ownership, row['clip'], row['phase'])


def metrics(model, row, layers, maps):
    seams = model.masks(row, model.layout['proof_joint_seams'], maps)
    refs = model.masks(row, model.layout['proof_rest_holes'], maps)
    ownership = boundary_ownership(model, row)
    owners = posed_owners(layers, model.layout['parts'], row['bones'], pixels.PROOF_DEFAULTS['source_offset'], ownership)
    holes = joint_holes(owners > 0, np.logical_or.reduce(seams), owners, refs, ownership)
    clean = clean_metrics(layers)
    return {'joint_holes': holes, 'dark_slab_blocks': clean['dark_slab_blocks'],
            'exposed_outline_pixels': clean['exposed_outline_pixels'],
            'components': len(components(owners > 0, 8)[1])}


def sweep(rig, root, before_path, after_path, output, view, clip):
    before, after = read_json(before_path), read_json(after_path)
    if not before['ok'] or not after['ok']: raise ValueError('Bone sample errors')
    index = {(r['view'], r['clip'], r['frame']): r for r in before['samples']}
    layout = read_json(root / f'layouts/{view}.json')
    model = CpuPose(root, layout, native_skin=bool(layout.get('stable_source_raster')),
                    triangle_batch_size=DEFAULTS['triangle_batch_size'])
    rows = [r for r in after['samples'] if r['view'] == view and r['clip'] == clip]
    findings, frames, held, different = [], [], 0, []
    drops = {}
    count = len(rows)
    selected = [28, 29, 41, 95] if rig == 'chainbound_gaoler' else [20, 21, 33, 101]
    with for_case(root):
        for row in rows:
            key = (view, clip, row['frame'])
            previous = index[key]
            # Includes death after release: no bone/node/depth changes allowed.
            if any(row[k] != previous[k] for k in ('bones', 'parts', 'phase')):
                raise ValueError('Changed motion or painted-node transform: ' + str(key))
            old_layers, maps = model.layers(row)
            new_layers = release_layers(model, row, old_layers)
            old_metric = metrics(model, row, old_layers, maps)
            changed_texture = any(active(p, clip, row['phase']) != p for p in layout['parts'])
            new_metric = metrics(model, row, new_layers, maps) if changed_texture else old_metric
            in_hand = row['phase'] < release(rig, view, clip)
            if in_hand:
                a, b = np.asarray(composite(old_layers)), np.asarray(composite(new_layers))
                changed = np.any(a != b, axis=-1)
                for y, x in np.argwhere(changed):
                    different.append({'view': view, 'clip': clip, 'frame': row['frame'], 'xy': [int(x), int(y)],
                                      'before': a[y, x].tolist(), 'after': b[y, x].tolist()})
                held += 1
                if old_metric != new_metric: raise ValueError('In-hand metrics changed')
            if old_metric != new_metric:
                findings.append({'frame': row['frame'], 'before': old_metric, 'after': new_metric})
            frames.append({'frame': row['frame'], 'before': old_metric, 'after': new_metric})
            if clip == 'death' and row['frame'] in selected:
                item = 'chain' if rig == 'chainbound_gaoler' else 'staff'
                drops[row['frame']] = [composite([layer for layer in group if layer[0]['logical_part'] in (item, 'hand_far')])
                                       for group in (old_layers, new_layers)]
    if len(rows) != frame_count(read_json(root / 'compiled_motion.json')['clips'][clip]):
        raise ValueError('Incomplete frame inventory')
    output.parent.mkdir(parents=True, exist_ok=True)
    if drops:
        bounds = [im.getbbox() for pair in drops.values() for im in pair if im.getbbox()]
        box = [min(b[0] for b in bounds), min(b[1] for b in bounds), max(b[2] for b in bounds), max(b[3] for b in bounds)]
        zoom, gutter = DEFAULTS['magnification'], DEFAULTS['strip_gutter_px']
        w, h = (box[2]-box[0])*zoom, (box[3]-box[1])*zoom
        for i, label in enumerate(('before', 'after')):
            strip = Image.new('RGBA', (len(drops)*w, h+gutter), tuple(DEFAULTS['proof_background_rgba']))
            draw = ImageDraw.Draw(strip)
            for j, (frame, pair) in enumerate(drops.items()):
                strip.alpha_composite(pair[i].crop(box).resize((w, h), Image.Resampling.NEAREST), (j*w, gutter))
                draw.text((j*w, 0), f'{view} {label} frame {frame}', fill='white')
            strip.save(output.with_name(view + '_' + label + '_drop_3x_cpu.png'))
    report = {'native_pixels': False, 'rig': rig, 'view': view, 'clip': clip, 'frames': frames,
              'ok': not different, 'in_hand_frames': held, 'differing_pixels': len(different), 'pixels': different,
              'changed_gate_metrics': findings, 'before_samples_sha256': digest(before_path),
              'after_samples_sha256': digest(after_path),
              'acceptance': 'In-hand exact pixels; all transforms fixed. Post-release gate changes are reported, not waived.'}
    write_json(output, report)
    print(f'RR58 CPU SWEEP: {rig}/{view}/{clip}: {count} frames; {held} in-hand; {len(different)} differing pixels; {len(findings)} changed gate rows', flush=True)
    return report


if __name__ == '__main__':
    from pathlib import Path
    p = argparse.ArgumentParser(description=__doc__)
    for field in ('case', 'before', 'after', 'output'): p.add_argument('--' + field, type=Path, required=True)
    for field in ('rig', 'view', 'clip'): p.add_argument('--' + field, required=True)
    a = p.parse_args()
    raise SystemExit(not sweep(a.rig, a.case, a.before, a.after, a.output, a.view, a.clip)['ok'])
