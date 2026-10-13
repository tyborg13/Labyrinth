extends RefCounted

const Bank = preload("res://scripts/sfx_bank.gd")
const Settings = preload("res://scripts/settings_store.gd")
const TEST_SEED: int = 410
const FIRST: String = "res://assets/audio/sfx/attack_melee_sword_first.wav"
const SECOND: String = "res://assets/audio/sfx/action_block.wav"
const LOOP: String = "res://assets/audio/sfx/ui/dungeon_hall_ambience_loop.wav"

static func run(expect: Callable) -> void:
	var bank := Bank.new()
	var source: Dictionary = {"cues": {
		"rotate": {"variants": [FIRST, SECOND], "volume_db": -2.0, "pitch_jitter": 0.05, "cooldown_ms": 30, "max_voices": 2, "bus": "World"},
		"reuse": {"variants_from": "rotate", "pitch_scale": 0.85, "volume_db": -4.0, "pitch_jitter": 0.0, "max_voices": 1, "bus": "UI"},
		"fallback": {"fallback": [FIRST], "volume_db": 0.0, "max_voices": 1},
		"silent": {"fallback": [], "max_voices": 1},
		"bed.a": {"variants": [LOOP], "volume_db": -20.0, "loop": true, "bus": "World"},
		"bed.b": {"variants": [LOOP], "volume_db": -22.0, "loop": true, "bus": "World"}
	}}
	bank.warm_up(null, source, TEST_SEED)
	bank.set_test_clock(1000)
	var pool_count: int = bank.get_child_count()
	bank.play("rotate", {"gain_db": -6.0})
	var voices: Array = bank.cues["rotate"]["voices"]
	var first: AudioStream = voices[0].stream
	var first_pitch: float = voices[0].pitch_scale
	expect.call(voices[0].volume_db == -8.0, "Variant volume adds caller gain to director level")
	expect.call(voices[0].pitch_scale >= 0.95 and voices[0].pitch_scale <= 1.05, "Pitch jitter stays inside the uniform authored fraction")
	expect.call(voices[0].bus == Settings.WORLD_SFX_BUS, "World cue routes to World SFX")
	bank.set_test_clock(1029)
	expect.call(bank.play("rotate") == 0.0 and bank.cues["rotate"]["played"] == 1, "Cooldown suppresses inside the window")
	bank.set_test_clock(1030)
	bank.play("rotate")
	expect.call(voices[1].stream != first, "Cooldown boundary rotates to the other variant")
	bank.set_test_clock(1060)
	bank.play("rotate")
	expect.call(voices[0].stream == first and voices[0].get_meta("serial") > voices[1].get_meta("serial"), "Voice cap steals the oldest and round-robin wraps without adjacent repeats")
	expect.call(voices.size() == 2 and bank.get_child_count() == pool_count, "Playback keeps the warmed player pool fixed")
	bank.play("reuse")
	var reuse: AudioStreamPlayer = bank.cues["reuse"]["voices"][0]
	expect.call(reuse.stream != null and is_equal_approx(reuse.pitch_scale, 0.85) and reuse.volume_db == -4.0, "Inherited variants retain the receiving cue volume and pitch multiplier")
	expect.call(reuse.bus == Settings.UI_SFX_BUS, "UI cue routes to dry UI SFX")
	bank.play("fallback")
	expect.call(bank.cues["fallback"]["voices"][0].stream != null and bank.cues["fallback"]["voices"][0].volume_db == -5.5, "Empty variants use the existing fallback at its owner-auditioned mix level")
	expect.call(bank.play("silent") == 0.0 and bank.cues["silent"]["silent"] == 1, "Empty variants and fallback are silent and counted")
	bank.play("bed.a")
	var bed_a: AudioStreamPlayer = bank.active_loop_player()
	expect.call(bed_a.stream is AudioStreamWAV and (bed_a.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD and (bed_a.stream as AudioStreamWAV).loop_end > 0, "Ambience stream loops")
	bank.advance(0.6)
	expect.call(is_equal_approx(bed_a.volume_db, -20.0), "First bed reaches its authored level after 0.6 seconds")
	bank.play("bed.b")
	var bed_b: AudioStreamPlayer = bank.active_loop_player()
	expect.call(bed_a != bed_b and bed_a.stream != null, "Ambience change retains outgoing voice for crossfade")
	bank.advance(0.3)
	expect.call(bed_a.volume_linear > 0.0 and bed_b.volume_linear > 0.0, "Both beds are audible halfway through crossfade")
	bank.advance(0.3)
	expect.call(bed_a.stream == null and is_equal_approx(bed_b.volume_db, -22.0), "Crossfade ends at 0.6 seconds and releases outgoing stream")
	bank.stop_loop()
	bank.advance(0.6)
	expect.call(bed_b.stream == null, "Stopping ambience completes the same fade")
	var twin := Bank.new()
	twin.warm_up(null, source, TEST_SEED)
	twin.set_test_clock(1000)
	twin.play("rotate", {"gain_db": -6.0})
	expect.call(twin.cues["rotate"]["voices"][0].stream == first and is_equal_approx(twin.cues["rotate"]["voices"][0].pitch_scale, first_pitch), "Seeded cue RNG reproduces the random round-robin start")
	var production := Bank.new()
	production.warm_up(null, {}, TEST_SEED)
	production.play("ambience.tharokh")
	production.advance(0.6)
	expect.call(is_equal_approx(production.active_loop_player().volume_db, -20.0), "Section fallback hall tone preserves today's owner-auditioned level until variants arrive")
	production.free()
	var raw: Dictionary = {"path": FIRST, "volume_db": -8.0, "duration": 0.1}
	bank.prepare_legacy([raw])
	var warmed_count: int = bank.get_child_count()
	bank.play_entry(raw)
	var raw_voice: AudioStreamPlayer = bank.cues["legacy:" + FIRST]["voices"][0]
	expect.call(is_equal_approx(raw_voice.volume_db, -8.0), "Legacy callers retain their own authored per-call gain")
	bank.play_entry({"path": FIRST, "volume_db": -3.0, "duration": 0.2})
	var raw_second: AudioStreamPlayer = bank.cues["legacy:" + FIRST]["voices"][1]
	expect.call(is_equal_approx(raw_second.volume_db, -3.0) and bank.get_child_count() == warmed_count, "A second legacy gain reuses the warmed cue without changing its level or allocating players")
	bank.play_entry({"path": FIRST, "volume_db": -2.0})
	var raw_full: AudioStreamPlayer = bank.cues["legacy:" + FIRST]["voices"][2]
	expect.call(int(raw_full.get_meta("until")) - bank.now_ms() > 500, "A legacy call without a duration retains its full tail after earlier trimmed calls")
	bank.free()
	twin.free()
