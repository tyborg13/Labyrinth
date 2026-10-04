extends RefCounted

const Socket = preload("res://scripts/combat_hud_socket.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Palette = preload("res://scripts/ui_palette.gd")

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
	socket.mouse_default_cursor_shape = Control.CURSOR_ARROW
	return socket

static func active_rite(entry: Dictionary, rite_index: int, art: Texture2D) -> Button:
	var socket := Socket.new()
	socket.name = "ActiveRite_%d" % rite_index
	socket.socket_size = 48.0
	socket.set_meta("rite_card_id", str(entry.get("card_id", "")))
	var mark: Texture2D = ActionIcons.icon_texture(str(entry.get("icon", "rite")))
	socket.setup(art if art != null else mark, str(entry.get("tooltip", "")))
	socket.mouse_default_cursor_shape = Control.CURSOR_ARROW
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
	socket.interactive = false
	socket.mouse_filter = Control.MOUSE_FILTER_PASS
	socket.set_meta("header_utility", true)
	socket.set_meta("defiance_remaining", remaining)
	socket.set_meta("defiance_capacity", capacity)
	var tooltip: String = (
		"DEFIANCE %d / %d\nLethal health loss spends 1 to restore 25%% max health.\n"
		+ "Every fourth permanent level grants 1. Defiance does not refill during a run."
	) % [remaining, capacity]
	socket.setup(AssetLoader.load_texture("res://assets/art/icons/defiance.png"), tooltip, "%d/%d" % [remaining, capacity])
	socket.get_node("Badge").name = "DefianceCount"
	socket.disabled = remaining <= 0
	return socket
