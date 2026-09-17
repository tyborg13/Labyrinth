extends SceneTree
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const RigData = preload("res://scripts/protagonist_cutout/rig_data.gd")
const DropletRig = preload("res://scripts/cinder_droplet_cutout/rig.gd")
var _errors: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	var first := DropletRig.new()
	var second := DropletRig.new()
	root.add_child(first)
	root.add_child(second)
	_check(first.load_rig() and second.load_rig(), "Both independent live rigs load")
	var source_lifetime: WeakRef = weakref(first.get("_source_data"))
	_check(is_same(first.get("_source_data"), second.get("_source_data")), "Live duplicates share parsed and validated source data")
	first.apply_pose("walk", 0.15)
	second.apply_pose("attack", 0.60)
	for name: String in first.bones:
		_check(first.bones[name] != second.bones[name], "Each actor owns its own bone " + name)
	var other_pose: Transform2D = second.bones.values()[0].transform
	first.bones.values()[0].position += Vector2(20, 10)
	_check(second.bones.values()[0].transform == other_pose, "Moving one copy never changes another copy")
	for child: Node in first.get_children():
		if not child is Polygon2D: continue
		var mesh: Polygon2D = child
		var other: Polygon2D = second.get_node(NodePath(str(child.name)))
		_check(mesh != other and mesh.polygon == other.polygon and mesh.polygons == other.polygons and mesh.uv == other.uv, "Copies preserve exact geometry with independent canvas nodes")
		var vertices: PackedVector2Array = mesh.polygon
		vertices[0] += Vector2(17, 9)
		mesh.polygon = vertices
		_check(mesh.polygon != other.polygon, "Packed mesh data remains copy-on-write")
	first.free()
	_check(source_lifetime.get_ref() != null, "Source survives while another actor uses it")
	second.free()
	_check(source_lifetime.get_ref() == null, "Source/mesh arrays are released when the last actor leaves")
	var again := DropletRig.new()
	root.add_child(again)
	_check(again.load_rig(), "An expired weak entry reloads successfully")
	again.free()
	# These noncombat actors inherit the same mesh loader, but retain their own
	# pose/draw-order behavior. Loading two copies must keep that path valid too.
	for actor: String in ["scavenger", "graftwright", "lightning_wisp"]:
		var script: Script = load("res://scripts/%s_cutout/rig.gd" % actor)
		var actors: Array[Node2D] = []
		for copy: int in range(2):
			var rig: Node2D = script.new()
			root.add_child(rig)
			_check(rig.call("load_rig"), actor + " inherits validated mesh loading")
			rig.call("apply_pose", "idle", float(copy) * 0.4)
			actors.append(rig)
		_check(is_same(actors[0].get("_source_data"), actors[1].get("_source_data")), actor + " shares source data")
		for rig: Node2D in actors: rig.free()
	# Display names are optional/non-unique; source positions identify meshes.
	var data := RigData.Data.new()
	data.layout = {"joints":{"root":{}}}
	var face: Dictionary = {"vertices":[[0,0],[1,0],[0,1]], "uvs":[[0,0],[1,0],[0,1]], "triangles":[[0,1,2]], "weights":{"root":[1,1,1]}}
	var first_face: Dictionary = data.prepare_mesh(face, "PaintedJoint", "joint:0")
	face = face.duplicate(true)
	face["vertices"][0] = [3,4]
	var second_face: Dictionary = data.prepare_mesh(face, "PaintedJoint", "joint:1")
	_check(first_face["vertices"] != second_face["vertices"], "Identically named meshes keep their own geometry")
	for error: String in _errors: push_error(error)
	print("CUTOUT RIG DATA: " + ("PASS" if _errors.is_empty() else "FAIL"))
	quit(0 if _errors.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition: _errors.append(message)
