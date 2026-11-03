extends "res://scripts/combat_board_view.gd"
## Production HUD pass with only the chip-placement implementation selectable.
const Before = preload("res://tests/pt14_01_before_badges.gd")
var drawn_unit_keys: Dictionary = {}
var drawn_chip_layouts: Array[Dictionary]
var drawn_before: bool = false

func _draw_unit_body(unit: Dictionary) -> void:
	super._draw_unit_body(unit)
	if _texture_for_unit(unit) == null or not _unit_texture_draw_rect(unit, _unit_center(unit)).has_area(): return
	var owner: Node = _render_instrumentation_owner if is_instance_valid(_render_instrumentation_owner) else self
	owner.drawn_unit_keys[str(unit["key"])] = true

func _draw_hud_render_layer() -> void:
	var started_usec: int = Time.get_ticks_usec()
	_dynamic_draw_count += 1
	_tooltip_regions.clear()
	if combat_state.is_empty():
		_record_dynamic_draw_time(started_usec)
		return
	var section_started_usec: int = Time.get_ticks_usec()
	var units_to_draw: Array[Dictionary] = _visible_units()
	_draw_noctyrax_brazier_markers()
	_draw_unit_huds(units_to_draw)
	_record_render_section_time("unit_huds", section_started_usec)
	# Damage-preview text and the lost-HP band must composite after the health
	# bar itself. Drawing them on the lower effects layer lets the retained HUD
	# layer paint over the projected HP text during ranged targeting.
	section_started_usec = Time.get_ticks_usec()
	_draw_unit_damage_preview_overlays(units_to_draw)
	_draw_friendly_damage_chips()
	ReflectView.draw_preview(self)
	var owner: Node = _render_instrumentation_owner if is_instance_valid(_render_instrumentation_owner) else self
	owner.drawn_before = bool(presentation.get("intent_chip_proof_before", false))
	var measured: Array[Dictionary]
	if owner.drawn_before: measured = Before.layouts(self, (presentation.get("threats_at_rest", {}) as Dictionary).get("badges", []))
	else: measured = IntentBadges.layouts(self, (presentation.get("threats_at_rest", {}) as Dictionary).get("badges", []))
	owner.drawn_chip_layouts = measured
	if bool(presentation.get("intent_chip_proof_before", false)):
		Before.draw(self, (presentation.get("threats_at_rest", {}) as Dictionary).get("badges", []))
	else:
		IntentBadges.draw(self, (presentation.get("threats_at_rest", {}) as Dictionary).get("badges", []))
	_record_render_section_time("damage_preview_overlays", section_started_usec)
	# Intent results are the topmost board HUD, above every bar, pip and badge.
	section_started_usec = Time.get_ticks_usec()
	IntentCallouts.draw(self, presentation.get("intent_callouts", []))
	_record_render_section_time("intent_callouts", section_started_usec)
	_record_dynamic_draw_time(started_usec)

