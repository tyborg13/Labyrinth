extends RefCounted

const Socket = preload("res://scripts/combat_hud_socket.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const GameData = preload("res://scripts/game_data.gd")
const TempoRelicRules = preload("res://scripts/tempo_relic_rules.gd")

static func apply_badge_state(socket: Button, relic_id: String, definition: Dictionary, combat_state: Dictionary) -> void:
	var icon: CanvasItem = socket.get_node_or_null("Icon") as CanvasItem
	for effect: Dictionary in GameData.relic_effects_for_ids([relic_id]):
		if str(effect.get("type", "")) == "unused_play_extra_turn" and TempoRelicRules.used(combat_state, effect):
			if icon != null:
				icon.modulate.a = 0.45
			socket.tooltip_text += "\nUsed this combat."
	for effect: Dictionary in definition.get("effects", []):
		if str(effect.get("type", "")) == "store_consumed_surface_release":
			var stored: Array = combat_state.get("relic_stored_surfaces", []) as Array
			socket.tooltip_text += "\nStored: " + element_names(stored, true)
			_add_stored_surfaces(socket, stored)
		if str(effect.get("type", "")) == "combat_element_knots":
			var tied: Array = combat_state.get("relic_element_knots", []) as Array
			var count_badge: Label = socket.get_node_or_null("Badge") as Label
			if count_badge != null:
				count_badge.name = "RelicKnots"
				count_badge.text = str(tied.size())
				count_badge.visible = true
				socket.call_deferred("_layout")
			socket.tooltip_text += knots_tooltip(effect, tied)

static func _add_stored_surfaces(socket: Button, stored: Array) -> void:
	var pip_layer := Control.new()
	pip_layer.name = "RelicStoredSurfaces"
	pip_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pip_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	socket.add_child(pip_layer)
	for pip_index: int in range(stored.size()):
		var backing := Panel.new()
		backing.name = "RelicStoredSurface_%d" % pip_index
		backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		backing.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		backing.offset_left = Typography.scaled_value(socket, 2.0 + pip_index * 16.0)
		backing.offset_right = backing.offset_left + Typography.scaled_value(socket, 16.0)
		backing.offset_top = -Typography.scaled_value(socket, 18.0)
		backing.offset_bottom = -Typography.scaled_value(socket, 2.0)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.07, 0.05, 0.08, 0.86)
		style.border_color = Palette.GOLD_DIM
		style.set_border_width_all(maxi(1, roundi(Typography.scaled_value(socket, 1.0))))
		style.set_corner_radius_all(roundi(Typography.scaled_value(socket, 8.0)))
		backing.add_theme_stylebox_override("panel", style)
		pip_layer.add_child(backing)
		var pip := TextureRect.new()
		pip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pip.texture = ActionIcons.icon_texture("surface_" + str(stored[pip_index]))
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		backing.add_child(pip)

static func element_names(elements: Array, surfaces: bool = false) -> String:
	var names := PackedStringArray()
	for element: String in elements:
		names.append("Electrified" if surfaces and element == "electrified" else element.capitalize())
	return ", ".join(names) if not names.is_empty() else "nothing"

static func knots_tooltip(effect: Dictionary, tied: Array) -> String:
	var detail: String = "\nKnots: %s (%d of %d)" % [element_names(tied), tied.size(), int(effect["max_knots"])]
	if tied.size() >= int(effect["pierce_threshold"]): detail += ": attacks Pierce"
	if tied.size() >= int(effect["chain_threshold"]): detail += " and Chain %d" % int(effect["chain"])
	if tied.size() >= int(effect["block_threshold"]): detail += "; every card grants %d Block" % int(effect["block"])
	return detail + "."

static func relic(relic_id: String, definition: Dictionary, stored_time: int = -1, capacity: int = 0) -> Button:
	var socket := Socket.new()
	socket.socket_size = 48.0
	socket.set_meta("relic_id", relic_id)
	var tooltip: String = "%s\n%s" % [str(definition.get("name", relic_id)), str(definition.get("description", ""))]
	if stored_time >= 0:
		tooltip += "\nStored Time: %d / %d" % [stored_time, capacity]
	socket.setup(AssetLoader.load_texture(str(definition.get("icon_path", ""))), tooltip, str(stored_time) if stored_time >= 0 else "")
	if stored_time >= 0:
		socket.get_node("Badge").name = "RelicTimeReserve"
	socket.inspect_only = true
	return socket

static func active_rite(entry: Dictionary, rite_index: int, art: Texture2D) -> Button:
	var socket := Socket.new()
	socket.name = "ActiveRite_%d" % rite_index
	socket.socket_size = 48.0
	socket.set_meta("rite_card_id", str(entry.get("card_id", "")))
	var mark: Texture2D = ActionIcons.icon_texture(str(entry.get("icon", "rite")))
	socket.setup(art if art != null else mark, str(entry.get("tooltip", "")))
	socket.inspect_only = true
	if art != null:
		socket.get_node("Icon").name = "RiteArt"
		var backing := Panel.new()
		backing.name = "RiteMarkBacking"
		backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Palette.INK_2
		style.border_color = Palette.GOLD_DIM
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		backing.add_theme_stylebox_override("panel", style)
		backing.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		backing.offset_left = -Typography.scaled_value(socket, 20.0)
		backing.offset_top = -Typography.scaled_value(socket, 20.0)
		socket.add_child(backing)
		var icon := TextureRect.new()
		icon.name = "RiteMark"
		icon.texture = mark
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 2.0
		icon.offset_top = 2.0
		icon.offset_right = -2.0
		icon.offset_bottom = -2.0
		backing.add_child(icon)
	else:
		socket.get_node("Icon").name = "RiteMark"
	return socket

static func defiance(remaining: int, capacity: int) -> Button:
	var socket := Socket.new()
	socket.name = "DefianceBadge"
	socket.socket_size = 48.0
	socket.inspect_only = true
	socket.set_meta("header_utility", true)
	socket.set_meta("defiance_remaining", remaining)
	socket.set_meta("defiance_capacity", capacity)
	var tooltip: String = (
		"DEFIANCE %d / %d\nLethal health loss spends 1 to restore 25%% max health.\n"
		+ "Every fourth permanent level grants 1. Defiance does not refill during a run."
	) % [remaining, capacity]
	socket.setup(AssetLoader.load_texture("res://assets/art/icons/defiance.png"), tooltip, "%d/%d" % [remaining, capacity])
	socket.get_node("Badge").name = "DefianceCount"
	socket.dimmed = remaining <= 0
	return socket
