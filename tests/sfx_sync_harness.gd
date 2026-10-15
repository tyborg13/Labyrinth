extends SceneTree

const Alignment = preload("res://scripts/sfx_peak_alignment.gd")
const Clock = preload("res://tests/sfx_sync_clock.gd")
const FixedPacing = preload("res://tests/sfx_sync_pacing.gd")
const Bank = preload("res://scripts/sfx_bank.gd")
const Router = preload("res://scripts/sfx_cue_router.gd")
const MotionFixture = preload("res://tests/suites/combat_motion_timing_suite.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const SupportCases = preload("res://tests/sfx_sync_support.gd")
const Sources = preload("res://tests/sfx_sync_sources.gd")
const Coverage = preload("res://tests/sfx_sync_coverage.gd")
const Visuals = preload("res://tests/sfx_sync_visuals.gd")
const Fx = preload("res://scripts/attack_fx_library.gd")
const INPUT_ANCHORS: Array = ["_on_card_pressed", "_on_card_drag_started", "_begin_card_preview", "_on_card_hover_started", "_on_board_tile_clicked", "_on_map_view_room_selected", "_on_section_map_event", "_on_merchant_buy_pressed", "_on_merchant_sell_pressed", "_refresh_relic_bar", "_update_ambient_sfx_for_context"]
const FIXTURE_SEED: int = 410
const MAX_ACTION_FRAMES: int = 600
const SETTLE_FRAMES: int = 12
const CASE_GAP_USEC: int = 5000000
var clock := Clock.new()
var scene: Node
var bank: Node
var router: RefCounted
var events: Array[Dictionary]
var rows: Array[Dictionary]
var failures: Array[String]
var scenario: String = ""
var completed: bool = false
var source: String
var walk_goal: Vector2
var walk_actor: String = ""
var walk_goals: Dictionary = {}
var silence_rows: Array[Dictionary]
var measured_samples: Dictionary = {}
var assert_onsets: bool = false
var supplied_sources: Dictionary = {}
var source_hashes: Dictionary = {}

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--samples="):
			measured_samples = JSON.parse_string(FileAccess.get_file_as_string(argument.trim_prefix("--samples=")))
		if argument == "--assert-onsets": assert_onsets = true
		if argument.begins_with("--sources="):
			supplied_sources = JSON.parse_string(FileAccess.get_file_as_string(argument.trim_prefix("--sources=")))
	if assert_onsets and measured_samples.is_empty():
		measured_samples = Coverage.measured_samples(failures)
		if not failures.is_empty():
			for failure: String in failures: push_error(failure)
			quit(1)
			return
	source_hashes = Sources.hashes(supplied_sources)
	# Compile the production scene verbatim except its clock/timer providers and
	# an observer at the board submission boundary. No action or cue logic is
	# replaced. Source line numbers are preserved for the audit's call sites.
	source = Sources.read_source("scripts/run_scene.gd", supplied_sources)
	var instrumented: String = source.replace("Time.get_ticks_usec()", "_sfx_sync_clock.usec").replace("Time.get_ticks_msec()", "int(_sfx_sync_clock.usec / 1000)")
	instrumented = instrumented.replace('const SfxBankScript = preload("res://scripts/sfx_bank.gd")', 'var SfxBankScript: Script')
	instrumented = instrumented.replace('const SfxCueRouterScript = preload("res://scripts/sfx_cue_router.gd")', 'var SfxCueRouterScript: Script')
	instrumented = instrumented.replace("get_tree().create_timer(", "_sfx_sync_clock.create_timer(")
	instrumented = instrumented.replace("\tboard_view.present_sound_snapshot(display_state, presentation)", "\t_sfx_sync_clock.render(display_state, presentation, get_stack()); board_view.present_sound_snapshot(display_state, presentation)")
	instrumented += "\nvar _sfx_sync_clock: RefCounted\n"
	var instrumented_lines: PackedStringArray = instrumented.split("\n")
	var input_method: String = ""
	for index: int in range(instrumented_lines.size()):
		var line: String = instrumented_lines[index]
		if line.begins_with("func "):
			var method: String = line.trim_prefix("func ").get_slice("(", 0)
			input_method = method if INPUT_ANCHORS.has(method) else ""
		elif not input_method.is_empty() and line.begins_with("\t") and not line.strip_edges().begins_with("#") and not line.strip_edges().is_empty():
			instrumented_lines[index] = '\t_sfx_sync_clock.mark("' + input_method + '", get_stack()); ' + line.trim_prefix("\t")
			input_method = ""
	instrumented = "\n".join(instrumented_lines)
	var script: GDScript = Sources.compile_script("scripts/run_scene.gd", instrumented)
	var bank_script: GDScript = Sources.bank(supplied_sources)
	var router_script: GDScript = Sources.compile_script("scripts/sfx_cue_router.gd", Sources.read_source("scripts/sfx_cue_router.gd", supplied_sources))
	if script == null or bank_script == null or router_script == null:
		push_error("SFX sync: production scene instrumentation failed to compile")
		quit(1)
		return
	scene = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	scene.get("_combat_pacing").free()
	scene.set_script(script)
	scene.set("SfxBankScript", bank_script)
	scene.set("SfxCueRouterScript", router_script)
	scene.set("_sfx_sync_clock", clock)
	scene.get("_combat_pacing").free()
	var pacing := FixedPacing.new()
	pacing.sync_clock = clock
	scene.set("_combat_pacing", pacing)
	pacing.install(scene)
	root.add_child(scene)
	for index: int in range(SETTLE_FRAMES): clock.step(self)
	MotionFixture._install_fixture(scene, false)
	scene.call("_ensure_sfx_bank")
	bank = scene.get("_sfx_bank")
	clock.bank = bank
	bank.set_test_clock(clock.usec / 1000)
	router = scene.get("_sfx_router")
	bank.cue_requested.connect(_record)
	_drive_actions()
	_drive_presentations()
	_drive_support()
	if assert_onsets: Coverage.verify(rows, silence_rows, bank.data["cues"], failures)
	_write_report()
	clock.observing = false
	clock.timers.clear()
	bank.cue_requested.disconnect(_record)
	scene.queue_free()
	await process_frame
	for failure: String in failures: push_error(failure)
	print("SFX SYNC HARNESS RESULT: %s (%d observations, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", rows.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)

func _record(cue: String, result: String) -> void:
	if not clock.observing or not bank.data["cues"].has(cue): return
	var voice: AudioStreamPlayer
	for player: AudioStreamPlayer in bank.cues[cue]["voices"]:
		if voice == null or int(player.get_meta("serial", -1)) > int(voice.get_meta("serial", -1)): voice = player
	var source_entry: Dictionary = bank._source_entry(cue)
	var paths: Array = source_entry.get("variants", [])
	if paths.is_empty(): paths = source_entry.get("fallback", [])
	var sample: String = str(paths[posmod(int(bank.cues[cue]["next"]) - 1, paths.size())]) if not paths.is_empty() else ""
	var aligned: Dictionary = {}
	if result == "played" and bank.get("last_play") != null and str(bank.last_play.get("cue", "")) == cue:
		var played: Dictionary = bank.last_play
		aligned = played["alignment"].duplicate(true)
		if not aligned.is_empty():
			_verify_faded_pcm(played)
			aligned["fade_and_tail_verified"] = played["alignment"]["fade_and_tail_verified"]
			var path: String = ProjectSettings.globalize_path(_report_path()).get_base_dir().path_join("sfx-sync-pcm-%d-%d.wav" % [rows.size(), events.size()])
			(played["stream"] as AudioStreamWAV).save_to_wav(path)
			aligned["pcm_path"] = path
			sample = str(paths[int(played["selected"]["sample_index"])])
	var targets: Dictionary = router.get("_merged_hits")
	var target_key: String = str(targets.keys().back()) if not targets.is_empty() else ""
	events.append({"target_key": target_key, "cue": cue, "result": result, "play_ms": float(clock.usec) / 1000.0,
		"stack": bank.scheduled_stack if not bank.scheduled_stack.is_empty() else get_stack(), "pitch": voice.pitch_scale if voice != null else 1.0,
		"gain_db": voice.volume_db if voice != null else 0.0, "sample": sample, "alignment": aligned})

func _begin(label: String) -> void:
	clock.observing = false
	scene.get("_combat_pacing").end_scope()
	scene.get("_intent_callouts").set("_announced", {})
	clock.step(self, CASE_GAP_USEC)
	scene.get("_intent_callouts").set("_announced", {})
	# A real scene may start with a random run's ambient bed. Each fixture owns
	# its initial loop state, so context cases cannot inherit that startup bed.
	bank.stop_loop(true)
	scene.set("_active_ambient_sfx_id", "")
	scenario = label
	walk_actor = ""
	walk_goals.clear()
	events.clear()
	clock.frames.clear()
	clock.observing = true

func _state() -> Dictionary:
	return (scene.get("_combat_state") as Dictionary).duplicate(true)

func _invoke(method: String, args: Array) -> void:
	completed = false
	_track(method, args)
	for index: int in range(MAX_ACTION_FRAMES):
		if completed: break
		clock.step(self)
	if not completed:
		failures.append("Fixed-clock action did not finish: " + scenario)
		print("SFX_SYNC_PENDING=", scenario, " ", clock.frames.back().get("stack", []) if not clock.frames.is_empty() else [], " pacing=", scene.get("_combat_pacing").get("_phase"))
	# Flush area scheduling without changing the recorded visual anchor.
	for index: int in range(8): clock.step(self)

func _track(method: String, args: Array) -> void:
	await scene.callv(method, args)
	completed = true

func _drive_actions() -> void:
	for kind: String in ["blink", "illusion_swap", "swap"]:
		_begin("player/" + kind)
		var before: Dictionary = _state()
		var after: Dictionary = before.duplicate(true)
		after["player"]["pos"] = Vector2i(4, 4)
		if kind == "swap":
			before["enemies"][0]["pos"] = Vector2i(4, 4)
			after["enemies"][0]["pos"] = before["player"]["pos"]
		_invoke("_animate_player_action_step", [before, after, "shadow_step", {"type": kind, "range": 4}, Vector2i(4, 4)])
		if supplied_sources.is_empty() and events.filter(func(e: Dictionary) -> bool: return e["cue"] == "move.blink" and e["result"] == "played").size() != 1:
			failures.append("Player transition must play exactly one blink: " + kind)
		_finish(before)
	_begin("movement/relay_blink")
	var state: Dictionary = _state()
	state["relics"] = ["unclouded_sun"]
	state["umbra"]["light_sources"] = [{"owner": "player", "pos": state["player"]["pos"], "radius": 0, "remaining_activations": 2}, {"owner": "player", "pos": Vector2i(4, 4), "radius": 0, "remaining_activations": 2}]
	var relay_after: Dictionary = state.duplicate(true)
	relay_after["player"]["pos"] = Vector2i(4, 4)
	_invoke("_animate_player_action_step", [state, relay_after, "step", {"type": "move", "range": 5, "amount": 5}, Vector2i(4, 4)])
	_finish(state)
	for kind: String in ["melee", "ranged", "aoe"]:
		_begin("player_attack/" + kind)
		var before: Dictionary = _state()
		var after: Dictionary = before.duplicate(true)
		after["enemies"][0]["hp"] -= 3
		_invoke("_animate_player_action_step", [before, after, "lantern_shot", {"type": kind, "range": 5, "damage": 3}, before["enemies"][0]["pos"]])
		_finish(before)

func _drive_presentations() -> void:
	# Every contact is submitted through the real run-scene board presentation.
	# The fixture clock measures SfxBank's actual play call, including scheduled
	# area voices. Payloads are deliberately debug-only combat states.
	for weapon: String in ["sword", "maul", "spear", ""]:
		for damage: int in [3, 6]:
			_present_hit("weapon/" + weapon + "/" + str(damage), {"type": "melee", "damage": damage}, weapon, 4)
	for element: String in ["fire", "ice", "lightning", "earth", "air", "shadow"]:
		_present_hit("element/" + element, {"type": "ranged", "element": element, "damage": 3}, "", 4)
	_present_hit("area/single", {"type": "aoe", "element": "fire", "damage": 3}, "", 1, {}, {}, true)
	_present_hit("area/same_frame", {"type": "aoe", "element": "fire", "damage": 3}, "", 3, {}, {}, true)
	_present_hit("area/fire", {"type": "aoe", "element": "fire", "damage": 3}, "", 4)
	_present_hit("collision", {"type": "push", "collision": true, "damage": 3}, "", 4)
	_present_hit("blocked", {"type": "melee", "damage": 0}, "sword", 4, {"block": 3})
	_present_hit("block_break", {"type": "melee", "damage": 6}, "sword", 4, {"block": 3})
	_present_hit("shatter", {"type": "melee", "damage": 3}, "sword", 4, {"freeze": 1})
	_present_hit("area/claw", {"type": "melee", "damage": 3}, "", 4, {}, {"type": "crawler"})
	for status: String in ["block", "stoneskin", "bleed", "freeze", "shock", "stagger"]:
		_begin("status/" + status)
		var before: Dictionary = _state()
		var after: Dictionary = before.duplicate(true)
		after["player"][status] = 3
		router.begin_player_action(before, {"type": "fixture"})
		scene.call("_render_board_state", after, {"impact_actor_keys": ["player"]})
		_finish(before)
	for type: String in ["player", "crawler", "acolyte", "harrier", "warden", "cinder_ooze", "lightning_wisp", "gallows_roc", "tharokh"]:
		_begin("death/" + type)
		var before: Dictionary = _state()
		router.begin_player_action(before, {"type": "fixture"})
		var unit: Dictionary = {"type": type, "hp": 0, "pos": Vector2i(3, 3), "death_animation": true, "death_frame": 0, "key": "player" if type == "player" else "enemy_99"}
		if type != "player": unit["id"] = type
		scene.call("_render_board_state", before, {"death_animation_units": [unit]})
		_finish(before)

func _present_hit(label: String, action: Dictionary, weapon: String, count: int = 1, target_fields: Dictionary = {}, actor: Dictionary = {}, simultaneous: bool = false) -> void:
	_begin(label)
	if simultaneous:
		bank.cues["spell.fire"]["rng"].seed = FIXTURE_SEED
		bank.cues["spell.fire"]["next"] = 0
	var before: Dictionary = _state()
	before["enemies"] = []
	for index: int in range(count):
		var unit: Dictionary = {"id": 100 + index, "type": "crawler", "hp": 12, "pos": Vector2i(3 + index, 4), "block": 0}
		unit.merge(target_fields, true)
		before["enemies"].append(unit)
	var after: Dictionary = before.duplicate(true)
	for unit: Dictionary in after["enemies"]:
		unit["hp"] -= int(action.get("damage", 0))
		unit["block"] = 0
	if actor.is_empty(): router.begin_player_action(before, action, weapon)
	else: router.begin_enemy_action(before, action, actor)
	var effect: Dictionary = action.duplicate(true)
	effect["kind"] = action["type"]
	effect["from"] = before["player"]["pos"]
	effect["to"] = before["enemies"][0]["pos"]
	var contacts: Dictionary = {"count": 0}
	var display: Dictionary = before.duplicate(true)
	var frame_count: int = Fx.animation_frame_count(effect, scene.ATTACK_FRAMES, false)
	var frame_seconds: float = Fx.animation_frame_seconds(effect, scene.ATTACK_FRAME_SECONDS, false)
	_invoke("_play_timed_animation_frames", [frame_count, frame_seconds, func(frame_number: int) -> void:
		var progress: float = float(frame_number) / float(frame_count)
		var shown: Dictionary = {"effect": effect, "effect_progress": progress}
		var contact: bool = progress >= float(scene.call("_attack_feedback_start_progress", effect))
		if contact:
			var next_count: int = count if simultaneous else mini(count, int(contacts["count"]) + 1)
			for index: int in range(next_count): display["enemies"][index] = after["enemies"][index]
			contacts["count"] = next_count
			shown["impact_actor_keys"] = scene.call("_player_action_impact_actor_keys", before, after)
			shown["floating_texts"] = scene.call("_player_action_floating_texts", before, after)
		scene.call("_render_board_state", display if contact else before, shown)
	])
	if supplied_sources.is_empty() and simultaneous and events.filter(func(e: Dictionary) -> bool: return e["cue"] == "spell.fire" and e["result"] == "played").size() != 1:
		failures.append("Same-frame area must have one primary voice")
	_finish(before)

func _drive_support() -> void:
	SupportCases.run(self)

func _finish(before: Dictionary) -> void:
	var occurrences: Dictionary = {}
	for event: Dictionary in events:
		var cue: String = event["cue"]
		var occurrence: int = int(occurrences.get(cue, 0))
		occurrences[cue] = occurrence + 1
		var anchor: Dictionary = _anchor(cue, before, event, occurrence)
		var climax: Dictionary = Visuals.climax(str(event["cue"]), clock.frames, anchor)
		rows.append({"scenario": scenario, "cue": event["cue"], "result": event["result"],
			"play_ms": event["play_ms"], "anchor_ms": anchor.get("time_ms"),
			"delay_ms": float(event["play_ms"]) - float(anchor["time_ms"]) if not anchor.is_empty() else null,
			"stack": event["stack"], "anchor_stack": anchor.get("stack", []),
			"climax_applicable": climax.get("applicable", true), "climax_kind": climax.get("kind", "missing"),
			"climax_ms": climax.get("time_ms"), "climax_stack": climax.get("stack", []),
			"climax_after_trigger_ms": float(climax["time_ms"]) - float(anchor["time_ms"]) if climax.has("time_ms") and not anchor.is_empty() else null,
			"pitch": event["pitch"], "sample": event["sample"], "gain_db": event["gain_db"], "alignment": event.get("alignment", {})})
		if assert_onsets and event["result"] == "played":
			_assert_onset(rows.back())
	clock.observing = false

func _assert_onset(row: Dictionary) -> void:
	var cue: String = row["cue"]
	if row["delay_ms"] == null:
		failures.append("Missing visual anchor: %s / %s" % [scenario, cue])
		return
	var delay: float = float(row["delay_ms"])
	var entry: Dictionary = bank.data["cues"][cue]
	if bool(entry.get("loop", false)):
		if not is_zero_approx(delay): failures.append("Loop waits after its state change: " + cue)
		return
	var aligned: Dictionary = row.get("alignment", {})
	if not aligned.is_empty():
		var pitch: float = row["pitch"]
		var peak: float = float(aligned["metrics"]["peak_ms"]) / pitch
		if row["climax_after_trigger_ms"] == null:
			failures.append("Missing aligned visual climax: " + scenario)
		else:
			var relative: float = delay + peak - float(row["climax_after_trigger_ms"])
			if relative < 0.0 or relative > 30.0: failures.append("Per-call RMS peak outside climax + 0..30 ms: %s / %s (%.3f)" % [scenario, cue, relative])
		if peak < 15.0 - 1000.0 / float(aligned["rate"]) / pitch: failures.append("Head skip retained less than 15 ms before peak: " + scenario)
		if float(aligned["metrics"]["perceived_onset_ms"]) / pitch > Visuals.onset_cap(cue): failures.append("Aligned perceived onset exceeds cap from scheduled start: " + scenario)
		return
	var source_entry: Dictionary = bank._source_entry(cue)
	var paths: Array = source_entry.get("variants", [])
	if paths.is_empty(): paths = source_entry.get("fallback", [])
	var minimum_pitch: float = float(entry.get("pitch_scale", 1.0)) * (1.0 - float(entry.get("pitch_jitter", 0.0)))
	var maximum_pitch: float = float(entry.get("pitch_scale", 1.0)) * (1.0 + float(entry.get("pitch_jitter", 0.0)))
	for path: String in paths:
		if not measured_samples.has(path):
			failures.append("Unmeasured sample: " + path)
			continue
		var lead: float = float(measured_samples[path]["leading_ms"])
		if delay + lead / maximum_pitch < 0.0 or delay + lead / minimum_pitch > 20.0 or lead > 10.0:
			failures.append("Onset outside director window: %s / %s (delay %.3f ms, sample %.3f ms)" % [scenario, cue, delay, lead])
		var perceived: float = delay + float(measured_samples[path]["perceived_onset_ms"]) / minimum_pitch
		if perceived > Visuals.onset_cap(cue):
			failures.append("Perceived onset exceeds cap: %s / %s (%.3f ms)" % [scenario, cue, perceived])
		if bool(row["climax_applicable"]):
			if row["climax_after_trigger_ms"] == null:
				failures.append("Missing visual climax: %s / %s" % [scenario, cue])
			elif delay + float(measured_samples[path]["peak_ms"]) / minimum_pitch > float(row["climax_after_trigger_ms"]) + 30.0:
				failures.append("Sample peak trails visual climax: %s / %s" % [scenario, cue])
			elif bool(measured_samples[path].get("peak_aligned", false)) and delay + float(measured_samples[path]["peak_ms"]) / maximum_pitch < float(row["climax_after_trigger_ms"]):
				failures.append("Rebuilt sample peak precedes visual climax: %s / %s" % [scenario, cue])

func _anchor(cue: String, before: Dictionary, event: Dictionary = {}, occurrence: int = 0) -> Dictionary:
	var segment: int = -1
	var previous_tile: Variant = null
	for frame: Dictionary in clock.frames:
		var shown: Dictionary = frame["shown"]
		var state: Dictionary = frame["state"]
		if frame.has("mark"):
			if cue.begins_with("card.") or cue.begins_with("map.") or cue.begins_with("event.") or cue.begins_with("shop.") or cue.begins_with("ambience.") or cue in ["defiance", "omen.bane", "omen.blessing"]: return frame
			continue
		if cue == "move.blink" and scenario == "player/swap" and state.get("player", {}).get("pos") != before["player"]["pos"]: return frame
		if cue == "move.blink" and str(shown.get("effect", {}).get("kind", "")) == "blink": return frame
		if scenario == "enemy/eclipse" and cue == "spell.shadow" and shown.has("effect"): return frame
		if cue.begins_with("swing.") and not (shown.get("effect", {}) as Dictionary).is_empty(): return frame
		if cue.begins_with("death.") and not (shown.get("death_animation_units", []) as Array).is_empty(): return frame
		if cue.begins_with("hit.") or cue.begins_with("spell.") or cue in ["block.break", "hurt.hero", "status.shatter", "push.collision"]:
			if shown.has("impact_actor_keys"):
				var key: String = event.get("target_key", "")
				var old_units: Dictionary = router._unit_snapshot(before)
				var units: Dictionary = router._unit_snapshot(state)
				if key.is_empty() or units.get(key, {}) != old_units.get(key, {}): return frame
		elif cue.begins_with("status.") or cue in ["block.gain", "stoneskin.gain"]:
			if state != before: return frame
		elif cue in ["cast.arcane", "shot.bow", "shot.crossbow"]:
			if not shown.get("effect", {}).is_empty():
				if cue == "cast.arcane" or float(shown.get("effect_progress", 0.0)) >= 0.18: return frame
		elif cue == "fatigue":
			if shown.has("impact_actor_keys"): return frame
		elif cue == "heal":
			if int(state.get("player", {}).get("hp", 0)) > int(before.get("player", {}).get("hp", 0)): return frame
		elif cue in ["illusion.spawn", "illusion.break"]:
			if state.get("illusions", []) != before.get("illusions", []): return frame
		elif cue.begins_with("crate."):
			if state.get("terrain", []) != before.get("terrain", []): return frame
		elif cue.begins_with("surface.") or cue == "trap.trigger":
			if shown.has("surface_feedback_events") or shown.has("trap_effects"): return frame
		elif cue in ["radiance.light", "relic.trigger", "card.exhaust", "deck.shuffle"]: return frame
		elif cue.begins_with("step.") or cue == "dragon.wings":
			if shown.has("unit_world_positions"):
				var tile: Variant = shown.get("unit_draw_tiles", {}).get(walk_actor)
				if tile != previous_tile:
					segment += 1
					previous_tile = tile
				if segment != occurrence: continue
				var goal: Vector2 = walk_goals.get(tile, walk_goal)
				if cue == "dragon.wings" or (shown["unit_world_positions"].get(walk_actor, Vector2.INF) as Vector2).is_equal_approx(goal): return frame
		elif cue in ["vocal.beast", "dragon.roar", "push.slide"]:
			if shown.has("effect") or shown.has("focus_actor_keys"): return frame
		elif cue.begins_with("pickup."):
			if state.get("loot", []) != before.get("loot", []): return frame
	return {}

func _report_path() -> String:
	var path: String = "user://sfx_sync_trace.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): path = argument.trim_prefix("--output=")
	return path

func _write_report() -> void:
	var path: String = _report_path()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"rows": rows, "silences": silence_rows, "failures": failures, "frame_usec": Clock.FRAME_USEC, "source_sha256": source_hashes}, "\t"))
	print("SFX_SYNC_TRACE=" + ProjectSettings.globalize_path(path))

