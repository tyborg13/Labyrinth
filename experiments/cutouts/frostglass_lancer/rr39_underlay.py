"""Partition the protected director paint in its original 255px registration.

The torso keeps the rr-37 extended flank; the remaining covered paint belongs
to the far cloak. No nearest-donor synthesis is permitted inside this footprint.
"""
import numpy as np
from PIL import Image
from rr37_case import PROJECT
from humanoid_cutout.covered_surfaces import row_outline

DIRECTOR = PROJECT / 'spec/peer_benchmark/staged/rr-39'


def inputs():
    paint = np.asarray(Image.open(DIRECTOR/'front_far_underlay.png').convert('RGBA')).copy()
    footprint = np.asarray(Image.open(DIRECTOR/'front_far_footprint_mask.png').convert('L')) > 0
    return paint, footprint


def domains(visible, solos):
    paint, footprint = inputs()
    torso = row_outline(solos['torso'] | (visible['torso'][..., 3] > 0))
    y, x = np.indices(footprint.shape)
    torso |= (y >= 82) & (y <= 117) & (x >= 88) & (x <= 135)
    opaque = footprint & (paint[..., 3] > 0)
    # The director also restored the boot where the lower spear crossed it.
    # Its existing painted owner supplies the attachment, not the moving cape.
    boot_top = np.flatnonzero((visible['foot_far'][..., 3] > 0).any(axis=1))[0]
    boot = opaque & (y >= boot_top)
    return {'torso': opaque & torso & ~boot, 'cape_far': opaque & ~torso & ~boot, 'foot_far': boot}


def replace(visible, hidden, solos):
    paint, footprint = inputs()
    required = domains(visible, solos)
    for name in required:
        hidden[name][footprint] = 0
        hidden[name][required[name]] = paint[required[name]]
    return required


def covered(name, target):
    paint, _ = inputs()
    result = np.zeros_like(paint)
    result[target] = paint[target]
    return result


def retire_recipes(layout):
    """Old procedural torso/cloak recipes cannot repaint director-owned air."""
    if layout['facing'] != 'front': return
    _, footprint = inputs()
    parts = {p['name']: p for p in layout['parts']}
    tables = [layout.get('gait_continuations', {})] + list(layout.get('clip_continuations', {}).values())
    for table in tables:
        for name, recipe in list(table.items()):
            part = parts[name]
            if part['logical_part'] not in ('torso', 'cape_far', 'foot_far'): continue
            x0, y0 = part['offset']
            recipe['texels'] = [row for row in recipe['texels'] if not footprint[row[1]+y0, row[0]+x0]]


def paint_mask(case, layout, part):
    """Independent certificate for direct underlay texels, including its ink."""
    if layout['facing'] != 'front' or part['logical_part'] not in ('torso', 'cape_far', 'foot_far'):
        return np.zeros((255, 255), bool)
    if not part.get('hidden_material'): return np.zeros((255, 255), bool)
    from maquette_motion.features import source_pixels
    paint, footprint = inputs()
    image = source_pixels(case, part)
    return footprint & (paint[..., 3] > 0) & np.all(image == paint, axis=-1)


def presentation_anchor(view, name):
    """Keep rr-37 sprite registration when the underlay changes a storage crop."""
    if view != 'front' or name != 'hidden_torso': return None
    from rr39_fixture import TARGET
    from cutout_pipeline.cases import read_json
    layout = read_json(TARGET/f'case/layouts/{view}.json')
    part = next(p for p in layout['parts'] if p['name'] == name)
    return part.get('presentation_anchor', part['offset'])
