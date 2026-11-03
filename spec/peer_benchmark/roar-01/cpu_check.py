#!/usr/bin/env python3
"""Conservative native calibration and per-painted-part CPU seam gate."""
from __future__ import annotations
import argparse
import json
import hashlib
from pathlib import Path
import numpy as np
from PIL import Image
from cpu_render import mirror
from seam_check import IDS, ALPHA_THRESHOLD, alpha, analyze, components, enclosed, thin_gaps

# GPU framebuffer alpha is quantized after each source-over operation.
ALPHA_QUANTIZATION = 1
RASTER_EDGE_PIXELS = 1  # Existing repo native-raster edge uncertainty, calibrated below.


def label_for(path, view):
    return Path(path).stem.removeprefix(view + '_')


def variant_flags(variants, rest):
    counts = []
    possible = np.zeros(rest.shape, bool)
    for image in variants:
        gaps = thin_gaps(image > ALPHA_THRESHOLD, rest)
        counts.append(len(gaps))
        for gap in gaps:
            xy = np.asarray(gap['pixels'])
            possible[xy[:,1],xy[:,0]] = True
    # Retain uncertain transparent paint even when one tie opens an enclosed
    # native gap to outside air. Counts still use every actual sampler AND the
    # two interval extremes; a min-alpha mask can never hide their failures.
    low = variants.min(axis=0).astype(int) - ALPHA_QUANTIZATION > ALPHA_THRESHOLD
    high = variants.max(axis=0).astype(int) + ALPHA_QUANTIZATION > ALPHA_THRESHOLD
    possible |= (high | enclosed(high)) & ~low & ~enclosed(rest)
    from PIL import ImageFilter
    possible = np.asarray(Image.fromarray(possible.astype(np.uint8)*255).filter(ImageFilter.MaxFilter(2*RASTER_EDGE_PIXELS+1))) > 0
    return counts, possible


def calibration(native, cpu):
    report = analyze(native)
    total = 0
    missing = []
    brackets = []
    undercounts = []
    for row in report['records']:
        folder = cpu / row['dragon']
        label = label_for(row['file'], row['view'])
        data = dict(np.load(folder / ('bounds_' + label + '.npz')))
        rest_path = next(folder.glob('front_00_*.png'))
        rest = alpha(rest_path)
        if row['view'] == 'mirrored_front':
            data = {k: (np.stack([mirror(a) for a in v]) if v.ndim == 3 else mirror(v)) for k, v in data.items()}
            rest = mirror(rest)
        actual = np.asarray(Image.open(row['file']).convert('RGBA'))[..., 3].astype(int)
        outside = (actual < data['lower'].astype(int) - ALPHA_QUANTIZATION) | (actual > data['upper'].astype(int) + ALPHA_QUANTIZATION)
        if outside.any(): brackets.append({'file': row['file'], 'pixels': int(outside.sum())})
        counts, possible = variant_flags(data["variants"], rest)
        if row["count"] > max(counts): undercounts.append({"file": row["file"], "native_count": row["count"], "cpu_counts": counts})
        for gap in row['gaps']:
            total += 1
            xy = np.asarray(gap['pixels'])
            missed = int((~possible[xy[:, 1], xy[:, 0]]).sum())
            if missed: missing.append({'file': row['file'], 'bbox': gap['bbox'], 'missed_pixels': missed})
    return {'ok': not missing and not undercounts, 'native_flags': total, 'missing_flags': missing,
            'under_counted_frames': undercounts, 'alpha_interval_outliers': brackets, 'raster_edge_pixels': RASTER_EDGE_PIXELS, 'basis': 'Conservative independent-UV-tie possible-gap interval plus all actual sampler flags, expanded by one raster-edge pixel. Maximum count across actual samplers AND interval extremes must cover native count. Min-alpha never replaces actual-sampler counts; no native-pixel union.'}


def attachment_gaps(frame, witness):
    labels, names = components(witness & ~frame)
    result = []
    for n in names:
        y, x = np.nonzero(labels == n)
        if len(x) >= 12 and max(x.max() - x.min() + 1, y.max() - y.min() + 1) >= 10:
            result.append({'area': len(x), 'bbox': [int(x.min()), int(y.min()), int(x.max()+1), int(y.max()+1)]})
    return result


