extends SceneTree

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
var _type: String
var _output: String
var _scene: Control
var _viewport: SubViewport
var _stage: String
var _logic: bool
var _frames: Array[Dictionary]
var _failures: Array[String]
var _data: Dictionary

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.find("--type") < 0 or args.find("--output") < 0:
		push_error("Use -- --type hoarfrost_seer|arc_thrall --output DIRECTORY [--logic-only]")
		quit(1)
		return
	_type = args[args.find("--type") + 1]
	_output = args[args.find("--output") + 1]
	_logic = args.has("--logic-only")
	_data = Action.data_for(_type)
	if _data.is_empty() or (DisplayServer.get_name() == "headless" and not _logic):
		push_error("Production capture requires a registered creature and windowed renderer (or --logic-only)")
		quit(1)
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	Settings.set_storage_path("user://rr07_settings.json")
	Store.set_storage_path("user://rr07_profile.json")
	Store.set_run_storage_path("user://rr07_run.save")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	_viewport = CaptureViewport.create(root)
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	_scene.set_script(CaptureScene)
	_scene.proof_actor_type = _type
	_scene.proof_capture = _capture
	_viewport.add_child(_scene)
	await settle()
	_scene._load_run_state(Run.new().create_new_run(Fixtures.TEST_SEED, Store.default_data()))
	await settle()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	for clip: String in _data["clips"]:
		_stage = clip
		var state: Dictionary = fixture("icefall" if _type == "hoarfrost_seer" else "arc_jab")
		if clip == "idle":
			await install(state)
			var renderer: Node = _scene.board_view.unit_cutout_renderer({"type": _type, "id": 1})
			# Idle advances with production _process, not a sought proof phase.
			var count: int = roundi(Action.seconds_for(_type, "idle") * 60.0)
			for frame: int in range(count):
				await _capture()
				await create_timer(IDLE_SAMPLE_SECONDS).timeout
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
		var selector: String = str(_data["clips"][clip]["intents"][0])
		var fields: PackedStringArray = selector.split(":")
		state = fixture(fields[0])
		if clip == "jab": state["enemies"][0]["pos"] = Vector2i(5, 4)
		await install(state)
		var action: Dictionary = {}
		for item: Dictionary in state["enemies"][0]["intent"]["actions"]:
			if fields.size() == 1 or str(item["type"]) == fields[1]: action = item
		var engine := Combat.new()
		var context: Dictionary = engine.enemy_intent_plan(state, 0)
		var after: Dictionary = engine._resolve_enemy_action(state.duplicate(true), 0, action, null, {}, engine._dictionary_values([]), context)
		var step: Dictionary = engine._enemy_action_step(state, after, 0, action, context)
		await _scene.record_action(clip, func() -> void: await _scene._animate_enemy_phase_steps(state.duplicate(true), [step]))
	_failures.append_array(preload("res://tests/maquette_cutout/capture_contract.gd").errors(_frames, _data, _scene.proof_completions, not _logic))
	for error: String in _failures: push_error(error)
	var integration_path: String = "res://assets/units/" + str(_data["creature"]) + "_cutout/integration.json"
	var integration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(integration_path))
	var bindings: Dictionary = preload("res://tests/maquette_cutout/proof_inputs.gd").bindings("res://" + str(integration["case"]))
	bindings.merge(preload("res://tests/maquette_cutout/proof_inputs.gd").production_bindings(integration_path.get_base_dir()))
	var report: Dictionary = {"ok": _failures.is_empty(), "native_pixels": not _logic, "type": _type,
		"size": [1920, 1080], "ui_scale": 1.0, "inputs": bindings, "frames": _frames, "completions": _scene.proof_completions, "errors": _failures}
	var file := FileAccess.open(_output.path_join("logic_frames.json" if _logic else "frames.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	print("MAQUETTE PRODUCTION %s: %s (%d frames)" % ["LOGIC" if _logic else "NATIVE", "PASS" if _failures.is_empty() else "FAIL", _frames.size()])
	print("Saved " + ProjectSettings.globalize_path(_output))
	if not _logic: print_proof_images()
	_scene.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)

func _capture() -> void:
	await process_frame
	await process_frame
	if not _logic: await RenderingServer.frame_post_draw
	var renderer: Node = _scene.board_view.unit_cutout_renderer({"type": _type, "id": 1})
	if renderer == null: return
	var snapshot: Dictionary = renderer.snapshot()
	if snapshot["clip"] != _stage: return
	var rig: Node = renderer.rigs[snapshot["facing"]]
	var pose: Array = []
	for bone: String in rig.bones:
		var node: Bone2D = rig.bones[bone]
		pose.append([bone, str(node.transform), node.modulate.a])
	var row: Dictionary = {"stage": _stage, "snapshot": snapshot, "pose_sha256": JSON.stringify(pose).sha256_text(), "seconds": _scene.proof_elapsed_seconds}
	var shown: Dictionary = _scene.board_view.presentation
	row["effect"] = shown.get("effect", {})
	row["player_hp"] = int(_scene.board_view.combat_state["player"]["hp"])
	row["marks"] = _scene.board_view.combat_state["enemies"][0].get("icefall_tiles", []).size()
	if _type == "arc_thrall":
		var partner: Node = _scene.board_view.unit_cutout_renderer({"type": _type, "id": 2})
		row["partner_clip"] = partner.snapshot()["clip"] if partner != null else "missing"
		if _stage == "tether" and row["partner_clip"] == "tether": _failures.append("Tether animated the non-acting partner")
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
		_viewport.get_texture().get_image().save_png(_output.path_join(filename))
	_frames.append(row)

func fixture(intent: String) -> Dictionary:
	var actors: Array[Dictionary]
	actors.assign([Fixtures.enemy(_type, 1, Vector2i(2, 4), intent)])
	if _type == "arc_thrall": actors.append(Fixtures.enemy(_type, 2, Vector2i(6, 4), "tether"))
	var state: Dictionary = Fixtures.state(actors)
	if intent == "icefall_land":
		# Generate the marked tiles with the real resolver before installing land.
		var engine := Combat.new()
		var marked: Dictionary = fixture("icefall")
		var mark: Dictionary = marked["enemies"][0]["intent"]["actions"][0]
		var context: Dictionary = engine.enemy_intent_plan(marked, 0)
		state = engine._resolve_enemy_action(marked, 0, mark, null, {}, engine._dictionary_values([]), context)
		state["enemies"][0]["intent"] = Fixtures.enemy(_type, 1, Vector2i(2, 4), intent)["intent"]
	return state

func install(state: Dictionary) -> void:
	Fixtures.install(_scene, state)
	await settle()

func settle() -> void:
	for frame: int in range(SETTLE_FRAMES): await process_frame

func print_proof_images() -> void:
	for clip: String in _data["clips"]:
		var unique: Dictionary = {}
		for row: Dictionary in _frames:
			if row["stage"] == clip: unique[str(row["pixels_sha256"])] = row
		var selected: Array = unique.values()
		selected.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["snapshot"]["phase"]) < float(b["snapshot"]["phase"]))
		if selected.size() < 6: continue
		for sample: int in range(6):
			var index: int = roundi(float(sample) * (selected.size() - 1) / 5.0)
			print(ProjectSettings.globalize_path(_output.path_join(str(selected[index]["file"]))))
		if _data["clips"][clip].has("contact"):
			for row: Dictionary in _frames:
				if row["stage"] == clip and absf(float(row["snapshot"]["phase"]) - float(_data["clips"][clip]["contact"])) < 0.000001:
					print(ProjectSettings.globalize_path(_output.path_join(str(row["file"]))))
					break
