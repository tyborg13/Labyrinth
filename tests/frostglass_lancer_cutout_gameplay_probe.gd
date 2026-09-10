extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const ContextualCombatTutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const InputRouter = preload("res://scripts/input_router.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const Cutout = preload("res://scripts/frostglass_lancer_cutout/renderer.gd")
const OUTPUT: String = "user://probes/frostglass_gameplay_v01"
const SIZE := Vector2i(1920, 1080)
var _errors: Array[String]
var _capture: bool = true
var _instance: Node
var _board: Control
var _render_viewport: SubViewport
var _manifest: Dictionary = {"size": [1920, 1080], "ui_scale": 1.0, "clips": [], "errors": []}
var _texture_id: int = 0

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_capture = not OS.get_cmdline_user_args().has("--logic-only")
	if not _capture:
		# Headless rendering never emits this signal. Advance the existing
		# first-frame barriers for logic checks only; native proof uses real draws.
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = SIZE
	root.size = SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	ProgressionStore.set_storage_path("user://frostglass_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://frostglass_probe_run.save")
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
	var directions: Array[Vector2i]
	directions.assign([Vector2i(0,1),Vector2i(1,0),Vector2i(0,-1),Vector2i(-1,0)])
	for index: int in range(directions.size()):
		var origin: Vector2i = [Vector2i(3,1),Vector2i(1,3),Vector2i(3,6),Vector2i(6,3)][index]
		await _fixture(origin + directions[index] * 5,origin,false,"glass_lunge")
		_texture_id = int(_snapshot().get("texture_id",0))
		_assert(_texture_id != 0,"Actual RunScene owns the Frostglass texture")
		await _record("idle_"+_direction_name(index),false,false,{},3.6)
		await _pass_and_compare("lunge_"+_direction_name(index),true)
		_check_direction(index)
	for action: String in ["spear_cast","frost_pin","refract_guard"]:
		for index: int in range(directions.size()):
			var origin := Vector2i(3,3)
			await _fixture(origin+directions[index]*(1 if action=="refract_guard" else 2),origin,false,action)
			_texture_id = int(_snapshot()["texture_id"])
			await _pass_and_compare(action+"_"+_direction_name(index),action!="refract_guard")
			if action != "refract_guard":
				_check_direction(index)
	for action: String in ["glass_lunge","spear_cast","frost_pin"]:
		await _fixture(Vector2i(3,5),Vector2i(3,3),true,action)
		_texture_id = int(_snapshot()["texture_id"])
		await _pass_and_compare("reduced_"+action,false)
		_assert(_snapshot()["clip"] == "rest","Reduced motion keeps the painted rest pose")
	await _fixture(Vector2i(3, 4), Vector2i(3, 3), false, "glass_lunge", 9)
	_texture_id = int(_snapshot()["texture_id"])
	await _instance.call("_on_card_pressed", 0)
	_instance.call("_on_board_tile_hovered", Vector2i(3, 3))
	await _settle()
	await _still("08_target_preview")
	_instance.call("_on_board_tile_clicked", Vector2i(3, 3))
	await _record("09_frostglass_death", true, false)
	_assert(_snapshot().is_empty(), "Dead Frostglass Lancer releases its cutout after the dissolve")
	var survivors: Array = ((_instance.get("_combat_state") as Dictionary)["enemies"] as Array).filter(func(enemy: Dictionary) -> bool: return int(enemy.get("hp", 0)) > 0)
	_assert(survivors.size() == 1 and int(survivors[0]["id"]) == 2, "The other Frostglass Lancer remains alive after the exact lethal hit")
	await _fixture(Vector2i(3, 4), Vector2i(3, 3))
	_texture_id = int(_snapshot()["texture_id"])
	var router: Node = root.get_node_or_null("InputRouter")
	if router != null:
		router.call("set_forced_state_for_test", InputRouter.MODALITY_CONTROLLER, InputRouter.FAMILY_STEAM_DECK)
		_instance.call("_refresh_controller_interface")
		await _instance.call("_on_card_pressed", 0)
		await _settle()
		await _still("10_controller_target")
		var before: Dictionary = (_instance.get("_combat_state") as Dictionary).duplicate(true)
		var cancel := InputEventAction.new()
		cancel.action = InputRouter.ACTION_CANCEL
		cancel.pressed = true
		_assert(await _instance.call("_handle_controller_input", cancel), "Controller Cancel remains handled")
		_assert(before == _instance.get("_combat_state"), "Controller cancel preserves combat state")
		router.call("set_forced_state_for_test", InputRouter.MODALITY_POINTER, InputRouter.FAMILY_STEAM_DECK)
		_instance.call("_refresh_controller_interface")
		await _settle()
		await _still("11_pointer_handoff")
		router.call("clear_forced_state_for_test")
	var around: Array[Vector2i]
	around.assign([Vector2i(3, 4), Vector2i(4, 3), Vector2i(3, 2), Vector2i(2, 3)])
	for index: int in range(around.size()):
		var destination: Vector2i = around[(index + 1) % around.size()]
		await _fixture(around[index], Vector2i(3, 3))
		_texture_id = int(_snapshot()["texture_id"])
		var before: Dictionary = _snapshot()
		await _instance.call("_on_board_tile_clicked", around[index])
		_instance.call("_on_board_tile_hovered", destination)
		await _settle()
		_assert(bool(_instance.get("_player_movement_selected")), "The actual player-selection input opens movement")
		_instance.call("_on_board_tile_clicked", destination)
		await _record("%02d_player_reposition_%s" % [12 + index, _direction_name((index + 1) % 4)], false, false, before)
		var after: Dictionary = _instance.get("_combat_state")
		_assert(after["player"]["pos"] == destination and int(after["player"]["hp"]) == 40, "Real two-tile player movement completes without damage")
		_assert((_manifest["clips"][-1]["phases_seen"] as Array).has("player_walk"), "Facing proof exercises actual animated player movement")
		var facing: Dictionary = Cutout.direction_for_delta(destination - Vector2i(3, 3))
		_assert(_snapshot()["clip"] == "idle" and _snapshot()["facing"] == facing["facing"] and _snapshot()["mirrored"] == facing["mirrored"], "Frostglass Lancer idle turns toward the player's completed destination")
		var player_idle: Dictionary = _board.call("protagonist_animation_snapshot")
		_assert(player_idle["clip"] == "idle" and player_idle["facing"] == "front" and not player_idle["mirrored"], "Player still returns to camera-facing idle")
	var portrait: String = str(_instance.TURN_ORDER_PORTRAITS.get("frostglass_lancer", ""))
	_assert(portrait == "res://assets/art/portraits/frostglass_lancer.png" and preload("res://scripts/asset_loader.gd").load_texture_source_first(portrait) != null, "Turn clock retains the dedicated Frostglass Lancer portrait")
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
	print("FROSTGLASS GAMEPLAY PROBE: " + ("PASS" if _errors.is_empty() else "FAIL"))
	quit(0 if _errors.is_empty() else 1)

func _pass_and_compare(label: String, require_attack: bool) -> void:
	var before: Dictionary = (_instance.get("_combat_state") as Dictionary).duplicate(true)
	var engine := CombatEngine.new()
	var expected: Dictionary = engine.advance_to_next_player_turn_with_steps(engine.finish_player_activation(before))["state"]
	_instance.call("_on_pass_turn_pressed")
	await _record(label,false,require_attack)
	var after: Dictionary = _instance.get("_combat_state")
	_assert(int(after["player"]["hp"]) == int(expected["player"]["hp"]),label+" applies the resolver damage exactly")
	_assert(after["enemies"][0]["pos"] == expected["enemies"][0]["pos"],label+" follows the resolved route")
	_assert(int(after["enemies"][0].get("block",0)) == int(expected["enemies"][0].get("block",0)),label+" preserves defense outcomes")
	_assert(int(after["initiative_clock"]) == int(expected["initiative_clock"]),label+" preserves initiative")
	if label.begins_with("lunge_"):
		_assert((_manifest["clips"][-1]["phases_seen"] as Array).has("walk"),"Glass Lunge uses the live travel cycle before thrust")

func _fixture(player_tile: Vector2i, enemy_tile: Vector2i, reduced: bool = false, intent_id: String = "glass_lunge", frostglass_hp: int = 12) -> void:
	_instance.call("_cancel_drag_play")
	_instance.call("_reset_card_resolution")
	var hand: Array = ["quick_stab", "brace", "sidestep_slash", "bone_dart", "patch_up"]
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	var layout: Dictionary = {"name": "Frostglass Lancer Combat Trial", "coord": Vector2i(4, 3), "type": "combat", "grid": grid,
		"player_start": player_tile, "enemies": [{"id": 1, "type": "frostglass_lancer", "pos": enemy_tile, "hp": frostglass_hp, "max_hp": 12, "block": 0}],
		"traps": [], "terrain": [], "element": "none"}
	layout["enemies"].append({"id": 2, "type": "frostglass_lancer", "pos": Vector2i(6, 6), "hp": 12, "max_hp": 12, "block": 0})
	var combat := CombatEngine.new()
	var state: Dictionary = combat.create_combat(260908, layout, {"hp": 40, "max_hp": 40, "deck_cards": hand.duplicate(), "relics": [], "hand_size": 5, "heal_bonus": 0})
	for intent: Dictionary in GameData.enemy_def("frostglass_lancer")["intents"]:
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
	var other: Dictionary = _board.call("frostglass_animation_snapshot","enemy_2")
	_assert(other.get("texture_id",0) != _snapshot().get("texture_id",0) and int(other.get("rig_count",0)) == 2,"Each actor retains its own front/rear rigs")

func _record(label: String, allow_death: bool, require_attack: bool, observer_before: Dictionary = {}, minimum_seconds: float = 0.0) -> void:
	if not _capture:
		minimum_seconds = 0.0
	var started: int = Time.get_ticks_usec()
	var next_capture: int = started
	var finish: int = 0
	var phases: Dictionary = {}
	var samples: Array[Dictionary]
	var images: Array[Image]
	var previous_support: Dictionary = {}
	var max_drift: float = 0.0
	while Time.get_ticks_usec() - started < 12000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		if not bool(_instance.get("_animation_lock")) and finish == 0:
			finish = now
		var snapshot: Dictionary = _snapshot()
		_assert((allow_death and snapshot.is_empty()) or int(snapshot.get("texture_id", 0)) == _texture_id, "One Frostglass Lancer texture remains live through " + label)
		var presentation: Dictionary = _board.get("presentation")
		var effect: Dictionary = presentation.get("effect", {})
		var player_motion: Dictionary = presentation.get("protagonist_motion", {})
		if not observer_before.is_empty() and str(player_motion.get("clip", "")) == "walk":
			phases["player_walk"] = true
			_assert(snapshot["facing"] == observer_before["facing"] and snapshot["mirrored"] == observer_before["mirrored"], "Frostglass Lancer waits until player movement finishes before turning")
		phases[str(snapshot.get("clip", "gone"))] = true
		var display_state: Dictionary = _board.get("combat_state")
		var unit: Dictionary = {}
		for candidate: Dictionary in _board.call("_visible_units"):
			if str(candidate.get("key", "")) == "enemy_1":
				unit = candidate
		if str(snapshot.get("clip", "")) in ["thrust","cast","pin"]:
			_assert((_board.call("_unit_center", unit) as Vector2).is_equal_approx(_board.call("world_position_for_tile", unit["pos"])), "Frostglass Lancer attack keeps its planted stance on its actual tile")
			var progress: float = float(presentation.get("effect_progress", 0.0))
			var boundary: float = float(_instance.call("_attack_feedback_start_progress", effect))
			if effect.is_empty():
				_assert(int(display_state["player"]["hp"]) == 40,"Preparation precedes visible damage")
			elif int(effect.get("hp_loss",0)) > 0:
				_assert((int(display_state["player"]["hp"]) == 40) == (progress < boundary),"Visible damage changes at the existing contact boundary")
		if str(snapshot.get("clip", "")) == "walk" and not unit.is_empty():
			var support: Dictionary = _support_points(unit, snapshot)
			if previous_support.get("view", "") == support["view"]:
				for foot: String in ["foot_r", "foot_l"]:
					if support.has(foot) and previous_support.has(foot) and float(support[foot]["cycle"]) >= float(previous_support[foot]["cycle"]):
						var drift: float = (support[foot]["world"] as Vector2).distance_to(previous_support[foot]["world"])
						max_drift = maxf(max_drift, drift)
			previous_support = support
		else:
			previous_support = {}
		if now >= next_capture:
			next_capture = now + 33333
			samples.append({"seconds": float(now - started) / 1000000.0, "animation": snapshot,
				"player_motion": player_motion.duplicate(true), "effect": effect.duplicate(true), "effect_progress": float(presentation.get("effect_progress", 0.0)),
				"player_hp": int(display_state.get("player", {}).get("hp", 0)),
				"death_units": presentation.get("death_animation_units", []).duplicate(true)})
			if _capture:
				await RenderingServer.frame_post_draw
				images.append(_render_viewport.get_texture().get_image())
		if finish > 0 and now - finish > 250000 and float(now - started) / 1000000.0 >= minimum_seconds:
			break
	_assert(not bool(_instance.get("_animation_lock")), "Input returns after " + label)
	_assert(max_drift < 0.2, "Native world-space support feet stay planted through " + label)
	if require_attack:
		_assert(phases.has("thrust") or phases.has("cast") or phases.has("pin"), "Actual End Turn plays the Frostglass Lancer weapon action in " + label)
	var folder: String = OUTPUT.path_join(label)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for index: int in range(images.size()):
		images[index].save_jpg(folder.path_join("frame_%04d.jpg" % index), 0.95)
	if not images.is_empty():
		images[-1].save_png(OUTPUT.path_join(label + ".png"))
		for target: float in [0.32, 0.5, 0.65]:
			var nearest: int = -1
			var difference: float = INF
			for index: int in range(samples.size()):
				if not str(samples[index]["animation"].get("clip", "")) in ["thrust","cast","pin"]:
					continue
				var gap: float = absf(float(samples[index]["animation"]["phase"]) - target)
				if gap < difference:
					difference = gap
					nearest = index
			if nearest >= 0:
				images[nearest].save_png(OUTPUT.path_join(label + "_attack_%03d.png" % roundi(target * 100)))
		if allow_death:
			for target: float in [0.0, 0.5, 0.8]:
				var nearest: int = -1
				var difference: float = INF
				for index: int in range(samples.size()):
					for dying: Dictionary in samples[index]["death_units"]:
						if str(dying.get("key", "")) != "enemy_1":
							continue
						var gap: float = absf(float(dying.get("death_progress", 0.0)) - target)
						if gap < difference:
							difference = gap
							nearest = index
				if nearest >= 0:
					images[nearest].save_png(OUTPUT.path_join(label + "_dissolve_%03d.png" % roundi(target * 100)))
	print("FROSTGLASS CLIP "+label+": "+str(phases.keys())+" errors="+str(_errors))
	_manifest["clips"].append({"label": label, "phases_seen": phases.keys(), "max_support_drift_px": max_drift, "samples": samples})

func _support_points(unit: Dictionary, snapshot: Dictionary) -> Dictionary:
	var renderer: Node = (_board.get("_frostglass_renderers") as Dictionary)["enemy_1"]
	var rig: Node2D = renderer.get("rigs")[snapshot["facing"]]
	var logical: Rect2 = _board.call("_unit_draw_rect", unit)
	var result: Dictionary = {"view": str(snapshot["facing"]) + str(snapshot["mirrored"])}
	for foot: String in ["foot_r", "foot_l"]:
		var state: Dictionary = Cutout.Motion.walk_foot_state(float(snapshot["phase"]), foot, rig.layout, str(snapshot["facing"]))
		if not bool(state["contact"]):
			continue
		var offset: Vector2 = Cutout.Motion.landmark(rig.layout,"sole_"+foot.trim_prefix("foot_")) - Cutout.Motion.point(rig.layout, foot)
		var canvas_point: Vector2 = (rig.bones[foot] as Node2D).global_transform * offset
		result[foot] = {"world": logical.position + (canvas_point - Cutout.SOURCE_OFFSET) * logical.size / Cutout.SOURCE_SIZE, "cycle": state["cycle_phase"]}
	return result

func _check_direction(index: int) -> void:
	var facings: Array[String]
	facings.assign(["front", "front", "rear", "rear"])
	var mirrors: Array[bool]
	mirrors.assign([false, true, false, true])
	for sample: Dictionary in _manifest["clips"][-1]["samples"]:
		var animation: Dictionary = sample["animation"]
		if str(animation.get("clip", "")) in ["walk","thrust","cast","pin"]:
			_assert(animation["facing"] == facings[index] and animation["mirrored"] == mirrors[index], "Frostglass Lancer movement and melee face " + _direction_name(index))
	_assert(_snapshot()["facing"] == facings[index] and _snapshot()["mirrored"] == mirrors[index], "Idle retains the completed direction")

func _snapshot() -> Dictionary:
	return _board.call("frostglass_animation_snapshot", "enemy_1")

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
