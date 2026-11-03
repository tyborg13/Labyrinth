"""Gaoler native calibration: registered float32 poses and real UV neighbours."""
from maquette_motion import pixels
from maquette_motion.raster import SUBPIXEL_SCALE
from humanoid_cutout.cpu_pose import sprite_transform
from humanoid_cutout.gates import matrix

# Metal vertex snapping and UV interpolation each contribute a half step.
# Only nearest real-source neighbours within one 8-bit UV step are candidates.
# This opt-in changes no default raster output or other figure's proof policy.
NATIVE_UV_STEP = 1 / SUBPIXEL_SCALE


def pose_for_raster(pose):
    if 'raster_bones' not in pose:return pose
    return dict(pose,canonical_bones=pose.get('canonical_bones',pose['bones']),
                canonical_parts=pose.get('canonical_parts',pose['parts']),
                canonical_cap_bones=pose.get('canonical_cap_bones',pose.get('cap_bones',{})),
                bones=pose['raster_bones'],parts=pose['raster_parts'],cap_bones=pose.get('raster_cap_bones',{}),
                stable_geometry=pose.get('raster_stable_geometry',pose.get('stable_geometry',{})))


def pose_families(pose):
    if 'raster_bones' not in pose:return (pose,)
    native=pose_for_raster(pose)
    canonical=dict(pose,bones=native['canonical_bones'],parts=native['canonical_parts'],cap_bones=native['canonical_cap_bones'])
    return (native,canonical)


def rigid(image,layout,pose,part,*,with_ties=False):
    name=part.get('name')
    transform=(matrix(pose['parts'][name]['transform']) if name in pose.get('parts',{})
               else sprite_transform(layout,pose,part))
    if layout.get('stable_source_raster'):
        import numpy as np
        transform=transform.astype(np.float32).astype(np.float64)
    return pixels.render(image,transform,with_ties=with_ties,tie_epsilon=NATIVE_UV_STEP)
