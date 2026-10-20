extends SceneTree

## Headless runtime regression: move an actual far wrist through the torso.
const Rig = preload("res://assets/units/hollow_mimic_cutout/rig.gd")
const Order = preload("res://assets/units/hollow_mimic_cutout/draw_order.gd")
const FIXTURE_ORIGIN := Vector2(128, 128)
const FIXTURE_SCALE := Vector2(2, 2)
const CROSSING_OFFSET_PX: float = 1.0
const OUTSIDE_GAP_PX: float = 10.0
var errors: Array[String]
var checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	for view: String in ["front", "rear"]:
		var rig := Rig.new()
		rig.position = FIXTURE_ORIGIN
		rig.scale = FIXTURE_SCALE
		rig.facing = view
		root.add_child(rig)
		check(rig.load_rig(), view + ": load")
		rig.apply_pose("rest", 0.0)
		var torso: Dictionary = part_for(rig, "torso")
		var hand: Dictionary = part_for(rig, "hand_far")
		var wrist: Bone2D = rig.bones["hand_far"]
		var original: Transform2D = wrist.transform
		var box: Rect2 = Order.projected_box(rig, torso)
		var middle: float = (rig.global_transform.affine_inverse() * (rig.bones["torso"] as Bone2D).global_transform).origin.x
		var rest_side: float = signf(float(rig.layout["joints"]["hand_far"]["position"][0]) - float(rig.layout["joints"]["torso"]["position"][0]))
		# Set only the wrist's projected position. Keep the production paint,
		# skeleton, mesh and rigid hand nodes and call the real ordering code.
		wrist.global_position = rig.to_global(Vector2(middle - rest_side * CROSSING_OFFSET_PX, box.get_center().y))
		check(Order.projected_box(rig, hand).intersects(box), view + ": overlapping far wrist fixture")
		check((rig.to_local(wrist.global_position).x - middle) * rest_side < 0.0, view + ": crossed midline fixture")
		Order.apply(rig, "block")
		for name: String in ["hand_far", "sleeve_far"]:
			var part: Dictionary = part_for(rig, name)
			var expected: int = maxi(int(part["z_index"]), int(torso["z_index"]) + 1) if view == "front" else int(part["z_index"])
			check(Order.node_for(rig, part).z_index == expected, view + ": crossing " + name)
			if view == "front": check(expected > int(part["z_index"]), "fixture must exercise promotion: " + name)
		# Cross back to the far side while still overlapping: midline matters.
		wrist.global_position = rig.to_global(Vector2(middle + rest_side * CROSSING_OFFSET_PX, box.get_center().y))
		check(Order.projected_box(rig, hand).intersects(box), view + ": returning overlap fixture")
		Order.apply(rig, "block")
		check_restored(rig, view + ": returned across midline")
		var hand_size := Vector2(hand["bbox"][2] - hand["bbox"][0], hand["bbox"][3] - hand["bbox"][1])
		wrist.global_position = rig.to_global(box.end + Vector2.ONE * (OUTSIDE_GAP_PX + hand_size.length()))
		Order.apply(rig, "block")
		check_restored(rig, view + ": no overlap")
		wrist.transform = original
		rig.apply_pose("rest", 0.0)
		check_restored(rig, view + ": rest")
		rig.free()
	for error: String in errors: push_error(error)
	print("RR29 FAR ARM RUNTIME: %s (%d checks)" % ["PASS" if errors.is_empty() else "FAIL", checks])
	quit(0 if errors.is_empty() else 1)

func part_for(rig: Node2D, name: String) -> Dictionary:
	for part: Dictionary in rig.layout["parts"]:
		if part["name"] == name: return part
	return {}

func check_restored(rig: Node2D, context: String) -> void:
	for name: String in ["hand_far", "sleeve_far"]:
		var part: Dictionary = part_for(rig, name)
		check(Order.node_for(rig, part).z_index == int(part["z_index"]), context + " " + name)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: errors.append(message)
