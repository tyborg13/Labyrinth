#!/usr/bin/env python3
"""Unit-local, read-only thin-gap diagnostic and approved-clip seam gate."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

IDS = ('tharokh', 'vyraketh', 'iskaldra', 'vaeloryx', 'noctyrax', 'zekarion')
MIN_AREA = 12
MIN_LENGTH = 10
EROSION_SIZE = 5
ALPHA_THRESHOLD = 16


def components(mask, diagonal=True):
    """8-connected run-length labeling; no SciPy/OpenCV dependency."""
    height, width = mask.shape
    labels = np.zeros((height, width), np.int32)
    parents = [0]
    def root(n):
        while parents[n] != n:
            parents[n] = parents[parents[n]]
            n = parents[n]
        return n
    previous = []
    for y in range(height):
        edges = np.flatnonzero(np.diff(np.r_[False, mask[y], False]))
        current = []
        j = 0
        for x0, x1 in edges.reshape(-1, 2):
            while j < len(previous) and previous[j][1] < x0 + (0 if diagonal else 1):
                j += 1
            overlaps = []
            for left, right, label in previous[j:]:
                if left > x1 - (0 if diagonal else 1): break
                overlaps.append(root(label))
            label = min(overlaps) if overlaps else len(parents)
            if not overlaps: parents.append(label)
            for other in overlaps: parents[root(other)] = label
            labels[y, x0:x1] = label
            current.append((x0, x1, label))
        previous = current
    lookup = np.asarray([root(n) for n in range(len(parents))])
    labels = lookup[labels]
    return labels, [int(n) for n in np.unique(labels) if n]


def enclosed(occupied):
    labels, names = components(~occupied, diagonal=False)
    outside = set(np.r_[labels[0], labels[-1], labels[:, 0], labels[:, -1]])
    inside = [n for n in names if n not in outside]
    return np.isin(labels, inside)


def thin_gaps(occupied, rest):
    candidates = enclosed(occupied) & ~enclosed(rest)
    labels, names = components(candidates)
    result = []
    for name in names:
        ys, xs = np.nonzero(labels == name)
        if len(xs) < MIN_AREA: continue
        x0, x1, y0, y1 = int(xs.min()), int(xs.max()) + 1, int(ys.min()), int(ys.max()) + 1
        if max(x1 - x0, y1 - y0) < MIN_LENGTH: continue
        mask = np.pad(labels[y0:y1, x0:x1] == name, EROSION_SIZE)
        eroded = np.asarray(Image.fromarray(mask.astype(np.uint8) * 255).filter(ImageFilter.MinFilter(EROSION_SIZE)))
        if eroded.any(): continue
        result.append({'area': len(xs), 'bbox': [x0, y0, x1, y1], 'pixels': np.column_stack((xs, ys)).tolist()})
    return result


def alpha(path, threshold=ALPHA_THRESHOLD):
    with Image.open(path) as image:
        return np.asarray(image.convert('RGBA'))[..., 3] > threshold


def analyze(folder, threshold=ALPHA_THRESHOLD):
    records = []
    missing = []
    for dragon in IDS:
        for view in ('front', 'mirrored_front'):
            rest_path = next(iter(sorted((folder / dragon).glob(view + '_00_*.png'))), folder / dragon / (view + '_00_missing.png'))
            if not rest_path.exists():
                missing.append(str(rest_path)); continue
            rest = alpha(rest_path, threshold)
            baselines = sorted((folder / dragon).glob(view + '_baseline_*.png'))
            counts = [len(thin_gaps(alpha(path, threshold), rest)) for path in baselines]
            baseline = max(counts) if counts else None
            for path in sorted((folder / dragon).glob(view + '_[0-9][0-9]_*.png')):
                gaps = thin_gaps(alpha(path, threshold), rest)
                records.append({'dragon': dragon, 'view': view, 'file': str(path),
                                'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                                'count': len(gaps), 'baseline': baseline, 'gaps': gaps})
            if baseline is None: missing.append(f'{dragon}/{view}: approved baseline absent')
    return {'threshold': threshold, 'min_area': MIN_AREA, 'min_length': MIN_LENGTH,
            'erosion_size': EROSION_SIZE, 'records': records, 'missing': missing}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--frames', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--diagnostic-only', action='store_true')
    parser.add_argument('--cpu', type=Path, help='Matching CPU bounds/provenance for open-attachment and single-painted-part gates')
    parser.add_argument('--alpha-threshold', type=int, default=ALPHA_THRESHOLD)
    args = parser.parse_args()
    report = analyze(args.frames, args.alpha_threshold)
    failures = [r for r in report['records'] if r['baseline'] is not None and r['count'] > r['baseline']]
    report['attachment_failures'] = []
    report['single_part_failures'] = []
    if args.cpu:
        from cpu_check import attachment_gaps, part_failures, label_for, calibration, stale_sources
        from cpu_render import mirror
        for row in report['records']:
            path = args.cpu / row['dragon'] / ('bounds_' + label_for(row['file'], row['view']) + '.npz')
            data = np.load(path)
            witness = data['attachment']
            if row['view'] == 'mirrored_front': witness = mirror(witness)
            gaps = attachment_gaps(alpha(row['file'], args.alpha_threshold), witness)
            if gaps: report['attachment_failures'].append({'file': row['file'], 'gaps': gaps})
        for dragon in IDS:
            report['single_part_failures'].extend(part_failures(args.cpu / dragon))
        report['cpu_calibration'] = calibration(args.frames, args.cpu)
        if not args.diagnostic_only: report['missing'].extend(stale_sources(args.cpu))
    elif not args.diagnostic_only:
        report['missing'].append('matching CPU painted-part provenance is required')
    report['ok'] = not report['missing'] and not failures and not report['attachment_failures'] and not report['single_part_failures'] and report.get('cpu_calibration', {'ok': True})['ok']
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    for dragon in IDS:
        rows = [r for r in report['records'] if r['dragon'] == dragon and r['view'] == 'front']
        print(dragon, 'thin gaps:', ', '.join(str(r['count']) for r in rows), 'baseline:', rows[0]['baseline'] if rows else 'missing')
    tail = [g for r in report['attachment_failures'] if '/tharokh/' in r['file'] and 'front_04_' in r['file'] for g in r['gaps']]
    print('THAROKH TAIL:', 'FLAGGED' if tail else 'not flagged', [(g['area'], g['bbox']) for g in tail])
    print('ROAR SEAM GATE:', 'PASS' if report['ok'] else 'INCOMPLETE' if report['missing'] else 'FAIL', str(args.output))
    return 0 if args.diagnostic_only or report['ok'] else 1

if __name__ == '__main__': raise SystemExit(main())
