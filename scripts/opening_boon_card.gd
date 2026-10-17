extends Control

## Non-spell offers use the director-approved choice surface, with the reward
## card's focus pose and NEW badge finish. Layout is authored at 1920 × 1080.
signal activated
signal preview_requested(owner: Control, id: String, kind: String)
signal preview_hidden

const Rules = preload("res://scripts/opening_boon_rules.gd")
const Data = preload("res://scripts/game_data.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const Strip = preload("res://scripts/ui_card_strip.gd")
const Socket = preload("res://scripts/ui_socket.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Inline = preload("res://scripts/inline_icon_text.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Card = preload("res://scripts/card_widget.gd")
const Router = preload("res://scripts/input_router.gd")
const Motion = preload("res://scripts/settings_store.gd")
const CARD_SIZE := Vector2(300.0, 400.0)
const PREVIEW_RECT := Rect2(24.0, 96.0, 252.0, 140.0)
const RULES_RECT := Rect2(24.0, 256.0, 252.0, 120.0)
const SOCKET_SIZE: float = 96.0
const GLYPH_SIZE: float = 64.0
const TAG_SIZE: int = 16
const TITLE_TOP: float = 40.0
# Same cubic/ease-out transition as CardWidget._update_pose.
const REWARD_POSE_SECONDS: float = 0.12
var _skin := UiSkin.new()
var _surface: PanelContainer
var _host: Node
var _tween: Tween
var _hovered: bool = false

func configure(host: Node, offer: Dictionary) -> void:
	_host = host
	name = "Boon_" + str(offer["boon"])
	size = CARD_SIZE
	custom_minimum_size = CARD_SIZE
	pivot_offset = CARD_SIZE * 0.5
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_surface = PanelContainer.new()
	_surface.name = "BoonSurface"
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_surface)
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_skin.apply_panel_surface(_surface, UiSkin.SURFACE_CHOICE)
	_tag(str(offer["column"]).to_upper())
	var title := _label(str(Rules.definitions()["boons"][offer["boon"]]["name"]))
	title.name = "BoonTitle"
	# Reward cards render their native 19px title at the reward widget scale.
	var reward_size: Vector2 = host.call("_reward_choice_card_size", 3, true)
	Typography.set_label_size(title, roundi(19.0 * reward_size.x / Card.BASE_CARD_SIZE.x))
	title.add_theme_font_override("font", Typography.ui_font())
	add_child(title)
	title.position = Vector2(24.0, TITLE_TOP)
	title.size = Vector2(252.0, title.get_minimum_size().y)
	var preview := Control.new()
	preview.name = "BoonPreviewZone"
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(preview)
	preview.position = PREVIEW_RECT.position
	preview.size = PREVIEW_RECT.size
	var activate := func() -> void: activated.emit()
	if offer.has("spells"): _spells(preview, offer["spells"], activate)
	for kind: String in ["item", "relic"]:
		if offer.has(kind): _object(preview, str(offer[kind]), kind, activate)
	if str(offer["boon"]) in ["vitality", "debt"]:
		var health: bool = str(offer["boon"]) == "vitality"
		_glyph(preview, "health" if health else "ember", "+%d" % int(Rules.definitions()["boons"][offer["boon"]]["max_hp" if health else "embers"]))
	var rules := RichTextLabel.new()
	rules.name = "BoonRules"
	rules.bbcode_enabled = true
	rules.scroll_active = false
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.mouse_filter = Control.MOUSE_FILTER_PASS
	Typography.apply_rich_text_role(rules, Typography.ROLE_BODY)
	rules.add_theme_color_override("default_color", Palette.TEXT)
	add_child(rules)
	rules.position = RULES_RECT.position
	rules.size = RULES_RECT.size
	if str(offer["boon"]) == "purge":
		rules.position.y = 0.0
		rules.size.y = CARD_SIZE.y
		rules.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rules.mouse_entered.connect(_pointer_changed)
	rules.mouse_exited.connect(_pointer_changed)
	Inline.apply_to(rules, "[center]" + Rules.text(offer) + "[/center]", Inline.DEFAULT_ICON_SCALE, true)
	gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed("ui_accept") or event.is_action_pressed(Router.ACTION_ACCEPT):
			accept_event()
			activated.emit()
	)
	mouse_entered.connect(_pointer_changed)
	mouse_exited.connect(_pointer_changed)
	focus_entered.connect(_pose)
	focus_exited.connect(_pose)

