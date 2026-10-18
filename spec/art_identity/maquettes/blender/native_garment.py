"""Continuous sewn rest surface tailored on native posed anatomy.

The watertight anatomical support supplies a connected shoulder/arm junction.
Neck, waist and cuff boundaries are cut open before native Cloth is added.
This mesh is free fabric, not a rendered rigid shell or an alternate anatomy.
"""
import json
import bpy
import bmesh
from mathutils import Vector

from .rig import active
from .pieces import mesh_object
from .conformance import body_tree
from .drape_collision import closed_anatomy

NATIVE_REST_DEFAULTS = {'revision': 1, 'voxel_size': .022, 'smoothing_iterations': 4,
                        'smoothing_factor': .5, 'upper_cuff_pins': 2}


def make(obj, body, piece, spec):
    settings = piece['drape']['native_rest']
    support = closed_anatomy(body)
    source = support.data.copy()
    old = obj.data
    obj.data = source
    bpy.data.meshes.remove(old)
    active(obj)
    remesh = obj.modifiers.new('sewn_rest_sampling', 'REMESH')
    remesh.mode = 'VOXEL'
    remesh.voxel_size = NATIVE_REST_DEFAULTS['voxel_size']
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    smooth = obj.modifiers.new('sewn_rest_relax', 'SMOOTH')
    smooth.factor = NATIVE_REST_DEFAULTS['smoothing_factor']
    smooth.iterations = NATIVE_REST_DEFAULTS['smoothing_iterations']
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    tree = body_tree(body)
    source_owners = json.loads(body['face_owners'])
    topology = bmesh.new()
    topology.from_mesh(obj.data)
    owner_layer = topology.faces.layers.int.new('sewn_owner')
    allowed = set(piece['sewn_parts'])
    neckline = None
    if settings.get('neckline_px'):
        from .source_recipe import paired_point
        neckline = paired_point(spec, *settings['neckline_px'])[2]
    discard = []
    for face in topology.faces:
        centre = face.calc_center_median()
        _, _, index, _ = tree.find_nearest(centre)
        owner = source_owners[index]
        keep = owner in allowed
        if neckline is not None and centre.z > neckline:
            keep = False
        if owner == piece['part'] and centre.z < spec['joints'][settings['waist_joint']][2]:
            keep = False
        for cuff in settings['cuffs']:
            if owner in cuff['regions']:
                elbow, hand = (Vector(spec['joints'][j]) for j in cuff['joints'])
                axis = hand - elbow
                if (centre - elbow).dot(axis) / axis.length_squared > cuff['fraction']:
                    keep = False
        if not keep:
            discard.append(face)
        else:
            face[owner_layer] = list(spec['labels']).index(owner)
    bmesh.ops.delete(topology, geom=discard, context='FACES')
    bmesh.ops.delete(topology, geom=[v for v in topology.verts if not v.link_faces], context='VERTS')
    components, pending = [], set(topology.verts)
    while pending:
        component, stack = set(), [min(pending, key=lambda v: tuple(v.co))]
        while stack:
            vertex = stack.pop()
            if vertex in pending:
                pending.remove(vertex)
                component.add(vertex)
                stack.extend(e.other_vert(vertex) for e in vertex.link_edges)
        components.append(component)
    components.sort(key=lambda group: -len(group))
    removed_components = [len(group) for group in components[1:]]
    if len(components) > 1:
        bmesh.ops.delete(topology, geom=[v for group in components[1:] for v in group], context='VERTS')
    represented = {face[owner_layer] for face in topology.faces}
    if represented != {list(spec['labels']).index(p) for p in piece['sewn_parts']}:
        raise ValueError('Removing rest-sampling islands would erase a required garment part')
    topology.verts.index_update()
    # Sewn neck/waist rims attach to the body. Only the upper two points of
    # either open cuff attach at a wrist; the remaining cuff fabric droops.
    remaining = {v for v in topology.verts if v.is_boundary}
    pins = []
    loops = []
    while remaining:
        start = min(remaining, key=lambda v: v.index)
        loop, stack = [], [start]
        while stack:
            vertex = stack.pop()
            if vertex in remaining:
                remaining.remove(vertex)
                loop.append(vertex)
                stack.extend(e.other_vert(vertex) for e in vertex.link_edges if e.is_boundary)
        loops.append(loop)
    for loop in loops:
        centre = sum((v.co for v in loop), Vector()) / len(loop)
        if not settings['cuffs']:
            pins.extend(v.index for v in loop)
            continue
        nearest_cuff = min(settings['cuffs'], key=lambda c: (centre - Vector(spec['joints'][c['joints'][-1]])).length)
        wrist_distance = (centre - Vector(spec['joints'][nearest_cuff['joints'][-1]])).length
        torso_distance = min(abs(centre.z - spec['joints'][settings['waist_joint']][2]),
                             (centre - Vector(spec['joints']['head'])).length)
        if wrist_distance < torso_distance:
            pins.extend(v.index for v in sorted(loop, key=lambda v: (-v.co.z, v.index))[:NATIVE_REST_DEFAULTS['upper_cuff_pins']])
        else:
            pins.extend(v.index for v in loop)
    topology.to_mesh(obj.data)
    topology.free()
    from .sewn_garment import topology_report
    report = topology_report([list(v.co) for v in obj.data.vertices], [list(p.vertices) for p in obj.data.polygons])
    report.update(source='native anatomy union / sewn shoulder rest surface', regions=list(piece['sewn_parts']),
                  pins=len(pins), vertices=len(obj.data.vertices), removed_sampling_islands=removed_components, defaults=NATIVE_REST_DEFAULTS)
    obj['sewn_rest_report'] = json.dumps(report)
    print('SEWN_NATIVE_REST: ' + json.dumps(report), flush=True)
    if not report['connected'] or report['nonmanifold_edges']:
        raise ValueError('Native sewn rest surface is disconnected or nonmanifold')
    return sorted(set(pins))