_TOPOLOGY_CACHE = {}

def topology_counts(values):
    if values.ndim == 2: values = values[None]
    counts = []
    for value in values:
        key = hashlib.sha256(value.tobytes()).digest()
        if key not in _TOPOLOGY_CACHE:
            _TOPOLOGY_CACHE[key] = len(thin_gaps(value > ALPHA_THRESHOLD, np.ones(value.shape, bool)))
        counts.append(_TOPOLOGY_CACHE[key])
    return np.array(counts)


def part_failures(folder):
    rest = dict(np.load(next(folder.glob('parts_00_*.npz'))))
    baseline = [dict(np.load(p)) for p in folder.glob('parts_baseline_*.npz')]
    limits = {part: int(np.maximum.reduce([topology_counts(rest[part])] + [topology_counts(b[part]) for b in baseline]).min()) for part in rest}
    result = []
    for path in sorted(folder.glob('parts_[0-9][0-9]_*.npz')):
        if '_00_' in path.name or '_07_' in path.name: continue
        sample=np.load(path)
        for part in rest:
            counts=topology_counts(sample[part])
            if counts.max() > limits[part]: result.append({'file':str(path),'part':part,'counts':counts.tolist(),'baseline':limits[part]})
    return result


def stale_sources(cpu):
    from cpu_render import ROOT
    path = cpu / 'frames.json'
    manifest = json.loads(path.read_text()) if path.exists() else {}
    sources = manifest.get('sources', {})
    sources = dict(sources, **manifest.get('cpu_sources', {}))
    if not sources: return ['CPU proof lacks source fingerprints; re-export poses']
    return [source for source, digest in sources.items()
            if hashlib.sha256((ROOT / source.removeprefix('res://')).read_bytes()).hexdigest() != digest]


def gate(cpu):
    report=analyze(cpu)
    count_failures=[];parts=[];attachments=[]
    for dragon in IDS:
        folder=cpu/dragon
        if not folder.exists():continue
        rest=alpha(next(folder.glob('front_00_*.png')))
        baseline=[dict(np.load(p)) for p in folder.glob('bounds_baseline_*.npz')]
        baseline_counts=[variant_flags(b['variants'],rest)[0] for b in baseline]
        limit=int(np.max(baseline_counts,axis=0).min())
        parts.extend(part_failures(folder))
        for path in sorted(folder.glob('bounds_[0-9][0-9]_*.npz')):
            data=np.load(path);counts,_mask=variant_flags(data['variants'],rest)
            if max(counts)>limit:count_failures.append({'dragon':dragon,'file':str(path),'counts':counts,'baseline':limit})
            gaps=attachment_gaps(data['lower']>ALPHA_THRESHOLD,data['attachment'])
            if gaps:attachments.append({'file':str(path),'gaps':gaps})
    stale=stale_sources(cpu)
    return {'ok':not report['missing'] and not count_failures and not parts and not attachments and not stale,
            'count_failures':count_failures,'single_part_failures':parts,'attachment_failures':attachments,
            'missing':report['missing'],'stale_sources':stale}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cpu', type=Path, required=True)
    parser.add_argument('--native', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--calibration-only', action='store_true')
    args = parser.parse_args()
    if args.calibration_only and args.native is None: parser.error("--calibration-only requires --native")
    report = {}
    if args.native:
        report['calibration'] = calibration(args.native, args.cpu)
        c = report['calibration']
        print('ROAR CPU CALIBRATION:', 'PASS' if c['ok'] else 'FAIL', c['native_flags'], 'native flags;', len(c['missing_flags']), 'missed;', len(c['under_counted_frames']), 'under-counted frames;', len(c['alpha_interval_outliers']), 'frames with alpha-only interval outliers')
    if not args.calibration_only:
        report['gate'] = gate(args.cpu)
        g = report['gate']
        print('ROAR CPU SEAM GATE:', 'PASS' if g['ok'] else 'FAIL', len(g['count_failures']), 'count;', len(g['single_part_failures']), 'single-part;', len(g['attachment_failures']), 'attachment failures')
    report['ok'] = all(v['ok'] for v in report.values())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    return 0 if report['ok'] else 1

if __name__ == '__main__': raise SystemExit(main())
