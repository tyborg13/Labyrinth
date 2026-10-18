"""Case-owned anatomy. Runtime layouts and approved paint remain immutable."""
from pathlib import Path
from functools import lru_cache

from cutout_pipeline.cases import read_json
from .schema import validate as validate_schema


@lru_cache(maxsize=1)
def _schema():
    return read_json(Path(__file__).with_name('anatomy.schema.json'))


def validate(data):
    return validate_schema(data, _schema())


def load(case):
    return validate(read_json(Path(case) / 'anatomy.json'))


def for_layout(layout):
    if 'anatomy' in layout:
        return validate(layout['anatomy'])
    path = layout['motion_data']
    if path.startswith('res://'):
        path = Path(__file__).resolve().parents[2] / path[6:]
    return load(Path(path).parent)


def owner_ids(ownership):
    return {name: index + 1 for index, name in enumerate(ownership['names'])}
