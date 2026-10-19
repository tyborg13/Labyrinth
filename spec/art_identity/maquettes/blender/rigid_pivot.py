"""Move an editable attachment's origin to its rig pivot, preserving geometry."""
import numpy as np

PIVOT_DEFAULTS = {'tolerance_m': 1e-6}


def local_shift(matrix, pivot):
    return np.linalg.solve(np.asarray(matrix, float), [*pivot, 1])[:3].tolist()


def apply(obj, pivot):
    import json
    from mathutils import Matrix
    obj['pivot_design_matrix'] = json.dumps([list(row) for row in obj.matrix_world])
    shift = local_shift([list(row) for row in obj.matrix_world], pivot)
    obj.data.transform(Matrix.Translation([-value for value in shift]))
    obj.matrix_world = obj.matrix_world @ Matrix.Translation(shift)


def report(spec):
    import bpy
    rows = {}
    for piece in spec['pieces']:
        joint = piece.get('rig_pivot_joint')
        if joint:
            source = bpy.data.objects[piece['id']]
            error = float(np.linalg.norm(np.subtract(source.matrix_world.translation, spec['joints'][joint])))
            rows[piece['id']] = {'joint': joint, 'error_m': error,
                                 'passed': error <= PIVOT_DEFAULTS['tolerance_m']}
    return rows
