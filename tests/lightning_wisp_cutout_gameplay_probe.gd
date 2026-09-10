extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const ContextualCombatTutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const InputRouter = preload("res://scripts/input_router.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const Cutout = preload("res://scripts/lightning_wisp_cutout/renderer.gd")
const OUTPUT: String = "user://probes/lightning_wisp_gameplay_v1"
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
	call_deferred("_run")

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = SIZE
	root.size = SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	ProgressionStore.set_storage_path("user://lightning_wisp_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://lightning_wisp_probe_run.save")
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
	directions.assign([Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)])
	for index: int in range(directions.size()):
		var origin := Vector2i(3, 3)
		await _fixture(origin + directions[index] * 2, origin)
		_texture_id = int(_snapshot().get("texture_id", 0))
		_assert(_texture_id != 0, "Actual RunScene owns the Lightning Wisp texture")
		await _record("00_idle_" + _direction_name(index), false, false, {}, 3.2)
		var before: Dictionary = (_instance.get("_combat_state") as Dictionary).duplicate(true)
		var engine := CombatEngine.new()
		var expected: Dictionary = engine.advance_to_next_player_turn_with_steps(engine.finish_player_activation(before))["state"]
		_instance.call("_on_pass_turn_pressed")
		await _record("%02d_spark_dart_%s" % [index + 1, _direction_name(index)], false, true)
		var after: Dictionary = _instance.get("_combat_state")
		_assert(int(after["player"]["hp"]) == 37 and int(after["player"]["hp"]) == int(expected["player"]["hp"]), "Spark Dart applies exactly three damage once")
		_assert(after["enemies"][0]["pos"] == origin + directions[index] and after["enemies"][0]["pos"] == expected["enemies"][0]["pos"], "Spark Dart follows the resolved one-tile route")
		_assert(int(after["initiative_clock"]) == int(expected["initiative_clock"]), "Animation preserves initiative resolution")
		_check_direction(index)
	for intent: String in ["static_lash", "blinding_arc"]:
		for index: int in range(directions.size()):
			var origin := Vector2i(3, 3)
			await _fixture(origin + directions[index] * 2, origin, false, intent)
			_texture_id = int(_snapshot()["texture_id"])
			var before: Dictionary = (_instance.get("_combat_state") as Dictionary).duplicate(true)
			var engine := CombatEngine.new()
			var expected: Dictionary = engine.advance_to_next_player_turn_with_steps(engine.finish_player_activation(before))["state"]
			_instance.call("_on_pass_turn_pressed")
			await _record(intent + "_" + _direction_name(index), false, true)
			var after: Dictionary = _instance.get("_combat_state")
			_assert(after["player"]["hp"] == expected["player"]["hp"] and after["enemies"][0]["pos"] == expected["enemies"][0]["pos"], intent + " preserves its resolved damage and route")
			_assert(after.get("surfaces", {}) == expected.get("surfaces", {}), intent + " preserves exactly the resolver's electrical surfaces")
			_assert(int(after["initiative_clock"]) == int(expected["initiative_clock"]), intent + " retains its initiative result")
			var final_delta: Vector2i = after["player"]["pos"] - after["enemies"][0]["pos"]
			var expected_facing: Dictionary = Cutout.direction_for_delta(final_delta)
			_assert(_snapshot()["clip"] == "idle" and _snapshot()["facing"] == expected_facing["facing"] and _snapshot()["mirrored"] == expected_facing["mirrored"], "Casting recovers toward the resolved target")
	await _fixture(Vector2i(3, 5), Vector2i(3, 3), true)
	_texture_id = int(_snapshot()["texture_id"])
	_instance.call("_on_pass_turn_pressed")
	await _record("06_reduced_spark_dart", false, false)
	_assert(int((_instance.get("_combat_state") as Dictionary)["player"]["hp"]) == 37, "Reduced motion preserves the same movement and damage")
	_assert(_snapshot()["clip"] == "rest", "Reduced motion keeps the new Lightning Wisp still")
	await _fixture(Vector2i(3, 4), Vector2i(3, 3), false, "spark_dart", 6)
	_texture_id = int(_snapshot()["texture_id"])
	await _instance.call("_on_card_pressed", 0)
	_instance.call("_on_board_tile_hovered", Vector2i(3, 3))
	await _settle()
	await _still("08_target_preview")
	_instance.call("_on_board_tile_clicked", Vector2i(3, 3))
	await _record("09_lightning_wisp_death", true, false)
	_assert(_snapshot().is_empty(), "Dead Lightning Wisp releases its cutout after the dissolve")
	var survivors: Array = ((_instance.get("_combat_state") as Dictionary)["enemies"] as Array).filter(func(enemy: Dictionary) -> bool: return int(enemy.get("hp", 0)) > 0)
	_assert(survivors.size() == 1 and int(survivors[0]["id"]) == 2, "The other Lightning Wisp remains alive after the exact lethal hit")
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
		_assert(_snapshot()["clip"] == "idle" and _snapshot()["facing"] == facing["facing"] and _snapshot()["mirrored"] == facing["mirrored"], "Lightning Wisp idle turns toward the player's completed destination")
		var player_idle: Dictionary = _board.call("protagonist_animation_snapshot")
		_assert(player_idle["clip"] == "idle" and player_idle["facing"] == "front" and not player_idle["mirrored"], "Player still returns to camera-facing idle")
	await _additional_intent_checks()
	await _summon_check()
	var portrait: String = str(_instance.TURN_ORDER_PORTRAITS.get("lightning_wisp", ""))
	_assert(portrait == "res://assets/art/portraits/lightning_wisp.png" and preload("res://scripts/asset_loader.gd").load_texture_source_first(portrait) != null, "Turn clock retains the dedicated Stone Lightning Wisp portrait")
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
	print("LIGHTNING WISP GAMEPLAY PROBE: " + ("PASS" if _errors.is_empty() else "FAIL"))
	quit(0 if _errors.is_empty() else 1)

