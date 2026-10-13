# Blender headless maquette for the Gust Shrike: posed proxy, board camera (orthographic, azimuth 45, elevation 30),
# front (facing screen lower-left) and rear renders; flat part colours + clay. Usage:
#   Blender -b --factory-startup -P shrike.py -- OUT_DIR
import bpy, math, sys, os
from mathutils import Vector, Euler
out = sys.argv[sys.argv.index('--') + 1]
os.makedirs(out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

PART_COLOURS = {  # label colours (not paint colours)
    'body': (0.85, 0.15, 0.15), 'head': (0.95, 0.85, 0.1), 'beak': (1, 1, 1), 'mask': (0.1, 0.1, 0.1),
    'wing_near': (1.0, 0.55, 0.1), 'wing_far': (0.15, 0.35, 0.95), 'tail': (0.85, 0.2, 0.85), 'legs': (0.1, 0.85, 0.85),
}
mats = {}
for name, c in PART_COLOURS.items():
    m = bpy.data.materials.new(name); m.diffuse_color = (*c, 1); mats[name] = m

root = bpy.data.objects.new('bird', None); scene.collection.objects.link(root)

def add(obj, part):
    obj.data.materials.append(mats[part]); obj.parent = root; return obj

def ellipsoid(part, loc, scale, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, location=loc, rotation=rot)
    o = bpy.context.object; o.scale = scale; bpy.ops.object.shade_smooth(); return add(o, part)

def cone(part, loc, r1, r2, depth, rot):
    bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    return add(bpy.context.object, part)

def cyl(part, a, b, r):
    a, b = Vector(a), Vector(b); d = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=r, depth=d.length, location=(a + b) / 2)
    o = bpy.context.object; o.rotation_mode = 'QUATERNION'; o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d)
    return add(o, part)

def wing(part, side):
    # A broad feathered sail: leading edge from the shoulder up and back to the tip; trailing edge from the tip back
    # down to the hip, notched into primaries. Slightly cupped and spread outward.
    import bmesh
    me = bpy.data.meshes.new(part); o = bpy.data.objects.new(part, me); scene.collection.objects.link(o)
    bm = bmesh.new()
    n = 16
    def lead(t):  # shoulder (0.25, 0.75) -> tip (-0.85, 2.15), bowed forward
        x = 0.32 - 1.05 * t
        z = 0.92 + 1.30 * (1 - (1 - t) ** 1.6)
        return x + 0.18 * math.sin(math.pi * t), z
    def trail(t):  # hip (-0.45, 0.62) -> tip, sagging, with primaries notches near the tip
        x = -0.32 - 0.41 * t
        z = 0.58 + 1.64 * t ** 1.4
        notch = 0.10 * (1 if (int(t * n) % 2) else 0) * t
        return x - notch, z - notch * 0.6
    rows = []
    for i in range(n + 1):
        t = i / n
        y = side * (0.26 + 0.20 * t)
        lx, lz = lead(t); tx, tz = trail(t)
        cup = side * 0.06 * math.sin(math.pi * t)
        rows.append((bm.verts.new((lx, y, lz)), bm.verts.new(((lx + tx) / 2, y + cup, (lz + tz) / 2)), bm.verts.new((tx, y, tz))))
    for i in range(n):
        a, b = rows[i], rows[i + 1]
        bm.faces.new((a[0], b[0], b[1], a[1])); bm.faces.new((a[1], b[1], b[2], a[2]))
    bm.to_mesh(me); bm.free()
    mod = o.modifiers.new('thick', 'SOLIDIFY'); mod.thickness = 0.05
    return add(o, part)

# Body: low, nearly horizontal, pointing +X (forward)
ellipsoid('body', (0.0, 0, 0.62), (0.66, 0.34, 0.31), (0, math.radians(-32), 0))
ellipsoid('head', (0.58, 0, 1.12), (0.24, 0.21, 0.21))
cone('beak', (0.83, 0, 1.06), 0.09, 0.0, 0.26, (0, math.radians(105), 0))
ellipsoid('mask', (0.66, 0, 1.16), (0.12, 0.215, 0.06))
# Tail fan: several flat blades behind
for k in range(-3, 4):
    a = math.radians(k * 11)
    import bmesh
    me = bpy.data.meshes.new('tail'); o = bpy.data.objects.new('tail', me); scene.collection.objects.link(o)
    bm = bmesh.new()
    base = Vector((-0.5, 0, 0.36)); tip = base + Vector((-0.78 * math.cos(a), 0.78 * math.sin(a), -0.34))
    side = Vector((0.0, 0.07, 0)) if abs(k) < 3 else Vector((0, 0.06, 0))
    v = [bm.verts.new(base - side), bm.verts.new(base + side), bm.verts.new(tip + side * 1.8), bm.verts.new(tip - side * 1.8)]
    bm.faces.new(v); bm.to_mesh(me); bm.free()
    o.modifiers.new('thick', 'SOLIDIFY').thickness = 0.03
    add(o, 'tail')
# Legs and talons
for s in (1, -1):
    cyl('legs', (0.05, s * 0.14, 0.42), (0.12, s * 0.16, 0.0), 0.05)
    for t in (-25, 0, 25):
        a = math.radians(t)
        cyl('legs', (0.12, s * 0.16, 0.02), (0.12 + 0.18 * math.cos(a), s * 0.16 + 0.18 * math.sin(a), -0.02), 0.025)
    cyl('legs', (0.12, s * 0.16, 0.02), (-0.02, s * 0.16, 0.0), 0.022)
wing('wing_near', 1)
wing('wing_far', -1)

# Board camera: orthographic, azimuth 45 deg, elevation 30 deg (2:1 board projection).
cam_data = bpy.data.cameras.new('cam'); cam_data.type = 'ORTHO'; cam_data.ortho_scale = 3.6
cam = bpy.data.objects.new('cam', cam_data); scene.collection.objects.link(cam); scene.camera = cam
el, az, dist = math.radians(30), math.radians(45), 20
target = Vector((0, 0, 0.9))
cam.location = target + Vector((math.cos(el) * math.cos(az), math.cos(el) * math.sin(az), math.sin(el))) * dist
cam.rotation_euler = (target - cam.location).to_track_quat('-Z', 'Y').to_euler()

scene.render.engine = 'BLENDER_WORKBENCH'
scene.render.resolution_x = scene.render.resolution_y = 1024
scene.render.film_transparent = True
sh = scene.display.shading

def render(name, yaw_deg, mode):
    root.rotation_euler = (0, 0, math.radians(yaw_deg))
    if mode == 'parts':
        sh.light = 'FLAT'; sh.color_type = 'MATERIAL'
    else:
        sh.light = 'STUDIO'; sh.color_type = 'SINGLE'; sh.single_color = (0.6, 0.6, 0.6)
    sh.show_cavity = mode != 'parts'
    scene.render.filepath = os.path.join(out, name)
    bpy.ops.render.render(write_still=True)

# Facing: yaw chosen so +X (forward) points to the screen's lower-left (toward the camera-left).
FRONT_YAW = float(os.environ.get('FRONT_YAW', '135'))
render('front_parts.png', FRONT_YAW, 'parts'); render('front_clay.png', FRONT_YAW, 'clay')
render('rear_parts.png', FRONT_YAW + 180, 'parts'); render('rear_clay.png', FRONT_YAW + 180, 'clay')
