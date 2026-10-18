"""Stage compact native deliveries, hash discarded evidence, and remove it.

The measured recipe is the build input. spec_native.json, blends and caches
are generated intermediates. Clays retain every native RGBA pixel and colour
chunk; PNG stamps are removed. Mask packing also zeros RGB behind zero alpha.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct

import numpy as np
from PIL import Image

from .capture_manifest import read_manifest, write_manifest
from .compile_recipe import compile_recipe
from .contract import digest

CURATION_DEFAULTS = {'budget_bytes': 6_000_000, 'png_compression': 9}


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def write(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('w') as stream:
        json.dump(data, stream, separators=(',', ':'), allow_nan=False)
        stream.write('\n')
        stream.flush()
        os.fsync(stream.fileno())


def canonical_png(source, destination, mask=False):
    """Remove volatile Blender stamps; retain colour chunks and all clay RGBA."""
    from PIL.PngImagePlugin import PngInfo
    pixels = np.array(Image.open(source).convert('RGBA'))
    packed = pixels.copy()
    if mask:
        packed[packed[:, :, 3] == 0, :3] = 0
    info = PngInfo()
    raw = Path(source).read_bytes()
    position = 8
    while position < len(raw):
        length = struct.unpack('>I', raw[position:position + 4])[0]
        kind = raw[position + 4:position + 8]
        if kind in (b'gAMA', b'cHRM', b'sRGB', b'iCCP'):
            info.add(kind, raw[position + 8:position + 8 + length])
        position += length + 12
    Image.fromarray(packed).save(destination, pnginfo=info, optimize=True,
                               compress_level=CURATION_DEFAULTS['png_compression'])
    actual = np.array(Image.open(destination).convert('RGBA'))
    if not (np.array_equal(actual, pixels) if not mask else
            np.array_equal(actual[:, :, 3], pixels[:, :, 3]) and
            np.array_equal(actual[pixels[:, :, 3] > 0], pixels[pixels[:, :, 3] > 0])):
        raise ValueError('Mask packing changed a visible pixel or alpha')


def stage(folder, source):
    folder, source = Path(folder), Path(source)
    spec = compile_recipe(json.loads((folder / 'measurements.json').read_text()))
    manifest = read_manifest(source, digest(spec), ('full',))
    output = folder / 'delivery'
    output.mkdir(exist_ok=True)
    original, pixel_hashes = {}, {}
    for name in manifest['images']:
        original[name] = sha(source / name)
        clay = name in ('front_clay.png', 'rear_clay.png')
        canonical_png(source / name, output / name, mask=not clay)
        if clay:
            pixel_hashes[name] = hashlib.sha256(Image.open(source / name).convert('RGBA').tobytes()).hexdigest()
    for name in ('joints_px.json', 'build_report.json', 'capture_checks.json', 'facing_report.json',
                 'ownership_validation.json', 'solo_coverage.json', 'cloak_side.json'):
        if (source / name).exists():
            shutil.copyfile(source / name, output / name)
    write(output / 'native_capture_manifest.json', manifest)
    write_manifest(output, digest(spec), 'full', list(manifest['images']))
    for name in ('recipe_proof.json', 'exact_native_replay.json'):
        shutil.copyfile(source / 'determinism' / name, output / name)
    write(output / 'provenance.json', {'schema': 1, 'spec_hash': digest(spec),
        'recipe_sha256': sha(folder / 'measurements.json'), 'native_image_sha256': original,
        'native_clay_rgba_sha256': pixel_hashes,
        'generated_spec': 'spec_native.json is compiled output, not a tracked input. Regenerate from measurements.json.',
        'packing': 'Clays preserve every native RGBA sample and colour chunk; volatile Blender path/date/render-time stamps are removed for reproducible PNG hashes. Other capture PNGs also zero RGB behind alpha=0; every alpha and every visible RGBA sample remains exact.'})
    print('DELIVERY_STAGE: PASS; ' + folder.name)


def inventory(folder):
    return sorted(p for p in Path(folder).rglob('*') if p.is_file())


def discard_evidence(folder, paths, archive):
    folder, archive = Path(folder).resolve(), Path(archive)
    paths = [Path(p) for p in paths]
    if any(p.is_symlink() or not p.resolve().is_relative_to(folder) for p in paths):
        raise ValueError('Evidence removal must stay inside its figure tree')
    paths = [p.resolve() for p in paths]
    entries = [[str(p.relative_to(folder)), p.stat().st_size, sha(p)] for p in paths]
    previous = json.loads(archive.read_text()).get('files', []) if archive.exists() else []
    write(archive, {'schema': 1, 'columns': ['path', 'bytes', 'sha256'],
        'files': previous + entries, 'dropped_bytes_this_run': sum(e[1] for e in entries)})
    # The complete hash inventory is durable before the first file is removed.
    for path in paths:
        path.unlink()


def curate(folder):
    folder = Path(folder).resolve()
    archive = folder / 'discarded_proof_sha256.json'
    manifest = folder / 'COMMIT_MANIFEST.txt'
    keep = {p for p in inventory(folder) if p.is_relative_to(folder / 'delivery')}
    keep |= {folder / 'measurements.json', folder / 'README.md', folder / '.gdignore', archive, manifest}
    if not (folder / 'delivery/provenance.json').is_file() or not (folder / 'README.md').is_file():
        raise ValueError('Stage and document the delivery before curation')
    dropped = [p for p in inventory(folder) if p not in keep]
    discard_evidence(folder, dropped, archive)
    manifest.write_text('# Paths relative to this figure. Shared builder: ../blender/*.py\n' +
        '# Canonical build specification: measurements.json; generated spec_native.json is omitted.\n' +
        '\n'.join(sorted(str(p.relative_to(folder)) for p in keep)) + '\n')
    for path in sorted(folder.rglob('*'), key=lambda p: len(p.parts), reverse=True):
        if path.is_dir() and not any(path.iterdir()):
            path.rmdir()
    return verify(folder)


def verify(folder):
    folder = Path(folder)
    listed = {line for line in (folder / 'COMMIT_MANIFEST.txt').read_text().splitlines() if line and not line.startswith('#')}
    files = inventory(folder)
    actual = {str(p.relative_to(folder)) for p in files}
    if listed != actual:
        raise ValueError('Commit manifest differs from disk: ' + str(sorted(listed ^ actual)))
    if any('.blend' in p.suffixes for p in files):
        raise ValueError('Native blend retained in curated tree')
    spec = compile_recipe(json.loads((folder / 'measurements.json').read_text()))
    read_manifest(folder / 'delivery', digest(spec), ('full',))
    provenance = json.loads((folder / 'delivery/provenance.json').read_text())
    if provenance['spec_hash'] != digest(spec) or provenance['recipe_sha256'] != sha(folder / 'measurements.json'):
        raise ValueError('Curated provenance is stale')
    for name, expected in provenance['native_clay_rgba_sha256'].items():
        with Image.open(folder / 'delivery' / name) as image:
            if hashlib.sha256(image.convert('RGBA').tobytes()).hexdigest() != expected:
                raise ValueError('Curated clay differs from native pixels')
    for name in ('recipe_proof.json', 'exact_native_replay.json'):
        proof = json.loads((folder / 'delivery' / name).read_text())
        if not proof['passed'] or proof['spec_hash'] != digest(spec):
            raise ValueError('Native determinism proof is missing or stale')
    total = sum(p.stat().st_size for p in files)
    if total > CURATION_DEFAULTS['budget_bytes']:
        raise ValueError('Figure exceeds commit budget: ' + str(total))
    result = {'figure': folder.name, 'bytes': total, 'files': len(files), 'budget_bytes': CURATION_DEFAULTS['budget_bytes']}
    print('COMMIT_CURATION: PASS; ' + json.dumps(result, sort_keys=True))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('stage', 'curate', 'verify'))
    parser.add_argument('folder', type=Path)
    parser.add_argument('--capture', type=Path)
    args = parser.parse_args()
    if args.operation == 'stage':
        if args.capture is None:
            parser.error('stage requires --capture')
        stage(args.folder, args.capture)
    elif args.operation == 'curate':
        curate(args.folder)
    else:
        verify(args.folder)


if __name__ == '__main__':
    main()
