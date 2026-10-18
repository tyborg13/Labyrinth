"""Required native socket receipts, independent of Blender and sealing."""
import json
import math

from .socket_tuck import SOCKET_DEFAULTS


def validate_reports(spec, reports):
    expected = {item['id']: item for item in spec['base'].get('socket_tucks', [])}
    if not isinstance(reports, dict) or set(reports) != set(expected):
        raise ValueError('Missing or stale native socket details')
    pieces = {piece['id']: piece for piece in spec['pieces']}
    for name, item in expected.items():
        row = reports[name]
        indices = row.get('source_vertex_indices', [])
        numeric = ('minimum_insertion_m', 'maximum_endpoint_radius_m', 'inner_radius_m',
                   'maximum_source_boundary_error_m')
        if (row.get('passed') is not True or
                any(row.get(field) != item[field] for field in ('source_region', 'adjacent_region')) or
                row.get('endpoint_joint') != item['end_joint'] or len(indices) < 3 or
                len(set(indices)) != len(indices) or row.get('source_boundary_vertices') != len(indices) or
                any(not isinstance(row.get(key), (int, float)) or not math.isfinite(row[key]) for key in numeric)):
            raise ValueError('Missing or failed native socket details: ' + name)
        radius = pieces[item['socket']]['socket']['inner_radius']
        epsilon = SOCKET_DEFAULTS['epsilon_m']
        if (row['minimum_insertion_m'] <= 0 or row['inner_radius_m'] != radius or
                not 0 <= row['maximum_endpoint_radius_m'] <= radius + epsilon or
                not 0 <= row['maximum_source_boundary_error_m'] <= epsilon):
            raise ValueError('Native socket geometry failed: ' + name)
    return reports


def collect(spec, objects):
    return validate_reports(spec, {obj.name: json.loads(obj['socket_tuck_report'])
                                  for obj in objects if 'socket_tuck_report' in obj})
