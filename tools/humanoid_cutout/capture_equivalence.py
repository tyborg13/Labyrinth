"""Headless before/after evidence comparison; never changes gate reports.

Compare snapshots made by each checkout's own proof commands, including all
JSON gate results and pocket/detached diagnostics. Only timestamp and path
values are normalized. Texture hashes are compared independently of storage
hashes. Reels are compared after decoding with ffmpeg (not by container hash).
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess

from .native_frames import load_frame

TIMESTAMP_FIELDS = frozenset(('timestamp', 'created_at', 'generated_at', 'captured_at'))
PATH_FIELDS = frozenset(('path', 'output', 'capture', 'directory', 'failure_output'))


def canonical(value, roots=(), key=''):
    if key in TIMESTAMP_FIELDS:
        return '<timestamp>'
    if isinstance(value, dict):
        return {k: canonical(v, roots, k) for k, v in sorted(value.items())}
    if isinstance(value, list):
        return [canonical(v, roots, key) for v in value]
    if isinstance(value, str):
        for root in roots:
            value = value.replace(str(root), '<capture>')
        # Field-specific paths keep their filename so different frames cannot
        # disappear behind a generic placeholder. Errors keep all other text.
        if key in PATH_FIELDS and value.startswith('/'):
            return '<path>/' + Path(value).name
    return value


def json_bytes(path, roots):
    return json.dumps(canonical(json.loads(path.read_bytes()), roots), sort_keys=True,
                      separators=(',', ':'), ensure_ascii=False).encode()


def texture_hashes(manifest):
    fields = ('view', 'stage', 'clip', 'frame', 'pixels_sha256')
    return [{key: row[key] for key in fields if key in row}
            for row in manifest['frames'] if 'pixels_sha256' in row]


def decoded_hashes(path):
    result = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(path), '-map', '0:v:0',
                             '-f', 'framemd5', '-'], check=True, capture_output=True, text=True)
    return [line for line in result.stdout.splitlines() if not line.startswith('#software:')]


def frame_files(value):
    """All captured surfaces referenced by a manifest, including clean layers."""
    result = set()
    if isinstance(value, dict):
        for key, item in value.items():
            if isinstance(item, str) and (key in ('file', 'checks', 'rest', 'before', 'after', 'overview') or key.endswith('_file')):
                result.add(item)
            elif isinstance(item, (dict, list)):
                result.update(frame_files(item))
    elif isinstance(value, list):
        for item in value:
            result.update(frame_files(item))
    return result


def native_files(folder, manifest):
    index = folder / 'native_storage.json'
    if index.is_file():
        return set(json.loads(index.read_bytes())['files'])
    # Legacy writers have no storage index; the capture directory contains
    # their original PNG payloads, including idle-comparison and auxiliary
    # pixel/seam surfaces that older main manifests did not enumerate.
    return frame_files(manifest) | {
        p.relative_to(folder).as_posix() for p in folder.rglob('*.png')
        if 'proof_exports' not in p.relative_to(folder).parts and not p.name.startswith('full_')}


def compare(before, after, *, reports=(), reels=(), captures=()):
    errors, checks = [], []
    roots = (before.resolve(), after.resolve())
    if not reports and not reels and not captures:
        raise ValueError('Specify gate reports, reels and/or capture directories')
    for relative in reports:
        a, b = before / relative, after / relative
        if json_bytes(a, roots) != json_bytes(b, roots):
            errors.append('Gate JSON differs: ' + relative)
        checks.append({'report': relative, 'canonical_sha256': hashlib.sha256(json_bytes(a, roots)).hexdigest()})
    for relative in captures:
        a, b = before / relative, after / relative
        old, new = [json.loads((folder / 'frames.json').read_bytes()) for folder in (a, b)]
        if len(old['frames']) != len(new['frames']):
            errors.append('Frame count differs: ' + relative)
            continue
        old_hashes, new_hashes = texture_hashes(old), texture_hashes(new)
        if old_hashes != new_hashes:
            errors.append('Renderer texture hashes differ: ' + relative)
        if any('stage' in r for r in old['frames']) and len(old_hashes) != len(old['frames']):
            errors.append('Missing production texture hashes: ' + relative)
        # Native layers and pair/reel inputs must reproduce every original pixel.
        # Production crops compare their full captured region; full clip refs
        # intentionally cover static outside-board sampling, not changing FX.
        for index, (left, right) in enumerate(zip(old['frames'], new['frames'])):
            identity = ('view', 'stage', 'clip', 'frame', 'phase')
            if any(left.get(k) != right.get(k) for k in identity):
                errors.append(f'Frame identity differs: {relative}/{index}')
                continue
            if 'stage' not in right:
                continue  # Compared once with all referenced native surfaces below.
            aa = load_frame(a / left['file']).convert('RGBA')
            bb = load_frame(b / right['file']).convert('RGBA')
            if 'stage' in right and 'crop' in new:
                x, y, w, h = new['crop']
                aa, bb = [im.crop((x, y, x+w, y+h)) for im in (aa, bb)]
            if aa.size != bb.size or aa.tobytes() != bb.tobytes():
                errors.append(f'Pixels differ: {relative}/{index}')
        if not any('stage' in row for row in old['frames']):
            old_files, new_files = native_files(a, old), native_files(b, new)
            if old_files != new_files:
                errors.append('Native surface sets differ: ' + relative)
            for filename in sorted(old_files & new_files):
                aa, bb = [load_frame(folder / filename).convert('RGBA') for folder in (a, b)]
                if aa.size != bb.size or aa.tobytes() != bb.tobytes():
                    errors.append('Native surface pixels differ: ' + relative + '/' + filename)
        checks.append({'capture': relative, 'frames': len(old['frames']), 'texture_hashes': len(old_hashes)})
    for relative in reels:
        if decoded_hashes(before / relative) != decoded_hashes(after / relative):
            errors.append('Decoded reel frames differ: ' + relative)
        checks.append({'reel': relative, 'comparison': 'exact decoded frames (framemd5)'})
    return {'ok': not errors, 'errors': errors, 'checks': checks,
            'json_comparison': 'canonical UTF-8 bytes; timestamps and paths only',
            'reel_comparison': 'exact decoded frames; no tolerance'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--before', type=Path, required=True)
    parser.add_argument('--after', type=Path, required=True)
    parser.add_argument('--report', action='append', default=[])
    parser.add_argument('--reel', action='append', default=[])
    parser.add_argument('--capture', action='append', default=[])
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    try:
        result = compare(args.before, args.after, reports=args.report, reels=args.reel, captures=args.capture)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        result = {'ok': False, 'errors': [str(error)]}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print('CAPTURE EQUIVALENCE: ' + ('PASS' if result['ok'] else 'FAIL'))
    for error in result.get('errors', []):
        print(error)
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
