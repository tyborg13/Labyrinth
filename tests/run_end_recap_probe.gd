extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const Score = preload("res://scripts/run_score_rules.gd")
const Overlay = preload("res://scripts/run_end_recap_overlay.gd")
const CutoutContext = preload("res://scripts/cutout_context.gd")
const RUN_SCENE = preload("res://scenes/run_scene.tscn")

const EMBER_HEARTH_PROOF_SEED: int = 8821
const RECOVERY_PROOF_SEED: int = 8822
const OUTPUT_ROOT: String = "user://run_end_recap_probe_v9"

var _failed: bool = false
var _resolution: Vector2i = Vector2i(1920, 1080)
var _output_dir: String = ""

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_resolution = _requested_resolution()
	_output_dir = "%s/%dx%d" % [OUTPUT_ROOT, _resolution.x, _resolution.y]
	_configure_window(_resolution)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_dir))
	_clear_probe_output(_output_dir)
	ProgressionStore.set_storage_path("user://run_end_recap_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://run_end_recap_probe_saved_run.save")
	ProgressionStore.clear_saved_run()
	call_deferred("_capture_states")

func _capture_states() -> void:
	await process_frame
	await process_frame
	var instance: Node = RUN_SCENE.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	var engine := RunEngine.new()

	var baseline_stats: Dictionary = {
		"enemies_killed": 3,
		"damage_dealt": 300,
		"damage_received": 150,
		"depth": 1,
		"rooms_cleared": 1,
		"bosses_defeated": 0
	}
	var baseline_record: Dictionary = ProgressionStore.record_run_result(ProgressionStore.default_data(), "probe:baseline", baseline_stats)
	var defeat_progression: Dictionary = baseline_record.get("data", {}) as Dictionary
	var defeat_state: Dictionary = _terminal_state(engine, defeat_progression, Vector2i(4, 0), "defeat", 214, 29, {
		"enemies_killed": 61,
		"enemies_slain": 61,
		"rooms_explored": 29,
		"guardians_slain": 2,
		"dragons_slain": ["tharokh", "vyraketh"],
		"dragons_flawless": ["vyraketh"],
		"max_single_hit": 22,
		"max_kills_one_card": 3,
		"killer": {"enemy_type": "frostglass_lancer", "intent_id": "glass_lunge", "damage": 6},
		"damage_dealt": 780,
		"damage_received": 260
	})
	await _capture_player_death_transition(instance, defeat_state)
	defeat_state.erase("_probe_terminal_combat_state")
	await _install_state(instance, defeat_progression, defeat_state)
	var recap: Control = instance.get("_run_end_recap") as Control
	instance.call("_seek_run_end_board_reframe", 1.0)
	_validate_last_light_semantics(instance, recap)
	if recap != null:
		recap.call("seek_presentation", 0.0)
	instance.call("_seek_run_end_board_reframe", 0.0)
	_validate_glow_tracks_death_site(instance, recap, "start")
	await _capture("defeat_pre_engulf.png")
	if recap != null:
		recap.call("seek_presentation", 0.95)
	instance.call("_seek_run_end_board_reframe", 0.55)
	_validate_glow_tracks_death_site(instance, recap, "mid-reframe")
	await _capture("defeat_mid_engulf.png")
	if recap != null:
		recap.call("seek_presentation", float(recap.call("presentation_duration")))
	instance.call("_seek_run_end_board_reframe", 1.0)
	await _capture("defeat_final.png")
	var main_menu_button: Button = recap.find_child("MainMenuButton", true, false) as Button if recap != null else null
	if main_menu_button != null:
		main_menu_button.grab_focus()
	await process_frame
	await _capture("defeat_secondary_focused.png")
	if recap != null:
		recap.call("reset")
		recap.call("set_motion_enabled", false)
		instance.call("_reset_run_end_board_reframe")
		instance.call("_show_run_end_recap", "defeat")
	await create_timer(0.08).timeout
	await _capture("defeat_reduced_motion_final.png")

	var victory_progression: Dictionary = ProgressionStore.load_data()
	var victory_state: Dictionary = _terminal_state(engine, victory_progression, Vector2i(8, 0), "victory", 1200, 66, {
		"rooms_explored": 66,
		"enemies_slain": 140,
		"guardians_slain": 6,
		"dragons_slain": ["tharokh", "vyraketh", "vaeloryx", "iskaldra", "zekarion", "noctyrax"],
		"run_seconds": 3600,
		"enemies_killed": 140,
		"damage_dealt": 1240,
		"damage_received": 310
	})
	await _install_state(instance, victory_progression, victory_state)
	recap = instance.get("_run_end_recap") as Control
	if recap != null:
		recap.call("set_motion_enabled", true)
		recap.call("seek_presentation", float(recap.call("presentation_duration")))
		var victory_new_run: Button = recap.find_child("NewRunButton", true, false) as Button
		var victory_main_menu: Button = recap.find_child("MainMenuButton", true, false) as Button
		if victory_new_run == null or victory_main_menu == null or str(victory_new_run.get_meta("button_variant", "")) != "large" or str(victory_main_menu.get_meta("button_variant", "")) != "large":
			_fail("Victory proof should retain the established large action treatment")
	await _capture("victory_final.png")
	if recap != null:
		var victory_model: Dictionary = recap.call("recap_model")
		if str(victory_model.get("title", "")) != "ESCAPED" or victory_model["score"]["lines"].size() != 5:
			_fail("Victory must score six dragons and the escape bonus")
	var overflow: Dictionary = victory_state.duplicate(true)
	overflow["run_index"] = int(overflow.get("run_index", 0)) + 1
	overflow["run_stats"].merge({"guardians_unscathed": ["craghide", "rimejaw"], "dragons_flawless": overflow["run_stats"]["dragons_slain"].duplicate(), "max_single_hit": 22, "max_kills_one_card": 3, "mystery_rooms_entered": 10, "events_resolved": 8, "max_held_embers": 1200, "defiance_spent": 1, "run_seconds": 2699}, true)
	await _install_state(instance, ProgressionStore.load_data(), overflow)
	recap = instance.get("_run_end_recap") as Control
	if recap != null:
		recap.call("skip_presentation")
		var ledger: Control = recap.find_child("ScoreLedger", true, false)
		var bases: Control = ledger.get_node("ScoreRows")
		var feats: Control = ledger.get_node("FeatRows")
		if ledger is ScrollContainer or ledger.size != Vector2(780, 380) or bases.get_child_count() != 5 or feats.get_child_count() != 10 or feats.position.x != 400:
			_fail("All feats must fit the approved 380/20/380 ledger without scrolling")
		var dragon_detail: Label = feats.get_child(1).get_node("ScoreDetail")
		if dragon_detail.text != "Tharokh, Vyraketh, Vaeloryx +3" or dragon_detail.tooltip_text != dragon_detail.text or dragon_detail.text_overrun_behavior != TextServer.OVERRUN_TRIM_ELLIPSIS:
			_fail("Aggregated Flawless names truncate with ellipsis and preserve the full tooltip")
	await _capture("victory_overflow_final.png")

	# The brief separately asks for two feats; keep that fixture as well as the
	# approved HTML's three-feat, 567-point state above.
	var two_feats: Dictionary = defeat_state.duplicate(true)
	two_feats["run_stats"]["max_single_hit"] = 0
	two_feats["run_index"] = int(two_feats.get("run_index", 0)) + 1
	await _install_state(instance, ProgressionStore.load_data(), two_feats)
	recap = instance.get("_run_end_recap") as Control
	instance.call("_seek_run_end_board_reframe", 1.0)
	if recap != null:
		recap.call("skip_presentation")
		if recap.call("recap_model")["score"]["feats"].size() != 2:
			_fail("Two-feat defeat fixture must have exactly two feats")
	await _capture("defeat_two_feats.png")
	var recovery_profile: Dictionary = ProgressionStore.load_data()
	recovery_profile["run_counter"] = int(ProgressionStore.recovery_marker(recovery_profile).get("available_run", 1)) - 1
	var next_run: Dictionary = engine.create_new_run(RECOVERY_PROOF_SEED, ProgressionStore.prepare_for_new_run(recovery_profile))
	var recovery_coord: Vector2i = engine.call("_recovery_coord_for_run", next_run)
	var recovery_room: Dictionary = engine.room_metadata(next_run, recovery_coord)
	if not bool(recovery_room.get("recovery_marker", false)) or int(recovery_room.get("recovery_amount", 0)) != 214:
		_fail("Next section-map run must stage all lost Embers at its mapped recovery room")

	var hearth: Dictionary = engine.create_new_run(EMBER_HEARTH_PROOF_SEED, ProgressionStore.load_data())
	var hearth_coord: Vector2i = engine.available_moves(hearth)[0]
	var hearth_key: String = _room_key(hearth_coord)
	hearth["rooms"][hearth_key]["type"] = "campfire"
	hearth = engine.move_to_room(hearth, hearth_coord)
	hearth = engine.set_held_embers(hearth, 214)
	ProgressionStore.save_data(hearth["progression"])
	instance.set("_progression", hearth["progression"].duplicate(true))
	instance.call("_load_run_state", hearth)
	instance.call("_close_dialogue")
	await instance.call("_on_campfire_embrace_pressed")
	await process_frame
	recap = instance.get("_run_end_recap") as Control
	if recap != null:
		recap.call("set_motion_enabled", false)
		var embrace_model: Dictionary = recap.call("recap_model")
		if str(embrace_model.get("title", "")) != "WITHDRAWN" or not str(embrace_model.get("cause", "")).contains("Ember Hearth"):
			_fail("Embrace must present the approved WITHDRAWN copy")
		for property: String in ["stats_label", "loadout_button", "grimoire_button", "menu_button"]:
			if (instance.get(property) as Control).is_visible_in_tree():
				_fail("WITHDRAWN must hide the top-right HUD: %s" % property)
	await _capture("embrace_final.png")

	instance.queue_free()
	await process_frame
	print(ProjectSettings.globalize_path(_output_dir))
	quit(1 if _failed else 0)

