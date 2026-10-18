"""Deterministic native pin gathering; rest fabric retains its sewn allowance."""
from copy import deepcopy
import numpy as np

YOKE_DEFAULTS={'rest_clearance_fraction':.1}


def sew_yoke(piece,spec,joint):
    """Add connected fabric between the yoke seam and the measured banner.

    The banner itself retains every measured control. The added row is its
    actual sewn attachment, rather than animating the whole root from the
    elevated painted silhouette down to the shoulder during simulation.
    """
    result=deepcopy(piece)
    rows=result['pattern']['rows']
    span=float(np.linalg.norm(np.subtract(rows[0]['points'][-1],rows[0]['points'][0])))
    top=np.array(spec['joints'][joint],float)
    top[0]-=spec['ortho_scale']*YOKE_DEFAULTS['rest_clearance_fraction']
    rows.insert(0,{'points':[(top-[0,0,span*t]).tolist() for t in np.linspace(0,1,result['pattern']['columns'])]})
    result['yoke_seam_length']=span
    return result


def animate_pins(obj, targets, frames):
    import bpy
    obj.shape_key_add(name='sewn_rest_fabric')
    key = obj.shape_key_add(name='gathered_attachments')
    for i, point in targets.items():
        key.data[i].co = point
    key.value = 0
    key.keyframe_insert(data_path='value', frame=1)
    key.value = 1
    key.keyframe_insert(data_path='value', frame=frames)
    # Explicit interpolation avoids a user preference affecting the pre-roll.
    action = obj.data.shape_keys.animation_data.action
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for point in curve.keyframe_points:
                        point.interpolation = 'LINEAR'
    bpy.context.scene.frame_set(1)
