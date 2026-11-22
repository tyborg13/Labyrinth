extends SceneTree

const Assets = preload("res://scripts/asset_loader.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const SectionArt = preload("res://scripts/run_section_art.gd")
const CACHE_TIMEOUT_MSEC: int = 5000


class RunOwner extends Node:
	var _run_state: Dictionary = {
		"section_map_version": Graph.VERSION,
		"current_room": Vector2i.ZERO,
		"rooms": {"0,0": {"section_index": 1}},
		"map_sections": [{"boss_id": "tharokh"}, {}],
	}


class HistoryErrorLog extends Logger:
	var errors := PackedStringArray()

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var message: String = "%s %s" % [code, rationale]
		if message.contains("Error calling deferred method:") and message.contains("::prepare_history_for"):
			errors.append(message.strip_edges())


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	await process_frame
	var errors := HistoryErrorLog.new()
	OS.add_logger(errors)

	var owner := RunOwner.new()
	var map := Control.new()
	root.add_child(owner)
	root.add_child(map)
	SectionArt.prepare_history_for.call_deferred(owner, map)
	owner.free()
	await process_frame
	var freed_owner_errors: PackedStringArray = errors.errors.duplicate()
	errors.errors.clear()

	owner = RunOwner.new()
	root.add_child(owner)
	SectionArt.prepare_history_for.call_deferred(owner, map)
	map.free()
	await process_frame
	var freed_map_errors: PackedStringArray = errors.errors.duplicate()
	OS.remove_logger(errors)

	map = Control.new()
	owner.add_child(map)
	var path: String = SectionArt.background_path(Graph.section(owner._run_state, 0))
	Assets.release_cached_texture_families(PackedStringArray([path]))
	SectionArt.prepare_history_for.call_deferred(owner, map)
	var deadline_msec: int = Time.get_ticks_msec() + CACHE_TIMEOUT_MSEC
	while not Assets.has_cached_texture(path) and Time.get_ticks_msec() < deadline_msec:
		await process_frame
	var cached: bool = Assets.has_cached_texture(path)
	owner.queue_free()
	await process_frame

	print("SECTION HISTORY: freed owner errors=%d, freed map errors=%d, live map painting cached=%s" % [
		freed_owner_errors.size(), freed_map_errors.size(), str(cached),
	])
	var passed: bool = freed_owner_errors.is_empty() and freed_map_errors.is_empty() and cached
	print("TEST RESULT: %s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
