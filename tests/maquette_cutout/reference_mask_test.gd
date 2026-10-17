extends SceneTree

## Headless image-operation proof, not native renderer proof.
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var directory: String = args[args.find("--output") + 1]
	DirAccess.make_dir_recursive_absolute(directory)
	var rows: Array[Dictionary]
	for creature: String in ["shale_bloomer", "lightning_wisp"]:
		var revision: String = "mq3" if creature == "shale_bloomer" else "mq4"
		var source: String = "res://experiments/cutouts/%s/%s" % [creature, revision]
		for view: String in ["front", "rear"]:
			var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source.path_join("layouts/" + view + ".json")))
			var images: Dictionary = preload("reference_masks.gd").images(source, layout)
			for kind: String in images:
				var path: String = directory.path_join(creature + "_" + view + "_" + kind + ".png")
				(images[kind] as Image).save_png(path)
				rows.append({"creature": creature, "view": view, "kind": kind, "file": path})
	var file := FileAccess.open(directory.path_join("images.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"images": rows, "native_pixels": false}))
	print("MAQUETTE REFERENCE MASKS: PASS (8 source masks; headless image operations only)")
	quit()