func _capture_player_death_transition(instance: Node, terminal_state: Dictionary) -> void:
	var after_combat: Dictionary = (terminal_state.get("_probe_terminal_combat_state", {}) as Dictionary).duplicate(true)
	if after_combat.is_empty():
		_fail("Lethal-transition proof should retain the terminal combat state")
		return
	var death_tile: Vector2i = (terminal_state.get("current_room_layout", {}) as Dictionary).get("player_start", Vector2i(-1, -1))
	var after_player: Dictionary = (after_combat.get("player", {}) as Dictionary).duplicate(true)
	after_player["hp"] = 0
	after_combat["player"] = after_player
	var before_combat: Dictionary = after_combat.duplicate(true)
	var before_player: Dictionary = after_player.duplicate(true)
	before_player["hp"] = maxi(18, int(before_player.get("max_hp", 18)))
	before_combat["player"] = before_player
	var living_run: Dictionary = terminal_state.duplicate(true)
	living_run["mode"] = "combat"
	living_run["game_over"] = false
	living_run["victory"] = false
	living_run["player_hp"] = int(before_player.get("hp", 18))
	living_run["combat_state"] = before_combat
	instance.call("_load_run_state", living_run)
	instance.call("_close_dialogue")
	await process_frame
	await process_frame
	var board: Control = instance.get_node("BoardUnderlay/CombatBoard") as Control
	var living_player_found: bool = false
	for unit_var: Variant in board.call("_visible_units") as Array:
		if typeof(unit_var) == TYPE_DICTIONARY and str((unit_var as Dictionary).get("role", "")) == "player":
			living_player_found = true
	if not living_player_found:
		_fail("Lethal-transition proof should begin with the living player rendered")
	await _capture("defeat_player_living.png")
	var death_presentation: Dictionary = instance.call("_death_hold_presentation", before_combat, after_combat, {}) as Dictionary
	var death_units: Array = death_presentation.get("death_animation_units", []) as Array
	if death_units.size() != 1:
		_fail("Lethal transition should produce exactly one player death presentation unit")
	else:
		var death_unit: Dictionary = (death_units[0] as Dictionary).duplicate(true)
		if str(death_unit.get("role", "")) != "player" or death_unit.get("pos", Vector2i(-1, -1)) != death_tile:
			_fail("Player collapse should remain on the terminal death tile")
		if not bool(board.call("_unit_uses_cutout", death_unit)):
			_fail("Player collapse proof should use the current protagonist cutout")
		var native_rect := Rect2(Vector2(120.0, 80.0), Vector2(255.0, 255.0))
		if not (board.call("_death_animation_render_rect", death_unit, native_rect) as Rect2).is_equal_approx(native_rect):
			_fail("Cutout death proof should bypass procedural squash/stretch")
		for frame_spec: Dictionary in [
			{"frame": 3, "progress": 0.20, "file": "defeat_player_death_early.png"},
			{"frame": 9, "progress": 0.60, "file": "defeat_player_death_mid.png"},
			{"frame": 15, "progress": 1.0, "file": "defeat_player_death_final.png"},
		]:
			var frame_unit: Dictionary = death_unit.duplicate(true)
			frame_unit["death_frame"] = int(frame_spec.get("frame", 0))
			frame_unit["death_progress"] = float(frame_spec.get("progress", 0.0))
			var frame_presentation: Dictionary = death_presentation.duplicate(true)
			frame_presentation["death_animation_units"] = [frame_unit]
			instance.call("_render_board_state", after_combat, frame_presentation)
			await process_frame
			await process_frame
			var cutout: Dictionary = board.call("protagonist_animation_snapshot") as Dictionary
			var expected_phase: float = clampf(float(frame_spec["progress"]) / CutoutContext.DEATH_SETTLE_PROGRESS, 0, 1)
			if str(cutout.get("clip", "")) != "death" or not is_equal_approx(float(cutout.get("phase", -1)), expected_phase) or int(cutout.get("texture_id", 0)) == 0:
				_fail("Player cutout should render its death clip at the requested phase with approved art")
			var rendered_death_units: Array = board.call("_death_animation_units_from_presentation") as Array
			if rendered_death_units.size() != 1 or str((rendered_death_units[0] as Dictionary).get("role", "")) != "player":
				_fail("CombatBoard should render the lethal player through its cutout collapse path")
			elif (rendered_death_units[0] as Dictionary).get("pos", Vector2i(-1, -1)) != death_tile:
				_fail("Rendered player death frame should not drift from the eventual ember tile")
			await _capture(str(frame_spec.get("file", "defeat_player_death.png")))

