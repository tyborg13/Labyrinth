extends SceneTree

## Packs every production script plus the 19 cutout asset directories. This
## deliberately excludes the loose project, legacy art, tools and experiments.
var _errors: Array[String]

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Pass an absolute output PCK path after --")
		quit(1)
		return
	var pack := PCKPacker.new()
	_check(pack.pck_start(args[0]) == OK, "PCK opens")
	_pack_directory(pack,"res://scripts",["gd","gdshader"])
	for folder: String in DirAccess.get_directories_at("res://assets/units"):
		if folder.ends_with("_cutout"):
			_pack_directory(pack,"res://assets/units".path_join(folder),["png","json","import"])
	_check(pack.add_file("res://runtime.gd","res://tests/fixtures/enemy_cutout_roster_export_smoke.gd") == OK, "Runtime smoke script packs")
	var scene: String = "[gd_scene load_steps=2 format=3]\n[ext_resource type=\"Script\" path=\"res://runtime.gd\" id=\"1\"]\n[node name=\"RosterExportSmoke\" type=\"Node\"]\nscript = ExtResource(\"1\")\n"
	var project: String = "config_version=5\n[application]\nconfig/name=\"Enemy Roster Export Smoke\"\nrun/main_scene=\"res://runtime.tscn\"\n"
	for entry: Array in [["runtime.tscn",scene],["project.godot",project],[".godot/global_script_class_cache.cfg","list=Array[Dictionary]([])\n"]]:
		var source: String = "user://" + str(entry[0])
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(source.get_base_dir()))
		var file := FileAccess.open(source,FileAccess.WRITE)
		file.store_string(str(entry[1]))
		file.close()
		_check(pack.add_file("res://" + str(entry[0]),source) == OK,"Boot resource packs")
	_check(pack.flush() == OK,"PCK closes")
	for error: String in _errors:
		push_error(error)
	print("ENEMY CUTOUT ROSTER PACK BUILD TEST RESULT: " + ("PASS" if _errors.is_empty() else "FAIL"))
	quit(0 if _errors.is_empty() else 1)

func _pack_directory(pack: PCKPacker, path: String, extensions: Array) -> void:
	for file: String in DirAccess.get_files_at(path):
		if file.get_extension() in extensions:
			_check(pack.add_file(path.path_join(file),path.path_join(file)) == OK,"Packs " + path.path_join(file))
	for folder: String in DirAccess.get_directories_at(path):
		_pack_directory(pack,path.path_join(folder),extensions)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
