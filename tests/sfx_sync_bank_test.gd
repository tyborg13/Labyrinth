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
	for index: int in range(4):
		router.hit({"type": "aoe", "element": "fire", "damage": 3}, {}, "", {"id": index, "hp": 10}, {"hp": 7})
	_expect(starts.size() == 3 and starts.all(func(row: Dictionary) -> bool: return row["result"] == "played" and row["time"] == FIXTURE_CLOCK_MS), "Area impacts retain the three-instance cap and start on the same frame")
	bank.set_test_clock(FIXTURE_CLOCK_MS + 1000)
	bank.advance(1.0)
	_expect(starts.size() == 3, "Advancing the clock cannot release delayed area voices")
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
	limited.play("fixture", {"area_instance": true, "gain_db": Router.AREA_GAIN_DB})
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
