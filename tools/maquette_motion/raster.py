"""Nearest source texels through the captured native sprite-quad raster path.

The director's Metal capture uses an eight-fractional-bit vertex grid and the
top-left/bottom-right quad diagonal. Pillow's 16.16 inverse-affine fast path
does neither; it can choose adjacent texels across an entire scanline. Retained
native fixtures pin this model without rendering or changing any gate tolerance.

At an exact integer UV (within 1e-6 in float64 after vertex snapping), native
interpolation rounding may select either adjacent texel. The default rendering
is retained for reproducibility; optional per-axis candidates mark only these
exact ties. No direction of native tie rounding is assumed.
"""
from dataclasses import dataclass
import numpy as np

SUBPIXEL_BITS = 8
SUBPIXEL_SCALE = 1 << SUBPIXEL_BITS
QUAD_TRIANGLES = ((0, 1, 2), (0, 2, 3))
EXACT_TIE_EPSILON = 1e-6


@dataclass
class QuadSamples:
    default: np.ndarray
    alternative: np.ndarray
    alternative_u: np.ndarray
    alternative_v: np.ndarray
    ties: np.ndarray

    @property
    def candidates(self):
        # A simultaneous u/v tie permits independent choices on the two axes.
        return (self.default, self.alternative_u, self.alternative_v, self.alternative)


def nearest_quad(image, transform, bounds, with_ties=False):
    """Rasterize at absolute destination pixel centers, then crop to bounds.

    Vertex rounding must happen in fixed-canvas coordinates. Re-registering the
    quad at a crop origin can change texel selection and invalidate the metric.
    """
    paint = np.asarray(image)
    height, width = paint.shape[:2]
    left, top, right, bottom = bounds
    result = np.zeros((bottom - top, right - left, 4), dtype=np.uint8)
    samples = QuadSamples(result, result.copy(), result.copy(), result.copy(),
                          np.zeros(result.shape[:2], dtype=bool)) if with_ties else None
    uv = np.array([[0, 0], [width, 0], [width, height], [0, height]], dtype=float)
    xy = uv @ transform[:2, :2].T + transform[:2, 2]
    # The native rasterizer rounds a half-subpixel upward, not to even. Rear
    # Wisp arc_right frame 90 places its top edge exactly on this tie.
    fixed = np.floor(xy * SUBPIXEL_SCALE + 0.5).astype(np.int64)
    xy = fixed / SUBPIXEL_SCALE
    low = np.maximum(np.floor(xy.min(axis=0)).astype(int), [left, top])
    high = np.minimum(np.ceil(xy.max(axis=0)).astype(int), [right, bottom])
    if np.any(low >= high):
        return samples if with_ties else result
    x, y = np.meshgrid(np.arange(low[0], high[0]) + 0.5,
                       np.arange(low[1], high[1]) + 0.5)
    fixed_x = (x * SUBPIXEL_SCALE).astype(np.int64)
    fixed_y = (y * SUBPIXEL_SCALE).astype(np.int64)
    roi = np.s_[low[1] - top:high[1] - top, low[0] - left:high[0] - left]
    target = result[roi]
    for triangle in QUAD_TRIANGLES:
        indices = list(triangle)
        basis = np.concatenate((xy[indices], np.ones((3, 1))), axis=1)
        if np.linalg.det(basis) == 0:
            continue
        affine = np.linalg.solve(basis, uv[indices])
        # Exact edge equations make the shared diagonal watertight. Floating
        # barycentrics can reject that same pixel in both triangles. The GPU's
        # top-left rule includes top/left edges and excludes bottom/right edges,
        # including a half-pixel outer edge; no coverage epsilon is involved.
        if np.linalg.det(basis) < 0:
            indices[1], indices[2] = indices[2], indices[1]
        inside = np.ones(x.shape, dtype=bool)
        for index in range(3):
            start, end = fixed[indices[index]], fixed[indices[(index + 1) % 3]]
            dx, dy = end - start
            edge = dx * (fixed_y - start[1]) - dy * (fixed_x - start[0])
            top_left = dy < 0 or (dy == 0 and dx > 0)
            inside &= (edge > 0) | ((edge == 0) & top_left)
        raw_u = x * affine[0, 0] + y * affine[1, 0] + affine[2, 0]
        raw_v = x * affine[0, 1] + y * affine[1, 1] + affine[2, 1]
        # Preserve the existing deterministic default. This numerical rounding
        # is not a claim about the GPU's choice at an exact integer UV.
        u = np.rint(raw_u.astype(np.float32) - 0.5).astype(int)
        v = np.rint(raw_v.astype(np.float32) - 0.5).astype(int)
        valid = inside & (u >= 0) & (v >= 0) & (u < width) & (v < height)
        target[valid] = paint[v[valid], u[valid]]
        if with_ties:
            integer_u, integer_v = np.rint(raw_u).astype(int), np.rint(raw_v).astype(int)
            tie_u = np.abs(raw_u - integer_u) <= EXACT_TIE_EPSILON
            tie_v = np.abs(raw_v - integer_v) <= EXACT_TIE_EPSILON
            other_u = np.where(tie_u, np.where(u == integer_u - 1, integer_u, integer_u - 1), u)
            other_v = np.where(tie_v, np.where(v == integer_v - 1, integer_v, integer_v - 1), v)
            samples.ties[roi] |= inside & (tie_u | tie_v)
            for surface, source_u, source_v in ((samples.alternative_u, other_u, v),
                                               (samples.alternative_v, u, other_v),
                                               (samples.alternative, other_u, other_v)):
                valid = inside & (source_u >= 0) & (source_v >= 0) & (source_u < width) & (source_v < height)
                surface[roi][valid] = paint[source_v[valid], source_u[valid]]
    return samples if with_ties else result
