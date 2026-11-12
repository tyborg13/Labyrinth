extends RefCounted

const ForecastPanel = preload("res://scripts/pass_forecast_focus_tooltip.gd")
const Slots = preload("res://scripts/turn_order_slots.gd")

# A visibility/lifecycle observer owns no simulation. It runs only while the
# forecast is active and starts the fade when any preview owner ends or locks.
# Ancestor visibility changes also re-evaluate a targetless confirmation after
# choice refresh or deferred hand layout shows the retained PASS dock again.
class Lifecycle extends Node:
	var scene: Node
	var chip: Button
	var previewed: bool = false
	var eligible: Callable

	func _ready() -> void:
		chip.visibility_changed.connect(_visibility_changed)
		_visibility_changed()

	func _visibility_changed() -> void:
		if chip.is_visible_in_tree(): scene.call_deferred("_refresh_selected_card_forecast")

	func _process(_delta: float) -> void:
		var selection_ended: bool = previewed and scene._selected_card_index < 0 and not scene._player_movement_selected and not scene._surface_aim.active()
		if selection_ended or not eligible.call():
			ForecastPanel.refresh(chip, false)
			chip.set_meta("pass_action_preview", false)
			chip.set_meta("pass_movement_preview", false)
			Slots.refresh_pass_badges(scene, chip)
			set_process(false)

static func allowed(scene: Node) -> bool:
	return not scene._animation_lock and not scene._dialogue_active and scene._drag_card_index < 0 and str(scene._run_state.get("mode", "")) == "combat" and scene._combat_engine.is_player_turn(scene._combat_state) and scene._combat_engine.combat_outcome(scene._combat_state).is_empty()

static func preview_active(scene: Node) -> bool:
	if not allowed(scene): return false
	if not scene._player_movement_selected and scene._selected_card_index < 0 and not scene._surface_aim.active(): return false
	if scene._selected_card_index >= 0 and scene._pending_card_requires_confirmation(): return true
	if scene._selected_card_index >= 0 and scene._orientation_pending():
		return scene._direction_choice_tiles(scene._pending_orientation_target_tile).has(scene._hovered_board_tile)
	var preview: Dictionary = scene._active_card_preview()
	if preview.is_empty(): return false
	return (preview.get("target_tiles", []) as Array).has(scene._hovered_board_tile) or not scene._shortcut_plan_for_tile(preview, scene._hovered_board_tile).is_empty()

# Retain the round-2 helper contract for movement-specific probes.
static func movement_active(scene: Node) -> bool:
	return preview_active(scene) and str((scene._active_card_preview().get("action", {}) as Dictionary).get("type", "")) in ["move", "blink"]

static func refresh(scene: Node, chip: Button, summary: Dictionary) -> void:
	var lifecycle: Lifecycle = chip.get_node_or_null("PassForecastLifecycle") as Lifecycle
	if lifecycle == null:
		lifecycle = Lifecycle.new()
		lifecycle.name = "PassForecastLifecycle"
		lifecycle.scene = scene
		lifecycle.chip = chip
		lifecycle.eligible = allowed.bind(scene)
		chip.add_child(lifecycle)
	chip.set_meta("pass_forecast_summary", summary)
	var previewed: bool = preview_active(scene)
	var pass_active: bool = not chip.disabled and (chip.has_focus() or bool(chip.get_meta("pass_keyboard_focus", false)) or bool(chip.get_meta("pass_pointer_hover", false)))
	var active: bool = allowed(scene) and chip.is_visible_in_tree() and not summary.is_empty() and (previewed or pass_active)
	lifecycle.previewed = previewed
	lifecycle.set_process(active)
	chip.set_meta("pass_action_preview", previewed)
	chip.set_meta("pass_movement_preview", movement_active(scene))
	# Keep the last destination's rows throughout its fade-out. Visibility alone
	# never requests a forecast: the caller passes the strip's cached summary.
	if active or not chip.has_node("PassForecastFocusTooltip"):
		var state: Dictionary = scene._pass_preview_prewarm.cached_source(scene, scene._hovered_board_tile)
		var portraits: Array[Dictionary] = Slots.pass_repeat_portraits(scene, summary, state)
		var source: Array = [summary, portraits]
		if chip.get_meta("forecast_presentation_source", []) != source:
			chip.set_meta("forecast_presentation_source", source.duplicate(true))
			var inks: Dictionary = {
				"block": scene._pass_preview_damage_entries({"block": 1})[0]["color"],
				"stoneskin": scene._pass_preview_damage_entries({"stoneskin": 1})[0]["color"],
				"health": scene._pass_preview_damage_entries({"hp": 1})[0]["color"],
				"defiance": scene._pass_preview_damage_entries({"defiance_spent": 1})[0]["color"],
				"unknown": scene._pass_preview_forecast_entries({"umbra_unknown_before_player": true})[0]["color"]
			}
			var rows: Array[Dictionary] = ForecastPanel.rows(summary, portraits, inks)
			if bool(summary.get("terminal_unknown", false)):
				# Use the approved Umbra '?' row instead of asserting Safe when
				# even the absence of hidden foes is undisclosed information.
				for index: int in range(rows.size() - 1, -1, -1):
					if rows[index].get("parts", [])[0].get("text", "") == "Safe": rows.remove_at(index)
			ForecastPanel.configure(chip, rows)
		chip.set_meta("forecast_repeat_portraits", portraits)
	ForecastPanel.refresh(chip, active)
	Slots.refresh_pass_badges(scene, chip)
