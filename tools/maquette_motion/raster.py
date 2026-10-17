"""Nearest source texels through the captured native sprite-quad raster path.

The director's Metal capture uses an eight-fractional-bit vertex grid and the
top-left/bottom-right quad diagonal. Pillow's 16.16 inverse-affine fast path
does neither; it can choose adjacent texels across an entire scanline. Retained
native fixtures pin this model without rendering or changing any gate tolerance.
"""
import numpy as np

SUBPIXEL_BITS = 8
SUBPIXEL_SCALE = 1 << SUBPIXEL_BITS
QUAD_TRIANGLES = ((0, 1, 2), (0, 2, 3))


def nearest_quad(image, transform, bounds):
    """Rasterize at absolute destination pixel centers, then crop to bounds.

    Vertex rounding must happen in fixed-canvas coordinates. Re-registering the
    quad at a crop origin can change texel selection and invalidate the metric.
    """
    paint = np.asarray(image)
    height, width = paint.shape[:2]
    left, top, right, bottom = bounds
    result = np.zeros((bottom - top, right - left, 4), dtype=np.uint8)
    uv = np.array([[0, 0], [width, 0], [width, height], [0, height]], dtype=float)
    xy = uv @ transform[:2, :2].T + transform[:2, 2]
    # The native rasterizer rounds a half-subpixel upward, not to even. Rear
    # Wisp arc_right frame 90 places its top edge exactly on this tie.
    fixed = np.floor(xy * SUBPIXEL_SCALE + 0.5).astype(np.int64)
    xy = fixed / SUBPIXEL_SCALE
    low = np.maximum(np.floor(xy.min(axis=0)).astype(int), [left, top])
    high = np.minimum(np.ceil(xy.max(axis=0)).astype(int), [right, bottom])
    if np.any(low >= high):
        return result
    x, y = np.meshgrid(np.arange(low[0], high[0]) + 0.5,
                       np.arange(low[1], high[1]) + 0.5)
    fixed_x = (x * SUBPIXEL_SCALE).astype(np.int64)
    fixed_y = (y * SUBPIXEL_SCALE).astype(np.int64)
    target = result[low[1] - top:high[1] - top, low[0] - left:high[0] - left]
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
        # The sampler receives float32 texel coordinates and resolves exact
        # midpoint ties to the even texel. Wisp arc_right frames 18 and 90 pin
        # opposite tie directions. No epsilon or gate tolerance is involved.
        u = np.rint((x * affine[0, 0] + y * affine[1, 0] + affine[2, 0]).astype(np.float32) - 0.5).astype(int)
        v = np.rint((x * affine[0, 1] + y * affine[1, 1] + affine[2, 1]).astype(np.float32) - 0.5).astype(int)
        valid = inside & (u >= 0) & (v >= 0) & (u < width) & (v < height)
        target[valid] = paint[v[valid], u[valid]]
    return result
