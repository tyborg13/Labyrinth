extends SceneTree

## Exercise actual registration, board/portrait/live adapters and utility clocks.
const Presentation = preload("res://scripts/maquette_cutout_runtime/presentation.gd")
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Renderer = preload("res://assets/units/briar_weaver_cutout/renderer.gd")
const Actions = preload("res://assets/units/briar_weaver_cutout/actions.gd")
const Fixtures = preload("res://tests/suites/en03_enemies_suite.gd")
const TYPE: String = "briar_weaver"
const EPSILON: float = 0.0001
var failures: Array[String]
var checks: int = 0

class ClockScene extends Control:
	var rows: Array[Dictionary]
	var applied: int = 0
	var applied_frame: int = -1
	var frame_index: int = 0
	var cues: Array[Dictionary]
	var reduced: bool = false

	func _reduced_motion_enabled() -> bool: return reduced
	func _set_action_banner(_text: String) -> void: pass
	func _play_timed_animation_frames(count: int, _seconds: float, callback: Callable) -> void:
		for frame: int in range(1, count + 1):
			frame_index = frame
			callback.call(frame)
	func _apply_animation_step(_state: Dictionary, _step: Dictionary) -> void:
		applied += 1
		applied_frame = frame_index
	func _play_sfx(entry: Dictionary) -> void: cues.append(entry)
	func _render_board_state(_state: Dictionary, shown: Dictionary, _immediate: bool = false) -> void:
		if not shown.is_empty(): rows.append(shown.duplicate(true))
	func _enemy_phase_status_presentation(step: Dictionary) -> Dictionary:
		return {"effect": step, "floating_texts": []}
	func _attack_feedback_death_hold_presentation(_before: Dictionary, _after: Dictionary, shown: Dictionary) -> Dictionary: return shown
	func _death_hold_presentation(_before: Dictionary, _after: Dictionary, shown: Dictionary) -> Dictionary: return shown
	func _animate_floating_text_presentation(_state: Dictionary, _shown: Dictionary, _elapsed: float) -> void: pass

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _run() -> void:
	check(Presentation.handles(TYPE), "production registration")
	check(not preload("res://scripts/static_enemy_facing.gd").handles(TYPE), "removed from static roster")
	check(preload("res://scripts/turn_order_portraits.gd").PATHS.has(TYPE), "public portrait identity fallback retained")
	check(Presentation.asset_directory(TYPE).ends_with("/humanoid_v2"), "declared rig directory")
	check(Presentation.renderer_script(TYPE) == Renderer, "registered runtime adapter")
	var renderer := Renderer.new()
	root.add_child(renderer)
	check(renderer.rigs.size() == 2, "two true painted views")
	for view: String in ["front", "rear"]:
		var rig: Node2D = renderer.rigs[view]
		check(rig.load_errors.is_empty(), "production rig loads " + view)
		for name: String in ["arm_near", "arm_far", "leg_near", "leg_far", "tatters"]:
			check(rig.get_node_or_null(NodePath(name)) is Polygon2D, "skinned " + view + "/" + name)
		rig.apply_pose("idle", 0.3)
		check(is_equal_approx((rig.bones["torso"] as Bone2D).rotation, 0.0), "rigid idle torso " + view)
		rig.apply_pose("death", 1.0)
		rig.apply_pose("rest", 0.0)
		check((rig.bones["torso"] as Bone2D).rotation == 0.0, "rest reset " + view)
	var portrait := TextureRect.new()
	root.add_child(portrait)
	preload("res://scripts/maquette_cutout_runtime/portrait.gd").bind(portrait, TYPE, false)
	check(portrait.has_node("MaquettePortraitRenderer") and portrait.texture is AtlasTexture, "live portrait replaces static fallback")
	var live := preload("res://scripts/live_actor_presentation.gd").new()
	live.configure(TYPE, portrait, 1, 3)
	root.add_child(live)
	check(live.snapshot()["presentation"] == "cutout", "pre-battle live actor")
	check(absf(float(live.snapshot()["initial_phase"]) - 1.0 / 3.0) < EPSILON, "actor slot idle seed")
	var actor: Dictionary = Fixtures.enemy(TYPE, 1, Vector2i(2, 4), "thornwall")
	for definition: Array in [["thornwall", "grow_bramble", "thornwall"], ["root_mend", "heal_ally", "mend"], ["lash_of_thorns", "ranged", "lash"]]:
		actor["intent"]["id"] = definition[0]
		check(Action.clip_for({"kind": definition[1]}, actor) == definition[2], "protected selector " + str(definition[0]))
	for clip: String in ["thornwall", "mend"]:
		actor["intent"]["id"] = "thornwall" if clip == "thornwall" else "root_mend"
		var step: Dictionary = {"actor_key": "enemy_2" if clip == "mend" else "enemy_1", "source_actor_key": "enemy_1", "kind": "heal" if clip == "mend" else "grow_bramble", "en04_mechanic": "grow_bramble", "to": Vector2i(3, 4), "tiles": []}
		check(Action.declared_adapter(step, actor) == Actions, "declared adapter " + clip)
		for reduced: bool in [false, true]:
			var scene := ClockScene.new()
			scene.reduced = reduced
			await Actions.animate(scene, {"player": {"pos": Vector2i(4, 4)}}, step, actor)
			check(scene.applied == 1, "one outcome " + clip)
			check(scene.rows.size() == (1 if reduced else Action.frames_for(TYPE, clip)), "complete frame inventory " + clip)
			var previous: float = -1.0
			var contacts: int = 0
			for row: Dictionary in scene.rows:
				var phase: float = float(row[TYPE + "_motion"]["enemy_1"]["phase"])
				check(phase >= previous, "monotone action " + clip)
				if is_equal_approx(phase, float(Action.data_for(TYPE)["clips"][clip]["contact"])): contacts += 1
				if phase < float(Action.data_for(TYPE)["clips"][clip]["contact"]): check(not row.has("effect"), "feedback waits for contact")
				previous = phase
			check(reduced or contacts == 1, "exact contact " + clip)
			check(scene.cues.size() == (1 if clip == "thornwall" else 0), "existing bramble cue once")
			scene.free()
	portrait.free()
	live.free()
	renderer.free()
	for failure: String in failures: push_error(failure)
	print("RR21 RUNTIME: %s (%d checks; headless registration and action clocks)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
