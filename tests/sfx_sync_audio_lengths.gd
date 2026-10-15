extends RefCounted

const Assets = preload("res://scripts/asset_loader.gd")
const Rules = preload("res://scripts/sfx_sync_rules.gd")

# Expected durations come from independently decoded PCM. This catches malformed
# Ogg EOS granules even when the entire waveform still decodes in FFmpeg.
static func verify(samples: Dictionary, failures: Array[String]) -> void:
	var lengths: Dictionary = {}
	for path: String in samples:
		if not samples[path].has("duration_seconds"):
			failures.append("Missing decoded duration: " + path)
			continue
		var stream: AudioStream = Assets.load_audio_stream(path)
		if stream == null:
			failures.append("Cannot load measured audio: " + path)
		elif absf(stream.get_length() - float(samples[path]["duration_seconds"])) > 0.001:
			failures.append("Godot/decoded length differs by more than 1 ms: %s (%.6f vs %.6f)" % [path, stream.get_length(), samples[path]["duration_seconds"]])
		if stream != null: lengths[path] = stream.get_length()
	var cues: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Rules.DATA_PATH))["cues"]
	for cue: String in cues:
		var source: Dictionary = cues[cue]
		var visited: Dictionary = {}
		while source.has("variants_from"):
			var parent: String = str(source["variants_from"])
			if visited.has(parent):
				failures.append("Cyclic duration source: " + cue)
				break
			visited[parent] = true
			source = cues[parent]
		var paths: Array = source.get("variants", [])
		if paths.is_empty(): paths = source.get("fallback", [])
		for path: String in paths:
			if not lengths.has(path):
				failures.append("Unmeasured cue duration: " + cue + " / " + path)
			elif float(lengths[path]) > Rules.duration_cap(cue, cues[cue]) + 0.000001:
				failures.append("One-shot duration exceeds cap: %s / %s (%.6f > %.3f s)" % [cue, path, lengths[path], Rules.duration_cap(cue, cues[cue])])
	print("SFX AUDIO LENGTHS: %d Godot streams compared with decoded PCM" % samples.size())
