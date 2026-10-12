extends RefCounted

const Omens = preload("res://scripts/omen_rules.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Tooltip = preload("res://scripts/ui_tooltip_panel.gd")

# Central inventory for this new icon-bearing collection; the identity audit
# compares every id with the protected catalog and all other icon families.
const ICONS: Dictionary = {
	"deepening_dark": "res://assets/art/icons/omens/deepening_dark.png",
	"dread": "res://assets/art/icons/omens/dread.png",
	"ember_tithe": "res://assets/art/icons/omens/ember_tithe.png",
	"ember_ward": "res://assets/art/icons/omens/ember_ward.png",
	"hunted": "res://assets/art/icons/omens/hunted.png",
	"kindled": "res://assets/art/icons/omens/kindled.png",
	"lantern_sight": "res://assets/art/icons/omens/lantern_sight.png",
	"leaden_limbs": "res://assets/art/icons/omens/leaden_limbs.png",
	"quickened_blood": "res://assets/art/icons/omens/quickened_blood.png",
	"stone_vow": "res://assets/art/icons/omens/stone_vow.png",
	"tithe_of_ash": "res://assets/art/icons/omens/tithe_of_ash.png"
}

static func icon_path(id: String) -> String:
	return str(ICONS.get(id, ""))

class Badge extends Control:
	var entry: Dictionary = {}
	var _focus_tooltip: PanelContainer
	var _motion: Tween

	func _ready() -> void:
		custom_minimum_size = Vector2(38, 38)
		size = custom_minimum_size
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_HELP
		set_meta("cursor_feedback_context", "help")
		focus_entered.connect(_show_focus_tooltip)
		focus_exited.connect(_hide_focus_tooltip)
		var icon := TextureRect.new()
		icon.name = "OmenIcon"
		icon.texture = Assets.load_texture(str(ICONS.get(str(entry["id"]), "")))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = Vector2(38, 38)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon)
		var counter := Control.new()
		counter.name = "FightsLeftDisc"
		counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		counter.draw.connect(func() -> void:
			var center: Vector2 = (size - Vector2(38, 38)) * 0.5 + Vector2(30, 30)
			counter.draw_circle(center, 8, Palette.INK_0)
			counter.draw_arc(center, 8, 0, TAU, 32, Palette.GOLD if str(entry["kind"]) == "blessing" else Palette.UMBRA, 1, true)
			var font: Font = Typography.ui_font()
			var numeral: String = str(entry["fights_left"])
			counter.draw_string(font, center + Vector2(-font.get_string_size(numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x / 2, 5), numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.TEXT)
		)
		add_child(counter)
		# The existing relic grid may allocate a larger cell; keep the authored
		# 38 px seal centred without changing the relic layout or icon size.
		resized.connect(func() -> void:
			icon.position = (size - Vector2(38, 38)) * 0.5
			pivot_offset = size * 0.5
			counter.queue_redraw()
		)
		update_entry(entry)

	func update_entry(value: Dictionary) -> void:
		entry = value.duplicate(true)
		tooltip_text = "%s\n%s\n%s\n%d fights left" % [entry["name"], str(entry["kind"]).capitalize(), entry["description"], int(entry["fights_left"])]
		if has_node("FightsLeftDisc"): get_node("FightsLeftDisc").queue_redraw()
		if _focus_tooltip != null: _hide_focus_tooltip(); _show_focus_tooltip()

	func _make_custom_tooltip(_text: String) -> Object:
		var panel: PanelContainer = Tooltip.make_lines(str(entry["name"]), PackedStringArray([str(entry["description"]), "%d fights left" % int(entry["fights_left"])]))
		var box: VBoxContainer = panel.get_child(0) as VBoxContainer
		var eyebrow := Label.new()
		Typography.apply_eyebrow(eyebrow, 15, Palette.EVENT_BLESSING if str(entry["kind"]) == "blessing" else Palette.EVENT_BANE)
		eyebrow.text = str(entry["kind"]).capitalize()
		eyebrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(eyebrow)
		box.move_child(eyebrow, 1)
		return panel

	func _show_focus_tooltip() -> void:
		_hide_focus_tooltip()
		_focus_tooltip = _make_custom_tooltip(tooltip_text) as PanelContainer
		_focus_tooltip.top_level = true
		_focus_tooltip.z_as_relative = false
		_focus_tooltip.z_index = 2201
		add_child(_focus_tooltip)
		_focus_tooltip.position = get_global_rect().position + Vector2(0, 44)

	func _hide_focus_tooltip() -> void:
		if is_instance_valid(_focus_tooltip): _focus_tooltip.queue_free()
		_focus_tooltip = null

	func gain(reduced: bool) -> void:
		pivot_offset = Vector2(19, 19)
		if reduced: return
		scale = Vector2.ONE * 1.25
		_motion = create_tween()
		_motion.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	func expire() -> void:
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hide_focus_tooltip()
		if _motion != null: _motion.kill()
		_motion = create_tween()
		_motion.tween_property(self, "modulate:a", 0.0, 0.3)
		_motion.tween_callback(queue_free)

var badges: Dictionary = {}
var _previous_ids: Array[String]
var _initialized: bool = false

func sync(host: GridContainer, state: Dictionary, reduced_motion: bool = false) -> void:
	var current: Array[String]
	for entry: Dictionary in Omens.active(state):
		var id: String = str(entry["id"])
		current.append(id)
		var badge: Control = badges.get(id)
		if not is_instance_valid(badge) or badge.is_queued_for_deletion() or badge.get_parent() != host:
			badge = Badge.new()
			badge.name = "Omen_" + id
			badge.entry = entry.duplicate(true)
			badge.set_meta("omen_id", id)
			host.add_child(badge)
			badges[id] = badge
			if _initialized and not _previous_ids.has(id): badge.gain(reduced_motion)
		else:
			var refreshed: bool = int(entry["fights_left"]) > int(badge.entry.get("fights_left", 0))
			badge.update_entry(entry)
			if refreshed: badge.gain(reduced_motion)
		# Rebuilds of the relic grid must preserve ordering after relics and Rites.
		host.move_child(badge, host.get_child_count() - 1)
	for id: String in badges.keys():
		if current.has(id): continue
		var badge: Control = badges[id]
		if is_instance_valid(badge) and not badge.is_queued_for_deletion():
			host.move_child(badge, host.get_child_count() - 1)
			badge.expire()
		badges.erase(id)
	_previous_ids = current
	_initialized = true

func clear_relic_children(host: GridContainer) -> void:
	# Relic revisions rebuild their own badges. Keep omen nodes alive so an
	# expiry at a combat boundary can still complete its authored 0.3 s fade.
	for child: Node in host.get_children():
		if child.has_meta("omen_id"): continue
		host.remove_child(child)
		child.queue_free()

func has_visible_badges(host: GridContainer) -> bool:
	for child: Node in host.get_children():
		if child.has_meta("omen_id") and not child.is_queued_for_deletion(): return true
	return false
