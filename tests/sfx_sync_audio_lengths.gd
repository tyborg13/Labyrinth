extends RefCounted

const Assets = preload("res://scripts/asset_loader.gd")

# Expected durations come from independently decoded PCM. This catches malformed
# Ogg EOS granules even when the entire waveform still decodes in FFmpeg.
static func verify(samples: Dictionary, failures: Array[String]) -> void:
	for path: String in samples:
		if not samples[path].has("duration_seconds"):
			failures.append("Missing decoded duration: " + path)
			continue
		var stream: AudioStream = Assets.load_audio_stream(path)
		if stream == null:
			failures.append("Cannot load measured audio: " + path)
		elif absf(stream.get_length() - float(samples[path]["duration_seconds"])) > 0.001:
			failures.append("Godot/decoded length differs by more than 1 ms: %s (%.6f vs %.6f)" % [path, stream.get_length(), samples[path]["duration_seconds"]])
	print("SFX AUDIO LENGTHS: %d Godot streams compared with decoded PCM" % samples.size())
