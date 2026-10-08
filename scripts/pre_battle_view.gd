extends RefCounted

const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Surface = preload("res://scripts/ui_component_surface.gd")
const Controls = preload("res://scripts/pre_battle_controls.gd")
const SectionHeader = preload("res://scripts/ui_section_header.gd")
const InkPool = preload("res://scripts/ui_ink_pool_stage.gd")
const Socket = preload("res://scripts/ui_socket.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const GameData = preload("res://scripts/game_data.gd")
const ObjectiveRules = preload("res://scripts/combat_objective_rules.gd")
const ElementData = preload("res://scripts/element_data.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const TooltipButton = preload("res://scripts/ui_tooltip_button.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const TurnOrderInk = preload("res://scripts/turn_order_ink.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const ThreatTags = preload("res://scripts/pre_battle_threat_tags.gd")
const FoeCaption = preload("res://scripts/pre_battle_foe_caption.gd")
const FoeLayout = preload("res://scripts/pre_battle_foe_layout.gd")
const Lineup = preload("res://scripts/pre_battle_lineup.gd")

static func build(host: Node, panel: PanelContainer, room: Dictionary, combat: Dictionary, accent: Color, state: Dictionary = {}) -> void:
	for job: Callable in build_jobs(host, panel, room, combat, accent, state): job.call()

# The synchronous path and hidden travel preparation execute the same ordered
# constructors. Nodes, fonts, and host callbacks remain main-thread-owned.
static func build_jobs(host: Node, panel: PanelContainer, room: Dictionary, combat: Dictionary, accent: Color, state: Dictionary = {}) -> Array[Callable]:
	var jobs: Array[Callable]
	var margin := MarginContainer.new()
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, roundi(Typography.scaled_value(panel, 52.0)))
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, roundi(Typography.scaled_value(panel, 8.0)))
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.name = "PreBattleContent"
	content.add_theme_constant_override("separation", roundi(Typography.scaled_value(panel, 16.0)))
	margin.add_child(content)
	jobs.append(func() -> void:
		var started: int = Time.get_ticks_usec()
		content.add_child(build_header(host, room, combat, accent))
		host.call("_record_runtime_performance_phase", "pre_battle_header", started)
	)
	var body := HBoxContainer.new()
	body.name = "PreBattleBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", roundi(Typography.scaled_value(panel, 16.0)))
	content.add_child(body)
	jobs.append(func() -> void:
		var started: int = Time.get_ticks_usec()
		body.add_child(build_foes(host, combat, state))
		host.call("_record_runtime_performance_phase", "pre_battle_enemy_section", started)
	)
	jobs.append(func() -> void:
		var started: int = Time.get_ticks_usec()
		var divider := Controls.Rule.new()
		divider.name = "PreBattleColumnDivider"
		divider.vertical = true
		divider.custom_minimum_size.x = Typography.scaled_value(panel, 1.0)
		body.add_child(divider)
		body.add_child(build_kit(host, state))
		host.call("_record_runtime_performance_phase", "pre_battle_deck_section", started)
	)
	# Keep the authored header before the body even though the body shell is
	# present while a staged build is waiting between its component jobs.
	jobs.append(func() -> void: content.move_child(body, content.get_child_count() - 1))
	return jobs

# Retain only the currently displayed components. These keys name every input
# read by their constructors; the scene owns an exact snapshot, never a hash.
# Rebuilding a kit must not destroy an unchanged foe's native controls/layout.
static func refresh_sections(host: Node, panel: PanelContainer, room: Dictionary, combat: Dictionary, accent: Color, state: Dictionary, previous: Dictionary, current: Dictionary) -> bool:
	if previous.is_empty() or _common_key(previous) != _common_key(current): return false
	var content: VBoxContainer = panel.find_child("PreBattleContent", true, false) as VBoxContainer
	if content == null or content.get_child_count() != 2: return false
	var body: HBoxContainer = content.get_child(1) as HBoxContainer
	if body == null or body.name != "PreBattleBody" or body.get_child_count() != 3: return false
	if content.get_child(0).name != "PreBattleHeader" or body.get_child(0).name != "PreBattleEnemySection" or body.get_child(2).name != "PreBattleDeckSection": return false
	if _header_key(previous) != _header_key(current):
		_replace_component(host, content, 0, build_header(host, room, combat, accent))
	if _foes_key(previous) != _foes_key(current):
		_replace_component(host, body, 0, build_foes(host, combat, state))
	if _kit_key(previous) != _kit_key(current):
		if not _refresh_kit(host, body.get_child(2) as Control, state, previous, current):
			_replace_component(host, body, 2, build_kit(host, state))
	return true

