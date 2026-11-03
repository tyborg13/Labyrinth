"""Compare ordered native primitives in board-local ground coordinates.

Old native captures predate an explicit origin field. The three named floor
centres recover tile (0, 0) from the existing affine isometric lattice:
O = 3 P(1,1) - P(2,1) - P(1,2). No actor bounds or painter order is consulted.
"""
import math

IDENTITY_FIELDS = ('id', 'kind', 'plane', 'tie_rank')
ORIGIN_ANCHORS = (('floor_1_1', 3), ('floor_2_1', -1), ('floor_1_2', -1))
FLOAT32_SIGNIFICAND_BITS = 24
FLOAT32_MIN_SUBNORMAL_EXPONENT = -149


def coordinate(layer, axis):
    value = layer['ground_' + axis]
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        raise ValueError('Non-finite/non-numeric ground coordinate: ' + str(layer.get('id')))
    return value


def float32_rounding_radius(value):
    # Vector2 stores float32. Each captured component is within half an ULP of
    # its value before storage; JSON's decimal error is much smaller. Propagate
    # those intervals through origin subtraction instead of a pixel tolerance.
    if value == 0:
        return math.ldexp(0.5, FLOAT32_MIN_SUBNORMAL_EXPONENT)
    exponent = math.frexp(abs(value))[1] - FLOAT32_SIGNIFICAND_BITS
    return math.ldexp(0.5, max(FLOAT32_MIN_SUBNORMAL_EXPONENT, exponent))


def board_origin(layers):
    by_id = {layer['id']: layer for layer in layers}
    if len(by_id) != len(layers):
        raise ValueError('Duplicate primitive id')
    origin, uncertainty = [], []
    for axis in ('x', 'y'):
        values = [(coordinate(by_id[name], axis), weight) for name, weight in ORIGIN_ANCHORS]
        origin.append(sum(value * weight for value, weight in values))
        uncertainty.append(sum(float32_rounding_radius(value) * abs(weight) for value, weight in values))
    return origin, uncertainty


def compare_primitives(observed, expected):
    """Reject any ordered identity change or board-relative geometry change."""
    identities = lambda layers: [tuple(layer[key] for key in IDENTITY_FIELDS) for layer in layers]
    if identities(observed) != identities(expected):
        raise ValueError('drawn/culled sprite set differs from inventory (id/kind/plane/tie rank/order)')
    origin, radius = board_origin(observed)
    reference, reference_radius = board_origin(expected)
    max_error, max_bound = [0.0, 0.0], [0.0, 0.0]
    for actual, wanted in zip(observed, expected):
        for index, axis in enumerate(('x', 'y')):
            a, b = coordinate(actual, axis), coordinate(wanted, axis)
            error = abs((a - origin[index]) - (b - reference[index]))
            bound = (radius[index] + reference_radius[index]
                     + float32_rounding_radius(a) + float32_rounding_radius(b))
            max_error[index] = max(max_error[index], error)
            max_bound[index] = max(max_bound[index], bound)
            if error > bound:
                raise ValueError('relative sprite position differs from inventory: '
                                 + actual['id'] + '/ground_' + axis)
    return {'board_origin': origin, 'origin_uncertainty_pixels': radius,
            'inventory_board_origin': reference,
            'translation_from_inventory': [a - b for a, b in zip(origin, reference)],
            'origin_source': 'captured_floor_lattice',
            'max_relative_error_pixels': max_error,
            'max_float32_rounding_bound_pixels': max_bound}
