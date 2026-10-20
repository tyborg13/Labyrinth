extends SceneTree

const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Special = preload("res://assets/units/glacial_mirror_cutout/actions.gd")
const Fixture = preload("res://tests/suites/en03_enemies_suite.gd")
const CASE: String = "res://experiments/cutouts/glacial_mirror/rr18"
const PROOF_IDLE_SEED: float = 0.37
const EPSILON: float = 0.0001
const PROOF_IDLE_SAMPLES: int = 51
const FIXTURE_ACTOR_TILE := Vector2i(2, 4)
const FIXTURE_ALLY_TILE := Vector2i(2, 3)
const FIXTURE_TARGET_TILE := Vector2i(4, 4)
var checks: int = 0
var failures: Array[String]

class ContactScene extends Control:
	var reduced: bool = false
	var frame: int = 0
	var calls: Array[Dictionary]
	var sound_frames: Array[int]
	var apply_frames: Array[int]
	func _reduced_motion_enabled() -> bool: return reduced
	func _set_action_banner(_text: String) -> void: pass
	func _enemy_phase_status_presentation(step: Dictionary) -> Dictionary: return {"effect": step, "floating_texts": []}
	func _floating_texts_for_target_losses(_losses: Array) -> Array: return []
	func _play_timed_animation_frames(count: int, _seconds: float, callback: Callable) -> void:
		for index: int in range(1, count + 1):
			frame = index
			callback.call(index)
	func _apply_animation_step(state: Dictionary, _step: Dictionary) -> void:
		apply_frames.append(frame)
		state["applied"] = true
	func _play_sfx(_entry: Dictionary) -> void: sound_frames.append(frame)
	func _attack_feedback_death_hold_presentation(_before: Dictionary, _after: Dictionary, presentation: Dictionary) -> Dictionary: return presentation
	func _render_board_state(state: Dictionary, presentation: Dictionary, _validated: bool = false) -> void:
		calls.append({"frame": frame, "state": state.duplicate(true), "presentation": presentation.duplicate(true)})
	func _death_hold_presentation(_before: Dictionary, _after: Dictionary, presentation: Dictionary) -> Dictionary: return presentation
	func _animate_floating_text_presentation(_state: Dictionary, _presentation: Dictionary, _elapsed: float) -> void: pass

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _run() -> void:
	var renderer := preload("res://assets/units/glacial_mirror_cutout/renderer.gd").new()
	renderer.seed_idle_phase(PROOF_IDLE_SEED)
	root.add_child(renderer)
	check(renderer.rigs.size() == 2, "both production views")
	check(is_equal_approx(float(renderer.snapshot()["phase"]), PROOF_IDLE_SEED), "idle actor seed")
	check(not preload("res://scripts/static_enemy_facing.gd").handles("glacial_mirror"), "removed from static facing")
	check(preload("res://scripts/cutout_context.gd").family_key("glacial_mirror") == "glacial_mirror_motion", "reaction family")
	check(Action.playback_adapter({}, {"type": "arc_thrall"}) == null, "existing Thrall dispatch retained")
	var data: Dictionary = Action.data_for("glacial_mirror")
	for clip: String in data["clips"]:
		for selector: String in data["clips"][clip].get("intents", []):
			var fields: PackedStringArray = selector.split(":")
			check(Action.clip_for({"intent_id": fields[0], "action_type": fields[1]}, {"type": "glacial_mirror"}) == clip, selector)
	var anatomy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CASE.path_join("anatomy.json")))
	for view: String in renderer.rigs:
		var rig: Node2D = renderer.rigs[view]
		check(rig.layout["joint_meshes"].is_empty(), "every piece rigid: " + view)
		check(rig.layout["parts"].size() == 30, "15 boulders and their covered continuations")
		for frame: int in range(PROOF_IDLE_SAMPLES):
			rig.apply_pose("idle", float(frame) / PROOF_IDLE_SAMPLES)
			for group: String in anatomy["idle_groups"]:
				var offsets: Array[Vector2]
				for name: String in anatomy["idle_groups"][group]["bones"]:
					var pose: Transform2D = rig.global_transform.affine_inverse() * rig.bones[name].global_transform
					var bind: Vector2 = Vector2(float(rig.layout["joints"][name]["position"][0]), float(rig.layout["joints"][name]["position"][1]))
					var delta: Vector2 = pose.origin - bind
					check(pose.x.distance_to(Vector2.RIGHT) < EPSILON and pose.y.distance_to(Vector2.DOWN) < EPSILON, "idle rigid basis")
					check(delta.distance_to(delta.round()) < EPSILON, "idle whole pixels")
					if not offsets.is_empty(): check(delta.distance_to(offsets[0]) < EPSILON, "idle group translation")
					if anatomy["idle_groups"][group]["stationary"]: check(delta.length() < EPSILON, "idle planted")
					offsets.append(delta)
	# Exercise the real resolver spellings and ward source/recipient split.
	var engine := preload("res://scripts/combat_engine.gd").new()
	for intent: String in ["refraction", "crystal_guard"]:
		var state: Dictionary = Fixture.state([Fixture.enemy("glacial_mirror", 1, FIXTURE_ACTOR_TILE, intent), Fixture.enemy("crawler", 2, FIXTURE_ALLY_TILE)])
		var action: Dictionary = state["enemies"][0]["intent"]["actions"][0]
		var context: Dictionary = engine.enemy_intent_plan(state, 0)
		var after: Dictionary = engine._resolve_enemy_action(state.duplicate(true), 0, action, null, {}, engine._dictionary_values([]), context)
		var step: Dictionary = engine._enemy_action_step(state, after, 0, action, context)
		check(Special.handles(step, state["enemies"][0]), "real resolver selects " + intent)
		if intent == "crystal_guard":
			check(step.get("source_actor_key") == "enemy_1" and step.get("actor_key") == "enemy_2", "ward preserves source/recipient")
	var portrait: AtlasTexture = preload("res://scripts/maquette_cutout_runtime/portrait.gd").source_texture(renderer, "glacial_mirror")
	check(portrait.atlas == renderer.texture() and portrait.region == Rect2(128, 128, 255, 255), "live portrait registration")
	for clip: String in ["refraction", "guard"]:
		for reduced: bool in [false, true]:
			var scene := ContactScene.new()
			scene.reduced = reduced
			var state: Dictionary = Fixture.state([Fixture.enemy("glacial_mirror", 1, FIXTURE_ACTOR_TILE, "refraction" if clip == "refraction" else "crystal_guard")])
			var selector: PackedStringArray = str(data["clips"][clip]["intents"][0]).split(":")
			var step: Dictionary = {"kind": "aoe" if clip == "refraction" else "block", "action_type": selector[1], "intent_id": selector[0], "actor_key": "enemy_1", "from": FIXTURE_ACTOR_TILE, "to": FIXTURE_TARGET_TILE, "element": "ice"}
			check(Special.handles(step, state["enemies"][0]), "contact adapter handles " + clip)
			await Special.animate(scene, state, step, state["enemies"][0])
			var count: int = Action.frames_for("glacial_mirror", clip)
			var contact_frame: int = 1 if reduced else ceili(float(data["clips"][clip]["contact"]) * (count - 1)) + 1
			check(scene.sound_frames.size() == 1 and scene.sound_frames[0] == contact_frame, "sound exactly once at contact")
			check(scene.apply_frames.size() == 1 and scene.apply_frames[0] == contact_frame, "outcome exactly once at contact")
			for row: Dictionary in scene.calls:
				var presentation: Dictionary = row["presentation"]
				if not presentation.has("glacial_mirror_motion"): continue
				var phase: float = presentation["glacial_mirror_motion"]["enemy_1"]["phase"]
				check(presentation.has("effect") == (phase >= float(data["clips"][clip]["contact"]) and (clip == "guard" or reduced or (phase - float(data["clips"][clip]["contact"])) * float(data["clips"][clip]["seconds"]) < 0.3)), "existing effect begins at contact")
			scene.free()
	renderer.free()
	for failure: String in failures: push_error(failure)
	print("RR18 RUNTIME: %s (%d checks; headless logic only)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