func _validate_glow_tracks_death_site(instance: Node, recap: Control, stage: String) -> void:
	if recap == null:
		_fail("%s glow proof should have a recap overlay" % stage)
		return
	var glow_site: Vector2 = recap.call("glow_site_normalized") as Vector2
	var projected_death_site: Vector2 = instance.call("_run_end_death_site_normalized") as Vector2
	if glow_site.distance_to(projected_death_site) > 0.008:
		_fail("%s Last Light glow should remain anchored to the projected ember tile" % stage)

func _install_state(instance: Node, progression: Dictionary, state: Dictionary) -> void:
	ProgressionStore.save_data(progression)
	instance.set("_progression", progression.duplicate(true))
	instance.call("_load_run_state", state)
	await process_frame
	await process_frame
	var recap: Control = instance.get("_run_end_recap") as Control
	if recap == null or not recap.visible:
		_fail("Terminal state should display the recap overlay")
	var board: Control = instance.get_node("BoardUnderlay/CombatBoard") as Control
	if board == null or not board.visible:
		_fail("Terminal state should keep the final tactical room visible")

func _validate_last_light_semantics(instance: Node, recap: Control) -> void:
	if recap == null:
		return
	var model: Dictionary = recap.call("recap_model") as Dictionary
	var title: Label = recap.find_child("OutcomeTitle", true, false) as Label
	if title == null or title.text not in ["SLAIN", "FALLEN"] or title.get_theme_font("font") != load("res://fonts/LabyrinthCrumble-Display.tres") or title.get_theme_font_size("font_size") != 112:
		_fail("Defeat uses the seeded title in the approved 112px Display face")
	var column: Control = recap.find_child("OutcomeRecap", true, false) as Control
	if column == null or column.position != Vector2(1010, 82) or column.size.x != 780:
		_fail("Recap right column must use the approved 1920x1080 coordinates")
	var scored: Dictionary = model.get("score", {})
	if int(scored.get("total", 0)) != 567 or scored.get("feats", []).size() != 3:
		_fail("Approved mockup fixture must total 567 with its three depicted feats")
	var ledger: Control = recap.find_child("ScoreRows", true, false) as Control
	if ledger == null or ledger.get_child_count() != 7:
		_fail("Mockup fixture must show four base rows and three feat rows")
	var chronicle: Button = recap.find_child("ChronicleButton", true, false) as Button
	if chronicle == null or not chronicle.disabled or chronicle.tooltip_text != "Coming soon":
		_fail("Chronicle is disabled with its approved tooltip")
	var primary: Button = recap.find_child("NewRunButton", true, false) as Button
	if primary == null or primary.text != "Rise Again":
		_fail("Primary action retains its node id and approved label")
	if not bool(model.get("new_best_score", false)):
		_fail("Mockup fixture must prove NEW BEST")
	var board: Control = instance.get_node("BoardUnderlay/CombatBoard") as Control
	var ember_snapshot: Dictionary = board.call("death_site_embers_snapshot") as Dictionary
	var death_tile: Vector2i = (instance.get("_run_state") as Dictionary).get("current_room_layout", {}).get("player_start", Vector2i(-1, -1))
	if ember_snapshot.get("tile", Vector2i(-1, -1)) != death_tile or not ember_snapshot.get("texture", null) is Texture2D:
		_fail("Defeat proof should leave raster embers grounded on the exact death tile")
	var ember_rect: Rect2 = ember_snapshot.get("rect", Rect2()) as Rect2
	var tile_width: float = float(ember_snapshot.get("tile_width", 0.0))
	if ember_rect.size.x > tile_width * 0.40:
		_fail("Death-site embers should fit within the board tile footprint")
	for unit_var: Variant in board.call("_visible_units") as Array:
		if typeof(unit_var) == TYPE_DICTIONARY and str((unit_var as Dictionary).get("role", "")) == "player":
			_fail("Terminal defeat board should remove the dead player before leaving embers")
	var centered_site: Vector2 = instance.call("_run_end_death_site_normalized") as Vector2
	var fixed_window: Vector2 = recap.call("death_site_normalized") as Vector2
	if centered_site.distance_to(fixed_window) > 0.008:
		_fail("The translated death tile should settle beneath the fixed Umbra window (tile %s, window %s)" % [centered_site, fixed_window])
	_validate_glow_tracks_death_site(instance, recap, "settled")

