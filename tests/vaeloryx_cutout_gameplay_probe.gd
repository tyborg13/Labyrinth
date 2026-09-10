extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const ContextualCombatTutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const InputRouter = preload("res://scripts/input_router.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const Cutout = preload("res://scripts/vaeloryx_cutout/renderer.gd")
const OUTPUT: String = "user://probes/vaeloryx_gameplay_v3"
const SIZE := Vector2i(1920, 1080)
var _errors: Array[String]
var _capture: bool = true
var _instance: Node
var _board: Control
var _render_viewport: SubViewport
var _manifest: Dictionary = {"size": [1920, 1080], "ui_scale": 1.0, "grid_size": [9, 9], "clips": [], "errors": []}
var _texture_id: int = 0
var _other_texture: int = 0
const Analytics = preload("res://scripts/analytics_store.gd")

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_capture = not OS.get_cmdline_user_args().has("--logic-only")
	_manifest["capture_mode"] = "native" if _capture else "logic_only"
	if not _capture:
		# Headless logic audit only: release the production draw-boundary waits.
		# Native proof uses real renderer signals and never enters this branch.
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = SIZE
	root.size = SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	Analytics.set_storage_dir(OUTPUT.path_join("analytics"))
	ProgressionStore.set_storage_path("user://vaeloryx_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://vaeloryx_probe_run.save")
	ProgressionStore.clear_saved_run()
	_render_viewport = SubViewport.new()
	_render_viewport.size = SIZE
	_render_viewport.disable_3d = true
	_render_viewport.world_2d = World2D.new()
	_render_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_render_viewport)
	_instance = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_render_viewport.add_child(_instance)
	await _settle()
	_board = _instance.get("board_view") as Control
	var dive_starts: Array[Vector2i]
	dive_starts.assign([Vector2i(4, 7), Vector2i(7, 5), Vector2i(5, 1), Vector2i(1, 4)])
	var gale_starts: Array[Vector2i]
	gale_starts.assign([Vector2i(4, 6), Vector2i(6, 5), Vector2i(5, 3), Vector2i(3, 4)])
	for index: int in range(4):
		await _fixture(dive_starts[index], Vector2i(4, 4))
		await _record("idle_" + _direction_name(index), false, "", {}, 4.0)
		await _turn("dive_" + _direction_name(index), "dive")
		_check_idle_facing()
	for intent: String in ["hollow_gale", "skyhook", "eye_of_storm"]:
		for index: int in range(4):
			var start: Vector2i = gale_starts[index] if intent == "hollow_gale" else dive_starts[index]
			await _fixture(start, Vector2i(4, 4), false, intent)
			await _turn(intent + "_" + _direction_name(index), {"hollow_gale": "gale", "skyhook": "pull", "eye_of_storm": "guard"}[intent])
			if intent == "hollow_gale":
				_assert((_instance.get("_combat_state") as Dictionary)["player"]["pos"] != start, "Hollow Gale visibly pushes in every direction")
			_check_idle_facing()
	await _fixture(Vector2i(7, 7), Vector2i(4, 4), false, "hollow_gale")
	await _turn("hollow_gale_wall_stop", "gale")
	_assert((_instance.get("_combat_state") as Dictionary)["player"]["pos"] == Vector2i(7, 7), "Arena corner stops Hollow Gale displacement")
	await _fixture(Vector2i(4, 7), Vector2i(4, 4), true)
	await _turn("reduced_dive", "")
	_assert(_snapshot()["clip"] == "rest", "Reduced motion remains still")
	await _fixture(Vector2i(4, 6), Vector2i(4, 4), false, "razor_dive", 9)
	await _instance.call("_on_card_pressed", 0)
	for tile: Vector2i in [Vector2i(4, 4), Vector2i(5, 4), Vector2i(4, 5), Vector2i(5, 5)]:
		_instance.call("_on_board_tile_hovered", tile)
		await _settle()
		await _still("target_footprint_%d_%d" % [tile.x, tile.y])
	_instance.call("_on_board_tile_clicked", Vector2i(4, 5))
	await _record("death", true)
	_assert(_snapshot().is_empty(), "Dead dragon releases the completed dissolve")
	_assert(int(_board.call("vaeloryx_animation_snapshot", "enemy_2")["texture_id"]) == _other_texture, "Other dragon survives without texture replacement")
	_assert(str((_instance.get("_run_state") as Dictionary)["mode"]) == "combat", "Another living boss prevents premature room outcome")
	await _fixture(Vector2i(4, 6), Vector2i(4, 4))
	var router: Node = root.get_node_or_null("InputRouter")
	_assert(router != null, "Input router exists")
	if router != null:
		router.call("set_forced_state_for_test", InputRouter.MODALITY_CONTROLLER, InputRouter.FAMILY_STEAM_DECK)
		_instance.call("_refresh_controller_interface")
		await _instance.call("_on_card_pressed", 0)
		await _settle()
		await _still("controller_target")
		var before: Dictionary = (_instance.get("_combat_state") as Dictionary).duplicate(true)
		var cancel := InputEventAction.new()
		cancel.action = InputRouter.ACTION_CANCEL
		cancel.pressed = true
		_assert(await _instance.call("_handle_controller_input", cancel), "Controller Cancel is handled")
		_assert(before == _instance.get("_combat_state"), "Controller cancel preserves state")
		router.call("set_forced_state_for_test", InputRouter.MODALITY_POINTER, InputRouter.FAMILY_STEAM_DECK)
		_instance.call("_refresh_controller_interface")
		await _settle()
		await _still("pointer_handoff")
		router.call("clear_forced_state_for_test")
	var starts: Array[Vector2i]
	starts.assign([Vector2i(5, 6), Vector2i(6, 4), Vector2i(4, 3), Vector2i(3, 5)])
	var ends: Array[Vector2i]
	ends.assign([Vector2i(6, 5), Vector2i(5, 3), Vector2i(3, 4), Vector2i(4, 6)])
	for index: int in range(4):
		await _fixture(starts[index], Vector2i(4, 4))
		var before: Dictionary = _snapshot()
		before["other"] = _board.call("vaeloryx_animation_snapshot", "enemy_2")
		await _instance.call("_on_board_tile_clicked", starts[index])
		_instance.call("_on_board_tile_hovered", ends[index])
		await _settle()
		_assert(bool(_instance.get("_player_movement_selected")), "Actual player selection opens movement")
		_instance.call("_on_board_tile_clicked", ends[index])
		await _record("player_reposition_" + _direction_name((index + 1) % 4), false, "", before)
		var after: Dictionary = _instance.get("_combat_state")
		_assert(after["player"]["pos"] == ends[index] and int(after["player"]["hp"]) == 100, "Two-tile player movement completes without damage")
		_assert((_manifest["clips"][-1]["phases_seen"] as Array).has("player_walk"), "Facing proof exercises actual player movement")
		_check_idle_facing()
		var player_idle: Dictionary = _board.call("protagonist_animation_snapshot")
		_assert(player_idle["clip"] == "idle" and player_idle["facing"] == "front" and not player_idle["mirrored"], "Protagonist returns to camera-facing idle")
	_assert(str(_instance.TURN_ORDER_PORTRAITS.get("vaeloryx", "")) == "res://assets/art/portraits/vaeloryx.png", "Dedicated portrait retained")
	_manifest["errors"] = _errors
	_manifest["ok"] = _errors.is_empty()
	var file := FileAccess.open(OUTPUT.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_manifest, "\t"))
	file.close()
	_instance.queue_free()
	_render_viewport.queue_free()
	await process_frame
	for error: String in _errors:
		push_error(error)
	print("Saved " + ProjectSettings.globalize_path(OUTPUT))
	print("VAELORYX GAMEPLAY PROBE: " + ("PASS" if _errors.is_empty() else "FAIL"))
	quit(0 if _errors.is_empty() else 1)

