extends RefCounted
## Presentation only: ids are supplied by EventRules, never rolled here.
const Data = preload("res://scripts/game_data.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Builder = preload("res://scripts/item_preview_builders.gd")
const Tooltip = preload("res://scripts/ui_tooltip_panel.gd")
const Surface = preload("res://scripts/ui_component_surface.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Omens = preload("res://scripts/omen_badges.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Separation = preload("res://scripts/event_reward_separation.gd")
const MAX_WIDTH: float = 940.0
const ICON_SIZE: float = 128.0
const GEAR_CARD_SCALE: float = 0.6
const TRANSFORM_SCALE: float = 0.5
const DETAIL_PANEL_WIDTH: float = 420.0

static func first_concrete(lines: Array) -> Dictionary:
	for line: Dictionary in lines:
		if str(line.get("kind", "plain")) != "plain" and not (line.get("ids", []) as Array).is_empty(): return line.duplicate(true)
	return {}

static func outcome_line(outcome: Dictionary) -> Dictionary:
	var kind: String = str(outcome.get("type", "plain"))
	if kind == "transform_magic": kind = "transform"
	var ids: Array[String]
	if outcome.has("to"): ids.assign([str(outcome["from"]), str(outcome["to"])])
	elif outcome.has("id"): ids.append(str(outcome["id"]))
	elif outcome.has("cards"): ids.assign(outcome["cards"])
	return {"kind": kind, "ids": ids}

static func build(line: Dictionary, state: Dictionary, beat_only: bool = false) -> Control:
	var work: Dictionary = begin_build(line, state, beat_only)
	while not build_next(work): pass
	return work["stage"]

## The same native tree can be assembled one object at a time under event open.
## Jobs contain data and parent nodes, never callbacks retaining their owner.
static func begin_build(line: Dictionary, state: Dictionary, beat_only: bool = false) -> Dictionary:
	var kind: String = str(line.get("kind", "plain"))
	var ids: Array = line.get("ids", [])
	var jobs: Array[Dictionary]
	var stage := Control.new()
	stage.name = "EventRewardPreview"
	stage.set_meta("preview_line", line.duplicate(true))
	stage.set_meta("beat_only", beat_only)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	stage.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	# CardWidget creates its keyword controls in _ready. Disable those once,
	# after the subtree is ready, without inspecting it on the frame path.
	stage.ready.connect(ignore_input.bind(stage), CONNECT_ONE_SHOT)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	stage.add_child(row)
	var content: Control = row
	if kind in ["transform", "reforge"]:
		stage.remove_child(row)
		row.free()
		var pairs := VBoxContainer.new()
		stage.add_child(pairs)
		content = pairs
		for index: int in range(0, mini(ids.size(), 6), 2):
			if index + 1 >= ids.size(): break
			var pair := HBoxContainer.new()
			pair.alignment = BoxContainer.ALIGNMENT_CENTER
			pairs.add_child(pair)
			var object_kind: String = "equipment" if kind == "reforge" else "card"
			var factor: float = TRANSFORM_SCALE if kind == "transform" else 1.0
			jobs.append(_object_job(pair, 0, object_kind, str(ids[index]), factor))
			pair.add_child(_label("→", Typography.SIZE_SECTION, Palette.GOLD))
			jobs.append(_object_job(pair, 2, object_kind, str(ids[index + 1]), factor))
	else:
		for index: int in range(ids.size()): jobs.append(_object_job(row, index, kind, str(ids[index]), 1.0, beat_only))
	return {"stage": stage, "content": content, "jobs": jobs, "line": line, "state": state, "beat_only": beat_only}

static func _object_job(parent: Control, index: int, kind: String, id: String, factor: float, beat_only: bool = false) -> Dictionary:
	return {"parent": parent, "index": index, "kind": kind, "id": id, "factor": factor, "beat_only": beat_only}

## Returns true only after fitting/decorating the completed subtree. At most one
## card or icon is instantiated per call, including equipment's embedded cards.
static func build_next(work: Dictionary) -> bool:
	var jobs: Array[Dictionary] = work["jobs"]
	if not jobs.is_empty():
		var job: Dictionary = jobs.pop_front()
		var child: Control = _object(job.kind, job.id, work.state, job.factor, job.beat_only, jobs)
		var parent: Control = job.parent
		parent.add_child(child)
		parent.move_child(child, mini(int(job.index), parent.get_child_count() - 1))
		work["last_object"] = child
		return false
	var stage: Control = work.stage
	var kind: String = str(work.line.get("kind", "plain"))
	var ids: Array = work.line.get("ids", [])
	var beat_only: bool = work.beat_only
	_fit(stage, work.content)
	if beat_only and kind not in ["transform", "reforge"]:
		var art_size: Vector2 = Builder.CARD_TOOLTIP_SIZE if kind in ["card", "card_choice", "item", "lose_item"] else Vector2.ONE * ICON_SIZE
		art_size *= work.content.scale.x
		stage.set_meta("reward_art_rect", Rect2(Vector2((stage.size.x - art_size.x) * 0.5, 0), art_size))
	# Negative gain receipts retain their native crush/dissolve presentation.
	var negative_beat: bool = beat_only and (kind == "lose_item" or (kind == "omen" and not ids.is_empty() and str(Data.omen_def(str(ids[0])).get("kind", "")) == "bane"))
	if not negative_beat: Separation.decorate(stage)
	if not beat_only: Separation.pool(stage, Rect2(Vector2.ZERO, stage.size))
	ignore_input(stage)
	return true

static func _fit(stage: Control, content: Control) -> void:
	var extent: Vector2 = content.get_combined_minimum_size()
	content.size = extent
	var factor: float = minf(1.0, MAX_WIDTH / maxf(1.0, extent.x))
	content.scale = Vector2.ONE * factor
	stage.size = extent * factor
	stage.custom_minimum_size = stage.size
	stage.pivot_offset = stage.size * 0.5

static func _object(kind: String, id: String, state: Dictionary, scale_hint: float = 1.0, beat_only: bool = false, pending: Variant = null) -> Control:
	if kind in ["card", "card_choice", "item", "lose_item"]:
		var builder := Builder.new()
		builder.state = state
		builder.use_run_display = true
		var dimensions: Vector2 = Builder.CARD_BASE_SIZE * scale_hint if scale_hint != 1.0 else Builder.CARD_TOOLTIP_SIZE
		var slot: Control = builder.card_preview(id, dimensions)
		slot.set_meta("reward_id", id)
		if kind == "lose_item":
			var art: TextureRect = slot.get_node("CardScaleFrame/CardWidget/Margin/VBox/ArtBleed/ArtFrame/Art") as TextureRect
			art.material = Surface.socket_material(0.0)
			if beat_only: return slot
			var column := VBoxContainer.new()
			column.add_child(slot)
			column.add_child(_label("You lose this.", Typography.SIZE_BODY, Palette.TEXT))
			return column
		return slot
	var definition: Dictionary = Data.equipment_def(id) if kind == "equipment" else Data.omen_def(id) if kind == "omen" else {"name": Icons.label("defiance")} if kind == "defiance" else Data.relic_def(id)
	var column := VBoxContainer.new()
	var path: String = Omens.icon_path(id) if kind == "omen" else Icons.icon_path("defiance") if kind == "defiance" else str(definition.get("icon_path", ""))
	column.add_child(icon_control(path))
	var rarity: String = str(definition.get("rarity", ""))
	var accent: Color = Color(Data.relic_rarity_accent(rarity))
	if kind == "omen":
		var tone: String = str(definition.get("kind", ""))
		accent = Palette.EVENT_BLESSING if tone == "blessing" else Palette.EVENT_BANE
	elif kind == "defiance": accent = Palette.GOLD
	if beat_only:
		column.add_child(_label(str(definition.get("name", id)).to_upper(), Typography.SIZE_BODY_LARGE, accent))
		return column
	var lines := PackedStringArray()
	if kind != "omen" and not rarity.is_empty(): lines.append(rarity.capitalize())
	if kind != "equipment": lines.append(str(definition.get("description", "")))
	var panel: PanelContainer = Tooltip.make_lines(str(definition.get("name", id)), lines, DETAIL_PANEL_WIDTH)
	panel.set_meta("reward_id", id)
	# The native tooltip surface has a -1 ornament. Raise this embedded panel
	# once so that ornament paints above the event's opaque painting/panel.
	panel.z_index = 1
	column.add_child(panel)
	var box: VBoxContainer = panel.get_child(0)
	(box.get_child(0) as Label).add_theme_color_override("font_color", accent)
	if kind == "omen":
		var tone_label := _label(str(definition.get("kind", "")).capitalize(), Typography.SIZE_BODY, accent)
		box.add_child(tone_label)
		box.move_child(tone_label, 1)
		box.add_child(_label("%d fights" % int(definition.get("fights", 3)), Typography.SIZE_BODY, Palette.TEXT_2))
	if kind == "equipment":
		var cards := HBoxContainer.new()
		cards.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(cards)
		for card_id: String in Data.equipment_cards(id, state):
			if pending == null: cards.add_child(_object("card", card_id, state, GEAR_CARD_SCALE))
			else: pending.append(_object_job(cards, pending.size(), "card", card_id, GEAR_CARD_SCALE))
	return column

static func icon_control(path: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = Assets.load_texture(path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ONE * ICON_SIZE
	icon.size = icon.custom_minimum_size
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_meta("event_reward_icon", true)
	return icon

static func _label(text: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = text
	Typography.set_label_size(label, font_size)
	label.add_theme_color_override("font_color", tint)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

static func ignore_input(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.focus_mode = Control.FOCUS_NONE
		node.tooltip_text = ""
	for child: Node in node.get_children(): ignore_input(child)
