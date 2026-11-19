extends SceneTree

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Fixtures = preload("res://tests/suites/en03_enemies_suite.gd")
const SIZE := Vector2i(1920, 1080)
const BOOT_SEED: int = 1792274653 # Reuse the deterministic EN06 boot.
const HERO_TILE := Vector2i(4, 4)
const WISP_TILE := Vector2i(5, 4)
const WISP_ID: int = 1
const SETTLE_FRAMES: int = 12
const LEAD_FRAMES: int = 12
const CLIP_FRAMES: int = 120 # Four seconds at the wrapper's fixed 30 fps.
const OUTPUT_DIR: String = "user://sfx06/1920x1080_ui100"
const IMPACT: String = "spell.lightning"
const PROOF_MUSIC_VOLUME: float = 0.0
const LENGTH_TOLERANCE_SECONDS: float = 0.001
const EXPECTED_LENGTHS: Dictionary = {
	"res://assets/audio/sfx/cues/spell.lightning/spell.lightning_01.ogg": 0.55,
	"res://assets/audio/sfx/elemental/lightning_attack.wav": 0.55,
	"res://assets/audio/sfx/cues/status.shock/status.shock_01.ogg": 0.32,
	"res://assets/audio/sfx/cues/surface.electric/surface.electric_01.ogg": 0.40,
}

var _validate_only: bool = false
var _capture_saved: bool = false
var _events: Array[Dictionary]


func _initialize() -> void:
	Runtime.apply_from_environment()
	_validate_only = OS.get_cmdline_user_args().has("--validate-only")
	call_deferred("_run")


func _run() -> void:
	if not _validate_only and DisplayServer.get_name().to_lower() == "headless":
		_fail("Native Wisp proof requires a windowed renderer")
		return
	for path: String in EXPECTED_LENGTHS:
		var stream: AudioStream = Assets.load_audio_stream(path)
		var loops: bool = (stream is AudioStreamOggVorbis and stream.loop) or (stream is AudioStreamWAV and stream.loop_mode != AudioStreamWAV.LOOP_DISABLED)
		if stream == null or absf(stream.get_length() - float(EXPECTED_LENGTHS[path])) > LENGTH_TOLERANCE_SECONDS or loops:
			_fail("Runtime stream duration or loop flag differs: " + path)
			return
		print("SFX06 STREAM %s %.3fs loop=false" % [path.get_file(), stream.get_length()])

	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	Settings.set_storage_path("user://sfx06/settings.json")
	Store.set_storage_path("user://sfx06/progression.json")
	Store.set_run_storage_path("user://sfx06/proof.save")
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	settings["music_volume"] = PROOF_MUSIC_VOLUME
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.set_meta("labyrinth_performance_probe_seed", BOOT_SEED)
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	root.remove_meta("labyrinth_performance_probe_seed")
	await _frames(SETTLE_FRAMES)
	scene._close_dialogue()
	var wisp: Dictionary = Fixtures.enemy("lightning_wisp", WISP_ID, WISP_TILE, "static_lash")
	var before: Dictionary = Fixtures.state([wisp], HERO_TILE, "lightning")
	Fixtures.install(scene, before)
	scene._close_dialogue()
	await _frames(SETTLE_FRAMES)

	var bank: Node = scene.get("_sfx_bank")
	bank.stop_loop(true)
	bank.cue_requested.connect(_on_cue)
	var safe_start: int = Engine.get_frames_drawn()
	print("SFX06_SAFE_START_FRAME=%d" % safe_start)
	await _frames(LEAD_FRAMES)

	var engine: RefCounted = scene.get("_combat_engine")
	var result: Dictionary = engine.resolve_enemy_turn_with_steps(before, 0)
	var animated: Dictionary = before.duplicate(true)
	await scene._animate_enemy_phase_steps(animated, result["steps"], result["state"])
	var damage: int = int(before["player"]["hp"]) - int(animated["player"]["hp"])
	var impact_played: bool = _events.any(func(event: Dictionary) -> bool: return event["cue"] == IMPACT and event["result"] == "played")
	if damage <= 0 or not impact_played:
		_fail("Static Lash must damage the hero and play the lightning variant")
		return

	if not _validate_only:
		while Engine.get_frames_drawn() < safe_start + CLIP_FRAMES + 1: await process_frame
		if not _capture_saved:
			_fail("Lightning impact screenshot was not written")
			return

	var trace := FileAccess.open(OUTPUT_DIR.path_join("cue-events.json"), FileAccess.WRITE)
	trace.store_string(JSON.stringify({"hero_damage_fixed_point": damage, "events": _events}, "\t"))
	print("SFX06 PROOF DIR: " + ProjectSettings.globalize_path(OUTPUT_DIR))
	print("SFX06 WISP PROBE RESULT: PASS (hero damage fixed-point=%d, lightning played=true, validate_only=%s)" % [damage, _validate_only])
	scene.queue_free()
	await process_frame
	quit()


func _on_cue(cue: String, result: String) -> void:
	_events.append({"cue": cue, "result": result, "frame": Engine.get_process_frames()})
	if not _validate_only and cue == IMPACT and result == "played":
		_save_impact.call_deferred()


func _save_impact() -> void:
	await RenderingServer.frame_post_draw
	_capture_saved = root.get_texture().get_image().save_png(OUTPUT_DIR.path_join("wisp-impact.png")) == OK


func _frames(count: int) -> void:
	for frame: int in range(count): await process_frame


func _fail(message: String) -> void:
	push_error(message)
	print("SFX06 WISP PROBE RESULT: FAIL")
	quit(1)
