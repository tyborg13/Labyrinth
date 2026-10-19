"""Replay covered sleeve-edge underlaps without rebuilding approved Seer cuts."""
from pathlib import Path
import sys

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools'))
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.skin_layers import layer
from maquette_motion.features import source_pixels
from maquette_motion.bleed import edge_texels
from maquette_motion.material_palette import rules, outline_class

CASE = ROOT / 'experiments/cutouts/hoarfrost_seer/rr10'


def apply(layout):
    view = layout['facing']
    anatomy = read_json(CASE / 'anatomy.json')
    recipes = read_json(CASE / 'rr26_underlaps.json').get(view, [])
    for recipe in recipes:
        name, garment = recipe['name'], recipe['garment']
        owner = next(p for p in layout['parts'] if p['name'] == garment)
        source = source_pixels(CASE, owner)
        target = np.zeros(source.shape[:2], dtype=bool)
        for x, y in recipe['source_points']:
            if not source[y, x, 3]:
                raise ValueError('Underlap must remain under its own approved paint')
            target[y, x] = True
        # Retain the source edge's existing minimum tuck as transparent mesh
        # margin. Its common garment weight field is not retuned or replaced.
        edge = np.asarray(recipe['edge_source_points'])
        depth = anatomy['joint_continuations']['depth_px']
        low, high = edge.min(axis=0) - depth, edge.max(axis=0) + depth + 1
        bbox = [*low.tolist(), *high.tolist()]
        left, top, right, bottom = bbox
        if int(target[top:bottom, left:right].sum()) != int(target.sum()):
            raise ValueError('Underlap target lies outside its traced edge margin')
        material_rules = rules(CASE, view)
        paint = edge_texels(source, target, material_rules)
        checks = np.zeros_like(paint)
        checks[target] = [255, 255, 0, 255]
        checks[target & outline_class(paint, material_rules), 2] = 255
        paths = {}
        for kind, image in (('pieces', paint), ('checks', checks)):
            path = CASE / kind / view / (name + '.png')
            Image.fromarray(image[top:bottom, left:right]).save(path)
            Path(str(path) + '.import').write_text('[remap]\n\nimporter="keep"\n')
            paths[kind] = str(path.relative_to(CASE))
        existing = [p for p in layout['parts'] if p['name'] != name]
        row = {'name': name, 'logical_part': garment, 'bone': owner['bone'],
               'file': paths['pieces'], 'offset': bbox[:2], 'bbox': bbox,
               'z_index': min(p['z_index'] for p in existing) - 1,
               'hidden_material': True}
        layout['parts'] = existing + [row]
        layout['joint_meshes'] = [m for m in layout['joint_meshes'] if m['name'] != name] + [
            layer(row, garment, owner['bbox'], layout['joints'], row['z_index'], True,
                  recipe=anatomy['meshes'][garment])]
        layout['proof_layers'][name] = {'mask': paths['checks'], 'mask_offset': bbox[:2],
            'z_index': row['z_index'], 'source': row['file'], 'rigid': False,
            'source_sha256': digest(CASE / row['file'])}
    return layout


if __name__ == '__main__':
    for view in ('front', 'rear'):
        layout = apply(read_json(CASE / f'layouts/{view}.json'))
        write_json(CASE / f'layouts/{view}.json', layout)
    print('RR26 SEER SLEEVE UNDERLAP: installed own-piece coverage; original cuts and poses retained')
