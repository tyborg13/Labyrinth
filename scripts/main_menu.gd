extends Control

const AssetLoader = preload("res://scripts/asset_loader.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const GameData = preload("res://scripts/game_data.gd")
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
	UiTypography.set_button_size(continue_button, UiTypography.SIZE_SMALL)
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
	_clear_children(upgrade_list)
	for upgrade_id: String in GameData.upgrade_ids():
		upgrade_list.add_child(_build_upgrade_row(upgrade_id))

func _build_upgrade_row(upgrade_id: String) -> Control:
	var upgrade: Dictionary = GameData.upgrade_def(upgrade_id)
	var container := PanelContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_theme_stylebox_override("panel", _ui_skin.make_plain_card_style(Color("f3ead8"), Color("a17d56"), 10.0))
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	container.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = "%s (%d)" % [str(upgrade.get("name", upgrade_id)), int(upgrade.get("cost", 0))]
	title.add_theme_color_override("font_color", Color("433122"))
	title.add_theme_color_override("font_outline_color", Color("fff4dd"))
	title.add_theme_constant_override("outline_size", 2)
	UiTypography.set_label_size(title, UiTypography.SIZE_SMALL)
	var description := Label.new()
	description.text = str(upgrade.get("description", ""))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", Color("6d5841"))
	UiTypography.set_label_size(description, UiTypography.SIZE_CAPTION)
	info.add_child(title)
	info.add_child(description)
	var button := Button.new()
	var owned: bool = ProgressionStore.has_upgrade(_progression, upgrade_id)
	if owned:
		button.text = "Owned"
		button.disabled = true
	elif ProgressionStore.can_purchase(_progression, upgrade_id):
		button.text = "Buy"
	else:
		button.text = "Need %d" % int(upgrade.get("cost", 0))
		button.disabled = true
	button.custom_minimum_size = Vector2(112.0, 0.0)
	_ui_skin.apply_button_stylebox_overrides(button)
	_ui_skin.apply_button_text_overrides(button)
	UiTypography.set_button_size(button, UiTypography.SIZE_SMALL)
	if not owned and not button.disabled:
		button.pressed.connect(_on_upgrade_pressed.bind(upgrade_id))
	row.add_child(info)
	row.add_child(button)
	return container

func _on_upgrade_pressed(upgrade_id: String) -> void:
	_progression = ProgressionStore.purchase_upgrade(_progression, upgrade_id)
	ProgressionStore.save_data(_progression)
	_reload_progression()

func _on_start_button_pressed() -> void:
	if get_tree().root.has_meta("labyrinth_resume_saved_run"):
		get_tree().root.remove_meta("labyrinth_resume_saved_run")
	ProgressionStore.clear_saved_run()
	get_tree().change_scene_to_file("res://scenes/run_scene.tscn")

func _on_continue_button_pressed() -> void:
	get_tree().root.set_meta("labyrinth_resume_saved_run", true)
	get_tree().change_scene_to_file("res://scenes/run_scene.tscn")

func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		child.queue_free()
