extends SceneTree

const Fixture = preload("res://tools/ptf09/real_fixture.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const MANIFEST: String = "/private/tmp/labyrinth_codex/rd-05/inspection.json"
const OUTPUT: String = "/private/tmp/labyrinth_codex/rd-05/proof.json"
const OUTSIDE_POINTER := Vector2(-1000, -1000)
const SETTLE_FRAMES: int = 30
const IDLE_FRAMES: int = 120
const FADE_SETTLE: float = 0.25
const AIM_SETTLE_FRAMES: int = 2
const OVERLAP_DELAY: float = 0.1
const SETTLED_SECONDS: float = 3.0
var failures: Array[String]
var checks: int = 0
var scene: Node
var board: Control
var canvas: SubViewport
var evidence: Dictionary = {}

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	if DisplayServer.get_name() == "headless": process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var manifest: String = args[args.find("--fixture-manifest") + 1] if args.has("--fixture-manifest") else MANIFEST
	_check(FileAccess.file_exists(manifest), "Certified real save manifest exists")
	if not failures.is_empty(): _finish(); return
	Fixture.install_save(manifest)
	canvas = Fixture.make_canvas(self)
	root.set_meta("labyrinth_resume_saved_run", true)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	scene.get_node("BoardUnderlay/CombatBoard").set_script(preload("res://tools/rd05/proof_board.gd"))
	canvas.add_child(scene)
	await _settle(SETTLE_FRAMES)
	board = scene.get("board_view")
	_check(str(scene.get("_run_state").get("mode")) == "combat", "Resumed through production boot")
	_check(is_equal_approx(Typography.ui_scale(scene), 1.0), "100% UI scale")
	_clear_context()
	_setting(Settings.BOARD_HEALTH_CONTEXTUAL)
	board.plate_visibility.advance(SETTLED_SECONDS)
	for unit: Dictionary in board.call("_visible_units"):
		_check(is_zero_approx(board.call("_plate_opacity", unit)), "No plate at rest: " + str(unit["key"]))
	var units: Array = board.call("_visible_units")
	var foe: Dictionary = {}
	for unit: Dictionary in units:
		if str(unit.get("role")) == "enemy" and not bool(unit.get("boss_bar", false)): foe = unit; break
	_check(not foe.is_empty(), "Real fixture includes an ordinary foe")
	if foe.is_empty(): _finish(); return
	var key: String = foe["key"]
	var tile: Vector2i = foe["pos"]
	var measured: Array = Badges.layouts(board, board.presentation.get("threats_at_rest", {}).get("badges", []))
	for badge: Dictionary in measured:
		var actor: Dictionary = board.call("_units_by_key", units).get(str(badge["key"]), {})
		var moved: Rect2 = board.plate_visibility.feet_rect(board, actor, badge["order_rect"])
		var front: float = -INF
		for part: Vector2i in board.call("_unit_footprint_tiles", actor):
			for point: Vector2 in board.call("_tile_polygon", part): front = maxf(front, point.y)
		_check(is_equal_approx(moved.get_center().y, front - 0.22 * float(board.call("_tile_height"))), "Badge at footprint front: " + str(actor["key"]))
		_check(moved.size == (badge["order_rect"] as Rect2).size, "Badge art dimensions preserved")
		var layout: Dictionary = board.get("_status_plate_layout").resolve(board, actor, board.call("_unit_health_bar_rect", actor, board.call("_unit_center", actor)))
		var entries: Array = board.plate_visibility.rest_entries(layout, moved)
		var x: float = moved.end.x + 4.0
		for entry: Dictionary in entries:
			_check(is_equal_approx(entry["rect"].position.x, x) and is_equal_approx(entry["rect"].get_center().y, moved.get_center().y), "Rest row has 4px gap and vertical centering")
			x = entry["rect"].end.x + 4.0
	# All actual input hooks, with deterministic animation advancement.
	for kind: String in ["tile", "body", "chip"]:
		_clear_context()
		var point: Vector2 = board.call("world_position_for_tile", tile)
		if kind == "body": point = (board.call("_unit_draw_rect", foe) as Rect2).get_center()
		if kind == "chip":
			for badge: Dictionary in measured:
				if str(badge["key"]) == key: point = badge["center"]
		var event := InputEventMouseMotion.new()
		event.position = point
		board.call("_gui_input", event)
		board.plate_visibility.advance(FADE_SETTLE)
		_check(board.plate_visibility.opacity(key) == 1.0, kind + " hover reveals plate")
		board.mouse_exited.emit()
		board.plate_visibility.advance(FADE_SETTLE)
		_check(board.plate_visibility.opacity(key) == 0.0, kind + " pointer exit hides plate despite retained tile hover")
	_clear_context()
	for slot: Control in (scene.get("_turn_order_bar") as Control).get_children():
		if str(slot.get_meta("rd05_actor_key", "")) == key:
			slot.mouse_entered.emit()
			board.plate_visibility.advance(FADE_SETTLE)
			_check(board.plate_visibility.opacity(key) == 1.0, "Rail portrait hover reveals plate")
			slot.focus_entered.emit()
			slot.mouse_exited.emit()
			board.plate_visibility.advance(FADE_SETTLE)
			_check(board.plate_visibility.opacity(key) == 1.0, "Rail controller focus survives pointer exit")
			slot.focus_exited.emit()
			break
	_clear_context()
	board.call("set_controller_focus_tile", tile)
	board.plate_visibility.advance(FADE_SETTLE)
	_check(board.plate_visibility.opacity(key) == 1.0, "Controller focus reveals plate")
	_clear_context()
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "controller", "steam_deck")
	scene.set("_controller_region", "board")
	scene.call("_controller_set_board_tile", tile)
	board.plate_visibility.advance(FADE_SETTLE)
	_check(board.plate_visibility.opacity(key) == 1.0, "Steam Deck controller navigation reveals focused unit")
	router.call("set_forced_state_for_test", "pointer", "desktop")
	_clear_context()
	scene.call("_on_enemy_intent_toggle_toggled", true)
	board.plate_visibility.refresh()
	board.plate_visibility.advance(FADE_SETTLE)
	for unit: Dictionary in units: _check(board.plate_visibility.opacity(str(unit["key"])) == 1.0, "Details shows every plate")
	scene.call("_on_enemy_intent_toggle_toggled", false)
	_clear_context()
	await _aiming_checks()
	_clear_context()
	await _change_checks(foe)
	_clear_context()
	_setting(Settings.BOARD_HEALTH_ALWAYS)
	var always_intents: Array = Badges.layouts(board, board.presentation.get("threats_at_rest", {}).get("badges", []))
	for unit: Dictionary in board.call("_visible_units"): _check(board.plate_visibility.opacity(str(unit["key"])) == 1.0, "Always applies immediately mid-fight")
	_setting(Settings.BOARD_HEALTH_CONTEXTUAL)
	board.plate_visibility.advance(FADE_SETTLE)
	var contextual_intents: Array = Badges.layouts(board, board.presentation.get("threats_at_rest", {}).get("badges", []))
	_check(always_intents == contextual_intents, "Intent chip geometry unchanged across settings")
	_rail_checks()
	# Isolate periodic scene scheduling; retain normal board idle/ambient work.
	scene.set_process(false)
	var counts: Array = []
	for setting: String in [Settings.BOARD_HEALTH_ALWAYS, Settings.BOARD_HEALTH_CONTEXTUAL]:
		_setting(setting)
		board.plate_visibility.advance(SETTLED_SECONDS)
		await _settle(SETTLE_FRAMES)
		board.set("_continuous_presentation_elapsed", 0.0)
		board.set("_idle_elapsed", 0.0)
		board.set("redraw_requests", {})
		var visibility_redraws: int = board.plate_visibility.redraw_requests
		await _settle(IDLE_FRAMES)
		counts.append((board.get("redraw_requests") as Dictionary).duplicate())
		_check(board.plate_visibility.redraw_requests == visibility_redraws, "No visibility invalidation over 120 idle frames: " + setting)
	evidence["idle_redraw_requests"] = counts
	_check(counts[0] == counts[1], "120 idle frames have equal board redraw counts in both settings")
	_finish()