static func _replace_component(host: Node, parent: Node, index: int, replacement: Control) -> void:
	var old: Node = parent.get_child(index)
	host.call("_prepare_node_for_immediate_free", old)
	parent.remove_child(old)
	old.queue_free()
	parent.add_child(replacement)
	parent.move_child(replacement, index)

static func _common_key(key: Dictionary) -> Array:
	return [key.get("viewport"), key.get("scale"), key.get("skin")]

static func _header_key(key: Dictionary) -> Array:
	var combat: Dictionary = key.get("combat", {})
	return [key.get("room"), combat.get("room_name"), combat.get("room_type"), combat.get("room_element"), combat.get("room_depth"), key.get("umbra_stage"), combat.has("umbra"), combat.get("objective", {})]

static func _foes_key(key: Dictionary) -> Array:
	var combat: Dictionary = key.get("combat", {})
	# Actions live beneath the foe lineup, including True Bearing's selected tile.
	return [combat.get("enemies", []), combat.get("objective", {}), key.get("enemies"), key.get("start_tiles"), key.get("pre_battle_start"), key.get("true_bearing_description")]

static func _kit_key(key: Dictionary) -> Array:
	return [key.get("player_hp"), key.get("player_max_hp"), key.get("defiance_capacity"), key.get("defiance_remaining"), key.get("equipped_equipment"), key.get("attuned_magic_cards"), key.get("deck_cards"), key.get("cards"), key.get("equipment")]

static func label(text: String, font_size: int, color: Color = Palette.TEXT, eyebrow: bool = false) -> Label:
	var result := Label.new()
	result.text = text
	Surface.label_style(result, font_size, color)
	if eyebrow:
		Typography.apply_eyebrow(result, font_size, color)
	return result

static func section(title: String, count_text: String = "", node_name: String = "") -> Control:
	var header := SectionHeader.new()
	header.name = node_name if not node_name.is_empty() else "PreBattle%sLabel" % title.replace(" ", "")
	header.setup(title, count_text)
	return header

static func build_header(host: Node, room: Dictionary, combat: Dictionary, accent: Color) -> Control:
	var header := VBoxContainer.new()
	header.name = "PreBattleHeader"
	header.add_theme_constant_override("separation", 4)
	header.add_child(build_room_chip(host, room, combat, accent))
	return header

static func build_room_chip(host: Node, room: Dictionary, combat: Dictionary, accent: Color) -> Control:
	var chip := VBoxContainer.new()
	chip.name = "PreBattleRoomChip"
	chip.add_theme_constant_override("separation", 4)
	var center := CenterContainer.new()
	center.name = "PreBattleRoomMeta"
	chip.add_child(center)
	var meta := HBoxContainer.new()
	meta.name = "PreBattleDepthOrnamentRow"
	meta.add_theme_constant_override("separation", 10)
	center.add_child(meta)
	var depth := label("DEPTH %d" % int(combat.get("room_depth", room.get("depth", 0))), 15, Palette.TEXT_2, true)
	depth.name = "PreBattleDepthLabel"
	meta.add_child(depth)
	var elemental: bool = ElementData.is_elemental(str(combat.get("room_element", room.get("element", ElementData.NONE))))
	if bool(host.call("_pre_battle_has_active_umbra", combat)):
		var diamond := label("◆", 14, accent if elemental else Palette.GOLD_DIM)
		diamond.name = "PreBattleDepthOrnament"
		meta.add_child(diamond)
	if bool(host.call("_pre_battle_has_active_umbra", combat)):
		var stage: String = str(host.get("_combat_engine").effective_umbra_stage(combat))
		var umbra := label("%s Umbra" % CombatEngine.umbra_stage_display_name(stage), 15, Palette.UMBRA, true)
		umbra.name = "PreBattleUmbraLabel"
		meta.add_child(umbra)
	var header_room: Dictionary = room.duplicate(true)
	for key: String in ["name", "type", "element"]:
		header_room[key] = combat.get("room_" + key, room.get(key, ""))
	var title := label(str(host.call("_room_title_text", header_room)), 58, Palette.GOLD_BRIGHT)
	title.name = "PreBattleRoomTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", Typography.display_font())
	title.add_theme_color_override("font_shadow_color", Color.BLACK)
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.add_theme_color_override("font_outline_color", Color(Palette.EMBER, 0.12))
	title.add_theme_constant_override("outline_size", 3)
	chip.add_child(title)
	chip.add_child(build_objective(combat))
	return chip

