"""Bridge-only attribution of remaining native cloak contact samples."""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))


def main(build, output):
    import bpy
    import numpy as np
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    from mathutils.geometry import closest_point_on_tri
    from spec.art_identity.maquettes.blender.cloth_contacts import inside
    bpy.ops.wm.open_mainfile(filepath=str(Path(build) / 'maquette.blend'))
    obj = bpy.data.objects['cloak_render']
    plate = bpy.data.objects['back_carapace_render']
    points = [obj.matrix_world @ v.co for v in obj.data.vertices]
    faces = [list(f.vertices) for f in obj.data.polygons]
    used = {i for f in faces for i in f}
    tree = BVHTree.FromPolygons([plate.matrix_world @ v.co for v in plate.data.vertices],
                                [list(f.vertices) for f in plate.data.polygons])
    samples = [('vertex', i, p, i in used) for i, p in enumerate(points)]
    for i, face in enumerate(faces):
        pts = [points[v] for v in face]
        samples.append(('centre', i, sum(pts, Vector()) / len(pts), True))
        samples.extend(('edge', i, (a+b)/2, True) for a, b in zip(pts, pts[1:]+pts[:1]))
    bad = []
    plate.data.calc_loop_triangles()
    solid = np.array([[list(plate.matrix_world @ plate.data.vertices[i].co) for i in t.vertices]
                      for t in plate.data.loop_triangles])
    obj.data.calc_loop_triangles()
    for kind, index, point, rendered in samples:
        near, normal, _, distance = tree.find_nearest(point)
        if (point-near).dot(normal) < 0 and inside(tree, point):
            p = solid-np.asarray(point)
            a, b, c = p[:, 0], p[:, 1], p[:, 2]
            la, lb, lc = (np.linalg.norm(x, axis=1) for x in (a, b, c))
            numerator = np.einsum('ij,ij->i', a, np.cross(b,c))
            denominator = la*lb*lc+np.einsum('ij,ij->i',a,b)*lc+np.einsum('ij,ij->i',b,c)*la+np.einsum('ij,ij->i',c,a)*lb
            winding = float((2*np.arctan2(numerator,denominator)).sum()/(4*np.pi))
            actual = []
            if kind == 'centre':
                for t in obj.data.loop_triangles:
                    if t.polygon_index != index:
                        continue
                    pts = [points[i] for i in t.vertices]
                    centre = sum(pts,Vector())/3
                    near, n, _, dist = tree.find_nearest(centre)
                    actual.append({'centre':list(centre),'distance':dist,'inside':inside(tree,centre),
                        'sample_off_triangle_m':(closest_point_on_tri(point,*pts)-point).length})
            bad.append({'kind': kind, 'index': index, 'point': list(point), 'rendered': rendered,
                        'inside_distance': distance, 'winding':winding,'actual_triangles':actual})
    Path(output).write_text(json.dumps({'unused_vertices': len(points)-len(used), 'inside_samples': bad}, indent=2)+'\n')
    print('MQ13_COLLISION_ATTRIBUTION: ' + json.dumps(bad))


if __name__ == '__main__':
    main(*sys.argv[sys.argv.index('--')+1:])