func _aiming_checks() -> void:
	for index: int in range(4):
		await scene.call("_on_card_pressed", index)
		await _settle(AIM_SETTLE_FRAMES)
		var preview: Dictionary = scene.call("_active_card_preview")
		var keys: Array = scene.get("_board_plate_aim").affected(scene, preview)
		board.plate_visibility.refresh()
		board.plate_visibility.advance(FADE_SETTLE)
		var card: String = str(scene.call("_card_id_for_hand_index", index))
		evidence[card] = keys.duplicate()
		_check(not keys.is_empty(), "Nonempty aiming set: " + card)
		for key: String in keys: _check(board.plate_visibility.opacity(key) == 1.0, "Aiming reveals affected unit: " + key)
		if index == 0:
			var expected: Array[String]
			var targets: Array = preview.get("target_tiles", [])
			for unit: Dictionary in board.call("_visible_units"):
				if str(unit.get("role")) != "enemy": continue
				for tile: Vector2i in board.call("_unit_footprint_tiles", unit):
					if targets.has(tile) and not expected.has(str(unit["key"])): expected.append(str(unit["key"]))
			expected.sort()
			var sorted: Array = keys.duplicate(); sorted.sort()
			_check(sorted == expected, "Single target set equals all valid foes")
		if index in [1, 2]:
			var expected: Array[String]
			var tiles: Array[Vector2i]
			var state: Dictionary = preview.get("state", {})
			if index == 1:
				for tile: Vector2i in preview.get("target_tiles", []):
					for part: Vector2i in scene.call("_aoe_tiles_for_action", state, preview.get("action", {}), tile):
						if not tiles.has(part): tiles.append(part)
			else:
				tiles.assign(scene.get("_preview_shortcuts_cache").get("tiles", []))
				expected.append("player")
			for unit: Dictionary in board.call("_visible_units"):
				if str(unit.get("role")) != "enemy": continue
				for tile: Vector2i in board.call("_unit_footprint_tiles", unit):
					if tiles.has(tile) and not expected.has(str(unit["key"])): expected.append(str(unit["key"]))
			expected.sort()
			var sorted: Array = keys.duplicate(); sorted.sort()
			_check(sorted == expected, "Exact area/reachable-strike union: " + card)
		if index == 3: _check(keys == ["player"], "Self-only card shows hero alone")
		await scene.call("_on_cancel_requested")
		_clear_context()

