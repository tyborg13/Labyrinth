extends SceneTree

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	preload("res://tools/rd02/fixture.gd").install("zekarion")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var target: String = args[args.find("--output") + 1]
	var payload := Resource.new()
	payload.set_meta("run_state", preload("res://scripts/progression_store.gd").load_saved_run())
	assert(ResourceSaver.save(payload, target) == OK, "Package certified release fixture")
	print("RD02 RELEASE FIXTURE: ", target)
	quit()
