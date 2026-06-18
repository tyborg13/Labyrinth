extends Control

const AssetLoader = preload("res://scripts/asset_loader.gd")
const GameData = preload("res://scripts/game_data.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")

const CARD_PLAY_ICON_PATH: String = "res://assets/art/icons/card_play.png"
const EMBER_ICON_PATH: String = "res://assets/art/icons/ember.png"
const FOCUS_ICON_PATH: String = "res://assets/art/icons/stat_focus.png"

@onready var body_row: HBoxContainer = $Backdrop/Margin/Center/BodyRow
@onready var hero_panel: PanelContainer = $Backdrop/Margin/Center/BodyRow/HeroPanel
@onready var hero_vbox: VBoxContainer = $Backdrop/Margin/Center/BodyRow/HeroPanel/HeroMargin/HeroVBox
@onready var title_label: Label = $Backdrop/Margin/Center/BodyRow/HeroPanel/HeroMargin/HeroVBox/Title
@onready var subtitle_label: Label = $Backdrop/Margin/Center/BodyRow/HeroPanel/HeroMargin/HeroVBox/Subtitle
@onready var hero_art: TextureRect = $Backdrop/Margin/Center/BodyRow/HeroPanel/HeroMargin/HeroVBox/HeroArt
@onready var embers_label: Label = $Backdrop/Margin/Center/BodyRow/HeroPanel/HeroMargin/HeroVBox/Embers
@onready var footer_label: Label = $Backdrop/Margin/Center/BodyRow/HeroPanel/HeroMargin/HeroVBox/Footer
@onready var button_row: HBoxContainer = $Backdrop/Margin/Center/BodyRow/HeroPanel/HeroMargin/HeroVBox/ButtonRow
@onready var continue_button: Button = $Backdrop/Margin/Center/BodyRow/HeroPanel/HeroMargin/HeroVBox/ButtonRow/ContinueButton
@onready var start_button: Button = $Backdrop/Margin/Center/BodyRow/HeroPanel/HeroMargin/HeroVBox/ButtonRow/StartButton
@onready var boss_button: Button = $Backdrop/Margin/Center/BodyRow/HeroPanel/HeroMargin/HeroVBox/ButtonRow/BossButton
@onready var upgrade_panel: PanelContainer = $Backdrop/Margin/Center/BodyRow/UpgradePanel
@onready var upgrade_title_label: Label = $Backdrop/Margin/Center/BodyRow/UpgradePanel/UpgradeMargin/UpgradeVBox/UpgradeTitle
@onready var upgrade_subtitle_label: Label = $Backdrop/Margin/Center/BodyRow/UpgradePanel/UpgradeMargin/UpgradeVBox/UpgradeSubtitle
@onready var upgrade_list: VBoxContainer = $Backdrop/Margin/Center/BodyRow/UpgradePanel/UpgradeMargin/UpgradeVBox/UpgradeList

var _ui_skin: UiSkin = UiSkin.new()
var _progression: Dictionary = {}

func _ready() -> void:
	_apply_style()
	_reload_progression()

