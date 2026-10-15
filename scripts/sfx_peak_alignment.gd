extends RefCounted

# Decode each shared approved stream once. Per-call PCM copies preserve its tail;
# they exist only in memory and live as long as the voice using them.
const Rules = preload("res://scripts/sfx_sync_rules.gd")
static var _decoded: Dictionary = {}

static func decoded(stream: AudioStream) -> Dictionary:
	var key: int = stream.get_instance_id()
	if _decoded.has(key): return _decoded[key]
	var rate: int = int(AudioServer.get_mix_rate())
	var playback: AudioStreamPlayback = stream.instantiate_playback()
	playback.start()
	var pcm: PackedVector2Array = playback.mix_audio(1.0, ceili(stream.get_length() * rate))
	playback.stop()
	var bytes := PackedByteArray()
	bytes.resize(pcm.size() * 4)
	var quantized := PackedVector2Array()
	quantized.resize(pcm.size())
	var sums := PackedFloat64Array()
	sums.resize(pcm.size() + 1)
	for index: int in range(pcm.size()):
		var left: int = clampi(roundi(pcm[index].x * 32768.0), -32768, 32767)
		var right: int = clampi(roundi(pcm[index].y * 32768.0), -32768, 32767)
		bytes.encode_s16(index * 4, left)
		bytes.encode_s16(index * 4 + 2, right)
		quantized[index] = Vector2(left, right) / 32768.0
		sums[index + 1] = sums[index] + quantized[index].length_squared() * 0.5
	var result: Dictionary = {"pcm": pcm, "bytes": bytes, "sums": sums, "rate": rate, "stream": stream, "metrics": metrics(quantized, rate)}
	_decoded[key] = result
	return result

static func _window_frames(rate: int) -> int:
	var exact_window: float = float(Rules.config()["envelope_window_ms"]) * rate / 1000.0
	var window: int = maxi(1, floori(exact_window))
	# Match the audit's nearest-even window rounding (220 frames at 44.1 kHz).
	if exact_window - window > 0.5 or (is_equal_approx(exact_window - window, 0.5) and window % 2 == 1): window += 1
	return window

static func metrics(pcm: PackedVector2Array, rate: int) -> Dictionary:
	var window: int = _window_frames(rate)
	var half: int = window / 2
	var sums := PackedFloat64Array()
	sums.resize(pcm.size() + 1)
	for index: int in range(pcm.size()):
		sums[index + 1] = sums[index] + pcm[index].length_squared() * 0.5
	var powers := PackedFloat64Array()
	powers.resize(pcm.size())
	var peak: int = 0
	for index: int in range(pcm.size()):
		powers[index] = (sums[mini(pcm.size(), index - half + window)] - sums[maxi(0, index - half)]) / window
		if powers[index] > powers[peak]: peak = index
	var strongest: int = peak
	var minimum_power: float = powers[strongest] * pow(10.0, -float(Rules.config()["alignment_peak_within_db"]) / 10.0)
	for index: int in range(1, powers.size() - 1):
		if powers[index] >= minimum_power and powers[index] > powers[index - 1] and powers[index] >= powers[index + 1]:
			peak = index
			break
	var onset: int = 0
	while onset < peak and powers[onset] < powers[peak] * pow(10.0, -float(Rules.config()["perceived_below_peak_db"]) / 10.0): onset += 1
	return {"peak_ms": peak * 1000.0 / rate, "perceived_onset_ms": onset * 1000.0 / rate, "peak_power": powers[peak]}

static func plan(stream: AudioStream, pitch: float, climax_ms: float) -> Dictionary:
	var source: Dictionary = decoded(stream)
	var start: float = climax_ms + float(Rules.config()["target_lag_ms"]) - float(source["metrics"]["peak_ms"]) / pitch
	return {"delay_ms": maxf(0.0, start), "skip_ms": maxf(0.0, -start) * pitch,
		"source_peak_ms": source["metrics"]["peak_ms"], "climax_ms": climax_ms}

static func trimmed(stream: AudioStream, pitch: float, skip_ms: float) -> Dictionary:
	var source: Dictionary = decoded(stream)
	var pcm: PackedVector2Array = source["pcm"]
	var rate: int = source["rate"]
	# Flooring keeps at least the requested pre-peak interval.
	var latest: float = maxf(0.0, float(source["metrics"]["peak_ms"]) - float(Rules.config()["minimum_pre_peak_ms"]) * pitch)
	var offset: int = maxi(0, floori(minf(skip_ms, latest) * rate / 1000.0))
	var fade: int = maxi(2, ceili(float(Rules.config()["fade_ms"]) * rate * pitch / 1000.0))
	# Slice the cached PCM in native code; only the 3 ms ramp is rebuilt. A
	# whole-file GDScript conversion here would stall the presentation frame.
	var data: PackedByteArray = (source["bytes"] as PackedByteArray).slice(offset * 4)
	var sums: PackedFloat64Array = source["sums"]
	var delta := PackedFloat64Array()
	delta.resize(fade + 1)
	for index: int in range(mini(fade, data.size() / 4)):
		var value: Vector2 = pcm[index + offset] * float(index) / float(fade - 1)
		var left: int = clampi(roundi(value.x * 32768.0), -32768, 32767)
		var right: int = clampi(roundi(value.y * 32768.0), -32768, 32767)
		data.encode_s16(index * 4, left)
		data.encode_s16(index * 4 + 2, right)
		var quantized: Vector2 = Vector2(left, right) / 32768.0
		delta[index + 1] = delta[index] + quantized.length_squared() * 0.5 - (sums[offset + index + 1] - sums[offset + index])
	# The peak lies >=15 ms beyond the cut, so the 3 ms fade cannot touch its
	# 5 ms window. Locate onset from cached power sums plus the ramp correction.
	var peak: int = roundi(float(source["metrics"]["peak_ms"]) * rate / 1000.0) - offset
	var threshold: float = float(source["metrics"]["peak_power"]) * pow(10.0, -float(Rules.config()["perceived_below_peak_db"]) / 10.0)
	var window: int = _window_frames(rate)
	var onset: int = 0
	while onset < peak:
		var lo: int = maxi(0, onset - window / 2)
		var hi: int = mini(pcm.size() - offset, onset - window / 2 + window)
		var power: float = (sums[offset + hi] - sums[offset + lo] + delta[mini(hi, fade)] - delta[mini(lo, fade)]) / window
		if power >= threshold: break
		onset += 1
	var output_metrics: Dictionary = {"peak_ms": peak * 1000.0 / rate, "perceived_onset_ms": onset * 1000.0 / rate}
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = true
	wav.data = data
	return {"stream": wav, "metrics": output_metrics, "offset_frames": offset,
		"fade_frames": fade, "rate": rate, "source_frames": pcm.size()}
