extends SceneTree

## Stable resource identities prepared before the director's visual runner.
func _initialize() -> void:
	for directory: String in ["res://tests/rr22", "res://assets/units/slag_mortar_cutout", "res://experiments/cutouts/slag_mortar/rr22"]:
		for name: String in DirAccess.get_files_at(directory):
			if not name.ends_with(".gd"): continue
			var path: String = directory.path_join(name) + ".uid"
			if FileAccess.file_exists(path): continue
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_line(ResourceUID.id_to_text(ResourceUID.create_id()))
	print("RR22 SCRIPT SIDECARS: PASS")
	quit()