static func build_objective(combat: Dictionary) -> Control:
	var objective: Dictionary = combat.get("objective", {}) as Dictionary
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	for side: int in range(2):
		var rule := Controls.Rule.new()
		rule.reverse = side == 0
		rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rule.custom_minimum_size.x = 24.0
		row.add_child(rule)
		if side != 0:
			continue
		var plate := Controls.Plate.new()
		plate.name = "PreBattleObjectiveChip"
		plate.set_meta("objective_title", ObjectiveRules.title_for_objective(objective))
		plate.set_meta("objective_description", ObjectiveRules.description_for_objective(objective))
		plate.tooltip_text = "%s\n%s" % [ObjectiveRules.title_for_objective(objective), ObjectiveRules.description_for_objective(objective)]
		row.add_child(plate)
		var contents := HBoxContainer.new()
		contents.add_theme_constant_override("separation", 8)
		plate.add_child(contents)
		contents.add_child(icon(ObjectiveRules.icon_path(str(objective.get("type", ObjectiveRules.KILL_ALL))), 22.0, "PreBattleObjectiveIcon"))
		var eyebrow := label("OBJECTIVE", 14, Palette.DANGER_BRIGHT.lerp(Palette.TEXT_2, 0.6), true)
		eyebrow.name = "PreBattleObjectiveTitle"
		eyebrow.tooltip_text = ObjectiveRules.title_for_objective(objective)
		contents.add_child(eyebrow)
		var description: String = ObjectiveRules.description_for_objective(objective)
		if description.is_empty():
			description = ObjectiveRules.title_for_objective(objective)
		var detail := label(description, 19)
		detail.name = "PreBattleObjectiveDescription"
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Long exit/survival rules wrap without widening the fixed outer frame.
		detail.custom_minimum_size.x = minf(760.0, detail.get_theme_font("font").get_string_size(description, HORIZONTAL_ALIGNMENT_LEFT, -1.0, detail.get_theme_font_size("font_size")).x)
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		contents.add_child(detail)
	return row

