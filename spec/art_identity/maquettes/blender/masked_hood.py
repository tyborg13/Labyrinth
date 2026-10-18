"""Fit a source-defined mask aperture and native curved metal face plate."""
import json
import numpy as np

from ..raster import camera,project
from .source_recipe import plane_point
from .cloth_cutouts import cut_pattern

MASK_DEFAULTS={'source_size':256,'ray_distance':30}


def contains(point,polygon):
    x,y=point
    result=False
    for a,b in zip(polygon,polygon[1:]+polygon[:1]):
        if (a[1]>y)!=(b[1]>y) and x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]:result=not result
    return result


def aperture(obj,pins,piece,spec):
    import bpy
    mask=next(p for p in spec['pieces'] if p['id']==piece['drape']['native_hood']['mask_piece'])
    polygon=mask['source_outline_px']
    report=json.loads(obj['rounded_hood_report'])
    centre=np.mean(report['head_bounds'],axis=0)
    points=np.array([list(obj.matrix_world@v.co) for v in obj.data.vertices])
    pixels=project(spec,points,'front',MASK_DEFAULTS['source_size'])[:,:2]
    matrix,_,basis,_=camera(spec,'front')
    toward=basis[2]@matrix[:3,:3]
    faces=[list(p.vertices) for p in obj.data.polygons]
    blocked=set()
    for i,face in enumerate(faces):
        if (points[face].mean(0)-centre)@toward<=0:continue
        samples=[pixels[j] for j in face]+[pixels[face].mean(0)]
        if any(contains(p,polygon) for p in samples):blocked.add(i)
    faces,pins=cut_pattern(faces,blocked,pins)
    old=obj.data;mesh=bpy.data.meshes.new(piece['id']+'_mask_aperture')
    mesh.from_pydata([list(v.co) for v in old.vertices],[],faces);mesh.update();obj.data=mesh;bpy.data.meshes.remove(old)
    report.update(opening_mode='source_mask',mask_piece=mask['id'],mask_source_outline_px=polygon,cut_faces=len(blocked))
    obj['rounded_hood_report']=json.dumps(report)
    return pins


def fit_plate(obj,piece,spec,body):
    import bpy
    from mathutils import Vector
    from .conformance import regional_body,body_tree
    target=(bpy.data.objects[piece['seat_on']+'_render'] if piece.get('seat_on') else
            regional_body(body,{'id':'mask_'+piece['id'],'body_regions':['head'],'contact_hull':True}))
    tree=body_tree(target)
    points=[target.matrix_world@v.co for v in target.data.vertices]
    centre=sum(points,Vector())/len(points)
    matrix,_,basis,_=camera(spec,'front');direction=Vector(basis[2]@matrix[:3,:3]).normalized()
    vertices=[]
    pixels=piece['source_outline_px']
    for i,pixel in enumerate(pixels+[np.mean(pixels,axis=0).tolist()]):
        origin=Vector(plane_point(spec,pixel,2,0))
        hit,_,_,_=tree.ray_cast(origin+direction*MASK_DEFAULTS['ray_distance'],-direction)
        if hit is None:
            nearest,_,_,_=tree.find_nearest(origin+direction*(centre-origin).dot(direction))
            hit=origin+direction*(nearest-origin).dot(direction)
        point=hit+direction*piece['thick']
        if str(i) in piece.get('spatial_anchors',{}):point=Vector(piece['spatial_anchors'][str(i)])
        vertices.append(list(point))
    if piece.get('closed_cover'):
        # A curved plate interpolated between sparse rim samples can sink into
        # a convex cloth cowl. A continuous cover plane clears every native
        # cloth sample under the measured gold-mask footprint.
        samples=np.array([list(target.matrix_world@v.co) for v in target.data.vertices])
        projected=project(spec,samples,'front',MASK_DEFAULTS['source_size'])[:,:2]
        selected=[p for p,xy in zip(samples,projected) if contains(xy,pixels)]
        depth=max(np.dot(p,direction) for p in selected)+piece['thick']
        vertices=[list(Vector(p)+direction*(depth-Vector(p).dot(direction))) for p in vertices]
    count=len(pixels);faces=[[i,(i+1)%count,count] for i in range(count)]
    old=obj.data;mesh=bpy.data.meshes.new(piece['id']+'_native_fitted');mesh.from_pydata(vertices,[],faces);mesh.update();obj.data=mesh;bpy.data.meshes.remove(old)
    obj['conformed_corners']=json.dumps(vertices[:count])
    obj['source_mask_fit']=json.dumps({'source_outline_px':pixels,'anchors':piece.get('spatial_anchors',{}),
        'target':piece.get('seat_on','native head convex surface')})