func _turn(label: String, action: String) -> void:
	var before: Dictionary = (_instance.get("_combat_state") as Dictionary).duplicate(true)
	var engine := CombatEngine.new()
	var phase: Dictionary = engine.advance_to_next_player_turn_with_steps(engine.finish_player_activation(before))
	var expected: Dictionary = phase["state"]
	var prior_events: int = Analytics.load_all_events().size()
	var expected_events: Array = _instance.call("_analytics_enemy_action_events", phase, {})
	_instance.call("_on_pass_turn_pressed")
	await _record(label, false, action)
	var after: Dictionary = _instance.get("_combat_state")
	for field: String in ["player", "enemies", "initiative_clock", "turn_queue", "terrain", "traps", "surfaces", "outcome"]:
		_assert(after.get(field) == expected.get(field), label + " exact resolved " + field)
	var action_events: Array[Dictionary]
	var all_events: Array[Dictionary] = Analytics.load_all_events()
	for index: int in range(prior_events, all_events.size()):
		if str(all_events[index]["event_type"]) == "enemy_action_resolved":
			action_events.append(all_events[index])
	_assert(action_events.size() == expected_events.size(), label + " analytics action count without duplicates")
	for index: int in range(mini(action_events.size(), expected_events.size())):
		for field: String in ["action_type", "presentation_kind", "intent_id", "actor_key", "path_steps"]:
			_assert(action_events[index]["payload"][field] == expected_events[index]["payload"][field], label + " analytics " + field)
	_manifest["clips"][-1]["outcome"] = {"before": before, "expected": expected, "actual": after.duplicate(true), "expected_steps": phase["steps"], "analytics_events": action_events}

