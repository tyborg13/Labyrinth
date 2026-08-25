extends Node
class_name PerformanceTelemetrySampler

const SCHEMA_VERSION: int = 1
const DEFAULT_STORAGE_DIR: String = "user://telemetry"
const DEFAULT_FLUSH_INTERVAL_SECONDS: float = 60.0
const RENDER_SAMPLE_INTERVAL_FRAMES: int = 10
const MAX_FRAME_SAMPLES: int = 7200
const META_FILE_NAME: String = "meta.json"
const ENDPOINT_ENV: String = "LABYRINTH_TELEMETRY_ENDPOINT"
const TOKEN_ENV: String = "LABYRINTH_TELEMETRY_TOKEN"
const STEAM_STATS_SCHEMA_VERSION: int = 1
const STEAM_COHORT_THRESHOLDS_MS: Array[float] = [20.0, 33.33, 50.0]

var _storage_dir: String = DEFAULT_STORAGE_DIR
var _frame_samples_ms: Array[float] = []
var _frames_over_16_67_ms: int = 0
var _frames_over_20_ms: int = 0
var _frames_over_33_33_ms: int = 0
var _frames_over_50_ms: int = 0
var _frame_index: int = 0
var _elapsed_since_flush: float = 0.0
var _render_sample_count: int = 0
var _draw_calls_total: float = 0.0
var _draw_calls_max: float = 0.0
var _objects_total: float = 0.0
var _objects_max: float = 0.0
var _primitives_total: float = 0.0
var _primitives_max: float = 0.0
var _process_ms_total: float = 0.0
var _process_ms_max: float = 0.0
var _gameplay_context: Dictionary = {}
var _gameplay_context_signature: int = 0
var _active_frame_cohorts: Array[String] = ["frontend"]
var _cohort_frame_windows: Dictionary = {}
var _session_id: String = ""
var _install_id: String = ""
var _sequence: int = 0
var _http_request: HTTPRequest
var _last_summary: Dictionary = {}
var _last_upload_status: Dictionary = {}
var _last_steam_stats_status: Dictionary = {}
var _sampling_enabled: bool = true
var _steam_session_recorded: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_install_id = _ensure_installation_id()
	_session_id = _random_id("perf_session")
	_sampling_enabled = bool(ProjectSettings.get_setting("telemetry/performance/local_enabled", true))
	_http_request = HTTPRequest.new()
	_http_request.name = "PerformanceTelemetryUpload"
	_http_request.request_completed.connect(_on_upload_completed)
	add_child(_http_request)
	set_process(_sampling_enabled)

func _process(delta: float) -> void:
	if not _sampling_enabled:
		return
	_sample_frame(delta * 1000.0)
	_elapsed_since_flush += delta
	var flush_interval: float = maxf(
		10.0,
		float(ProjectSettings.get_setting("telemetry/performance/flush_interval_seconds", DEFAULT_FLUSH_INTERVAL_SECONDS))
	)
	if _elapsed_since_flush >= flush_interval or _frame_samples_ms.size() >= MAX_FRAME_SAMPLES:
		flush_now("interval")

func _exit_tree() -> void:
	if not _frame_samples_ms.is_empty():
		flush_now("shutdown")

func set_gameplay_context(context: Dictionary) -> void:
	var sanitized: Dictionary = _sanitize_dictionary(context)
	var signature: int = hash(sanitized)
	if signature == _gameplay_context_signature:
		return
	_gameplay_context = sanitized
	_gameplay_context_signature = signature
	_active_frame_cohorts = _frame_cohorts_for_context(sanitized)

func flush_now(reason: String = "manual") -> Dictionary:
	if _frame_samples_ms.is_empty():
		return {}
	_sequence += 1
	var summary: Dictionary = _build_summary(reason)
	_append_jsonl(summary)
	_last_summary = summary.duplicate(true)
	_submit_steam_aggregates(summary, reason)
	_try_upload_summary(summary)
	_reset_window()
	return summary

