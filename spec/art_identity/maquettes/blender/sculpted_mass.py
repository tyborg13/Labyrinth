"""Editable displaced ellipsoids and chipped boulders; dimensions live in recipes.

The same evaluated mesh supplies clay, ownership and unoccluded solos. Relief
and grooves are geometry modifiers, never textures painted onto a proxy.
"""
import math


MASS_DEFAULTS = {'sphere_segments': 64, 'sphere_rings': 32,
                 'weight_epsilon': 1e-8}


def point_segment_distance(point, start, end):
    delta = end - start
    t = max(0, min(1, (point - start).dot(delta) / max(delta.length_squared, MASS_DEFAULTS['weight_epsilon'])))
    return (point - (start + t * delta)).length


def sculpted_mass(piece, spec):
    import bpy
    from mathutils import Vector
    from .pieces import place, mesh_object
    from .mass_topology import ico_sphere, uv_sphere, clip_convex, outward_faces
    profile = piece.get('profile')
    if profile:
        from .sculpt_profile import PROFILE_DEFAULTS
        vertices, faces = ico_sphere(profile.get('seed_subdivisions',PROFILE_DEFAULTS['seed_subdivisions']))
    elif piece['surface'] == 'boulder':
        vertices, faces = ico_sphere(piece['ico_subdivisions'])
    else:
        vertices, faces = uv_sphere(MASS_DEFAULTS['sphere_segments'], MASS_DEFAULTS['sphere_rings'])
    # Bake metric dimensions before native bevel/displacement, so their widths
    # remain actual metres on each differently proportioned mass.
    if piece['surface'] == 'boulder':
        vertices = [[v[i]*piece['radii'][i] for i in range(3)] for v in vertices]
        if profile:
            # Dense radial projection retains samples across every fracture
            # plane, so relief is not interpolated across one giant cap ngon.
            for point in vertices:
                factor = 1.
                for chip in piece['chips']:
                    normal = Vector(chip['normal']).normalized()
                    distance = Vector(point).dot(normal)
                    if distance > chip['distance']:
                        factor = min(factor,chip['distance']/distance)
                for axis in range(3):point[axis] *= factor
        else:
            for chip in piece['chips']:
                vertices, faces = clip_convex(vertices, faces, chip['normal'], chip['distance'])
    obj = mesh_object(piece['id'], vertices, faces)
    if piece['surface'] == 'organic':
        for vertex in obj.data.vertices:
            for axis in range(3):
                vertex.co[axis] *= piece['radii'][axis]
    if piece.get('swept_sections'):
        from .limb_mesh import section_mesh
        vertices=[list(v.co) for v in obj.data.vertices];faces=[list(p.vertices) for p in obj.data.polygons]
        for section in piece['swept_sections']:
            path=[[point[i]-piece['centre'][i] for i in range(3)] for point in section['path']]
            v,f=section_mesh(path,section['radii'],section['sculpt'])
            start=len(vertices);vertices.extend(v);faces.extend([[start+i for i in face] for face in f])
        old=obj.data;mesh=bpy.data.meshes.new(piece['id']+'_compound_rest')
        mesh.from_pydata(vertices,[],faces);mesh.update();obj.data=mesh;bpy.data.meshes.remove(old)
        union=obj.modifiers.new('sculpted_section_union','REMESH');union.mode='VOXEL'
        union.voxel_size=piece['union_voxel_size'];union.use_smooth_shade=True
    references = [vertex.co.copy() for vertex in obj.data.vertices]
    if profile:
        from .sculpt_profile import deform
        for vertex in obj.data.vertices:
            vertex.co = deform(vertex.co,piece['radii'],profile)
            if piece['surface']=='boulder':
                factor=1.
                for chip in piece['chips']:
                    distance=vertex.co.dot(Vector(chip['normal']).normalized())
                    if distance>chip['distance']:factor=min(factor,chip['distance']/distance)
                vertex.co *= factor
        obj['modelled_profile'] = True
    place(obj, piece, spec)
    obj.location += Vector(piece['centre'])
    bpy.context.view_layer.update()
    from .mass_fracture import fracture, ground
    fracture(obj,piece)
    if profile:
        from .mass_fracture import difference
        inverse=obj.matrix_world.inverted()
        for index,cutout in enumerate(piece.get('cutouts',[])):
            vertices=[list(inverse @ Vector(p)) for p in cutout['vertices']]
            difference(obj,'modelled_feature_inset_'+str(index),vertices,
                       outward_faces(vertices,cutout['faces']))
    if piece['surface'] == 'boulder':
        bevel = obj.modifiers.new('modelled_chipped_bevel', 'BEVEL')
        bevel.width = piece['bevel']['width']
        bevel.segments = piece['bevel']['segments']
        bevel.limit_method = 'ANGLE'
        bevel.angle_limit = piece['bevel']['angle_limit']
    subdiv = obj.modifiers.new('rounded_mass_subdivision', 'SUBSURF')
    subdiv.subdivision_type = 'CATMULL_CLARK'
    subdiv.levels = piece['subdivision_levels']
    subdiv.render_levels = piece['subdivision_levels']
    from .surface_relief import relief_weight
    relief_group = obj.vertex_groups.new(name='deterministic_surface_relief')
    for vertex in obj.data.vertices:
        if profile:
            from .sculpt_profile import sculpt_weight
            weight = sculpt_weight(vertex.co,piece['relief'],profile)
        else:
            weight = relief_weight(vertex.co, piece['relief']['scale'], piece['relief']['depth'])
        relief_group.add([vertex.index], weight, 'REPLACE')
        normal = Vector([vertex.co[i]/piece['radii'][i]**2 for i in range(3)]).normalized()
        vertex.co -= normal * piece['relief']['strength'] * .5
    relief = obj.modifiers.new('modelled_surface_relief', 'DISPLACE')
    relief.vertex_group = relief_group.name
    relief.strength = piece['relief']['strength']
    relief.mid_level = 0
    bpy.context.view_layer.update()
    if piece.get('grooves'):
        group = obj.vertex_groups.new(name='whole_shell_crack_grooves')
        inverse = obj.matrix_world.inverted()
        paths = [[inverse @ Vector(p) for p in path] for path in piece['grooves']['paths']]
        for vertex in obj.data.vertices:
            reference = references[vertex.index] if profile else vertex.co
            distance = min(point_segment_distance(reference, a, b) for path in paths for a, b in zip(path, path[1:]))
            weight = math.exp(-distance * distance / piece['grooves']['width'] ** 2)
            if weight > MASS_DEFAULTS['weight_epsilon']:
                group.add([vertex.index], weight, 'REPLACE')
        groove = obj.modifiers.new('carved_whole_cracks', 'DISPLACE')
        groove.vertex_group = group.name
        groove.strength = -piece['grooves']['depth']
        groove.mid_level = 0
        obj['whole_crack_count'] = len(paths)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    for index, cutout in enumerate([] if profile else piece.get('cutouts', [])):
        cutter = mesh_object(piece['id']+'_inset_'+str(index), cutout['vertices'],
                             outward_faces(cutout['vertices'], cutout['faces']))
        cutter.hide_render = True
        cutter.hide_set(True)
        cutter['native_source'] = True
        cutter.parent = obj
        from mathutils import Matrix
        cutter.matrix_world = Matrix.Identity(4)
        modifier = obj.modifiers.new('modelled_feature_inset_'+str(index), 'BOOLEAN')
        modifier.operation = 'DIFFERENCE'
        modifier.solver = 'EXACT'
        modifier.object = cutter
    ground(obj,piece)
    return obj


