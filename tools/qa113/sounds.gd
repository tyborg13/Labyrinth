extends "res://tools/qa103/proof.gd"
## Count attempts and voice starts from production cue triggers and the live bank.

const Bank = preload("res://scripts/sfx_bank.gd")
const Router = preload("res://scripts/sfx_cue_router.gd")
const EXPECTED := {"spell.lightning": 0.550, "status.shock": 0.320, "surface.electric": 0.400,
	"omen.bane": 1.050, "illusion.break": 0.420, "spell.shadow": 0.900,
	"illusion.spawn": 0.950, "dragon.roar": 2.338}
const BANE_FIXTURE: String = "dread"
const SEED: int = 410
const CLOCK_START: int = 10000
const CLOCK_STEP: int = 5000
const LENGTH_EPSILON: float = 0.002
const AUDIO_DRAIN_SECONDS: float = 0.1

var bank: Node
var router: RefCounted
var requests: Array[Dictionary]
var sound_passes: int

func exercise() -> void:
	bank = Bank.new()
	root.add_child(bank)
	bank.warm_up(null, {}, SEED)
	bank.cue_requested.connect(_cue)
	router = Router.new(bank)
	var index: int = 0
	for cue: String in EXPECTED:
		for repeat: int in range(2):
			index += 1
			bank.set_test_clock(CLOCK_START + index * CLOCK_STEP)
			requests.clear()
			var before: int = _voice_generation(cue)
			_trigger(cue)
			var voices_started: int = _voice_generation(cue) - before
			var matches: Array = requests.filter(func(row: Dictionary) -> bool: return row["id"] == cue)
			var ok: bool = voices_started == 1 and matches.size() == 1 and _matches_duration(cue, matches[0])
			check(ok, cue + ": expected one non-looping voice with the approved source and documented alignment cut")
			if ok: sound_passes += 1
			print("QA113 SOUND ", JSON.stringify({"cue": cue, "trigger": repeat + 1, "voices": voices_started, "requests": matches}))
	router = null
	for voice: AudioStreamPlayer in bank.players:
		voice.stop()
	await create_timer(AUDIO_DRAIN_SECONDS).timeout
	bank.queue_free()
	await frames(2)
	print("QA113 SOUNDS: passed=%d/16" % sound_passes)

func _matches_duration(cue: String, row: Dictionary) -> bool:
	if row["result"] != "played" or row["loop"]: return false
	if absf(float(row["source_seconds"]) - EXPECTED[cue]) > LENGTH_EPSILON: return false
	if cue != "illusion.spawn" and float(row["alignment_offset_seconds"]) > 0.0: return false
	var reconstructed: float = float(row["stream_seconds"]) + float(row["alignment_offset_seconds"])
	return absf(reconstructed - EXPECTED[cue]) <= LENGTH_EPSILON

func _voice_generation(cue: String) -> int:
	var generation: int = 0
	for voice: AudioStreamPlayer in bank.cues[cue]["voices"]:
		generation += int(voice.get_meta("play_generation", 0))
	return generation

func _cue(cue_id: String, result: String) -> void:
	var stream: AudioStream = bank.last_play.get("stream") if result == "played" else null
	var looped: bool = false
	if stream is AudioStreamOggVorbis: looped = stream.loop
	if stream is AudioStreamWAV: looped = stream.loop_mode != AudioStreamWAV.LOOP_DISABLED
	var selected: Dictionary = bank.last_play.get("selected", {}) if result == "played" else {}
	var source: AudioStream = selected.get("resource")
	var alignment: Dictionary = bank.last_play.get("alignment", {}) if result == "played" else {}
	var offset: float = float(alignment.get("offset_frames", 0)) / maxf(1.0, float(alignment.get("rate", 1.0)))
	requests.append({"id": cue_id, "result": result, "stream_seconds": stream.get_length() if stream != null else -1.0,
		"source_seconds": source.get_length() if source != null else -1.0, "pitch": selected.get("pitch"),
		"source": source.resource_path if source != null else "", "loop": looped, "alignment_offset_seconds": offset})

func _trigger(cue: String) -> void:
	var state: Dictionary = {"player": {"hp": 12}}
	match cue:
		"spell.lightning", "spell.shadow":
			var action: Dictionary = {"type": "ranged", "element": cue.get_slice(".", 1)}
			router.begin_player_action(state, action)
			for id: int in [1, 2]:
				router.hit(action, {"type": "player"}, "", {"id": id, "hp": 12}, {"hp": 9})
		"status.shock":
			router.baseline(state)
			state["player"]["shock"] = 1
			router.presentation(state, {})
			router.presentation(state, {})
		"surface.electric":
			var event: Dictionary = {"kind": "surface_created", "surface": "electrified"}
			router.outcomes([event, event])
		"omen.bane":
			router.run_context({})
			var awarded: Dictionary = preload("res://scripts/omen_rules.gd").add({}, BANE_FIXTURE)
			router.run_context(awarded)
			router.run_context(awarded)
		"illusion.spawn", "illusion.break":
			var with_illusion: Dictionary = state.duplicate(true)
			with_illusion["illusions"] = [{"id": 1, "hp": 1}]
			var spawn: bool = cue == "illusion.spawn"
			router.baseline(state if spawn else with_illusion)
			var snapshot: Dictionary = with_illusion if spawn else state
			router.presentation(snapshot, {})
			router.presentation(snapshot, {})
		"dragon.roar":
			router.dragon_arrival("enemy:1")