func _fixture(player_tile: Vector2i, enemy_tile: Vector2i, reduced: bool = false, intent_id: String = "spark_dart", lightning_wisp_hp: int = 6, enemy_type: String = "lightning_wisp") -> void:
	_instance.call("_cancel_drag_play")
	_instance.call("_reset_card_resolution")
	var hand: Array = ["quick_stab", "brace", "sidestep_slash", "bone_dart", "patch_up"]
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	var layout: Dictionary = {"name": "Lightning Wisp Combat Trial", "coord": Vector2i(4, 3), "type": "combat", "grid": grid,
		"player_start": player_tile, "enemies": [{"id": 1, "type": enemy_type, "pos": enemy_tile, "hp": lightning_wisp_hp, "max_hp": int(GameData.enemy_def(enemy_type)["max_hp"]), "block": 0}],
		"traps": [], "terrain": [], "element": "none"}
	layout["enemies"].append({"id": 2, "type": "lightning_wisp", "pos": Vector2i(6, 6), "hp": 6, "max_hp": 6, "block": 0})
	var combat := CombatEngine.new()
	var state: Dictionary = combat.create_combat(260908, layout, {"hp": 40, "max_hp": 40, "deck_cards": hand.duplicate(), "relics": [], "hand_size": 5, "heal_bonus": 0})
	for intent: Dictionary in GameData.enemy_def(enemy_type)["intents"]:
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

