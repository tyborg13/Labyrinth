"""Bridge adapter: fitting measures actual Blender silhouettes, never v1 proxies."""
from __future__ import annotations

import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image

from ..raster import Raster
from .contract import DEFAULT_BUNDLE, digest, validate
from .capture_manifest import read_manifest, require_image


DEFAULT_BLENDER = '/Applications/Blender.app/Contents/MacOS/Blender'
BUILDER = Path(__file__).with_name('build.py')
BACKEND_DEFAULTS = {'job_timeout_s': 900}


def command(spec_path, output, blender=DEFAULT_BLENDER, bundle=None, silhouettes=False, gallery=False):
    result = [sys.executable, str(Path(__file__).with_name('bridge_client.py')),
              '--timeout', str(BACKEND_DEFAULTS['job_timeout_s']),
              str(BUILDER), '--', str(Path(spec_path).resolve()), str(Path(output).resolve()), '--engine', 'cycles']
    if bundle:
        result += ['--bundle', str(bundle)]
    if silhouettes:
        result.append('--silhouettes-only')
    if gallery:
        result.append('--gallery')
    return result


def load_render(spec, folder, view='front', image_folder=None):
    folder = Path(folder)
    images = Path(image_folder) if image_folder is not None else folder
    report = json.loads((folder / 'build_report.json').read_text())
    if report['spec_hash'] != digest(spec):
        raise ValueError('Blender render belongs to a different spec')
    names = list(spec['labels'])
    masks = {}
    manifest = read_manifest(folder, digest(spec), ('full', 'fit', 'preview', 'silhouettes'), images)
    fit_only = manifest['mode'] in ('fit', 'preview')
    for name in ([] if fit_only else names):
        require_image(manifest, f'{view}_solo_{name}.png')
        with Image.open(images / f'{view}_solo_{name}.png') as image:
            masks[name] = np.asarray(image.convert('RGBA'))[..., 3] >= 128
    if fit_only:
        for name, filename in [('__body__', f'{view}_body.png'), (spec['fit'].get('head_part', 'head'), f'{view}_head.png')]:
            require_image(manifest, filename)
            with Image.open(images / filename) as image:
                masks[name] = np.asarray(image.convert('RGBA'))[..., 3] >= 128
    require_image(manifest, f'{view}_silhouette.png')
    with Image.open(images / f'{view}_silhouette.png') as image:
        foreground = np.asarray(image.convert('RGBA'))[..., 3] >= 128
    owners = np.where(foreground, 0, -1).astype(np.int16)
    # Numerical fitting uses silhouettes and solos. A parts capture, when present,
    # additionally provides depth-tested owners for comparison tooling.
    parts = images / f'{view}_parts.png'
    if parts.name in manifest['images']:
        with Image.open(parts) as image:
            pixels = np.asarray(image.convert('RGBA'))[..., :3].astype(float)
        distance = np.full(foreground.shape, np.inf)
        for i, name in enumerate(names):
            linear = np.array(spec['labels'][name])
            srgb = np.where(linear <= .0031308, linear * 12.92, 1.055 * linear ** (1 / 2.4) - .055) * 255
            error = ((pixels - srgb) ** 2).sum(-1)
            win = foreground & (error < distance)
            owners[win], distance[win] = i, error[win]
    if any(mask.shape != foreground.shape for mask in masks.values()):
        raise ValueError('Inconsistent Blender render sizes')
    joints = json.loads((folder / 'joints_px.json').read_text())[view]
    if set(joints) != set(spec['joints']):
        raise ValueError('Blender render joint coverage differs from spec')
    return Raster(names, owners, masks, joints)


class BlenderRenderer:
    def __init__(self, output, blender=DEFAULT_BLENDER, bundle=None):
        self.output = Path(output).resolve()
        self.blender = blender
        self.bundle = bundle

    def capture(self, spec, silhouettes=True, gallery=False):
        validate(spec)
        folder = self.output / digest(spec)
        folder.mkdir(parents=True, exist_ok=True)
        path = folder / 'spec.json'
        path.write_text(json.dumps(spec, indent=2, allow_nan=False) + '\n')
        from .bridge_client import run_job
        cmd = [str(path), str(folder), '--engine', 'cycles']
        if self.bundle:
            cmd += ['--bundle', str(self.bundle)]
        if silhouettes:
            cmd.append('--fit-only')
        if gallery:
            cmd.append('--gallery')
        result = run_job(BUILDER, cmd, timeout_s=BACKEND_DEFAULTS['job_timeout_s'])
        (folder / 'blender.log').write_text(result['stdout'])
        (folder / 'bridge_result.json').write_text(json.dumps({k: v for k, v in result.items() if k != 'stdout'}, indent=2))
        if result['exit']:
            raise ValueError(f"Blender bridge exited {result['exit']}; see {folder / 'blender.log'}")
        return folder

    def __call__(self, spec, view='front'):
        folder = self.capture(spec)
        return load_render(spec, folder, view)
