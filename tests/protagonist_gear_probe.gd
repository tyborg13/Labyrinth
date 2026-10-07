extends SceneTree

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Gear = preload("res://scripts/protagonist_cutout/gear_visuals.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const Baker = preload("res://scripts/protagonist_cutout/gear_rest_baker.gd")
const Layers = preload("res://tests/helpers/protagonist_gear_layer_checks.gd")
const Suite = preload("res://tests/suites/protagonist_gear_suite.gd")
const SIZE := Vector2i(1920, 1080)
const OUTPUT: String = "user://probes/protagonist_gear"

var _surface: SubViewport
var _scene: Node
var _board: Control
var _errors: Array[String] = []
var _manifest: Dictionary = {"size": [1920, 1080], "ui_scale": 1.0, "captures": []}

func _initialize() -> void:
	Runtime.apply_from_environment()
	if DisplayServer.get_name() == "headless":
		push_error("Protagonist gear probe requires a real renderer")
		quit(1)
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	Settings.set_storage_path("user://gear_probe_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	Progression.set_storage_path("user://gear_probe_profile.json")
	Progression.set_run_storage_path("user://gear_probe_run.save")
	Progression.clear_saved_run()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await Suite.run(self, _expect)
	print("PROTAGONIST GEAR REAL-RENDERER SUITE: " + ("PASS" if _errors.is_empty() else "FAIL"))
	# This is the source of the shipped default PNG, never a CPU composite.
	var default_signature: String = Gear.signature(Gear.DEFAULTS)
	var pending: Node = Baker._jobs.get(default_signature, null)
	if is_instance_valid(pending):
		await pending.baked
	else:
		var job := Baker.new()
		root.add_child(job)
		await job._bake(default_signature, Gear.DEFAULTS)
	var default_rest: Texture2D = Baker.cached(Gear.signature(Gear.DEFAULTS))
	_expect(default_rest != null, "Default real-renderer bake exists")
	if default_rest != null:
		var pixels: Image = AssetLoader.texture_source_image(default_rest)
		_expect(pixels.save_png(OUTPUT.path_join("front_default_gear_rest.png")) == OK, "Default PNG saves")
		if OS.get_cmdline_user_args().has("--write-default-rest"):
			_expect(pixels.save_png(Baker.DEFAULT_PATH) == OK, "Production default gear rest PNG saves")
			var import_file := FileAccess.open(Baker.DEFAULT_PATH + ".import", FileAccess.WRITE)
			import_file.store_string("[remap]\n\nimporter=\"keep\"\n\n[deps]\n\nsource_file=\"" + Baker.DEFAULT_PATH + "\"\n")
			AssetLoader._texture_cache.erase(Baker.DEFAULT_PATH)
		if FileAccess.file_exists(Baker.DEFAULT_PATH):
			# The board proof must exercise the shipped cached-shadow identity.
			Baker._cache[Gear.signature(Gear.DEFAULTS)] = AssetLoader.load_texture_source_first(Baker.DEFAULT_PATH)
	_surface = SubViewport.new()
	_surface.size = SIZE
	_surface.disable_3d = true
	_surface.world_2d = World2D.new()
	_surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_surface)
	_scene = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_surface.add_child(_scene)
	await _settle()
	_board = _scene.get("board_view")
	var loadouts: Array = [Gear.DEFAULTS, Suite.L1, Suite.L2, Suite.L3, Suite.L4]
	for index: int in range(loadouts.size()):
		await _fixture(loadouts[index])
		await _pose("idle", 0.0)
		await _capture("L%d_board_idle_front" % index)
		await _pose("walk", 0.25, Vector2i(0, -1))
		await _capture("L%d_board_walk_rear" % index)
	# Mirrored facings: southeast reflects the front rig, northwest the rear.
	for index: int in [0, 1, 2]:
		await _fixture(loadouts[index])
		await _pose("walk", 0.25, Vector2i(1, 0))
		await _capture("L%d_board_walk_mirrored_front" % index)
		await _pose("walk", 0.25, Vector2i(-1, 0))
		await _capture("L%d_board_walk_mirrored_rear" % index)
	for index: int in [0, 2]:
		await _fixture(loadouts[index])
		for clip: String in ["shoot", "cast"]:
			await _pose(clip, 0.42)
			var snap: Dictionary = _board.protagonist_animation_snapshot()
			_expect(snap["crossbow_visible"] == (clip == "shoot"), "Crossbow only shows for shooting")
			_expect(bool(snap["offhand_visible"]), "The offhand stays equipped while casting and shooting")
			await _capture("L%d_board_%s_phase_042" % [index, clip])
	await _fixture(Gear.DEFAULTS)
	await _pose("block", 0.25)
	await _capture("L0_board_block_phase_025")
	await _fixture(Suite.L2, true)
	await _pose("idle", 0.0)
	await _capture("L2_board_active_illusion")
	await _fixture(Suite.L1, false, true)
	await _pose("walk", 0.25, Vector2i(0, -1))
	await _capture("L1_board_reduced_motion")
	for index: int in [1, 2]:
		await _fixture(loadouts[index])
		_scene.call("_open_character_overlay", "equipment")
		await _settle()
		await _capture("L%d_character_gear" % index, false)
		_scene.call("_close_card_upgrade_overlay")
		await _settle()
	_manifest["gpu_readbacks"] = Baker._readbacks.duplicate()
	var file := FileAccess.open(OUTPUT.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_manifest, "\t"))
	_scene.queue_free()
	await process_frame
	for error: String in _errors:
		push_error(error)
	print("PROTAGONIST GEAR PROBE RESULT: " + ("PASS" if _errors.is_empty() else "FAIL"))
	print(ProjectSettings.globalize_path(OUTPUT))
	quit(0 if _errors.is_empty() else 1)

