extends SceneTree

## Permanent copy of the director's status fixture, plus hover and coverage proof.
## Execute via visual_probe_runner.py, never capture through a headless renderer.
const Fixture = preload("res://tools/warband_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const SIZE := Vector2i(1920, 1080)
const OUTPUT: String = "user://status-captures"
# Proof-only timing and fixture values; never production presentation values.
const SETTLE_SECONDS: float = 2.5
const SETTLE_FRAMES: int = 4
const TOOLTIP_TIMEOUT_SECONDS: float = 3.0
const IDLE_POINTER := Vector2.ZERO
const CATALOG_COUNT: int = 3
const EXPECTED_ORDER_DISCS: int = 5
const RESERVATION_PROBE_DELTA := Vector2(0, 1)
var canvas: SubViewport
var _captures: Array[Dictionary]
var _failures: Array[String]
var _check_only: bool = false
var _crowded: bool = false
var _hover_checks: Array[Dictionary]
var _crowded_states: Array[Dictionary]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _director_run() -> Dictionary:
	var engine := Run.new()
	var run: Dictionary = Fixture.build(engine, Combat.new(), engine.create_new_run(Fixture.FIXTURE_SEED, Store.default_data()), {"warband_biome": "earth", "warband_tier": 2})
	var state: Dictionary = run["combat_state"]
	state["player"].merge({"block": 6, "stoneskin": 4, "bleed": 2, "expose": 1}, true)
	# The protected mock also shows Stoneskin 3 on the right-hand knight.
	var looks: Array = [
		{"block": 5, "stoneskin": 3, "chilled": true, "shock": 1},
		{"stoneskin": 3, "bleed": 3, "expose": 2, "immobilize": true},
		{"freeze": 1, "block": 8},
		{"petrify": 1, "stoneskin": 2, "bleed": 1},
	]
	var index: int = 0
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0 or index >= looks.size(): continue
		enemy.merge(looks[index], true)
		index += 1
	return run

func _run() -> void:
	var run: Dictionary = _director_run()
	_crowded = OS.get_cmdline_user_args().has("--crowded")
	if _crowded: run["combat_state"] = preload("res://tests/suites/board_hud_group_suite.gd").mixed_state()
	_check_only = OS.get_cmdline_user_args().has("--check-only")
	_expect(_crowded or run.get("combat_state", {}).get("enemies", []).size() == 5, "Director fixture has six nameplates including the hero")
	if not _check_only and DisplayServer.get_name() == "headless":
		_expect(false, "Renderer proof requires the windowed visual runner")
		_finish()
		return
	Settings.set_storage_path("user://status-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.size = SIZE
	root.content_scale_size = SIZE
	canvas = SubViewport.new()
	canvas.size = SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	canvas.gui_embed_subwindows = true
	root.add_child(canvas)
	# An uncontained SubViewport needs its own mouse-enter notification before
	# real pointer motion can start Godot's native tooltip timer.
	canvas.notify_mouse_entered()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	await process_frame
	scene.call("_load_run_state", run)
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	await create_timer(SETTLE_SECONDS).timeout
	var board: Control = scene.get("board_view")
	for layer: Control in board.call("_retained_render_layers"):
		_expect(is_same(board.get("_status_plate_layout"), layer.get("_status_plate_layout")), "Retained board layers share the status layout cache")
	if _crowded:
		await _crowded_capture(scene, board)
		scene.queue_free()
		await process_frame
		await _encounter_captures()
		var proof := FileAccess.open(OUTPUT.path_join("crowded-semantic-proof.json"), FileAccess.WRITE)
		proof.store_string(JSON.stringify({"resolution": [1920, 1080], "ui_scale": 1.0, "check_only": _check_only, "captures": _captures, "states": _crowded_states, "failures": _failures}, "\t"))
		proof.close()
		print("STATUS crowded captures: " + ProjectSettings.globalize_path(OUTPUT))
		_finish()
		return
	await _capture(board, "statuses_board")
	_expect((_captures[0]["actors"] as Array).size() == 6, "Production board exposes all six fixture nameplates")
	await _hover_capture(board, false)
	await _hover_capture(board, true)
	await _catalog_capture(scene, run)
	await _wrapped_capture(scene, run)
	var file := FileAccess.open(OUTPUT.path_join("semantic-proof.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"resolution": [1920, 1080], "ui_scale": 1.0, "check_only": _check_only, "captures": _captures, "hover_checks": _hover_checks, "failures": _failures}, "\t"))
	file.close()
	print("STATUS captures: " + ProjectSettings.globalize_path(OUTPUT))
	_finish()

func _capture(board: Control, name: String) -> void:
	for _frame: int in range(SETTLE_FRAMES): await process_frame
	var path: String = OUTPUT.path_join(name + "_1920x1080.png")
	if not _check_only:
		await RenderingServer.frame_post_draw
		var image: Image = canvas.get_texture().get_image()
		_expect(image.get_size() == SIZE, "Capture is native 1920x1080")
		_expect(image.save_png(path) == OK, "Capture writes " + name)
	var actors: Array[Dictionary]
	var transform: Transform2D = board.get_global_transform_with_canvas()
	for unit: Dictionary in board.call("_hud_layout_units"):
		var frame: Rect2 = Badges.health_rect(board, unit)
		var defenses: Array = board.call("_unit_defense_plate_entries", unit, frame)
		var statuses: Array = board.call("_unit_status_pill_entries", unit, frame)
		actors.append({"key": unit.get("key", ""), "type": unit.get("type", ""), "frame": _rect_data(transform * frame), "defenses": _entries_data(defenses, transform), "statuses": _entries_data(statuses, transform)})
		if _check_only and name == "statuses_board": print("STATUS FIXTURE GEOMETRY: " + JSON.stringify(actors.back()))
	var discs: Array[Dictionary]
	var rest: Dictionary = (board.get("presentation") as Dictionary).get("threats_at_rest", {})
	for layout: Dictionary in Badges.layouts(board, rest.get("badges", [])):
		var rect: Rect2 = layout["order_rect"]
		if rect.has_area(): discs.append({"key": layout["key"], "order": layout["order"], "rect": _rect_data(transform * rect)})
	_expect(_crowded or discs.size() == EXPECTED_ORDER_DISCS, name + " preserves all five production order discs")
	_captures.append({"name": name, "path": ProjectSettings.globalize_path(path), "actors": actors, "order_discs": discs})

func _hover_capture(board: Control, defense: bool) -> void:
	var hero: Dictionary = {}
	for unit: Dictionary in board.call("_hud_layout_units"):
		if unit.get("key") == "player": hero = unit
	var frame: Rect2 = Badges.health_rect(board, hero)
	var kind: String = "plate" if defense else "pill"
	var entries: Array = board.call("_unit_defense_plate_entries" if defense else "_unit_status_pill_entries", hero, frame)
	_expect(not entries.is_empty(), "Hover proof has a hero " + kind)
	if entries.is_empty(): return
	var subject: Rect2 = entries[0]["rect"]
	var expected: String = str(entries[0]["tooltip"])
	_move_pointer(IDLE_POINTER)
	await process_frame
	var point: Vector2 = board.get_global_transform_with_canvas() * subject.get_center()
	_move_pointer(point)
	for _frame: int in range(SETTLE_FRAMES): await process_frame
	_expect(canvas.gui_get_hovered_control() == board, "Real pointer reaches the board's " + kind)
	_expect(board.call("_get_tooltip", subject.get_center()) == expected, "Real retained hover regions resolve the " + kind + " tooltip")
	var deadline: int = Time.get_ticks_msec() + int(TOOLTIP_TIMEOUT_SECONDS * 1000.0)
	var popup: Window = _visible_tooltip(board, expected)
	while popup == null and Time.get_ticks_msec() < deadline:
		await process_frame
		popup = _visible_tooltip(board, expected)
	_expect(popup != null, "Godot's real tooltip panel appears over the " + kind)
	if popup != null:
		var embedded: bool = popup.is_embedded() and canvas.get_embedded_subwindows().has(popup)
		_expect(embedded, "The " + kind + " tooltip is embedded in the captured viewport")
		var popup_rect := Rect2(Vector2(popup.position), Vector2(popup.size))
		_expect(Rect2(Vector2.ZERO, Vector2(SIZE)).encloses(popup_rect) and popup_rect.has_area(), "The native " + kind + " tooltip is visible inside the capture")
		_hover_checks.append({"kind": kind, "native": true, "embedded": embedded, "subject_rect": _rect_data(subject), "popup_rect": _rect_data(popup_rect), "tooltip": expected, "lines": _tooltip_lines(popup)})
		await _capture(board, "statuses_hover_" + kind)
		_expect(_visible_tooltip(board, expected) != null, "The native " + kind + " tooltip stays visible through capture")
	_move_pointer(IDLE_POINTER)
	for _frame: int in range(SETTLE_FRAMES): await process_frame
	_expect(_visible_tooltip(board, expected) == null, "Leaving the " + kind + " closes the real tooltip")

func _move_pointer(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.relative = point - canvas.get_mouse_position()
	canvas.push_input(motion, true)

func _visible_tooltip(node: Node, expected: String) -> Window:
	if node is Window and (node as Window).visible and str(node.get("theme_type_variation")) == "TooltipPanel":
		var lines: PackedStringArray = _tooltip_lines(node)
		var expected_lines: PackedStringArray = expected.split("\n")
		if lines.has(expected_lines[0].to_upper()) and lines.has(expected_lines[1]): return node as Window
	for child: Node in node.get_children(true):
		var popup: Window = _visible_tooltip(child, expected)
		if popup != null: return popup
	return null

func _tooltip_lines(node: Node) -> PackedStringArray:
	var lines: PackedStringArray
	if node is Label: lines.append((node as Label).text)
	if node is RichTextLabel: lines.append((node as RichTextLabel).get_parsed_text())
	for child: Node in node.get_children(true): lines.append_array(_tooltip_lines(child))
	return lines

func _catalog_capture(scene: Node, run: Dictionary) -> void:
	var state: Dictionary = run["combat_state"].duplicate(true)
	state["player"].merge({"freeze": 1, "shock": 1, "immobilize": true, "frost_armor": CATALOG_COUNT}, true)
	state["retaliate"] = {"amount": CATALOG_COUNT}
	state["turn_flags"] = {"quicken_pending": CATALOG_COUNT, "next_attack_buffs": [{"damage": CATALOG_COUNT}]}
	state["self_flags"] = {"ice_skate": {}, "anchored": {}, "fire_immune_turn": {}}
	var umbra: Dictionary = (state.get("umbra", {}) as Dictionary).duplicate(true)
	umbra["truesight_activations"] = -1
	state["umbra"] = umbra
	var presentation: Dictionary = {"reduced_motion": true, "umbra_truesight_activations": -1, "surface_status_preview": {"player": {"chilled": true, "shock": 2}}}
	_show_constructed_state(scene, state, presentation)
	await _capture(scene.get("board_view"), "statuses_all")
	var shown: Dictionary = {}
	for actor: Dictionary in _captures.back()["actors"]:
		for entry: Dictionary in actor["statuses"]: shown[entry["icon"]] = true
	for icon: String in ["freeze", "petrify", "shock", "immobilize", "chilled", "bleed", "expose", "truesight", "frost_armor", "retaliate", "quicken", "next_attack", "anchored", "skate", "fireproof"]:
		_expect(shown.has(icon), "Coverage capture contains " + icon)

func _wrapped_capture(scene: Node, run: Dictionary) -> void:
	var state: Dictionary = run["combat_state"].duplicate(true)
	state["player"].merge({"freeze": 1, "shock": 1, "immobilize": true, "frost_armor": CATALOG_COUNT}, true)
	_show_constructed_state(scene, state, {"reduced_motion": true})
	await _capture(scene.get("board_view"), "statuses_wrapped")
	var rows: Array[float]
	for actor: Dictionary in _captures.back()["actors"]:
		if actor["key"] != "player": continue
		_expect((actor["statuses"] as Array).size() >= 5, "Wrapped-row fixture has at least five statuses")
		for status: Dictionary in actor["statuses"]:
			var y: float = float(status["rect"][1])
			if not rows.has(y): rows.append(y)
	rows.sort()
	_expect(rows.size() >= 2, "Wrapped-row capture contains multiple rows")
	for row: int in range(1, rows.size()):
		_expect(is_equal_approx(rows[row] - rows[row - 1], 25.0), "Captured rows retain 22 px pills and 3 px spacing")

func _show_constructed_state(scene: Node, state: Dictionary, overrides: Dictionary) -> void:
	# Keep stage chrome, scheduling/visibility and the production at-rest data.
	# Rebuild only the state-dependent threat projection with its normal producer.
	var board: Control = scene.get("board_view")
	var presentation: Dictionary = (board.get("presentation") as Dictionary).duplicate(true)
	presentation.merge(overrides, true)
	presentation["threats_at_rest"] = Badges.build(Combat.new(), state, state)
	scene.call("_render_board_state", state, presentation)

func _rect_data(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func _entries_data(entries: Array, transform: Transform2D) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for entry: Dictionary in entries:
		result.append({"icon": entry["icon"], "label": entry["label"], "rect": _rect_data(transform * (entry["rect"] as Rect2)), "tooltip": entry["tooltip"]})
	return result

func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)

func _finish() -> void:
	for failure: String in _failures: push_error(failure)
	print("STATUS CAPTURE PROBE RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)

func _crowded_capture(scene: Node, board: Control) -> void:
	await _capture(board, "statuses_crowded_hand")
	var units: Array[Dictionary] = board._hud_layout_units()
	var groups: Array[Dictionary]
	for unit: Dictionary in units:
		var group: Dictionary = board._status_plate_layout.cached_group(str(unit["key"]))
		preload("res://tests/suites/board_hud_group_suite.gd")._check_group(board, unit, group, _expect)
		groups.append({"key": unit["key"], "offset": [group["offset"].x, group["offset"].y], "compacted": group["compacted"], "overlap_area": group["placement"]["overlap_area"], "legal": group["placement"]["legal"]})
	var hand_count: int = 0
	for index: int in range(board.combat_state.get("deck", {}).get("hand", []).size()):
		var card: Control = scene.call("_hand_card_control", index)
		if card == null: continue
		hand_count += 1
		var card_rect: Rect2 = scene.call("_control_visual_global_rect", card)
		for unit: Dictionary in units:
			for piece: Rect2 in board._status_plate_layout.cached_group(str(unit["key"]))["group_rects"]:
				_expect(not card_rect.intersects(board._visual_rect_to_global(piece), false), "Crowded HUD clears every live hand card")
	_expect(hand_count > 0, "Mixed fixture uses a real run scene with its hand up")
	var panel: Control = scene.get("hand_box")
	_expect(panel != null and panel.is_visible_in_tree(), "Live scene exposes its hand reservation")
	if panel != null:
		var position: Vector2 = panel.position
		var previous_reservations: Array[Rect2] = board._status_plate_layout.Groups.screen_reservations(board)
		panel.position += RESERVATION_PROBE_DELTA
		_expect(previous_reservations != board._status_plate_layout.Groups.screen_reservations(board), "Reservation fixture moves actual screen UI")
		board.set_combat_state(board.combat_state, board.move_tiles, board.attack_tiles, board.selected_tile, board.status_label, board.status_detail, board.exit_tiles, board.exit_icon_ids, board.presentation)
		for layer: Control in board._retained_render_layers():
			_expect(is_same(layer.get("_hud_layout_entries_cache"), board._hud_layout_entries_cache), "Reservation-only layout updates reach every retained layer")
		panel.position = position
		board.set_combat_state(board.combat_state, board.move_tiles, board.attack_tiles, board.selected_tile, board.status_label, board.status_detail, board.exit_tiles, board.exit_icon_ids, board.presentation)
	var ordered: Array = board._hud_group_draw_entries(units)
	var previous_y: float = -INF
	var by_key: Dictionary = board._units_by_key(units)
	for entry: Dictionary in ordered:
		if by_key[entry["actor_key"]].get("role") == "player": continue
		var y: float = board._unit_center(by_key[entry["actor_key"]]).y
		_expect(y >= previous_y, "Nearer owner draws over farther groups")
		previous_y = y
	_expect(ordered.back()["actor_key"] == "player", "Hero draws above all unfocused groups")
	for key: String in ["player", "enemy_1"]:
		board.set_controller_focus_tile(by_key[key]["pos"])
		ordered = board._hud_group_draw_entries(units)
		_expect(ordered.back()["actor_key"] == key, "Controller-focused group draws above all: " + key)
		if key == "enemy_1":
			var actual_focus: Rect2 = board.enemy_intent_visual_global_rect(key)
			for entry: Dictionary in board._hud_layout_entries_cache:
				if entry["actor_key"] == key: _expect(actual_focus == board._visual_rect_to_global(entry["layout"]["intent_rect"]), "Focus rect follows the drawn intent")
	board.set_controller_focus_tile(Vector2i(-1, -1))
	board._hover_tile = by_key["enemy_1"]["pos"]
	_expect(board._hud_group_draw_entries(units).back()["actor_key"] == "enemy_1", "Hovered group draws above all")
	board._hover_tile = Vector2i(-1, -1)
	_crowded_states.append({"name": "mixed", "groups": groups, "hand_cards": hand_count})

func _encounter_captures() -> void:
	var suite = preload("res://tests/suites/board_hud_group_suite.gd")
	var boss: Dictionary = _director_run()
	boss["combat_state"] = suite.boss_state()
	var fixtures: Array[Dictionary]
	fixtures.assign([
		{"name": "statuses_air_expanded", "run": suite.warband_run("air"), "expanded": true},
		{"name": "statuses_ice_warband", "run": suite.warband_run("ice"), "expanded": false},
		{"name": "statuses_boss_neighbours", "run": boss, "expanded": false}])
	for fixture: Dictionary in fixtures:
		var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
		canvas.add_child(scene)
		await process_frame
		scene.call("_load_run_state", fixture["run"])
		if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
		await create_timer(SETTLE_SECONDS).timeout
		var board: Control = scene.get("board_view")
		_show_constructed_state(scene, board.combat_state, {"show_all_enemy_intents": fixture["expanded"]})
		await _capture(board, fixture["name"])
		var groups: Array[Dictionary]
		for unit: Dictionary in board._hud_layout_units():
			if unit.get("boss_bar", false) or unit.get("role") == "npc": continue
			var group: Dictionary = board._status_plate_layout.cached_group(str(unit["key"]))
			suite._check_group(board, unit, group, _expect)
			groups.append({"key": unit["key"], "compacted": group["compacted"], "legal": group["placement"]["legal"]})
		_crowded_states.append({"name": fixture["name"], "groups": groups})
		scene.queue_free()
		await process_frame
