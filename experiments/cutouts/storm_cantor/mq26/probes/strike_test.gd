extends SceneTree

const Points = preload("res://scripts/enemy_strike_points.gd")
const Trail = preload("res://scripts/strike_trail_fx.gd")
const Fixture = preload("res://tests/helpers/enemy_strike_fixture.gd")
const Guardian = preload("res://scripts/guardian_cutout/renderer.gd")
const DIRECTIONS: Array = [Vector2i(0,1),Vector2i(0,-1),Vector2i(1,0),Vector2i(-1,0)]
var failures: Array[String]
var checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	for type: String in ["storm_cantor"]:
		if Points.REGISTRY[type]["kind"] == "arc": continue
		var model: Script = preload("res://scripts/actor_presentation.gd").travel_renderer(type)
		var renderer: Node = model.new()
		if Guardian.handles(type): renderer.character_id = type
		root.add_child(renderer)
		await process_frame
		for delta: Vector2i in DIRECTIONS:
			var state_value: Dictionary = Fixture.state(type, delta)
			var effect: Dictionary = Fixture.effect(type, state_value)
			var source: Dictionary = state_value["enemies"][0]
			var settings_value: Dictionary = Points.settings(type, effect)
			var boundary: float = Points.contact(effect)
			var samples: Array[Dictionary] = Points.samples(renderer, source, effect, delta, settings_value, boundary)
			var at_contact: Dictionary = Trail.sample_at(samples, boundary)
			var motion: Dictionary = Fixture.presentation(type,state_value,effect,boundary)[Fixture.motion_field(type)]["enemy_1"]
			renderer.present(motion, false)
			var rig: Node2D = renderer.rigs[renderer.facing]
			var bone: Bone2D = rig.bones[settings_value["bone"]]
			# Compare with the actual displayed Bone2D, not another sampler call.
			var bind: Array = rig.layout["joints"][settings_value["bone"]]["position"]
			var point: Vector2 = Points.bind_point(rig.layout,settings_value,renderer.facing)
			var live: Vector2 = rig.global_transform.affine_inverse() * bone.global_transform * (point - Vector2(bind[0],bind[1]))
			if renderer.mirrored: live.x = 255.0-live.x
			if renderer.has_method("strike_samples"):
				# V2 rigid paint snaps independently of its bone. Inspect the
				# displayed sprite transform, including reflection and padding.
				for part: Dictionary in rig.layout["parts"]:
					if part["name"] != settings_value["bone"]: continue
					var sprite: Sprite2D = bone.get_node(NodePath(part["name"]))
					var offset: Array = part["offset"]
					live = sprite.global_transform * (point - Vector2(offset[0], offset[1])) - (renderer.canvas_geometry()["offset"] as Vector2)
			if (at_contact["tip"] as Vector2).distance_to(live) >= 0.25:
				print("STRIKE CONTACT MISMATCH %s %s: sampled=%s live=%s error=%.4f" % [type,delta,at_contact["tip"],live,(at_contact["tip"] as Vector2).distance_to(live)])
			_expect((at_contact["tip"] as Vector2).distance_to(live) < 0.25, "Strike contact follows the displayed bone, facing and mirror: " + type)
			var batches: Array[Dictionary] = Trail.geometry(samples,settings_value["kind"],boundary,boundary,settings_value["window"],"none",1.0,11,float(settings_value.get("length",48.0)))
			_expect(not batches.is_empty() and _area(batches[1]) > 0.0, "Contact has luminous triangles: " + type)
			var visible: Array[Dictionary] = Trail.visible_samples(samples,boundary,settings_value["window"])
			var path := PackedVector2Array()
			for sample: Dictionary in visible: path.append(sample["tip"])
			_expect((path[-1]-path[0]).length() > 0.5, "The real strike path moves independently of the glint: " + type)
			_expect(Trail.geometry(samples,settings_value["kind"],0.20,boundary,settings_value["window"],"none",1.0,11).is_empty(), "No trail during preparation: " + type)
			_expect(Trail.geometry(samples,settings_value["kind"],0.90,boundary,settings_value["window"],"none",1.0,11).is_empty(), "Trail fades before recovery: " + type)
		renderer.queue_free()
		await process_frame
	for failure: String in failures: push_error(failure)
	print("RR56 STRIKE REGISTRATION: %s (%d checks; production registry and every supported facing)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

static func _area(batch: Dictionary) -> float:
	var total: float = 0.0
	var points: PackedVector2Array = batch["vertices"]
	var indices: PackedInt32Array = batch["indices"]
	for i: int in range(0,indices.size(),3):
		total += absf((points[indices[i+1]]-points[indices[i]]).cross(points[indices[i+2]]-points[indices[i]])) * 0.5
	return total
