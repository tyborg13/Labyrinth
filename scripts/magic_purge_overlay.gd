extends Control

signal confirmed(card_id: String, source: String)
signal closed

const List = preload("res://scripts/magic_deck_list.gd")
const Data = preload("res://scripts/game_data.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Confirmation = preload("res://scripts/magic_purge_confirmation.gd")
const PileView = preload("res://scripts/pile_dialog_view.gd")
const Section = preload("res://scripts/ui_section_header.gd")
const StatChip = preload("res://scripts/ui_stat_chip.gd")
const PriceTag = preload("res://scripts/scavenger_price_tag.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const RowScroll = preload("res://scripts/magic_purge_row_scroll.gd")
const ScavengerAction = preload("res://scripts/scavenger_action.gd")
const ScavengerMaterials = preload("res://scripts/scavenger_materials.gd")
const StrikeLight = preload("res://scripts/strike_trail_fx.gd")
const BurnShader = preload("res://shaders/card_burn.gdshader")
const BURN_SECONDS: float = 0.70
const REDUCED_BURN_SECONDS: float = 0.25
const BURN_EASE_POWER: float = 1.4
const EMBER_COUNT: int = 12
const EMBER_SECONDS: float = 0.5
const EMBER_RISE := Vector2(40.0, 80.0)
const EMBER_DIAMETER := Vector2(2.0, 3.0)
const BURN_CHAR_RGBA: int = 0x281810ff
# The brief calls for "slight" drift but supplies no distance. Owner fills this.
const EMBER_SIDEWAYS_DRIFT_PX: float = 10.0
const MAX_COLUMNS: int = 7
const GRID_LAYOUT_CARD_WIDTH: float = 196.0
const CARD_GAP := Vector2(16.0, 20.0)
const CROWN_HEADROOM: float = 18.0
const BADGE_OVERFLOW_PADDING := Vector2(24.0, 24.0)
const HEADER_HEIGHT: float = 72.0
const HEADER_GAP: float = 16.0
const SIDE_MARGIN: float = 32.0
const TOP_MARGIN: float = 24.0
const BOTTOM_MARGIN: float = 28.0
const MIN_WIDTH: float = 760.0
const SCREEN_MARGIN: float = 24.0
const GRID_CONFIRM_MODULATE: float = 0.30
const HEADER_CONFIRM_MODULATE: float = 0.60
const SCRIM_ALPHA: float = 0.72
# The Scavenger's Purge service sits this far right of the Browse/Sell tabs.
const SCAVENGER_SERVICE_GAP: float = 28.0

var source: String = ""
var pending_card_id: String = ""
var _confirm: Button
var _list_cancel: Button
var _list_center: CenterContainer
var _confirmation: Control
var _rows: Dictionary = {}
var _can_afford: bool = true
var _host: Node
var _price: int = 0
var _held: int = 0
var _panel: PanelContainer
var _grid: Control
var _scroll: ScrollContainer
var _header: HBoxContainer
var _grid_panel_style: StyleBoxFlat
var _confirm_panel_style: StyleBoxFlat
var _columns: int = 1
var _return_card_id: String = ""
var _committing: bool = false
var _center_grid: bool = false

# A private, seekable presentation. Render the actual card subtree on its own
# canvas rather than flattening its z levels or rebuilding a similar-looking
# card proxy. The full-size target preserves subpixel placement and overhang.
class PurgeBurn extends Control:
	var elapsed: float = 0.0
	var card_rect: Rect2
	var burn_material: ShaderMaterial
	var sparks: Array[Dictionary]
	var _canvas: SubViewport
	var _paint: TextureRect
	var _seed: Vector2
	var _tail: bool = false
	var _last_ember: float = 0.0

	func configure(slot: Control, card_id: String, reduced_motion: bool = false) -> void:
		name = "CardProxy"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 1
		card_rect = slot.get_global_rect()
		size = Vector2(get_viewport_rect().size)
		_canvas = SubViewport.new()
		_canvas.name = "PurgeCardCanvas"
		_canvas.size = Vector2i(size)
		_canvas.transparent_bg = true
		_canvas.msaa_2d = get_viewport().msaa_2d
		_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_canvas)
		var card_transform: Transform2D = slot.get_global_transform()
		slot.reparent(_canvas, false)
		slot.position = card_transform.origin
		slot.scale = card_transform.get_scale()
		_paint = TextureRect.new()
		_paint.name = "PurgeCardComposite"
		_paint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_paint.show_behind_parent = true
		_paint.texture = _canvas.get_texture()
		_paint.size = size
		add_child(_paint)
		burn_material = ShaderMaterial.new()
		burn_material.shader = BurnShader
		burn_material.set_shader_parameter("card_origin", card_rect.position)
		burn_material.set_shader_parameter("card_size", card_rect.size)
		var card_hash: int = card_id.hash()
		_seed = Vector2(card_hash & 65535, (card_hash >> 16) & 65535)
		burn_material.set_shader_parameter("seed", _seed)
		var light: Array = StrikeLight.palette("none")
		burn_material.set_shader_parameter("warm_white", light[0])
		burn_material.set_shader_parameter("amber", light[1])
		burn_material.set_shader_parameter("ember_red", light[2])
		burn_material.set_shader_parameter("char_color", Color.hex(BURN_CHAR_RGBA))
		_paint.material = burn_material
		set_process(false)
		seek(0.0)
		if reduced_motion: return
		for index: int in range(EMBER_COUNT):
			var uv := Vector2((index + 0.5) / EMBER_COUNT, _lattice(index, card_hash))
			# Each birth is the exact threshold crossing at its origin, so even
			# the irregular parts of the burn shed sparks from the actual front.
			var birth: float = BURN_SECONDS * pow(burn_field(uv), 1.0 / BURN_EASE_POWER)
			sparks.append({"birth": birth, "origin": card_rect.position + uv * card_rect.size,
				"rise": lerpf(EMBER_RISE.x, EMBER_RISE.y, _lattice(index + EMBER_COUNT, card_hash)),
				"drift": lerpf(-EMBER_SIDEWAYS_DRIFT_PX, EMBER_SIDEWAYS_DRIFT_PX, _lattice(index + EMBER_COUNT * 2, card_hash)),
				"diameter": lerpf(EMBER_DIAMETER.x, EMBER_DIAMETER.y, _lattice(index + EMBER_COUNT * 3, card_hash))})
			_last_ember = maxf(_last_ember, birth + EMBER_SECONDS)

	func fade(opacity: float) -> void:
		burn_material.set_shader_parameter("opacity", opacity)

	func seek(seconds: float) -> void:
		elapsed = maxf(0.0, seconds)
		burn_material.set_shader_parameter("threshold", pow(clampf(elapsed / BURN_SECONDS, 0.0, 1.0), BURN_EASE_POWER))
		_paint.visible = elapsed < BURN_SECONDS
		queue_redraw()

	func release_embers(parent: Node) -> void:
		# Card removal completes at .70s. Let already-born sparks finish their
		# .5s lives without delaying the existing dialog/Hearth continuation.
		_canvas.queue_free()
		_paint.hide()
		var depth: int = z_index
		var ancestor: Node = get_parent()
		while ancestor is CanvasItem:
			depth += (ancestor as CanvasItem).z_index
			if not (ancestor as CanvasItem).z_as_relative: break
			ancestor = ancestor.get_parent()
		reparent(parent, true)
		z_as_relative = false
		z_index = depth
		_tail = true
		set_process(true)

	func _process(delta: float) -> void:
		if not _tail: return
		seek(elapsed + delta)
		if elapsed >= _last_ember: queue_free()

	func _draw() -> void:
		var light: Array = StrikeLight.palette("none")
		for spark: Dictionary in sparks:
			var age: float = elapsed - float(spark["birth"])
			if age < 0.0 or age >= EMBER_SECONDS: continue
			var t: float = age / EMBER_SECONDS
			var point: Vector2 = spark["origin"] + Vector2(float(spark["drift"]), -float(spark["rise"])) * t
			var radius: float = float(spark["diameter"]) * 0.5
			draw_colored_polygon(_diamond(point, radius), Color(light[2], 1.0 - t))
			draw_colored_polygon(_diamond(point, radius * 0.5), Color(light[1], 1.0 - t))

	static func _diamond(point: Vector2, radius: float) -> PackedVector2Array:
		return PackedVector2Array([point + Vector2(0, -radius), point + Vector2(radius, 0), point + Vector2(0, radius), point + Vector2(-radius, 0)])

	func burn_field(uv: Vector2) -> float:
		var point: Vector2 = uv * 6.0 + _seed
		var cell := Vector2i(floori(point.x), floori(point.y))
		var f: Vector2 = point - Vector2(cell)
		f = f * f * (Vector2.ONE * 3.0 - f * 2.0)
		var noise: float = lerpf(lerpf(_lattice(cell.x, cell.y), _lattice(cell.x + 1, cell.y), f.x), lerpf(_lattice(cell.x, cell.y + 1), _lattice(cell.x + 1, cell.y + 1), f.x), f.y)
		return 0.65 * (1.0 - uv.y) + 0.35 * noise

	static func _lattice(x: int, y: int) -> float:
		var h: int = (x * 374761393 + y * 668265263) & 0xffffffff
		h = ((h ^ (h >> 13)) * 1274126177) & 0xffffffff
		h = h ^ (h >> 16)
		return float(h & 65535) / 65535.0

# Purge owns this larger treatment; other section eyebrows keep their sizing.
class PurgeHeading extends Section:
	func _get_minimum_size() -> Vector2:
		var minimum: Vector2 = super._get_minimum_size()
		minimum.y = maxf(minimum.y, _title.get_minimum_size().y)
		return minimum

	func _layout() -> void:
		Typography.apply_eyebrow(_title, Typography.SIZE_SECTION_LARGE, Palette.GOLD_BRIGHT)
		_title.add_theme_color_override("font_outline_color", Palette.TEXT_OUTLINE)
		_title.add_theme_constant_override("outline_size", 3)
		_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		preload("res://scripts/ui_component_surface.gd").label_style(_count, Typography.SIZE_BODY_LARGE, Palette.TEXT_2)
		_title.position = Vector2.ZERO
		_title.size = Vector2(_title.get_minimum_size().x, size.y)
		_count.position = Vector2(_title.size.x + Typography.scaled_value(self, 10.0), 0.0)
		_count.size = Vector2(_count.get_minimum_size().x, size.y)
		queue_redraw()

func configure(host: Node, state: Dictionary, purge_source: String, _dialog_size: Vector2) -> void:
	_host = host
	source = purge_source
	_price = host.get("_run_engine").scavenger_purge_price(state) if source == "scavenger" else 0
	_held = host.get("_run_engine").held_embers(state)
	_can_afford = source != "scavenger" or _held >= _price
	name = "MagicPurgeOverlay"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_as_relative = false
	z_index = Confirmation.highest_visible_z(get_parent(), self) + 1
	# The pile scrim already owns the brief's exact 0.02 neutral RGB.
	var scrim: Color = host.get("_pile_scrim").color
	scrim.a = SCRIM_ALPHA
	add_child(Confirmation.backdrop(scrim))
	_list_center = CenterContainer.new()
	add_child(_list_center)
	_list_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.name = "MagicPurgePanel"
	_list_center.add_child(_panel)
	var pile: PanelContainer = host.get("_pile_dialog")
	var style: StyleBox = pile.get_meta(UiSkin.OUTER_PANEL_BASELINE_STYLE_META).duplicate()
	# Panel margins are the sole insets; no inherited 16px pile padding stacks up.
	style.content_margin_left = SIDE_MARGIN
	style.content_margin_right = SIDE_MARGIN
	style.content_margin_top = TOP_MARGIN
	style.content_margin_bottom = BOTTOM_MARGIN
	PileView.finish_panel(_panel, style)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", int(HEADER_GAP))
	_panel.add_child(content)
	var header := HBoxContainer.new()
	header.name = "MagicPurgeHeader"
	_header = header
	header.custom_minimum_size.y = HEADER_HEIGHT
	header.add_theme_constant_override("separation", int(CARD_GAP.x))
	content.add_child(header)
	var entries: Array[Dictionary] = List.entries(state.get("attuned_magic_cards", []) as Array)
	_columns = columns_for(entries.size())
	var dialog_size: Vector2 = dialog_size_for(entries.size(), source == "scavenger" and not _can_afford)
	var frame_size: Vector2 = Typography.modal_size(self, dialog_size)
	_center_grid = frame_size.y > _picker_height_for(entries.size())
	var available_width: float = frame_size.x - SIDE_MARGIN * 2.0 - BADGE_OVERFLOW_PADDING.x
	_columns = maxi(1, mini(_columns, floori((available_width + CARD_GAP.x) / (PileView.CARD_SIZE.x + CARD_GAP.x))))
	var bounded_grid: bool = frame_size != dialog_size or _columns != columns_for(entries.size())
	var heading := PurgeHeading.new()
	heading.name = "MagicPurgeHeading"
	heading.setup("PURGE A SPELL", "%d spells" % (state.get("attuned_magic_cards", []) as Array).size())
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	if source == "scavenger":
		var price := StatChip.new()
		price.name = "MagicPurgePrice"
		price.setup(Assets.load_texture(PriceTag.EMBER_PATH), str(_price), "PRICE", Palette.GOLD_BRIGHT if _can_afford else Palette.DANGER)
		price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(price)
	_list_cancel = Button.new()
	_list_cancel.name = "CancelMagicPurgeList"
	_list_cancel.text = "X"
	UiSkin.new().apply_button_stylebox_overrides(_list_cancel, UiSkin.VARIANT_ICON)
	UiSkin.new().apply_button_text_overrides(_list_cancel)
	Typography.set_button_size(_list_cancel, Typography.SIZE_SMALL)
	_list_cancel.custom_minimum_size = Vector2(40.0, 40.0)
	_list_cancel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_list_cancel.pressed.connect(cancel)
	header.add_child(_list_cancel)
	# Let the viewport use the existing right inset for the badge overhang.
	# Its matching content padding keeps the card columns and header unchanged.
	var scroll_host := Control.new()
	scroll_host.name = "MagicPurgeScrollHost"
	scroll_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(scroll_host)
	_scroll = ScrollContainer.new() if bounded_grid else RowScroll.new()
	_scroll.name = "MagicPurgeScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if bounded_grid or entries.size() > _columns * RowScroll.VISIBLE_ROWS else ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = bounded_grid
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var padding := StyleBoxEmpty.new()
	padding.content_margin_top = CROWN_HEADROOM
	_scroll.add_theme_stylebox_override("panel", padding)
	scroll_host.add_child(_scroll)
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_right = BADGE_OVERFLOW_PADDING.x
	_grid = Control.new()
	_grid.name = "MagicPurgeRows"
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_grid)
	for entry: Dictionary in entries:
		var cell: Button = PileView.card_cell(host, str(entry["card_id"]), int(entry["count"]), select_card)
		_rows[_rows.size()] = cell
		_grid.add_child(cell)
	if entries.is_empty():
		var empty: Label = preload("res://scripts/character_menu_view.gd").empty_copy(preload("res://scripts/event_rules.gd").MAGIC_REQUIREMENT_COPY)
		empty.name = "MagicPurgeEmpty"
		_grid.add_child(empty)
		empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not entries.is_empty() and _scroll is RowScroll:
		(_scroll as RowScroll).configure(_grid, _columns, ceili(PileView.CARD_SIZE.y + CARD_GAP.y))
	_grid.resized.connect(_layout_grid)
	_scroll.resized.connect(_layout_grid)
	_panel.custom_minimum_size = frame_size if not entries.is_empty() else Typography.modal_size(self, _dialog_size)
	# Reserve the scrollbar in the existing right margin, keeping the
	# card spacing and the outer dialog width exact as columns reflow.
	if entries.size() > _columns * RowScroll.VISIBLE_ROWS:
		var bar_width: float = _scroll.get_v_scroll_bar().get_combined_minimum_size().x
		_panel.get_theme_stylebox("panel").content_margin_right = SIDE_MARGIN - bar_width
	_grid_panel_style = _panel.get_theme_stylebox("panel") as StyleBoxFlat
	_confirm_panel_style = _grid_panel_style.duplicate() as StyleBoxFlat
	_confirm_panel_style.bg_color.a = 1.0
	_contain_list_focus()
	_confirmation = Confirmation.new()
	add_child(_confirmation)
	_confirmation.configure(host)
	_confirmation.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_confirmation.clip_contents = true
	_panel.item_rect_changed.connect(_layout_confirmation_frame)
	_header.item_rect_changed.connect(_layout_confirmation_frame)
	_layout_confirmation_frame()
	_confirm = _confirmation.confirm_button
	_confirm.disabled = true
	_confirmation.accepted.connect(func() -> void:
		if pending_card_id.is_empty() or _confirm.disabled or _committing: return
		_committing = true
		_confirm.disabled = true
		confirmed.emit(pending_card_id, source)
	)
	_confirmation.cancelled.connect(cancel)
	call_deferred("focus_default")

