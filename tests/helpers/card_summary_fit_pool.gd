extends RefCounted

const Audit = preload("res://tests/helpers/card_legibility_audit.gd")
var workers: Array = []
var clones: Array[Control]

# One live production screen supplies the real CardScaleFrame and ancestors.
# Overlay identical CardWidget scenes in that same non-container frame for
# CPU geometry sampling; renderer proof always uses the single native face.
func open(live: RefCounted, context: Dictionary, count: int, expect: Callable) -> Array:
	cleanup()
	var native_faces: Array = await live.open(context)
	workers = live.workers.duplicate()
	if native_faces.size() != 1 or not native_faces[0] is Audit.Card:
		return native_faces
	var native: Control = native_faces[0]
	var parent: Node = native.get_parent()
	expect.call(not parent is Container, "Production card frame permits independent native-size faces: " + context["id"])
	if parent is Container: return native_faces
	for index: int in range(1, count):
		var face: Control = Audit.CardScene.instantiate()
		face.custom_minimum_size = native.custom_minimum_size
		face.size = native.size
		parent.add_child(face)
		face.position = native.position
		face.scale = native.scale
		face.rotation = native.rotation
		face.set_hover_pose(float(native.get("_hover_lift")), float(native.get("_hover_scale")))
		clones.append(face)
		workers.append({"scene": live.workers[0]["scene"], "face": face})
	return workers.map(func(worker: Dictionary) -> Control: return worker["face"])

func aligned(face: Control) -> bool:
	if not face is Audit.Card: return true
	var native: Control = workers[0]["face"]
	return face.get_parent() == native.get_parent() and face.size == native.size and face.get_global_transform_with_canvas().is_equal_approx(native.get_global_transform_with_canvas())

func cleanup() -> void:
	for face: Control in clones:
		if is_instance_valid(face): face.free()
	clones.clear()
	workers.clear()
