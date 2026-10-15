extends SceneTree

const Bank = preload("res://scripts/sfx_bank.gd")
const Coverage = preload("res://tests/sfx_sync_coverage.gd")
const Lengths = preload("res://tests/sfx_sync_audio_lengths.gd")
const Router = preload("res://scripts/sfx_cue_router.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const FIXTURE_CLOCK_MS: int = 10000
const FIXTURE_SEED: int = 410
const FIXTURE_GAIN_DB: float = -3.0
var failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	Lengths.verify(Coverage.measured_samples(failures), failures)
	var bank := Bank.new()
	root.add_child(bank)
	bank.warm_up(null, {}, FIXTURE_SEED)
	bank.set_test_clock(FIXTURE_CLOCK_MS)
	var starts: Array[Dictionary]
	bank.cue_requested.connect(func(cue: String, result: String) -> void:
		starts.append({"cue": cue, "result": result, "time": bank.now_ms()})
	)
	bank.play("hit.blade.light")
	bank.play("status.freeze")
	_expect(starts.size() == 2 and starts.all(func(row: Dictionary) -> bool: return row["result"] == "played" and row["time"] == FIXTURE_CLOCK_MS), "A hit and its status layer both start on their triggering frame")
	for cue: String in ["hit.blade.light", "status.freeze"]:
		_expect((bank.cues[cue]["voices"] as Array).any(func(player: AudioStreamPlayer) -> bool: return player.playing), cue + " starts a real in-tree AudioStreamPlayer")
	starts.clear()
	var router := Router.new(bank)
	router.begin_player_action({}, {"type": "aoe", "element": "fire", "damage": 3})
	for index: int in range(3):
		router.hit({"type": "aoe", "element": "fire", "damage": 3}, {}, "", {"id": index, "hp": 10}, {"hp": 7})
	_expect(starts.size() == 1 and starts.all(func(row: Dictionary) -> bool: return row["result"] == "played" and row["time"] == FIXTURE_CLOCK_MS), "Three same-frame targets produce exactly one primary voice")
	for index: int in range(3, 6):
		bank.set_test_clock(FIXTURE_CLOCK_MS + (index - 2) * 17)
		router.hit({"type": "aoe", "element": "fire", "damage": 3}, {}, "", {"id": index, "hp": 10}, {"hp": 7})
	_expect(starts.size() == 3 and starts[1]["time"] == FIXTURE_CLOCK_MS + 17 and starts[2]["time"] == FIXTURE_CLOCK_MS + 34, "Only two later contact frames add immediate area layers")
	var area_voices: Array = bank.cues["spell.fire"]["voices"]
	_expect(area_voices.filter(func(player: AudioStreamPlayer) -> bool: return player.volume_db == float(bank.data["cues"]["spell.fire"]["volume_db"]) + Router.AREA_GAIN_DB).size() == 2, "Later area voices retain the authored -6 dB gain")
	bank.set_test_clock(FIXTURE_CLOCK_MS + 1000)
	bank.advance(1.0)
	_expect(starts.size() == 3, "Advancing the clock cannot release delayed area voices")
	starts.clear()
	router.begin_player_action({}, {"type": "melee", "damage": 3})
	starts.clear()
	router.hit({"type": "melee", "damage": 3}, {}, "sword", {"id": 81, "hp": 10, "block": 3}, {"hp": 10, "block": 0})
	router.hit({"type": "melee", "damage": 3}, {}, "sword", {"id": 82, "hp": 10}, {"hp": 7})
	_expect(starts.size() == 2 and starts[0]["cue"] == "hit.blocked" and starts[1]["cue"] == "hit.blade.light", "Distinct blocked and unblocked cues both play on the same frame")
	_expect(bank.last_play["selected"]["gain"] == float(bank.data["cues"]["hit.blade.light"]["volume_db"]) + Router.AREA_GAIN_DB, "Second distinct same-frame cue retains -6 dB layering")
	# Force each approved pitch bound through the actual selection/play path.
	# Fixing the entry's jitter at zero avoids replacing any planner or player.
	for cue: String in ["move.blink", "dragon.roar", "cast.arcane", "hit.blunt.heavy", "illusion.spawn"]:
		var entry: Dictionary = bank.cues[cue]["entry"]
		var jitter: float = entry["pitch_jitter"]
		var base: float = float(entry.get("pitch_scale", 1.0))
		for pitch: float in [base * (1.0 - jitter), base, base * (1.0 + jitter)]:
			entry["pitch_jitter"] = 0.0
			entry["pitch_scale"] = pitch
			for climax: float in [0.0, 316.673, 566.678]:
				bank.set_test_clock(bank.now_ms() + 5000)
				var start: int = bank.now_ms()
				bank.play(cue, {"peak_climax_ms": climax})
				if not bank._peak_pending.is_empty():
					var delay: float = bank._peak_pending[0]["selected"]["remaining_ms"]
					bank.set_test_clock(start + ceili(delay))
					bank.advance(float(ceili(delay)) / 1000.0)
				var played: Dictionary = bank.last_play
				_expect(played["cue"] == cue and not played["alignment"].is_empty(), "Aligned call reaches its actual voice")
				if played["cue"] != cue or played["alignment"].is_empty(): continue
				var peak: float = float(played["alignment"]["metrics"]["peak_ms"]) / float(played["selected"]["pitch"])
				_expect(is_equal_approx(played["selected"]["pitch"], pitch), "Actual voice selects the forced pitch bound")
				_expect(absf(bank.now_ms() - start + peak - climax - 15.0) <= 1.0, "Actual bank playback targets +15 ±1 ms at each pitch bound")
		entry["pitch_jitter"] = jitter
		entry["pitch_scale"] = base
	bank.set_test_clock(bank.now_ms() + 5000)
	starts.clear()
	var previous: int = bank.cues["move.blink"]["last_ms"]
	bank.play("move.blink", {"peak_climax_ms": 500.0})
	_expect(starts.is_empty() and bank.cues["move.blink"]["last_ms"] == previous, "Future peak does not consume cooldown")
	bank.play("status.freeze")
	_expect(starts.size() == 1 and starts[0]["cue"] == "status.freeze", "Unrelated cue starts while an aligned call waits")
	_expect(not bank._peak_pending.is_empty(), "Future alignment creates a pending call")
	if not bank._peak_pending.is_empty():
		var remaining: float = bank._peak_pending[0]["selected"]["remaining_ms"]
		bank.advance(1.0 / 60.0)
		_expect(not bank._peak_pending.is_empty() and is_equal_approx(bank._peak_pending[0]["selected"]["remaining_ms"], remaining), "A new request cannot consume time before it was scheduled")
		paused = true
		bank.set_test_clock(bank.now_ms() + 2000)
		bank.advance(2.0)
		_expect(starts.size() == 1, "Pause cannot release a delayed call")
		paused = false
		Engine.time_scale = 0.0
		bank.set_test_clock(bank.now_ms() + 2000)
		bank.advance(0.0)
		_expect(starts.size() == 1, "Hit-stop cannot release a delayed call")
		Engine.time_scale = 1.0
		bank.advance(0.001)
		_expect(starts.size() == 1, "Resume does not catch up paused wall time")
		bank.set_test_clock(bank.now_ms() + ceili(remaining))
		bank.advance(float(ceili(remaining)) / 1000.0)
		_expect(starts.size() == 2 and starts.back()["cue"] == "move.blink", "Remaining active time releases the queued call")
	_absolute_deadline_cases(bank)
	bank.free()
	var limited := Bank.new()
	root.add_child(limited)
	limited.warm_up(null, {"cues": {"fixture": {"variants": ["res://assets/audio/sfx/cues/hit.blade.light/hit.blade.light_01.ogg"], "volume_db": FIXTURE_GAIN_DB, "max_voices": 1}}}, FIXTURE_SEED)
	limited.set_test_clock(FIXTURE_CLOCK_MS)
	starts.clear()
	limited.cue_requested.connect(func(cue: String, result: String) -> void: starts.append({"cue": cue, "result": result, "time": limited.now_ms()}))
	limited.play("fixture")
	var primary: AudioStreamPlayer = limited.cues["fixture"]["voices"][0]
	var generation: int = int(primary.get_meta("play_generation"))
	limited.set_test_clock(FIXTURE_CLOCK_MS + 1)
	limited.play("fixture", {"area_instance": true, "gain_db": Router.AREA_GAIN_DB})
	_expect(int(limited.cues["fixture"]["last_ms"]) == FIXTURE_CLOCK_MS, "A dropped request cannot move the last successful play time")
	_expect(starts.back()["result"] == "priority", "An optional area layer drops immediately behind a primary voice")
	_expect(primary.volume_db == FIXTURE_GAIN_DB and int(primary.get_meta("play_generation")) == generation, "Dropping an area layer preserves the audible primary's gain and start")
	var dropped_duration: float = limited.play("fixture", {"area_instance": true, "peak_deadline_ms": limited.presentation_ms()})
	_expect(is_zero_approx(dropped_duration) and starts.back()["result"] == "priority", "A dropped aligned layer returns zero playback duration")
	limited.play("fixture")
	_expect(starts.back()["result"] == "played" and int(primary.get_meta("play_generation")) == generation + 1, "An equal-priority fresh cue steals immediately instead of waiting")
	limited.schedule_area("fixture", 1000, Router.AREA_GAIN_DB)
	var count: int = starts.size()
	limited.set_test_clock(FIXTURE_CLOCK_MS + 2000)
	limited.advance(2.0)
	_expect(starts.size() == count, "The compatibility area API cannot serialize a cue behind a delay")
	limited.free()
	for failure: String in failures: push_error(failure)
	print("SFX SYNC BANK TEST RESULT: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _absolute_deadline_cases(bank: Node) -> void:
	var clock: Dictionary = {"usec": 10000000}
	bank.presentation_clock = func() -> int: return int(clock["usec"])
	for scale: float in [1.0, 1.5, 2.0]:
		Engine.time_scale = scale
		for cue: String in ["move.blink", "dragon.roar", "cast.arcane", "hit.blunt.heavy", "illusion.spawn"]:
			var entry: Dictionary = bank.cues[cue]["entry"]
			var jitter: float = entry["pitch_jitter"]
			var base: float = float(entry.get("pitch_scale", 1.0))
			for pitch: float in [base * (1.0 - jitter), base, base * (1.0 + jitter)]:
				entry["pitch_jitter"] = 0.0
				entry["pitch_scale"] = pitch
				bank.set_test_clock(bank.now_ms() + 5000)
				var before: int = bank.cues[cue]["played"]
				var deadline: float = bank.presentation_ms() + 100.0 * scale
				bank.play(cue, {"peak_deadline_ms": deadline})
				clock["usec"] = roundi(deadline * 1000.0) - 1
				bank.advance(0.1 * scale)
				_expect(bank.cues[cue]["played"] == before, "Absolute presentation deadline never fires early")
				clock["usec"] += 1
				bank.advance(0.0)
				_expect(bank.cues[cue]["played"] == before + 1, "First tick at the absolute deadline plays the selected cue")
				var played: Dictionary = bank.last_play
				_expect(is_equal_approx(played["selected"]["pitch"], pitch), "Absolute deadline uses the actual forced pitch")
				var peak: float = played["alignment"]["metrics"]["peak_ms"] / pitch
				_expect(absf(peak - 15.0) <= 1.0, "Absolute deadline keeps +15 ms at every pitch and combat scale")
				# A submission already due must dispatch in this process tick,
				# even if this bank's _process callback ran earlier in the frame.
				bank.set_test_clock(bank.now_ms() + 5000)
				var duration: float = bank.play(cue, {"peak_deadline_ms": bank.presentation_ms()})
				_expect(bank.cues[cue]["played"] == before + 2 and bank._peak_pending.is_empty(), "Submitted climax does not wait for another process frame")
				_expect(is_equal_approx(duration, bank.last_play["stream"].get_length() / pitch), "Immediate aligned call returns its actual trimmed playback duration")
			entry["pitch_jitter"] = jitter
			entry["pitch_scale"] = base
	Engine.time_scale = 1.0
	bank.set_test_clock(bank.now_ms() + 5000)
	var before: int = bank.cues["move.blink"]["played"]
	var deadline: float = bank.presentation_ms() + 100.0
	bank.play("move.blink", {"peak_deadline_ms": deadline})
	paused = true
	bank.set_test_clock(bank.now_ms() + 3000)
	bank.advance(3.0)
	_expect(bank.cues["move.blink"]["played"] == before, "Pause freezes the absolute presentation deadline")
	paused = false
	Engine.time_scale = 0.0
	bank.set_test_clock(bank.now_ms() + 3000)
	bank.advance(0.0)
	_expect(bank.cues["move.blink"]["played"] == before, "Hit-stop freezes the absolute presentation deadline")
	Engine.time_scale = 1.0
	bank.advance(0.0)
	_expect(bank.cues["move.blink"]["played"] == before, "Resume cannot consume paused wall time")
	clock["usec"] = roundi((deadline + 7.0) * 1000.0)
	bank.advance(0.107)
	var played: Dictionary = bank.last_play
	_expect(bank.cues["move.blink"]["played"] == before + 1, "Late tick releases the absolute deadline")
	_expect(is_equal_approx(played["alignment"]["late_ms"], 7.0), "Absolute deadline measures lateness in wall time")
	_expect(played["alignment"]["requested_skip_ms"] > played["alignment"]["skip_ms"], "Lateness increases the requested head skip")
	var peak: float = played["alignment"]["metrics"]["peak_ms"] / played["selected"]["pitch"]
	_expect(peak >= 15.0 and peak + 7.0 <= 30.0, "Lateness compensation preserves the minimum pre-peak lead")
	bank.presentation_clock = Callable()