func _layout_confirmation_frame() -> void:
	if _confirmation == null: return
	_confirmation.content_top = _header.get_global_rect().end.y - _panel.global_position.y + Typography.SPACE_SMALL
	_confirmation.content_bottom_inset = BOTTOM_MARGIN
	_confirmation.global_position = _panel.global_position
	_confirmation.size = _panel.size
	_confirmation.call("_layout")

static func dialog_size_for(identities: int, show_wallet: bool = false) -> Vector2:
	var confirmation_height: float = TOP_MARGIN + HEADER_HEIGHT + Typography.SPACE_SMALL + Confirmation.minimum_stack_height(show_wallet) + BOTTOM_MARGIN
	return Vector2(layout_width_for(identities), minf(1080.0 - SCREEN_MARGIN * 2.0, maxf(_picker_height_for(identities), confirmation_height)))

static func _picker_height_for(identities: int) -> float:
	var cols: int = columns_for(identities)
	var rows: int = maxi(1, mini(ceili(float(identities) / cols), RowScroll.VISIBLE_ROWS))
	var viewport_height: float = rows * PileView.CARD_SIZE.y + (rows - 1) * CARD_GAP.y + CROWN_HEADROOM + BADGE_OVERFLOW_PADDING.y
	return minf(1080.0 - SCREEN_MARGIN * 2.0, TOP_MARGIN + HEADER_HEIGHT + HEADER_GAP + viewport_height + BOTTOM_MARGIN)