func _verify_faded_pcm(played: Dictionary) -> void:
	var alignment: Dictionary = played["alignment"]
	var wav: AudioStreamWAV = played["stream"]
	var source_pcm: PackedVector2Array = Alignment.decoded(played["selected"]["resource"])["pcm"]
	var offset: int = alignment["offset_frames"]
	var fade: int = alignment["fade_frames"]
	var data: PackedByteArray = wav.data
	var correct: bool = data.size() / 4 == source_pcm.size() - offset
	for index: int in range(data.size() / 4):
		var actual := Vector2(data.decode_s16(index * 4), data.decode_s16(index * 4 + 2)) / 32768.0
		var expected: Vector2 = source_pcm[index + offset]
		if index < fade: expected *= float(index) / float(fade - 1)
		if absf(actual.x - expected.x) > 1.0 / 32768.0 or absf(actual.y - expected.y) > 1.0 / 32768.0:
			correct = false
			break
	if data.decode_s16(0) != 0 or data.decode_s16(2) != 0: correct = false
	if absf(float(fade) * 1000.0 / wav.mix_rate / float(played["selected"]["pitch"]) - 3.0) > 1000.0 / wav.mix_rate: correct = false
	if not correct: failures.append("Actual 3 ms linear PCM ramp or complete unchanged tail failed: " + scenario)
	alignment["fade_and_tail_verified"] = correct
