extends SceneTree

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")

func _initialize() -> void:
	Runtime.apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	Settings.set_storage_path("user://hud_benchmark_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	Settings.apply_settings(settings, root, false)
	Store.set_storage_path("user://hud_benchmark_profile.json")
	Store.set_run_storage_path("user://hud_benchmark_run.save")
	var profile: Dictionary = Store.default_data()
	profile[Tutorial.PROGRESSION_KEY] = {"version": Tutorial.VERSION, "status": "dismissed", "completed_steps": []}
	Store.save_data(profile)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	root.add_child(viewport)
	var instance: Node = load("res://scenes/run_scene.tscn").instantiate()
	viewport.add_child(instance)
	await process_frame
	instance.call("_close_dialogue")
	var state: Dictionary = Run.new().create_new_run(123, profile)
	state["relics"] = ["iron_lung", "ember_lens", "pilgrim_boots", "mirror_shard", "phoenix_ember", "winters_hour", "stormroad_coil", "iron_buckler", "reinforced_shield", "coffin_nails"]
	instance.set("_run_state", state)
	instance.set("_combat_state", {})
	var grid: Node = instance.get("_relic_icon_grid")
	var samples: Array[int]
	var cold: int = 0
	for index: int in range(41):
		instance.set("_relic_bar_signature", "benchmark_%d" % index)
		grid.set_meta("relic_icon_signature", -1)
		var started: int = Time.get_ticks_usec()
		instance.call("_refresh_relic_bar")
		var elapsed: int = Time.get_ticks_usec() - started
		if index == 0:
			cold = elapsed
		elif index > 5:
			samples.append(elapsed)
		await process_frame
	samples.sort()
	print("RELIC GRID BUILD (10 relics): cold=%dus warm_median=%dus warm_p95=%dus samples=%d" % [cold, samples[samples.size() / 2], samples[roundi(float(samples.size() - 1) * 0.95)], samples.size()])
	var glows: Dictionary = {}
	var materials: Dictionary = {}
	for socket: Button in grid.get_children():
		glows[socket.get("_glow")] = true
		materials[socket.get_node("Icon").material] = true
	var shared: bool = grid.get_child_count() == 10 and glows.size() == 1 and materials.size() == 1
	print("RELIC GRID RESOURCE REUSE: sockets=%d glow_textures=%d icon_materials=%d %s" % [grid.get_child_count(), glows.size(), materials.size(), "PASS" if shared else "FAIL"])
	instance.queue_free()
	await process_frame
	viewport.queue_free()
	await process_frame
	quit(0 if shared else 1)