func _terminal_state(engine: RunEngine, progression: Dictionary, coord: Vector2i, outcome: String, held_embers: int, cleared_rooms: int, run_stats: Dictionary) -> Dictionary:
	var state: Dictionary = engine.create_new_run(8841 + held_embers * 3 + coord.x, progression)
	var rooms: Dictionary = (state.get("rooms", {}) as Dictionary).duplicate(true)
	var marked: int = 0
	for room_key_var: Variant in rooms.keys():
		if marked >= cleared_rooms:
			break
		var room_var: Variant = rooms[room_key_var]
		if typeof(room_var) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = (room_var as Dictionary).duplicate(true)
		if int(candidate.get("depth", 0)) <= 0 or str(room_key_var) == _room_key(coord):
			continue
		candidate["visited"] = true
		candidate["cleared"] = true
		rooms[room_key_var] = candidate
		marked += 1
	var room: Dictionary = engine.room_metadata(state, coord).duplicate(true)
	room["revealed"] = true
	room["visited"] = true
	room["cleared"] = false
	room["section_index"] = 2 if outcome == "defeat" else 5
	room["map_step"] = 7 if outcome == "defeat" else 12
	var section_index: int = int(room["section_index"])
	if section_index < state["map_sections"].size():
		state["map_sections"][section_index]["boss_id"] = "iskaldra" if outcome == "defeat" else "noctyrax"
		state["map_sections"][section_index]["room_count"] = 11 if outcome == "defeat" else 12
	if outcome == "victory":
		room["type"] = "boss"
	rooms[_room_key(coord)] = room
	state["rooms"] = rooms
	state["current_room"] = coord
	state["run_stats"] = CombatEngine.normalized_run_stats(run_stats)
	var layout: Dictionary = engine.call("_combat_layout_for_room", room, Vector2i(1, 0), state)
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(int(state.get("seed", 0)), layout, engine.call("_player_snapshot", state) as Dictionary)
	combat_state["run_stats"] = CombatEngine.normalized_run_stats(run_stats)
	if outcome == "defeat":
		var player: Dictionary = (combat_state.get("player", {}) as Dictionary).duplicate(true)
		player["hp"] = 0
		combat_state["player"] = player
	else:
		var enemies: Array = (combat_state.get("enemies", []) as Array).duplicate(true)
		for index: int in range(enemies.size()):
			var enemy: Dictionary = (enemies[index] as Dictionary).duplicate(true)
			enemy["hp"] = 0
			enemies[index] = enemy
		combat_state["enemies"] = enemies
	state["mode"] = "combat"
	state["combat_state"] = combat_state
	state["held_embers"] = held_embers
	state["unbanked_embers"] = held_embers
	state["_probe_terminal_combat_state"] = combat_state.duplicate(true)
	state = engine.finish_combat(state, combat_state)
	state["mode"] = outcome
	state["victory"] = outcome == "victory"
	state["game_over"] = outcome == "defeat"
	state["held_embers"] = held_embers
	state["unbanked_embers"] = held_embers
	state["run_stats"] = CombatEngine.normalized_run_stats(run_stats)
	state["progression"] = progression.duplicate(true)
	return state

