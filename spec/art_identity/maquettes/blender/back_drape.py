"""A continuous back rest surface fitted in the actual shoulder-yoke frame."""
from mathutils import Vector
from .conformance import body_tree
from .drape_collision import COLLIDER_DEFAULTS

BACK_DRAPE_DEFAULTS={'revision':1}


def fit_rest(obj,support,piece,spec):
    config=piece['drape']['back_rest']
    near,far=(Vector(spec['joints'][j]) for j in config['shoulders'])
    lateral=near-far;lateral.z=0;lateral.normalize()
    forward=lateral.cross(Vector((0,0,1)))
    tree=body_tree(support)
    margin=piece.get('solver_margin',piece['collision_margin'])+COLLIDER_DEFAULTS['initial_clearance']+piece['thick']/2
    inverse=obj.matrix_world.inverted()
    for vertex in obj.data.vertices:
        point=obj.matrix_world@vertex.co
        origin=point-forward*spec['ortho_scale']
        hit,_,_,_=tree.ray_cast(origin,forward)
        if hit is not None:
            difference=(hit-point).dot(forward)-margin
            if difference<0:vertex.co=inverse@(point+forward*difference)
    obj.data.update()


def radial_fit(obj,support,piece,spec):
    origin=Vector(spec['joints'][piece['drape']['radial_rest']['joint']])
    tree=body_tree(support)
    margin=piece.get('solver_margin',piece['collision_margin'])+COLLIDER_DEFAULTS['initial_clearance']+piece['thick']/2
    inverse=obj.matrix_world.inverted()
    for vertex in obj.data.vertices:
        point=obj.matrix_world@vertex.co
        centre=Vector((origin.x,origin.y,point.z))
        radial=point-centre
        if radial.length==0:continue
        direction=radial.normalized()
        hit,_,_,_=tree.ray_cast(centre+direction*spec['ortho_scale'],-direction)
        if hit is not None:
            radius=max(radial.length,(hit-centre).dot(direction)+margin)
            vertex.co=inverse@(centre+direction*radius)
    obj.data.update()