func _change_checks(foe: Dictionary) -> void:
	var original: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	for field: String in ["hp", "block", "bleed"]:
		var state: Dictionary = original.duplicate(true)
		for enemy: Dictionary in state["enemies"]:
			if int(enemy["id"]) == int(foe["id"]): enemy[field] = int(enemy.get(field, 0)) + (-1 if field == "hp" else 1)
		board.plate_visibility.observe(original, {})
		board.call("set_health_ghost_source_state", state)
		board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, board.presentation)
		board.plate_visibility.refresh()
		board.plate_visibility._clock.set_process(false)
		board.plate_visibility.advance(0.12)
		_check(board.plate_visibility.opacity(str(foe["key"])) == 1.0, "Changed " + field + " reveals plate through animation")
		var animation: float = 0.9 if field == "hp" else 0.0
		board.plate_visibility.advance(animation + 0.98)
		_check(board.plate_visibility.opacity(str(foe["key"])) == 1.0, "Changed " + field + " still shown at 1.1s after animation")
		board.plate_visibility.advance(0.35)
		_check(is_zero_approx(board.plate_visibility.opacity(str(foe["key"]))), "Changed " + field + " gone by 1.45s after animation")
		board.call("set_health_ghost_source_state", original)
		board.call("set_combat_state", original, [], [], Vector2i(-1, -1), "", "", {}, {}, board.presentation)
		board.health_ghost_tracker.advance(SETTLED_SECONDS)
		board.plate_visibility.advance(SETTLED_SECONDS)

	# A later status event cannot truncate the hold belonging to a health ghost.
	var damaged: Dictionary = original.duplicate(true)
	for enemy: Dictionary in damaged["enemies"]:
		if int(enemy["id"]) == int(foe["id"]): enemy["hp"] = int(enemy["hp"]) - 1
	board.call("set_health_ghost_source_state", damaged)
	board.call("set_combat_state", damaged, [], [], Vector2i(-1, -1), "", "", {}, {}, board.presentation)
	board.plate_visibility.refresh()
	board.plate_visibility.advance(OVERLAP_DELAY)
	var guarded: Dictionary = damaged.duplicate(true)
	for enemy: Dictionary in guarded["enemies"]:
		if int(enemy["id"]) == int(foe["id"]): enemy["block"] = int(enemy.get("block", 0)) + 1
	board.call("set_health_ghost_source_state", guarded)
	board.call("set_combat_state", guarded, [], [], Vector2i(-1, -1), "", "", {}, {}, board.presentation)
	board.plate_visibility.refresh()
	board.plate_visibility.advance(0.9 + 1.1 - OVERLAP_DELAY)
	_check(board.plate_visibility.opacity(str(foe["key"])) == 1.0, "Status during ghost preserves its full 1.2s after-animation hold")
	board.plate_visibility.advance(0.35)
	_check(is_zero_approx(board.plate_visibility.opacity(str(foe["key"]))), "Overlapping change still finishes its fade")
	board.call("set_health_ghost_source_state", original)
	board.call("set_combat_state", original, [], [], Vector2i(-1, -1), "", "", {}, {}, board.presentation)
	board.health_ghost_tracker.advance(SETTLED_SECONDS)
	board.plate_visibility.advance(SETTLED_SECONDS)