static func layout_width_for(identities: int) -> float:
	var cols: int = maxi(1, mini(identities, MAX_COLUMNS))
	return maxf(MIN_WIDTH, cols * GRID_LAYOUT_CARD_WIDTH + (cols - 1) * CARD_GAP.x + SIDE_MARGIN * 2.0)

static func columns_for(identities: int) -> int:
	var available: float = layout_width_for(identities) - SIDE_MARGIN * 2.0
	return maxi(1, mini(identities, floori((available + CARD_GAP.x) / (PileView.CARD_SIZE.x + CARD_GAP.x))))

func _layout_grid() -> void:
	var rows: int = ceili(float(_rows.size()) / _columns)
	_grid.custom_minimum_size.y = rows * PileView.CARD_SIZE.y + maxi(0, rows - 1) * CARD_GAP.y + BADGE_OVERFLOW_PADDING.y
	# Only the grown picker spends its extra height equally above/below the
	# grid. Preserve the authored crown/badge padding and two-row scroll pitch.
	var page_height: float = _scroll.size.y - _scroll.get_theme_stylebox("panel").get_minimum_size().y
	var top: float = maxf(0.0, (page_height - _grid.custom_minimum_size.y) * 0.5) if _center_grid else 0.0
	var card_width: float = _grid.size.x - BADGE_OVERFLOW_PADDING.x
	for index: int in range(_rows.size()):
		var row: int = index / _columns
		var row_count: int = mini(_columns, _rows.size() - row * _columns)
		var row_width: float = row_count * PileView.CARD_SIZE.x + (row_count - 1) * CARD_GAP.x
		var cell: Control = _rows[index]
		cell.position = Vector2((card_width - row_width) * 0.5 + (index % _columns) * (PileView.CARD_SIZE.x + CARD_GAP.x), top + row * ceili(PileView.CARD_SIZE.y + CARD_GAP.y))