func _check_idle_facing() -> void:
	var state: Dictionary = _instance.get("_combat_state")
	var player: Vector2i = state["player"]["pos"]
	for enemy: Dictionary in state["enemies"]:
		if str(enemy["type"]) != "vaeloryx" or int(enemy["hp"]) <= 0:
			continue
		var direction: Dictionary = Cutout.direction_for_delta(player * 2 - ((enemy["pos"] as Vector2i) * 2 + Vector2i.ONE))
		var snapshot: Dictionary = _board.call("vaeloryx_animation_snapshot", "enemy_%d" % int(enemy["id"]))
		_assert(snapshot["clip"] in ["idle", "rest"] and snapshot["facing"] == direction["facing"] and snapshot["mirrored"] == direction["mirrored"], "Both dragons return to player-facing idle")

func _fixture(player_tile: Vector2i, enemy_tile: Vector2i, reduced: bool = false, intent_id: String = "razor_dive", warden_hp: int = 58) -> void:
	_instance.call("_cancel_drag_play")
	_instance.call("_reset_card_resolution")
	var hand: Array = ["quick_stab", "brace", "sidestep_slash", "bone_dart", "patch_up"]
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if x == 0 or y == 0 or x == 8 or y == 8 else "stone")
		grid.append(row)
	var layout: Dictionary = {"name": "The Hollow Gale Trial", "coord": Vector2i(4, 3), "type": "boss", "boss_id": "vaeloryx", "grid": grid,
		"player_start": player_tile, "enemies": [{"id": 1, "type": "vaeloryx", "pos": enemy_tile, "hp": warden_hp, "max_hp": 58, "block": 0}],
		"traps": [], "terrain": [], "element": "air"}
	layout["enemies"].append({"id": 2, "type": "vaeloryx", "pos": Vector2i(1, 6), "hp": 58, "max_hp": 58, "block": 0})
	layout["enemies"].append({"id": 3, "type": "crawler", "pos": Vector2i(2, 1), "hp": 9, "max_hp": 9})
	layout["enemies"].append({"id": 4, "type": "warden", "pos": Vector2i(6, 1), "hp": 18, "max_hp": 18})
	var combat := CombatEngine.new()
	var state: Dictionary = combat.create_combat(260908, layout, {"hp": 100, "max_hp": 100, "deck_cards": hand.duplicate(), "relics": [], "hand_size": 5, "heal_bonus": 0})
	for intent: Dictionary in GameData.enemy_def("vaeloryx")["intents"]:
		if str(intent["id"]) == intent_id:
			state["enemies"][0]["intent"] = intent.duplicate(true)
	for entry: Dictionary in state["turn_queue"]:
		entry["time"] = 1 if int(entry.get("enemy_id", -1)) == 1 else 100
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
	_texture_id = int(_snapshot()["texture_id"])
	_other_texture = int(_board.call("vaeloryx_animation_snapshot", "enemy_2")["texture_id"])
	_assert(_texture_id != _other_texture, "Two independent persistent dragon textures")
	_assert(not (_board.call("warden_animation_snapshot", "enemy_4") as Dictionary).is_empty(), "Existing Warden coexists")