static func icon(path: String, diameter: float, node_name: String = "") -> TextureRect:
	var result := TextureRect.new()
	if not node_name.is_empty():
		result.name = node_name
	result.texture = AssetLoader.load_texture(path)
	result.custom_minimum_size = Vector2.ONE * diameter
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func build_foes(host: Node, combat: Dictionary, state: Dictionary = {}) -> Control:
	var foes := VBoxContainer.new()
	foes.name = "PreBattleEnemySection"
	foes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var separation: int = roundi(Typography.scaled_value(host, 4.0))
	foes.add_theme_constant_override("separation", separation)
	var enemies: Array = []
	for entry: Variant in combat.get("enemies", []):
		if entry is Dictionary and int(entry.get("hp", 0)) > 0:
			enemies.append(entry)
	var objective: Dictionary = combat.get("objective", {}) as Dictionary
	if enemies.size() == 3:
		var center_index: int = -1
		for index: int in range(enemies.size()):
			var enemy: Dictionary = enemies[index]
			if bool(enemy.get("is_leader", false)) or (objective.has("leader_id") and enemy.get("id", -1) == objective["leader_id"]):
				center_index = index
				break
			if center_index < 0 and bool(FoeLayout.metrics(str(enemy.get("type", "")))["large"]):
				center_index = index
		if center_index >= 0:
			var center_enemy: Dictionary = enemies.pop_at(center_index)
			enemies.insert(1, center_enemy)
	var header := section("FOES", str(enemies.size()), "PreBattleFoesDivider")
	foes.add_child(header)
	var scroll := ScrollContainer.new()
	scroll.name = "PreBattleEnemyScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	foes.add_child(scroll)
	var flow := Lineup.new()
	flow.name = "PreBattleEnemyFlow"
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(flow)
	for enemy: Dictionary in enemies:
		var leader: bool = bool(enemy.get("is_leader", false)) or (objective.has("leader_id") and enemy.get("id", -1) == objective["leader_id"])
		var card := build_foe(host, enemy, Vector2.ZERO, leader)
		flow.add_child(card)
		var caption := card.get_node("PreBattleFoeCaption") as Control
		caption.minimum_size_changed.connect(flow.queue_sort)
	var hint := Controls.PointerHint.new()
	hint.text = "Hover or select a foe to read its moves"
	Typography.apply_eyebrow(hint, 13, Palette.TEXT_3)
	hint.name = "PreBattleFoeHint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint_slot := Control.new()
	hint_slot.name = "PreBattleFoeHintSlot"
	var hint_height: float = hint.get_combined_minimum_size().y
	# Keep the same reserve when controller input hides the pointer hint.
	hint_slot.custom_minimum_size.y = hint_height + Typography.scaled_value(host, 14.0) - separation
	hint_slot.add_child(hint)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -hint_height
	foes.add_child(hint_slot)
	var actions := build_actions(host, state)
	foes.add_child(actions)
	if flow.get_child_count() > 0:
		var focus_foe := flow.get_child(mini(1, flow.get_child_count() - 1)) as Control
		for action_button: Control in actions.get_children():
			action_button.focus_neighbor_top = action_button.get_path_to(focus_foe)
	for index: int in range(actions.get_child_count()):
		var action_button := actions.get_child(index) as Control
		if index > 0:
			action_button.focus_neighbor_left = action_button.get_path_to(actions.get_child(index - 1))
		if index + 1 < actions.get_child_count():
			action_button.focus_neighbor_right = action_button.get_path_to(actions.get_child(index + 1))
	header.item_rect_changed.connect(flow.queue_sort)
	actions.item_rect_changed.connect(flow.queue_sort)
	return foes