func storage_dir() -> String:
	return _storage_dir

func current_file_path() -> String:
	return ProjectSettings.globalize_path(_storage_dir).path_join("performance-%s.jsonl" % _utc_date_string())

func last_summary() -> Dictionary:
	return _last_summary.duplicate(true)

func last_upload_status() -> Dictionary:
	return _last_upload_status.duplicate(true)

func last_steam_stats_status() -> Dictionary:
	return _last_steam_stats_status.duplicate(true)

func set_storage_dir_for_test(path: String) -> void:
	_storage_dir = path if not path.is_empty() else DEFAULT_STORAGE_DIR

func sample_frame_for_test(frame_ms: float, render_metrics: Dictionary = {}) -> void:
	_sample_frame(frame_ms, render_metrics)

func steam_metric_prefix_for_test(os_name: String, steam_deck: bool) -> String:
	return _steam_metric_prefix(os_name, steam_deck)

func steam_metric_deltas_for_test(summary: Dictionary, os_name: String, steam_deck: bool, include_session: bool = true) -> Dictionary:
	return _steam_metric_deltas(summary, _steam_metric_prefix(os_name, steam_deck), include_session)

func frame_cohorts_for_test(context: Dictionary) -> Array[String]:
	return _frame_cohorts_for_context(context)

func _sample_frame(frame_ms: float, render_metrics: Dictionary = {}) -> void:
	if frame_ms <= 0.0 or frame_ms > 2000.0:
		return
	_frame_samples_ms.append(frame_ms)
	_frames_over_16_67_ms += 1 if frame_ms > 16.67 else 0
	_frames_over_20_ms += 1 if frame_ms > 20.0 else 0
	_frames_over_33_33_ms += 1 if frame_ms > 33.33 else 0
	_frames_over_50_ms += 1 if frame_ms > 50.0 else 0
	_sample_active_cohorts(frame_ms)
	_frame_index += 1
	if render_metrics.is_empty() and _frame_index % RENDER_SAMPLE_INTERVAL_FRAMES != 0:
		return
	var draw_calls: float = float(render_metrics.get(
		"draw_calls",
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	))
	var objects: float = float(render_metrics.get(
		"objects",
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	))
	var primitives: float = float(render_metrics.get(
		"primitives",
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	))
	var process_ms: float = float(render_metrics.get(
		"process_ms",
		float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	))
	_render_sample_count += 1
	_draw_calls_total += draw_calls
	_draw_calls_max = maxf(_draw_calls_max, draw_calls)
	_objects_total += objects
	_objects_max = maxf(_objects_max, objects)
	_primitives_total += primitives
	_primitives_max = maxf(_primitives_max, primitives)
	_process_ms_total += process_ms
	_process_ms_max = maxf(_process_ms_max, process_ms)

