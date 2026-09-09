extends SceneTree

## Build the production-only cutout PCK in the task project; verify from an empty
## --path (optionally with a desktop export template) so references cannot mask
## a missing shipped layout, raw PNG or imported-cache dependency.
var _errors: Array[String] = []

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["build", "verify"]:
		push_error("Use -- build|verify /absolute/path/to/cutout.pck")
		quit(1)
		return
	if args[0] == "build":
		var pack := PCKPacker.new()
		_check(pack.pck_start(args[1]) == OK, "PCK opens")
		for file: String in ["scripts/stone_warden_cutout/rig.gd", "scripts/stone_warden_cutout/motion.gd", "scripts/stone_warden_cutout/renderer.gd", "scripts/asset_loader.gd", "scripts/protagonist_cutout/rig.gd", "scripts/protagonist_cutout/motion.gd"]:
			_check(pack.add_file("res://" + file, "res://" + file) == OK, "Packs " + file)
		_pack_directory(pack, "res://assets/units/stone_warden_cutout")
		# A tiny boot scene also lets the unmodified export template run this
		# package directly, without its deliberately disabled --path override.
		_check(pack.add_file("res://runtime.gd", "res://tests/fixtures/stone_warden_cutout_export_smoke.gd") == OK, "Packs export-runtime entry script")
		var runtime_scene: String = "[gd_scene load_steps=2 format=3]\n[ext_resource type=\"Script\" path=\"res://runtime.gd\" id=\"1\"]\n[node name=\"CutoutExportSmoke\" type=\"Node\"]\nscript = ExtResource(\"1\")\n"
		var runtime_project: String = "config_version=5\n[application]\nconfig/name=\"Cutout Export Smoke\"\nrun/main_scene=\"res://runtime.tscn\"\n"
		for entry: Array in [["runtime.tscn", runtime_scene], ["project.godot", runtime_project], [".godot/global_script_class_cache.cfg", "list=Array[Dictionary]([])\n"]]:
			var source: String = "user://" + str(entry[0])
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(source.get_base_dir()))
			var file: FileAccess = FileAccess.open(source, FileAccess.WRITE)
			file.store_string(str(entry[1]))
			file.close()
			_check(pack.add_file("res://" + str(entry[0]), source) == OK, "Packs runtime smoke entry")
		_check(pack.flush() == OK, "PCK closes")
	else:
		_check(not FileAccess.file_exists("res://assets/placeholders/units/player_reaver.png"), "No legacy-art source tree is available")
		_check(not FileAccess.file_exists("res://assets/units/stone_warden_cutout/front.json"), "No loose cutout source tree is available")
		_check(ProjectSettings.load_resource_pack(args[1]), "Production cutout PCK mounts")
		var script: Script = load("res://scripts/stone_warden_cutout/renderer.gd") as Script
		_check(script != null, "Packed cutout script loads")
		if script != null:
			var renderer: Node = script.new()
			root.add_child(renderer)
			await process_frame
			for view: String in ["front", "rear"]:
				var rig: Node = renderer.get("rigs")[view]
				_check((rig.get("load_errors") as PackedStringArray).is_empty(), view + " packed paint loads")
				for clip: String in ["idle", "walk", "attack"]:
					rig.call("apply_pose", clip, 0.42)
				_check((rig.get("bones") as Dictionary).size() == 19, view + " packed skeleton is complete")
			renderer.queue_free()
			await process_frame
	for message: String in _errors:
		push_error(message)
	print("WARDEN CUTOUT PACK TEST RESULT: " + ("PASS" if _errors.is_empty() else "FAIL") + " (" + args[0] + ", editor=" + str(OS.has_feature("editor")) + ")")
	quit(0 if _errors.is_empty() else 1)

func _pack_directory(pack: PCKPacker, path: String) -> void:
	for file: String in DirAccess.get_files_at(path):
		if file.get_extension() in ["png", "json", "import"]:
			_check(pack.add_file(path.path_join(file), path.path_join(file)) == OK, "Packs " + file)
	for directory: String in DirAccess.get_directories_at(path):
		_pack_directory(pack, path.path_join(directory))

func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
