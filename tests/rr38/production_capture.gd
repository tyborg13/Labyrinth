extends SceneTree

const CaptureStorage = preload("res://tests/maquette_cutout/capture_storage.gd")

## Actual resolver steps -> RunScene animation callbacks -> production bones.
const CaptureScene = preload("capture_scene.gd")
const CaptureViewport = preload("res://tests/gust_shrike_capture_viewport.gd")
const Fixtures = preload("res://tests/suites/en03_enemies_suite.gd")
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const SIZE := Vector2i(1920, 1080)
const SETTLE_FRAMES: int = 8
const HIT_PROOF_HP: int = 30
const IDLE_SAMPLE_SECONDS: float = 1.0 / 60.0
const PROOF_FRONT_TILE := Vector2i(2, 4)
const PROOF_REAR_TILE := Vector2i(6, 4)
const PROOF_GUARD_FRONT_TARGET := Vector2i(5, 4)
const PROOF_GUARD_REAR_TARGET := Vector2i(3, 4)
const PROOF_FRONT_ALLY_TILE := Vector2i(3, 4)
const PROOF_REAR_ALLY_TILE := Vector2i(5, 4)
var _type: String
var _output: String
var _scene: Control
var _logic: bool
var _frames: Array[Dictionary]
var _viewport: SubViewport
var _stage: String
var _walk_samples: Dictionary = {}
var _walk_context: Dictionary = {}
var _movement_frames: Array[Dictionary]
var _failures: Array[String]
var _data: Dictionary
var _rear_fixture: bool = false
var _references: Dictionary = {}
var _reference_case: String = "res://experiments/cutouts/chainbound_gaoler/rr38"

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.find("--type") < 0 or args.find("--output") < 0:
		push_error("Use -- --type chainbound_gaoler --output DIRECTORY [--logic-only]")
		quit(1)
		return
	_type = args[args.find("--type") + 1]
	_output = args[args.find("--output") + 1]
	CaptureStorage.setup(_output)
	_logic = args.has("--logic-only")
	_rear_fixture = args.has("--rear")
	if args.has("--case"): _reference_case = args[args.find("--case") + 1]
	_data = Action.data_for(_type)
	if _data.is_empty() or (DisplayServer.get_name() == "headless" and not _logic):
		push_error("Production capture requires a registered creature and windowed renderer (or --logic-only)")
		quit(1)
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	Settings.set_storage_path("user://rr38_settings.json")
	Store.set_storage_path("user://rr38_profile.json")
	Store.set_run_storage_path("user://rr38_run.save")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	_viewport = CaptureViewport.create(root)
	await _create_capture_scene()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	await _prepare_production_crop()
	await _run_clips()
	_failures.append_array(preload("res://tests/rr17/capture_contract.gd").errors(_frames, _data, _scene.proof_completions, not _logic))
	for error: String in _failures: push_error(error)
	var bindings: Dictionary = preload("res://tests/rr10/bindings.gd").for_case(_reference_case)
	var report: Dictionary = {"ok": _failures.is_empty(), "native_pixels": not _logic, "type": _type,
		"size": [1920, 1080], "ui_scale": 1.0, "inputs": bindings, "frames": _frames, "walk_samples": _walk_samples, "movement_frames": _movement_frames, "completions": _scene.proof_completions, "errors": _failures}
	if not _logic or OS.get_cmdline_user_args().has("--validate-crop"):
		report.merge(CaptureStorage.metadata())
	if not _logic: CaptureStorage.finish()
	var file := FileAccess.open(_output.path_join("logic_frames.json" if _logic else "frames.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	print("MAQUETTE PRODUCTION %s: %s (%d frames)" % ["LOGIC" if _logic else "NATIVE", "PASS" if _failures.is_empty() else "FAIL", _frames.size()])
	print("Saved " + ProjectSettings.globalize_path(_output))
	if not _logic: print_proof_images()
	_scene.queue_free()
	for reference: Node2D in _references.values(): reference.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)

func _prepare_production_crop() -> void:
	if CaptureStorage.legacy or (_logic and not OS.get_cmdline_user_args().has("--validate-crop")): return
	var capture_logic: bool = _logic
	_logic = true
	CaptureStorage.begin_production()
	CaptureStorage.include_production_board_position(_scene.board_view, _scene._board_centering_target)
	await _run_clips()
	CaptureStorage.finish_production(SIZE)
	# Replay in a fresh scene so planning clocks, cues and renderer state cannot
	# leak into the real capture. Keep any failures observed during planning.
	_scene.queue_free()
	await process_frame
	_frames.clear()
	_walk_samples.clear()
	_walk_context.clear()
	_movement_frames.clear()
	for reference: Node2D in _references.values(): reference.free()
	_references.clear()
	_logic = capture_logic
	await _create_capture_scene()

func _create_capture_scene() -> void:
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	_scene.set_script(CaptureScene)
	_scene.proof_actor_type = _type
	_scene.proof_capture = _capture
	_viewport.add_child(_scene)
	if _logic: _scene.board_view.hide() # Dummy renderer cannot read live Veil viewport textures.
	await settle()
	_scene._load_run_state(Run.new().create_new_run(Fixtures.TEST_SEED, Store.default_data()))
	await settle()

func _run_clips() -> void:
	for clip: String in _data["clips"]:
		_stage = clip
		var state: Dictionary = fixture("manacle_pin")
		if clip == "idle":
			await install(state)
			if _logic: _scene.board_view.show() # Normal visible-parent production idle clock.
			var renderer: Node = _scene.board_view.unit_cutout_renderer({"type": _type, "id": 1})
			# Idle advances with production _process, not a sought proof phase.
			var count: int = roundi(Action.seconds_for(_type, "idle") * 60.0)
			for frame: int in range(count):
				await _capture()
				await create_timer(IDLE_SAMPLE_SECONDS).timeout
			if _logic: _scene.board_view.hide()
			continue
		if clip in ["hit", "death"]:
			state["enemies"][0]["pos"] = Vector2i(5, 4)
			if clip == "death": state["enemies"][0]["hp"] = 1
			else:
				state["enemies"][0]["hp"] = HIT_PROOF_HP
				state["enemies"][0]["max_hp"] = HIT_PROOF_HP
			await install(state)
			var engine := Combat.new()
			var action: Dictionary = Data.card_def("quick_stab")["actions"][0]
			var target: Vector2i = state["enemies"][0]["pos"]
			var after: Dictionary = engine.apply_player_action(state, action, target)
			await _scene.record_action(clip, func() -> void: await _scene._animate_player_action_step(state, after, "quick_stab", action, target))
			if clip == "hit":
				var renderer: Node = _scene.board_view.unit_cutout_renderer({"type": _type, "id": 1})
				while renderer != null and renderer.snapshot()["clip"] == "hit":
					await _capture()
					await create_timer(IDLE_SAMPLE_SECONDS).timeout
				_scene.proof_completions[clip] = renderer.snapshot() if renderer != null else {}
			continue
		if clip == "move":
			await install(state)
			var moved: Dictionary = state.duplicate(true)
			var origin: Vector2i = state["enemies"][0]["pos"]
			var target: Vector2i = origin + Vector2i(-1 if _rear_fixture else 1, 0)
			moved["enemies"][0]["pos"] = target
			var step: Dictionary = {"kind": "move", "actor_key": "enemy_1", "from": origin, "to": target, "enemy_after": moved["enemies"][0]}
			await _scene.record_action(clip, func() -> void: await _scene._animate_move_step(state, step))
			# Uniform diagnostic sampling must not seek the rig while its live
			# action is being recorded (the renderer caches its painted phase).
			for view: String in _walk_context:
				var context: Dictionary = _walk_context[view]
				var rig: Node2D = context["rig"]
				var old_step: float = float(rig.layout["step_distance_px"])
				var old_scale: float = float(rig.layout["screen_pixel_scale"])
				rig.layout["step_distance_px"] = context["snapshot"]["step_distance_px"]
				rig.layout["screen_pixel_scale"] = context["snapshot"]["screen_pixel_scale"]
				_walk_samples[view] = preload("res://tests/gait01/production_walk.gd").capture(rig, "idle", 0.0)
				rig.layout["step_distance_px"] = old_step
				rig.layout["screen_pixel_scale"] = old_scale
			continue
		var selector: String = str(_data["clips"][clip]["intents"][0])
		var fields: PackedStringArray = selector.split(":")
		state = fixture(fields[0])
		await install(state)
		var engine := Combat.new()
		var planned: Dictionary = engine.enemy_intent_plan(state, 0)
		var resolved: Dictionary = state.duplicate(true)
		var steps: Array[Dictionary]
		var actions: Array = state["enemies"][0]["intent"]["actions"]
		for index: int in range(actions.size()):
			var action: Dictionary = actions[index]
			var context: Dictionary = planned.duplicate(true)
			context["action_index"] = index
			var before: Dictionary = resolved.duplicate(true)
			resolved = engine._resolve_enemy_action(resolved, 0, action, null, {}, engine._dictionary_values([]), context)
			if engine._enemy_action_is_movement(action): planned["resolved_path"] = context.get("resolved_path", engine._vector2i_values([resolved["enemies"][0]["pos"]]))
			steps.append(engine._enemy_action_step(before, resolved, 0, action, context))
		await _scene.record_action(clip, func() -> void: await _scene._animate_enemy_phase_steps(state.duplicate(true), steps))

func _capture() -> void:
	await process_frame
	await process_frame
	if not _logic: await RenderingServer.frame_post_draw
	var renderer: Node = _scene.board_view.unit_cutout_renderer({"type": _type, "id": 1})
	if renderer == null: return
	var snapshot: Dictionary = renderer.snapshot()
	if snapshot["clip"] == "move":
		_movement_frames.append({"intent": _stage, "phase": snapshot["phase"], "facing": snapshot["facing"], "step_distance_px": snapshot["step_distance_px"]})
	if snapshot["clip"] != _stage: return
	if CaptureStorage.production_planning:
		CaptureStorage.record_production_canvas(_scene.board_view, _scene.board_view.combat_state["enemies"][0])
	elif not _logic or OS.get_cmdline_user_args().has("--validate-crop"):
		if not CaptureStorage.check_production_canvas(_scene.board_view, _scene.board_view.combat_state["enemies"][0], _output, _stage, _frames.size()):
			quit(1)
			return
	var rig: Node = renderer.rigs[snapshot["facing"]]
	if _stage == "move" and not _walk_context.has(snapshot["facing"]):
		_walk_context[snapshot["facing"]] = {"rig": rig, "snapshot": snapshot.duplicate(true)}
	var pose: Array = []
	for bone: String in rig.bones:
		var node: Bone2D = rig.bones[bone]
		pose.append([bone, str(node.transform), node.modulate.a])
	var row: Dictionary = {"stage": _stage, "snapshot": snapshot, "pose_sha256": JSON.stringify(pose).sha256_text(), "seconds": _scene.proof_elapsed_seconds}
	var shown: Dictionary = _scene.board_view.presentation
	row["effect"] = shown.get("effect", {})
	if _stage in ["reel", "pin", "press"] and not (row["effect"] as Dictionary).is_empty():
		row["socket_proof"] = preload("renderer_sockets.gd").measure(_scene.board_view, renderer, row["effect"])
	row["effect_progress"] = shown.get("effect_progress", -1.0)
	row["cues"] = _scene.proof_cues.slice(_scene.proof_cue_start)
	row["player_pos"] = str(_scene.board_view.combat_state["player"]["pos"])
	row["player_hp"] = int(_scene.board_view.combat_state["player"]["hp"])
	row["actor_pos"] = str(_scene.board_view.combat_state["enemies"][0]["pos"])
	row["actor_block"] = int(_scene.board_view.combat_state["enemies"][0].get("block", 0))
	row["terrain_count"] = _scene.board_view.combat_state.get("terrain", []).size()
	row["ally_hp"] = int(_scene.board_view.combat_state["enemies"][1]["hp"]) if _scene.board_view.combat_state["enemies"].size() > 1 else -1
	row["root_alpha"] = rig.bones["root"].modulate.a
	row["bones"] = bones_for(rig)
	row["parts"] = parts_for(rig)
	var reference: Node2D = reference_for(snapshot)
	row["reference_bones"] = bones_for(reference)
	row["reference_parts"] = parts_for(reference)
	for unit: Dictionary in shown.get("death_animation_units", []):
		if str(unit.get("type", "")) == _type:
			row["death_progress"] = float(unit.get("death_progress", 0.0))
			row["fade_progress"] = preload("res://scripts/maquette_cutout_runtime/death.gd").dissolve_phase(_type, row["death_progress"])
	row["actor_tile"] = str(_scene.board_view.combat_state["enemies"][0]["pos"])
	row["surface_feedback_events"] = shown.get("surface_feedback_events", [])
	if not _logic:
		var image: Image = renderer.texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		var bytes: PackedByteArray = image.get_data()
		for alpha: int in range(3, bytes.size(), 4):
			if bytes[alpha] == 0:
				bytes[alpha - 3] = 0
				bytes[alpha - 2] = 0
				bytes[alpha - 1] = 0
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(bytes)
		row["pixels_sha256"] = hash.finish().hex_encode()
		var filename: String = "frame_%05d_%s.png" % [_frames.size(), _stage]
		row["file"] = filename
		CaptureStorage.save(_viewport.get_texture().get_image(), _output.path_join(filename), _stage)
	_frames.append(row)

func fixture(intent: String) -> Dictionary:
	var tile: Vector2i = PROOF_REAR_TILE if _rear_fixture else PROOF_FRONT_TILE
	var hero := Vector2i(4, 4)
	if intent == "iron_guard": hero = PROOF_GUARD_REAR_TARGET if _rear_fixture else PROOF_GUARD_FRONT_TARGET
	var actors: Array[Dictionary]
	actors.assign([Fixtures.enemy(_type, 1, tile, intent)])
	return Fixtures.state(actors, hero)

func install(state: Dictionary) -> void:
	Fixtures.install(_scene, state)
	await settle()
	if CaptureStorage.production_planning and not CaptureStorage.production_bounds.has_area():
		CaptureStorage.plan_production(_scene.board_view, _type, _data, fixture, Vector2i(5, 4))

func settle() -> void:
	for frame: int in range(SETTLE_FRAMES): await process_frame

func print_proof_images() -> void:
	for clip: String in _data["clips"]:
		var unique: Dictionary = {}
		for row: Dictionary in _frames:
			if row["stage"] == clip: unique[str(row["pixels_sha256"])] = row
		var selected: Array = unique.values()
		selected.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["snapshot"]["phase"]) < float(b["snapshot"]["phase"]))
		# Print native representatives without manufacturing extra idle states.
		var count: int = mini(6, selected.size())
		for sample: int in range(count):
			var index: int = roundi(float(sample) * (selected.size() - 1) / maxf(1.0, float(count - 1)))
			print(ProjectSettings.globalize_path(CaptureStorage.proof_png(_output.path_join(str(selected[index]["file"])))))
		if _data["clips"][clip].has("contact"):
			for row: Dictionary in _frames:
				if row["stage"] == clip and absf(float(row["snapshot"]["phase"]) - float(_data["clips"][clip]["contact"])) < 0.000001:
					print(ProjectSettings.globalize_path(CaptureStorage.proof_png(_output.path_join(str(row["file"])))))
					break

