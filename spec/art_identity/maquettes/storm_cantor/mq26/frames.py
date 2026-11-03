"""Posed body frames and the capture camera's screen-height metric.

Torso and pelvis pieces are authored in local coordinates about the rest hip
centre (x forward, y near, z up) and head pieces about the rest head joint;
the mq-19 pose maps them exactly as it maps its own pieces. Proportions are
compared on the front capture camera, the way the original sprite was measured.
"""
import numpy as np
from spec.art_identity.maquettes.raster import camera


class Frames:
    def __init__(self, rest, joints, frames, H):
        old = {k: np.asarray(v, float) for k, v in rest.items()}
        self.H = H
        self.j = {k: np.asarray(v, float) for k, v in joints.items()}
        self.hc_rest = (old['hip_near'] + old['hip_far']) / 2
        self.hc = (self.j['hip_near'] + self.j['hip_far']) / 2
        self.head_rest = old['head']
        self.Rc, self.Rp, self.Rh = (np.asarray(frames[k], float) for k in ('torso', 'pelvis', 'head'))

    def torso(self, local):
        return self.hc + np.einsum('nj,kj->nk', np.atleast_2d(np.asarray(local, float)), self.Rc)

    def pelvis(self, local):
        return self.hc + np.einsum('nj,kj->nk', np.atleast_2d(np.asarray(local, float)), self.Rp)

    def head(self, local):
        return self.j['head'] + np.einsum('nj,kj->nk', np.atleast_2d(np.asarray(local, float)), self.Rh)

    def to_torso(self, world):
        return np.einsum('nj,jk->nk', np.atleast_2d(np.asarray(world, float)) - self.hc, self.Rc)

    def to_head(self, world):
        return np.einsum('nj,jk->nk', np.atleast_2d(np.asarray(world, float)) - self.j['head'], self.Rh)

    def to_pelvis(self, world):
        return np.einsum('nj,jk->nk', np.atleast_2d(np.asarray(world, float)) - self.hc, self.Rp)


def screen_basis(spec, view='front'):
    matrix, _, basis, _ = camera(spec, view)
    return basis @ matrix[:3, :3]


def screen_heights(spec, points, view='front'):
    """Height on the capture screen in metres (camera up axis), up to a constant."""
    return np.atleast_2d(np.asarray(points, float)) @ screen_basis(spec, view)[1]


def screen_widths(spec, points, view='front'):
    return np.atleast_2d(np.asarray(points, float)) @ screen_basis(spec, view)[0]
