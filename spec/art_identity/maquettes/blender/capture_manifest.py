"""Bind each numerical capture input to its spec, mode, and exact bytes."""
import hashlib
import json
from pathlib import Path
import struct

CAPTURE_MODES = ('full', 'fit', 'preview', 'silhouettes', 'ownership')


def capture_mode(*, ownership_only=False, solo_parts=None, fit_only=False, preview=False, silhouettes_only=False):
    if ownership_only or solo_parts is not None:
        return 'ownership'
    return 'fit' if fit_only else 'preview' if preview else 'silhouettes' if silhouettes_only else 'full'


def selected_solos(labels, selection=None):
    """Validate a bounded solo batch without changing global material indices."""
    result = list(labels if selection is None else selection)
    if not result or len(set(result)) != len(result) or not set(result) <= set(labels):
        raise ValueError('Solo selection must contain distinct registered labels')
    return result


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def prepare_capture(folder, mode):
    if mode in ('full', 'silhouettes', 'ownership'):
        for view in ('front', 'rear'):
            for suffix in ('body', 'head'):
                (Path(folder) / f'{view}_{suffix}.png').unlink(missing_ok=True)


def write_manifest(folder, spec_hash, mode, images):
    folder = Path(folder)
    if mode not in CAPTURE_MODES:
        raise ValueError('Unknown capture mode: ' + mode)
    entries = {}
    for name in sorted(set(images)):
        path = folder / name
        header = path.read_bytes()[:24]
        if header[:8] != b'\x89PNG\r\n\x1a\n':
            raise ValueError('Capture is not a PNG: ' + name)
        entries[name] = {'sha256': sha256(path), 'size': list(struct.unpack('>II', header[16:24]))}
    manifest = {'schema': 1, 'spec_hash': spec_hash, 'mode': mode, 'images': entries,
                'joints_sha256': sha256(folder / 'joints_px.json')}
    (folder / 'capture_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    return manifest


def read_manifest(folder, spec_hash, modes, image_folder=None):
    folder = Path(folder)
    images = Path(image_folder) if image_folder is not None else folder
    path = folder / 'capture_manifest.json'
    if not path.is_file():
        raise ValueError('Blender capture manifest is missing')
    manifest = json.loads(path.read_text())
    if manifest['spec_hash'] != spec_hash:
        raise ValueError('Blender capture belongs to a different spec')
    if manifest['mode'] not in modes:
        raise ValueError('Incompatible Blender capture mode: ' + manifest['mode'])
    for name, entry in manifest['images'].items():
        if Path(name).is_absolute() or '..' in Path(name).parts:
            raise ValueError('Invalid capture image name')
        if not (images / name).is_file() or sha256(images / name) != entry['sha256']:
            raise ValueError('Stale or corrupt capture image: ' + name)
    if sha256(folder / 'joints_px.json') != manifest['joints_sha256']:
        raise ValueError('Stale capture joints')
    return manifest


def require_image(manifest, name):
    if name not in manifest['images']:
        raise ValueError('Image not named by current capture manifest: ' + name)
