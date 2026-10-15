extends SceneTree

const Bank = preload("res://scripts/sfx_bank.gd")
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
	# Shared-sample alignment uses the selected pitch, including both jitter bounds.
	for cue: String in ["move.blink", "dragon.roar"]:
		var stream: AudioStream = bank.cues[cue]["streams"][0]
		var jitter: float = bank.cues[cue]["entry"]["pitch_jitter"]
		for pitch: float in [1.0 - jitter, 1.0, 1.0 + jitter]:
			for climax: float in [0.0, 316.673, 566.678]:
				var plan: Dictionary = Bank.PeakAlignment.plan(stream, pitch, climax)
				var trimmed: Dictionary = Bank.PeakAlignment.trimmed(stream, pitch, plan["skip_ms"])
				var peak: float = float(trimmed["metrics"]["peak_ms"]) / pitch
				_expect(peak >= 15.0 and absf(float(plan["delay_ms"]) + peak - climax - 15.0) < 0.1, "Per-call peak targets +15 ms at every approved pitch bound")
	bank.set_test_clock(FIXTURE_CLOCK_MS + 5000)
	starts.clear()
	var previous: int = bank.cues["move.blink"]["last_ms"]
	bank.play("move.blink", {"peak_climax_ms": 500.0})
	_expect(starts.is_empty() and bank.cues["move.blink"]["last_ms"] == previous, "A future peak queues only that call and does not consume cooldown")
	bank.play("status.freeze")
	_expect(starts.size() == 1 and starts[0]["cue"] == "status.freeze", "An unrelated cue starts while a peak-aligned call waits")
	var pending: Dictionary = bank._peak_pending[0]
	var due: float = pending["selected"]["due_ms"]
	bank.set_test_clock(floori(due))
	bank.advance(0.0)
	_expect(starts.size() == 1, "The aligned call cannot start before its due time")
	bank.set_test_clock(ceili(due) + 16)
	bank.advance(0.017)
	_expect(starts.size() == 2 and starts.back()["cue"] == "move.blink", "The due call plays independently on the next scheduler tick")
	var aligned: Dictionary = bank.last_play["alignment"]
	var relative: float = bank.now_ms() - (FIXTURE_CLOCK_MS + 5000) + float(aligned["metrics"]["peak_ms"]) / float(bank.last_play["selected"]["pitch"]) - 500.0
	_expect(relative >= 0.0 and relative <= 30.0, "Scheduler overshoot is compensated without shifting the target peak")
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
