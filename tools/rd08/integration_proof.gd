extends "res://tools/rd04/threat_isolation_proof.gd"

const TileTooltips = preload("res://scripts/board_tile_tooltip.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const ROOT: String = "/private/tmp/labyrinth_codex/rd-08"
const FADE_SETTLE: float = 0.25

func _run() -> void:
	output_dir = ROOT
	manifest = ROOT + "/overlap.json"
	Fixture.install_save(manifest)
	canvas = Fixture.make_canvas(self)
	scene = Fixture.resume(self, canvas)
	await _settle()
	board = scene.get("board_view")
	var found: Dictionary = Cases.find(board)
	print("RD08 CASE: enemy=", found.enemy.get("id", -1), " overlap=", found.overlap, " empty=", found.empty)
	_check(not found.enemy.is_empty() and found.overlap.x >= 0, "Real certified overlap fight")
	if found.enemy.is_empty() or found.overlap.x < 0: _finish(); return
	var key: String = "enemy_%d" % int(found.enemy.id)
	var roster_before: Array = board.call("_visible_units").duplicate()
	Isolation.enemy_at_point(board, Vector2.ZERO)
	_check(board.call("_visible_units") == roster_before, "Read-only enemy hit testing preserves retained actor order")
	for layer: Control in board.get("_scene_render_layers"):
		for slice: Control in layer.get("_layer_slices").canvases:
			_check(slice.show_behind_parent, "Tile slices precede the original team/body canvas")
			for operation: Array in slice.get("_render_slice_ops"):
				_check(str(operation[0]) != "_draw_unit_body", "Team body pass owns each unit exactly once")
	for setting: String in [Settings.BOARD_HEALTH_ALWAYS, Settings.BOARD_HEALTH_CONTEXTUAL]:
		Settings._applied_board_health_bars = setting
		await _hover(found.empty)
		board.plate_visibility.advance(FADE_SETTLE)
		var chip: Dictionary = _badge(key)
		_check(not chip.is_empty(), setting + ": intent exists")
		if chip.is_empty(): continue
		Fixture.pointer(self, board, chip.rect.get_center())
		await _settle()
		board.plate_visibility.advance(FADE_SETTLE)
		_expect_keys([key], setting + ": disc/chip routes enemy hover")
		_check(board.plate_visibility.inspected(key) and board.plate_visibility.opacity(key) == 1.0, "Disc hover opens own plate")
		_check(_expanded(key), "Disc hover unfurls intent")
		_assert_no_enemy_tooltip(Isolation.enemy_at_tile(board, found.enemy.pos), setting)
		_check(board.get("_hud_health_rects_source_snapshot").get("hover_actor_key") == key, "Focused intent title stays bound to the hovered enemy")
		_check(not (board.presentation.get("enemy_threat_previews", []) as Array).is_empty(), "Hovered enemy still presents its move/attack plan")
		_check(board.get("_occlusion_silhouettes").team.entries.has(key), "Hovered enemy keeps its team outline")
		var slot: Control = _rail_slot(key)
		var edge: Control = slot.get_meta("perf03_retained_parts").edge
		var prior: Tween = slot.get_meta("rd07_edge_tween") if slot.has_meta("rd07_edge_tween") else null
		Isolation.update_rail(scene, [key])
		board.plate_visibility.set_external(key, true, "rd08-union")
		Isolation.update_rail(scene, [])
		_check(edge.color == Palette.GOLD_BRIGHT, "Hovered actor stays lit when isolation leaves")
		_check((slot.get_meta("rd07_edge_tween") if slot.has_meta("rd07_edge_tween") else null) == prior, "No second animation when both rail causes apply")
		board.plate_visibility.set_external(key, false, "rd08-union")
		await _hover(found.overlap)
		var attackers: Array[String] = Isolation.tile_keys(board, found.overlap)
		_expect_keys(attackers, setting + ": reverse lookup isolates telegraphs")
		for attacker: String in attackers: _check(_expanded(attacker), setting + ": reverse lookup unfurls " + attacker)
		await _hover(found.empty)
		await create_timer(RAIL_RETURN_SETTLE_SECONDS).timeout
		_check(edge.color.is_equal_approx(slot.get_meta("rd07_resting_edge")), "Unified rail returns to exact rest")
	Settings._applied_board_health_bars = Settings.BOARD_HEALTH_CONTEXTUAL
	await scene.call("_on_card_pressed", 0)
	await _settle()
	await create_timer(FADE_SETTLE).timeout
	var focus: RefCounted = board.get("_aim_focus")
	_check(focus.active, "Production ranged aim activates focus")
	var overlay: Node2D = board.get("_occlusion_silhouettes")
	var stepped_back: int = 0
	for unit: Dictionary in board.call("_visible_units"):
		var expected: float = 1.0 if focus.full_strength(board, unit) else 0.5
		if expected == 0.5: stepped_back += 1
		var actor: String = unit.key
		_check(is_equal_approx(overlay.unit_alpha_multiplier(actor), expected), "Aim outline multiplier " + actor)
		if overlay.team.entries.has(actor): _check(is_equal_approx(overlay.team.entries[actor].base_alpha, 0.8 * expected), "Team outline receives same multiplier " + actor)
		if overlay.entries.has(actor): _check(is_equal_approx(overlay.entries[actor].sprite.material.get_shader_parameter("rim_color").a, 0.85 * expected), "X-ray receives same multiplier " + actor)
	_check(stepped_back > 0, "Real aimed card leaves foes out of reach")
	# Exercise the production outline transition at exact half/full duration.
	for record: Dictionary in focus.canvases.values():
		if bool(record.get("top", false)): continue # callout canvas: never dims, topmost
		if focus.full_strength(board, record.unit): continue
		var actor: String = record.unit.key
		overlay.set_unit_alpha_multiplier(actor, 1.0)
		focus.get("_outline_targets").erase(actor)
		focus.call("_present", record)
		var motion: Tween = focus.get("_outline_tweens")[actor]
		motion.custom_step(preload("res://scripts/board_aim_focus.gd").TRANSITION_SECONDS * 0.5)
		_check(is_equal_approx(overlay.unit_alpha_multiplier(actor), 0.625), "Outline half-duration follows quadratic ease-out")
		motion.custom_step(preload("res://scripts/board_aim_focus.gd").TRANSITION_SECONDS * 0.5)
		_check(is_equal_approx(overlay.unit_alpha_multiplier(actor), 0.5), "Outline reaches exactly fifty percent at 0.12 seconds")
		break
	await scene.call("_on_cancel_requested")
	await create_timer(FADE_SETTLE).timeout
	for unit: Dictionary in board.call("_visible_units"): _check(is_equal_approx(overlay.unit_alpha_multiplier(unit.key), 1.0), "Cancel restores outline " + str(unit.key))
	scene.queue_free(); canvas.queue_free(); await process_frame
	for boss_name: String in ["zekarion", "vyraketh"]:
		Fixture.install_save(ROOT + "/" + boss_name + ".json")
		canvas = Fixture.make_canvas(self)
		scene = Fixture.resume(self, canvas)
		await _settle()
		board = scene.get("board_view")
		for setting: String in [Settings.BOARD_HEALTH_ALWAYS, Settings.BOARD_HEALTH_CONTEXTUAL]:
			Settings._applied_board_health_bars = setting
			for unit: Dictionary in board.call("_visible_units"):
				if str(unit.get("type", "")) != boss_name: continue
				for tile: Vector2i in board.call("_unit_footprint_tiles", unit):
					await _hover(tile)
					board.plate_visibility.advance(FADE_SETTLE)
					_check(board.controller_tooltip_for_tile(tile) == board.call("_surface_tooltip_for_tile", tile), "Dragon focus exposes only independent floor details " + str(tile))
					_check(board.call("_get_tooltip", board.call("world_position_for_tile", tile)) == "", "No enemy or floor tooltip on a dragon footprint tile under the pointer " + str(tile))
					_check(not Badges.details_discloses_compass(board.presentation, str(unit.key)), "No floor compass under a hovered dragon " + str(tile))
					_check(board.plate_visibility.opacity(unit.key) == 1.0 and _expanded(unit.key), "Dragon footprint keeps plate and unfurled disc")
					_expect_keys([unit.key], "Dragon footprint hover without tooltip")
				_assert_no_enemy_tooltip(unit, boss_name + "/" + setting)
		scene.queue_free(); canvas.queue_free(); await process_frame
	await preload("res://tools/rd08/sealbinder_checks.gd").run(self, _check, _preserved_tooltip_for_board)
	_finish()

func _assert_no_enemy_tooltip(unit: Dictionary, label: String) -> void:
	var key: String = unit.key
	var points: Array[Vector2]
	points.append(board.call("world_position_for_tile", unit.pos))
	points.append(board.call("_unit_draw_rect", unit).get_center())
	var badge: Dictionary = _badge(key)
	if not badge.is_empty(): points.append(badge.rect.get_center())
	for point: Vector2 in points:
		var actual: String = board.call("_get_tooltip", point)
		_check(_only_preserved_tooltip(actual, point), label + ": body/tile/disc has only preserved floor/status tooltips")
	var slot: Control = _rail_slot(key)
	_check(slot != null and slot.tooltip_text.is_empty() and str(slot.get_meta("turn_order_tooltip", "")).is_empty(), label + ": rail portrait has no enemy tooltip")
	if slot != null:
		_check(preload("res://scripts/turn_order_slots.gd").controller_controls(scene).has(slot), label + ": tooltip-free rail portrait remains controller navigable")
		var rail_candidate: Dictionary = scene.call("_controller_candidate_for_control", slot)
		_check(str(rail_candidate.get("detail", "")).is_empty(), label + ": controller rail detail is empty")
	var candidate: Dictionary = scene.call("_controller_candidate_for_tile", unit.pos)
	_check(str(candidate.kind) == "enemy" and not str(candidate.detail).contains(str(unit.name)), label + ": controller enemy focus has no enemy summary")

func _only_preserved_tooltip(actual: String, point: Vector2) -> bool:
	return _preserved_tooltip_for_board(board, actual, point)

func _preserved_tooltip_for_board(view: Control, actual: String, point: Vector2) -> bool:
	if actual.is_empty(): return true
	var status: String = view.plate_visibility.tooltip_at(point)
	if not status.is_empty() and actual == status: return true
	# A tall prop/trap hit region can belong to a neighboring floor tile.
	# Validate every panel against the canonical ground/prop entries, rather
	# than rejecting those preserved inspectors or accepting arbitrary stacks.
	var entries: Array[Dictionary] = TileTooltips.decode(actual)
	if entries.is_empty(): return false
	var allowed: Array[Dictionary]
	for tile: Vector2i in view.call("_rendered_tiles_in_draw_order"):
		allowed.append_array(TileTooltips.entries(view, tile))
	for entry: Dictionary in entries:
		if not allowed.has(entry): return false
	return true

func _badge(key: String) -> Dictionary:
	for badge: Dictionary in Badges.layouts(board, board.presentation.get("threats_at_rest", {}).get("badges", [])):
		if str(badge.key) == key: return badge
	return {}

func _expanded(key: String) -> bool:
	var badge: Dictionary = _badge(key)
	return not badge.is_empty() and (bool(badge.get("unfurled", false)) if bool(badge.get("contextual", false)) else (board.presentation.get("expanded_enemy_actor_keys", []) as Array).has(key))

func _finish() -> void:
	var file := FileAccess.open(ROOT + "/integration.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	for failure: String in failures: push_error(failure)
	print("RD08 INTEGRATION: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