func _apply_style() -> void:
	$Backdrop.color = Color("100b09")
	body_row.custom_minimum_size = Vector2(1320.0, 0.0)
	body_row.add_theme_constant_override("separation", 28)
	hero_panel.custom_minimum_size = Vector2(800.0, 0.0)
	upgrade_panel.custom_minimum_size = Vector2(430.0, 0.0)
	hero_vbox.add_theme_constant_override("separation", 18)
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	upgrade_list.add_theme_constant_override("separation", 10)
	var hero_style := _ui_skin.make_plain_card_style(Color("1c1816"), Color("c99854"), 22.0)
	hero_style.shadow_size = 14
	hero_style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	hero_panel.add_theme_stylebox_override("panel", hero_style)
	var character_style := _ui_skin.make_plain_card_style(Color("211913"), Color("9d7a50"), 18.0)
	character_style.shadow_size = 12
	character_style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	upgrade_panel.add_theme_stylebox_override("panel", character_style)
	_ui_skin.apply_button_stylebox_overrides(continue_button)
	_ui_skin.apply_button_text_overrides(continue_button)
	_ui_skin.apply_button_stylebox_overrides(start_button)
	_ui_skin.apply_button_text_overrides(start_button)
	_ui_skin.apply_button_stylebox_overrides(boss_button)
	_ui_skin.apply_button_text_overrides(boss_button)
	UiTypography.set_button_size(continue_button, UiTypography.SIZE_SMALL)
	UiTypography.set_button_size(start_button, UiTypography.SIZE_SMALL)
	UiTypography.set_button_size(boss_button, UiTypography.SIZE_SMALL)
	_ui_skin.apply_button_native_size(continue_button, UiSkin.BUTTON_HEIGHT_LARGE, 234.0)
	_ui_skin.apply_button_native_size(start_button, UiSkin.BUTTON_HEIGHT_LARGE, 234.0)
	_ui_skin.apply_button_native_size(boss_button, UiSkin.BUTTON_HEIGHT_LARGE, 234.0)
	continue_button.disabled = false
	boss_button.visible = false
	UiTypography.set_label_size(title_label, UiTypography.SIZE_HERO)
	UiTypography.set_label_size(subtitle_label, UiTypography.SIZE_BODY_LARGE)
	UiTypography.set_label_size(embers_label, UiTypography.SIZE_SECTION)
	UiTypography.set_label_size(footer_label, UiTypography.SIZE_SMALL)
	UiTypography.set_label_size(upgrade_title_label, UiTypography.SIZE_SECTION)
	UiTypography.set_label_size(upgrade_subtitle_label, UiTypography.SIZE_SMALL)
	title_label.add_theme_color_override("font_color", Color("f1e8d3"))
	title_label.add_theme_color_override("font_outline_color", Color("2b1e16"))
	title_label.add_theme_constant_override("outline_size", 3)
	subtitle_label.add_theme_color_override("font_color", Color("d8c7a8"))
	subtitle_label.add_theme_color_override("font_outline_color", Color("211711"))
	subtitle_label.add_theme_constant_override("outline_size", 1)
	embers_label.add_theme_color_override("font_color", Color("f0c978"))
	embers_label.add_theme_color_override("font_outline_color", Color("211711"))
	embers_label.add_theme_constant_override("outline_size", 1)
	footer_label.add_theme_color_override("font_color", Color("bba78a"))
	footer_label.add_theme_color_override("font_outline_color", Color("211711"))
	footer_label.add_theme_constant_override("outline_size", 1)
	upgrade_title_label.add_theme_color_override("font_color", Color("f0e6d2"))
	upgrade_title_label.add_theme_color_override("font_outline_color", Color("2c1f16"))
	upgrade_title_label.add_theme_constant_override("outline_size", 2)
	upgrade_subtitle_label.add_theme_color_override("font_color", Color("cdbca2"))
	hero_art.texture = AssetLoader.load_texture("res://assets/placeholders/units/player_reaver.png")
	hero_art.custom_minimum_size = Vector2(0.0, 286.0)
	hero_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hero_art.modulate = Color(1.0, 0.97, 0.92, 1.0)

func _reload_progression() -> void:
	_progression = ProgressionStore.load_data()
	embers_label.text = "LV %d  |  EMBERS %d" % [int(_progression.get("level", 1)), int(_progression.get("embers", 0))]
	continue_button.visible = ProgressionStore.has_saved_run()
	footer_label.text = "Continue your route or begin again." if continue_button.visible else "Start at the center. Carry embers from campfires."
	upgrade_title_label.text = "Character"
	upgrade_subtitle_label.text = "Held embers and stat growth."
	_clear_children(upgrade_list)
	upgrade_list.add_child(_build_metric_row(
		"Level",
		str(int(_progression.get("level", 1))),
		"%d unspent" % int(_progression.get("unspent_stat_points", 0)),
		FOCUS_ICON_PATH,
		Color("c9a1ec")
	))
	upgrade_list.add_child(_build_metric_row(
		"Embers",
		str(int(_progression.get("embers", 0))),
		_next_level_detail(),
		EMBER_ICON_PATH,
		Color("f0c978")
	))
	upgrade_list.add_child(_build_metric_row(
		"Bound Magicks",
		str(_bound_magick_count()),
		"Cards altered",
		CARD_PLAY_ICON_PATH,
		Color("d0a05c")
	))
	upgrade_list.add_child(_build_upgrade_hint())

