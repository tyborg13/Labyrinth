"""Case-owned anatomy. Runtime layouts and approved paint remain immutable."""
from pathlib import Path

from cutout_pipeline.cases import read_json


def load(case):
    data = read_json(Path(case) / 'anatomy.json')
    if data['schema_version'] != 1:
        raise ValueError('Unsupported humanoid anatomy schema')
    return data


def for_layout(layout):
    if 'anatomy' in layout:
        return layout['anatomy']
    path = layout['motion_data']
    if path.startswith('res://'):
        path = Path(__file__).resolve().parents[2] / path[6:]
    return load(Path(path).parent)


def owner_ids(ownership):
    return {name: index + 1 for index, name in enumerate(ownership['names'])}
