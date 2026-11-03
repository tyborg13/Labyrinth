extends "res://tests/fix18/real_fight_capture_probe.gd"

## Reuse the real persisted Continue boot, camera and root readback contract.
## --scenario warband --warband-biome fire --warband-tier 2 --seed 83
## Output uses LABYRINTH_REAL_FIGHT_CAPTURE_OUTPUT, as the parent probe does.
const ROUNDS: int = 3
const RETREAT_REPETITIONS: int = 3
const RECORD_FPS: float = 30.0
const PROOF_PLAYER_HP: int = 1000
var recording: bool = false
var record_rows: Array[Dictionary]
var record_origin_usec: int
var record_stage: String = ""

func _parse_capture_args(_args: PackedStringArray) -> Dictionary:
	_capture_label = "rr46_fire_fight"
	_validate_only = OS.get_environment("LABYRINTH_RR46_VALIDATE_ONLY") == "1"
	var parsed: Dictionary = _parse_args()
	parsed["player_hp"] = PROOF_PLAYER_HP
	parsed["player_max_hp"] = PROOF_PLAYER_HP
	return parsed

func _build_run_state(_scenario: String, progression: Dictionary) -> Dictionary:
	return super._build_run_state("warband",progression)

func _sample_frames() -> void:
	await super._sample_frames()
	# Validation proves the persisted fixture and Continue boot only. Full FX
	# playback belongs to the native run; the headless clock/path tests cover
	# schedules separately and never wait for a renderer-dependent fight.
	if _validate_only: return
	record_origin_usec = Time.get_ticks_usec()
	if not _validate_only:
		recording = true
		_record()
	# Normal player Pass input, live resolver, live presentation and unchanged AI.
	record_stage = "real_fight"
	for _round: int in range(ROUNDS):
		await _capture_scene._on_pass_turn_pressed()
		if str(_capture_scene._run_state.get("mode","")) != "combat": break
	# Isolate the reported retreat and collapse after the real rounds. These
	# are explicitly staged fixture actions, using the real Warband board and
	# resolver-produced keep_distance routes; they are labelled in the record.
	record_stage = "staged_keep_distance"
	for _repeat: int in range(RETREAT_REPETITIONS):
		var battle: Dictionary = _capture_scene._combat_state.duplicate(true)
		if not preload("res://tools/warband_inspection.gd").stage_keep_distance(battle): break
		var captain: Dictionary = battle["enemies"][0]
		var path: Array[Vector2i] = preload("res://scripts/warband_combat_rules.gd").retreat_path(_combat_engine,battle,captain)
		if path.size()<2: break
		_capture_scene._combat_state = battle
		_capture_scene._run_state["combat_state"] = battle
		_capture_scene._animation_lock = true
		_capture_scene._combat_pacing.begin_enemies()
		await _capture_scene._animate_move_step(battle,{"kind":"move","actor_key":"enemy_%d"%int(captain["id"]),"from":path[0],"to":path[-1],"path":path,"label":"Retreat"})
		_capture_scene._combat_pacing.end_scope()
		_capture_scene._animation_lock = false
	record_stage = "staged_death"
	var before: Dictionary = _capture_scene._combat_state.duplicate(true)
	if not before.get("enemies",[]).is_empty():
		before["enemies"][0]["block"] = 0
		before["enemies"][0]["stoneskin"] = 0
		var after: Dictionary = _combat_engine._damage_enemy(before.duplicate(true),0,int(before["enemies"][0]["hp"]),false,true)
		_capture_scene._animation_lock = true
		_capture_scene._combat_pacing.begin_card()
		await _capture_scene._animate_defeats_and_terrain_destruction(before,after)
		_capture_scene._combat_pacing.end_scope()
		_capture_scene._animation_lock = false
	recording = false
	await process_frame
	_manifest["rr46_recording"] = {"native":not _validate_only,"frames":record_rows,"fps_limit":RECORD_FPS,"rounds":ROUNDS,"staged_retreat_repetitions":RETREAT_REPETITIONS,"proof_player_hp":PROOF_PLAYER_HP}
	_write_recording_manifest()

func _write_recording_manifest() -> void:
	FileAccess.open(_capture_output.path_join("recording.json"),FileAccess.WRITE).store_string(JSON.stringify(_manifest["rr46_recording"],"\t"))
	# The runner recursively discovers PNGs in announced directories. Recording
	# frames live outside user:// when OUTPUT_ENV is set; the final still alone
	# cannot satisfy the unchanged three-image/recording-frame proof contract.
	print(ProjectSettings.globalize_path(_capture_output))

func _record() -> void:
	var last: int = -1
	while recording:
		await RenderingServer.frame_post_draw
		if not recording: break
		var elapsed: int = Time.get_ticks_usec()-record_origin_usec
		if elapsed-last < 1000000.0/RECORD_FPS: continue
		last = elapsed
		var filename: String = "fight_%06d.png"%record_rows.size()
		root.get_texture().get_image().save_png(_capture_output.path_join(filename))
		var shown: Dictionary = _capture_board.presentation
		record_rows.append({"file":filename,"elapsed_seconds":elapsed/1000000.0,"stage":record_stage,"motion":shown.get("slag_mortar_motion",{}),"death_units":shown.get("death_animation_units",[]),"draw_tiles":shown.get("unit_draw_tiles",{})})
