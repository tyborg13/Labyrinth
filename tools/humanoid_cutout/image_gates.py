"""Native-pixel morphology, opt-in only; no figure-specific allowances.

All structuring elements are Euclidean disks. Pixels outside the fixed canvas
are transparent. Joint zones use pixel centres, never resized review crops.
"""
import numpy as np


def offsets(radius, *, strict=False):
    return [(x, y) for y in range(-radius, radius + 1)
            for x in range(-radius, radius + 1)
            if (x*x + y*y < radius*radius if strict else x*x + y*y <= radius*radius)]


def morphology(alpha, element, *, erode=False):
    radius = max(max(abs(x), abs(y)) for x, y in element)
    padded = np.pad(np.asarray(alpha, dtype=bool), radius)
    height, width = alpha.shape
    result = np.full(alpha.shape, erode, dtype=bool)
    for x, y in element:
        shifted = padded[radius+y:radius+y+height, radius+x:radius+x+width]
        if erode:
            result &= shifted
        else:
            result |= shifted
    return result


def defects(alpha):
    disk2, disk1 = offsets(2), offsets(1)
    closing = morphology(morphology(alpha, disk2), disk2, erode=True)
    opening = morphology(morphology(alpha, disk1, erode=True), disk1)
    return closing & ~alpha, alpha & ~opening


def interior(alpha):
    # EDT to transparent pixel centres >= 2: exclude all offsets with d < 2.
    return morphology(alpha, offsets(2, strict=True), erode=True)


def counts(mask, centroids, radius=14):
    yy, xx = np.nonzero(mask)
    return {name: int(((xx + .5 - x)**2 + (yy + .5 - y)**2 <= radius**2).sum())
            for name, (x, y) in centroids.items()}


def measure(alpha, centroids):
    notches, frays = defects(alpha)
    return {name: {'notches': n, 'frays': counts(frays, centroids)[name]}
            for name, n in counts(notches, centroids).items()}


def compare(rest, posed):
    errors = []
    if rest.keys() != posed.keys():
        raise ValueError('Joint inventory differs from rest')
    for name, row in posed.items():
        for metric, allowance in (('notches', 0), ('frays', 2)):
            if row[metric] > rest[name][metric] + allowance:
                errors.append(dict(joint=name, metric=metric, pixels=row[metric],
                                   rest_pixels=rest[name][metric], allowance=allowance))
    return errors
