"""Preserve rr-43's exact layouts around rr-45's sole authorized depth delta.

Frozen art/geometry certificates stay immutable. Reconstruct their prior bytes
only after requiring the current spear's corrected layer; no other field is
normalized. The two prior values transcribe the accepted rr-43 layouts.
"""
import copy
import json

PRIOR_SPEAR_DEPTH = {'front':23, 'rear':24}
SHAFT_OCCLUDERS = ('torso','pelvis','cape_near','cape_far','arm_far','hand_far')


def lowered_depth(layout):
    return min(p['z_index'] for p in layout['parts'] if p['name'] in SHAFT_OCCLUDERS)-1


def prior_layout(layout):
    result = copy.deepcopy(layout)
    spear = next(p for p in result['parts'] if p['name']=='spear')
    if spear['z_index'] != lowered_depth(layout):
        raise ValueError('Unauthorized spear draw depth')
    spear['z_index'] = PRIOR_SPEAR_DEPTH[layout['facing']]
    if 'proof_layers' in result:
        if result['proof_layers']['spear']['z_index'] != lowered_depth(layout):
            raise ValueError('Spear proof depth differs from its corrected layer')
        result['proof_layers']['spear']['z_index'] = spear['z_index']
    return result


def prior_layout_bytes(layout):
    return (json.dumps(prior_layout(layout),indent=2)+'\n').encode()