static func bones_for(rig: Node2D) -> Dictionary:
	var result: Dictionary = {}
	var source: Transform2D = rig.global_transform.affine_inverse()
	for name: String in rig.bones:
		var bone: Bone2D = rig.bones[name]
		result[name] = {"local": matrix(bone.transform), "global": matrix(source * bone.global_transform)}
	return result

static func matrix(value: Transform2D) -> Array:
	return [value.x.x, value.x.y, value.y.x, value.y.y, value.origin.x, value.origin.y]

static func parts_for(rig: Node2D) -> Dictionary:
	var result: Dictionary = {}
	var source: Transform2D = rig.global_transform.affine_inverse()
	for part: Dictionary in rig.layout["parts"]:
		var node: Node2D = rig.get_node_or_null(NodePath(str(part["name"])))
		if node == null: node = rig.bones[part["bone"]].get_node(NodePath(str(part["name"])))
		result[part["name"]] = {"transform": matrix(source * node.global_transform), "alpha": node.modulate.a}
	return result

func reference_for(snapshot: Dictionary) -> Node2D:
	var view: String = str(snapshot["facing"])
	if not _references.has(view):
		var reference := preload("res://scripts/maquette_cutout_runtime/rig.gd").new()
		reference.case_directory = _reference_case
		reference.facing = view
		root.add_child(reference)
		if not reference.load_rig(): _failures.append("Source reference failed: " + str(reference.load_errors))
		_references[view] = reference
	var reference: Node2D = _references[view]
	# Use the same canvas translation/reflection for the independent source rig.
	# A zero-origin oracle changes float32 half-pixel snap ties in guard; compare
	# identical presentation conditions without changing the authored motion.
	var renderer: Node = _scene.board_view.unit_cutout_renderer({"type": _type, "id": 1})
	reference.global_transform = renderer.rigs[view].global_transform
	reference.layout["screen_pixel_scale"] = snapshot["screen_pixel_scale"]
	reference.layout["step_distance_px"] = snapshot["step_distance_px"]
	reference.apply_pose(snapshot["shown_clip"], snapshot["phase"])
	return reference
