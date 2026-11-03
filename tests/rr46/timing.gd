extends SceneTree

const ClockScene = preload("clock_scene.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Death = preload("res://scripts/maquette_cutout_runtime/death.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Context = preload("res://scripts/cutout_context.gd")
const Fixture = preload("res://tests/maquette_cutout/runtime_suite.gd")
const PlaybackTiming = preload("res://scripts/maquette_cutout_runtime/playback_timing.gd")
const TYPES := ["hoarfrost_seer", "arc_thrall", "glacial_mirror", "briar_weaver", "hollow_mimic", "slag_mortar", "gale_herald", "gloam_stalker", "frostglass_lancer", "chainbound_gaoler"]
const OLDER := ["ash_hound", "ember_tick", "cinder_ooze"]
const SPEEDS := ["normal", "fast", "fastest"]
const PROOF_SIZE := Vector2(1920, 1080)
const FRAME_TOLERANCE_SECONDS: float = 1.0 / 60.0
const CLOCK_SAMPLE_USEC: int = 100000
var errors: Array[String]

class ClockOwner extends Node:
	var _settings: Dictionary = {}
	var _animation_lock: bool = true
	var _drag_card_index: int = -1
	var _run_state: Dictionary = {"mode":"combat"}
	func _controller_modal_visible() -> bool: return false

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var measure_only: bool = args.has("--measure-only")
	var output: String = args[args.find("--output") + 1] if args.has("--output") else "user://rr46/timing.json"
	var board := Board.new()
	board.size = PROOF_SIZE
	var scene := ClockScene.new()
	scene.board_view = board
	scene._combat_pacing.enemies_active = true
	var counts: Array[int]
	counts.assign([8])
	var legacy_move: float = 8 * roundi(scene._combat_pacing.walk_frame_seconds("enemy_1", counts, scene.MOVE_FRAME_SECONDS) * 1000000.0) / 1000000.0
	var legacy_death: float = Board.ENEMY_SHADOW_DISSOLVE_FRAME_COUNT * Board.ENEMY_SHADOW_DISSOLVE_FRAME_SECONDS
	var rows: Array[Dictionary]
	for type: String in OLDER + TYPES:
		var state: Dictionary = Fixture.fixture(type)
		var unit: Dictionary = state["enemies"][0].duplicate(true)
		unit.merge({"key": "enemy_1", "role": "enemy", "death_animation": true}, true)
		var path: Array[Vector2i]
		path.assign([unit["pos"], unit["pos"] + Vector2i.RIGHT, unit["pos"] + Vector2i.RIGHT * 2])
		scene.scheduled.clear()
		scene.submissions.clear()
		await scene._animate_actor_along_path(state, "enemy_1", path, {})
		var move: float = float(scene.scheduled[0]["seconds"]) / (path.size() - 1)
		var death: float = scene._enemy_death_frame_count_for_unit(unit) * scene._enemy_death_frame_seconds_for_unit(unit)
		var data: Dictionary = Action.data_for(type)
		# walk-01 compiles the leg-reach step count into one tile's move clip.
		# Its frame clock is clip seconds / frames per tile, so the scheduled
		# path seconds / path tile count must equal that authored clip duration.
		var authored_tile_clock: bool = PlaybackTiming.AUTHORED_HUMANOID_TILE_TYPES.has(type)
		var expected_move: float = float(data["clips"]["move"]["seconds"]) if authored_tile_clock else legacy_move
		var attacks: Dictionary = preload("attack_timings.gd").measure(type)
		for speed: String in SPEEDS:
			var scale: float = Settings.combat_speed_scale({"combat_speed": speed})
			var attack_scale: float = scale * scene._combat_pacing.ENEMY_ACTION_SPEED_SCALE
			var attack_rows: Dictionary = attacks.duplicate(true)
			for clip: String in attack_rows:
				attack_rows[clip]["clip_seconds"] /= attack_scale
				attack_rows[clip]["contact_seconds"] /= attack_scale
			var row: Dictionary = {"type": type, "speed": speed, "scale": scale, "move_seconds": move / scale,
				"death_seconds": death / scale, "death_in_enemy_action_seconds": death / attack_scale,
				"hit_seconds": (Action.seconds_for(type, "hit") if Action.handles(type) else Context.HIT_SECONDS) / scale,
				"attacks": attack_rows, "movement_frames_two_tiles": scene.scheduled[0]["frames"]}
			if TYPES.has(type):
				row["death_clip_seconds"] = Death.clip_seconds(type) / scale
				row["death_fade_seconds"] = Death.dissolve_seconds(type) / scale
				row["move_duration_scale"] = move / float(data["clips"]["move"]["seconds"])
				row["death_duration_scale"] = Death.clip_seconds(type) / float(data["clips"]["death"]["seconds"])
				if not measure_only:
					check(absf(move / scale - expected_move / scale) <= FRAME_TOLERANCE_SECONDS, type + "/" + speed + (": authored humanoid tile clock" if authored_tile_clock else ": move parity"))
					check(absf(death / scale - (float(data["clips"]["death"]["seconds"]) * Death.HUMANOID_DEATH_CLIP_RATE + Death.HUMANOID_DISSOLVE_SECONDS) / scale) <= FRAME_TOLERANCE_SECONDS, type + "/" + speed + ": full humanoid fall then dissolve")
			rows.append(row)
	if not measure_only: _check_speed_clock(scene)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"rows": rows, "legacy_move_seconds": legacy_move, "legacy_death_seconds": legacy_death, "errors": errors}, "\t"))
	scene.board_view = null
	scene._combat_pacing.free()
	scene.free()
	board.free()
	for error: String in errors: printerr(error)
	print("RR46 TIMING: %s (%d actor/speed rows; production path schedule)" % ["PASS" if errors.is_empty() else "FAIL", rows.size()])
	quit(0 if errors.is_empty() else 1)

func check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)

func _check_speed_clock(scene: Node) -> void:
	var owner := ClockOwner.new()
	root.add_child(owner)
	var pacing: Node = preload("res://scripts/combat_pacing.gd").new()
	pacing.install(owner)
	for speed: String in SPEEDS:
		owner._settings = {"combat_speed":speed}
		pacing.begin_enemies()
		check(is_equal_approx(Engine.time_scale, Settings.combat_speed_scale(owner._settings)), speed+": movement/death speed reaches Engine clock")
		pacing._set_enemy_action_active(true)
		var scale: float = Settings.combat_speed_scale(owner._settings)*pacing.ENEMY_ACTION_SPEED_SCALE
		check(is_equal_approx(Engine.time_scale,scale), speed+": attack/hit speed reaches Engine clock")
		var started: int = pacing.presentation_usec()
		pacing._last_clock_usec -= CLOCK_SAMPLE_USEC
		var elapsed: float = (pacing.presentation_usec()-started)/1000000.0
		check(absf(elapsed-0.1*scale)<FRAME_TOLERANCE_SECONDS, speed+": timed clips consume scaled clock")
		pacing.end_scope()
	owner.remove_child(pacing)
	pacing.free()
	owner.free()