func _fixture(equipped: Dictionary, illusion: bool = false, reduced: bool = false) -> void:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	var hand: Array = ["quick_stab", "brace", "sidestep_slash", "bone_dart", "patch_up"]
	var layout: Dictionary = {"name": "Visible Gear Trial", "coord": Vector2i(4, 3), "type": "combat", "grid": grid, "player_start": Vector2i(3, 3), "enemies": [{"id": 1, "type": "crawler", "pos": Vector2i(5, 3), "hp": 40, "max_hp": 40, "block": 0}], "traps": [], "terrain": [], "element": "none"}
	var engine := Combat.new()
	var state: Dictionary = engine.create_combat(261005, layout, {"hp": 24, "max_hp": 24, "deck_cards": hand.duplicate(), "relics": [], "hand_size": 5, "heal_bonus": 0})
	state["deck"] = {"hand": hand, "draw": [], "discard": [], "burned": []}
	state["current_actor"] = {"kind": "player", "key": "player"}
	if illusion:
		state["illusions"] = [{"id": 8, "pos": Vector2i(3, 4), "hp": 2, "max_hp": 2, "block": 0}]
	var progression: Dictionary = (_scene.get("_progression") as Dictionary).duplicate(true)
	for prompt: String in Tutorial.prompt_ids():
		progression = Tutorial.resolve_progression(progression, prompt)
	var run: Dictionary = (_scene.get("_run_state") as Dictionary).duplicate(true)
	run.merge({"mode": "combat", "current_room": layout["coord"], "current_room_layout": layout, "combat_state": state, "progression": progression, "equipped_equipment": equipped.duplicate(), "equipment_inventory": Gear._items.keys()}, true)
	_scene.set("_progression", progression)
	_scene.set("_run_state", run)
	var settings: Dictionary = (_scene.get("_settings") as Dictionary).duplicate()
	settings["reduced_motion"] = reduced
	settings["ui_scale"] = 1.0
	_scene.set("_settings", settings)
	_scene.call("_sync_combat_state_from_run")
	_scene.set("_animation_lock", false)
	_scene.call("_refresh_ui")
	Input.warp_mouse(Vector2(960, 80))
	await _settle()
	for renderer: Node in (_board.get("_illusion_renderers") as Dictionary).values():
		renderer.set_process(false)
	(_board.get("_protagonist_renderer") as Node).set_process(false)

func _pose(clip: String, phase: float, direction: Vector2i = Vector2i(0, 1)) -> void:
	var presentation: Dictionary = (_board.get("presentation") as Dictionary).duplicate()
	presentation["protagonist_motion"] = {"clip": clip, "phase": phase, "direction": direction}
	_board.set_combat_state(_scene.get("_combat_state"), _board.get("move_tiles"), _board.get("attack_tiles"), _board.get("selected_tile"), _board.get("status_label"), _board.get("status_detail"), _board.get("exit_tiles"), _board.get("exit_icon_ids"), presentation)
	var renderer: Node = _board.get("_protagonist_renderer")
	if clip == "idle":
		renderer.set("_idle_seconds", 0.0)
		renderer.call("_apply_pose")
	await _settle()

func _capture(label: String, board_capture: bool = true) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = _surface.get_texture().get_image()
	_expect(image.get_size() == SIZE, "Capture uses exact 1920x1080 SubViewport")
	_expect(image.save_png(OUTPUT.path_join(label + ".png")) == OK, "Capture saves: " + label)
	if board_capture:
		var player: Dictionary = (_scene.get("_combat_state") as Dictionary)["player"].duplicate()
		player["type"] = "player"
		player["role"] = "player"
		var center: Vector2 = _board.call("world_position_for_tile", player["pos"])
		var body: Rect2 = _board.call("_unit_draw_rect_for_center", player, center)
		var screen_center: Vector2 = _board.get_global_transform_with_canvas() * body.get_center()
		var crop_origin := Vector2i(screen_center - Vector2(170, 170))
		var zoom: Image = image.get_region(Rect2i(crop_origin, Vector2i(340, 340)))
		zoom.resize(1020, 1020, Image.INTERPOLATE_NEAREST)
		_expect(zoom.save_png(OUTPUT.path_join(label + "_hero_3x.png")) == OK, "Nearest-neighbour hero crop saves")
	var renderer: Node = _board.get("_protagonist_renderer")
	var rig: Node2D = renderer.rigs[renderer.snapshot()["facing"]]
	Layers.overlays(rig, _expect)
	_manifest["captures"].append({"file": label + ".png", "hero": _board.protagonist_animation_snapshot(),
		"weapon_z": rig._gear_base_parts["weapon_r"]["node"].z_index, "grip_visible": rig._gear_layers.grip.is_visible_in_tree()})

func _settle() -> void:
	for frame: int in range(5):
		await process_frame
		await RenderingServer.frame_post_draw

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