func _requested_resolution() -> Vector2i:
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--resolution="):
			continue
		var value: String = argument.trim_prefix("--resolution=").to_lower()
		var parts: PackedStringArray = value.split("x", false)
		if parts.size() == 2:
			var width: int = int(parts[0])
			var height: int = int(parts[1])
			if width >= 640 and height >= 360:
				return Vector2i(width, height)
	return Vector2i(1920, 1080)

func _configure_window(resolution: Vector2i) -> void:
	root.content_scale_size = resolution
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = resolution
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(resolution)

func _capture(filename: String) -> void:
	await process_frame
	await process_frame
	var instance: Node = root.get_node_or_null("RunScene")
	var recap: Control = instance.get("_run_end_recap") as Control if instance != null else null
	if recap != null and recap.visible:
		_validate_score_geometry(recap)
	var image: Image = root.get_viewport().get_texture().get_image()
	if image.get_width() != _resolution.x or image.get_height() != _resolution.y:
		# macOS exposes the Retina backing texture even though content_scale_size is
		# the requested logical proof viewport. Preserve that Metal render and
		# downsample it to the exact review resolution.
		image.resize(_resolution.x, _resolution.y, Image.INTERPOLATE_LANCZOS)
	var error: Error = image.save_png("%s/%s" % [_output_dir, filename])
	if error != OK:
		_fail("Could not save %s" % filename)

