extends "res://tools/rebake_cutout_rests.gd"

## Promotion changes the assembly even if density cleanup changes zero texels.
## Always rebake both Hollow Mimic views; never certify this from a headless run.
func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	super._initialize()

func _parts_changed(entry: Dictionary, _facing: String) -> bool:
	return str(entry["id"]) == "hollow_mimic_cutout"

