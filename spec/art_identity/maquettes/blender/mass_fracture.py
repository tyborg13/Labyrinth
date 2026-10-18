"""Native Boolean fracture cuts and ground-contact clipping for sculpted solids."""


def wedge(centre, size, rotation):
    """An asymmetric triangular chip, tapering to a fracture tip."""
    import math
    import numpy as np
    from .mass_topology import outward_faces
    x,y,z=rotation;cx,sx=math.cos(x),math.sin(x);cy,sy=math.cos(y),math.sin(y);cz,sz=math.cos(z),math.sin(z)
    axis=np.array([[cz,-sz,0],[sz,cz,0],[0,0,1]]) @ np.array([[cy,0,sy],[0,1,0],[-sy,0,cy]]) @ np.array([[1,0,0],[0,cx,-sx],[0,sx,cx]])
    cross=[[-.5,.5],[.5,.5],[.10,-.5]]
    vertices=[(np.asarray(centre)+axis @ np.array([side*size[0],a*size[1],b*size[2]])).tolist()
              for side in (-.5,.5) for a,b in cross]
    faces=[[0,2,1],[3,4,5],[0,1,4,3],[1,2,5,4],[2,0,3,5]]
    return vertices,outward_faces(vertices,faces)


def box(centre, size, rotation):
    from mathutils import Euler, Vector
    axis = Euler(rotation,'XYZ').to_matrix()
    vertices = [list(Vector(centre)+axis @ Vector([x*size[0]/2,y*size[1]/2,z*size[2]/2]))
                for z in (-1,1) for y in (-1,1) for x in (-1,1)]
    faces = [[0,2,3,1],[4,5,7,6],[0,1,5,4],[2,6,7,3],[0,4,6,2],[1,3,7,5]]
    return vertices,faces


def difference(obj, name, vertices, faces):
    import bpy
    from mathutils import Matrix
    from .pieces import mesh_object
    cutter = mesh_object(obj.name+'_'+name,vertices,faces)
    # Vertices are local to the source. An identity child frame keeps every
    # cutter attached when its boulder is posed, without a stale world inverse.
    cutter.parent = obj
    cutter.matrix_parent_inverse = Matrix.Identity(4)
    cutter.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    cutter.hide_render = True
    cutter.hide_set(True)
    cutter['native_source'] = True
    modifier = obj.modifiers.new(name,'BOOLEAN')
    modifier.operation = 'DIFFERENCE'
    modifier.solver = 'EXACT'
    modifier.object = cutter
    return modifier


def fracture(obj, piece):
    for index, cut in enumerate(piece.get('fractures',[])):
        shape=wedge if cut.get('shape')=='wedge' else box
        difference(obj,'modelled_fracture_'+str(index),*shape(cut['centre'],cut['size'],cut['rot']))


def ground(obj, piece):
    if 'support_z' in piece:
        # An actual planar Boolean face survives subdivision/displacement;
        # the retained, thick foot above it is not a separate display disc.
        height = max(piece['radii'])*8
        local_z = piece['support_z']-piece['centre'][2]
        difference(obj,'support_ground_clip',*box([0,0,local_z-height/2],
                                                [height,height,height],[0,0,0]))