static func build_foe(host: Node, enemy: Dictionary, card_size: Vector2, leader: bool = false) -> Control:
	var card := Controls.Foe.new()
	card.name = "PreBattleEnemyCard"
	card.host = host
	card.enemy = enemy.duplicate(true)
	card.set_meta("is_leader", leader)
	card.custom_minimum_size = card_size
	card.tooltip_text = "enemy:%s" % str(enemy.get("type", ""))
	var definition: Dictionary = GameData.enemy_def(str(enemy.get("type", "")))
	var stage := InkPool.new()
	stage.name = "PreBattleEnemyBrush"
	stage.variant = "b" if posmod(int(enemy.get("id", 0)), 2) else "a"
	card.add_child(stage)
	var art := icon(str(definition.get("art_path", "")), 0.0, "PreBattleEnemyArt")
	# The combat board inherits linear filtering and uses the original full canvas.
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.stretch_mode = TextureRect.STRETCH_SCALE
	card.add_child(art)
	var health := Controls.Plate.new()
	health.name = "PreBattleEnemyHealth"
	health.radius = 12.0
	health.border = Palette.DANGER
	var health_style := StyleBoxEmpty.new()
	health_style.content_margin_left = 6.0
	health_style.content_margin_right = 6.0
	health.add_theme_stylebox_override("panel", health_style)
	card.add_child(health)
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 3)
	health.add_child(hp_row)
	hp_row.add_child(label("♥", 17, Palette.DANGER_BRIGHT))
	var hp: int = int(enemy.get("hp", 0))
	var max_hp: int = int(enemy.get("max_hp", hp))
	hp_row.add_child(label(str(hp) if hp == max_hp else "%d/%d" % [hp, max_hp], 17))
	if leader:
		var badge := label("LEADER", 14, Palette.GOLD, true)
		badge.name = "PreBattleLeaderLabel"
		card.add_child(badge)
	var caption := FoeCaption.new()
	caption.name = "PreBattleFoeCaption"
	caption.name_font_size = Typography.scaled_size(host, 19)
	caption.compact_font_size = Typography.scaled_size(host, 17)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_constant_override("separation", roundi(Typography.scaled_value(host, 8.0)))
	card.add_child(caption)
	var name_label := label(str(definition.get("name", enemy.get("type", ""))), 19)
	name_label.name = "PreBattleEnemyName"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.max_lines_visible = 2
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_WORD_ELLIPSIS
	caption.enemy_name = name_label
	caption.add_child(name_label)
	var threat_tags: Array = ThreatTags.build(str(enemy.get("type", "")))
	var summary: String = ThreatTags.summary(threat_tags)
	var tags: Control = build_move_tags(host, threat_tags)
	caption.add_child(tags)
	# Keep the exact established summary queryable without duplicating visible copy.
	var threat := label(summary, 14, Palette.TEXT_2)
	threat.name = "PreBattleThreatSummary"
	threat.hide()
	card.add_child(threat)
	card.resized.connect(FoeLayout.fit_single.bind(card))
	caption.minimum_size_changed.connect(FoeLayout.fit_single.bind(card))
	return card

static func build_move_tags(host: Node, threat_tags: Array) -> Control:
	var tags := Controls.MoveTags.new()
	tags.name = "PreBattleMoveTags"
	tags.gap = Typography.scaled_value(host, 6.0)
	tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tags.base_overflow = maxi(0, threat_tags.size() - 3)
	for index: int in range(mini(3, threat_tags.size())):
		var definition: Dictionary = threat_tags[index] as Dictionary
		var word: String = str(definition.get("text", ""))
		var icon_key: String = str(definition.get("icon_key", ""))
		var tag := HBoxContainer.new()
		tag.set_meta("tag_word", word)
		tag.set_meta("icon_key", icon_key)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_theme_constant_override("separation", 2)
		tags.add_child(tag)
		if not icon_key.is_empty():
			var intent_icon := icon("", 18.0)
			intent_icon.texture = ActionIcons.icon_texture(icon_key)
			intent_icon.set_meta("icon_key", icon_key)
			tag.add_child(intent_icon)
		tag.add_child(label(word, 14, Palette.TEXT_2))
	return tags

static func build_actions(host: Node, future_state: Dictionary = {}) -> Control:
	var row := HBoxContainer.new()
	row.name = "PreBattleActions"
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	var state: Dictionary = host.get("_run_state") if future_state.is_empty() else future_state
	var tiles: Array[Vector2i] = host.get("_run_engine").pre_battle_start_tiles(state)
	if not tiles.is_empty():
		var selected: Vector2i = state.get("pre_battle_start", tiles[0])
		var position_button := action(host, "TrueBearingButton", "Position %d/%d" % [maxi(0, tiles.find(selected)) + 1, tiles.size()], "_on_true_bearing_pressed", 148.0)
		position_button.tooltip_text = "%s\nSelected tile: %d, %d" % [preload("res://scripts/skill_tree_library.gd").description("true_bearing"), selected.x, selected.y]
		row.add_child(position_button)
	var equip := action(host, "PreBattleEquipButton", "Equip", "_on_pre_battle_equip_pressed", 132.0)
	equip.tooltip_text = "Character"
	equip.icon = AssetLoader.load_texture("res://assets/art/equipment/training_sword.png")
	equip.expand_icon = true
	row.add_child(equip)
	var start := action(host, "PreBattleStartButton", "Start", "_on_pre_battle_start_pressed", 170.0, true)
	start.tooltip_text = "Start combat"
	row.add_child(start)
	return row

