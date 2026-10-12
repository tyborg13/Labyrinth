extends Button

signal hero_fade_finished

const Rules = preload("res://scripts/movement_undo_rules.gd")
const Router = preload("res://scripts/input_router.gd")
const HudSkin = preload("res://scripts/ui_skin.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Palette = preload("res://scripts/ui_palette.gd")

const FADE_BACK_SECONDS: float = 0.12
const BLOCKED_NOTICE: String = "Can't undo — something changed."
const UNDO_BUTTON_HEIGHT: float = 34.0
const UNDO_BUTTON_GAP: float = 6.0
const RunSfxLibrary = preload("res://scripts/run_sfx_library.gd")
# Undo reuses the soft menu-close cue (owner-auditioned UI family).
const SOFT_UI_CANCEL_SOUND_ID: String = RunSfxLibrary.MENU_CLOSE_ID

var rules = Rules.new()
var _host: Control
var _trigger_down: bool = false
var _hero_fade_running: bool = false
var _hero_fade_coroutine_running: bool = false
var _hero_fade_started_usec: int = 0
var _hero_fade_completed_usec: int = 0
var _hero_fade_renderer: Node
var _hero_fade_completion_reason: String = ""
var _leaving_tree: bool = false

func _init() -> void:
	name = "MovementUndoButton"
	text = "Undo move"
	tooltip_text = "Take back your last move. Moves that revealed or triggered something can't be undone."
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	z_as_relative = false
	z_index = 120
	visible = false
	set_process(false)
	var skin := HudSkin.new()
	skin.apply_button_stylebox_overrides(self, HudSkin.VARIANT_COMPACT)
	# Match the Intents button's shared text and muted key treatment.
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_color_override("font_color" if state == "normal" else "font_%s_color" % state, Color.TRANSPARENT)
	add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	for value: String in ["Undo move", "Z"]:
		var label := Label.new()
		label.name = "UndoKey" if value == "Z" else "UndoTitle"
		label.text = value
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font", Typography.ui_font())
		Typography.set_label_size(label, 15)
		label.add_theme_color_override("font_color", Palette.TEXT_3 if value == "Z" else Palette.TEXT)
		row.add_child(label)
	pressed.connect(request_undo)

func configure(host: Control) -> void:
	_host = host
	refresh()

func _can_interact() -> bool:
	return (
		is_instance_valid(_host)
		and str(_host.get("_run_state").get("mode", "")) == "combat"
		and not _host.get("_animation_lock")
		and not _host.get("_pending_umbra_commit_locked")
		and not _host.get("_drag_cancel_in_progress")
		and not _host.call("_controller_modal_visible")
		and not _host.call("_guided_tutorial_hard_gate_active")
		and int(_host.get("_drag_card_index")) < 0
		and str(_host.get("_combat_skill_card_selection_zone")).is_empty()
		and not _host.get("_surface_aim").active()
		and _host.get("_combat_engine").is_player_turn(_host.get("_combat_state"))
	)

func undo_available() -> bool:
	return _can_interact() and rules.available(_host.get("_combat_state"))

func refresh() -> void:
	if not is_instance_valid(_host): return
	if not _host.get("_animation_lock"): rules.observe(_host.get("_combat_state"))
	var meter: Control = _host.get("_movement_meter")
	visible = undo_available() and is_instance_valid(meter) and meter.visible
	if is_instance_valid(meter):
		custom_minimum_size = Vector2(meter.size.x, UNDO_BUTTON_HEIGHT)
		size = Vector2(meter.size.x, maxf(UNDO_BUTTON_HEIGHT, get_combined_minimum_size().y))
		global_position = meter.global_position + Vector2(0.0, meter.size.y + UNDO_BUTTON_GAP)

func handle_input(event: InputEvent) -> bool:
	var pressed_now: bool = event.is_action_pressed(Router.ACTION_UNDO_MOVE)
	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_TRIGGER_LEFT:
		var was_down: bool = _trigger_down
		_trigger_down = pressed_now
		pressed_now = pressed_now and not was_down
	if not pressed_now or not _can_interact(): return false
	if Router.is_controller_event(event):
		var router: Node = get_node_or_null("/root/InputRouter")
		if router != null: router.call("mark_controller_device", event.device)
	await request_undo()
	return true

func record_walk(before: Dictionary, after: Dictionary) -> void:
	rules.record_walk(before, after)

func clear_history() -> void:
	_finish_hero_fade("history_cleared")
	rules.clear()
	refresh()

func request_undo() -> void:
	if not _can_interact(): return
	var before: Dictionary = _host.get("_combat_state")
	var result: Dictionary = rules.undo(before)
	if result.is_empty():
		if rules.last_walk_committed:
			await _show_blocked_notice()
		return
	_host.set("_animation_lock", true)
	_host.call("_cancel_player_movement_selection", false)
	_host.call("_reset_card_resolution")
	var restored: Dictionary = result["state"]
	_host.set("_combat_state", restored)
	_host.set("_run_state", _host.get("_run_engine").set_combat_state(_host.get("_run_state"), restored))
	_host.get("_board_presentation").clear()
	_host.call("_mark_combat_preview_state_changed")
	_host.call("_persist_committed_boundary", "player_move_undone")
	_host.get("_analytics_store").write_event("player_move_undone", _host.call("_analytics_context_from_states", _host.get("_run_state"), before), {"tiles": result["tiles"], "activation_seq": result["activation_seq"]})
	_host.call("_play_sfx", RunSfxLibrary.entry(SOFT_UI_CANCEL_SOUND_ID))
	_host.call("_refresh_ui") # Board, Pass forecast and Turn Clock use restored state immediately.
	await _fade_hero_back()
	if _leaving_tree or not is_instance_valid(_host) or not _host.is_inside_tree(): return
	_host.set("_animation_lock", false)
	_host.call("_refresh_ui")

func _fade_hero_back() -> void:
	_finish_hero_fade("restarted")
	_hero_fade_renderer = _drawn_hero_renderer()
	if not is_instance_valid(_hero_fade_renderer): return
	if _host.call("_reduced_motion_enabled"):
		_set_hero_alpha(_hero_fade_renderer, 1.0)
		return
	_hero_fade_started_usec = Time.get_ticks_usec()
	_hero_fade_completed_usec = 0
	_hero_fade_completion_reason = ""
	_hero_fade_running = true
	_hero_fade_coroutine_running = true
	_set_hero_alpha(_hero_fade_renderer, 0.0)
	set_process(true)
	# Refresh the live viewport immediately before rendering as well as in
	# _process. Readbacks/PNG encoding can stall between rendered frames; a
	# coroutine waiting only for process_frame leaves the last alpha stale.
	RenderingServer.frame_pre_draw.connect(_update_hero_fade)
	await hero_fade_finished
	_hero_fade_coroutine_running = false

func _process(_delta: float) -> void:
	_update_hero_fade()

func _drawn_hero_renderer() -> Node:
	if not is_instance_valid(_host): return null
	var board: Control = _host.get("board_view")
	return board.unit_cutout_renderer({"type": "player"}) if is_instance_valid(board) else null

func _set_hero_alpha(renderer: Node, alpha: float) -> void:
	if not is_instance_valid(renderer): return
	for rig: CanvasItem in renderer.get("rigs").values():
		if is_instance_valid(rig): rig.modulate.a = alpha
	var viewport: SubViewport = renderer.get("viewport")
	if is_instance_valid(viewport): viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _update_hero_fade() -> void:
	if not _hero_fade_running: return
	if not is_instance_valid(_host) or _host.call("_reduced_motion_enabled"):
		_finish_hero_fade("interrupted")
		return
	var drawn_renderer: Node = _drawn_hero_renderer()
	if drawn_renderer != _hero_fade_renderer:
		_set_hero_alpha(_hero_fade_renderer, 1.0)
		_hero_fade_renderer = drawn_renderer
	if not is_instance_valid(_hero_fade_renderer):
		_finish_hero_fade("renderer_removed")
		return
	var elapsed: float = float(Time.get_ticks_usec() - _hero_fade_started_usec) / 1000000.0
	if elapsed >= FADE_BACK_SECONDS:
		_finish_hero_fade("completed")
	else:
		_set_hero_alpha(_hero_fade_renderer, elapsed / FADE_BACK_SECONDS)

func _finish_hero_fade(reason: String) -> void:
	if not _hero_fade_running: return
	# Always write exactly 1.0 to both the previous and currently drawn rig,
	# including loads, reduced-motion changes, renderer replacement and exit.
	_set_hero_alpha(_hero_fade_renderer, 1.0)
	_set_hero_alpha(_drawn_hero_renderer(), 1.0)
	_hero_fade_running = false
	_hero_fade_completed_usec = Time.get_ticks_usec()
	_hero_fade_completion_reason = reason
	set_process(false)
	if RenderingServer.frame_pre_draw.is_connected(_update_hero_fade):
		RenderingServer.frame_pre_draw.disconnect(_update_hero_fade)
	hero_fade_finished.emit()

func hero_fade_snapshot() -> Dictionary:
	var renderer: Node = _drawn_hero_renderer()
	var rig: CanvasItem = renderer.get("rigs").get(str(renderer.get("facing"))) if is_instance_valid(renderer) else null
	return {"alpha": rig.modulate.a if is_instance_valid(rig) else -1.0, "elapsed_seconds": float(Time.get_ticks_usec() - _hero_fade_started_usec) / 1000000.0 if _hero_fade_started_usec > 0 else 0.0, "running": _hero_fade_running, "coroutine_running": _hero_fade_coroutine_running, "completion_reason": _hero_fade_completion_reason, "completed_elapsed_seconds": float(_hero_fade_completed_usec - _hero_fade_started_usec) / 1000000.0 if _hero_fade_completed_usec > 0 else 0.0, "renderer_id": renderer.get_instance_id() if is_instance_valid(renderer) else 0, "rig_id": rig.get_instance_id() if is_instance_valid(rig) else 0}

func _exit_tree() -> void:
	_leaving_tree = true
	_finish_hero_fade("tree_exit")

func _show_blocked_notice() -> void:
	_host.set("_animation_lock", true)
	_host.call("_refresh_animation_lock_ui")
	await _host.call("_animate_floating_text_presentation", _host.get("_combat_state"), {"floating_texts": [{"tile": _host.get("_combat_state")["player"]["pos"], "text": BLOCKED_NOTICE, "color": Palette.TEXT, "offset": -8.0}]})
	_host.get("_board_presentation").clear()
	_host.set("_animation_lock", false)
	_host.call("_refresh_ui")
