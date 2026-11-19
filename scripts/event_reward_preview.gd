extends RefCounted
## Presentation only: ids are supplied by EventRules, never rolled here.
const Data = preload("res://scripts/game_data.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Builder = preload("res://scripts/item_preview_builders.gd")
const Surface = preload("res://scripts/ui_component_surface.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Omens = preload("res://scripts/omen_badges.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Plate = preload("res://scripts/event_reward_plate.gd")
const Separation = preload("res://scripts/event_reward_separation.gd")
const MAX_WIDTH: float = 940.0
const ICON_SIZE: float = 128.0
const GEAR_CARD_SCALE: float = 0.6
const TRANSFORM_SCALE: float = 0.5
const HOVER_CARD_SCALE: float = 1.35

static func first_concrete(lines: Array) -> Dictionary:
	for line: Dictionary in lines:
		if str(line.get("kind", "plain")) != "plain" and not (line.get("ids", []) as Array).is_empty(): return line.duplicate(true)
	return {}

## The existing concrete reward takes priority over ancillary Health/Ember gains.
## Plain choice rows already own the exact player-facing gain copy.
static func hover_line(lines: Array) -> Dictionary:
	var concrete: Dictionary = first_concrete(lines)
	if not concrete.is_empty(): return concrete
	for line: Dictionary in lines:
		var text: String = str(line.get("text", ""))
		if text.begins_with("Gain ") and text.ends_with(" Embers."):
			return {"kind": "gain", "ids": ["ember"], "text": text}
		if text.contains("@icon(health)") and (text.begins_with("Heal ") or text.begins_with("+")):
			return {"kind": "gain", "ids": ["health"], "text": text.replace("@icon(health)", Icons.label("health"))}
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
static func begin_build(line: Dictionary, state: Dictionary, beat_only: bool = false, hover_cards: bool = true) -> Dictionary:
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
	row.name = "Rewards"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	stage.add_child(row)
	var content: Control = row
	if kind in ["transform", "reforge"]:
		stage.remove_child(row)
		row.free()
		var pairs := VBoxContainer.new()
		pairs.name = "Rewards"
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
	return {"stage": stage, "content": content, "jobs": jobs, "line": line, "state": state, "beat_only": beat_only, "hover_cards": hover_cards}

static func _object_job(parent: Control, index: int, kind: String, id: String, factor: float, beat_only: bool = false) -> Dictionary:
	return {"parent": parent, "index": index, "kind": kind, "id": id, "factor": factor, "beat_only": beat_only}

## Returns true only after fitting/decorating the completed subtree. At most one
## card or icon is instantiated per call, including equipment's embedded cards.
static func build_next(work: Dictionary) -> bool:
	var jobs: Array[Dictionary] = work["jobs"]
	if not jobs.is_empty():
		var job: Dictionary = jobs.pop_front()
		var dimensions_scale: float = job.factor
		# Enlarge only card art in hover previews, including gear's granted cards.
		# Result beats, transform pairs, relics, gear icons and items stay native.
		if not bool(work.beat_only) and bool(work.hover_cards) and str(work.line.get("kind", "")) in ["card", "card_choice", "equipment"] and str(job.kind) in ["card", "card_choice"]:
			dimensions_scale = (Builder.CARD_TOOLTIP_SIZE.x / Builder.CARD_BASE_SIZE.x if is_equal_approx(dimensions_scale, 1.0) else dimensions_scale) * HOVER_CARD_SCALE
		var child: Control
		if job.beat_only or job.get("embedded", false):
			child = _bare_object(job.kind, job.id, work.state, dimensions_scale, job.beat_only)
		else:
			child = _reward_plate(job, work, dimensions_scale)
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
	ignore_input(stage)
	return true

static func refit(stage: Control) -> void:
	_fit(stage, stage.get_node("Rewards"))

static func _fit(stage: Control, content: Control) -> void:
	var extent: Vector2 = content.get_combined_minimum_size()
	content.size = extent
	var factor: float = minf(1.0, MAX_WIDTH / maxf(1.0, extent.x))
	content.scale = Vector2.ONE * factor
	stage.custom_minimum_size = Vector2(minf(extent.x, MAX_WIDTH), extent.y * factor)
	stage.size = stage.custom_minimum_size
	stage.pivot_offset = stage.size * 0.5

static func _reward_plate(job: Dictionary, work: Dictionary, factor: float) -> Control:
	var kind: String = job.kind
	var id: String = job.id
	if kind in ["card", "card_choice", "item", "lose_item"]:
		# Item rewards are native cards too, with run-specific rules and costs.
		var plate: PanelContainer = Plate.make()
		var face: Control = _bare_object(kind, id, work.state, factor)
		if kind in ["item", "lose_item"]:
			var card: Control = face.find_child("CardWidget", true, false)
			var accent := Color(Data.card_def(id).get("accent", Data.card_rarity_accent(Data.card_rarity(id))))
			card.ready.connect(Plate.add_item_art_light.bind(card, accent), CONNECT_ONE_SHOT)
		face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		Plate.contents(plate).add_child(face)
		return plate
	if kind == "gain":
		var accent: Color = Palette.EMBER if id == "ember" else Palette.ALLY
		return Plate.with_icon(icon_control(Icons.icon_path(id)), str(work.line.text), accent)
	var definition: Dictionary = _definition(kind, id)
	var accent: Color = _accent(kind, id, definition)
	var rarity: String = str(definition.get("rarity", "")).capitalize()
	var description: String = str(definition.get("description", ""))
	var subtitle: String = str(definition.get("kind", "")).capitalize() if kind == "omen" else rarity
	var plate: PanelContainer = Plate.with_icon(icon_control(_icon_path(kind, id, definition)), str(definition.get("name", id)), accent, subtitle, description)
	plate.set_meta("reward_id", id)
	plate.set_meta("reward_description", description)
	var contents: VBoxContainer = Plate.contents(plate)
	if kind == "omen":
		contents.add_child(_label("%d fights" % int(definition.get("fights", 3)), Typography.SIZE_BODY, Palette.TEXT_2))
	if kind == "equipment":
		var cards := HBoxContainer.new()
		cards.alignment = BoxContainer.ALIGNMENT_CENTER
		contents.add_child(cards)
		var index: int = 0
		for card_id: String in Data.equipment_cards(id, work.state):
			var embedded: Dictionary = _object_job(cards, index, "card", card_id, GEAR_CARD_SCALE)
			embedded["embedded"] = true
			work.jobs.append(embedded)
			index += 1
	return plate

static func _definition(kind: String, id: String) -> Dictionary:
	match kind:
		"equipment": return Data.equipment_def(id)
		"omen": return Data.omen_def(id)
		"defiance": return {"name": Icons.label("defiance")}
	return Data.relic_def(id)

static func _accent(kind: String, id: String, definition: Dictionary) -> Color:
	match kind:
		"equipment": return Color(Data.equipment_accent(id))
		"omen": return Palette.EVENT_BLESSING if definition.get("kind") == "blessing" else Palette.EVENT_BANE
		"defiance": return Palette.GOLD
	return Color(Data.relic_accent(id))

static func _icon_path(kind: String, id: String, definition: Dictionary) -> String:
	if kind == "omen": return Omens.icon_path(id)
	if kind == "defiance": return Icons.icon_path("defiance")
	return str(definition.get("icon_path", ""))

static func _bare_object(kind: String, id: String, state: Dictionary, scale_hint: float, beat_only: bool = false) -> Control:
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
	var definition: Dictionary = _definition(kind, id)
	var column := VBoxContainer.new()
	column.add_child(icon_control(_icon_path(kind, id, definition)))
	# Result beats retain their original rarity tint and icon/name layout.
	var accent: Color = _accent(kind, id, definition) if kind in ["omen", "defiance"] else Color(Data.relic_rarity_accent(str(definition.get("rarity", ""))))
	column.add_child(_label(str(definition.get("name", id)).to_upper(), Typography.SIZE_BODY_LARGE, accent))
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
