extends RefCounted
## Keep RunScene integration small. All coordinates are live HUD coordinates.
const Omens = preload("res://scripts/omen_rules.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Floating = preload("res://scripts/floating_combat_text.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const START_STAGGER: float = 0.12

static func destinations(host: Node) -> Dictionary:
	var result: Dictionary = {}
	var controls: Dictionary = {
		"relic": host.get("relic_bar"), "loadout": host.get("loadout_button"),
		"deck": host.get("loadout_button"), "embers": host.get("stats_label"),
		"defiance": host.get("_defiance_badge"), "map": host.get("_section_map_hud_button")
	}
	var manager: RefCounted = host.get("_omen_badges")
	for id: String in manager.badges: controls["omen:" + id] = manager.badges[id]
	for key: String in controls:
		var control: Control = controls[key]
		if is_instance_valid(control): result[key] = {"control": control, "position": control.get_global_rect().get_center()}
	if result.has("embers"): result["embers"]["update"] = Callable(host, "_set_stats_label_text")
	return result

static func firing_omens(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for entry: Dictionary in Omens.active(state):
		if (state.get(Omens.START_APPLIED_KEY, []) as Array).has(str(entry["id"])): result.append(entry)
	return result

static func combat_start(host: Node) -> void:
	var state: Dictionary = host.get("_combat_state")
	var entries: Array[Dictionary] = firing_omens(state)
	if entries.is_empty(): return
	var feedback := CombatOmenFeedback.new()
	feedback.host = host
	feedback.entries = entries
	feedback.reduced = bool(host.call("_reduced_motion_enabled"))
	(host.get("ui_root") as Control).add_child(feedback)

class CombatOmenFeedback extends Control:
	var host: Node
	var entries: Array[Dictionary]
	var reduced: bool
	var elapsed: float = 0
	var next: int = 0
	var labels: Array[Label]
	var original_positions: Array[Vector2]
	func _ready() -> void:
		name = "CombatOmenFeedback"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 1700
		var state: Dictionary = host.get("_combat_state")
		var center: Vector2 = host.call("_board_global_position_for_tile", state["player"]["pos"])
		for entry: Dictionary in entries:
			var label := Label.new()
			label.text = str(entry["name"])
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.add_theme_font_override("font", Typography.display_font())
			Typography.set_label_size(label, Floating.EFFECT_BASE_FONT_SIZE)
			label.add_theme_color_override("font_color", Palette.EVENT_BLESSING if entry["kind"] == "blessing" else Palette.EVENT_BANE)
			label.add_theme_color_override("font_outline_color", Palette.TEXT_OUTLINE)
			label.add_theme_constant_override("outline_size", Floating.EFFECT_OUTLINE_SIZE)
			add_child(label)
			label.position = center - global_position - Vector2(label.get_combined_minimum_size().x * 0.5, Floating.SCREEN_POPUP_SOLO_VERTICAL_SHIFT + labels.size() * Floating.REDUCED_STACK_STEP_Y)
			labels.append(label)
			original_positions.append(label.position)
			label.hide()
	func _process(delta: float) -> void:
		if str(host.get("_run_state").get("mode", "")) != "combat": queue_free(); return
		elapsed += delta
		while next < entries.size() and elapsed >= next * START_STAGGER:
			var manager: RefCounted = host.get("_omen_badges")
			var badge: Control = manager.badges.get(str(entries[next]["id"]))
			if is_instance_valid(badge): badge.gain(reduced)
			labels[next].show()
			next += 1
		for index: int in range(next):
			var t: float = clampf((elapsed - index * START_STAGGER) / Floating.ANIMATION_DURATION_SECONDS, 0, 1)
			labels[index].modulate.a = 1 - smoothstep(Floating.DAMAGE_FADE_START, 1, t)
			if not reduced: labels[index].position = original_positions[index] - Vector2(0, Floating.ARC_RISE_HEIGHT * t)
		if elapsed >= (entries.size() - 1) * START_STAGGER + Floating.ANIMATION_DURATION_SECONDS: queue_free()
