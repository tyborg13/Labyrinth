extends SceneTree

## Temporary production-only package. No experiments/tools or legacy art tree
## is reachable in the resulting pack; the fixture becomes res://runtime.gd.
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Pass the output PCK path")
		quit(1)
		return
	var pack := PCKPacker.new()
	check(pack.pck_start(args[0]) == OK, "Open PCK")
	add_directory(pack, "res://scripts", ["gd", "gdshader"])
	add_directory(pack, "res://data", ["json"])
	for creature: String in ["burrow_grub", "ember_tick"]:
		add_directory(pack, "res://assets/units/" + creature + "_cutout", ["gd", "json", "png", "import"])
	check(pack.add_file("res://assets/units/hoarfrost_seer_cutout/precision.gd", "res://assets/units/hoarfrost_seer_cutout/precision.gd") == OK, "Shared native-tie precision packs")
	check(pack.add_file("res://runtime.gd", "res://experiments/cutouts/burrow_grub/rr12_pack_runtime.gd") == OK, "Runtime fixture packs")
	var project: String = "config_version=5\n[application]\nconfig/name=\"rr-12 package proof\"\nrun/main_scene=\"res://runtime.tscn\"\n[rendering]\nrenderer/rendering_method=\"gl_compatibility\"\n"
	var scene: String = "[gd_scene load_steps=2 format=3]\n[ext_resource type=\"Script\" path=\"res://runtime.gd\" id=\"1\"]\n[node name=\"RR12Package\" type=\"Node\"]\nscript = ExtResource(\"1\")\n"
	for entry: Array in [["project.godot", project], ["runtime.tscn", scene], [".godot/global_script_class_cache.cfg", "list=Array[Dictionary]([])\n"]]:
		var source: String = "user://" + str(entry[0])
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(source.get_base_dir()))
		var file := FileAccess.open(source, FileAccess.WRITE)
		file.store_string(str(entry[1]))
		file.close()
		check(pack.add_file("res://" + str(entry[0]), source) == OK, "Boot resource packs")
	check(pack.flush() == OK, "Close PCK")
	for error: String in failures: push_error(error)
	print("RR12 PACKAGE BUILD: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func add_directory(pack: PCKPacker, path: String, extensions: Array) -> void:
	for filename: String in DirAccess.get_files_at(path):
		if filename.get_extension() in extensions:
			check(pack.add_file(path.path_join(filename), path.path_join(filename)) == OK, "Pack " + path.path_join(filename))
	for folder: String in DirAccess.get_directories_at(path):
		add_directory(pack, path.path_join(folder), extensions)

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