func _validate_score_geometry(recap: Control) -> void:
	var column: Control = recap.find_child("OutcomeRecap", true, false)
	if column == null or not column.global_position.is_equal_approx(Vector2(1010, 82)) or not is_equal_approx(column.get_global_rect().size.x, 780):
		_fail("Every outcome must keep the recap at viewport x=1010, width=780")
	for node_name: String in ["ScoreRows", "FeatRows"]:
		var rows: Control = recap.find_child(node_name, true, false)
		for row: Control in rows.get_children():
			var label: Label = row.get_node("ScoreLabel")
			var detail: Label = row.get_node("ScoreDetail")
			var value: Label = row.get_node("ScorePoints")
			if detail.get_global_rect().position.x < label.get_global_rect().end.x or detail.get_global_rect().end.x > value.get_global_rect().position.x or value.get_global_rect().end.x > row.get_global_rect().end.x:
				_fail("Score detail overlaps a label, value or next column: %s" % label.text)
			if not detail.clip_text or detail.text_overrun_behavior != TextServer.OVERRUN_TRIM_ELLIPSIS or detail.tooltip_text != detail.text:
				_fail("Score details must truncate with ellipsis and a full tooltip: %s" % label.text)

func _room_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

func _clear_probe_output(output_dir: String) -> void:
	_clear_probe_output_absolute(ProjectSettings.globalize_path(output_dir))

func _clear_probe_output_absolute(absolute_dir: String) -> void:
	var dir := DirAccess.open(absolute_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry.is_empty():
			break
		if entry in [".", ".."]:
			continue
		var child_path: String = absolute_dir.path_join(entry)
		if dir.current_is_dir():
			_clear_probe_output_absolute(child_path)
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	dir.list_dir_end()

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	print("TEST RESULT: FAIL %s" % message)
