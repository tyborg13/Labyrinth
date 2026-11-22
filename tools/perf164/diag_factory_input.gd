extends SceneTree
## perf-164 diagnostic: where the checkpoint's repaired state and the installed
## run state differ as pre-battle factory inputs.
const Store = preload("res://scripts/progression_store.gd")
const Fixtures = preload("res://tools/hitch_census/fixtures.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var storage: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--storage="): storage = argument.trim_prefix("--storage=")
	if storage.is_empty():
		Store.set_storage_path("user://perf164-diag-profile.json")
		Store.set_run_storage_path("user://perf164-diag-run.save")
		var builder := Fixtures.new()
		var state: Dictionary = builder.make("pre_battle", 7)
		builder.free()
		Store.save_data(state["progression"])
		Store.save_run_state(state)
	else:
		Store.set_storage_path(storage.path_join("perf164-profile.json"))
		Store.set_run_storage_path(storage.path_join("perf164-run.save"))
	var scene: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	root.set_meta("labyrinth_resume_saved_run", true)
	scene.call("request_staged_initial_ui")
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var engine: RefCounted = scene._run_engine
	var disk: Dictionary = Store.read_resumable_checkpoint().get("state", {})
	if engine.run_content_migration_required(disk): disk = engine.migrate_renamed_content_ids(disk)
	disk = engine.repair_loaded_run_state(disk)
	root.set_meta("labyrinth_resume_saved_run", true)
	scene.call("_prepare_initial_run_state")
	var live: Dictionary = scene._run_state
	var a: Dictionary = engine._pre_battle_factory_input(disk)
	var b: Dictionary = engine._pre_battle_factory_input(live)
	print("PERF164 DIAG equal=", a == b, " mode=", live.get("mode"))
	for key: Variant in a.keys() + b.keys():
		if a.get(key) == b.get(key): continue
		var detail: String = ""
		if a.get(key) is Dictionary and b.get(key) is Dictionary:
			var sub := PackedStringArray()
			for inner: Variant in (a[key] as Dictionary).keys() + (b[key] as Dictionary).keys():
				if (a[key] as Dictionary).get(inner) != (b[key] as Dictionary).get(inner) and not sub.has(str(inner)): sub.append(str(inner))
			detail = " sub=" + ",".join(sub)
		print("PERF164 DIAG differs: ", key, detail, " disk=", str(a.get(key)).left(200), " live=", str(b.get(key)).left(200))
		if key == "rooms":
			for coord: Variant in (a[key] as Dictionary):
				var ra: Dictionary = a[key][coord]
				var rb: Dictionary = (b[key] as Dictionary).get(coord, {})
				if ra == rb: continue
				for field: Variant in ra.keys() + rb.keys():
					if ra.get(field) != rb.get(field): print("   room ", coord, " ", field, " disk=", str(ra.get(field)).left(120), " live=", str(rb.get(field)).left(120))
	quit()