func _record(label: String, allow_death: bool, require_attack: bool, observer_before: Dictionary = {}, minimum_seconds: float = 0.0) -> void:
	var started: int = Time.get_ticks_usec()
	var next_capture: int = started
	var finish: int = 0
	var phases: Dictionary = {}
	var samples: Array[Dictionary]
	var images: Array[Image]
	while Time.get_ticks_usec() - started < 12000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		if not bool(_instance.get("_animation_lock")) and finish == 0:
			finish = now
		var snapshot: Dictionary = _snapshot()
		_assert((allow_death and snapshot.is_empty()) or int(snapshot.get("texture_id", 0)) == _texture_id, "One Lightning Wisp texture remains live through " + label)
		var presentation: Dictionary = _board.get("presentation")
		var effect: Dictionary = presentation.get("effect", {})
		var player_motion: Dictionary = presentation.get("protagonist_motion", {})
		if not observer_before.is_empty() and str(player_motion.get("clip", "")) == "walk":
			phases["player_walk"] = true
			_assert(snapshot["facing"] == observer_before["facing"] and snapshot["mirrored"] == observer_before["mirrored"], "Lightning Wisp waits until player movement finishes before turning")
		phases[str(snapshot.get("clip", "gone"))] = true
		if not effect.is_empty():
			phases["effect_" + str(effect.get("kind", ""))] = true
		var display_state: Dictionary = _board.get("combat_state")
		var unit: Dictionary = {}
		for candidate: Dictionary in _board.call("_visible_units"):
			if str(candidate.get("key", "")) == "enemy_1":
				unit = candidate
		if str(snapshot.get("clip", "")) in ["attack", "cast"] and not effect.is_empty():
			_assert((_board.call("_unit_center", unit) as Vector2).is_equal_approx(_board.call("world_position_for_tile", unit["pos"])), "Lightning Wisp attacks keep logical hover registration on its actual tile")
			var progress: float = float(presentation.get("effect_progress", 0.0))
			var boundary: float = float(_instance.call("_attack_feedback_start_progress", effect))
			_assert((int(display_state["player"]["hp"]) == 40) == (progress < boundary), "Visible damage changes at the existing contact boundary")
		if not unit.is_empty():
			var logical: Rect2 = _board.call("_unit_draw_rect", unit)
			var padded: Rect2 = _board.call("_unit_texture_draw_rect", unit, _board.call("_unit_center", unit))
			if not bool(unit.get("death_animation", false)):
				_assert((padded.position + padded.size * Cutout.SOURCE_OFFSET / Vector2(Cutout.CANVAS_SIZE)).distance_to(logical.position) < .001, "Full canvas retains the logical hover/HUD anchor through " + label)
		var other: Dictionary = _board.call("lightning_wisp_animation_snapshot", "enemy_2")
		_assert(other.get("clip", "") in ["idle", "rest"] and int(other.get("texture_id", 0)) != _texture_id, "A second Wisp retains independent idle and texture through " + label)
		if now >= next_capture:
			next_capture = now + 33333
			samples.append({"seconds": float(now - started) / 1000000.0, "animation": snapshot,
				"player_motion": player_motion.duplicate(true), "effect": effect.duplicate(true), "effect_progress": float(presentation.get("effect_progress", 0.0)),
				"player_hp": int(display_state.get("player", {}).get("hp", 0)),
				"player_shock": int(display_state.get("player", {}).get("shock", 0)),
				"floating_texts": (presentation.get("floating_texts", []) as Array).duplicate(true),
				"illusions": (display_state.get("illusions", []) as Array).duplicate(true),
				"death_units": presentation.get("death_animation_units", []).duplicate(true)})
			await RenderingServer.frame_post_draw
			images.append(_render_viewport.get_texture().get_image())
		if finish > 0 and now - finish > 250000 and float(now - started) / 1000000.0 >= minimum_seconds:
			break
	_assert(not bool(_instance.get("_animation_lock")), "Input returns after " + label)
	if label.begins_with("static_lash") or label.begins_with("blinding_arc"):
		_assert(phases.has("cast") and phases.has("effect_ranged") and not phases.has("effect_melee"), "Electrical intents retain ranged outcomes and gathered release")
	if require_attack:
		_assert(phases.has("attack") or phases.has("cast"), "Actual End Turn plays the resolved Lightning Wisp attack in " + label)
	var folder: String = OUTPUT.path_join(label)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for index: int in range(images.size()):
		images[index].save_jpg(folder.path_join("frame_%04d.jpg" % index), 0.95)
	if not images.is_empty():
		images[-1].save_png(OUTPUT.path_join(label + ".png"))
		for target: float in [0.28, 0.42, 0.5, 0.75]:
			var nearest: int = -1
			var difference: float = INF
			for index: int in range(samples.size()):
				if str(samples[index]["animation"].get("clip", "")) not in ["attack", "cast"]:
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
	_manifest["clips"].append({"label": label, "phases_seen": phases.keys(), "hover_registration": "logical source remains registered; no ground contact for hovering anatomy", "samples": samples})

func _check_direction(index: int) -> void:
	var facings: Array[String]
	facings.assign(["front", "front", "rear", "rear"])
	var mirrors: Array[bool]
	mirrors.assign([false, true, false, true])
	for sample: Dictionary in _manifest["clips"][-1]["samples"]:
		var animation: Dictionary = sample["animation"]
		if str(animation.get("clip", "")) in ["walk", "attack"]:
			_assert(animation["facing"] == facings[index] and animation["mirrored"] == mirrors[index], "Lightning Wisp movement and melee face " + _direction_name(index))
	_assert(_snapshot()["facing"] == facings[index] and _snapshot()["mirrored"] == mirrors[index], "Idle retains the completed direction")

func _snapshot() -> Dictionary:
	return _board.call("lightning_wisp_animation_snapshot", "enemy_1")

func _still(label: String) -> void:
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

