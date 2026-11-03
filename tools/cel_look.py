#!/usr/bin/env python3
"""Offline cel variants. The protected director filter owns all look decisions.

fit freezes the rest's material assignment centres (before the final k-means
update, exactly like the reference), tones, thresholds and light normalization.
apply never fits a piece. Original PNGs and their import/provenance data are read-only.
"""
import argparse
import copy
import importlib.util
import json
import hashlib
import time
from pathlib import Path

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
DATA = PROJECT / 'spec/peer_benchmark/staged/cel-01'
_spec = importlib.util.spec_from_file_location('cel_reference', DATA / 'reference_filter.py')
reference = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(reference)
W = reference.W
from cel_look_state import CONFIG, OUTPUT_DIRECTORY, input_stamp, status, variant_relative


def settings():
    return json.loads(CONFIG.read_text())


def merged_look(config, facing, category=None):
    """Category then facing overrides ('category:<name>', then '<character>/<facing>') inherit nested settings
    without mutating owner data."""
    def merge(base, override):
        result = copy.deepcopy(base)
        for key, value in override.items():
            result[key] = merge(result[key], value) if isinstance(value, dict) and isinstance(result.get(key), dict) else copy.deepcopy(value)
        return result
    overrides = config.get('look_overrides', {})
    look = merge(config['look'], overrides.get('category:' + category, {}) if category else {})
    return merge(look, overrides.get(facing, {}))


def rgba(image):
    return np.asarray(image.convert('RGBA')).astype(float) / 255


def features(x, look):
    xl = x @ W
    return np.concatenate([x / np.maximum(xl[:, None], 0.04) * look['colour_weight'], xl[:, None] * 1.0], 1)


