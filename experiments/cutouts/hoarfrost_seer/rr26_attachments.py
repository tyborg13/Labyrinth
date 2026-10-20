"""Apply the director's neighbour-weight policy to the two painted hem tips."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools'))
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.texel_attachments import base_mesh, attach

CASE = ROOT / 'experiments/cutouts/hoarfrost_seer/rr10'


def apply(layout):
    definitions = read_json(CASE / 'rr26_hem_attachments.json')[layout['facing']]
    anatomy = read_json(CASE / 'anatomy.json')
    for mesh in layout['joint_meshes']:
        if mesh['name'] not in definitions: continue
        base = base_mesh(mesh, layout, anatomy['meshes'][mesh['name']])
        mesh.clear()
        mesh.update(attach(base, definitions[base['name']]))
    return layout


if __name__ == '__main__':
    for view in ('front', 'rear'):
        write_json(CASE / f'layouts/{view}.json', apply(read_json(CASE / f'layouts/{view}.json')))
    print('RR26 SEER HEM ATTACHMENTS: applied neighbour weights; paint and original body geometry retained')
