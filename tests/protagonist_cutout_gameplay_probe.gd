extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const ContextualCombatTutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const InputRouter = preload("res://scripts/input_router.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const Cutout = preload("res://scripts/protagonist_cutout/renderer.gd")
const OUTPUT: String = "user://probes/protagonist_cutout_gameplay_v9"
const SIZE := Vector2i(1920, 1080)

var _errors: Array[String] = []
var _capture: bool = false
var _manifest: Dictionary = {"size": [1920, 1080], "ui_scale": 1.0, "clips": [], "checks": []}
var _instance: Node
var _board: Control
var _render_viewport: Viewport
var _texture_id: int = 0

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_capture = DisplayServer.get_name() != "headless"
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = SIZE
	root.size = SIZE
	if _capture:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(SIZE)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	ProgressionStore.set_storage_path("user://cutout_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://cutout_probe_run.save")
	ProgressionStore.clear_saved_run()
	_instance = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_render_viewport = root
	if _capture:
		# Capture an actual 1920x1080 render target, independent of Retina backing
		# pixels or settings applying to the native host window during _ready().
		var surface := SubViewport.new()
		surface.size = SIZE
		surface.disable_3d = true
		surface.world_2d = World2D.new()
		surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(surface)
		_render_viewport = surface
	_render_viewport.add_child(_instance)
	await _settle()
	_board = _instance.get("board_view") as Control
	await _fixture(Vector2i(3, 3), Vector2i(5, 4))
	_texture_id = int(_snapshot()["texture_id"])
	_manifest["source_pixel_scale"] = _board.call("protagonist_source_pixel_scale")
	_manifest["tile_world_step"] = str(_board.call("world_position_for_tile", Vector2i(4, 3)) - _board.call("world_position_for_tile", Vector2i(3, 3)))
	await _record("01_idle", 3.4)
	var directions: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	for index: int in range(directions.size()):
		var direction: Vector2i = directions[index]
		await _fixture(Vector2i(3, 3), Vector2i(6, 6))
		await _instance.call("_on_board_tile_clicked", Vector2i(3, 3))
		_instance.call("_on_board_tile_hovered", Vector2i(3, 3) + direction)
		await _settle()
		_instance.call("_on_board_tile_clicked", Vector2i(3, 3) + direction)
		await _record("%02d_walk_%s" % [2 + index * 2, _direction_name(index)], 0.1)
		_assert(_player_pos() == Vector2i(3, 3) + direction, "Movement commits the selected tile in direction %s" % direction)
		_assert(CombatEngine.new().player_movement_remaining(_instance.get("_combat_state")) == 1, "Movement spends exactly one tile")
		_assert_facing(index)
		await _fixture(Vector2i(3, 3), Vector2i(3, 3) + direction)
		await _instance.call("_on_card_pressed", 0)
		_instance.call("_on_board_tile_hovered", Vector2i(3, 3) + direction)
		await _settle()
		_instance.call("_on_board_tile_clicked", Vector2i(3, 3) + direction)
		await _record("%02d_melee_%s" % [3 + index * 2, _direction_name(index)], 0.1)
		var enemy: Dictionary = (_instance.get("_combat_state") as Dictionary)["enemies"][0]
		_assert(int(enemy["hp"]) == 31, "Quick Stab applies its exact 9 damage once")
		_assert_facing(index)
	await _fixture(Vector2i(3, 2), Vector2i(6, 6))
	await _instance.call("_on_board_tile_clicked", Vector2i(3, 2))
	_instance.call("_on_board_tile_hovered", Vector2i(3, 4))
	await _settle()
	_instance.call("_on_board_tile_clicked", Vector2i(3, 4))
	await _record("09a_walk_two_tiles", 0.1)
	_assert(_player_pos() == Vector2i(3, 4) and CombatEngine.new().player_movement_remaining(_instance.get("_combat_state")) == 0, "Longer gait crosses two tiles and spends exactly two movement")
	_assert_facing(0)
	await _fixture(Vector2i(3, 3), Vector2i(3, 4), false, ["whirlwind_slash", "brace", "quick_stab", "bone_dart", "patch_up"], 24, [Vector2i(4, 3), Vector2i(3, 2), Vector2i(2, 3)])
	var sweep_facing: Dictionary = _snapshot()
	await _instance.call("_on_card_pressed", 0)
	_instance.call("_on_confirm_card_play_pressed")
	await _record("09b_melee_whirlwind", 0.1)
	var sweep_enemies: Array = (_instance.get("_combat_state") as Dictionary)["enemies"]
	_assert(sweep_enemies.size() == 4, "Whirlwind keeps all four nonlethal adjacent targets")
	for enemy: Dictionary in sweep_enemies:
		_assert(int(enemy["hp"]) == 32, "Whirlwind applies its exact 8 damage once to every adjacent enemy")
	_assert(_snapshot()["facing"] == sweep_facing["facing"] and _snapshot()["mirrored"] == sweep_facing["mirrored"], "Self-centered melee retains its previous facing")
	# Defensive card and ordinary UI refresh exercise the action-focus idle path.
	await _fixture(Vector2i(3, 3), Vector2i(5, 4))
	await _instance.call("_on_card_pressed", 1)
	_instance.call("_on_board_tile_clicked", Vector2i(3, 3))
	await _record("10_defensive_action", 0.1)
	_assert(int((_instance.get("_combat_state") as Dictionary)["player"].get("block", 0)) > 0, "Defensive card resolves while using camera-facing cutout idle")
	await _fixture(Vector2i(3, 3), Vector2i(5, 3))
	await _instance.call("_on_card_pressed", 3)
	_instance.call("_on_board_tile_clicked", Vector2i(5, 3))
	await _record("11_ranged_action", 0.1)
	_assert(int((_instance.get("_combat_state") as Dictionary)["enemies"][0]["hp"]) < 40, "Ranged damage resolves while using camera-facing cutout idle")
	await _fixture(Vector2i(3, 3), Vector2i(5, 3), false, ["cinderburst", "brace", "quick_stab", "bone_dart", "patch_up"])
	await _instance.call("_on_card_pressed", 0)
	_instance.call("_on_board_tile_clicked", Vector2i(5, 3))
	await _record("11a_targeted_aoe", 0.1)
	_assert(int((_instance.get("_combat_state") as Dictionary)["enemies"][0]["hp"]) == 33, "Targeted AoE retains idle while applying its exact ranged-area damage")
	await _fixture(Vector2i(3, 3), Vector2i(6, 6), false, ["shadow_step", "brace", "quick_stab", "bone_dart", "patch_up"])
	await _instance.call("_on_card_pressed", 0)
	_instance.call("_on_board_tile_clicked", Vector2i(4, 4))
	await _record("11b_blink", 0.1)
	_assert(_player_pos() == Vector2i(4, 4), "Blink reaches its exact destination with new-art afterimages")
	await _fixture(Vector2i(3, 3), Vector2i(5, 4), false, ["guarded_step", "brace", "quick_stab", "bone_dart", "patch_up"])
	await _instance.call("_on_card_pressed", 0)
	_instance.call("_on_board_tile_clicked", Vector2i(3, 4))
	await _record("11c_guarded_step", 0.1)
	_assert(_player_pos() == Vector2i(3, 4) and int((_instance.get("_combat_state") as Dictionary)["player"].get("block", 0)) > 0, "Move-then-Block resolves both actions without swapping art")
	# Enemy phases await frame_post_draw; exercise them on the real renderer.
	if _capture:
		await _fixture(Vector2i(3, 3), Vector2i(3, 4))
		for activation: int in range(3):
			_instance.call("_on_pass_turn_pressed")
			await _record("11d_take_damage_%d" % activation, 0.1)
			if int((_instance.get("_combat_state") as Dictionary)["player"]["hp"]) < 24:
				break
		_assert(int((_instance.get("_combat_state") as Dictionary)["player"]["hp"]) < 24, "Enemy damage resolves with the new cutout still present")
	# Controller target/cancel restores idle without changing game state or art.
	await _fixture(Vector2i(3, 3), Vector2i(5, 4))
	var router: Node = root.get_node_or_null("InputRouter")
	if router != null:
		router.call("set_forced_state_for_test", InputRouter.MODALITY_CONTROLLER, InputRouter.FAMILY_STEAM_DECK)
		_instance.call("_refresh_controller_interface")
		await _instance.call("_on_board_tile_clicked", Vector2i(3, 3))
		await _settle()
		await _still("12_controller_target")
		var before: Dictionary = (_instance.get("_combat_state") as Dictionary).duplicate(true)
		var cancel := InputEventAction.new()
		cancel.action = InputRouter.ACTION_CANCEL
		cancel.pressed = true
		_assert(await _instance.call("_handle_controller_input", cancel), "Controller Cancel is handled")
		_assert(before == _instance.get("_combat_state"), "Controller Cancel preserves the entire combat state")
		router.call("set_forced_state_for_test", InputRouter.MODALITY_POINTER, InputRouter.FAMILY_STEAM_DECK)
		_instance.call("_refresh_controller_interface")
	await _settle()
	_instance.call("_on_character_pressed")
	await _settle()
	var art: TextureRect = _instance.find_child("EquipmentCharacterArt", true, false) as TextureRect
	_assert(art != null and art.texture is AtlasTexture and art.get_node_or_null("EquipmentCutout") != null, "Equipment uses the new live cutout idle")
	await _still("13_equipment")
	_instance.call("_close_card_upgrade_overlay")
	await _settle()
	var cached_settings: Dictionary = (_instance.get("_settings") as Dictionary).duplicate(true)
	cached_settings["reduced_motion"] = true
	_instance.set("_settings", cached_settings)
	_instance.call("_on_character_pressed")
	await _settle()
	art = _instance.find_child("EquipmentCharacterArt", true, false) as TextureRect
	_assert(art.get_node("EquipmentCutout").call("snapshot")["clip"] == "rest", "Cached equipment follows a later reduced-motion setting change")
	await _still("13_equipment_reduced")
	_instance.call("_close_card_upgrade_overlay")
	cached_settings["reduced_motion"] = false
	_instance.set("_settings", cached_settings)
	await _settle()
	var run: Dictionary = (_instance.get("_run_state") as Dictionary).duplicate(true)
	_assert(ProgressionStore.save_run_state(run), "Cutout gameplay saves successfully")
	var loaded: Dictionary = ProgressionStore.load_saved_run()
	_assert(loaded["combat_state"] == run["combat_state"], "Save/resume preserves combat exactly without rig resources in persisted state")
	_instance.set("_run_state", loaded)
	_instance.call("_sync_combat_state_from_run")
	_instance.call("_refresh_ui")
	await _settle()
	await _still("14_resumed")
	await _fixture(Vector2i(3, 3), Vector2i(3, 4), true)
	await _instance.call("_on_card_pressed", 0)
	_instance.call("_on_board_tile_clicked", Vector2i(3, 4))
	await _record("15_reduced_melee", 0.1)
	_assert(_snapshot()["clip"] == "rest", "Reduced motion presents the new neutral cutout")
	_assert(int((_instance.get("_combat_state") as Dictionary)["enemies"][0]["hp"]) == 31, "Reduced-motion melee preserves the exact damage")
	await _still("16_reduced_idle")
	# Enemy phases await frame_post_draw; exercise them on the real renderer.
	if _capture:
		# Terminal damage goes through the real enemy-turn and defeat presentation.
		await _fixture(Vector2i(3, 3), Vector2i(3, 4), false, [], 1)
		for activation: int in range(3):
			_instance.call("_on_pass_turn_pressed")
			await _record("17_terminal_defeat_%d" % activation, 0.1)
			if str((_instance.get("_run_state") as Dictionary).get("mode", "")) == "defeat":
				break
		_assert(str((_instance.get("_run_state") as Dictionary).get("mode", "")) == "defeat", "Lethal damage reaches the terminal defeat screen")
	# Inspect the ordinary room renderer after leaving the combat presentation.
	await _fixture(Vector2i(3, 3), Vector2i(6, 6))
	var room_run: Dictionary = (_instance.get("_run_state") as Dictionary).duplicate(true)
	room_run["mode"] = "room"
	room_run["combat_state"] = {}
	room_run["pending_reward"] = {}
	room_run["current_room_layout"]["type"] = "empty"
	_instance.set("_run_state", room_run)
	_instance.call("_sync_combat_state_from_run")
	_instance.call("_refresh_ui")
	await _settle()
	await _record("18_room_idle", 0.6)
	_assert(_snapshot()["clip"] == "idle", "Ordinary room presentation keeps cutout idle active")
	_manifest["native_enemy_phase_checks"] = _capture
	_manifest["errors"] = _errors
	var file: FileAccess = FileAccess.open(OUTPUT + "/manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(_manifest, "\t"))
	file.close()
	if router != null:
		router.call("clear_forced_state_for_test")
	_instance.queue_free()
	if _render_viewport != root:
		_render_viewport.queue_free()
	await process_frame
	for message: String in _errors:
		push_error(message)
	print("PROTAGONIST CUTOUT GAMEPLAY PROBE: " + ("PASS" if _errors.is_empty() else "FAIL"))
	print(ProjectSettings.globalize_path(OUTPUT))
	quit(0 if _errors.is_empty() else 1)

func _fixture(player_tile: Vector2i, enemy_tile: Vector2i, reduced: bool = false, custom_hand: Array = [], player_hp: int = 24, extra_enemy_tiles: Array = []) -> void:
	_instance.call("_cancel_drag_play")
	_instance.call("_reset_card_resolution")
	var hand: Array = custom_hand.duplicate() if not custom_hand.is_empty() else ["quick_stab", "brace", "sidestep_slash", "bone_dart", "patch_up"]
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	var layout: Dictionary = {"name": "Cutout Animation Trial", "coord": Vector2i(4, 3), "type": "combat", "grid": grid,
		"player_start": player_tile, "enemies": [{"id": 1, "type": "crawler", "pos": enemy_tile, "hp": 40, "max_hp": 40, "block": 0}],
		"traps": [], "terrain": [], "element": "none"}
	for tile: Vector2i in extra_enemy_tiles:
		layout["enemies"].append({"id": (layout["enemies"] as Array).size() + 1, "type": "crawler", "pos": tile, "hp": 40, "max_hp": 40, "block": 0})
	var combat := CombatEngine.new()
	var state: Dictionary = combat.create_combat(260908, layout, {"hp": player_hp, "max_hp": 24, "deck_cards": hand.duplicate(), "relics": [], "hand_size": 5, "heal_bonus": 0})
	state["deck"] = {"hand": hand.duplicate(), "draw": [], "discard": [], "burned": []}
	state["current_actor"] = {"kind": "player", "key": "player"}
	state["cards_played_this_turn"] = 0
	state["death_bonus_card_plays_this_turn"] = 0
	state["card_play_bonus_this_turn"] = 0
	state["traps"] = []
	state["terrain"] = []
	state = combat.normalize_player_movement_pool(state)
	var progression: Dictionary = (_instance.get("_progression") as Dictionary).duplicate(true)
	for prompt: String in ContextualCombatTutorial.prompt_ids():
		progression = ContextualCombatTutorial.resolve_progression(progression, prompt)
	var run: Dictionary = (_instance.get("_run_state") as Dictionary).duplicate(true)
	run["mode"] = "combat"
	run["current_room"] = layout["coord"]
	run["current_room_layout"] = layout
	run["combat_state"] = state.duplicate(true)
	run["progression"] = progression.duplicate(true)
	_instance.set("_progression", progression)
	_instance.set("_run_state", run)
	var settings: Dictionary = (_instance.get("_settings") as Dictionary).duplicate(true)
	settings["reduced_motion"] = reduced
	settings["ui_scale"] = 1.0
	_instance.set("_settings", settings)
	_instance.call("_sync_combat_state_from_run")
	_instance.set("_animation_lock", false)
	_instance.call("_refresh_ui")
	if _capture:
		Input.warp_mouse(Vector2(960, 86))
	await _settle()

func _record(label: String, minimum_seconds: float) -> void:
	var started: int = Time.get_ticks_usec()
	var next_capture: int = started
	var samples: Array[Dictionary] = []
	var images: Array[Image] = []
	var phases: Dictionary = {}
	var finish: int = 0
	while Time.get_ticks_usec() - started < 8000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		if not bool(_instance.get("_animation_lock")) and finish == 0:
			finish = now
		var snapshot: Dictionary = _snapshot()
		_assert(int(snapshot.get("texture_id", 0)) == _texture_id, "One cutout texture remains live throughout " + label)
		phases[str(snapshot.get("clip", ""))] = true
		if snapshot.get("clip") == "idle":
			_assert(snapshot["facing"] == "front" and not snapshot["mirrored"], "Every idle frame returns to the camera-facing default in " + label)
		if snapshot.get("clip") == "attack":
			var unit: Dictionary = {"type": "player", "key": "player", "role": "player", "pos": _player_pos()}
			_assert((_board.call("_unit_center", unit) as Vector2).is_equal_approx(_board.call("world_position_for_tile", _player_pos())), "Melee keeps the cutout's planted stance on its actual tile")
		if now >= next_capture:
			next_capture = now + 33333
			var sample: Dictionary = {"seconds": float(now - started) / 1000000.0, "animation": snapshot,
				"center": str(_board.call("_unit_center", {"type": "player", "key": "player", "role": "player", "pos": _player_pos()})),
				"effect": (_board.get("presentation") as Dictionary).get("effect", {}),
				"effect_progress": float((_board.get("presentation") as Dictionary).get("effect_progress", 0.0)),
				"death_units": (_board.get("presentation") as Dictionary).get("death_animation_units", []),
				"player_hp": int((_instance.get("_combat_state") as Dictionary).get("player", {}).get("hp", 0))}
			if _capture:
				await RenderingServer.frame_post_draw
				images.append(_render_viewport.get_texture().get_image())
			samples.append(sample)
		if finish > 0 and now - started >= int(minimum_seconds * 1000000.0) and now - finish > 180000:
			break
	_assert(not bool(_instance.get("_animation_lock")), "Gameplay returns input after " + label)
	var directory: String = OUTPUT.path_join(label)
	if _capture:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		for index: int in range(images.size()):
			images[index].save_jpg(directory.path_join("frame_%04d.jpg" % index), 0.96)
		if not images.is_empty():
			_assert(images[-1].get_size() == SIZE, "Capture is natively 1920x1080")
			images[-1].save_png(OUTPUT.path_join(label + ".png"))
			if label.contains("melee") and not label.contains("reduced"):
				for phase_target: float in [0.27, 0.44, 0.60]:
					var nearest: int = -1
					var difference: float = INF
					for index: int in range(samples.size()):
						var animation: Dictionary = samples[index]["animation"]
						var gap: float = absf(float(animation["phase"]) - phase_target)
						if animation["clip"] == "attack" and gap < difference:
							nearest = index
							difference = gap
					if nearest >= 0:
						images[nearest].save_png(OUTPUT.path_join(label + "_phase_%03d.png" % roundi(phase_target * 100)))
		if label.contains("terminal_defeat") or label.contains("take_damage"):
			for index: int in range(samples.size()):
				if not (samples[index].get("death_units", []) as Array).is_empty() or not (samples[index].get("effect", {}) as Dictionary).is_empty():
					images[index].save_png(OUTPUT.path_join(label + "_contact.png"))
					break
		if label.contains("blink"):
			for phase_target: float in [0.25, 0.5, 0.75]:
				var nearest: int = -1
				var difference: float = INF
				for index: int in range(samples.size()):
					if str((samples[index].get("effect", {}) as Dictionary).get("kind", "")) != "blink":
						continue
					var gap: float = absf(float(samples[index].get("effect_progress", 0.0)) - phase_target)
					if gap < difference:
						nearest = index
						difference = gap
				if nearest >= 0:
					images[nearest].save_png(OUTPUT.path_join(label + "_phase_%03d.png" % roundi(phase_target * 100)))
		if label.contains("terminal_defeat"):
			for phase_target: float in [0.0, 0.67, 0.80]:
				var nearest: int = -1
				var difference: float = INF
				for index: int in range(samples.size()):
					for dying: Dictionary in samples[index].get("death_units", []):
						if str(dying.get("type", "")) != "player":
							continue
						var gap: float = absf(float(dying.get("death_progress", 0.0)) - phase_target)
						if gap < difference:
							nearest = index
							difference = gap
				if nearest >= 0:
					images[nearest].save_png(OUTPUT.path_join(label + "_collapse_%03d.png" % roundi(phase_target * 100)))
	_manifest["clips"].append({"label": label, "samples": samples, "phases_seen": phases.keys()})
	if label.contains("walk"):
		_assert(phases.has("walk"), "Real movement displays a walk cycle in " + label)
	if label.contains("melee") and not label.contains("reduced"):
		_assert(phases.has("attack"), "Real melee displays the sword cut in " + label)
	if label == "11a_targeted_aoe":
		_assert(not phases.has("attack"), "Targeted AoE does not trigger the weapon swing")

func _still(label: String) -> void:
	_assert(int(_snapshot().get("texture_id", 0)) == _texture_id, "New cutout remains active in " + label)
	if _capture:
		await RenderingServer.frame_post_draw
		_render_viewport.get_texture().get_image().save_png(OUTPUT.path_join(label + ".png"))

func _snapshot() -> Dictionary:
	return _board.call("protagonist_animation_snapshot")

func _player_pos() -> Vector2i:
	return (_instance.get("_combat_state") as Dictionary).get("player", {}).get("pos", Vector2i.ZERO)

func _assert_facing(index: int) -> void:
	var facings: Array[String] = ["front", "front", "rear", "rear"]
	var mirrors: Array[bool] = [false, true, false, true]
	var latest_clip: Dictionary = (_manifest["clips"] as Array)[-1]
	var saw_action: bool = false
	for sample: Dictionary in latest_clip["samples"]:
		var action: Dictionary = sample["animation"]
		if str(action["clip"]) in ["walk", "attack"]:
			saw_action = true
			_assert(action["facing"] == facings[index] and action["mirrored"] == mirrors[index], "Action facing matches " + _direction_name(index))
	var snapshot: Dictionary = _snapshot()
	_assert(saw_action and snapshot["facing"] == "front" and not snapshot["mirrored"] and snapshot["clip"] == "idle", "Action returns to default front idle after " + _direction_name(index))

func _direction_name(index: int) -> String:
	return ["southwest", "southeast", "northeast", "northwest"][index]

func _settle() -> void:
	for frame: int in range(8):
		await process_frame
	await create_timer(0.15).timeout

func _assert(condition: bool, message: String) -> void:
	if not condition and not _errors.has(message):
		_errors.append(message)
