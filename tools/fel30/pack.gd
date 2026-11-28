extends SceneTree
## Package only the generated diagnostic source copies.

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(1)
		return
	var folder: String = args[0]
	var pack := PCKPacker.new()
	if pack.pck_start(folder.path_join("census.pck")) != OK:
		quit(1)
		return
	if pack.add_file("res://project.godot", ProjectSettings.globalize_path("res://project.godot")) != OK:
		quit(1)
		return
	var files: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("scripts.json")))
	for name: String in files:
		if pack.add_file("res://scripts/" + str(files[name]), folder.path_join(name)) != OK:
			quit(1)
			return
	quit(pack.flush())