func select_card(card_id: String) -> void:
	if _committing: return
	var owned: bool = false
	for row: Control in _rows.values():
		if str(row.get("card_id")) == card_id: owned = true
	if not owned: return
	pending_card_id = card_id
	_return_card_id = card_id
	_host.call("_clear_controller_loadout_tooltip")
	# Keep the dialog/frame opaque; only its contents dim behind the card.
	_panel.add_theme_stylebox_override("panel", _confirm_panel_style)
	_scroll.modulate = Color(1, 1, 1, GRID_CONFIRM_MODULATE)
	# The selected card replaces the list inside the same frame. Keep its layout
	# and scroll position, without dimmed rows showing through the halo/buttons.
	_grid.modulate = Color(1, 1, 1, 0)
	_header.modulate = Color(1, 1, 1, HEADER_CONFIRM_MODULATE)
	for row: Control in _rows.values(): row.focus_mode = Control.FOCUS_NONE
	_list_cancel.focus_mode = Control.FOCUS_NONE
	_confirmation.present(card_id, _price, source == "scavenger", _can_afford, _held)

func cancel() -> void:
	if _committing: return
	if not pending_card_id.is_empty():
		pending_card_id = ""
		_confirmation.hide()
		_panel.add_theme_stylebox_override("panel", _grid_panel_style)
		_scroll.modulate = Color.WHITE
		_grid.modulate = Color.WHITE
		_header.modulate = Color.WHITE
		for row: Control in _rows.values(): row.focus_mode = Control.FOCUS_ALL
		_list_cancel.focus_mode = Control.FOCUS_ALL
		_confirm.disabled = true
		focus_default()
	else: closed.emit()

