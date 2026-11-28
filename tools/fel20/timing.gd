extends RefCounted

const Beats = preload("res://tools/fel20/beats.gd")
const Media = preload("res://tools/fel20/media.gd")
const QUIET_MS := 250.0
const READY_LIMIT_MS := 30000.0
const MOTION_LIMIT_AFTER_READY_MS := 4500.0
const FIRST_FLAG_MS := 100.0
const MENU_FLAG_MS := 600.0
const SCREEN_FLAG_MS := 1500.0
const HITCH_MS := 33.0
const FLAG_HITCH_MS := 50.0

var screens
var output: String
var native: bool
var action: int
var problem: String
var origin: int
var sent_at: float
var baseline: Array
var frames: Array[Dictionary]
var first: float = -1.0
var last: float = 0.0
var ready: float = -1.0
var matched: bool = false
var acknowledgement: String
var beats := Beats.new()
var media: RefCounted


func _init(host: RefCounted, directory: String, rendered: bool, number: int) -> void:
	screens = host
	output = directory
	native = rendered
	action = number


func begin(record: bool, recorder: AudioEffectRecord) -> bool:
	baseline = beats.sample(screens, 0.0)
	if record and native:
		media = Media.new()
		if not media.begin(output, action, screens.tree.root, recorder):
			problem = media.problem
			media.discard()
			return false
	origin = Time.get_ticks_usec()
	frames.append({"ms": 0.0, "gap_ms": 0.0, "changed": false})
	return true


func elapsed() -> float:
	return (Time.get_ticks_usec() - origin) / 1000.0


func sample() -> void:
	var at: float = elapsed()
	var signature: Array = beats.sample(screens, at)
	var changed: bool = signature != baseline
	baseline = signature
	var capture_ms: float = 0.0
	if media != null:
		var read_started: int = Time.get_ticks_usec()
		changed = media.frame(screens.tree.root)
		capture_ms = (Time.get_ticks_usec() - read_started) / 1000.0
		if not media.problem.is_empty(): problem = media.problem
	if changed:
		if first < 0.0: first = at
		last = at
	frames.append({"ms": at, "gap_ms": at - frames[-1]["ms"], "changed": changed, "capture_ms": capture_ms})


func finish(id: String, expected: String) -> Dictionary:
	var at: float = elapsed()
	if frames.size() > 1: _probe(expected)
	while problem.is_empty() and at < READY_LIMIT_MS:
		await RenderingServer.frame_post_draw
		sample()
		at = frames[-1]["ms"]
		_probe(expected)
		if ready >= 0.0 and at >= ready + QUIET_MS and at - last >= QUIET_MS and beats._open.is_empty(): break
		if ready >= 0.0 and at >= ready + MOTION_LIMIT_AFTER_READY_MS: break
	var stable: bool = at - last >= QUIET_MS and beats._open.is_empty()
	beats.finish(at)
	beats.record_dispatch(id, sent_at)
	var result: Dictionary = {"action": action, "id": id, "destination": expected, "reached": matched,
		"first_ms": first, "ready_ms": ready, "acknowledgement": acknowledgement,
		"total_ms": last if stable else -1.0, "last_change_ms": last, "observed_ms": at,
		"evidence": "framebuffer" if media != null else "presentation state", "beats": beats.spans,
		"frames": frames, "flags": [], "hitches": []}
	var threshold: float = MENU_FLAG_MS if id.get_slice(".", 0) in ["character", "large_map", "grimoire", "pause"] else SCREEN_FLAG_MS
	if first > FIRST_FLAG_MS: _flag(result, "first response", first)
	if ready > threshold: _flag(result, "input ready", ready)
	var cutoff: float = last if stable else at
	for frame: Dictionary in frames:
		if frame["ms"] > cutoff: break
		if frame["gap_ms"] > HITCH_MS: result["hitches"].append(frame)
		if frame["gap_ms"] > FLAG_HITCH_MS: _flag(result, "frame over 50 ms", frame["ms"], frame["gap_ms"])
	if media != null:
		if not problem.is_empty(): media.discard()
		elif not media.finish(result): problem = media.problem
	print("FEL20 | %05d | %s | first %.1f ms | ready %.1f ms | total %.1f ms | >33 ms %d | flags %d | reached %s | %s" %
		[action, id, first, ready, result["total_ms"], result["hitches"].size(), result["flags"].size(), str(matched), acknowledgement])
	for hitch: Dictionary in result["hitches"]:
		print("FEL20 HITCH %05d %s +%.3f ms frame %.3f ms" % [action, id, hitch["ms"], hitch["gap_ms"]])
	for flag: Dictionary in result["flags"]:
		print("FEL20 FLAG %05d %s +%.3f ms %s %.3f ms" % [action, id, flag["ms"], flag["kind"], flag["duration_ms"]])
	return result


func _probe(expected: String) -> void:
	matched = matched or screens.destination(expected)
	if ready >= 0.0: return
	acknowledgement = screens.probe(expected)
	if not acknowledgement.is_empty(): ready = elapsed()


func discard() -> void:
	if media != null: media.discard()


func _flag(result: Dictionary, kind: String, at: float, duration: float = -1.0) -> void:
	result["flags"].append({"kind": kind, "ms": at, "duration_ms": at if duration < 0.0 else duration})
