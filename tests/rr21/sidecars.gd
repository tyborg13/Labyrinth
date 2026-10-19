extends SceneTree

## Scoped metadata only; never an editor filesystem scan or a parser check.
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	for folder: String in ["res://assets/units/briar_weaver_cutout", "res://tests/rr21"]:
		collect(folder)
	print("RR21 SCRIPT SIDECARS: PASS (scoped stable UIDs)")
	quit()

func collect(folder: String) -> void:
	var access := DirAccess.open(folder)
	for name: String in access.get_files():
		if name.get_extension() != "gd": continue
		var path: String = folder.path_join(name) + ".uid"
		if FileAccess.file_exists(path): continue
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_line(ResourceUID.id_to_text(ResourceUID.create_id()))
	for name: String in access.get_directories(): collect(folder.path_join(name))
