"""Portable content keys and integrity checks for native cloth bakes."""
import json
from pathlib import Path

from .contract import BUILD_DEFAULTS, digest, mesh_hash

TOPOLOGY_FIELDS = ('edges', 'loop_vertices', 'loop_edges', 'polygon_starts', 'polygon_totals', 'polygon_smooth')


def topology_hash(payload):
    return digest({field: payload[field] for field in TOPOLOGY_FIELDS})


def cache_key(context_key, piece, blender_version):
    return digest({'context': context_key, 'piece': piece, 'blender': blender_version,
                   'cache_revision': BUILD_DEFAULTS['cache_revision']})


def read_cache(path):
    payload = json.loads(Path(path).read_text())
    if payload['mesh_hash'] != mesh_hash(payload['vertices'], payload['faces']):
        raise ValueError('Corrupt cloth cache: ' + str(path))
    if 'topology_hash' in payload and payload['topology_hash'] != topology_hash(payload):
        raise ValueError('Corrupt cloth cache topology: ' + str(path))
    return payload