func play_exhaust() -> void:
	_committing = true
	_confirm.disabled = true
	_confirmation.cancel_button.disabled = true
	var slot: Control = _confirmation.get("_card_slot")
	var reduced_motion: bool = bool(_host.call("_reduced_motion_enabled"))
	var burn := PurgeBurn.new()
	_confirmation.add_child(burn)
	burn.configure(slot, pending_card_id, reduced_motion)
	var tween: Tween = create_tween()
	if reduced_motion: tween.tween_method(burn.fade, 1.0, 0.0, REDUCED_BURN_SECONDS)
	else: tween.tween_method(burn.seek, 0.0, BURN_SECONDS, BURN_SECONDS)
	await tween.finished
	if not reduced_motion: burn.release_embers(get_parent())

func retry_confirmation() -> void:
	_committing = false
	_confirm.disabled = not _can_afford

func focus_scope() -> Control:
	return _confirmation if _confirmation.visible else self

func _contain_list_focus() -> void:
	var controls: Array[Control]
	for row: Control in _rows.values(): controls.append(row)
	controls.append(_list_cancel)
	for index: int in range(controls.size()):
		var control: Control = controls[index]
		control.focus_previous = control.get_path_to(controls[posmod(index - 1, controls.size())])
		control.focus_next = control.get_path_to(controls[(index + 1) % controls.size()])
		var left: Control = controls[posmod(index - 1, _rows.size())] if not _rows.is_empty() and control != _list_cancel else controls[0]
		var right: Control = controls[(index + 1) % _rows.size()] if not _rows.is_empty() and control != _list_cancel else controls[0]
		var up: Control = _rows[index - _columns] if index >= _columns and control != _list_cancel else _list_cancel
		var down: Control = _list_cancel
		if not _rows.is_empty():
			var last_row: int = (_rows.size() - 1) / _columns
			down = _rows[mini(index + _columns, _rows.size() - 1)] if index / _columns < last_row else _rows[index % _columns]
		if control == _list_cancel:
			up = controls[0]
			down = controls[0]
		control.focus_neighbor_left = control.get_path_to(left)
		control.focus_neighbor_right = control.get_path_to(right)
		control.focus_neighbor_top = control.get_path_to(up)
		control.focus_neighbor_bottom = control.get_path_to(down)

