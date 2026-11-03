"""Godot's packed four-weight skin positions for the native UV oracle only.

Godot 4.6 Polygon2D sorts/normalizes PackedFloat32 weights, RenderingServer
stores UNORM16, and skeleton.glsl blends the decoded transforms before applying
the vertex. Keep that representation out of the historical CPU diagnostic.
Sources: godotengine/godot 4.6-stable, scene/2d/polygon_2d.cpp,
servers/rendering/rendering_server.cpp and renderer_rd/shaders/skeleton.glsl.
"""
import numpy as np
from .gates import matrix

WEIGHT_UNORM_MAX = 65535  # Godot ARRAY_WEIGHTS format, not a proof tolerance.
MAX_BONE_WEIGHTS = 4     # Polygon2D's native vertex format.


def vertices(layout, pose, mesh):
    names = list(mesh['weights'])
    weights = np.array([mesh['weights'][n] for n in names],np.float32).T
    order = np.argsort(-weights,axis=1,kind='stable')[:,:MAX_BONE_WEIGHTS]
    weights = np.take_along_axis(weights,order,axis=1)
    total = np.zeros(len(weights),np.float32)
    for column in weights.T:total += column
    weights = np.divide(weights,total[:,None],out=np.zeros_like(weights),where=total[:,None]>0)
    weights = np.clip(weights*WEIGHT_UNORM_MAX,0,WEIGHT_UNORM_MAX).astype(np.uint16).astype(np.float32)/WEIGHT_UNORM_MAX
    transforms = []
    for name in names:
        if mesh.get('rigid_source_alignment'):
            from .cpu_pose import cap_source_bone
            bone=cap_source_bone(layout,pose,name)[:2].astype(np.float32)
        else:bone = matrix(pose['bones'][name]['global'])[:2].astype(np.float32)
        bind = np.array(layout['joints'][name]['position'],np.float32)
        bone[:,2] -= bone[:,0]*bind[0]+bone[:,1]*bind[1]
        transforms.append(bone)
    transforms = np.asarray(transforms)
    blended = np.zeros((len(weights),2,3),np.float32)
    for column in range(weights.shape[1]):
        blended += transforms[order[:,column]]*weights[:,column,None,None]
    source = np.array(mesh['vertices'],np.float32)
    return blended[:,:,0]*source[:,0,None]+blended[:,:,1]*source[:,1,None]+blended[:,:,2]
