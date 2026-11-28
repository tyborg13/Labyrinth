extends SceneTree
## Mount one replay in both worktrees. Headless packs also mount draw observers.

const SCRIPTS := ["replay", "observe", "floor_pixels", "sample_pixels", "adjacent", "trace"]
const REPLAY_HELPERS := ["input_driver", "screens"]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2 or args.size() > 3:
		quit(1)
		return
	var pack := PCKPacker.new()
	var paths: Array[String]
	for script: String in SCRIPTS: paths.append("tools/fel32/" + script + ".gd")
	for script: String in REPLAY_HELPERS: paths.append("tools/fel30/" + script + ".gd")
	if pack.pck_start(args[1]) != OK or pack.add_file("res://project.godot", args[0].path_join("project.godot")) != OK:
		quit(1)
		return
	for path: String in paths:
		if pack.add_file("res://" + path, ProjectSettings.globalize_path("res://" + path)) != OK:
			quit(1)
			return
	if args.size() == 3:
		for filename: String in DirAccess.get_files_at(args[2]):
			if pack.add_file("res://scripts/" + filename, args[2].path_join(filename)) != OK:
				quit(1)
				return
	quit(pack.flush())