static func action(host: Node, node_name: String, text: String, callback: String, width: float, primary: bool = false) -> Button:
	var button := TooltipButton.new()
	button.name = node_name
	button.text = text
	var skin: RefCounted = host.get("_ui_skin")
	skin.apply_button_stylebox_overrides(button, UiSkin.VARIANT_SELECTED if primary else UiSkin.VARIANT_STANDARD)
	skin.apply_button_text_overrides(button)
	Typography.apply_button_role(button, Typography.ROLE_SECTION if primary else Typography.ROLE_BODY)
	button.add_theme_font_size_override("font_size", Typography.scaled_size(button, 24 if primary else 19))
	button.custom_minimum_size = Vector2(width, 58.0 if primary else 46.0) * Typography.ui_scale(host)
	button.size_flags_vertical = Control.SIZE_SHRINK_END
	if primary:
		host.call("_apply_pre_battle_start_button_glow", button)
	button.pressed.connect(Callable(host, callback))
	return button

static func build_kit(host: Node, future_state: Dictionary = {}) -> Control:
	var kit := VBoxContainer.new()
	kit.name = "PreBattleDeckSection"
	kit.custom_minimum_size.x = Typography.scaled_value(host, 404.0)
	kit.add_theme_constant_override("separation", 6)
	kit.add_child(section("YOUR KIT"))
	kit.add_child(build_health(host, future_state))
	kit.add_child(_gear_row(host, future_state))
	var state: Dictionary = host.get("_run_state") if future_state.is_empty() else future_state
	var attuned: Array = state.get("attuned_magic_cards", []) as Array
	kit.add_child(loadout_header("ATTUNED MAGIC", "%d / %d" % [attuned.size(), GameData.magic_loadout_limit()]))
	kit.add_child(card_grid(host, attuned, "attuned", "PreBattleAttunedRow"))
	var deck: Array = state.get("deck_cards", []) as Array
	kit.add_child(loadout_header("ACTIVE DECK", "%d cards" % deck.size()))
	var scroll := ScrollContainer.new()
	scroll.name = "PreBattleDeckScroll"
	scroll.set_meta("deck_entry_count", deck.size())
	scroll.set_meta("deck_group_count", host.call("_pre_battle_card_groups", deck).size())
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	kit.add_child(scroll)
	scroll.add_child(card_grid(host, deck, "deck", "PreBattleDeckFlow"))
	return kit

static func _gear_row(host: Node, future_state: Dictionary = {}) -> Control:
	var gear_row := HBoxContainer.new()
	gear_row.add_theme_constant_override("separation", 8)
	var gear_label := label("GEAR", 14, Palette.TEXT_2, true)
	gear_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gear_row.add_child(gear_label)
	var sockets := HFlowContainer.new()
	sockets.name = "PreBattleEquipmentRow"
	sockets.add_theme_constant_override("h_separation", 8)
	sockets.custom_minimum_size.x = Typography.scaled_value(host, 282.0)
	gear_row.add_child(sockets)
	var state: Dictionary = host.get("_run_state") if future_state.is_empty() else future_state
	var equipped: Dictionary = state.get("equipped_equipment", {}) as Dictionary
	for slot: String in GameData.equipment_slots():
		var socket := Controls.Gear.new()
		socket.name = "PreBattleEquipmentChip"
		socket.host = host
		socket.equipment_id = str(equipped.get(slot, ""))
		socket.set_meta("equipment_id", socket.equipment_id)
		socket.set_meta("slot_id", slot)
		var definition: Dictionary = GameData.equipment_def(socket.equipment_id)
		socket.setup(AssetLoader.load_texture(str(definition.get("icon_path", ""))), "equipment:%s" % socket.equipment_id if not socket.equipment_id.is_empty() else "")
		socket.interactive = not socket.equipment_id.is_empty()
		sockets.add_child(socket)
	return gear_row

static func loadout_header(title: String, count_text: String) -> Control:
	var row := HBoxContainer.new()
	var title_label := label(title, 14, Palette.TEXT_2, true)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_label)
	row.add_child(label(count_text, 15, Palette.TEXT_2))
	return row

