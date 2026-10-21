"""Source-measured joint interfaces and exact Euclidean cover distances."""
import numpy as np
from maquette_motion.silhouette import dilate
from maquette_motion.material_palette import luma, rules
from maquette_motion.features import source_pixels

COVER_LIMIT_PX = 3.0  # Director feedback 3.
DISTANCE_CHUNK_PIXELS = 1024  # Proof memory only.
SKIN_PREFIXES = ('upper_', 'fore_', 'hand_', 'thigh_')


def interfaces(visible, joins):
    """Grid-edge segments where the two approved painted cuts touch."""
    result = {}
    for first, second in joins:
        a, b = [visible[n][..., 3] > 0 for n in (first, second)]
        segments = []
        for left, right in ((a, b), (b, a)):
            y, x = np.nonzero(left[:, :-1] & right[:, 1:])
            segments.extend([[[int(xx)+1,int(yy)],[int(xx)+1,int(yy)+1]] for yy,xx in zip(y,x)])
            y, x = np.nonzero(left[:-1] & right[1:])
            segments.extend([[[int(xx),int(yy)+1],[int(xx)+1,int(yy)+1]] for yy,xx in zip(y,x)])
        result[first + '/' + second] = dict(pieces=[first,second],segments=segments)
    return result


def declared_joins(anatomy):
    joins={tuple(sorted(pair)) for pair in anatomy['seam_joins']}
    joins.update(tuple(sorted((name,other))) for name,definition in anatomy['tucks']['pieces'].items()
                 for other in definition['covers'])
    return sorted(joins)


def distance(points, segments):
    points = np.asarray(points, dtype=float).reshape(-1,2)
    segments = np.asarray(segments, dtype=float).reshape(-1,2,2)
    if not len(segments): return np.full(len(points), np.inf)
    start, delta = segments[:,0], segments[:,1]-segments[:,0]
    length = np.sum(delta*delta,axis=1)
    result = []
    for offset in range(0,len(points),DISTANCE_CHUNK_PIXELS):
        difference = points[offset:offset+DISTANCE_CHUNK_PIXELS,None]-start
        u = np.clip(np.sum(difference*delta,axis=2)/length,0,1)
        result.extend(np.sqrt(np.min(np.sum((difference-u[...,None]*delta)**2,axis=2),axis=1)))
    return np.asarray(result)


def material_floor(image, definition):
    """Darkest painted material above this painting's explicit outline tones.

    Original dark painting pixels retain a separate exact per-texel exception;
    they are never donors for a newly revealed skin/cloth joint surface.
    """
    palette = np.asarray(definition['outline_palette'])
    outline = max([definition['visible_luma_cutoff']] +
                  ([float(luma(palette).max())] if len(palette) else []))
    values = luma(image)
    available = (image[...,3]>0) & (values>outline)
    if not available.any(): raise ValueError('Joint has no painted material above its outline tone')
    return float(values[available].min())


def source_materials(case, layout):
    visible = {p['logical_part']:source_pixels(case,p) for p in layout['parts'] if not p['hidden_material']}
    return visible, rules(case,layout['facing'])