def validate_mass(piece):
    from .contract import vector
    vector(piece['centre'], 3, 'mass centre')
    vector(piece['radii'], 3, 'mass radii')
    if min(piece['radii']) <= 0 or piece['surface'] not in ('organic', 'boulder'):
        raise ValueError('Mass requires positive radii and organic/boulder surface')
    if type(piece['subdivision_levels']) is not int or piece['subdivision_levels'] < 1:
        raise ValueError('Mass requires real subdivision')
    if any(not math.isfinite(piece['relief'][key]) or piece['relief'][key] <= 0
           for key in ('strength', 'scale')):
        raise ValueError('Mass requires modelled surface relief')
    if piece['surface'] == 'boulder':
        if not piece['chips'] or piece['bevel']['width'] <= 0 or piece['bevel']['segments'] < 2:
            raise ValueError('Boulder requires explicit chips and modelled rounded bevels')
        if type(piece['ico_subdivisions']) is not int or piece['ico_subdivisions'] < 1:
            raise ValueError('Boulder requires a native subdivided seed')
        for chip in piece['chips']:
            vector(chip['normal'], 3, 'chip normal')
            if sum(x*x for x in chip['normal']) <= 0 or not math.isfinite(chip['distance']) or chip['distance'] <= 0:
                raise ValueError('Chip requires a nonzero normal and positive finite plane distance')
    if piece.get('grooves'):
        grooves = piece['grooves']
        if min(grooves['width'], grooves['depth']) <= 0 or not grooves['paths'] or any(len(p) < 2 for p in grooves['paths']):
            raise ValueError('Grooves require whole nonempty paths and positive width/depth')
        for path in grooves['paths']:
            for point in path:
                vector(point, 3, 'groove point')
    if piece.get('swept_sections'):
        if not 0 < piece['union_voxel_size'] <= min(piece['radii']):
            raise ValueError('Section union requires a positive sub-radius voxel size')
        from .limb_mesh import validate_sculpt
        for section in piece['swept_sections']:
            if len(section['path']) != len(section['radii']) or min(section['radii']) <= 0:
                raise ValueError('Swept sections require corresponding positive radii')
            validate_sculpt(section['sculpt'])
    from .mass_topology import validate_volume
    if piece.get('profile'):
        from .sculpt_profile import validate_profile
        validate_profile(piece['profile'])
    for fracture in piece.get('fractures',[]):
        if fracture.get('shape','box') not in ('box','wedge'):raise ValueError('Unknown fracture volume')
        for key in ('centre','size','rot'):vector(fracture[key],3,'fracture '+key)
        if min(fracture['size']) <= 0:raise ValueError('Fracture requires positive volume')
    if 'support_z' in piece and (not math.isfinite(piece['support_z']) or piece['rot'] != [0,0,0] or
                               not piece.get('minimum_support_thickness',0) > 0):
        raise ValueError('Ground support requires a finite plane and unrotated mass')
    for volume in piece.get('cutouts', []):
        validate_volume(volume)


