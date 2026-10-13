# Humanoid maquette builder (Blender, headless). Spec JSON: joints in 3D (x forward, y left, z up), limbs as capsules
# between joints with radii, extra shapes (boxes/plates/chains), part labels with colours. Renders from the board
# camera (orthographic, azimuth 45, elevation 30; +X faces the board's lower-left) for yaw 0 (front) and 180 (rear):
# parts (flat labels), clay, and per-part solo renders; writes projected 2D joint positions (render pixels).
#   Blender -b --factory-startup -P humanoid.py -- SPEC.json OUT_DIR
import bpy, bmesh, json, math, os, sys
from mathutils import Vector
args = sys.argv[sys.argv.index('--') + 1:]
spec = json.load(open(args[0])); out = args[1]; os.makedirs(out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
root = bpy.data.objects.new('maquette', None); scene.collection.objects.link(root)
J = {k: Vector(v) for k, v in spec['joints'].items()}
mats = {}
def mat(part):
    if part not in mats:
        m = bpy.data.materials.new(part); m.diffuse_color = (*spec['labels'][part], 1); mats[part] = m
    return mats[part]
objs = {}
def own(o, part):
    o.data.materials.clear(); o.data.materials.append(mat(part)); o.parent = root
    objs.setdefault(part, []).append(o); return o
def capsule(part, a, b, r1, r2=None):
    a, b = Vector(a), Vector(b); r2 = r1 if r2 is None else r2; d = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=20, radius1=r1, radius2=r2, depth=d.length, location=(a + b) / 2)
    o = bpy.context.object; o.rotation_mode = 'QUATERNION'; o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d)
    own(o, part)
    for p, r in ((a, r1), (b, r2)):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=10, radius=r, location=p); own(bpy.context.object, part)
def ellipsoid(part, c, s, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, location=c, rotation=rot); o = bpy.context.object; o.scale = s; own(o, part)
def box(part, c, s, rot=(0, 0, 0), bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(location=c, rotation=rot); o = bpy.context.object; o.scale = [v / 2 for v in s]
    if bevel:
        m = o.modifiers.new('b', 'BEVEL'); m.width = bevel; m.segments = 2
    own(o, part)
def plate(part, pts, thick=0.04):
    me = bpy.data.meshes.new(part); o = bpy.data.objects.new(part, me); scene.collection.objects.link(o)
    bm = bmesh.new(); vs = [bm.verts.new(p) for p in pts]; bm.faces.new(vs); bm.to_mesh(me); bm.free()
    o.modifiers.new('t', 'SOLIDIFY').thickness = thick; own(o, part)
def chain(part, a, b, links, r):
    a, b = Vector(a), Vector(b)
    for i in range(links):
        t = (i + 0.5) / links; p = a.lerp(b, t)
        bpy.ops.mesh.primitive_torus_add(location=p, major_radius=r, minor_radius=r * 0.32, rotation=(math.radians(90 * (i % 2)), 0, 0))
        own(bpy.context.object, part)
for s in spec['shapes']:
    kind = s['type']; part = s['part']
    if kind == 'capsule': capsule(part, J.get(s['a'], s['a']) if isinstance(s['a'], str) else s['a'], J[s['b']] if isinstance(s['b'], str) else s['b'], s['r1'], s.get('r2'))
    elif kind == 'ellipsoid': ellipsoid(part, J[s['at']] + Vector(s.get('offset', (0, 0, 0))) if 'at' in s else s['c'], s['s'], s.get('rot', (0, 0, 0)))
    elif kind == 'box': box(part, (J[s['at']] + Vector(s.get('offset', (0, 0, 0)))) if 'at' in s else s['c'], s['s'], s.get('rot', (0, 0, 0)), s.get('bevel', 0))
    elif kind == 'plate': plate(part, [Vector(p) for p in s['pts']], s.get('thick', 0.04))
    elif kind == 'chain': chain(part, J[s['a']] if isinstance(s['a'], str) else s['a'], J[s['b']] if isinstance(s['b'], str) else s['b'], s['links'], s['r'])
cam_data = bpy.data.cameras.new('cam'); cam_data.type = 'ORTHO'; cam_data.ortho_scale = spec.get('ortho_scale', 3.4)
cam = bpy.data.objects.new('cam', cam_data); scene.collection.objects.link(cam); scene.camera = cam
el, az, dist = math.radians(30), math.radians(45), 30
target = Vector(spec.get('target', (0, 0, 1.2)))
cam.location = target + Vector((math.cos(el) * math.cos(az), math.cos(el) * math.sin(az), math.sin(el))) * dist
cam.rotation_euler = (target - cam.location).to_track_quat('-Z', 'Y').to_euler()
scene.render.engine = 'BLENDER_WORKBENCH'; scene.render.resolution_x = scene.render.resolution_y = 1024
scene.render.film_transparent = True; sh = scene.display.shading
from bpy_extras.object_utils import world_to_camera_view
def project(p):
    co = world_to_camera_view(scene, cam, root.matrix_world @ p); return [round(co.x * 1024, 2), round((1 - co.y) * 1024, 2)]
result = {}
for view, yaw in (('front', 0), ('rear', 180)):
    root.rotation_euler = (0, 0, math.radians(yaw)); bpy.context.view_layer.update()
    for mode in ('parts', 'clay'):
        sh.light = 'FLAT' if mode == 'parts' else 'STUDIO'; sh.color_type = 'MATERIAL' if mode == 'parts' else 'SINGLE'
        sh.single_color = (0.6, 0.6, 0.6); sh.show_cavity = mode == 'clay'
        for o in [o for os_ in objs.values() for o in os_]: o.hide_render = False
        scene.render.filepath = os.path.join(out, f'{view}_{mode}.png'); bpy.ops.render.render(write_still=True)
    sh.light = 'FLAT'; sh.color_type = 'MATERIAL'
    for part in spec.get('solo', []):
        for p2, os_ in objs.items():
            for o in os_: o.hide_render = (p2 != part)
        scene.render.filepath = os.path.join(out, f'{view}_solo_{part}.png'); bpy.ops.render.render(write_still=True)
    for o in [o for os_ in objs.values() for o in os_]: o.hide_render = False
    result[view] = {k: project(v) for k, v in J.items()}
json.dump(result, open(os.path.join(out, 'joints_px.json'), 'w'), indent=1)
