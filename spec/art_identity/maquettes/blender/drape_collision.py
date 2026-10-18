"""Isolated native collision setup for opted-in simulated garments.

Each solver sees the full posed anatomy and a watertight outward-offset skin.
This avoids open anatomy interiors catching fabric or unrelated garment
colliders contaminating subsequent simulations. The final gate still measures
every cloth triangle against the complete, unchanged posed anatomy.
"""
import bpy
import json

from .cloth_contacts import project_constraints, stabilise_collision
from .rig import active


COLLIDER_DEFAULTS = {'voxel_size': .012, 'surface_allowance': .025,
                     'initial_clearance': .02}


def closed_anatomy(body):
    """Watertight, outward-offset native collision skin; never rendered."""
    name = 'native_drape_collision_skin'
    if name in bpy.data.objects:
        return bpy.data.objects[name]
    from .conformance import regional_body
    from .pieces import mesh_object
    vertices, faces = [], []
    # Each source triangle is contained by its owner's convex envelope.
    # Their voxel union closes internal skin folds without losing thin digits.
    for region in sorted(set(json.loads(body['face_owners']))):
        hull = regional_body(body, {'id': 'solver_envelope_' + region,
            'body_regions': [region], 'contact_hull': True})
        count = len(vertices)
        vertices.extend(list(hull.matrix_world @ v.co) for v in hull.data.vertices)
        faces.extend([i + count for i in p.vertices] for p in hull.data.polygons)
    obj = mesh_object(name, vertices, faces)
    active(obj)
    remesh = obj.modifiers.new('closed_anatomy', 'REMESH')
    remesh.mode = 'VOXEL'
    remesh.voxel_size = COLLIDER_DEFAULTS['voxel_size']
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    # Voxelization closes mouth/finger interiors and tiny source-cage folds.
    # The outward allowance keeps the solver skin outside the original model.
    offset = obj.modifiers.new('anatomy_clearance', 'DISPLACE')
    offset.direction = 'NORMAL'
    offset.strength = COLLIDER_DEFAULTS['surface_allowance']
    offset.mid_level = 0
    bpy.ops.object.modifier_apply(modifier=offset.name)
    obj['native_source'] = True
    obj.hide_render = True
    return obj


def prepare(obj, body, piece, spec):
    collection = bpy.data.collections.new('solver_' + piece['id'])
    bpy.context.scene.collection.children.link(collection)
    collection.objects.link(body)
    support = closed_anatomy(body)
    support.hide_set(False)
    support.modifiers.new('native_collision', 'COLLISION')
    support.collision.thickness_outer = piece['collision_margin']
    support.collision.thickness_inner = piece['collision_margin']
    collection.objects.link(support)
    bpy.context.view_layer.update()
    if piece['drape'].get('waist_anchor_px'):
        from mathutils import Vector
        from .conformance import body_tree
        from .source_recipe import paired_point
        anchor = Vector(paired_point(spec, *piece['drape']['waist_anchor_px']))
        direction = Vector((1 if piece['drape']['waist_side'] == 'front' else -1, 0, 0))
        tree = body_tree(support)
        hit, normal, _, _ = tree.ray_cast(anchor + direction * spec['ortho_scale'], -direction)
        if hit is None:
            raise ValueError('Waist attachment ray missed the native anatomy')
        centre = sum((obj.data.vertices[i].co for i in piece['_native_pins']), Vector()) / len(piece['_native_pins'])
        position = hit + direction * (piece['solver_margin'] + COLLIDER_DEFAULTS['initial_clearance'])
        position.y, position.z = anchor.y, anchor.z
        shift = position - centre
        for vertex in obj.data.vertices:
            vertex.co += shift
        obj.data.update()
    if piece['drape'].get('radial_rest'):
        from .back_drape import radial_fit
        radial_fit(obj, support, piece, spec)
    if piece['drape'].get('back_rest'):
        from .back_drape import fit_rest
        fit_rest(obj, support, piece, spec)
    # Start free fabric clear of the collider's friction band. Starting every
    # vertex exactly on that band can immobilize a whole fitted garment.
    initial_piece = dict(piece)
    initial_piece['solver_margin'] = piece.get('solver_margin', piece['collision_margin']) + COLLIDER_DEFAULTS['initial_clearance']
    project_constraints(obj, support, initial_piece)
    targets = {}
    if piece['drape'].get('back_sheet'):
        from mathutils import Vector
        targets = {i: Vector(p) for i, p in enumerate(json.loads(obj['back_sheet_report'])['pin_targets'])}
    if piece['drape'].get('attach_pins_to_support'):
        from .conformance import body_tree
        tree = body_tree(support)
        inverse = obj.matrix_world.inverted()
        margin = piece.get('solver_margin', piece['collision_margin']) + piece['thick'] / 2
        for i in piece['_native_pins']:
            point, normal, _, _ = tree.find_nearest(obj.matrix_world @ obj.data.vertices[i].co)
            targets[i] = inverse @ (point + normal * margin)
            if not piece['drape'].get('gather_frames'):
                obj.data.vertices[i].co = targets[i]
        obj.data.update()
    if piece['drape'].get('yoke_seam_joint'):
        obj['attachment_report']=json.dumps({'joint':piece['drape']['yoke_seam_joint'],
            'source_seam_length':piece['yoke_seam_length'],'pin_targets':{str(i):list(p) for i,p in targets.items()}})
    if spec.get('rear_body', {}).get('hem_piece') == piece['id']:
        from .rear_body import prepare_floor
        prepare_floor(obj, piece, spec, collection)
    return collection, support, targets


def finish(collection, support, targets):
    support.hide_set(True)
    support.modifiers.clear()
    bpy.data.collections.remove(collection)


def regional_contacts(obj, support, body, piece):
    """Resolve a concave union contact with explicit native regional envelopes.

    The cloth solve and its folds are retained. This optional final refinement
    avoids alternating nearest normals where an arm meets the torso; the gate
    still checks every triangle against the complete original source anatomy.
    """
    settings = piece['drape'].get('regional_contact')
    if not settings:
        return
    from .conformance import regional_body
    refinement = dict(piece, collision_refine_levels=settings['refine_levels'])
    stabilise_collision(obj, support, refinement)
    groups = [settings['regions']] if settings.get('union_regions') else [[r] for r in settings['regions']]
    for regions in groups:
        hull = regional_body(body, {'id': 'final_' + piece['id'] + '_' + '_'.join(regions),
            'body_regions': regions, 'contact_hull': True})
        project_constraints(obj, hull, piece)
