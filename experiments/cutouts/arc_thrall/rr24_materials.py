"""Own-mq7b donor provenance, in source space and on exposed posed pixels."""
import numpy as np

from maquette_motion.material_palette import interior_donors


def colour_codes(image):
    rgba = image.astype(np.uint32)
    return rgba[...,0] | rgba[...,1] << 8 | rgba[...,2] << 16 | rgba[...,3] << 24


def donor_palettes(visible, definition):
    palettes = {}
    for name,image in visible.items():
        donors = interior_donors(image,definition)
        palettes[name] = np.unique(colour_codes(donors)[donors[...,3]>0])
    return palettes


def foreign_pixels(image, palette):
    return (image[...,3]>0) & ~np.isin(colour_codes(image),palette)


def exposed_provenance(layers, palettes):
    covered = np.zeros(layers[0][1].shape[:2],dtype=bool)
    rows = []
    for part,image,checks in sorted(layers,key=lambda row:row[0]['z_index'],reverse=True):
        opaque = image[...,3]>0
        exposed = opaque & ~covered & (checks[...,1]>0)
        if exposed.any():
            foreign = exposed & foreign_pixels(image,palettes[part['logical_part']])
            rows.append({'piece':part['name'],'garment':part['logical_part'],
                         'exposed_pixels':int(exposed.sum()),'foreign_pixels':int(foreign.sum())})
        covered |= opaque
    return rows