func _additional_intent_checks() -> void:
	for intent: String in ["static_lash", "blinding_arc"]:
		await _fixture(Vector2i(3, 5), Vector2i(3, 3), true, intent)
		_texture_id = int(_snapshot()["texture_id"])
		var engine := CombatEngine.new()
		var before: Dictionary = (_instance.get("_combat_state") as Dictionary).duplicate(true)
		var expected: Dictionary = engine.advance_to_next_player_turn_with_steps(engine.finish_player_activation(before))["state"]
		_instance.call("_on_pass_turn_pressed")
		await _record("reduced_" + intent, false, false)
		var after: Dictionary = _instance.get("_combat_state")
		_assert(after["player"]["hp"] == expected["player"]["hp"] and after.get("surfaces", {}) == expected.get("surfaces", {}), "Reduced electrical presentation keeps the exact damage/surface outcome")
		_assert(_snapshot()["clip"] == "rest", "Reduced electrical recovery retains the new still art")
	await _fixture(Vector2i(6, 3), Vector2i(1, 3), false, "static_lash")
	_texture_id = int(_snapshot()["texture_id"])
	_instance.call("_on_pass_turn_pressed")
	await _record("static_lash_long_advance", false, true)
	_assert((_manifest["clips"][-1]["phases_seen"] as Array).has("walk"), "Static Lash actually advances from beyond its firing range")
	await _fixture(Vector2i(3, 5), Vector2i(3, 3), false, "blinding_arc")
	var state: Dictionary = (_instance.get("_combat_state") as Dictionary).duplicate(true)
	# The closer illusion takes the direct hit. The player is reached through
	# its connected ground, so Capacitor Arc's conducted-only Shock applies.
	state["illusions"] = [{"id": 5, "pos": Vector2i(3, 4), "hp": 10, "max_hp": 10}]
	Ground.place(state, Vector2i(3, 5), "electrified")
	Ground.place(state, Vector2i(3, 4), "electrified")
	_install_state(state)
	await _settle()
	_texture_id = int(_snapshot()["texture_id"])
	var engine := CombatEngine.new()
	var expected: Dictionary = engine.advance_to_next_player_turn_with_steps(engine.finish_player_activation(state))["state"]
	_instance.call("_on_pass_turn_pressed")
	await _record("blinding_arc_conduction", false, true)
	var after: Dictionary = _instance.get("_combat_state")
	_assert(after["player"]["hp"] == expected["player"]["hp"] and after["illusions"] == expected["illusions"], "Actual Capacitor Arc conducts to player and illusion exactly once")
	_assert(int(after["illusions"][0]["hp"]) == 6 and int(after["enemies"][1]["hp"]) == 6, "Conduction damages the opponent illusion and leaves the allied Wisp untouched")
	_assert(after.get("surfaces", {}) == expected.get("surfaces", {}), "Capacitor Arc preserves reusable conducting ground")
	_assert(bool(after.get("player_turn_restrictions", {}).get("shocked", false)) and after.get("player_turn_restrictions", {}) == expected.get("player_turn_restrictions", {}), "Conducted Shock applies the exact next-activation restriction")
	var saw_shock: bool = false
	for sample: Dictionary in _manifest["clips"][-1]["samples"]:
		# The existing animation state replays losses and status floating text;
		# the resolver consumes the stored Shock into the next-turn restriction.
		for entry: Dictionary in sample["floating_texts"]:
			saw_shock = saw_shock or "Shock" in str(entry.get("text", ""))
	_assert(saw_shock, "The real electrical result displays its specialist Shock feedback")

func _install_state(state: Dictionary) -> void:
	var run: Dictionary = (_instance.get("_run_state") as Dictionary).duplicate(true)
	run["combat_state"] = state.duplicate(true)
	_instance.set("_run_state", run)
	_instance.call("_sync_combat_state_from_run")
	_instance.call("_refresh_ui")

func _summon_check() -> void:
	await _fixture(Vector2i(3, 5), Vector2i(3, 2), false, "call_wisps", 40, "zekarion")
	var state: Dictionary = (_instance.get("_combat_state") as Dictionary).duplicate(true)
	state["enemies"] = [state["enemies"][0]]
	state["turn_queue"] = (state["turn_queue"] as Array).filter(func(entry: Dictionary) -> bool: return int(entry.get("enemy_id", -1)) != 2)
	_install_state(state)
	await _settle()
	var engine := CombatEngine.new()
	var expected: Dictionary = engine.advance_to_next_player_turn_with_steps(engine.finish_player_activation(state))["state"]
	await _still("summon_before_action")
	await _instance.call("_on_pass_turn_pressed")
	await _settle()
	var after: Dictionary = _instance.get("_combat_state")
	var summoned: Array = (after["enemies"] as Array).filter(func(enemy: Dictionary) -> bool: return str(enemy.get("type", "")) == "lightning_wisp")
	_assert(summoned.size() == 2 and after["enemies"] == expected["enemies"], "Actual Call Wisps retains the exact two-minion spawn, IDs, HP and intent result")
	var records: Array[Dictionary]
	var texture_ids: Array[int]
	for unit: Dictionary in summoned:
		var snapshot: Dictionary = _board.call("lightning_wisp_animation_snapshot", "enemy_%d" % int(unit["id"]))
		_assert(bool(unit.get("summoned", false)) and not snapshot.is_empty(), "Freshly summoned zero-reward Wisps immediately own production cutouts")
		_assert(snapshot.get("clip", "") == "idle" and not texture_ids.has(int(snapshot.get("texture_id", 0))), "Each summoned Wisp starts an independent idle renderer")
		texture_ids.append(int(snapshot.get("texture_id", 0)))
		records.append({"unit": unit.duplicate(true), "animation": snapshot})
	_manifest["summon"] = {"trigger": "RunScene Pass / Call Wisps", "expected_enemy_count": (expected["enemies"] as Array).size(), "actors": records}
	await _still("summoned_wisps")
