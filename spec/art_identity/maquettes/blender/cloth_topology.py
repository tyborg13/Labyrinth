"""Lossless native mesh topology for cloth replay before Solidify evaluation.

Solidify emits rim polygons in edge order. Reconstructing edges from faces
changes raw evaluated polygon/loop ordering despite identical geometry.
Cache revision 8 preserves the original RNA arrays instead.
"""
import bpy

from .cloth_cache import topology_hash
from .contract import mesh_hash


def snapshot(mesh):
    payload = {'vertices': [list(v.co) for v in mesh.vertices],
               'faces': [list(p.vertices) for p in mesh.polygons],
               'edges': [list(e.vertices) for e in mesh.edges],
               'loop_vertices': [loop.vertex_index for loop in mesh.loops],
               'loop_edges': [loop.edge_index for loop in mesh.loops],
               'polygon_starts': [p.loop_start for p in mesh.polygons],
               'polygon_totals': [p.loop_total for p in mesh.polygons],
               'polygon_smooth': [p.use_smooth for p in mesh.polygons]}
    if 'sewn_owner' in mesh.attributes:
        payload['sewn_owners'] = [a.value for a in mesh.attributes['sewn_owner'].data]
    payload['mesh_hash'] = mesh_hash(payload['vertices'], payload['faces'])
    payload['topology_hash'] = topology_hash(payload)
    return payload


def restore(name, payload):
    if 'topology_hash' not in payload:
        raise ValueError('Cloth cache lacks lossless topology; rebuild with cache revision 8')
    data = bpy.data.meshes.new(name)
    data.vertices.add(len(payload['vertices']))
    data.vertices.foreach_set('co', [x for v in payload['vertices'] for x in v])
    data.edges.add(len(payload['edges']))
    data.edges.foreach_set('vertices', [i for e in payload['edges'] for i in e])
    data.loops.add(len(payload['loop_vertices']))
    data.loops.foreach_set('vertex_index', payload['loop_vertices'])
    data.loops.foreach_set('edge_index', payload['loop_edges'])
    data.polygons.add(len(payload['polygon_starts']))
    data.polygons.foreach_set('loop_start', payload['polygon_starts'])
    data.polygons.foreach_set('loop_total', payload['polygon_totals'])
    data.polygons.foreach_set('use_smooth', payload['polygon_smooth'])
    if 'sewn_owners' in payload:
        attribute = data.attributes.new('sewn_owner', 'INT', 'FACE')
        attribute.data.foreach_set('value', payload['sewn_owners'])
    data.update(calc_edges=False, calc_edges_loose=False)
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    return obj
