extends RefCounted
class_name CardActionContextArt


const AssetLoader = preload("res://scripts/asset_loader.gd")
const PlacardSoftGlowShader = preload("res://shaders/card_action_context_soft_glow.gdshader")
const MODE_ART_PATHS: Dictionary = {
	"play": "res://assets/art/ui/card_action_mode_printed_v1.png",
	"attack": "res://assets/art/ui/card_action_mode_attack_v1.png",
	"move": "res://assets/art/ui/card_action_mode_move_v1.png",
	"blink": "res://assets/art/ui/card_action_mode_blink_v1.png",
}
const MODE_SPINE_PATH: String = "res://assets/art/ui/card_action_mode_spine_v1.png"
const ACTION_TAG_PATH: String = "res://assets/art/ui/card_action_step_tag_v1.png"
const ACTION_ARROW_PATH: String = "res://assets/art/ui/card_action_step_arrow_v1.png"


static func attach_mode_spine(host: Control) -> TextureRect:
	var spine := TextureRect.new()
	spine.name = "ModePlacardSpine"
	spine.anchor_left = 0.5
	spine.anchor_top = 0.0
	spine.anchor_right = 0.5
	spine.anchor_bottom = 1.0
	spine.offset_left = -18.0
	spine.offset_top = -24.0
	spine.offset_right = 18.0
	spine.offset_bottom = 24.0
	spine.texture = AssetLoader.load_texture(MODE_SPINE_PATH)
	spine.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spine.stretch_mode = TextureRect.STRETCH_SCALE
	spine.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	spine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spine.show_behind_parent = true
	spine.z_index = -5
	spine.set_meta("connects_placards_only", true)
	spine.set_meta("spine_art_path", MODE_SPINE_PATH)
	host.add_child(spine)
	return spine

static func attach_mode_placard(button: BaseButton, play_kind: String, accent: Color, active: bool, available: bool) -> TextureRect:
	var art_path: String = str(MODE_ART_PATHS.get(play_kind, MODE_ART_PATHS["play"]))
	var texture: Texture2D = AssetLoader.load_texture(art_path)
	if active and available:
		var glow := _placard_soft_glow(texture)
		glow.set_meta("matches_pre_battle_start_glow", true)
		glow.set_meta("follows_placard_alpha", true)
		button.add_child(glow)
	var placard := _texture_layer("ModePlacardTexture", texture, -1)
	button.add_child(placard)
	button.set_meta("authored_placard_choice", true)
	button.set_meta("placard_art_path", art_path)
	button.set_meta("embedded_identity_icon", true)
	button.set_meta("selected_glow_visible", active and available)
	return placard


static func attach_action_tag(panel: PanelContainer, status: String) -> TextureRect:
	var texture: Texture2D = AssetLoader.load_texture(ACTION_TAG_PATH)
	if status == "current":
		var glow := _gold_glow_panel("CurrentStepGlow", 5, 0.22)
		glow.offset_left = 6.0
		glow.offset_top = 9.0
		glow.offset_right = -6.0
		glow.offset_bottom = -9.0
		panel.add_child(glow)
	var tag := _texture_layer("ActionTagTexture", texture, -1)
	tag.modulate = _status_tint(status)
	panel.add_child(tag)
	panel.set_meta("action_medallion", true)
	panel.set_meta("authored_action_tag", true)
	panel.set_meta("action_tag_art_path", ACTION_TAG_PATH)
	return tag


static func make_action_connector(status: String, connector_index: int) -> Control:
	var connector := Control.new()
	connector.name = "ActionStepConnector%d" % connector_index
	connector.custom_minimum_size = Vector2(24.0, 64.0)
	connector.size = connector.custom_minimum_size
	connector.mouse_filter = Control.MOUSE_FILTER_IGNORE
	connector.set_meta("ink_path_connector", true)
	connector.set_meta("authored_arrow", true)
	connector.set_meta("arrow_art_path", ACTION_ARROW_PATH)
	connector.set_meta("step_status", status)
	var arrow := _texture_layer("ActionArrowTexture", AssetLoader.load_texture(ACTION_ARROW_PATH), 0)
	arrow.offset_left = 1.0
	arrow.offset_top = 20.0
	arrow.offset_right = -1.0
	arrow.offset_bottom = -20.0
	arrow.modulate = _status_tint(status)
	connector.add_child(arrow)
	return connector


static func _placard_soft_glow(texture: Texture2D) -> TextureRect:
	var glow := _texture_layer("SelectedGlow", texture, -2)
	glow.offset_left = -12.0
	glow.offset_top = -10.0
	glow.offset_right = 12.0
	glow.offset_bottom = 10.0
	var material := ShaderMaterial.new()
	material.shader = PlacardSoftGlowShader
	material.set_shader_parameter("glow_color", Color(1.0, 0.52, 0.15, 0.86))
	material.set_shader_parameter("source_radius_px", Vector2(15.0, 23.0))
	material.set_shader_parameter("uv_margin", Vector2(0.035, 0.085))
	glow.material = material
	return glow


static func _texture_layer(layer_name: String, texture: Texture2D, layer_z: int) -> TextureRect:
	var layer := TextureRect.new()
	layer.name = layer_name
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.anchor_right = 1.0
	layer.anchor_bottom = 1.0
	layer.texture = texture
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_SCALE
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.show_behind_parent = true
	layer.z_index = layer_z
	return layer


static func _gold_glow_panel(panel_name: String, shadow_size: int, shadow_alpha: float) -> Panel:
	var glow := Panel.new()
	glow.name = panel_name
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.anchor_right = 1.0
	glow.anchor_bottom = 1.0
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.show_behind_parent = true
	glow.z_index = -2
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.14, 0.045, 0.20)
	style.border_color = Color("e5ae58")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 28
	style.corner_radius_top_right = 28
	style.corner_radius_bottom_right = 28
	style.corner_radius_bottom_left = 28
	style.shadow_color = Color(1.0, 0.52, 0.15, shadow_alpha)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0.0, 2.0)
	glow.add_theme_stylebox_override("panel", style)
	return glow


static func _status_tint(status: String) -> Color:
	match status:
		"current":
			return Color.WHITE
		"done":
			return Color("93b184")
		"skipped":
			return Color("b96557")
		_:
			return Color(0.72, 0.68, 0.62, 0.78)
