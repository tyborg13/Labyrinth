extends RefCounted
## Publish the existing title textures into the cache their draw paths use.
## Source-first flags must match the ornament and background consumers.

const Assets = preload("res://scripts/asset_loader.gd")
const Ornament = preload("res://scripts/themed_button_ornament.gd")
const BACKGROUND_ART_PATH: String = "res://assets/art/ui/main_menu_umbra_dragon.png"
const TEXTURES := {
	BACKGROUND_ART_PATH: false,
	Ornament.UMBRA_BUTTON_IDLE_PATH: true,
	Ornament.UMBRA_BUTTON_FOCUSED_PATH: true,
	Ornament.UMBRA_FOCUS_MARKER_LEFT_PATH: true,
	Ornament.UMBRA_FOCUS_MARKER_RIGHT_PATH: true,
}

static func prepare_for(root: Window, present: Callable, active: Callable) -> void:
	await Assets.prepare_textures_for(root, TEXTURES, present, active)
