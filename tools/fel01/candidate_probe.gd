extends "res://tools/fel01/resume_probe.gd"
## Screen retained hunt saves with the same Continue and capture phases as native.sh.

const Paths = preload("res://scripts/path_utils.gd")

var _composition: Dictionary = {}
var _failure: String = ""
var _resume_failed: bool = false


func _run() -> void:
	var candidates: String = OS.get_environment("FEL01_CANDIDATES")
	var names: PackedStringArray = DirAccess.get_directories_at(candidates)
	if not _dry or DisplayServer.get_name() != "headless" or names.is_empty():
		printerr("FEL01 candidate probe requires a headless dry run and FEL01_CANDIDATES")
		quit(1)
		return
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.set_storage_path("user://fel01_capture_settings.json")
	if not Settings.save_settings(settings):
		quit(1)
		return

	var accepted: int = 0
	names.sort()
	for name: String in names:
		_composition = {}
		_failure = ""
		var source: String = candidates.path_join(name)
		var eligible: bool = await _fixture(source)
		if _resume_failed:
			quit(1)
			return
		if is_instance_valid(_viewport) and not _viewport.is_queued_for_deletion():
			_viewport.queue_free()
			await process_frame
		var evidence: Dictionary = {
			"source": source, "eligible": eligible,
			"composition": _composition, "failure": _failure,
		}
		print("FEL01 CANDIDATE ", JSON.stringify(evidence))
		accepted += int(eligible)
	print("FEL01 SCREEN PASS candidates=%d eligible=%d" % [names.size(), accepted])
	quit()


func _capture_phases(scene: Node, id: String, tile: Vector2i) -> bool:
	var centering: Tween = scene.get("_board_centering_tween")
	while centering != null and centering.is_running():
		await process_frame
		centering = scene.get("_board_centering_tween")
	var board: Control = scene.get("board_view")
	var silhouettes: Node = board.get("_occlusion_silhouettes")
	var pillars: Dictionary = {}
	for source: Dictionary in silhouettes.current_sources():
		if source.get("prop_kind") == "pillar": pillars[source["tile"]] = true
	var combat: Dictionary = scene.get("_combat_state")
	var enemies: int = 0
	for enemy: Dictionary in combat.get("enemies", []):
		if int(enemy.get("hp", 0)) > 0 and Paths.is_in_bounds(combat["grid"], enemy.get("pos", Vector2i(-1, -1))):
			enemies += 1
	var run: Dictionary = scene.get("_run_state")
	var room: Dictionary = scene.get("_run_engine").room_metadata(run, run["current_room"])
	var boss_id: String = ""
	match str(room.get("type", "")):
		"boss": boss_id = str(room.get("boss_id", ""))
		"guardian": boss_id = str(room.get("guardian_id", ""))
	_composition = {"enemies_on_board": enemies, "visible_pillars": pillars.size(), "boss_id": boss_id}
	return await super._capture_phases(scene, id, tile)


func _fail(message: String) -> bool:
	_failure = message
	_resume_failed = message.contains("production Continue") or message.begins_with("cannot stage")
	if _resume_failed: printerr("FEL01 RESUME/CAPTURE FAIL " + message)
	return false