func _build_metric_row(title_text: String, value_text: String, detail_text: String, icon_path: String, accent: Color) -> Control:
	var container := PanelContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := _ui_skin.make_plain_card_style(Color("251c16"), accent.darkened(0.25), 10.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.shadow_size = 6
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	container.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	container.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(38.0, 38.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = AssetLoader.load_texture(icon_path)
	icon.modulate = Color(1.0, 0.96, 0.88, 0.95)
	row.add_child(icon)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 1)
	row.add_child(text_box)

	var title := Label.new()
	title.text = title_text
	UiTypography.set_label_size(title, UiTypography.SIZE_SMALL)
	title.add_theme_color_override("font_color", Color("f2e5cc"))
	title.add_theme_color_override("font_outline_color", Color("211711"))
	title.add_theme_constant_override("outline_size", 1)
	text_box.add_child(title)

	var detail := Label.new()
	detail.text = detail_text
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTypography.set_label_size(detail, UiTypography.SIZE_CAPTION)
	detail.add_theme_color_override("font_color", Color("c8b698"))
	text_box.add_child(detail)

	var value := Label.new()
	value.text = value_text
	value.custom_minimum_size = Vector2(64.0, 0.0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiTypography.set_label_size(value, UiTypography.SIZE_SECTION)
	value.add_theme_color_override("font_color", accent.lightened(0.18))
	value.add_theme_color_override("font_outline_color", Color("211711"))
	value.add_theme_constant_override("outline_size", 2)
	row.add_child(value)
	return container

func _build_upgrade_hint() -> Control:
	var container := PanelContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_theme_stylebox_override("panel", _ui_skin.make_plain_card_style(Color("302319"), Color("b38a55"), 12.0))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	container.add_child(info)
	var title := Label.new()
	title.text = "Stats"
	title.add_theme_color_override("font_color", Color("f4dfb8"))
	title.add_theme_color_override("font_outline_color", Color("211711"))
	title.add_theme_constant_override("outline_size", 2)
	UiTypography.set_label_size(title, UiTypography.SIZE_SMALL)
	var description := Label.new()
	description.text = _stat_summary_text()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", Color("cdbca2"))
	description.add_theme_color_override("font_outline_color", Color("211711"))
	description.add_theme_constant_override("outline_size", 1)
	UiTypography.set_label_size(description, UiTypography.SIZE_CAPTION)
	info.add_child(title)
	info.add_child(description)
	return container

func _bound_magick_count() -> int:
	var total: int = (_progression.get("card_upgrades", {}) as Dictionary).size()
	for mods_var: Variant in (_progression.get("card_mods", {}) as Dictionary).values():
		if typeof(mods_var) == TYPE_ARRAY:
			total += (mods_var as Array).size()
	return total

func _next_level_detail() -> String:
	if ProgressionStore.is_max_level(_progression):
		return "Max level"
	return "Next %d embers" % ProgressionStore.next_level_cost(_progression)

func _stat_summary_text() -> String:
	var stats: Dictionary = GameData.normalized_progression_stats(_progression.get("stats", {}))
	var parts: PackedStringArray = []
	for stat_id: String in GameData.progression_stat_ids():
		var value: int = int(stats.get(stat_id, 0))
		if value <= 0:
			continue
		var stat_def: Dictionary = GameData.progression_stat_def(stat_id)
		parts.append("%s %d" % [str(stat_def.get("name", stat_id)), value])
	if parts.is_empty():
		return "No stat points spent yet."
	return ", ".join(parts)

func _on_start_button_pressed() -> void:
	if get_tree().root.has_meta("labyrinth_resume_saved_run"):
		get_tree().root.remove_meta("labyrinth_resume_saved_run")
	if ProgressionStore.has_saved_run():
		_progression = ProgressionStore.set_embers(ProgressionStore.load_data(), 0)
		ProgressionStore.save_data(_progression)
	ProgressionStore.clear_saved_run()
	get_tree().change_scene_to_file("res://scenes/run_scene.tscn")

func _on_continue_button_pressed() -> void:
	get_tree().root.set_meta("labyrinth_resume_saved_run", true)
	get_tree().change_scene_to_file("res://scenes/run_scene.tscn")

func _on_boss_button_pressed() -> void:
	if get_tree().root.has_meta("labyrinth_resume_saved_run"):
		get_tree().root.remove_meta("labyrinth_resume_saved_run")
	get_tree().root.set_meta("labyrinth_debug_boss_run", true)
	get_tree().change_scene_to_file("res://scenes/run_scene.tscn")

func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		child.queue_free()