static func card_grid(host: Node, ids: Array, source_kind: String, node_name: String) -> Control:
	var grid := HFlowContainer.new()
	grid.name = node_name
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	for group: Dictionary in host.call("_pre_battle_card_groups", ids):
		grid.add_child(_card_strip(host, group, source_kind))
	return grid


# The current kit owns its controls in their final parents. Changed cards use
# the original constructor; unchanged idle cards avoid native theme/layout work.
# Keep no detached pool, and reset scroll only when the original kit rebuilt.
static func _refresh_kit(host: Node, kit: Control, state: Dictionary, previous: Dictionary, current: Dictionary) -> bool:
	if kit == null or kit.get_child_count() != 7 or not _kit_idle(kit): return false
	var gear: HBoxContainer = kit.get_child(2) as HBoxContainer
	var attuned: HFlowContainer = kit.get_child(4) as HFlowContainer
	var scroll: ScrollContainer = kit.get_child(6) as ScrollContainer
	if gear == null or attuned == null or scroll == null or gear.get_child_count() != 2 or scroll.get_child_count() != 1: return false
	var deck: HFlowContainer = scroll.get_child(0) as HFlowContainer
	if deck == null: return false
	var health_fields: Array[String]
	health_fields.assign(["player_hp", "player_max_hp", "defiance_capacity", "defiance_remaining"])
	var health_changed: bool = false
	for field: String in health_fields:
		health_changed = health_changed or previous.get(field) != current.get(field)
	if health_changed: _replace_component(host, kit, 1, build_health(host, state))
	if previous.get("equipped_equipment") != current.get("equipped_equipment") or previous.get("equipment") != current.get("equipment"):
		# This small socket row retains its original slot order and constructor.
		_replace_component(host, kit, 2, _gear_row(host, state))
	var attuned_ids: Array = state.get("attuned_magic_cards", []) as Array
	var deck_ids: Array = state.get("deck_cards", []) as Array
	if previous.get("attuned_magic_cards") != current.get("attuned_magic_cards"):
		_replace_component(host, kit, 3, loadout_header("ATTUNED MAGIC", "%d / %d" % [attuned_ids.size(), GameData.magic_loadout_limit()]))
	if previous.get("deck_cards") != current.get("deck_cards"):
		_replace_component(host, kit, 5, loadout_header("ACTIVE DECK", "%d cards" % deck_ids.size()))
	_refresh_card_grid(host, attuned, attuned_ids, "attuned")
	_refresh_card_grid(host, deck, deck_ids, "deck")
	scroll.set_meta("deck_entry_count", deck_ids.size())
	scroll.set_meta("deck_group_count", host.call("_pre_battle_card_groups", deck_ids).size())
	scroll.scroll_horizontal = 0
	scroll.scroll_vertical = 0
	return true

static func _kit_idle(node: Node) -> bool:
	if node is BaseButton:
		var button: BaseButton = node as BaseButton
		if button.has_focus() or button.is_hovered() or button.get_draw_mode() in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED]: return false
	if node is Controls.Strip and (bool(node.get("selected")) or bool(node.get("_inspection_active"))): return false
	if node is Controls.Gear and bool(node.get("selected")): return false
	for child: Node in node.get_children():
		if not _kit_idle(child): return false
	return true

static func _card_strip_input(host: Node, group: Dictionary, source_kind: String) -> Array:
	var id: String = str(group["card_id"])
	return [id, source_kind, int(group["count"]), GameData.card_def(id).duplicate(true), Typography.ui_scale(host)]

