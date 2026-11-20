extends SceneTree

const Suite = preload("res://tests/suites/threats_at_rest_suite.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Settings = preload("res://scripts/settings_store.gd")
const PaintReceipts = preload("res://tools/perf148/paint_receipts.gd")
const SETTLE_FRAMES: int = 10
const LOW_OPACITY: float = 0.006
const DISSOLVE_PROGRESS: float = 0.4
const FREED_RECEIPT_RECORD: String = "probe_freed_hud"
var failures: Array[String]

func _initialize() -> void:
	_run.call_deferred()

func _settle() -> void:
	for index: int in range(SETTLE_FRAMES):
		await process_frame

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	var cfg: Dictionary = Settings.default_settings()
	cfg["board_health_bars"] = Settings.BOARD_HEALTH_CONTEXTUAL
	Settings.apply_settings(cfg, null, false)
	var board := Board.new()
	board.size = Vector2(root.size)
	root.add_child(board)
	board.set_process(false)
	board.hide()
	var engine := Suite.Combat.new()
	var state: Dictionary = Suite.staged_state(engine)
	var rest: Dictionary = Suite.Badges.build(engine, state, state)
	var shown: Dictionary = {"isolated_enemy_actor_keys": [], "threats_at_rest": rest, "reduced_motion": true}
	var key: String = str(rest.badges[0].key)
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, shown)
	board.plate_visibility.set_external(key, true, "probe")
	board.plate_visibility._clock.set_process(false)
	await _settle()
	board.plate_visibility.advance(1.0)
	await _settle()
	board.show()
	await _settle()
	var badge: Control = _piece(board, key, "_draw_slice_intent_chip")
	var tab: Control = badge.get_node_or_null("IntentTab_" + key) if is_instance_valid(badge) else null
	var number: String = str(tab.ink.badge.get("number", "")) if is_instance_valid(tab) else ""
	_check(number == "4" and tab.reveal > 0.0, "expanded intent value 4 must paint after showing the board")
	var bar: Control = _piece(board, key, "_draw_health_bar_entry")
	_check(is_instance_valid(bar) and bar._plate_opacity({"key": key}) == 1.0 and bar.modulate.a == 1.0,
		"health fade completed while hidden must keep full ink after showing the board")
	if is_instance_valid(bar):
		await _low_opacity(board, bar, key)
	await _death(board, state, shown)
	for message: String in failures: printerr(message)
	print("PERF-148 REVIEW REPRO: %s (intent=%s, alpha=%.3f, %d failures)" % [
		"PASS" if failures.is_empty() else "FAIL", number, LOW_OPACITY, failures.size()])
	quit(int(not failures.is_empty()))

func _low_opacity(board: Control, bar: Control, key: String) -> void:
	var trace: RefCounted = board._board_redraw_trace
	board.plate_visibility._entries[key]["alpha"] = LOW_OPACITY
	trace.begin()
	board.plate_visibility.opacity_only = true
	board._plate_visibility_changed()
	board.plate_visibility.opacity_only = false
	await _settle()
	var draws: Array[Dictionary] = trace.finish()
	_check(is_equal_approx(bar._plate_opacity({"key": key}), LOW_OPACITY) and bar.modulate.a == 1.0
		and draws.any(func(row: Dictionary) -> bool: return row["path"] == str(bar.get_path())),
		"low opacity must repaint using primitive alpha and neutral CanvasItem modulation")
	if not trace.confirm_baseline and not trace.baseline:
		var receipt: Array = bar.get_meta("perf148_painted_receipt", [])
		_check(not receipt.is_empty() and is_equal_approx(float(receipt[1][0]), LOW_OPACITY),
			"active trace must capture the primitive alpha")
	bar.remove_meta("perf148_painted_receipt")
	bar.queue_redraw()
	await _settle()
	_check(not bar.has_meta("perf148_painted_receipt"), "inactive inputs trace recorded a HUD paint receipt")

func _death(board: Control, state: Dictionary, shown: Dictionary) -> void:
	var actor: Dictionary = state.enemies[0]
	var key: String = "enemy_%s" % actor.id
	var body: Control = board._occlusion_silhouettes.team.bodies.get(key)
	var old_sprite: Control = _piece(board, key, "_draw_unit_sprite")
	_check(is_instance_valid(old_sprite), "live sprite must exist before the death snapshot")
	for method: String in ["_draw_health_bar_entry", "_draw_slice_intent_chip"]:
		_check(is_instance_valid(_piece(board, key, method)), "live enemy must paint " + method)
	var count: int = body._dynamic_draw_count
	var death: Dictionary = actor.duplicate(true)
	death["key"] = key
	death["death_progress"] = DISSOLVE_PROGRESS
	var next: Dictionary = state.duplicate(true)
	next.enemies[0].hp = 0
	shown["death_animation_units"] = [death]
	board.set_combat_state(next, [], [], Vector2i(-1, -1), "", "", {}, {}, shown)
	await _settle()
	_check(body._unit_outline_actor.get("death_animation", false) and body._dynamic_draw_count > count,
		"body must redraw after the death snapshot is bound")
	_check(not is_instance_valid(old_sprite) or not old_sprite.visible, "old body sprite must retire during death dissolve")
	_check_retired_hud(board, key, "during dissolve")
	shown.erase("death_animation_units")
	shown["threats_at_rest"] = Suite.Badges.build(Suite.Combat.new(), next, next)
	board.set_combat_state(next, [], [], Vector2i(-1, -1), "", "", {}, {}, shown)
	await _settle()
	_check_retired_hud(board, key, "after dissolve")
	_check_freed_receipt(board)

func _check_retired_hud(board: Control, key: String, phase: String) -> void:
	for record: Dictionary in board._aim_focus.canvases.values():
		if not bool(record.hud) or record.unit.get("key") != key or not is_instance_valid(record.canvas): continue
		var canvas: Control = record.canvas
		_check(not canvas.is_visible_in_tree(), "dead enemy HUD still visible " + phase)

func _check_freed_receipt(board: Control) -> void:
	# A retired slice can leave a freed reference in the aim registry.
	var retired := Control.new()
	board._aim_focus.canvases[FREED_RECEIPT_RECORD] = {"canvas": retired, "hud": true}
	retired.free()
	var receipt: Dictionary = PaintReceipts.collect(board)
	board._aim_focus.canvases.erase(FREED_RECEIPT_RECORD)
	var hud: Dictionary = receipt.get("hud", {})
	_check(hud.keys().any(func(id: String) -> bool: return id.ends_with("/_draw_unit_hud_details/player")),
		"paint receipts must include the surviving hero HUD after a canvas is freed")

func _piece(board: Control, key: String, method: String) -> Control:
	for record: Dictionary in board._aim_focus.canvases.values():
		if record.unit.get("key") != key or not is_instance_valid(record.canvas): continue
		var canvas: Control = record.canvas
		if canvas.is_visible_in_tree() and not canvas._render_slice_ops.is_empty() and canvas._render_slice_ops[0][0] == method:
			return canvas
	return null

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
