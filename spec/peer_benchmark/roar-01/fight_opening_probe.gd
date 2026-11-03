extends SceneTree

# Reuses the director's real pre-battle flow; no combat state is fabricated.
const Dragon = preload("res://tools/dragon_boss_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Facing = preload("res://scripts/enemy_cutout_facing.gd")
const Proof = preload("res://spec/peer_benchmark/roar-01/proof_data.gd")
const FRAME_LIMIT: int = 60 * 25
const SEED: int = 7262026
const PREVIEW_SECONDS: float = 2.5
const TAIL_SECONDS: float = 4.0
var scene: Node
var failures: Array[String]
var records: Array[Dictionary]
var cues: Array[String]
var output: String
var dragon_id: String
var capture: bool = true
var peak_saved: bool = false

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _cue(id: String, result: String) -> void:
	cues.append(id)
	print("CUE f=%d %s %s" % [Engine.get_frames_drawn(), id, result])

func _run() -> void:
	capture = Proof.value("validate-only", "0") != "1"
	if capture and DisplayServer.get_name() == "headless":
		push_error("Movie/capture proof requires the director's window server")
		quit(1)
		return
	dragon_id = Proof.value("dragon", "tharokh")
	output = Proof.value("output-dir", Proof.OUTPUT).path_join("openings").path_join(dragon_id)
	DirAccess.make_dir_recursive_absolute(output)
	Store.set_storage_path("user://roar-01-profile.json")
	Store.set_run_storage_path("user://roar-01-run.save")
	Settings.set_storage_path("user://roar-01-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	settings["combat_speed"] = "normal"
	settings["reduced_motion"] = Proof.value("reduced", "0") == "1"
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.size = Proof.SCREEN
	root.content_scale_size = Proof.SCREEN
	scene = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var options: Dictionary = {"dragon_id": dragon_id, "dragon_depth": 24 if dragon_id == "noctyrax" else 4, "dragon_case": "pre_battle", "seed": SEED}
	var seed: int = Dragon.seed_for_options(options)
	options["seed"] = seed
	var engine := Run.new()
	var run: Dictionary = Dragon.build(engine, Combat.new(), engine.create_new_run(seed, Store.default_data()), options)
	var travel: Vector2i = Vector2i.DOWN if Proof.value("entry", "west") == "north" else Vector2i.RIGHT
	run["pre_battle_travel_dir"] = travel
	run["current_room_layout"] = engine._display_layout_for_room(seed, engine.room_metadata(run, run["current_room"]), travel)
	scene.call("_load_run_state", run)
	await create_timer(0.5).timeout
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	scene.call("_close_large_map")
	await create_timer(0.3).timeout
	scene.call("_sync_pre_battle_preview_after_refresh")
	scene.call("_ensure_sfx_bank")
	(scene.get("_sfx_bank") as Object).connect("cue_requested", _cue)
	await create_timer(PREVIEW_SECONDS if capture else 0.1).timeout
	if capture: Input.warp_mouse(Vector2(110, 520))
	print("POL27 CLIP START_FRAME=%d mode=%s" % [Engine.get_frames_drawn(), str((scene.get("_run_state") as Dictionary).get("mode", ""))])
	await create_timer(1.2 if capture else 0.1).timeout
	scene.call("_on_pre_battle_start_pressed")
	var board: Node = scene.get("board_view")
	var saw_roar: bool = false
	var elapsed_usec: int = Time.get_ticks_usec()
	var frames: int = 0
	var elapsed_game_seconds: float = 0.0
	var recovery_saved: bool = false
	while bool(scene.get("_animation_lock")) and frames < FRAME_LIMIT:
		await process_frame
		frames += 1
		elapsed_game_seconds += scene.get_process_delta_time()
		var state: Dictionary = scene.get("_combat_state")
		var enemy: Dictionary = preload("res://scripts/dragon_arrival.gd").dragon(state)
		if enemy.is_empty(): continue
		var snapshot: Dictionary = board.call(dragon_id + "_animation_snapshot", "enemy_%d" % int(enemy["id"]))
		if snapshot.is_empty(): continue
		records.append({"elapsed_game_seconds": elapsed_game_seconds, "elapsed_usec": Time.get_ticks_usec() - elapsed_usec, "snapshot": snapshot})
		if snapshot["clip"] == "roar":
			saw_roar = true
			_check(snapshot["facing"] == "front", "Every real opening frame uses front")
			var player: Vector2i = state["player"]["pos"]
			var origin: Vector2i = enemy["pos"]
			_check(bool(snapshot["mirrored"]) == (player.x - player.y >= origin.x - origin.y), "Real opening mirror faces hero screen side")
			if float(snapshot["phase"]) >= 0.27 and not peak_saved:
				peak_saved = true
				if capture: await _capture("roar_peak")
		elif saw_roar and not recovery_saved:
			recovery_saved = true
			var expected: Dictionary = Facing.direction_for_delta(state["player"]["pos"] * 2 - (enemy["pos"] * 2 + Vector2i.ONE))
			_check(snapshot["facing"] == expected["facing"] and snapshot["mirrored"] == expected["mirrored"], "Real opening restores ordinary hero-facing idle")
			if capture: await _capture("idle_after")
	_check(frames < FRAME_LIMIT and saw_roar and recovery_saved and peak_saved, "Real opening completes and shows roar/recovery")
	_check(cues.count("dragon.roar") == 1, "One real arrival cue")
	if capture: await create_timer(TAIL_SECONDS).timeout
	print("POL27 CLIP END_FRAME=%d" % Engine.get_frames_drawn())
	var file := FileAccess.open(output.path_join("opening.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"dragon": dragon_id, "entry": Proof.value("entry", "west"), "source_art": OS.get_environment("LABYRINTH_CEL_LOOK"), "size": [1920, 1080], "ui_scale": 1.0, "cues": cues, "frames": records, "errors": failures}, "\t"))
	file.close()
	for failure: String in failures: push_error(failure)
	print(output)
	print("ROAR REAL OPENING %s: %s" % [dragon_id, "PASS" if failures.is_empty() else "FAIL"])
	quit(0 if failures.is_empty() else 1)

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = normalize_capture(root.get_texture().get_image())
	_check(image.get_size() == Proof.SCREEN, "Saved game capture is 1920x1080")
	_check(image.save_png(output.path_join(dragon_id + "_" + label + ".png")) == OK, "Save real opening capture")

func _check(ok: bool, message: String) -> void:
	if not ok and not failures.has(message): failures.append(message)

static func normalize_capture(image: Image) -> Image:
	# macOS returns Retina backing pixels rather than the logical window size.
	if image.get_size() != Proof.SCREEN:
		image.resize(Proof.SCREEN.x, Proof.SCREEN.y, Image.INTERPOLATE_LANCZOS)
	return image