static func _refresh_card_grid(host: Node, grid: HFlowContainer, ids: Array, source_kind: String) -> void:
	var available: Dictionary = {}
	for child: Node in grid.get_children():
		available[str(child.get_meta("card_id", ""))] = child
	var retained: Array[Control]
	for group: Dictionary in host.call("_pre_battle_card_groups", ids):
		var id: String = str(group["card_id"])
		var strip: Control = available.get(id) as Control
		if strip == null or strip.get_meta("presentation_input", []) != _card_strip_input(host, group, source_kind):
			strip = _card_strip(host, group, source_kind)
			grid.add_child(strip)
		grid.move_child(strip, retained.size())
		retained.append(strip)
	for child: Node in grid.get_children():
		if not retained.has(child):
			host.call("_prepare_node_for_immediate_free", child)
			grid.remove_child(child)
			child.queue_free()
	# The original fresh grid gives only its first child the authored name;
	# later duplicates receive native automatic names. Preserve that observable
	# lookup when retained groups reorder. Only the displaced name owner needs
	# reinsertion; every other unchanged card keeps its final native parent.
	if not retained.is_empty():
		var authored_name: String = "PreBattleAttunedBadge" if source_kind == "attuned" else "PreBattleDeckBadge"
		var named: Node = grid.get_node_or_null(NodePath(authored_name))
		if named != retained[0]:
			var displaced_index: int = named.get_index() if named != null else -1
			if named != null: grid.remove_child(named)
			retained[0].name = authored_name
			if named != null:
				grid.add_child(named)
				grid.move_child(named, displaced_index)

static func _card_strip(host: Node, group: Dictionary, source_kind: String) -> Control:
	var strip := Controls.Strip.new()
	strip.host = host
	strip.name = "PreBattleAttunedBadge" if source_kind == "attuned" else "PreBattleDeckBadge"
	strip.source_kind = source_kind
	var id: String = str(group["card_id"])
	var definition: Dictionary = GameData.card_def(id)
	strip.setup(id, str(definition.get("name", id)), int(group["count"]))
	strip.set_meta("card_id", id)
	strip.set_meta("source_kind", source_kind)
	strip.set_meta("card_count", int(group["count"]))
	strip.set_meta("display_name", str(definition.get("name", id)))
	strip.tooltip_text = "card:%s" % id
	# Reserve scrollbar width so both columns remain stable when scrolling.
	strip.custom_minimum_size.x = Typography.scaled_value(host, 190.0)
	strip.set_meta("presentation_input", _card_strip_input(host, group, source_kind))
	return strip

static func build_health(host: Node, future_state: Dictionary = {}) -> Control:
	var row := HBoxContainer.new()
	row.name = "PreBattleHealthChip"
	row.add_theme_constant_override("separation", 12)
	var mask := TurnOrderInk.PortraitMask.new()
	mask.skew = 0.12
	mask.custom_minimum_size = Vector2(56.0, 56.0) * Typography.ui_scale(host)
	row.add_child(mask)
	var portrait := icon("res://assets/art/portraits/player_reaver.png", 0.0, "PreBattlePlayerPortrait")
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mask.add_child(portrait)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 6)
	row.add_child(stack)
	var values := HBoxContainer.new()
	stack.add_child(values)
	var health_label := label("Health", 17)
	health_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	values.add_child(health_label)
	var state: Dictionary = host.get("_run_state") if future_state.is_empty() else future_state
	values.add_child(label("%d / %d" % [int(state.get("player_hp", 0)), int(state.get("player_max_hp", 0))], 19, Palette.ALLY))
	var capacity: int = int(host.get("_run_engine").defiance_capacity(state))
	if capacity > 0:
		var defiance_icon := icon("", 18.0)
		defiance_icon.texture = ActionIcons.icon_texture("defiance")
		values.add_child(defiance_icon)
		var defiance := label("%d/%d" % [int(host.get("_run_engine").defiance_remaining(state)), capacity], 14, Palette.GOLD)
		defiance.name = "PreBattleDefianceCount"
		values.add_child(defiance)
	var bar := ProgressBar.new()
	bar.name = "PreBattleHealthBar"
	bar.custom_minimum_size.y = Typography.scaled_value(host, 12.0)
	bar.max_value = maxf(1.0, float(state.get("player_max_hp", 0)))
	bar.value = float(state.get("player_hp", 0))
	bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Palette.INK_3
	background.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", background)
	var fill := background.duplicate() as StyleBoxFlat
	fill.bg_color = Palette.ALLY
	bar.add_theme_stylebox_override("fill", fill)
	stack.add_child(bar)
	return row
