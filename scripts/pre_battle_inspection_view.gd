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
	content.add_child(header)
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
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", 6)
	header.add_child(identity)
	var name_label := View.label(str(definition.get("name", enemy.get("type", ""))), 30)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size.x = Typography.scaled_value(host, 300.0)
	name_label.size.x = name_label.custom_minimum_size.x
	identity.add_child(name_label)
	var hp: int = int(enemy.get("hp", definition.get("max_hp", 0)))
	var hp_label := View.label("HP %d/%d" % [hp, int(enemy.get("max_hp", hp))], 17, Palette.DANGER_BRIGHT)
	hp_label.name = "PreBattleEnemyHpLine"
	identity.add_child(hp_label)
	var initiative := View.label("Base initiative %d" % int(definition.get("base_initiative", 0)), 17, Palette.STEEL)
	initiative.name = "PreBattleEnemyInitiativeLine"
	identity.add_child(initiative)
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
	content.add_child(View.section("KNOWN MOVES"))
	var moves := VBoxContainer.new()
	moves.name = "PreBattleKnownMoves"
	moves.add_theme_constant_override("separation", 7)
	content.add_child(moves)
	for intent: Dictionary in host.call("_pre_battle_known_enemy_intents", str(enemy.get("type", ""))):
		moves.add_child(build_move(host, intent))
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

static func build_move(host: Node, intent: Dictionary) -> Control:
	var plate := Controls.Plate.new()
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
	var key: String = str(host.call("_pre_battle_known_move_icon_key", intent))
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
	var summary: String = ActionIcons.plain_text_for_rows(ActionIcons.rows_for_actions(actions)).replace("\n", "  /  ")
	text_box.add_child(rules_label(summary if not summary.is_empty() else "Recovers." if actions.is_empty() else "Special action", "PreBattleMoveEffect", 410.0))
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
