extends RefCounted

const REPORT: String = "res://spec/peer_benchmark/staged/sfx/sync_audit.json"
const ROUTER: String = "scripts/sfx_cue_router.gd"
const RUN: String = "scripts/run_scene.gd"

# The full suite needs only Godot. Encoded audio hashes bind the expensive
# sound-lab measurements to the exact bytes; source coverage is identified by
# function + statement, so comments and unrelated line shifts remain harmless.
static func measured_samples(failures: Array[String]) -> Dictionary:
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REPORT))
	var samples: Dictionary = report["after"]["samples"]
	for path: String in samples:
		if FileAccess.get_sha256(path) != str(samples[path]["sha256"]):
			failures.append("Audio changed; refresh sound-lab measurements: " + path)
	return samples

static func identity(site: Dictionary) -> String:
	return "%s|%s|%s" % [site["file"], site["function"], str(site.get("snippet", site["code"])).strip_edges()]

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
		var context: Array[String]
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for index: int in range(lines.size()):
			var found: RegExMatch = declaration.search(lines[index])
			if found != null:
				function = found.get_string(1)
				context.clear()
			var code: String = lines[index].get_slice("#", 0).strip_edges()
			var file: String = path.trim_prefix("res://")
			var relevant: bool = request.search(code) != null if file == ROUTER else trigger.search(code) != null
			if file != ROUTER:
				var call: RegExMatch = literal.search(code)
				if call != null and cues.has(call.get_string(1)): relevant = true
			var snippet: String = "\n".join(context.slice(maxi(0, context.size() - 2))) + ("\n" if not context.is_empty() else "") + code
			if not code.is_empty(): context.append(code)
			if not relevant or (file == RUN and function == "_play_sfx"): continue
			result[file + ":" + str(index + 1)] = {"file": file, "function": function, "code": code, "snippet": snippet, "dormant": file == ROUTER and function == "ambience"}
	return result

static func _location(frame: Dictionary) -> String:
	var file: String = str(frame["source"]).trim_prefix("res://")
	if file.begins_with("tests/sfx_sync_instrumented_"):
		file = "scripts/" + file.trim_prefix("tests/sfx_sync_instrumented_")
	return file + ":" + str(frame["line"])

static func _counts(rows: Array) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in rows:
		var key: String = str(row["scenario"]) + "|" + str(row["cue"])
		result[key] = int(result.get(key, 0)) + 1
	return result

static func verify(rows: Array[Dictionary], silences: Array[Dictionary], cues: Dictionary, failures: Array[String]) -> void:
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REPORT))["after"]
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
	for row: Dictionary in report["rows"]:
		var key: String = str(row["cue"]) + "|" + identity(row["call_site"])
		if not pairs.has(key): failures.append("Cue × call-site coverage shrank: " + key)
	for cue: String in cues:
		if not covered.has(cue): failures.append("Uncovered registered cue: " + cue)
	var expected: Dictionary = _counts(report["observations"])
	var actual: Dictionary = _counts(rows)
	for key: String in expected:
		if int(actual.get(key, 0)) < int(expected[key]): failures.append("Observation coverage shrank: " + key)
	for old: Dictionary in report.get("silences", []):
		if not silences.any(func(row: Dictionary) -> bool: return row["scenario"] == old["scenario"] and int(row["frames"]) > 0 and int(row["requests"]) == 0):
			failures.append("Silent visual coverage shrank: " + str(old["scenario"]))
	print("SFX SYNC COVERAGE: %d observations, %d cue × call-site pairs, %d silent visuals" % [rows.size(), pairs.size(), silences.size()])
