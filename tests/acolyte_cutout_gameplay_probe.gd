extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const ContextualCombatTutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const InputRouter = preload("res://scripts/input_router.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const Cutout = preload("res://scripts/acolyte_cutout/renderer.gd")
const OUTPUT: String = "user://probes/acolyte_gameplay_v01"
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
	ProgressionStore.set_storage_path("user://acolyte_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://acolyte_probe_run.save")
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
	var starts: Array[Vector2i]
	starts.assign([Vector2i(4,1), Vector2i(1,3), Vector2i(3,6), Vector2i(6,4)])
	var targets: Array[Vector2i]
	targets.assign([Vector2i(3,6), Vector2i(6,4), Vector2i(4,1), Vector2i(1,3)])
	for index: int in range(directions.size()):
		var origin: Vector2i = starts[index]
		await _fixture(targets[index], origin)
		_texture_id = int(_snapshot().get("texture_id", 0))
		_assert(_texture_id != 0, "Actual RunScene owns the Acolyte texture")
		await _record("00_idle_" + _direction_name(index), false, false, {}, 3.6)
		var before: Dictionary = (_instance.get("_combat_state") as Dictionary).duplicate(true)
		var engine := CombatEngine.new()
		var expected: Dictionary = engine.advance_to_next_player_turn_with_steps(engine.finish_player_activation(before))["state"]
		_instance.call("_on_pass_turn_pressed")
		await _record("%02d_dust_bolt_%s" % [index + 1, _direction_name(index)], false, true)
		var after: Dictionary = _instance.get("_combat_state")
		_assert(int(after["player"]["hp"]) == 35 and int(after["player"]["hp"]) == int(expected["player"]["hp"]), "Dust Bolt applies exactly five damage once")
		_assert(after["enemies"][0]["pos"] == expected["enemies"][0]["pos"], "Dust Bolt follows the resolved artillery route")
		_assert(int(after["initiative_clock"]) == int(expected["initiative_clock"]), "Animation preserves initiative resolution")
		_check_direction(index)
	for index: int in range(directions.size()):
		var origin: Vector2i = starts[index]
		await _fixture(targets[index], origin, false, "siphon", 8)
		_texture_id = int(_snapshot()["texture_id"])
		var before: Dictionary = (_instance.get("_combat_state") as Dictionary).duplicate(true)
		var engine := CombatEngine.new()
		var expected: Dictionary = engine.advance_to_next_player_turn_with_steps(engine.finish_player_activation(before))["state"]
		_instance.call("_on_pass_turn_pressed")
		await _record("05_siphon_" + _direction_name(index), false, true)
		var after: Dictionary = _instance.get("_combat_state")
		_assert(int(after["player"]["hp"]) == 36 and int(after["player"]["hp"]) == int(expected["player"]["hp"]), "Siphon preserves exactly four damage")
		_assert(int(after["enemies"][0]["hp"]) == 10 and int(after["enemies"][0]["hp"]) == int(expected["enemies"][0]["hp"]), "Siphon preserves the separate two-point self heal")
		var saw_siphon: bool = false
		for sample: Dictionary in _manifest["clips"][-1]["samples"]:
			if sample["animation"].get("clip", "") == "attack":
				saw_siphon = saw_siphon or sample["animation"].get("action", "") == "siphon"
		_assert(saw_siphon, "Actual Siphon intent selects its draw-back recovery")
		_check_direction(index)
	await _fixture(Vector2i(3, 5), Vector2i(3, 3), true)
	_texture_id = int(_snapshot()["texture_id"])
	_instance.call("_on_pass_turn_pressed")
	await _record("06_reduced_dust_bolt", false, false)
	_assert(int((_instance.get("_combat_state") as Dictionary)["player"]["hp"]) == 35, "Reduced motion preserves the same movement and damage")
	_assert(_snapshot()["clip"] == "rest", "Reduced motion keeps the new Acolyte still")
	await _fixture(Vector2i(3, 4), Vector2i(3, 3), false, "ward_chant")
	_texture_id = int(_snapshot()["texture_id"])
	_instance.call("_on_pass_turn_pressed")
	await _record("07_ward_chant", false, false)
	_assert(int((_instance.get("_combat_state") as Dictionary)["enemies"][0].get("block", 0)) == 4, "Ward Chant still grants four self block")
	await _fixture(Vector2i(3, 4), Vector2i(3, 3), false, "dust_bolt", 9)
	_texture_id = int(_snapshot()["texture_id"])
	await _instance.call("_on_card_pressed", 0)
	_instance.call("_on_board_tile_hovered", Vector2i(3, 3))
	await _settle()
	await _still("08_target_preview")
	_instance.call("_on_board_tile_clicked", Vector2i(3, 3))
	await _record("09_acolyte_death", true, false)
	_assert(_snapshot().is_empty(), "Dead Acolyte releases its cutout after the dissolve")
	var survivors: Array = ((_instance.get("_combat_state") as Dictionary)["enemies"] as Array).filter(func(enemy: Dictionary) -> bool: return int(enemy.get("hp", 0)) > 0)
	_assert(survivors.size() == 1 and int(survivors[0]["id"]) == 2, "The other Acolyte remains alive after the exact lethal hit")
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
		_assert(_snapshot()["clip"] == "idle" and _snapshot()["facing"] == facing["facing"] and _snapshot()["mirrored"] == facing["mirrored"], "Acolyte idle turns toward the player's completed destination")
		var player_idle: Dictionary = _board.call("protagonist_animation_snapshot")
		_assert(player_idle["clip"] == "idle" and player_idle["facing"] == "front" and not player_idle["mirrored"], "Player still returns to camera-facing idle")
	var portrait: String = str(_instance.TURN_ORDER_PORTRAITS.get("acolyte", ""))
	_assert(portrait == "res://assets/art/portraits/dust_acolyte.png" and preload("res://scripts/asset_loader.gd").load_texture_source_first(portrait) != null, "Turn clock retains the dedicated Dust Acolyte portrait")
	await _umbra_impact_origin_proof()
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
	print("ACOLYTE GAMEPLAY PROBE: " + ("PASS" if _errors.is_empty() else "FAIL"))
	quit(0 if _errors.is_empty() else 1)

func _umbra_impact_origin_proof() -> void:
	# Exercise the real Umbra descriptor and RunScene board routing at impact,
	# where the default projectile still draws its visible trail.
	await _fixture(Vector2i(2, 4), Vector2i(6, 4))
	var state: Dictionary = (_instance.get("_combat_state") as Dictionary).duplicate(true)
	var umbra: Dictionary = (state.get("umbra", {}) as Dictionary).duplicate(true)
	umbra.merge({"stage": "heart", "stage_reduction": 0, "light_sources": []}, true)
	state["umbra"] = umbra
	_instance.set("_combat_state", state)
	var run: Dictionary = (_instance.get("_run_state") as Dictionary).duplicate(true)
	run["combat_state"] = state.duplicate(true)
	_instance.set("_run_state", run)
	_instance.call("_refresh_ui")
	await _settle()
	var step: Dictionary = _instance.call("_visible_umbra_action_step", state, {
		"kind": "ranged", "action_type": "ranged", "actor_key": "enemy_1", "actor_name": "Dust Acolyte",
		"enemy_type": "acolyte", "intent_id": "dust_bolt", "element": "none",
		"from": Vector2i(6, 4), "to": Vector2i(2, 4), "hidden_by_umbra": true, "hp_loss": 5})
	_assert(bool(step.get("umbra_action_clipped", false)), "Hidden Dust Bolt uses the actual Umbra clipping descriptor")
	_assert(step.get("from", Vector2i.ZERO) == Vector2i(4, 4), "Hidden Dust Bolt enters at the visible Umbra edge")
	var checks: Array[Dictionary]
	for reduced: bool in [false, true]:
		var settings: Dictionary = (_instance.get("_settings") as Dictionary).duplicate(true)
		settings["reduced_motion"] = reduced
		_instance.set("_settings", settings)
		_instance.call("_render_board_state", state, {"effect": step, "effect_progress": 1.0 if reduced else 0.85, "reduced_motion": reduced}, true)
		await _settle()
		var presentation: Dictionary = _board.get("presentation")
		var effect: Dictionary = presentation.get("effect", {})
		_assert(bool(presentation.get("reduced_motion", false)) == reduced, "Umbra proof exercises the requested motion setting")
		_assert(bool(effect.get("acolyte_cast", false)), "The hidden regression reaches Acolyte orb routing")
		_assert(not (presentation.get("visible_enemy_ids", []) as Array).has(1), "The hidden caster stays concealed at impact")
		var clipped_start: Vector2 = _board.call("world_position_for_tile", Vector2i(4, 4))
		var actual_start: Vector2 = _board.call("_protagonist_launch_point", effect, clipped_start)
		_assert(actual_start.is_equal_approx(clipped_start), "Visible impact trail never restarts from the hidden orb")
		checks.append({"reduced_motion": reduced, "effect": effect, "origin": [actual_start.x, actual_start.y], "visible_enemy_ids": presentation.get("visible_enemy_ids", [])})
		await _still("17_umbra_reduced_impact" if reduced else "16_umbra_impact")
	_manifest["umbra_impact_origin_checks"] = checks

func _fixture(player_tile: Vector2i, enemy_tile: Vector2i, reduced: bool = false, intent_id: String = "dust_bolt", acolyte_hp: int = 12) -> void:
	_instance.call("_cancel_drag_play")
	_instance.call("_reset_card_resolution")
	var hand: Array = ["quick_stab", "brace", "sidestep_slash", "bone_dart", "patch_up"]
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	var layout: Dictionary = {"name": "Dust Acolyte Combat Trial", "coord": Vector2i(4, 3), "type": "combat", "grid": grid,
		"player_start": player_tile, "enemies": [{"id": 1, "type": "acolyte", "pos": enemy_tile, "hp": acolyte_hp, "max_hp": 12, "block": 0}],
		"traps": [], "terrain": [], "element": "none"}
	layout["enemies"].append({"id": 2, "type": "acolyte", "pos": Vector2i(6, 6), "hp": 12, "max_hp": 12, "block": 0})
	_assert(player_tile.x > 0 and player_tile.x < 7 and player_tile.y > 0 and player_tile.y < 7, "Inspection player begins inside the floor")
	_assert(enemy_tile.x > 0 and enemy_tile.x < 7 and enemy_tile.y > 0 and enemy_tile.y < 7, "Inspection enemy begins inside the floor")
	var combat := CombatEngine.new()
	var state: Dictionary = combat.create_combat(260909, layout, {"hp": 40, "max_hp": 40, "deck_cards": hand.duplicate(), "relics": [], "hand_size": 5, "heal_bonus": 0})
	for intent: Dictionary in GameData.enemy_def("acolyte")["intents"]:
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
	var previous_support: Dictionary = {}
	var max_drift: float = 0.0
	var support_comparisons: int = 0
	while Time.get_ticks_usec() - started < 12000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		if bool(_instance.get("_animation_lock")):
			finish = 0
		elif finish == 0:
			finish = now
		var snapshot: Dictionary = _snapshot()
		_assert((allow_death and snapshot.is_empty()) or int(snapshot.get("texture_id", 0)) == _texture_id, "One Acolyte texture remains live through " + label)
		var presentation: Dictionary = _board.get("presentation")
		var effect: Dictionary = presentation.get("effect", {})
		var player_motion: Dictionary = presentation.get("protagonist_motion", {})
		if not observer_before.is_empty() and str(player_motion.get("clip", "")) == "walk":
			phases["player_walk"] = true
			_assert(snapshot["facing"] == observer_before["facing"] and snapshot["mirrored"] == observer_before["mirrored"], "Acolyte waits until player movement finishes before turning")
		phases[str(snapshot.get("clip", "gone"))] = true
		var display_state: Dictionary = _board.get("combat_state")
		var unit: Dictionary = {}
		for candidate: Dictionary in _board.call("_visible_units"):
			if str(candidate.get("key", "")) == "enemy_1":
				unit = candidate
		if str(snapshot.get("clip", "")) == "attack":
			_assert((_board.call("_unit_center", unit) as Vector2).is_equal_approx(_board.call("world_position_for_tile", unit["pos"])), "Acolyte attack keeps its planted stance on its actual tile")
			var progress: float = float(presentation.get("effect_progress", 0.0))
			var boundary: float = float(_instance.call("_attack_feedback_start_progress", effect))
			_assert((int(display_state["player"]["hp"]) == 40) == (progress < boundary), "Visible damage changes at the existing contact boundary")
		if str(snapshot.get("clip", "")) == "walk" and not unit.is_empty():
			var support: Dictionary = _support_points(unit, snapshot)
			if previous_support.get("view", "") == support["view"]:
				for foot: String in ["hem_r", "hem_l"]:
					if support.has(foot) and previous_support.has(foot) and int(support[foot]["stride"]) == int(previous_support[foot]["stride"]) and float(support[foot]["cycle"]) >= float(previous_support[foot]["cycle"]):
						var drift: float = (support[foot]["world"] as Vector2).distance_to(previous_support[foot]["world"])
						max_drift = maxf(max_drift, drift)
						support_comparisons += 1
			previous_support = support
		else:
			previous_support = {}
		if now >= next_capture:
			next_capture = now + 33333
			samples.append({"seconds": float(now - started) / 1000000.0, "animation": snapshot,
				"animation_lock": bool(_instance.get("_animation_lock")), "acolyte_motion": presentation.get("acolyte_motion", {}).duplicate(true),
				"player_motion": player_motion.duplicate(true), "effect": effect.duplicate(true), "effect_progress": float(presentation.get("effect_progress", 0.0)),
				"player_hp": int(display_state.get("player", {}).get("hp", 0)),
				"enemy_hp": int((display_state.get("enemies", [{}]) as Array)[0].get("hp", 0)),
				"death_units": presentation.get("death_animation_units", []).duplicate(true)})
			await RenderingServer.frame_post_draw
			images.append(_render_viewport.get_texture().get_image())
		if finish > 0 and not bool(_instance.get("_animation_lock")) and now - finish > 250000 and float(now - started) / 1000000.0 >= minimum_seconds:
			break
	var record_seconds: float = float(Time.get_ticks_usec() - started) / 1000000.0
	_assert(not bool(_instance.get("_animation_lock")), "Input returns after " + label)
	_assert(max_drift < 0.2, "Native world-space support feet stay planted through " + label)
	if require_attack:
		_assert(phases.has("walk") and phases.has("attack"), "Actual End Turn plays the Acolyte ranged cast in " + label)
		_assert(support_comparisons > 10, "Actual traversal supplies enough within-stride support comparisons in " + label)
	var folder: String = OUTPUT.path_join(label)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for index: int in range(images.size()):
		images[index].save_jpg(folder.path_join("frame_%04d.jpg" % index), 0.95)
	if not images.is_empty():
		images[-1].save_png(OUTPUT.path_join(label + ".png"))
		for target: float in [0.12, 0.18, 0.66, 0.83]:
			var nearest: int = -1
			var difference: float = INF
			for index: int in range(samples.size()):
				if str(samples[index]["animation"].get("clip", "")) != "attack":
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
	_manifest["clips"].append({"label": label, "phases_seen": phases.keys(), "record_seconds": record_seconds,
		"max_support_drift_px": max_drift, "support_comparisons": support_comparisons, "samples": samples})

func _support_points(unit: Dictionary, snapshot: Dictionary) -> Dictionary:
	var renderer: Node = (_board.get("_acolyte_renderers") as Dictionary)["enemy_1"]
	var rig: Node2D = renderer.get("rigs")[snapshot["facing"]]
	var logical: Rect2 = _board.call("_unit_draw_rect", unit)
	var motion: Dictionary = (_board.get("presentation") as Dictionary).get("acolyte_motion", {}).get("enemy_1", {})
	var unwrapped_phase: float = float(motion.get("phase", 0.0))
	var result: Dictionary = {"view": str(snapshot["facing"]) + str(snapshot["mirrored"])}
	for foot: String in ["hem_r", "hem_l"]:
		var state: Dictionary = Cutout.Motion.walk_foot_state(float(snapshot["phase"]), foot, rig.layout, str(snapshot["facing"]))
		if not bool(state["contact"]):
			continue
		var offset: Vector2 = Vector2.ZERO
		var canvas_point: Vector2 = (rig.bones[foot] as Node2D).global_transform * offset
		# A delayed frame may skip a complete stride. Its next planted contact
		# is a different world point; compare only the same unwrapped stride.
		result[foot] = {"world": logical.position + (canvas_point - Cutout.SOURCE_OFFSET) * logical.size / Cutout.SOURCE_SIZE,
			"cycle": state["cycle_phase"], "stride": floori(unwrapped_phase + (0.5 if foot == "hem_l" else 0.0))}
	return result

func _check_direction(index: int) -> void:
	var facings: Array[String]
	facings.assign(["front", "front", "rear", "rear"])
	var mirrors: Array[bool]
	mirrors.assign([false, true, false, true])
	for sample: Dictionary in _manifest["clips"][-1]["samples"]:
		var animation: Dictionary = sample["animation"]
		if str(animation.get("clip", "")) == "attack":
			_assert(animation["facing"] == facings[index] and animation["mirrored"] == mirrors[index], "Acolyte casting faces " + _direction_name(index))
	_assert(_snapshot()["facing"] == facings[index] and _snapshot()["mirrored"] == mirrors[index], "Idle retains the completed direction")

func _snapshot() -> Dictionary:
	return _board.call("acolyte_animation_snapshot", "enemy_1")

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
