extends RefCounted

const REPORT: String = "res://spec/peer_benchmark/staged/sfx/sync_baseline.json"
const ROUTER: String = "scripts/sfx_cue_router.gd"
const RUN: String = "scripts/run_scene.gd"

# The full suite needs only Godot. Encoded audio hashes bind the expensive
# sound-lab measurements to the exact bytes; source coverage is identified by
# function + statement, so comments and unrelated line shifts remain harmless.
static func measured_samples(failures: Array[String]) -> Dictionary:
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REPORT))
	var samples: Dictionary = report["samples"]
	for path: String in samples:
		if FileAccess.get_sha256(path) != str(samples[path]["sha256"]):
			failures.append("Audio changed; refresh sound-lab measurements: " + path)
	return samples

static func identity(site: Dictionary) -> String:
	return "%s|%s|%s" % [site["file"], site["function"], RegEx.create_from_string("\\s+").sub(str(site["code"]).strip_edges(), " ", true)]

static func _scripts(directory: String, result: Array[String]) -> void:
	for file: String in DirAccess.get_files_at(directory):
		if file.ends_with(".gd"): result.append(directory.path_join(file))
	for child: String in DirAccess.get_directories_at(directory):
		_scripts(directory.path_join(child), result)

static func inventory(cues: Dictionary) -> Dictionary:
	var paths: Array[String]
	_scripts("res://scripts", paths)
	paths.sort()
	var declaration := RegEx.create_from_string("^(?:static )?func (\\w+)\\(")
	var request := RegEx.create_from_string("(?<!func )\\brequest\\(|bank\\.schedule_area\\(")
	var trigger := RegEx.create_from_string("_sfx_router\\.(?!baseline|begin_|bind_map_hover|weapon_for_card|ambience_for_run)(\\w+)\\(|_sfx_bank\\.play(?:_entry)?\\(")
	var literal := RegEx.create_from_string('\\b(?:play|request|schedule_area)\\(\\s*"([^"]+)"')
	var result: Dictionary = {}
	for path: String in paths:
		var function: String = ""
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for index: int in range(lines.size()):
			var found: RegExMatch = declaration.search(lines[index])
			if found != null:
				function = found.get_string(1)
			var code: String = lines[index].get_slice("#", 0).strip_edges()
			var file: String = path.trim_prefix("res://")
			var relevant: bool = request.search(code) != null if file == ROUTER else trigger.search(code) != null
			if file != ROUTER:
				var call: RegExMatch = literal.search(code)
				if call != null and cues.has(call.get_string(1)): relevant = true
			if not relevant or (file == RUN and function == "_play_sfx"): continue
			result[file + ":" + str(index + 1)] = {"file": file, "function": function, "code": code, "dormant": file == ROUTER and function == "ambience"}
	return result

static func _location(frame: Dictionary) -> String:
	var file: String = str(frame["source"]).trim_prefix("res://")
	if file.begins_with("tests/sfx_sync_instrumented_"):
		file = "scripts/" + file.trim_prefix("tests/sfx_sync_instrumented_")
	return file + ":" + str(frame["line"])

static func _counts(rows: Array, kind: String = "request_counts") -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in rows:
		var role: String = str(row.get("request", {}).get("role", "primary"))
		if kind == "primary_play_counts" and (row["result"] != "played" or role != "primary"): continue
		if kind == "optional_play_counts" and (row["result"] != "played" or role != "optional_layer"): continue
		var key: String = str(row["scenario"]) + "|" + str(row["cue"])
		result[key] = int(result.get(key, 0)) + 1
	return result

static func verify_request(row: Dictionary, cues: Dictionary, failures: Array[String]) -> void:
	var result: String = row["result"]
	if result == "played": return
	var request: Dictionary = row.get("request", {})
	var role: String = str(request.get("role", "primary"))
	if result == "priority" and role == "optional_layer": return
	if result == "cooldown" and int(request.get("since_success_ms", -1)) >= 0 and int(request.get("since_success_ms", -1)) < int(request.get("cooldown_ms", 0)): return
	if result == "silent" and bool(cues[row["cue"]].get("loop", false)): return
	failures.append("Required primary did not play: %s / %s (%s; %s)" % [row.get("scenario", "fixture"), row["cue"], result, role])

static func verify(rows: Array[Dictionary], silences: Array[Dictionary], cues: Dictionary, failures: Array[String]) -> void:
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REPORT))
	var sites: Dictionary = inventory(cues)
	var visited: Dictionary = {}
	var pairs: Dictionary = {}
	var covered: Dictionary = {}
	for row: Dictionary in rows:
		covered[row["cue"]] = true
		for frame: Dictionary in row["stack"]:
			var location: String = _location(frame)
			if sites.has(location):
				var key: String = identity(sites[location])
				visited[key] = true
				pairs[str(row["cue"]) + "|" + key] = true
	for site: Dictionary in sites.values():
		if not bool(site["dormant"]) and not visited.has(identity(site)):
			failures.append("Uncovered live call site: " + identity(site))
	for row: Array in report["cue_site_pairs"]:
		var key: String = "|".join(row)
		if not pairs.has(key): failures.append("Cue × call-site coverage shrank: " + key)
	for cue: String in cues:
		if not covered.has(cue): failures.append("Uncovered registered cue: " + cue)
	var speed: float = float(rows[0].get("speed", 1.0)) if not rows.is_empty() else 1.0
	var profile: String = str(rows[0].get("frame_profile", "fixed_60")) if not rows.is_empty() else "fixed_60"
	var run_index: int = -1
	# New enemy-action clocks inherit every count floor from their corresponding
	# combat speed. The approved baseline stays byte-for-byte unchanged.
	var baseline_speed: float = speed
	for base: float in [1.0, 1.5, 2.0]:
		if is_equal_approx(speed, base * 0.80): baseline_speed = base
	for index: int in range(report["runs"].size()):
		if report["runs"][index][0] == profile and is_equal_approx(float(report["runs"][index][1]), baseline_speed): run_index = index
	if run_index < 0:
		failures.append("Unbaselined frame profile / speed: %s / %s" % [profile, speed])
	else:
		for kind: String in ["request_counts", "primary_play_counts", "optional_play_counts"]:
			var actual: Dictionary = _counts(rows, kind)
			for key: String in report[kind]:
				if int(actual.get(key, 0)) < int(report[kind][key][run_index]): failures.append("%s shrank: %s / %sx / %s" % [kind, profile, speed, key])
	for old: Dictionary in report.get("silences", []):
		if not silences.any(func(row: Dictionary) -> bool: return row["scenario"] == old["scenario"] and int(row["frames"]) > 0 and int(row["requests"]) == 0):
			failures.append("Silent visual coverage shrank: " + str(old["scenario"]))
	print("SFX SYNC COVERAGE: %s / %sx: %d requests, %d primary plays, %d cue × call-site pairs, %d silent visuals" % [profile, speed, rows.size(), rows.filter(func(row: Dictionary) -> bool: return row["result"] == "played" and row["request"]["role"] == "primary").size(), pairs.size(), silences.size()])
