extends "res://tools/rebake_cutout_rests.gd"

## Promotion changes the assembly even if density cleanup changes zero texels.
## Always rebake both Briar Weaver views; never certify this from a headless run.
func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	super._initialize()

func _parts_changed(entry: Dictionary, _facing: String) -> bool:
	return str(entry["id"]) == "briar_weaver_cutout"

func _update_rest_fingerprint(layout_path: String, rest_path: String) -> void:
	super._update_rest_fingerprint(layout_path, rest_path)
	super._update_rest_fingerprint(layout_path.get_base_dir().path_join("humanoid_v2").path_join(layout_path.get_file()), rest_path)
