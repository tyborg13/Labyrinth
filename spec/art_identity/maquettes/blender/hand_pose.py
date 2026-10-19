"""Close native CC0 fingers into a fist without replacing their topology.

The knuckle is found in the native hand's longitudinal distribution. The
distal skin follows a half-circle into the palm; lateral finger separation and
cross-section thickness remain native. No hand, limb or glove proxy is added.
"""
import json
import math
import numpy as np

HAND_DEFAULTS = {'knuckle_quantile': .55, 'epsilon': 1e-9,
                 'knuckle_search_quantiles': [.45, .5, .55, .6, .65, .7, .75, .8, .85],
                 'minimum_finger_vertices': 4, 'contact_solve_iterations': 48,
                 'proximal_quantile': .1, 'palm_surface_quantile': .95,
                 'proximal_web_fraction': .5,
                 'mcp_closed_angle_rad': math.pi / 2,
                 'interphalangeal_closed_angle_rad': math.pi,
                 'implementation_revision': 7}


def components(selected, faces):
    neighbours = {i: set() for i in np.flatnonzero(selected)}
    for face in faces:
        for a, b in zip(face, [*face[1:], face[0]]):
            if a in neighbours and b in neighbours:
                neighbours[a].add(b)
                neighbours[b].add(a)
    groups = []
    while neighbours:
        group, pending = [], [next(iter(neighbours))]
        while pending:
            index = pending.pop()
            if index in neighbours:
                group.append(index)
                pending.extend(neighbours.pop(index))
        groups.append(group)
    return groups


def closed_fingers(points, wrist, direction, inward, faces=None):
    points, wrist = np.asarray(points, float), np.asarray(wrist, float)
    axis = np.array(direction, float, copy=True)
    axis /= np.linalg.norm(axis)
    normal = np.array(inward, float, copy=True)
    normal -= axis * (normal @ axis)
    if np.linalg.norm(normal) <= HAND_DEFAULTS['epsilon']:
        raise ValueError('Fist needs a palm direction perpendicular to its fingers')
    normal /= np.linalg.norm(normal)
    lateral = np.cross(axis, normal)
    relative = points - wrist
    along = relative @ axis
    knuckle = float(np.quantile(along, HAND_DEFAULTS['knuckle_quantile']))
    groups = [np.flatnonzero(along > knuckle).tolist()]
    if faces is not None:
        # Separate the four native fingers beyond their webbing. The shorter
        # thumb stays on the palm side of this section instead of being bent
        # sideways using a shared longest-finger length.
        candidates = []
        for quantile in HAND_DEFAULTS['knuckle_search_quantiles']:
            cut = float(np.quantile(along, quantile))
            found = [g for g in components(along > cut, faces)
                     if len(g) >= HAND_DEFAULTS['minimum_finger_vertices']]
            if 4 <= len(found) <= 5:
                candidates.append((cut, found))
        if not candidates:
            raise ValueError('Native fist could not separate the four fingers')
        knuckle, groups = candidates[0]
        palm = relative[along <= knuckle]
        _, axes = np.linalg.eigh(np.cov(palm.T))
        palm_normal = axes[:, 0]
        palm_normal -= axis * (palm_normal @ axis)
        palm_normal /= np.linalg.norm(palm_normal)
        normal = palm_normal if palm_normal @ normal >= 0 else -palm_normal
        lateral = np.cross(axis, normal)
        # The separation plane crosses the webbing beyond the MCP knuckles.
        # Include the proximal phalanx before bending, otherwise only the
        # fingertips curl and the hand remains an open C. Extend half the
        # shortest native distal finger length into that web, assigning the
        # existing skin to its nearest lateral finger centre.
        sideways = relative @ lateral
        centres = np.array([np.mean(sideways[group]) for group in groups])
        old = np.concatenate(groups)
        extension = min(float(along[group].max() - knuckle) for group in groups)
        knuckle -= extension * HAND_DEFAULTS['proximal_web_fraction']
        selected = ((along > knuckle) & (sideways >= sideways[old].min()) &
                    (sideways <= sideways[old].max()))
        nearest = np.argmin(abs(sideways[:, None] - centres[None, :]), axis=1)
        groups = [np.flatnonzero(selected & (nearest == i)).tolist() for i in range(len(groups))]
    length = float(along.max() - knuckle)
    if length <= HAND_DEFAULTS['epsilon']:
        raise ValueError('Fist needs nonzero native distal finger length')
    result = points.copy()
    angles = []
    for group in groups:
        distance = along[group] - knuckle
        finger_length = float(distance.max())
        normal_coordinates = relative[group] @ normal
        proximal = normal_coordinates[distance <= np.quantile(distance, HAND_DEFAULTS['proximal_quantile'])]
        base_depth = float(np.mean(proximal))
        maximum_angle = math.pi
        if faces is not None:
            # Contact is against the palm under this finger, not the wrist
            # or the thumb's raised thenar pad. Those remote extrema prevent
            # a fist from closing even though the local palm is reachable.
            sideways = relative @ lateral
            local = ((along <= knuckle) & (along >= knuckle - finger_length) &
                     (sideways >= sideways[group].min()) & (sideways <= sideways[group].max()))
            if not local.any():
                raise ValueError('Native finger has no local palm contact surface')
            palm_depths = relative[local] @ normal
            palm_surface = float(np.quantile(palm_depths, HAND_DEFAULTS['palm_surface_quantile']))
            finger_radius = float(np.ptp(proximal) / 2)
            contact_height = max(HAND_DEFAULTS['epsilon'], palm_surface + finger_radius - base_depth)
            # Native palm/finger thickness determines closure. A half-circle
            # leaves fingertips beyond the palm; solve the returning arc so
            # every finger ends against the actual palm surface.
            lo = HAND_DEFAULTS['mcp_closed_angle_rad'] + HAND_DEFAULTS['interphalangeal_closed_angle_rad']
            hi = math.tau
            for _ in range(HAND_DEFAULTS['contact_solve_iterations']):
                middle = (lo + hi) / 2
                height = finger_length / middle * (1 - math.cos(middle))
                if height > contact_height:
                    lo = middle
                else:
                    hi = middle
            maximum_angle = (lo + hi) / 2
        angles.append(math.degrees(maximum_angle))
        angle = maximum_angle * distance / finger_length
        radius = finger_length / maximum_angle
        depth = normal_coordinates - base_depth
        side = relative[group] @ lateral
        result[group] = (wrist + axis * knuckle +
                         (radius * np.sin(angle) - depth * np.sin(angle))[:, None] * axis +
                         (base_depth + radius * (1 - np.cos(angle)) + depth * np.cos(angle))[:, None] * normal +
                         side[:, None] * lateral)
    thumb_count = 0
    if faces is not None:
        from .thumb_pose import oppose
        thumb_count = oppose(points, result, groups, along, normal, lateral)
    return result, {'knuckle_distance_m': knuckle, 'native_distal_length_m': length,
                    'curled_vertices': sum(len(group) for group in groups), 'finger_groups': len(groups),
                    'palm_contact_arc_degrees': angles,
                    'thumb_curled_vertices': thumb_count,
                    'native_vertices': len(points),
                    'maximum_axial_before_m': float(along.max()),
                    'maximum_axial_after_m': float(((result - wrist) @ axis).max())}


