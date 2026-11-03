"""Bridge-only mq-13 measurements of the saved, unmodified native body."""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))


def main(spec_path, build, output):
    from spec.art_identity.maquettes.gloam_stalker.saved_body import load, verify_geometry
    spec, report, objects, native_hash = load(spec_path, build)
    import bpy
    import numpy as np
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    from spec.art_identity.maquettes.blender.contract import digest
    from spec.art_identity.maquettes.blender.capture_view import signature
    from spec.art_identity.maquettes.raster import project
    before = signature(objects)
    hood = bpy.data.objects['hood_render']
    indices = set(json.loads(hood['articulated_head_cover_indices']))
    cover = [list(hood.matrix_world @ v.co) for v in hood.data.vertices if v.index in indices]
    back = [list(hood.matrix_world @ v.co) for v in hood.data.vertices if v.index not in indices]
    shell = bpy.data.objects['back_carapace_render']
    plates = [list(shell.matrix_world @ v.co) for v in shell.data.vertices]
    result = {'spec_hash': digest(spec), 'native_mesh_hash': native_hash,
              'loaded_geometry_verified': True, 'views': {}}
    from spec.art_identity.maquettes.blender.rigid_clearance import components
    edge_uses = {}
    for face in shell.data.polygons:
        ring = list(face.vertices)
        for a, b in zip(ring, ring[1:] + ring[:1]):
            key = tuple(sorted((a, b)))
            edge_uses[key] = edge_uses.get(key, 0) + 1
    result['carapace_closed_components'] = len(components(len(plates), list(edge_uses)))
    result['carapace_manifold_edges'] = all(n == 2 for n in edge_uses.values())
    result['carapace_seating'] = json.loads(shell['rigid_clearance_report'])
    from spec.art_identity.maquettes.blender.back_plate_seat import plate_frame
    lateral = np.subtract(spec['joints']['shoulder_far'], spec['joints']['shoulder_near'])
    cloth_points, cloth_faces = [], []
    for piece in spec['pieces']:
        if piece['type'] != 'cloth':
            continue
        cloth = bpy.data.objects[piece['id'] + '_render']
        offset = len(cloth_points)
        cloth_points.extend(cloth.matrix_world @ v.co for v in cloth.data.vertices)
        cloth_faces.extend([i + offset for i in face.vertices] for face in cloth.data.polygons)
    cloth_tree = BVHTree.FromPolygons(cloth_points, cloth_faces)
    result['carapace_layers'] = [{'normal': plate_frame(np.array(plates)[ids], lateral, -np.array(spec['articulated_pose']['facing']))[:, 2].tolist(),
        'minimum_vertex_to_cloth_gap_m': min(cloth_tree.find_nearest(Vector(plates[i]))[3] for i in ids),
        'world_span_m': np.ptp(np.array(plates)[ids], axis=0).tolist(),
        'front_bounds_px': [project(spec, np.array(plates)[ids])[:, :2].min(0).tolist(),
                            project(spec, np.array(plates)[ids])[:, :2].max(0).tolist()]}
        for ids in components(len(plates), list(edge_uses))]
    feet = {}
    for side in ('near', 'far'):
        foot = next(o for o in objects if o['part'] == 'foot_' + side)
        used = {i for face in foot.data.polygons for i in face.vertices}
        feet[side] = min((foot.matrix_world @ foot.data.vertices[i].co).z for i in used)
    result['sole_min_z_m'] = feet
    result['sole_height_difference_m'] = abs(feet['near'] - feet['far'])
    result['floor_corrective'] = json.loads(bpy.data.objects['posed_body']['articulated_floor_contact'])
    rig = bpy.data.objects['maquette_armature']
    result['joint_errors_m'] = {b['name']: max(
        (rig.pose.bones[b['name']].head - Vector(spec['joints'][b['head']])).length,
        (rig.pose.bones[b['name']].tail - Vector(spec['joints'][b['tail']])).length) for b in spec['armature']['bones']}
    for view in ('front', 'rear'):
        head_top = float(project(spec, cover, view)[:, 1].min())
        back_pixels = project(spec, back, view)[:, :2]
        plate_pixels = project(spec, plates, view)[:, :2]
        shoulder_span = [float(back_pixels[:, 0].min()), float(back_pixels[:, 0].max())]
        plate_span = [float(plate_pixels[:, 0].min()), float(plate_pixels[:, 0].max())]
        overhang = max(0, shoulder_span[0] - plate_span[0], plate_span[1] - shoulder_span[1])
        back_top = float(back_pixels[:, 1].min())
        result['views'][view] = {'hood_top_y': head_top, 'back_top_y': back_top,
            'hood_above_back_px_report_only': back_top - head_top, 'shoulder_silhouette_span_x': shoulder_span,
            'carapace_span_x': plate_span, 'carapace_overhang_px': overhang,
            'carapace_overhang_passed': overhang <= 40}
    result['geometry_unchanged'] = signature(objects) == before
    verify_geometry(objects, report)
    result['native_geometry_passed'] = report['passed']
    Path(output).write_text(json.dumps(result, indent=2) + '\n')
    print('MQ13_NATIVE_OBSERVATIONS: COMPLETE; geometry_unchanged=' + str(result['geometry_unchanged']))


if __name__ == '__main__':
    main(*sys.argv[sys.argv.index('--') + 1:])