func _rail_checks() -> void:
	var found_hero: bool = false
	for slot: Control in (scene.get("_turn_order_bar") as Control).get_children():
		var numeral: Control = slot.get_node_or_null("TurnOrderHealthNumeral")
		var bar: Control = slot.get_node_or_null("TurnOrderHealthBar")
		if bar == null: continue
		_check(numeral != null, "Every shown rail health bar has a numeral")
		if numeral == null: continue
		_check(numeral.position == bar.position and numeral.size == bar.size, "Health numeral right-aligns to mini bar")
		if str(slot.get_meta("rd05_actor_key", "")) == "player":
			found_hero = true
			var hero: Dictionary = (scene.get("_combat_state") as Dictionary)["player"]
			_check(numeral.get("text") == "%d/%d" % [hero["hp"], hero["max_hp"]], "Hero numeral is current/max")
	_check(found_hero, "Hero is present in the real rail")

func _clear_context() -> void:
	if board == null: return
	board.set("_hover_tile", Vector2i(-1, -1))
	board.call("set_controller_focus_tile", Vector2i(-1, -1))
	board.plate_visibility.pointer_keys.clear()
	board.plate_visibility.external_keys.clear()
	board.plate_visibility.refresh()
	board.plate_visibility.advance(SETTLED_SECONDS)

func _setting(value: String) -> void:
	var settings: Dictionary = Settings.default_settings()
	settings["board_health_bars"] = value
	Settings.apply_settings(settings, null, false)

func _settle(frames: int) -> void:
	for frame: int in range(frames): await process_frame

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _finish() -> void:
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "evidence": evidence}, "\t"))
	file.close()
	for failure: String in failures: push_error(failure)
	print("RD05 PLATE VISIBILITY: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	if is_instance_valid(scene): scene.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
