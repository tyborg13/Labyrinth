"""Director rr-54: shaft ahead of the front torso, behind the rear silhouette.

The projected clips have no authored camera-depth crossing. Use one stable
order for every clip, preserving the approved grip, motion and all paint.
"""


def apply_layers(layout):
    parts = {part['name']: part for part in layout['parts']}
    if layout['facing'] == 'front':
        # Existing slot between torso and camera-side forearm/fingers.
        parts['spear']['z_index'] = min(parts[name]['z_index'] for name in
            ('arm_near', 'hand_near', 'hand_far')) - 1
        parts['hidden_spear']['z_index'] = parts['spear']['z_index'] - 1
    else:
        # Include seam/covered paint: hidden_spear must not bypass the body.
        first_body = min(part['z_index'] for part in layout['parts'] if part['logical_part'] != 'spear')
        parts['spear']['z_index'] = first_body - 1
        parts['hidden_spear']['z_index'] = first_body - 2
    for name in ('spear', 'hidden_spear'):
        if 'proof_layers' in layout:
            layout['proof_layers'][name]['z_index'] = parts[name]['z_index']


def assemble_rear_rest(case, layout):
    """Keep approved processed.png untouched; render the new rear layer order.

    This is a derived rest assembly of existing paint, not a paint repair.
    The old painted reference includes the shaft over the rear body, which the
    rr-54 world-space rule explicitly removes.
    """
    if layout['facing'] != 'rear': return
    from PIL import Image
    rest = Image.new('RGBA', (255, 255))
    for part in sorted(layout['parts'], key=lambda part: part['z_index']):
        rest.alpha_composite(Image.open(case / part['file']).convert('RGBA'), tuple(part['offset']))
    layout['rest_source'] = 'source/rear/rr54_assembled.png'
    path = case / layout['rest_source']
    rest.save(path)
    path.with_suffix('.png.import').write_text('[remap]\n\nimporter="keep"\n')