def apply(spec, body, rig, posed, owners):
    import bpy
    from .source_cage import unpose_point
    from .rig import evaluated_mesh
    requested = spec['base'].get('closed_hands', [])
    if not requested:
        return None
    points = np.array([list(v.co) for v in posed.data.vertices])
    regions = {b['name'] for b in spec['armature']['bones']}
    transforms = {name: np.asarray(rig.pose.bones[name].matrix @ rig.data.bones[name].matrix_local.inverted())
                  for name in regions}
    reports = {}
    for side in requested:
        part = 'hand_' + side
        indices = sorted({i for face, owner in zip(posed.data.polygons, owners)
                          if owner == part for i in face.vertices})
        wrist = np.array(spec['joints'][part])
        direction = np.subtract(spec['joints']['hand_tip_' + side], wrist)
        inward = np.subtract(spec['joints']['pelvis'], wrist)
        lookup = {index: i for i, index in enumerate(indices)}
        faces = [[lookup[i] for i in face.vertices] for face, owner in zip(posed.data.polygons, owners)
                 if owner == part]
        desired, report = closed_fingers(points[indices], wrist, direction, inward, faces)
        for index, point in zip(indices, desired):
            weights = {body.vertex_groups[g.group].name: g.weight for g in body.data.vertices[index].groups
                       if g.weight > 0 and body.vertex_groups[g.group].name in regions}
            body.data.vertices[index].co = unpose_point(point, [transforms[name] for name in weights],
                                                       list(weights.values()))
        report['passed'] = report['maximum_axial_after_m'] < report['maximum_axial_before_m']
        reports[part] = report
    body.data.update()
    bpy.context.view_layer.update()
    old = posed.data
    posed.data = evaluated_mesh(body)
    bpy.data.meshes.remove(old)
    posed['native_hand_pose'] = json.dumps(reports)
    return reports
