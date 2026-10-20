extends SceneTree

const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Presentation = preload("res://scripts/maquette_cutout_runtime/presentation.gd")
const Motion = preload("res://scripts/maquette_cutout_runtime/motion.gd")
const Contact = preload("res://scripts/maquette_cutout_runtime/contact_actions.gd")
const Humanoid = preload("res://scripts/maquette_cutout_runtime/humanoid_motion.gd")
const EPSILON: float = 0.0001
const PROOF_IDLE_SEED: float = 0.37
const PROOF_TERMINAL_PHASE: float = 0.9
var errors: Array[String]
var checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: errors.append(message)

func _run() -> void:
	var actor: Dictionary = {"type": "hollow_mimic"}
	check(not preload("res://scripts/static_enemy_facing.gd").handles("hollow_mimic"), "static facing removed")
	check(not "hollow_mimic" in preload("res://scripts/cutout_context.gd").STATIC_ENEMY_TYPES, "static reactions removed")
	check(Action.clip_for({"intent_id": "shade_bolt", "kind": "ranged"}, actor) == "bolt", "shade bolt selector")
	check(Action.clip_for({"intent_id": "recede", "action_type": "move_away"}, actor) == "move", "recede move selector")
	check(Action.clip_for({"intent_id": "recede", "kind": "block"}, actor) == "block", "recede block selector")
	for kind: String in ["melee", "ranged", "aoe"]:
		var step: Dictionary = {"en06_mirror": true, "kind": kind, "action_type": kind}
		check(Action.clip_for(step, actor) == "mirror", "copied " + kind + " selects mirror")
		check(Contact.handles(step, actor), "contact adapter handles copied " + kind)
		step["cancelled"] = true
		check(not Contact.handles(step, actor) and Action.clip_for(step, actor).is_empty(), "cancelled copy stays cancelled")
	var renderer: Node = Presentation.renderer_script("hollow_mimic").new()
	renderer.seed_idle_phase(PROOF_IDLE_SEED)
	root.add_child(renderer)
	check(renderer.rigs.size() == 2, "two production views")
	check(is_equal_approx(renderer.snapshot()["phase"], PROOF_IDLE_SEED), "actor idle seed retained")
	var portrait: AtlasTexture = preload("res://scripts/maquette_cutout_runtime/portrait.gd").source_texture(renderer, "hollow_mimic")
	check(portrait.atlas == renderer.texture() and portrait.region == Rect2(128,128,255,255), "portrait uses the registered live board texture")
	var anatomy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://experiments/cutouts/hollow_mimic/rr20/anatomy.json"))
	for view: String in renderer.rigs:
		var rig: Node2D = renderer.rigs[view]
		var source: Transform2D = rig.global_transform.affine_inverse()
		for frame: int in range(roundi(0.84 * 60)):
			rig.apply_pose("idle", float(frame) / roundi(0.84 * 60))
			for group: String in anatomy["idle_groups"]:
				var offsets: Array[Vector2]
				for name: String in anatomy["idle_groups"][group]["bones"]:
					var pose: Transform2D = source * rig.bones[name].global_transform
					var offset: Vector2 = pose.origin - Motion.point(rig.layout["joints"][name]["position"])
					check(pose.x.distance_to(Vector2.RIGHT) < EPSILON and pose.y.distance_to(Vector2.DOWN) < EPSILON, "idle rigid basis " + name)
					check(offset.distance_to(offset.round()) < EPSILON, "idle whole-pixel " + name)
					if not offsets.is_empty(): check(offset.distance_to(offsets[0]) < EPSILON, "idle group rigid " + group)
					if anatomy["idle_groups"][group]["stationary"]: check(offset.length() < EPSILON, "lower body stationary " + name)
					offsets.append(offset)
		var posed: Dictionary = Humanoid.world_transforms(renderer.motion_data(), "death", PROOF_TERMINAL_PHASE, rig.layout, view)
		for side: String in ["near", "far"]:
			var foot: String = "foot_" + side
			check((posed[foot] as Transform2D).origin.distance_to(Motion.point(rig.layout["joints"][foot]["position"])) < EPSILON, "boots planted in death collapse " + view + "/" + side)
		# Opt-in death support leaves the legacy FK path unchanged when absent.
		var legacy: Dictionary = rig.layout.duplicate(true)
		legacy.erase("planted_during_death")
		var unplanted: Dictionary = Humanoid.world_transforms(renderer.motion_data(), "death", PROOF_TERMINAL_PHASE, legacy, view)
		check((unplanted["foot_near"] as Transform2D).origin.distance_to((posed["foot_near"] as Transform2D).origin) > EPSILON, "death support is opt-in")
	renderer.free()
	for message: String in errors: push_error(message)
	print("RR20 RUNTIME: %s (%d checks; headless logic only)" % ["PASS" if errors.is_empty() else "FAIL", checks])
	quit(0 if errors.is_empty() else 1)