def native_stack_matches(piece, source):
    if source is None:
        return False
    modifiers = {m.name: m for m in source.modifiers}
    # Hidden editable sources still require active viewport AND render stacks.
    if any(not getattr(m,'show_viewport',False) or not getattr(m,'show_render',False)
           for m in source.modifiers if m.type != 'ARMATURE'):
        return False
    subdiv = modifiers.get('rounded_mass_subdivision')
    relief = modifiers.get('modelled_surface_relief')
    passed = (subdiv is not None and subdiv.type == 'SUBSURF' and
              subdiv.render_levels == piece['subdivision_levels'] and
              getattr(subdiv,'levels',None) == piece['subdivision_levels'] and
              relief is not None and relief.type == 'DISPLACE' and
              abs(relief.strength-piece['relief']['strength']) <= MASS_DEFAULTS['weight_epsilon'])
    if piece['surface'] == 'boulder':
        bevel = modifiers.get('modelled_chipped_bevel')
        passed &= (bevel is not None and bevel.type == 'BEVEL' and
                   bevel.segments == piece['bevel']['segments'] and
                   abs(bevel.width-piece['bevel']['width']) <= MASS_DEFAULTS['weight_epsilon'])
    if piece.get('grooves'):
        groove = modifiers.get('carved_whole_cracks')
        passed &= (groove is not None and groove.type == 'DISPLACE' and
                   abs(groove.strength+piece['grooves']['depth']) <= MASS_DEFAULTS['weight_epsilon'] and
                   source.get('whole_crack_count') == len(piece['grooves']['paths']))
    for index, _ in enumerate(piece.get('cutouts', [])):
        cutout = modifiers.get('modelled_feature_inset_'+str(index))
        passed &= (cutout is not None and cutout.type == 'BOOLEAN' and
                   cutout.operation == 'DIFFERENCE' and cutout.solver == 'EXACT' and cutout.object is not None)
    for name in (['modelled_fracture_'+str(i) for i in range(len(piece.get('fractures',[])))] +
                 (['support_ground_clip'] if 'support_z' in piece else [])):
        modifier=modifiers.get(name)
        passed &= (modifier is not None and modifier.type == 'BOOLEAN' and
                   modifier.operation == 'DIFFERENCE' and modifier.solver == 'EXACT' and modifier.object is not None)
    if piece.get('swept_sections'):
        union=modifiers.get('sculpted_section_union')
        passed &= (union is not None and union.type=='REMESH' and union.mode=='VOXEL' and
                   abs(union.voxel_size-piece['union_voxel_size']) <= MASS_DEFAULTS['weight_epsilon'])
    if piece.get('profile'):
        passed &= bool(source.get('modelled_profile'))
    return bool(passed)


def frozen_differs_from_base(source,frozen):
    """Compare actual mesh data, not a claimed modifier flag or cached summary."""
    if source is None or frozen is None:return False
    from .contract import digest
    def geometry(obj):
        return {'vertices':[list(v.co) for v in obj.data.vertices],
                'faces':[list(p.vertices) for p in obj.data.polygons]}
    return digest(geometry(source)) != digest(geometry(frozen))
