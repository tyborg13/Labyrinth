extends RefCounted

const View = preload("res://scripts/pre_battle_view.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Controls = preload("res://scripts/pre_battle_controls.gd")
const Socket = preload("res://scripts/ui_socket.gd")
const CloseSocket = preload("res://scripts/ui_close_socket.gd")
const InkPool = preload("res://scripts/ui_ink_pool_stage.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const GameData = preload("res://scripts/game_data.gd")
const GuardianLibrary = preload("res://scripts/guardian_library.gd")
const CapacitorView = preload("res://scripts/enemy_mechanics/capacitor_view.gd")
const BurstTraitText = preload("res://scripts/enemy_mechanics/burst_trait_text.gd")
const KnownMoveText = preload("res://scripts/known_move_text.gd")
const Lob = preload("res://scripts/enemy_mechanics/marked_strike.gd")
const RuleRows = preload("res://scripts/battlefield_rules/intent_rows.gd")

const PatternText = preload("res://scripts/pattern_text.gd")
const LoopContext = preload("res://scripts/tooltip_loop_context.gd")

class LoopMovePlate extends Controls.Plate:
	var loop_source: Dictionary = {}
	var loop_term: String = ""
	func _make_custom_tooltip(text: String) -> Object:
		if text.strip_edges().is_empty(): return null
		var panels = load("res://scripts/ui_tooltip_panel.gd")
		return panels.make_plain_text(text) if loop_term.is_empty() else panels.make_text(text, loop_source, loop_term)

class LoopTraitRow extends HBoxContainer:
	var loop_source: Dictionary = {}
	var loop_term: String = ""
	func _make_custom_tooltip(text: String) -> Object:
		if text.strip_edges().is_empty(): return null
		return load("res://scripts/ui_tooltip_panel.gd").make_text(text, loop_source, loop_term)

static func build(host: Node, enemy: Dictionary, interactive: bool = false) -> Control:
	var definition: Dictionary = GameData.enemy_def(str(enemy.get("type", "")))
	var panel := PanelContainer.new()
	panel.name = "PreBattleEnemyInspection"
	panel.custom_minimum_size.x = Typography.scaled_value(host, 680.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.INK_1, 0.98)
	style.border_color = Color(Palette.GOLD, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(24.0)
	panel.add_theme_stylebox_override("panel", style)
	host.get("_ui_skin").apply_menu_finish(panel, "section", Palette.GOLD)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	var header_host: VBoxContainer = content
	if not interactive:
		var window: Control = LoopContext.outer_popup_window(LoopContext.enemy_unit(enemy))
		if window != null:
			header_host = VBoxContainer.new()
			header_host.name = "PreBattleTooltipLoopHeader"
			header_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
			header_host.add_theme_constant_override("separation", 10)
			content.add_child(header_host)
			header_host.add_child(window)
	header_host.add_child(header)
	var stage := InkPool.new()
	stage.name = "PreBattleEnemyPortraitInset"
	stage.custom_minimum_size = Vector2(138.0, 154.0)
	stage.figure_width = 138.0
	header.add_child(stage)
	var portrait := View.icon(str(definition.get("art_path", "")), 0.0, "PreBattleEnemyPortrait")
	portrait.texture = Socket._cropped_icon(portrait.texture)
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.offset_bottom = -12.0
	stage.add_child(portrait)
	preload("res://scripts/maquette_cutout_runtime/portrait.gd").bind(portrait, str(enemy.get("type", "")), bool(host.call("_reduced_motion_enabled")), true)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", 6)
	header.add_child(identity)
	var name_label := View.label(preload("res://scripts/enemy_identity.gd").display_name(enemy, definition), 30)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size.x = Typography.scaled_value(host, 300.0)
	name_label.size.x = name_label.custom_minimum_size.x
	identity.add_child(name_label)
	var hp: int = int(enemy.get("hp", definition.get("max_hp", 0)))
	var hp_label := View.label("Health %d/%d" % [hp, int(enemy.get("max_hp", hp))], 17, Palette.DANGER_BRIGHT)
	hp_label.name = "PreBattleEnemyHpLine"
	identity.add_child(hp_label)
	var initiative := View.label("Base initiative %d" % int(definition.get("base_initiative", 0)), 17, Palette.STEEL)
	initiative.name = "PreBattleEnemyInitiativeLine"
	identity.add_child(initiative)
	# The Burst trait row below already states a Tick's headline threat.
	if not definition.has("death_burst"):
		identity.add_child(View.label(str(host.call("_pre_battle_enemy_threat_summary", str(enemy.get("type", "")))), 14, Palette.TEXT_2))
	if interactive:
		var close_button := CloseSocket.new()
		close_button.name = "PreBattleInspectionCloseButton"
		close_button.socket_size = 40.0
		close_button.setup(null, "Close")
		close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		close_button.set_glyph_name("PreBattleCloseGlyph")
		close_button.pressed.connect(Callable(host, "_close_pinned_tooltip"))
		header.add_child(close_button)
	var guardian_summary: String = GuardianLibrary.inspection_summary(enemy)
	if not guardian_summary.is_empty():
		content.add_child(rules_label(guardian_summary, "GuardianEncounterRules", 600.0))
	if bool(enemy.get("is_leader", false)):
		var battle: Dictionary = host.get("_pre_battle_preview_run_state").get("combat_state", {})
		var order: String = preload("res://scripts/warband_combat_rules.gd").order_line(battle.get("objective", {}))
		if not order.is_empty(): content.add_child(rules_label(order, "WarbandCaptainOrder", 600.0))
	var burst_trait: Dictionary = preload("res://scripts/enemy_mechanics/death_burst_view.gd").trait_token(enemy)
	if not burst_trait.is_empty(): content.add_child(build_trait(burst_trait, LoopContext.enemy_unit(enemy)))
	preload("res://scripts/enemy_mechanics/split_trait_text.gd").append_inspection(content, enemy, func(token: Dictionary) -> Control: return build_trait(token, LoopContext.enemy_unit(enemy)))
	# pla-01: unit traits (Steadfast, Immune, Anchored, Command) in the same row style.
	for unit_trait: Dictionary in preload("res://scripts/enemy_mechanics/unit_traits.gd").tokens(enemy, host.get("_pre_battle_preview_run_state").get("combat_state", {})):
		var trait_row: Control = build_trait(unit_trait, LoopContext.enemy_unit(enemy))
		for node: Node in trait_row.find_children("EnemyBurstTrait*", "", true, false):
			node.name = str(node.name).replace("Burst", "Unit")
		trait_row.name = "EnemyUnitTrait"
		trait_row.set_meta("unit_trait", str(unit_trait["unit_trait"]))
		content.add_child(trait_row)
	content.add_child(View.section("KNOWN MOVES"))
	var moves := VBoxContainer.new()
	moves.name = "PreBattleKnownMoves"
	moves.add_theme_constant_override("separation", 7)
	content.add_child(moves)
	var battle: Dictionary = host.get("_pre_battle_preview_run_state").get("combat_state", {})
	var engine: RefCounted = host.get("_combat_engine")
	for intent: Dictionary in host.call("_pre_battle_known_enemy_intents", str(enemy.get("type", ""))):
		var shown: Dictionary = preload("res://scripts/warband_combat_rules.gd").intent(battle, enemy, intent)
		shown = preload("res://scripts/warband_intent_presentation.gd").intent(engine, battle, enemy, shown)
		moves.add_child(build_move(host, Lob.presentation_intent(engine, battle, enemy, shown), LoopContext.enemy_unit(enemy), enemy, battle))
	if moves.get_child_count() == 0:
		moves.add_child(View.label("No recorded moves.", 14, Palette.TEXT_2))
	return panel

static func rules_label(text: String, node_name: String, width: float) -> Label:
	var result := View.label(text, 14, Palette.TEXT_2)
	result.name = node_name
	result.custom_minimum_size.x = width
	result.size.x = width
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return result

static func build_move(host: Node, intent: Dictionary, source: Dictionary = {}, unit: Dictionary = {}, state: Dictionary = {}) -> Control:
	var actor: Dictionary = unit if not unit.is_empty() else source
	var own_rows: Array = KnownMoveText.rows(intent, actor, state)
	var beat_row: Array = RuleRows.tokens(state, actor, intent)
	var rows: Array = own_rows if beat_row.is_empty() else own_rows + [beat_row]
	var capacitor: bool = CapacitorView.Rules.handles_intent(intent)
	var plate := LoopMovePlate.new()
	plate.loop_source = source
	plate.loop_term = LoopContext.intent_term(str(intent.get("name", "")), source, own_rows)
	plate.name = "PreBattleKnownMoveRow"
	plate.top = Palette.INK_2
	plate.bottom = Palette.INK_1
	plate.border = Color(Palette.GOLD, 0.25)
	plate.custom_minimum_size.y = 58.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	plate.add_child(row)
	var socket := Socket.new()
	socket.socket_size = 40.0
	socket.interactive = false
	var key: String = KnownMoveText.display_icon(intent, rows, Callable(host, "_pre_battle_known_move_icon_key"))
	socket.setup(ActionIcons.icon_texture(key))
	socket.get_node("Icon").name = "PreBattleKnownMoveIcon"
	socket.get_node("PreBattleKnownMoveIcon").set_meta("icon_key", key)
	row.add_child(socket)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 2)
	row.add_child(text_box)
	text_box.add_child(View.label(str(intent.get("name", "Move")), 18))
	var actions: Array = intent.get("actions", []) as Array
	var summary: String = KnownMoveText.summary(intent, own_rows)
	if capacitor or actions.any(func(action: Dictionary) -> bool: return str(action.get("type", "")) == "kindle"):
		plate.tooltip_text = move_tooltip(rows)
	text_box.add_child(_pattern_label(summary, "PreBattleMoveEffect", 410.0))

	if not beat_row.is_empty():
		var markup := PackedStringArray()
		for token: Dictionary in beat_row:
			if not str(token.get("icon", "")).is_empty(): markup.append("@" + "icon(" + str(token["icon"]) + ")")
			var value: String = ActionIcons.token_value_text(token)
			if not value.is_empty(): markup.append(value)
		var beat_label: RichTextLabel = preload("res://scripts/ui_tooltip_panel.gd")._make_rich_label(" ".join(markup), 410.0, Typography.ROLE_CAPTION, Palette.TEXT_2, 0)
		beat_label.name = "PreBattleRuleBeat"
		beat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		beat_label.set_meta("rule_tokens", beat_row)
		text_box.add_child(beat_label)
	if source.get("id") in ["burrow_grub", "hoarfrost_seer", "slag_mortar"]:
		for action: Dictionary in actions:
			if str(action.get("type", "")) in ["burrow", "erupt", "icefall_mark", "icefall_land", "lob_mark", "lob_land"]: plate.tooltip_text = ActionIcons.marked_move_text(action)
	var details: String = move_tooltip(rows)
	if plate.tooltip_text.is_empty() and not plate.loop_term.is_empty(): plate.tooltip_text = details
	var notes: String = GuardianLibrary.intent_notes(intent)
	if not notes.is_empty():
		text_box.add_child(rules_label(notes, "GuardianMoveRules", 410.0))
	# Keep the readable TIME chip until the 34px watch can be judged in a live render.
	var time_chip := Controls.Plate.new()
	time_chip.top = Palette.INK_3
	time_chip.bottom = Palette.INK_1
	time_chip.border = Color(Palette.GOLD, 0.6)
	time_chip.custom_minimum_size = Vector2(76.0, 34.0)
	time_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(time_chip)
	var time_label := View.label("TIME %d" % int(intent.get("time", 0)), 14, Palette.GOLD_BRIGHT)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_chip.add_child(time_label)
	return plate

static func _pattern_label(summary: String, label_name: String, width: float) -> Control:
	var patterns: Array[RegExMatch] = PatternText.matches(summary)
	var label: Label = rules_label(PatternText.strip(summary).strip_edges(), label_name, width)
	if patterns.is_empty(): return label
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size.x = width
	for token: RegExMatch in patterns:
		var diagram: Control = PatternText.make_view(token, Typography.SIZE_CAPTION)
		row.add_child(diagram)
		label.custom_minimum_size.x -= diagram.custom_minimum_size.x + row.get_theme_constant("separation")
	row.add_child(label)
	return row

static func move_rows(intent: Dictionary, source: Dictionary = {}, state: Dictionary = {}) -> Array:
	var rows: Array = KnownMoveText.rows(intent, source, state)
	var beat_row: Array = RuleRows.tokens(state, source, intent)
	if not beat_row.is_empty(): rows.append(beat_row)
	return rows

static func move_tooltip(rows: Array) -> String:
	var details := PackedStringArray()
	for row: Array in rows:
		for token: Dictionary in row:
			var detail: String = ActionIcons.token_tooltip(token)
			if not detail.is_empty() and not details.has(detail): details.append(detail)
	return "\n".join(details)

static func build_trait(burst_trait: Dictionary, source: Dictionary = {}) -> Control:
	var row := LoopTraitRow.new()
	row.loop_source = source
	row.loop_term = str(burst_trait.get("glossary_key", burst_trait.get("icon", "")))
	row.name = "EnemyBurstTrait"
	row.add_theme_constant_override("separation", 10)
	var socket := Socket.new()
	socket.socket_size = 40.0
	socket.interactive = false
	socket.setup(ActionIcons.icon_texture(str(burst_trait.get("icon", "burst"))))
	row.add_child(socket)
	var text := VBoxContainer.new()
	text.custom_minimum_size.x = BurstTraitText.WIDTH
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	var title := View.label(str(burst_trait["value"]), 18)
	title.name = "EnemyBurstTraitTitle"
	text.add_child(title)
	var details: String = trait_details(burst_trait)
	text.add_child(_pattern_label(details, "EnemyBurstTraitRules", BurstTraitText.WIDTH))
	row.tooltip_text = details
	return row

static func trait_details(token: Dictionary) -> String:
	return str(token.get("display_tooltip", token["tooltip"]))