func contain_input(event: InputEvent) -> bool:
	if _committing: return true
	var focus: Control = get_viewport().gui_get_focus_owner()
	var scope: Control = focus_scope()
	if focus != null and scope.is_ancestor_of(focus) and focus.is_visible_in_tree(): return false
	for action: StringName in [&"ui_focus_next", &"ui_focus_prev", &"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_accept", preload("res://scripts/input_router.gd").ACTION_ACCEPT]:
		if event.is_action_pressed(action):
			focus_default()
			return true
	return false

# Character rows still call this hook; purge now uses real cards and has no row
# selection ornament. Preserve the Character hook without changing its rendering.
static func apply_selection(_tile: PanelContainer) -> void:
	pass

func focus_default() -> void:
	if not is_inside_tree() or _committing: return
	if _confirmation.visible: _confirmation.cancel_button.grab_focus()
	elif not _rows.is_empty():
		var target: Control = _rows[0]
		for row: Control in _rows.values():
			if str(row.get("card_id")) == _return_card_id: target = row
		target.grab_focus()
	else: _list_cancel.grab_focus()

# The service's price, inked on its strap in the shop's own shaded type.
static func _scavenger_price_ink(font_size: int, line_height: float) -> HBoxContainer:
	var ink := HBoxContainer.new()
	ink.name = "ScavengerPurgePrice"
	ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ink.add_theme_constant_override("separation", 5)
	var ember := TextureRect.new()
	ember.texture = Assets.load_texture(PriceTag.EMBER_PATH)
	ember.custom_minimum_size = Vector2(18.0, 22.0)
	ember.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ember.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ember.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ember.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ember.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ink.add_child(ember)
	var value := Label.new()
	value.name = "PriceTagValue"
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ScavengerMaterials.shade(value, font_size, line_height)
	ink.add_child(value)
	return ink

