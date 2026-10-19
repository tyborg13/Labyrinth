extends SceneTree

const Presentation = preload("res://scripts/maquette_cutout_runtime/presentation.gd")
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Death = preload("res://scripts/maquette_cutout_runtime/death.gd")
const PROOF_IDLE_SEED: float = 0.37
const PROOF_ACTION_PHASE: float = 0.6
const PROOF_WALK_MUTATION_SECONDS: float = 1.25
var checks: int = 0
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _run() -> void:
	var renderer := preload("res://assets/units/slag_mortar_cutout/renderer.gd").new()
	renderer.seed_idle_phase(PROOF_IDLE_SEED)
	root.add_child(renderer)
	check(renderer.rigs.size() == 2, "both production views load")
	_check_walk_cadence(renderer)
	check(is_equal_approx(float(renderer.snapshot()["phase"]), PROOF_IDLE_SEED), "seed retained")
	check(Presentation.asset_directory("slag_mortar").ends_with("humanoid_v2"), "production path")
	check(not preload("res://scripts/static_enemy_facing.gd").handles("slag_mortar"), "static roster removed")
	check(not "slag_mortar" in preload("res://scripts/cutout_context.gd").STATIC_ENEMY_TYPES, "static reaction roster removed")
	var actor: Dictionary = {"type": "slag_mortar"}
	for selector: Array in [["lob_slag", "lob_mark", "lob"], ["slag_lands", "lob_land", "land"], ["brace", "block", "brace"], ["brace", "move_away", "move"], ["scatter_shot", "ranged", "scatter"]]:
		var step: Dictionary = {"intent_id": selector[0], "action_type": selector[1]}
		check(Action.clip_for(step, actor) == selector[2], "selector " + str(selector))
		check((Action.playback_adapter(step, actor) != null) == (selector[2] in ["lob", "land", "brace"]), "optional playback " + str(selector))
	check(is_equal_approx(Death.clip_seconds("slag_mortar"), 1.5), "death clip before fade")
	check(Death.dissolve_phase("slag_mortar", 0.0) == 0.0, "no early fade")
	for view: String in renderer.rigs:
		renderer.facing = view
		var rig: Node2D = renderer.rigs[view]
		for name: String in rig.layout.get("gait_continuations", {}):
			var recipe: Dictionary = rig.layout["gait_continuations"][name]
			var part: Dictionary = rig.layout["parts"].filter(func(p: Dictionary) -> bool: return p["name"] == name)[0]
			var donor: Dictionary = rig.layout["parts"].filter(func(p: Dictionary) -> bool: return p["name"] == recipe["donor"])[0]
			var node: Node2D = rig.bones[part["bone"]].get_node(NodePath(name))
			rig.apply_pose("rest", 0.0)
			var original: PackedByteArray = (node.get("texture") as Texture2D).get_image().get_data()
			for clip: String in recipe["clips"]:
				rig.apply_pose(clip, PROOF_ACTION_PHASE)
				var image: Image = (node.get("texture") as Texture2D).get_image()
				var paint: Image = rig._texture(donor["file"]).get_image()
				for texel: Array in recipe["texels"]:
					check(image.get_pixel(int(texel[0]), int(texel[1])) == paint.get_pixel(int(texel[2]), int(texel[3])), "own-edge action material " + view + "/" + name)
			rig.apply_pose("idle", PROOF_ACTION_PHASE)
			check((node.get("texture") as Texture2D).get_image().get_data() == original, "idle restores exact original texture " + name)
			rig.apply_pose("rest", 0.0)
			check((node.get("texture") as Texture2D).get_image().get_data() == original, "rest restores exact original texture " + name)
		check(rig.layout["joints"]["mortar"]["parent"] == "torso", "torso attachment")
		check(rig.layout["joints"]["apron_tip"]["parent"] == "apron_mid", "cloth chain")
		for clip: String in renderer.motion_data()["clips"]:
			if clip == "death": continue
			renderer.present({"clip": clip, "phase": PROOF_ACTION_PHASE, "facing": view}, false)
			check(renderer.snapshot()["clip"] == clip, "production " + view + "/" + clip)
			if clip == "hit": renderer.present({"clip": "hit", "phase": 1.0}, false)
			rig.apply_pose(clip, PROOF_ACTION_PHASE)
			rig.apply_pose("rest", 0.0)
			for bone: String in rig.bones: check((rig.bones[bone] as Bone2D).global_transform.is_finite(), "finite " + bone)
	var portrait: AtlasTexture = preload("res://scripts/maquette_cutout_runtime/portrait.gd").source_texture(renderer, "slag_mortar")
	check(portrait.atlas == renderer.texture(), "live portrait")
	renderer.present({"clip": "lob", "phase": PROOF_ACTION_PHASE}, true)
	check(renderer.snapshot()["shown_clip"] == "rest", "reduced-motion retains still art")
	for failure: String in failures: push_error(failure)
	print("RR22 RUNTIME: %s (%d checks; headless logic only)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	renderer.free()
	quit(0 if failures.is_empty() else 1)

func _check_walk_cadence(renderer: Node) -> void:
	var move: Dictionary = Action.data_for("slag_mortar")["clips"]["move"]
	var original: float = float(move["seconds"])
	check(renderer.walk_segment_frames(0.0) == Action.frames_for("slag_mortar", "move"), "compiled walk cadence")
	# Mutate only this process's cached test data; restore before other checks.
	move["seconds"] = PROOF_WALK_MUTATION_SECONDS
	check(renderer.walk_segment_frames(0.0) == Action.frames_for("slag_mortar", "move"), "walk follows changed compiled duration")
	move["seconds"] = original
	check(renderer.walk_segment_frames(0.0) == Action.frames_for("slag_mortar", "move"), "walk cadence restored")
