"""Independent scalar-source skin for the optional deterministic submission.

No native weight packing, transform blending, or alternate paint is involved.
Quantization is the existing eight-fractional-bit raster lattice, not motion
quantization. Source UVs, triangles and all authored weight fields are intact.
"""
import numpy as np
from maquette_motion.raster import SUBPIXEL_SCALE
from .gates import matrix


def vertices(layout, pose, mesh):
    source=np.asarray(mesh['vertices'],dtype=np.float64)
    if pose['clip'] in ('rest','idle'):
        logical=mesh.get('logical_part',mesh.get('garment',mesh.get('name','')))
        names=next((names for names in layout['idle_groups'].values() if logical in names),None)
        offset=np.zeros(2)
        if names:
            anchor=next(part["bone"] for part in layout["parts"] if part["name"]==names[0])
            from maquette_motion.pixels import round_pixels
            offset=round_pixels(np.asarray(pose['bones'][anchor]['global'][4:])-layout['joints'][anchor]['position'])
        return source+offset
    result=np.zeros_like(source)
    from .cpu_pose import cap_source_bone
    for name,weights in mesh['weights'].items():
        bone=cap_source_bone(layout,pose,name) if mesh.get('rigid_source_alignment') else matrix(pose['bones'][name]['global'])
        bone=bone.astype(np.float32).astype(np.float64)
        delta=source-layout['joints'][name]['position']
        transformed=np.column_stack((delta[:,0]*bone[0,0]+delta[:,1]*bone[0,1]+bone[0,2],
                                     delta[:,0]*bone[1,0]+delta[:,1]*bone[1,1]+bone[1,2]))
        result+=np.asarray(weights,dtype=np.float64)[:,None]*transformed
    return np.floor(result*SUBPIXEL_SCALE+.5)/SUBPIXEL_SCALE


def geometry_errors(layout,pose):
    """Compare real submitted buffers against the independent source oracle."""
    import hashlib
    from .cpu_pose import sprite_transform
    errors=[];records=pose.get('stable_geometry',{})
    if not layout.get('stable_source_raster'):
        return ['stable source raster contract missing']
    meshes={m['name']:m for m in layout['joint_meshes']}
    if set(records)!={p['name'] for p in layout['parts']}:return ['missing submitted source geometry']
    for part in layout['parts']:
        name=part['name'];record=records[name]
        if name in meshes:xy=vertices(layout,pose,meshes[name])
        else:
            transform=matrix(pose['parts'][name]['transform']).astype(np.float32).astype(np.float64)
            x,y,x1,y1=part['bbox'];w,h=x1-x,y1-y
            uv=np.array([[0,0],[w,0],[w,h],[0,h]],dtype=float)
            xy=uv@transform[:2,:2].T+transform[:2,2]
            xy=np.floor(xy*SUBPIXEL_SCALE+.5)/SUBPIXEL_SCALE
        expected=hashlib.sha256(np.asarray(xy,dtype='<f4').tobytes()).hexdigest()
        if record['vertices_sha256']!=expected or record['count']!=len(xy):errors.append('submitted vertices differ: '+name)
        if not (record['skeleton_empty'] and record['visible'] and record['source_suppressed'] and record['texture_matches']):
            errors.append('submitted source path differs: '+name)
        if not np.allclose(matrix(record['transform']),np.eye(3),atol=.0001,rtol=0):errors.append('submitted source transformed twice: '+name)
    return errors
