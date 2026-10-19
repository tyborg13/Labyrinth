extends SceneTree

## Self-contained production package, with no tools/ or experiments/ fallback.
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Use -- /absolute/path/to/rr22.pck")
		quit(1)
		return
	var pack := PCKPacker.new()
	var scripts: Dictionary = {}
	check(pack.pck_start(args[0]) == OK, "PCK opens")
	var script_packer: Script = load("res://tests/helpers/source_script_pack.gd")
	check(script_packer.add_tree(pack, "res://assets/units/slag_mortar_cutout/renderer.gd", scripts) == OK, "Packs renderer closure")
	check(script_packer.add_tree(pack, "res://assets/units/slag_mortar_cutout/rig.gd", scripts) == OK, "Packs rig closure")
	check(script_packer.add_tree(pack, "res://assets/units/hoarfrost_seer_cutout/precision.gd", scripts) == OK, "Packs shared legacy precision dependency")
	# The registry also contains a formatted runtime renderer path. Pack its
	# literal preloads; the selected concrete renderer is already packed above.
	var registry: String = "res://scripts/maquette_cutout_runtime/presentation.gd"
	check(pack.add_file(registry, registry) == OK, "Packs registry")
	var preloads := RegEx.new()
	preloads.compile('preload\\("([^"\\n]+\\.gd)"\\)')
	for reference: RegExMatch in preloads.search_all(FileAccess.get_file_as_string(registry)):
		var dependency: String = reference.get_string(1)
		if not dependency.begins_with("res://"): dependency = registry.get_base_dir().path_join(dependency)
		check(script_packer.add_tree(pack, dependency, scripts) == OK, "Packs registry preload closure")
	paint(pack, "res://assets/units/slag_mortar_cutout")
	check(pack.add_file("res://runtime.gd", "res://tests/rr22/export_smoke.gd") == OK, "Packs smoke entry")
	var scene: String = "[gd_scene load_steps=2 format=3]\n[ext_resource type=\"Script\" path=\"res://runtime.gd\" id=\"1\"]\n[node name=\"RR22ExportSmoke\" type=\"Node\"]\nscript = ExtResource(\"1\")\n"
	var project: String = "config_version=5\n[application]\nconfig/name=\"RR22 Export Smoke\"\nrun/main_scene=\"res://runtime.tscn\"\n"
	for entry: Array in [["runtime.tscn",scene],["project.godot",project],[".godot/global_script_class_cache.cfg","list=Array[Dictionary]([])\n"]]:
		var source: String = "user://" + str(entry[0])
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(source.get_base_dir()))
		var file := FileAccess.open(source, FileAccess.WRITE)
		file.store_string(str(entry[1]))
		file.close()
		check(pack.add_file("res://"+str(entry[0]),source) == OK,"Packs boot file")
	check(pack.flush() == OK, "PCK closes")
	for failure: String in failures: push_error(failure)
	print("RR22 PRODUCTION PACK BUILD: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func paint(pack: PCKPacker, directory: String) -> void:
	for name: String in DirAccess.get_files_at(directory):
		if name.get_extension() in ["json","png","import"]:
			check(pack.add_file(directory.path_join(name),directory.path_join(name)) == OK,"Packs "+name)
	for name: String in DirAccess.get_directories_at(directory): paint(pack,directory.path_join(name))

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
