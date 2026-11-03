"""Independently audit native shoulder motion against source geometry.

Never consume the deformation's influence mask or proposed shifted points.
Reconstruct the contract from the original surface, pinned attachments and
protected faces, and measure the actual world-space vertices after application.
"""
import numpy as np

AUDIT_DEFAULTS = {'epsilon': 1e-10, 'world_error_m': 1e-6}


def audit(before, after, faces, near, far, delta, mode, midpoint, roots=None,
          root_radius=0, head_floor=None, renderer_near_faces=(), tolerance=None):
    tolerance = AUDIT_DEFAULTS['world_error_m'] if tolerance is None else tolerance
    before, after, near, far, delta, midpoint = (
        np.asarray(v, float) for v in (before, after, near, far, delta, midpoint))
    protected = {i for face in renderer_near_faces for i in face}
    if mode == 'root':
        distances = np.linalg.norm(before[:, None] - np.asarray(roots)[None], axis=2).min(axis=1)
        distances = np.maximum(distances - root_radius, 0)
        extent = distances.max()
        fraction = 1 - distances / max(extent, AUDIT_DEFAULTS['epsilon'])
    else:
        direction = np.sign(far[1] - midpoint[1])
        side = np.clip((before[:, 1] - midpoint[1]) * direction /
                       abs(far[1] - midpoint[1]), 0, 1)
        if mode == 'far_top':
            low = before[:, 2].min()
            height = far[2] - low
            vertical = np.clip((before[:, 2] - low) / max(height, AUDIT_DEFAULTS['epsilon']), 0, 1)
        elif mode == 'far_skirt':
            vertical = np.clip((head_floor - before[:, 2]) / (head_floor - far[2]), 0, 1)
        elif mode == 'far_side':
            vertical = np.ones(len(before))
        else:
            raise ValueError('Unknown audited shoulder motion field: ' + mode)
        fraction = side * vertical
        for face in faces:
            vertices = before[list(face)]
            if ((vertices[:, 1].mean() - midpoint[1]) * direction <= 0 or
                    (head_floor is not None and vertices[:, 2].max() >= head_floor)):
                protected.update(face)
    expected_fraction = fraction ** 2 * (3 - 2 * fraction)
    protected = sorted(protected)
    expected_fraction[protected] = 0
    expected_displacement = expected_fraction[:, None] * delta
    observed_displacement = after - before
    attachments = expected_fraction == 1
    remote = expected_fraction == 0

    def error(values):
        return float(np.linalg.norm(values, axis=1).max()) if len(values) else 0.

    errors = {'deformation_error_m': error(observed_displacement - expected_displacement),
        'attachment_displacement_error_m': error(observed_displacement[attachments] - delta),
        'protected_face_error_m': error(observed_displacement[protected]),
        'remote_vertex_error_m': error(observed_displacement[remote])}
    return {**errors, 'expected_moving_vertices': int((expected_fraction > 0).sum()),
        'audited_attachment_vertices': int(attachments.sum()),
        'protected_face_vertices': len(protected),
        'passed': all(value <= tolerance for value in errors.values())}
