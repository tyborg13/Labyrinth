extends Control

const AssetLoader = preload("res://scripts/asset_loader.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")

@onready var hero_panel: PanelContainer = $Backdrop/Margin/Center/BodyRow/HeroPanel
@onready var title_label: Label = $Backdrop/Margin/Center/BodyRow/HeroPanel/HeroMargin/HeroVBox/Title
@onready var subtitle_label: Label = $Backdrop/Margin/Center/BodyRow/HeroPanel/HeroMargin/HeroVBox/Subtitle
@onready var hero_art: TextureRect = $Backdrop/Margin/Center/BodyRow/HeroPanel/HeroMargin/HeroVBox/HeroArt
@onready var embers_label: Label = $Backdrop/Margin/Center/BodyRow/HeroPanel/HeroMargin/HeroVBox/Embers
@onready var footer_label: Label = $Backdrop/Margin/Center/BodyRow/HeroPanel/HeroMargin/HeroVBox/Footer
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
	$Backdrop.color = Color("140f0d")
	hero_panel.add_theme_stylebox_override("panel", _ui_skin.make_board_frame_style(18.0))
	upgrade_panel.add_theme_stylebox_override("panel", _ui_skin.make_plain_card_style(Color("e8ddc7"), Color("876a48"), 16.0))
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
	UiTypography.set_label_size(title_label, UiTypography.SIZE_HERO)
	UiTypography.set_label_size(subtitle_label, UiTypography.SIZE_BODY_LARGE)
	UiTypography.set_label_size(embers_label, UiTypography.SIZE_SECTION)
	UiTypography.set_label_size(footer_label, UiTypography.SIZE_SMALL)
	UiTypography.set_label_size(upgrade_title_label, UiTypography.SIZE_SECTION)
	UiTypography.set_label_size(upgrade_subtitle_label, UiTypography.SIZE_SMALL)
	title_label.add_theme_color_override("font_color", Color("f1e8d3"))
	title_label.add_theme_color_override("font_outline_color", Color("2b1e16"))
	title_label.add_theme_constant_override("outline_size", 3)
	subtitle_label.add_theme_color_override("font_color", Color("d6c8b1"))
	embers_label.add_theme_color_override("font_color", Color("f0c978"))
	footer_label.add_theme_color_override("font_color", Color("bba78a"))
	upgrade_title_label.add_theme_color_override("font_color", Color("3e2e20"))
	upgrade_subtitle_label.add_theme_color_override("font_color", Color("725b42"))
	hero_art.texture = AssetLoader.load_texture("res://assets/placeholders/units/player_reaver.png")
	hero_art.modulate = Color(1.0, 0.97, 0.92, 1.0)

func _reload_progression() -> void:
	_progression = ProgressionStore.load_data()
	embers_label.text = "Banked Embers: %d" % int(_progression.get("embers", 0))
	continue_button.visible = ProgressionStore.has_saved_run()
	footer_label.text = "Continue or start fresh." if continue_button.visible else "Start at the center. Bank embers at campfires."
	upgrade_title_label.text = "Bound Magicks"
	upgrade_subtitle_label.text = "Touch the Emaciated Man in the waypoint."
	_clear_children(upgrade_list)
	upgrade_list.add_child(_build_upgrade_hint())

func _build_upgrade_hint() -> Control:
	var container := PanelContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_theme_stylebox_override("panel", _ui_skin.make_plain_card_style(Color("f3ead8"), Color("a17d56"), 10.0))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	container.add_child(info)
	var title := Label.new()
	var bound_count: int = _bound_magick_count()
	title.text = "%d card magick%s bound" % [
		bound_count,
		"" if bound_count == 1 else "s"
	]
	title.add_theme_color_override("font_color", Color("433122"))
	title.add_theme_color_override("font_outline_color", Color("fff4dd"))
	title.add_theme_constant_override("outline_size", 2)
	UiTypography.set_label_size(title, UiTypography.SIZE_SMALL)
	var description := Label.new()
	description.text = "Rest at a fire, then return to the waypoint to bind cards with banked embers."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", Color("6d5841"))
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

func _on_start_button_pressed() -> void:
	if get_tree().root.has_meta("labyrinth_resume_saved_run"):
		get_tree().root.remove_meta("labyrinth_resume_saved_run")
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
