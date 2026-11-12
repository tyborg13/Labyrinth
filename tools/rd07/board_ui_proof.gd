extends "res://tools/rd05/plate_visibility_proof.gd"

const Placement = preload("res://scripts/intent_chip_placement.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const COMBAT: String = "/private/tmp/labyrinth_codex/rd-07/combat.json"
const DRAGON: String = "/private/tmp/labyrinth_codex/rd-07/dragon.json"
const RESULT: String = "/private/tmp/labyrinth_codex/rd-07/proof.json"
const HERO_BLOCK: int = 7
const ENEMY_BLEED: int = 2
const ENEMY_EXPOSE: int = 1
const EDGE_SETTLE_SECONDS: float = 0.16

func _run() -> void:
	Fixture.install_save(COMBAT)
	canvas = Fixture.make_canvas(self)
	root.set_meta("labyrinth_resume_saved_run", true)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	scene.get_node("BoardUnderlay/CombatBoard").set_script(preload("res://tools/rd05/proof_board.gd"))
	canvas.add_child(scene)
	await _settle(SETTLE_FRAMES)
	board = scene.get("board_view")
	_check(board != null and str(scene.get("_run_state").get("mode")) == "combat", "Production boot from certified combat save")
	if board == null: _finish(); return
	var composition: Dictionary = preload("res://tools/rd07/fixture.gd").open_composition(board)
	_check(bool(composition.hero_clear) and int(composition.clear_foes) >= 2 and int(composition.foes) in [4, 5], "Standard real fight has clear hero and at least two clear ordinary foes")
	evidence["composition"] = composition
	_setting(Settings.BOARD_HEALTH_CONTEXTUAL)
	_clear_context()
	var prop: Dictionary = board.combat_state.terrain[0]
	var prop_key: String = board.plate_visibility.terrain_key(prop)
	var foe: Dictionary = _foe()
	var key: String = foe.key
	_check(board.plate_visibility.opacity(prop_key) == 0.0, "Prop bar hidden at rest")
	await _hover(board.call("world_position_for_tile", prop.pos))
	_check(board.plate_visibility.opacity(prop_key) == 1.0, "Prop footprint hover reveals its own bar")
	_clear_context()
	await _hover((board.call("_terrain_rect_for_tile", prop.pos, board.get("_terrain_textures").get(prop.kind), prop.kind) as Rect2).get_center())
	_check(board.plate_visibility.opacity(prop_key) == 1.0, "Prop body hover reveals its own bar")
	_clear_context()
	await _hover(board.call("world_position_for_tile", foe.pos))
	_check(board.plate_visibility.opacity(prop_key) == 0.0, "Adjacent enemy hover never reveals prop")
	_check(board.plate_visibility.opacity(key) == 1.0, "Enemy hover reveals its own plate")
	_rail_highlight(key)
	_clear_context()
	await create_timer(EDGE_SETTLE_SECONDS).timeout
	for slot: Control in (scene.get("_turn_order_bar") as Control).get_children():
		if str(slot.get_meta("rd05_actor_key", "")) == key:
			_check(slot.get_node("TurnOrderSlashEdge").get("color") == slot.get_meta("rd07_resting_edge"), "Rail edge returns after 0.12s ease-out")
	await _hover((board.call("_unit_draw_rect", foe) as Rect2).get_center())
	_check(board.plate_visibility.inspected(key), "Enemy body hover inspects actor")
	_clear_context()
	board.call("set_controller_focus_tile", prop.pos)
	board.plate_visibility.refresh(); board.plate_visibility.advance(FADE_SETTLE)
	_check(board.plate_visibility.opacity(prop_key) == 1.0, "Controller focus reveals prop")
	_clear_context()
	var prior: Dictionary = board.combat_state.duplicate(true)
	var changed: Dictionary = prior.duplicate(true)
	changed.terrain[0].hp = int(changed.terrain[0].hp) - 1
	board.plate_visibility.observe(prior, {})
	board.plate_visibility.observe(changed, {})
	board.plate_visibility.advance(0.12)
	_check(board.plate_visibility.opacity(prop_key) == 1.0, "Prop Health change reveals bar")
	board.plate_visibility.advance(1.0)
	_check(board.plate_visibility.opacity(prop_key) == 1.0, "Prop Health hold lasts 1.2 seconds")
	board.plate_visibility.advance(0.35)
	_check(board.plate_visibility.opacity(prop_key) == 0.0, "Prop Health hold expires")
	board.plate_visibility.observe(prior, {})
	board.plate_visibility.advance(SETTLED_SECONDS)
	var status_only: Dictionary = prior.duplicate(true)
	status_only.terrain[0].block = HERO_BLOCK
	board.plate_visibility.observe(status_only, {})
	board.plate_visibility.advance(FADE_SETTLE)
	_check(board.plate_visibility.opacity(prop_key) == 0.0, "Prop status-only change does not reveal Health bar")
	board.plate_visibility.observe(prior, {})
	# These are named debug-only status fixture values on a real resumed fight.
	var state: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	state.player.block = HERO_BLOCK
	state.enemies[0].bleed = ENEMY_BLEED
	state.enemies[0].expose = ENEMY_EXPOSE
	scene.set("_combat_state", state)
	scene.call("_refresh_stage_view")
	await _settle(SETTLE_FRAMES)
	_clear_context()
	for actor_key: String in ["player", key]: await _status_checks(actor_key)
	_clear_context()
	var compact: Dictionary = _badge(key)
	_check(bool(compact.contextual) and not bool(compact.unfurled), "Default marker is compact")
	_check((compact.rect as Rect2).size == Vector2.ONE * Badges.MEDALLION_DIAMETER, "Compact marker contains only today's icon disc")
	_anchor(foe)
	var rest_anchor: Vector2 = _badge(key).center
	var motion_offset: Vector2 = (board.call("world_position_for_tile", foe.pos + Vector2i.RIGHT) as Vector2) - (board.call("world_position_for_tile", foe.pos) as Vector2)
	var old_positions: Dictionary = board.presentation.get("unit_world_positions", {}).duplicate()
	board.presentation["unit_world_positions"] = old_positions.duplicate()
	board.presentation.unit_world_positions[key] = (board.call("world_position_for_unit_origin", foe, foe.pos) as Vector2) + motion_offset
	_check(Placement.compact_anchor(board, foe) == rest_anchor + motion_offset, "Compact anchor follows existing unit world interpolation")
	board.presentation["unit_world_positions"] = old_positions
	_check(Badges.ring_color({"danger": true}) == Palette.DANGER, "Danger ring keeps existing red token")
	_check(Badges.ring_color({"danger": false, "family": "attack"}) == Palette.GOLD, "Neutral attack keeps existing ring token")
	var danger_keys: Array[String]
	var neutral_keys: Array[String]
	for badge: Dictionary in Badges.layouts(board, board.presentation.threats_at_rest.badges):
		if bool(badge.get("danger", false)):
			danger_keys.append(str(badge.key))
			_check(Badges.ring_color(badge) == Palette.DANGER, "Real threatening marker has red ring")
		else: neutral_keys.append(str(badge.key))
	_check(not danger_keys.is_empty() and not neutral_keys.is_empty(), "Real fixture has dangerous and neutral intents")
	evidence["danger_keys"] = danger_keys
	evidence["neutral_keys"] = neutral_keys
	var center: Vector2 = compact.center
	await _hover(center)
	_check(bool(_badge(key).unfurled), "Marker hover unfurls")
	_check(_badge(key).center == center, "Disc fixed during unfurl")
	_rail_highlight(key)
	await _tab_checks(key, true)
	_clear_context()
	await _settle(SETTLE_FRAMES)
	await _tab_checks(key, false)
	_check(_badge(key).center == center, "Disc fixed after refurl")
	board.plate_visibility._entry(key).hold = 1.2
	board.plate_visibility.refresh()
	_check(not bool(_badge(key).unfurled), "Post-change hold does not unfurl")
	var previous_expanded: Array = board.presentation.get("expanded_enemy_actor_keys", [])
	board.presentation["expanded_enemy_actor_keys"] = [key]
	_check(not bool(_badge(key).unfurled), "Legacy expanded/pinned plans alone do not unfurl marker")
	board.presentation["expanded_enemy_actor_keys"] = previous_expanded
	_clear_context()
	board.call("set_controller_focus_tile", foe.pos)
	board.plate_visibility.refresh()
	_check(bool(_badge(key).unfurled), "Controller focus unfurls")
	_clear_context()
	for slot: Control in (scene.get("_turn_order_bar") as Control).get_children():
		if str(slot.get_meta("rd05_actor_key", "")) != key: continue
		slot.mouse_entered.emit()
		_check(bool(_badge(key).unfurled), "Rail hover unfurls")
		slot.mouse_exited.emit()
		break
	_clear_context()
	await scene.call("_on_card_pressed", 0)
	await _settle(AIM_SETTLE_FRAMES)
	board.plate_visibility.refresh()
	board.plate_visibility.advance(FADE_SETTLE)
	await create_timer(EDGE_SETTLE_SECONDS).timeout
	var focus: RefCounted = board.get("_aim_focus")
	for record: Dictionary in focus.canvases.values():
		if bool(record.get("top", false)): continue # callout canvas: never dims, topmost
		if not is_instance_valid(record.canvas) or not record.canvas.visible or not record.hud: continue
		if focus.full_strength(board, record.unit): continue
		_check(is_equal_approx(record.canvas.self_modulate.a, 0.5), "Non-affectable HUD steps back to 50 percent")
		for child: Node in record.canvas.get_children():
			if str(child.name).begins_with("IntentTab_"): _check(is_equal_approx(child.modulate.a, 0.5), "Intent tab inherits HUD step-back")
	for aimed: String in board.presentation.get("plate_aim_actor_keys", []):
		_check(board.plate_visibility.opacity(aimed) == 1.0, "Aim actor participates in visibility: " + aimed)
		if aimed.begins_with("enemy_"): _check(not bool(_badge(aimed).get("unfurled", false)), "Whole aim set does not unfurl: " + aimed)
	await _hover(board.call("world_position_for_tile", foe.pos))
	_check(bool(_badge(key).unfurled), "Selected card hovered target unfurls")
	_check(board.plate_visibility.opacity(prop_key) == (1.0 if board.presentation.get("plate_aim_actor_keys", []).has(prop_key) else 0.0), "Prop uses same selected-card affectable set")
	await scene.call("_on_cancel_requested")
	_clear_context()
	scene.call("_on_enemy_intent_toggle_toggled", true)
	board.plate_visibility.refresh(); board.plate_visibility.advance(FADE_SETTLE)
	_check(board.plate_visibility.opacity(prop_key) == 1.0, "Details reveals prop")
	for badge: Dictionary in Badges.layouts(board, board.presentation.threats_at_rest.badges): _check(bool(badge.unfurled), "Details unfurls every marker")
	scene.call("_on_enemy_intent_toggle_toggled", false)
	_clear_context()
	var frame_positions: Array = []
	for setting: String in [Settings.BOARD_HEALTH_ALWAYS, Settings.BOARD_HEALTH_CONTEXTUAL]:
		_setting(setting)
		frame_positions.append(board.get("_hud_health_rects_cache").duplicate(true))
		var source: String = FileAccess.get_file_as_string("res://scripts/combat_board_view.gd")
		var order_body: String = source.get_slice("func _draw_slice_intent_orders", 1).get_slice("\nfunc ", 0)
		_check(not order_body.contains("draw_order_disc"), "No ordinal paint path in " + setting)
		if setting == Settings.BOARD_HEALTH_ALWAYS:
			for badge: Dictionary in Badges.layouts(board, board.presentation.threats_at_rest.badges):
				_check(not bool(badge.get("contextual", false)), "Always retains original full chip solver")
				_check(badge.placement != "footprint_front", "Always retains original placement")
			for unit: Dictionary in board.call("_visible_units"): _check(board.plate_visibility.opacity(str(unit.key)) == 1.0, "Always retains full plates")
	_check(frame_positions[0] == frame_positions[1], "Bar positions identical across settings")
	_setting(Settings.BOARD_HEALTH_CONTEXTUAL)
	_rail_checks()
	await _idle_counts()
	# Multi-tile anchor proof is taken in Zekarion's certified production arena.
	scene.queue_free(); await process_frame
	preload("res://tools/rd07/fixture.gd").install_dragon(DRAGON)
	scene = Fixture.resume(self, canvas)
	await _settle(SETTLE_FRAMES)
	board = scene.get("board_view")
	_setting(Settings.BOARD_HEALTH_CONTEXTUAL)
	for unit: Dictionary in board.call("_visible_units"):
		if str(unit.get("type")) != "zekarion": continue
		_check((board.call("_unit_footprint_tiles", unit) as Array).size() > 1, "Zekarion has a multi-tile footprint")
		_anchor(unit)
	_finish()

func _foe() -> Dictionary:
	for unit: Dictionary in board.call("_visible_units"):
		if str(unit.get("role")) == "enemy": return unit
	return {}

func _badge(key: String) -> Dictionary:
	for badge: Dictionary in Badges.layouts(board, board.presentation.get("threats_at_rest", {}).get("badges", [])):
		if str(badge.key) == key: return badge
	return {}

func _hover(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	board.call("_gui_input", motion)
	board.plate_visibility.advance(FADE_SETTLE)
	await _settle(AIM_SETTLE_FRAMES)

func _anchor(unit: Dictionary) -> void:
	var xs: Array[float]
	var front: float = -INF
	for tile: Vector2i in board.call("_unit_footprint_tiles", unit):
		for point: Vector2 in board.call("_tile_polygon", tile): xs.append(point.x); front = maxf(front, point.y)
	xs.sort()
	var expected := Vector2((xs.front() + xs.back()) * 0.5, front - 0.12 * float(board.call("_tile_height")))
	_check(_badge(str(unit.key)).get("center") == expected, "Exact footprint-front marker anchor: " + str(unit.key))
	evidence[str(unit.key) + "_anchor"] = str(expected)

func _status_checks(key: String) -> void:
	_clear_context()
	var actor: Dictionary = board.call("_units_by_key", board.call("_visible_units")).get(key, {})
	var layout: Dictionary = board.get("_status_plate_layout").resolve(board, actor, board.call("_unit_health_bar_rect", actor, board.call("_unit_center", actor)))
	var rest: Array = board.plate_visibility.rest_entries(layout, Rect2())
	_check(rest.size() >= (1 if key == "player" else 2), "Status fixture coverage: " + key)
	for entry: Dictionary in rest:
		var point: Vector2 = (entry.rect as Rect2).get_center()
		_check(not str(entry.tooltip).is_empty(), "Status has keyword/full tooltip: " + str(entry.icon))
		# Headless renderer still submits retained draw commands and hit regions.
		await _settle(AIM_SETTLE_FRAMES)
		_check(str(board.call("_get_tooltip", point)) == str(entry.tooltip), "Status tooltip at rest: " + str(entry.icon))
		await _hover(point)
		_check(board.plate_visibility.inspected(key), "Status pointer counts as unit hover: " + key)
		_rail_highlight(key)
		if key.begins_with("enemy_"):
			_check(board.get("_hud_health_rects_source_snapshot").get("hover_actor_key") == key, "Status hover refreshes focused intent/title layout")
		var shown: Dictionary = board.get("_status_plate_layout").resolve(board, actor, board.call("_unit_health_bar_rect", actor, board.call("_unit_center", actor)))
		var entries: Array = board.plate_visibility.rest_entries(shown, Rect2())
		_check(entries == rest, "Status/defense positions identical to pixel: " + key)
		_check(str(board.call("_get_tooltip", point)) == str(entry.tooltip), "Status tooltip while shown: " + str(entry.icon))
		_clear_context()

func _rail_highlight(key: String) -> void:
	var found: int = 0
	for slot: Control in (scene.get("_turn_order_bar") as Control).get_children():
		if str(slot.get_meta("rd05_actor_key", "")) != key: continue
		found += 1
		_check(slot.get_node("TurnOrderSlashEdge").get("color") == Palette.GOLD_BRIGHT, "Every rail occurrence highlights: " + key)
		_check(slot.scale == Vector2.ONE, "Highlight never scales rail")
	_check(found > 0, "Hovered actor appears in rail")

func _tab_checks(key: String, expanded: bool) -> void:
	var anchor: Vector2 = _badge(key).center
	await create_timer(EDGE_SETTLE_SECONDS).timeout
	_check(_badge(key).center == anchor, "Animation leaves disc fixed to pixel")
	var found: int = 0
	for record: Dictionary in board.get("_aim_focus").canvases.values():
		if not is_instance_valid(record.canvas) or not record.canvas.visible: continue
		var tab: Control = record.canvas.get_node_or_null(NodePath("IntentTab_" + key))
		if tab == null: continue
		found += 1
		_check(tab.clip_contents and is_equal_approx(float(tab.get("reveal")), 1.0 if expanded else 0.0), "Tab clips and settles in 0.12s")
		_check(is_equal_approx(tab.size.x, float(tab.get("width")) * float(tab.get("reveal"))), "Tab reveal clips exactly at animated width")
		_check(is_equal_approx(tab.get("ink").position.x, -float(tab.get("width")) * (1.0 - float(tab.get("reveal")))), "Tab contents slide out to right")
	_check(found > 0, "Real retained marker owns tab canvas")

func _idle_counts() -> void:
	scene.set_process(false)
	var counts: Array = []
	for setting: String in [Settings.BOARD_HEALTH_ALWAYS, Settings.BOARD_HEALTH_CONTEXTUAL]:
		_setting(setting); _clear_context()
		board.plate_visibility.advance(SETTLED_SECONDS)
		await _settle(SETTLE_FRAMES)
		board.set("_continuous_presentation_elapsed", 0.0)
		board.set("_idle_elapsed", 0.0)
		# Match both the idle clock and its last submitted frame indices. Resetting
		# just the clock adds a phase-jump redraw to only one measured window.
		board.set("_idle_frame_by_source", board.call("_active_idle_frames_by_source"))
		board.set("redraw_requests", {})
		var before: int = board.plate_visibility.redraw_requests
		await _settle(IDLE_FRAMES)
		counts.append(board.get("redraw_requests").duplicate())
		_check(board.plate_visibility.redraw_requests == before, "No visibility redraws in 120 idle frames: " + setting)
	evidence["idle_redraw_requests"] = counts
	_check(counts[0] == counts[1], "120 idle frames have identical redraw counts")
	print("RD07 IDLE REDRAWS: " + JSON.stringify(counts))

func _finish() -> void:
	var file := FileAccess.open(RESULT, FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "evidence": evidence}, "\t"))
	for failure: String in failures: push_error(failure)
	print("RD07 BOARD UI: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	if is_instance_valid(scene): scene.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

# Clear through the real pointer/scene hook as well as the controller. Directly
# clearing only the board's tile would leave RunScene's focused threat cached.
func _clear_context() -> void:
	if board == null: return
	Fixture.pointer(self, board, OUTSIDE_POINTER)
	board.call("_update_hover_at", OUTSIDE_POINTER)
	super._clear_context()