func _record(label: String, allow_death: bool = false, required_action: String = "", observer_before: Dictionary = {}, minimum_seconds: float = 0.0) -> void:
	var started: int = Time.get_ticks_usec()
	var next_capture: int = started
	var finish: int = 0
	var phases: Dictionary = {}
	var samples: Array[Dictionary]
	var images: Array[Image]
	while Time.get_ticks_usec() - started < 15000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		if not bool(_instance.get("_animation_lock")) and finish == 0:
			finish = now
		var snapshot: Dictionary = _snapshot()
		_assert((allow_death and snapshot.is_empty()) or int(snapshot.get("texture_id", 0)) == _texture_id, "Persistent dragon texture: " + label)
		var presentation: Dictionary = _board.get("presentation")
		var effect: Dictionary = presentation.get("effect", {})
		var player_motion: Dictionary = presentation.get("protagonist_motion", {})
		var other: Dictionary = _board.call("vaeloryx_animation_snapshot", "enemy_2")
		_assert(int(other.get("texture_id", 0)) == _other_texture and str(other.get("clip", "")) in ["idle", "rest"], "Second dragon independent: " + label)
		if not observer_before.is_empty() and str(player_motion.get("clip", "")) == "walk":
			phases["player_walk"] = true
			_assert(snapshot["facing"] == observer_before["facing"] and snapshot["mirrored"] == observer_before["mirrored"], "Observer waits for completed player movement")
			_assert(other["facing"] == observer_before["other"]["facing"] and other["mirrored"] == observer_before["other"]["mirrored"], "Second observer waits for completed movement")
		phases[str(snapshot.get("clip", "gone"))] = true
		var display: Dictionary = _board.get("combat_state")
		if str(snapshot.get("clip", "")) in ["dive", "gale", "pull"]:
			var progress: float = float(presentation.get("effect_progress", 0.0))
			var boundary: float = float(_instance.call("_attack_feedback_start_progress", effect))
			_assert((int(display["player"]["hp"]) == 100) == (progress < boundary), "Damage display changes at existing contact: " + label)
		if now >= next_capture:
			next_capture = now + 33333
			samples.append({"seconds": float(now - started) / 1000000.0, "animation": snapshot, "other": other,
				"player_motion": player_motion.duplicate(true), "effect": effect.duplicate(true), "effect_progress": float(presentation.get("effect_progress", 0.0)),
				"player_hp": int(display.get("player", {}).get("hp", 0)), "death_units": presentation.get("death_animation_units", []).duplicate(true)})
			if _capture:
				await RenderingServer.frame_post_draw
				images.append(_render_viewport.get_texture().get_image())
		if finish > 0 and now - finish > 250000 and (not _capture or float(now - started) / 1000000.0 >= minimum_seconds):
			break
	_assert(not bool(_instance.get("_animation_lock")), "Input returns after " + label)
	if not required_action.is_empty():
		_assert(phases.has(required_action), "Real Pass triggers " + required_action + " in " + label)
	var folder: String = OUTPUT.path_join(label)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for index: int in range(images.size()):
		images[index].save_jpg(folder.path_join("frame_%04d.jpg" % index), 0.93)
	if not images.is_empty():
		images[-1].save_png(OUTPUT.path_join(label + ".png"))
		for target: float in [0.28, 0.42, 0.72]:
			var nearest: int = -1
			var difference: float = INF
			for index: int in range(samples.size()):
				if str(samples[index]["animation"].get("clip", "")) not in ["dive", "gale", "pull", "guard"]:
					continue
				var gap: float = absf(float(samples[index]["animation"]["phase"]) - target)
				if gap < difference:
					difference = gap
					nearest = index
			if nearest >= 0:
				images[nearest].save_png(OUTPUT.path_join(label + "_action_%03d.png" % roundi(target * 100)))
		if allow_death:
			for index: int in range(samples.size()):
				if not (samples[index]["death_units"] as Array).is_empty():
					images[index].save_png(OUTPUT.path_join(label + "_dissolve_%03d.png" % index))
	_manifest["clips"].append({"label": label, "phases_seen": phases.keys(), "samples": samples})

func _snapshot() -> Dictionary:
	return _board.call("vaeloryx_animation_snapshot", "enemy_1")

func _still(label: String) -> void:
	if not _capture:
		return
	await RenderingServer.frame_post_draw
	_render_viewport.get_texture().get_image().save_png(OUTPUT.path_join(label + ".png"))

func _direction_name(index: int) -> String:
	return ["southwest", "southeast", "northeast", "northwest"][index]

func _settle() -> void:
	for frame: int in range(8):
		await process_frame
	await create_timer(0.15).timeout

func _assert(condition: bool, message: String) -> void:
	if not condition and not _errors.has(message):
		_errors.append(message)