func _build_summary(reason: String) -> Dictionary:
	var stats: Dictionary = _stats(_frame_samples_ms)
	var render_divisor: float = maxf(1.0, float(_render_sample_count))
	return {
		"schema_version": SCHEMA_VERSION,
		"event_type": "performance_window",
		"timestamp_utc": _timestamp_utc_iso(),
		"install_id": _install_id,
		"session_id": _session_id,
		"sequence": _sequence,
		"reason": reason,
		"window_seconds": _elapsed_since_flush,
		"frame_interval_ms": stats,
		"frames_over_16_67_ms": _frames_over_16_67_ms,
		"frames_over_20_ms": _frames_over_20_ms,
		"frames_over_33_33_ms": _frames_over_33_33_ms,
		"frames_over_50_ms": _frames_over_50_ms,
		"render": {
			"sample_count": _render_sample_count,
			"draw_calls_mean": _draw_calls_total / render_divisor,
			"draw_calls_max": _draw_calls_max,
			"objects_mean": _objects_total / render_divisor,
			"objects_max": _objects_max,
			"primitives_mean": _primitives_total / render_divisor,
			"primitives_max": _primitives_max,
			"process_ms_mean": _process_ms_total / render_divisor,
			"process_ms_max": _process_ms_max,
		},
		"memory": {
			"static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
			"object_count": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
			"node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			"orphan_node_count": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		},
		"frame_cohorts": _cohort_summaries(),
		"sections": _consume_runtime_performance_sections(),
		"context": _gameplay_context.duplicate(true),
		"device": _device_context(),
	}

func _stats(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {"sample_count": 0, "mean": 0.0, "median": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0}
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var total: float = 0.0
	for value: float in sorted:
		total += value
	return {
		"sample_count": sorted.size(),
		"mean": total / float(sorted.size()),
		"median": _percentile(sorted, 0.50),
		"p95": _percentile(sorted, 0.95),
		"p99": _percentile(sorted, 0.99),
		"max": sorted[sorted.size() - 1],
	}

func _percentile(sorted: Array[float], percentile: float) -> float:
	if sorted.is_empty():
		return 0.0
	var index: int = clampi(int(ceil(percentile * float(sorted.size()))) - 1, 0, sorted.size() - 1)
	return sorted[index]

func _device_context() -> Dictionary:
	var viewport_size := Vector2i.ZERO
	if is_inside_tree() and get_viewport() != null:
		viewport_size = Vector2i(get_viewport().get_visible_rect().size)
	return {
		"os": OS.get_name(),
		"model": OS.get_model_name(),
		"renderer": RenderingServer.get_video_adapter_name(),
		"rendering_method": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
		"viewport": "%dx%d" % [viewport_size.x, viewport_size.y],
		"steam_deck": _is_steam_deck(),
		"game_version": str(ProjectSettings.get_setting("application/config/version", "development")),
	}

func _is_steam_deck() -> bool:
	if OS.get_environment("SteamDeck") == "1":
		return true
	if Engine.has_singleton("Steam"):
		var steam_service: Node = get_node_or_null("/root/SteamService")
		if (
			steam_service == null
			or not steam_service.has_method("is_steam_active")
			or not bool(steam_service.call("is_steam_active"))
		):
			return "steam deck" in OS.get_model_name().to_lower()
		var steam: Object = Engine.get_singleton("Steam")
		if steam != null and steam.has_method("isSteamRunningOnSteamDeck"):
			return bool(steam.call("isSteamRunningOnSteamDeck"))
	return "steam deck" in OS.get_model_name().to_lower()

func _append_jsonl(summary: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_storage_dir))
	var file: FileAccess = FileAccess.open(current_file_path(), FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(current_file_path(), FileAccess.WRITE_READ)
	if file == null:
		return false
	file.seek_end()
	file.store_line(JSON.stringify(summary))
	file.flush()
	var succeeded: bool = file.get_error() == OK
	file.close()
	return succeeded

func _try_upload_summary(summary: Dictionary) -> void:
	var endpoint: String = OS.get_environment(ENDPOINT_ENV).strip_edges()
	if endpoint.is_empty():
		endpoint = str(ProjectSettings.get_setting("telemetry/performance/upload_url", "")).strip_edges()
	if endpoint.is_empty() or _http_request == null:
		_last_upload_status = {"attempted": false, "reason": "endpoint_not_configured"}
		return
	if _http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_last_upload_status = {"attempted": false, "reason": "request_in_flight"}
		return
	var headers := PackedStringArray(["Content-Type: application/json", "User-Agent: EscapeTheUmbra/PerformanceTelemetry"])
	var token: String = OS.get_environment(TOKEN_ENV).strip_edges()
	if not token.is_empty():
		headers.append("Authorization: Bearer %s" % token)
	var error: Error = _http_request.request(endpoint, headers, HTTPClient.METHOD_POST, JSON.stringify(summary))
	_last_upload_status = {"attempted": true, "request_error": error}

func _submit_steam_aggregates(summary: Dictionary, reason: String) -> void:
	if not bool(ProjectSettings.get_setting("telemetry/performance/steam_stats_enabled", true)):
		_last_steam_stats_status = {"attempted": false, "reason": "disabled"}
		return
	var steam_service: Node = get_node_or_null("/root/SteamService")
	if (
		steam_service == null
		or not steam_service.has_method("is_steam_active")
		or not bool(steam_service.call("is_steam_active"))
		or not steam_service.has_method("accumulate_int_stats")
	):
		_last_steam_stats_status = {"attempted": false, "reason": "steam_not_active"}
		return
	var prefix: String = _steam_metric_prefix(OS.get_name(), _is_steam_deck())
	var deltas: Dictionary = _steam_metric_deltas(summary, prefix, not _steam_session_recorded)
	var result: Dictionary = steam_service.call("accumulate_int_stats", deltas) as Dictionary
	var accepted: Array = result.get("accepted", []) as Array
	var session_name: String = "%s_sessions" % prefix
	if session_name in accepted:
		_steam_session_recorded = true
	_last_steam_stats_status = result.duplicate(true)
	_last_steam_stats_status["attempted"] = true
	_last_steam_stats_status["prefix"] = prefix
	if reason == "shutdown" and steam_service.has_method("store_pending_stats"):
		_last_steam_stats_status["store"] = steam_service.call("store_pending_stats")

func _steam_metric_deltas(summary: Dictionary, prefix: String, include_session: bool) -> Dictionary:
	var frame_stats: Dictionary = summary.get("frame_interval_ms", {}) as Dictionary
	var render: Dictionary = summary.get("render", {}) as Dictionary
	var memory: Dictionary = summary.get("memory", {}) as Dictionary
	var p95_ms: float = float(frame_stats.get("p95", 0.0))
	var deltas: Dictionary = {
		"%s_windows" % prefix: 1,
		"%s_frame_samples" % prefix: maxi(0, int(frame_stats.get("sample_count", 0))),
		"%s_frames_over_16_67_ms" % prefix: maxi(0, int(summary.get("frames_over_16_67_ms", 0))),
		"%s_frames_over_20_ms" % prefix: maxi(0, int(summary.get("frames_over_20_ms", 0))),
		"%s_frames_over_33_33_ms" % prefix: maxi(0, int(summary.get("frames_over_33_33_ms", 0))),
		"%s_frames_over_50_ms" % prefix: maxi(0, int(summary.get("frames_over_50_ms", 0))),
		"%s_p95_over_20_ms_windows" % prefix: 1 if p95_ms > 20.0 else 0,
		"%s_p95_over_33_33_ms_windows" % prefix: 1 if p95_ms > 33.33 else 0,
		"%s_p95_over_50_ms_windows" % prefix: 1 if p95_ms > 50.0 else 0,
		"%s_render_samples" % prefix: maxi(0, int(render.get("sample_count", 0))),
		"%s_mean_draw_calls_window_sum" % prefix: maxi(0, int(round(float(render.get("draw_calls_mean", 0.0))))),
		"%s_mean_process_tenths_ms_window_sum" % prefix: maxi(0, int(round(float(render.get("process_ms_mean", 0.0)) * 10.0))),
		"%s_static_memory_mb_window_sum" % prefix: maxi(0, int(round(float(memory.get("static_bytes", 0)) / 1048576.0))),
		"%s_orphan_node_windows" % prefix: 1 if int(memory.get("orphan_node_count", 0)) > 0 else 0,
	}
	if include_session:
		deltas["%s_sessions" % prefix] = 1
	_append_steam_cohort_deltas(deltas, prefix, summary.get("frame_cohorts", {}) as Dictionary)
	_append_steam_section_deltas(deltas, prefix, summary.get("sections", {}) as Dictionary)
	for key_var: Variant in deltas.keys():
		if int(deltas[key_var]) <= 0:
			deltas.erase(key_var)
	return deltas

func _steam_metric_prefix(os_name: String, steam_deck: bool) -> String:
	var normalized_os: String = os_name.strip_edges().to_lower()
	var platform: String = "other"
	if normalized_os in ["windows", "win32", "win64"]:
		platform = "windows"
	elif normalized_os in ["macos", "osx", "mac os"]:
		platform = "macos"
	elif normalized_os in ["linux", "freebsd"]:
		platform = "linux"
	var device: String = "steamdeck" if steam_deck and platform == "linux" else "desktop"
	return "perf_v%d_%s_%s" % [STEAM_STATS_SCHEMA_VERSION, platform, device]

func _append_steam_cohort_deltas(deltas: Dictionary, prefix: String, cohorts: Dictionary) -> void:
	for cohort_var: Variant in cohorts.keys():
		var cohort: String = _normalized_metric_component(str(cohort_var))
		var summary: Dictionary = cohorts[cohort_var] as Dictionary
		var frame_stats: Dictionary = summary.get("frame_interval_ms", {}) as Dictionary
		var base: String = "%s_cohort_%s" % [prefix, cohort]
		deltas["%s_samples" % base] = maxi(0, int(frame_stats.get("sample_count", 0)))
		deltas["%s_over_20_ms" % base] = maxi(0, int(summary.get("frames_over_20_ms", 0)))
		deltas["%s_over_33_33_ms" % base] = maxi(0, int(summary.get("frames_over_33_33_ms", 0)))
		deltas["%s_over_50_ms" % base] = maxi(0, int(summary.get("frames_over_50_ms", 0)))

func _append_steam_section_deltas(deltas: Dictionary, prefix: String, sections: Dictionary) -> void:
	var groups: Dictionary = {}
	for phase_var: Variant in sections.keys():
		var phase: String = str(phase_var)
		# Whole-operation totals overlap their detailed phases. Keep them in local
		# JSON, but exclude them from globally summed subsystem time.
		if phase.ends_with("_total"):
			continue
		var section: Dictionary = sections[phase_var] as Dictionary
		var group: String = _section_group_for_phase(phase)
		var aggregate: Dictionary = groups.get(group, {"calls": 0, "total_usec": 0}) as Dictionary
		aggregate["calls"] = int(aggregate.get("calls", 0)) + maxi(0, int(section.get("count", 0)))
		aggregate["total_usec"] = int(aggregate.get("total_usec", 0)) + maxi(0, int(section.get("total_usec", 0)))
		groups[group] = aggregate
	for group_var: Variant in groups.keys():
		var group: String = _normalized_metric_component(str(group_var))
		var aggregate: Dictionary = groups[group_var] as Dictionary
		var base: String = "%s_section_%s" % [prefix, group]
		deltas["%s_calls" % base] = int(aggregate.get("calls", 0))
		deltas["%s_tenths_ms" % base] = int(round(float(aggregate.get("total_usec", 0)) / 100.0))

func _section_group_for_phase(phase: String) -> String:
	if phase.begins_with("engine_player_") or phase.begins_with("engine_player_action"):
		return "engine_player_action"
	if (
		phase.begins_with("engine_move_")
		or phase.begins_with("engine_planned_move")
		or phase.begins_with("engine_prevalidated_move")
		or phase.begins_with("engine_traverse")
	):
		return "engine_movement"
	if phase.begins_with("engine_trap"):
		return "engine_traps"
	if phase.begins_with("engine_"):
		return "engine_other"
	if phase.begins_with("card_preview_") or phase.begins_with("preview_"):
		return "card_preview"
	if phase.begins_with("stage_"):
		return "stage"
	if phase.begins_with("tracker_"):
		return "tracker"
	if phase.begins_with("hand_"):
		return "hand"
	if phase.begins_with("pass_preview_"):
		return "pass_preview"
	if phase.begins_with("hover_"):
		return "hover"
	if phase.begins_with("pile_"):
		return "pile"
	if phase.begins_with("character_"):
		return "character"
	if phase.begins_with("ability_detail_"):
		return "ability_detail"
	if phase.begins_with("shortcut_"):
		return "shortcuts"
	return "scene_other"

func _normalized_metric_component(value: String) -> String:
	var normalized: String = value.strip_edges().to_lower()
	var result: String = ""
	for index: int in range(normalized.length()):
		var code: int = normalized.unicode_at(index)
		result += normalized[index] if (code >= 97 and code <= 122) or (code >= 48 and code <= 57) else "_"
	return result.strip_edges().trim_prefix("_").trim_suffix("_")

func _sample_active_cohorts(frame_ms: float) -> void:
	for cohort: String in _active_frame_cohorts:
		var bucket: Dictionary
		if _cohort_frame_windows.has(cohort):
			bucket = _cohort_frame_windows[cohort] as Dictionary
		else:
			var samples: Array[float] = []
			bucket = {
				"samples": samples,
				"frames_over_20_ms": 0,
				"frames_over_33_33_ms": 0,
				"frames_over_50_ms": 0,
			}
			_cohort_frame_windows[cohort] = bucket
		var samples: Array[float] = bucket.get("samples", []) as Array[float]
		samples.append(frame_ms)
		bucket["frames_over_20_ms"] = int(bucket.get("frames_over_20_ms", 0)) + (1 if frame_ms > STEAM_COHORT_THRESHOLDS_MS[0] else 0)
		bucket["frames_over_33_33_ms"] = int(bucket.get("frames_over_33_33_ms", 0)) + (1 if frame_ms > STEAM_COHORT_THRESHOLDS_MS[1] else 0)
		bucket["frames_over_50_ms"] = int(bucket.get("frames_over_50_ms", 0)) + (1 if frame_ms > STEAM_COHORT_THRESHOLDS_MS[2] else 0)

func _cohort_summaries() -> Dictionary:
	var result: Dictionary = {}
	for cohort_var: Variant in _cohort_frame_windows.keys():
		var bucket: Dictionary = _cohort_frame_windows[cohort_var] as Dictionary
		var samples: Array[float] = bucket.get("samples", []) as Array[float]
		result[str(cohort_var)] = {
			"frame_interval_ms": _stats(samples),
			"frames_over_20_ms": int(bucket.get("frames_over_20_ms", 0)),
			"frames_over_33_33_ms": int(bucket.get("frames_over_33_33_ms", 0)),
			"frames_over_50_ms": int(bucket.get("frames_over_50_ms", 0)),
		}
	return result

func _frame_cohorts_for_context(context: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if bool(context.get("map_open", false)):
		result.append("map")
	elif bool(context.get("character_open", false)):
		var tab: String = str(context.get("character_tab", "equipment"))
		result.append("character_%s" % tab if tab in ["equipment", "magic", "skills"] else "character_other")
	elif bool(context.get("pile_open", false)):
		var pile_kind: String = str(context.get("pile_kind", ""))
		result.append("pile_%s" % pile_kind if pile_kind in ["draw", "discard", "exhaust"] else "pile_other")
	elif bool(context.get("menu_open", false)):
		result.append("menu")
	elif bool(context.get("grimoire_open", false)):
		result.append("grimoire")
	else:
		var mode: String = str(context.get("mode", "frontend"))
		if mode == "combat":
			if bool(context.get("animation_active", false)):
				result.append("combat_animation")
			elif bool(context.get("card_targeting", false)):
				result.append("combat_targeting")
			else:
				result.append("combat_idle")
		elif mode in ["room", "campfire", "treasure", "reward", "victory", "defeat"]:
			result.append(mode)
		else:
			result.append("frontend" if mode.is_empty() else "other")
	var enemy_count: int = maxi(0, int(context.get("living_enemy_count", 0)))
	if str(context.get("mode", "")) == "combat":
		result.append("density_1_2" if enemy_count <= 2 else ("density_3_4" if enemy_count <= 4 else "density_5_plus"))
	var depth: int = maxi(0, int(context.get("room_depth", 0)))
	if depth > 0:
		result.append("depth_1_4" if depth <= 4 else ("depth_5_12" if depth <= 12 else "depth_13_plus"))
	var relic_count: int = maxi(0, int(context.get("relic_count", 0)))
	result.append("relics_0_4" if relic_count <= 4 else ("relics_5_9" if relic_count <= 9 else "relics_10_plus"))
	return result

func _consume_runtime_performance_sections() -> Dictionary:
	if not bool(ProjectSettings.get_setting("telemetry/performance/section_instrumentation_enabled", true)):
		return {}
	if not is_inside_tree() or get_tree().current_scene == null:
		return {}
	var scene: Node = get_tree().current_scene
	if not scene.has_method("consume_runtime_performance_instrumentation_snapshot"):
		return {}
	var result: Variant = scene.call("consume_runtime_performance_instrumentation_snapshot")
	return result as Dictionary if typeof(result) == TYPE_DICTIONARY else {}

func _on_upload_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_last_upload_status = {
		"attempted": true,
		"result": result,
		"response_code": response_code,
		"ok": result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300,
	}

func _reset_window() -> void:
	_frame_samples_ms.clear()
	_frames_over_16_67_ms = 0
	_frames_over_20_ms = 0
	_frames_over_33_33_ms = 0
	_frames_over_50_ms = 0
	_frame_index = 0
	_elapsed_since_flush = 0.0
	_render_sample_count = 0
	_draw_calls_total = 0.0
	_draw_calls_max = 0.0
	_objects_total = 0.0
	_objects_max = 0.0
	_primitives_total = 0.0
	_primitives_max = 0.0
	_process_ms_total = 0.0
	_process_ms_max = 0.0
	_cohort_frame_windows.clear()

func _ensure_installation_id() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_storage_dir))
	var path: String = ProjectSettings.globalize_path(_storage_dir).path_join(META_FILE_NAME)
	if FileAccess.file_exists(path):
		var read_file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if read_file != null:
			var parsed: Variant = JSON.parse_string(read_file.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				var existing: String = str((parsed as Dictionary).get("install_id", ""))
				if not existing.is_empty():
					return existing
	var install_id: String = _random_id("perf_install")
	var write_file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if write_file != null:
		write_file.store_string(JSON.stringify({
			"schema_version": SCHEMA_VERSION,
			"install_id": install_id,
			"created_at_utc": _timestamp_utc_iso(),
		}, "\t"))
	return install_id

func _sanitize_dictionary(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key_var: Variant in source.keys():
		var key: String = str(key_var)
		var value: Variant = source[key_var]
		match typeof(value):
			TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_NIL:
				result[key] = value
			TYPE_ARRAY:
				result[key] = (value as Array).slice(0, mini(32, (value as Array).size()))
			TYPE_DICTIONARY:
				result[key] = _sanitize_dictionary(value as Dictionary)
			_:
				result[key] = str(value)
	return result

func _random_id(prefix: String) -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%s_%d_%08x" % [prefix, Time.get_ticks_usec(), rng.randi()]

func _timestamp_utc_iso() -> String:
	var now: Dictionary = Time.get_datetime_dict_from_system(true)
	return "%04d-%02d-%02dT%02d:%02d:%02dZ" % [
		int(now.get("year", 1970)), int(now.get("month", 1)), int(now.get("day", 1)),
		int(now.get("hour", 0)), int(now.get("minute", 0)), int(now.get("second", 0)),
	]

func _utc_date_string() -> String:
	var now: Dictionary = Time.get_datetime_dict_from_system(true)
	return "%04d-%02d-%02d" % [int(now.get("year", 1970)), int(now.get("month", 1)), int(now.get("day", 1))]
