"""Compare shared meshes to committed legacy renders, with per-part evidence."""
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image

from .raster import rasterise
from .shrike_spec import legacy_shrike


PROJECT = Path(__file__).resolve().parents[3]
COLOR_CONFIG = Path('/Applications/Blender.app/Contents/Resources/5.2/datafiles/colormanagement/config.ocio')
BASELINES = {
    'chainbound_gaoler': {'front': 'chainbound_gaoler/mq3_maquette_renders/front_parts.png',
                         'rear': 'chainbound_gaoler/mq3_maquette_renders/rear_parts.png',
                         'joints': 'chainbound_gaoler/mq3_maquette_renders/joints_px.json', 'solos': True},
    'frostglass_lancer': {'front': 'frostglass_lancer/mq1_front_v3/refs/01_maquette_front_parts.png',
                         'rear': 'frostglass_lancer/mq1_rear_v3/refs/01_maquette_rear_parts.png'},
    'lightning_wisp': {'front': 'lightning_wisp/mq1_front_v2/refs/02_maquette_front_parts_r3.png',
                       'rear': 'lightning_wisp/mq1_rear/refs/01_maquette_rear_parts.png'},
    'shale_bloomer': {'front': 'shale_bloomer/mq3_front_v2/refs/02_maquette_front_parts_r9.png',
                     'rear': 'shale_bloomer/mq3_rear/refs/01_maquette_rear_parts.png'},
    'gust_shrike': {'front': 'gust_shrike/mq2_front/refs/01_maquette_front_parts.png',
                    'rear': 'gust_shrike/mq2_rear/refs/01_maquette_rear_parts.png',
                    'joints_absolute': 'experiments/cutouts/gust_shrike/mq2/source/maquette/joints_px.json',
                    'solos_absolute': 'experiments/cutouts/gust_shrike/mq2/source/maquette'},
}


def read_spec(path):
    return json.loads(Path(path).read_text())


def label_masks(path, labels, palette):
    pixels = np.asarray(Image.open(path).convert('RGBA'))
    rgb = pixels[..., :3].astype(float)
    alpha = pixels[..., 3] >= 128
    foreground = alpha & (abs(rgb - [0, 255, 0]).max(-1) > 60)
    palette = np.array([palette[name] for name in labels])
    # Decode only foreground; nearest palette handles antialiasing at boundaries.
    owners = np.full(foreground.shape, -1, dtype=np.int16)
    owners[foreground] = ((rgb[foreground, None, :] - palette[None]) ** 2).sum(-1).argmin(-1)
    return {part: owners == i for i, part in enumerate(labels)}


def iou(a, b):
    union = (a | b).sum()
    return float((a & b).sum() / union) if union else 1.


def compare(spec, renders, joints=None, solo_folder=None, palette=None):
    if palette is None:
        # Reuse the existing exact OCIO/LUT decoder, without changing the
        # protected cutout tool or launching Blender.
        sys.path.insert(0, str(PROJECT / 'tools'))
        from maquette_cutout import display_palette
        palette = display_palette(spec, COLOR_CONFIG)
    result = {}
    for view, path in renders.items():
        raster = rasterise(spec, view)
        masks = label_masks(path, spec['labels'], palette)
        parts = {}
        for name, mask in masks.items():
            actual = raster.owners == raster.names.index(name) if name in raster.names else np.zeros_like(mask)
            entry = {'visible_iou': iou(mask, actual), 'baseline_pixels': int(mask.sum()), 'raster_pixels': int(actual.sum())}
            solo = Path(solo_folder) / f'{view}_solo_{name}.png' if solo_folder else None
            if solo and solo.is_file():
                pixels = np.asarray(Image.open(solo).convert('RGBA'))
                baseline = pixels[..., 3] >= 128
                entry['solo_iou'] = iou(baseline, raster.masks.get(name, np.zeros_like(mask)))
            parts[name] = entry
        joint_error = None
        if joints is not None:
            joint_error = max(float(np.linalg.norm(np.array(raster.joints[name]) - p)) for name, p in joints[view].items())
        result[view] = {'parts': parts, 'minimum_visible_iou': min(p['visible_iou'] for p in parts.values()),
                        'minimum_part_silhouette_iou': min(p.get('solo_iou', p['visible_iou']) for p in parts.values()),
                        'silhouette_iou': iou(np.logical_or.reduce(list(masks.values())), raster.silhouette),
                        'minimum_solo_iou': min((p['solo_iou'] for p in parts.values() if 'solo_iou' in p), default=None),
                        'max_joint_error_px': joint_error}
    return result


def compare_renders(spec, baseline, candidate):
    """Director's old/new Blender proof: compare solo alpha, no label decoding."""
    result = {}
    baseline, candidate = Path(baseline), Path(candidate)
    old_joints = read_spec(baseline / 'joints_px.json')
    new_joints = read_spec(candidate / 'joints_px.json')
    for view in ('front', 'rear'):
        parts = {}
        for part in spec['labels']:
            masks = []
            for folder in (baseline, candidate):
                path = folder / f'{view}_solo_{part}.png'
                if not path.is_file():
                    raise ValueError('Missing solo proof: ' + str(path))
                masks.append(np.asarray(Image.open(path).convert('RGBA'))[..., 3] >= 128)
            if masks[0].shape != masks[1].shape:
                raise ValueError('Render proof sizes differ')
            parts[part] = {'solo_iou': iou(*masks)}
        error = max(float(np.linalg.norm(np.array(new_joints[view][joint]) - value)) for joint, value in old_joints[view].items())
        result[view] = {'parts': parts, 'minimum_part_silhouette_iou': min(v['solo_iou'] for v in parts.values()), 'max_joint_error_px': error}
    return result


def baseline_report():
    jobs = PROJECT / 'spec/art_identity/jobs'
    result = {}
    for name, definition in BASELINES.items():
        spec = legacy_shrike() if name == 'gust_shrike' else read_spec(PROJECT / 'spec/art_identity/maquettes' / name / 'spec.json')
        joint_path = (jobs / definition['joints']) if 'joints' in definition else (PROJECT / definition['joints_absolute'] if 'joints_absolute' in definition else None)
        solo = jobs / Path(definition['front']).parent if definition.get('solos') else (PROJECT / definition['solos_absolute'] if 'solos_absolute' in definition else None)
        result[name] = compare(spec, {view: jobs / definition[view] for view in ('front', 'rear')},
                               read_spec(joint_path) if joint_path else None, solo)
        result[name]['baseline_files'] = definition
    return result