static func install_scavenger(host: Node, shop: Control) -> void:
	var buy: Button = shop.find_child("ScavengerBrowseMode", true, false)
	var sell: Button = shop.find_child("ScavengerSellMode", true, false)
	var tabs: Control = shop.find_child("ScavengerModeToggle", true, false)
	if buy == null or sell == null or tabs == null: return
	var button: Button = shop.find_child("ScavengerPurge", true, false)
	if button == null:
		# Purge is a paid service, not a third view of the shop: it stands apart
		# from the Browse/Sell tabs on the shop's BUY strap, its price inside it.
		button = ScavengerAction.new()
		button.name = "ScavengerPurge"
		Typography.set_button_size(button, 22)
		button.pressed.connect(host.call.bind("_open_magic_purge", "scavenger"))
		tabs.get_parent().add_child(button)
		var ink: HBoxContainer = _scavenger_price_ink(button.get_theme_font_size("font_size"), tabs.size.y - 14.0)
		button.add_child(ink)
		button.set("trailing", ink)
	var price: int = host.get("_run_engine").scavenger_purge_price(host.get("_run_state"))
	button.text = "Purge a spell"
	button.disabled = List.entries(host.get("_run_state").get("attuned_magic_cards", []) as Array).is_empty()
	button.tooltip_text = "You have no spells to purge." if button.disabled else "Remove a spell from your deck."
	var price_ink: HBoxContainer = button.get_node("ScavengerPurgePrice")
	var affordable: bool = host.get("_run_engine").held_embers(host.get("_run_state")) >= price
	var value: Label = price_ink.get_node("PriceTagValue")
	value.text = str(price)
	value.add_theme_color_override("font_color", Palette.GOLD_BRIGHT if affordable else Palette.DANGER_BRIGHT)
	price_ink.set_meta("affordable", affordable)
	price_ink.size = price_ink.get_combined_minimum_size()
	button.call("prepare_label")
	var caption_label: Label = button.get("_label")
	var caption: float = ceilf(caption_label.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_label.get_theme_font_size("font_size")).x)
	# Caption, gap and price between the strap's brass ends, with a little slack.
	var width: float = caption + price_ink.size.x + Typography.scaled_value(button, ScavengerAction.TRAILING_GAP) + 2.0 * ScavengerAction.TRAILING_EDGE + 4.0
	button.position = tabs.position + Vector2(tabs.size.x + SCAVENGER_SERVICE_GAP, 0.0)
	button.custom_minimum_size = Vector2(width, tabs.size.y)
	button.size = button.custom_minimum_size
	button.call("prepare_label")
	button.focus_neighbor_left = button.get_path_to(sell)
	button.focus_neighbor_right = button.get_path_to(shop.get("_leave_button"))
	sell.focus_neighbor_right = sell.get_path_to(button)
	shop.get("_leave_button").focus_neighbor_left = shop.get("_leave_button").get_path_to(button)
	var state: Dictionary = host.get("_run_state")
	var receipt: Dictionary = state.get("last_magic_purge", {})
	var notice: String = str(state.get("notice", ""))
	if str(receipt.get("source", "")) == "scavenger" and notice == "Purged %s." % str(Data.card_def(str(receipt.get("card_id", ""))).get("name", "")):
		# The fullscreen shop covers the room log. Reuse its existing text notice
		# surface so the persisted confirmation remains visible after closing.
		shop.call("_clear_receipt")
		shop.get("_dialogue_words").text = notice
