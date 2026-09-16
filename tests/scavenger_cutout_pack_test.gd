extends SceneTree
## Package only production dependencies; the unmodified export runtime opens it.
var failed: bool = false
func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(1)
		return
	var pack := PCKPacker.new()
	check(pack.pck_start(args[0]) == OK, "Open production pack")
	for path: String in ["scripts/scavenger_cutout/rig.gd", "scripts/scavenger_cutout/motion.gd", "scripts/protagonist_cutout/rig.gd", "scripts/protagonist_cutout/motion.gd", "scripts/asset_loader.gd"]:
		check(pack.add_file("res://" + path, "res://" + path) == OK, "Pack " + path)
	pack_directory(pack, "res://assets/units/scavenger_cutout")
	check(pack.add_file("res://runtime.gd", "res://tests/fixtures/scavenger_cutout_export_smoke.gd") == OK, "Pack runtime test")
	var entries: Dictionary = {
		"runtime.tscn": "[gd_scene load_steps=2 format=3]\n[ext_resource type=\"Script\" path=\"res://runtime.gd\" id=\"1\"]\n[node name=\"Smoke\" type=\"Node\"]\nscript=ExtResource(\"1\")\n",
		"project.godot": "config_version=5\n[application]\nconfig/name=\"Scavenger Cutout Smoke\"\nrun/main_scene=\"res://runtime.tscn\"\n",
		".godot/global_script_class_cache.cfg": "list=Array[Dictionary]([])\n"}
	for name: String in entries:
		var path: String = "user://" + name
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(entries[name])
		file.close()
		check(pack.add_file("res://" + name, path) == OK, "Pack smoke entry")
	check(pack.flush() == OK, "Close pack")
	print("SCAVENGER PRODUCTION PACK: " + ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)

func pack_directory(pack: PCKPacker, path: String) -> void:
	for file: String in DirAccess.get_files_at(path):
		if file.get_extension() in ["json", "png", "import"]:
			check(pack.add_file(path.path_join(file), path.path_join(file)) == OK, "Pack paint")
	for directory: String in DirAccess.get_directories_at(path):
		pack_directory(pack, path.path_join(directory))

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
