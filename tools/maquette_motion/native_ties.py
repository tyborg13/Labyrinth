"""Native sub-texel ties: candidate selection, occupancy report and temporal proof."""
import numpy as np

def select(actual, samples):
    """Use a native tie choice only where it exactly equals a legal candidate.

    Transparent RGB is immaterial, as in the existing pixel difference metric.
    Invalid ties keep the deterministic source pixel and are returned for
    counting. They use the ordinary raster mismatch allowance (rr-07 feedback
    3); this never makes an out-of-range texel a legal matching candidate.
    """
    ideal = samples.default.copy()
    matched = np.zeros(samples.ties.shape, dtype=bool)
    for candidate in samples.candidates:
        equal = np.all(actual == candidate, axis=-1) | ((actual[..., 3] == 0) & (candidate[..., 3] == 0))
        chosen = samples.ties & equal
        ideal[chosen] = candidate[chosen]
        matched |= chosen
    return ideal, samples.ties & ~matched


def statistics(samples):
    """Count painted ties, including either neighbour's edge coverage.

    Transparent padding cannot contribute to a part's occupied-pixel report.
    The occupied union keeps the denominator independent of GPU tie direction.
    """
    occupied = np.logical_or.reduce([candidate[..., 3] > 0 for candidate in samples.candidates])
    count = int((samples.ties & occupied).sum())
    area = int(occupied.sum())
    return {'pixels': count, 'occupied_pixels': area, 'fraction': count / max(1, area)}


def explanation(previous, current, held, canonical_previous, canonical_current):
    # On held frames, native candidate flips must not explain themselves. The
    # cached canonical pose supplies the unchanged rigid-transform change mask.
    return (canonical_previous, canonical_current) if held else (previous, current)