func _tag(text: String) -> void:
	var accent: Color = Palette.EMBER.lerp(Palette.GOLD_BRIGHT, 0.45)
	_host.call("_add_reward_card_badge", self, "BoonColumnTag", text, Vector2.ZERO, Vector2.ZERO, accent)
	var tag: PanelContainer = get_node("BoonColumnTag")
	var label: Label = tag.get_child(0)
	Typography.apply_eyebrow(label, TAG_SIZE, label.get_theme_color("font_color"))
	var extent := Vector2(ceilf(label.get_minimum_size().x + tag.get_theme_stylebox("panel").get_minimum_size().x), 26.0)
	tag.custom_minimum_size = extent
	tag.size = extent
	tag.position = Vector2((CARD_SIZE.x - extent.x) * 0.5, -extent.y * 0.5)

func _label(text: String) -> Label:
	var result := Label.new()
	result.text = text
	Typography.apply_label_role(result, Typography.ROLE_BODY)
	result.add_theme_color_override("font_color", Palette.GOLD_BRIGHT)
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func _spells(parent: Control, spells: Array, activate: Callable) -> void:
	# Five native 30px strips need a 2px reduction to fit the authored 140px
	# zone. Their native 15px names still render at the 14px readability floor.
	var factor: float = minf(1.0, parent.size.y / (30.0 * spells.size()))
	var top: float = (parent.size.y - spells.size() * 30.0 * factor) * 0.5
	for index: int in range(spells.size()):
		var id: String = str(spells[index])
		var strip := Strip.new()
		strip.name = "BoonSpell_%d_%s" % [index, id]
		parent.add_child(strip)
		strip.setup(id, str(Data.card_def(id).get("name", id)))
		strip.focus_mode = Control.FOCUS_NONE
		strip.size = Vector2(parent.size.x / factor, 30.0)
		strip.scale = Vector2.ONE * factor
		strip.position = Vector2(0.0, top + index * 30.0 * factor)
		strip.mouse_entered.connect(_pointer_changed)
		strip.mouse_exited.connect(_pointer_changed)
		strip.pressed.connect(activate)
		strip.hovered.connect(func(_id: String) -> void: preview_requested.emit(self, id, "spell"))
		strip.unhovered.connect(func(_id: String) -> void: preview_hidden.emit())

func _object(parent: Control, id: String, kind: String, activate: Callable) -> void:
	var spec: Dictionary = Data.equipment_def(id) if kind == "item" else Data.relic_def(id)
	var socket := Socket.new()
	socket.name = "BoonContent_" + id
	socket.socket_size = SOCKET_SIZE
	parent.add_child(socket)
	socket.setup(Assets.load_texture(str(spec.get("icon_path", ""))))
	socket.focus_mode = Control.FOCUS_NONE
	socket.position = Vector2((parent.size.x - SOCKET_SIZE) * 0.5, 0.0)
	socket.size = Vector2.ONE * SOCKET_SIZE
	socket.mouse_entered.connect(_pointer_changed)
	socket.mouse_exited.connect(_pointer_changed)
	socket.pressed.connect(activate)
	socket.mouse_entered.connect(func() -> void: preview_requested.emit(self, id, kind))
	socket.mouse_exited.connect(func() -> void: preview_hidden.emit())
	var label := _label(str(spec.get("name", id)))
	label.name = "BoonObjectName"
	label.custom_minimum_size.x = parent.size.x
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	label.position = Vector2(0.0, SOCKET_SIZE)
	label.size = Vector2(parent.size.x, parent.size.y - SOCKET_SIZE)

func _glyph(parent: Control, id: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.name = "BoonStat"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", Typography.SPACE_SMALL)
	parent.add_child(row)
	row.size = parent.size
	var icon := TextureRect.new()
	icon.name = "BoonKeywordGlyph"
	icon.texture = Icons.icon_texture(id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ONE * GLYPH_SIZE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var presentation: Control = load("res://scenes/card_widget.tscn").instantiate()
	var label: Label = presentation.call("_summary_value_label", value, Icons.tooltip(id), roundi(GLYPH_SIZE * Card.SUMMARY_VALUE_TO_ICON_RATIO), Icons.token_for(id, value))
	presentation.free()
	label.name = "BoonStatValue"
	row.add_child(label)

func _pointer_changed() -> void:
	_hovered = get_global_rect().has_point(get_global_mouse_position())
	_pose()

func _pose() -> void:
	var emphasized: bool = _hovered or has_focus()
	_skin.apply_choice_finish(_surface, Palette.GOLD, emphasized)
	var constants: Dictionary = _host.get_script().get_script_constant_map()
	var lift: float = float(constants["REWARD_CARD_HOVER_LIFT"]) if emphasized else 0.0
	var zoom: Vector2 = Vector2.ONE * (float(constants["REWARD_CARD_HOVER_SCALE"]) if emphasized else 1.0)
	z_index = 20 if emphasized else 0
	if _tween != null: _tween.kill()
	if Motion.applied_reduced_motion_enabled():
		position.y = lift
		scale = zoom
	else:
		_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "position:y", lift, REWARD_POSE_SECONDS)
		_tween.parallel().tween_property(self, "scale", zoom, REWARD_POSE_SECONDS)
