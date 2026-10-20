import bpy, json, sys
out = sys.argv[sys.argv.index("--") + 1]
dg = bpy.context.evaluated_depsgraph_get()
res = {}
for ob in bpy.data.objects:
    if ob.type != "MESH": continue
    ev = ob.evaluated_get(dg); me = ev.to_mesh()
    vs = [tuple(ob.matrix_world @ v.co) for v in me.vertices]
    head = [v for v in vs if v[2] > 1.30]
    if head:
        res[ob.name] = {"n": len(vs), "head_n": len(head), "head": head[::max(1, len(head)//4000)]}
    ev.to_mesh_clear()
json.dump(res, open(out, "w"))
print("objects", {k: (v["n"], v["head_n"]) for k, v in res.items()})