def nearest(x, centres):
    # Bounded temporary memory even for large NPC source canvases and sheets.
    chunk_pixels = 32768
    return np.concatenate([((chunk[:, None, :] - centres[None]) ** 2).sum(-1).argmin(1)
                           for chunk in np.array_split(x, max(1, (len(x) + chunk_pixels - 1) // chunk_pixels))])


def light(body, look):
    ops = reference
    h = np.zeros(body.shape)
    m = body.copy()
    for _ in range(30):
        h += m
        m = ~ops.grow(~m)
        if not m.any():
            break
    h = ops.blur(np.sqrt(h / max(h.max(), 1)), 2.5)
    gradient = np.gradient
    gy = gradient(h, axis=0) if h.shape[0] > 1 else np.zeros_like(h)
    gx = gradient(h, axis=1) if h.shape[1] > 1 else np.zeros_like(h)
    n = np.dstack([-gx * 9, -gy * 9, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    direction = np.array(look['key_light_direction'], float)
    direction /= np.linalg.norm(direction)
    # Accelerate can leave floating-point flags set despite finite, correct
    # dot-product values. Only silence flags for this operation; keep its math.
    with np.errstate(divide='ignore', over='ignore', invalid='ignore'):
        return n @ direction


def prepare(image, look):
    ops = reference
    a = rgba(image)
    rgb, alpha = a[..., :3], a[..., 3]
    body = alpha > 0.5
    olum = rgb @ W
    mx, mn = rgb.max(2), rgb.min(2)
    sat = (mx - mn) / np.maximum(mx, 1e-3)
    g = look['glow']
    glow = ops.grow(body & (mx > g['core_value']) & (sat > g['core_saturation'])) & body \
        & (mx > g['halo_value']) & (sat > g['halo_saturation'])
    ink = body & (olum < look['ink_value'])
    sm = ops.kuwahara(rgb, look['kuwahara_radius'])
    slum = sm @ W
    wsum = ops.blur(body.astype(float), look['value_blur'])
    vlum = ops.blur(np.where(body, slum, 0), look['value_blur']) / np.maximum(wsum, 1e-3)
    return rgb, alpha, body, olum, glow, ink, sm, slum, vlum


def fit(image, look=None):
    look = settings()['look'] if look is None else look
    rgb, alpha, body, olum, glow, ink, sm, slum, vlum = prepare(image, look)
    model = {'look': look, 'size': image.size, 'tones': {}}
    if look['key_light'] and body.any():
        ndl = light(body, look)
        vv = vlum[body]
        model['light'] = ndl
        model['normalization'] = vv.mean(), max(vv.std(), 1e-3), ndl[body].mean(), max(ndl[body].std(), 1e-3)
        vm, vs, lm, ls = model['normalization']
        vlum = (vlum - vm) / vs + look['key_light'] * (ndl - lm) / ls
    idx = np.flatnonzero((body & ~ink & ~glow).ravel())
    x = sm.reshape(-1, 3)[idx]
    if not len(x):
        model['centres'] = np.empty((0, 4))
        model['materials'] = np.empty((0, 3))
        return model
    feat = features(x, look)
    # These are the reference algorithm's iteration count and random seed,
    # not additional look controls. Every exposed look setting comes from JSON.
    rng = np.random.default_rng(3)
    k = min(look['materials'], len(x))
    centres = feat[rng.choice(len(x), k, replace=False)]
    for _ in range(12):
        assignment_centres = centres.copy()
        lab = nearest(feat, centres)
        for i in range(k):
            sel = feat[lab == i]
            if len(sel):
                centres[i] = sel.mean(0)
    model['centres'] = assignment_centres
    model['materials'] = np.array([x[lab == i].mean(0) if (lab == i).any() else np.zeros(3) for i in range(k)])
    v, ol = vlum.ravel()[idx], olum.ravel()[idx]
    for i in range(k):
        sel = lab == i
        if sel.sum() < 4:
            continue
        cols, vi = x[sel], v[sel]
        threshold = np.median(vi)
        f, step = (vi >= threshold).mean(), look['shadow_step']
        lit = np.clip(cols.mean(0) / (f + step * (1 - f)), 0, 1)
        shadow = lit * step * reference.SHADOW_TINT
        hl = look['highlight']
        hi_t = np.percentile(ol[sel], hl['percentile'])
        hi = None
        if hi_t > hl['min_value'] and hi_t - np.median(ol[sel]) > hl['min_rise']:
            hi = cols[ol[sel] >= hi_t].mean(0)
            hi = hi + (1 - hi) * hl['lift']
        model['tones'][i] = lit, shadow, threshold, hi_t, hi
    return model


def apply(image, model, touch=()):
    look = model['look']
    rgb, alpha, body, olum, glow, ink, sm, slum, vlum = prepare(image, look)
    if 'normalization' in model:
        # Same-canvas pieces share the rest silhouette's key-light field too.
        ndl = model['light'] if image.size == model['size'] else light(body, look)
        vm, vs, lm, ls = model['normalization']
        vlum = (vlum - vm) / vs + look['key_light'] * (ndl - lm) / ls
    idx = np.flatnonzero((body & ~ink & ~glow).ravel())
    res = rgb.copy()
    if len(idx) and len(model['centres']):
        lab = nearest(features(sm.reshape(-1, 3)[idx], look), model['centres'])
        flat, v, ol = res.reshape(-1, 3), vlum.ravel()[idx], olum.ravel()[idx]
        for i, (lit, shadow, threshold, hi_t, hi) in model['tones'].items():
            sel = lab == i
            out = np.where((v[sel] >= threshold)[:, None], lit, shadow)
            if hi is not None:
                out = np.where((ol[sel] >= hi_t)[:, None], hi, out)
            flat[idx[sel]] = out
        detail = body & ~ink & ~glow & (np.abs(olum - slum) > look['detail_contrast'])
        if detail.any():
            d = rgb[detail]
            near = nearest(d, model['materials'])
            out = d.copy()
            for i, (lit, shadow, *_rest) in model['tones'].items():
                sel = near == i
                out[sel] = np.where(((d[sel] @ W) >= ((lit + shadow) / 2) @ W)[:, None], lit, shadow)
            res[detail] = out
    res[ink] = reference.INK
    res[glow] = rgb[glow]
    if touch:
        keep = reference.touch_mask(body.shape, touch) & body
        res[keep] = rgb[keep]
    return Image.fromarray((np.dstack([np.clip(res, 0, 1), alpha]) * 255).round().astype(np.uint8))


def write_variant(source, variant, target):
    a, b = np.asarray(source.convert('RGBA')), np.asarray(variant.convert('RGBA'))
    if a.shape != b.shape or not np.array_equal(a[..., 3], b[..., 3]):
        raise ValueError(f'Refusing variant with changed size/alpha: {target}')
    target.parent.mkdir(parents=True, exist_ok=True)
    variant.save(target, format='PNG')


def entry_model(entry, project, config, models):
    # Facing is part of the key: shared source bytes may have distinct looks.
    key = entry['rest'], entry['facing'], entry.get('tileable', False), entry.get('category')
    if key not in models:
        with Image.open(project / entry['rest']) as rest:
            models[key] = fit(rest, merged_look(config, entry['facing'], entry.get('category')))
    return models[key]


def entry_touch(entry, config, image, model):
    own = config['touch_ups'].get(entry['path'], {}).get('ellipses', [])
    touch = own or config['touch_ups'].get(entry['facing'], {}).get('ellipses', [])
    mismatch = bool(touch and not own and image.size != model['size'])
    return (() if mismatch else touch), mismatch


def build(project=PROJECT, output=None, if_stale=False):
    from cel_look_inventory import inventory
    started = time.perf_counter()
    output = project / OUTPUT_DIRECTORY if output is None else output
    entries, classification = inventory(project)
    config, models, counts, mismatches = settings(), {}, {}, []
    current, reason = status(project, output, entries, config)
    if if_stale and current:
        print('CEL_BUILD current (no-op)', flush=True)
        return None
    # Floors are deliberately outside the approved look. No periodic filter ships.
    if any(e.get('tileable', False) for e in entries):
        raise ValueError('Cel inventory unexpectedly includes a floor')
    stamp = input_stamp(project, entries, config)
    output.mkdir(parents=True, exist_ok=True)
    (output / 'manifest.json').unlink(missing_ok=True)
    hashes = {}
    for entry in entries:
        model = entry_model(entry, project, config, models)
        with Image.open(project / entry['path']) as image:
            touch, mismatch = entry_touch(entry, config, image, model)
            if mismatch:
                mismatches.append(entry['path'])
            relative = variant_relative(entry['path'])
            target = output / relative
            write_variant(image, apply(image, model, touch), target)
            hashes[relative] = hashlib.sha256(target.read_bytes()).hexdigest()
        counts[entry['category']] = counts.get(entry['category'], 0) + 1
    if input_stamp(project, entries, config) != stamp:
        raise ValueError('Cel inputs changed during build; rebuild required')
    manifest = {'version': 2, 'stamp': stamp, 'files': {e['path']: e['scope'] for e in entries},
                'variants': {e['path']: variant_relative(e['path']) for e in entries}, 'sha256': hashes}
    temporary = output / 'manifest.json.tmp'
    temporary.write_text(json.dumps(manifest, sort_keys=True, indent=2) + '\n')
    temporary.replace(output / 'manifest.json')
    elapsed = time.perf_counter() - started
    report = {'counts': counts, 'total_files': len(entries),
              'touch_canvas_mismatches': mismatches, 'classification': classification, 'files': entries}
    (output / 'report.json').write_text(json.dumps(report, sort_keys=True, indent=2) + '\n')
    # Keep generated output byte deterministic; elapsed time belongs to stdout.
    print('CEL_BUILD ' + json.dumps(dict(seconds=elapsed, **{k: report[k] for k in ['counts', 'total_files', 'touch_canvas_mismatches']})), flush=True)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['build', 'inventory', 'status'])
    parser.add_argument('--project', type=Path, default=PROJECT)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--if-stale', action='store_true')
    args = parser.parse_args()
    if args.command == 'build':
        build(args.project, args.output, args.if_stale)
    else:
        from cel_look_inventory import inventory
        entries, classification = inventory(args.project)
        if args.command == 'status':
            current, reason = status(args.project, args.output or args.project / OUTPUT_DIRECTORY, entries, settings())
            print('CEL_STATUS ' + reason)
            raise SystemExit(0 if current else 1)
        print(json.dumps((entries, classification), indent=2))


if __name__ == '__main__':
    main()
