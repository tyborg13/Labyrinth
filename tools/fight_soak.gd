extends "res://tools/inspection_fixture.gd"
## Live scene lifetime soak. Bot decisions are unchanged; presentation uses the
## production card commit and pass paths. Terminal fights restart from the exact
## same fixture, never inflate HP or change combat rules to prolong a fight.
const Policy = preload("res://tools/bot_policy.gd")
const Metrics = preload("res://tools/fight_soak_metrics.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const DEFAULT_ROUNDS: int = 20
const SETTLE_FRAMES: int = 8
const IDLE_FRAMES: int = 6
const MAX_ROUND_MULTIPLIER: int = 2
const SAMPLE_FPS: int = 120
const BOT_CARDS_PER_ROUND: int = 1
const DEFAULT_HEADLESS_TIME_SCALE: float = 8.0
const VIEWPORT: Vector2i = Vector2i(1920, 1080)

var scene: Node
var fixture: Dictionary
var rows: Array[Dictionary]
var samples: Dictionary = {}
var phase: String = "startup"
var previous_frame_usec: int = 0
var round_count: int = DEFAULT_ROUNDS
var output: String = "user://fight_soak"
var native: bool = false
var hand_sweep: bool = false
var headless_time_scale: float = DEFAULT_HEADLESS_TIME_SCALE
var bouts: int = 0
var cards_played: int = 0
var enemy_rounds: int = 0
var first_census: Dictionary
var report: Dictionary
var check_plateau: bool = false
var replay_policy_cycles: bool = false
var replay_pending: bool = false
var focus_samples: Dictionary = {}

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	# Dummy rendering has no post-draw signal. Match the existing headless
	# section-transition test scheduler; this is lifetime/CPU proof only.
	if DisplayServer.get_name() == "headless": process_frame.connect(_headless_draw_boundary)
	_options = {"scenario": "warband", "seed": DEFAULT_SEED, "warband_biome": "earth", "warband_tier": 2, "warband_case": "encounter", "guardian_id": "craghide", "dragon_id": "vyraketh", "hero_facing": "persist"}
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = 0
	while index < args.size():
		var key: String = args[index]
		if key == "--check": check_plateau = true
		elif key == "--replay-policy-cycles": replay_policy_cycles = true
		elif key == "--native": native = true
		elif key == "--hand-sweep": hand_sweep = true
		else:
			index += 1
			if index >= args.size():
				_fail("Missing value for " + key)
				return
			if key == "--rounds": round_count = int(args[index])
			elif key == "--output-dir": output = args[index]
			elif key == "--headless-time-scale": headless_time_scale = float(args[index])
			elif key in ["--scenario", "--seed", "--warband-biome", "--warband-tier", "--warband-case", "--dragon-id", "--guardian-id"]:
				_options[key.trim_prefix("--").replace("-", "_")] = args[index]
			else:
				_fail("Unknown soak option " + key)
				return
		index += 1
	if headless_time_scale <= 0.0:
		_fail("Headless time scale must be positive")
		return
	if round_count < 20 or str(_options["scenario"]) not in ["warband", "dragon", "guardian", "combat"]:
		_fail("Soak requires >=20 rounds and warband/dragon/guardian/combat")
		return
	if native and DisplayServer.get_name() == "headless":
		_fail("--native requires a real renderer")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	ProgressionStore.set_storage_path(output.path_join("progression.json"))
	ProgressionStore.set_run_storage_path(output.path_join("run.save"))
	Settings.set_storage_path(output.path_join("settings.json"))
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	var progression: Dictionary = Tutorial.dismiss_tutorial(_build_progression())
	fixture = _build_run_state(str(_options["scenario"]), progression)
	if _failed: return
	fixture["progression"] = Tutorial.dismiss_tutorial(fixture.get("progression", progression))
	ProgressionStore.save_data(fixture["progression"])
	ProgressionStore.save_run_state(fixture)
	root.size = VIEWPORT
	root.content_scale_size = VIEWPORT
	Engine.max_fps = SAMPLE_FPS
	OS.low_processor_usage_mode = false
	scene = _make_scene()
	root.add_child(scene)
	await _settle()
	_install(fixture.duplicate(true))
	_close_prompts()
	await _settle()
	if not native: Engine.time_scale = headless_time_scale
	if native: RenderingServer.frame_post_draw.connect(_sample_frame)
	else: process_frame.connect(_sample_frame)
	first_census = Metrics.census(self)
	var board: Node = scene.get("board_view")
	board.call("set_submission_performance_instrumentation_enabled", true)
	var policy := Policy.new()
	policy.engine = scene.get("_combat_engine")
	print("ROUND BOUT TURN NODES ORPHANS OBJECTS RESOURCES STATIC_BYTES PROCESS_MEDIAN_MS PROCESS_P95_MS")
	var round_index: int = 0
	# A card can end a bout before its enemy phase. Keep playing fresh bouts
	# until both the requested hero rounds and enemy phases have executed.
	while round_index < round_count or enemy_rounds < round_count or (replay_policy_cycles and cards_played < round_count):
		if round_index >= round_count * MAX_ROUND_MULTIPLIER:
			_fail("Soak did not reach its requested enemy-phase count")
			return
		if _terminal() or (replay_policy_cycles and (replay_pending or (scene.get("_combat_state") as Dictionary).get("deck", {}).get("hand", []).is_empty())):
			bouts += 1
			replay_pending = false
			_install(fixture.duplicate(true))
			await _settle()
		_close_prompts()
		board.call("reset_render_instrumentation")
		phase = "idle_player"
		for frame: int in range(IDLE_FRAMES): await process_frame
		var idle_cpu: Dictionary = board.call("render_instrumentation_snapshot")
		phase = "hover_preview"
		var state: Dictionary = scene.get("_combat_state")
		if hand_sweep:
			await _hand_sweep_phase(state)
		else:
			if not (state.get("deck", {}).get("hand", []) as Array).is_empty():
				_hover_action("hand_enter", Vector2i(-1, -1), true)
				scene.call("_on_card_hover_started", 0)
				_hover_action("hand_enter", Vector2i(-1, -1), false)
				var hover_board: Control = scene.get("board_view") as Control
				for enemy: Dictionary in state["enemies"]:
					var motion := InputEventMouseMotion.new()
					motion.position = hover_board.call("_tile_center", enemy["pos"])
					_hover_action("target", enemy["pos"], true)
					_send_hover_motion(hover_board, motion)
					_hover_action("target", enemy["pos"], false)
					await _hover_frame(hover_board, motion)
				_hover_action("hand_leave", Vector2i(-1, -1), true)
				scene.call("_on_card_hover_ended", 0)
				_hover_action("hand_leave", Vector2i(-1, -1), false)
		print("SOAK ROUND %d: bot" % (round_index + 1))
		phase = "bot_policy"
		_sampling(false)
		var selected: Dictionary = policy.choose(scene.get("_combat_state"))
		replay_pending = selected.is_empty()
		# Flush the policy search frame before measuring production animation.
		await _settle()
		previous_frame_usec = 0
		_sampling(true)
		if not selected.is_empty():
			var plan: Dictionary = selected["commit"]
			# Includes the bot's legal pre-card movement, accepted by its normal
			# committed-rule adapter. Card animation/analytics remain production.
			var run: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
			run["combat_state"] = preload("res://scripts/battlefield_rules/committed.gd").accept(policy.engine, plan["before"])
			_install(run)
			print("SOAK ROUND %d: card" % (round_index + 1))
			phase = "card_play"
			await scene.call("_play_player_card", int(plan["index"]), plan["resolved"], plan["actions"], _vector2i_array(plan["targets"]))
			cards_played += 1
		var enemy_cpu: Dictionary = {}
		if not _terminal():
			board.call("reset_render_instrumentation")
			print("SOAK ROUND %d: enemy" % (round_index + 1))
			phase = "enemy_turn"
			await scene.call("_on_pass_turn_pressed")
			enemy_rounds += 1
			enemy_cpu = board.call("render_instrumentation_snapshot")
		phase = "settle"
		await _settle()
		_sampling(false)
		var census: Dictionary = Metrics.census(self)
		var row: Dictionary = Metrics.counts()
		row["preview_memo_entries"] = _memo_entries()
		row.merge({"round": round_index + 1, "bout": bouts + 1, "turn": int((scene.get("_combat_state") as Dictionary).get("turn", 0)), "census": census, "idle_cpu": idle_cpu, "enemy_cpu": enemy_cpu, "tree_delta": Metrics.difference(first_census["tree"], census["tree"]), "orphan_delta": Metrics.difference(first_census["orphans"], census["orphans"]), "phases": _phase_stats(), "raw_samples": samples.duplicate(true)})
		rows.append(row)
		phase = "proof_io"
		await _capture_round_proof(round_index + 1)
		var timing: Dictionary = row["phases"].get("enemy_turn", {}).get("process_ms", {})
		print("%d %d %d %d %d %d %d %d %.3f %.3f" % [row["round"], row["bout"], row["turn"], row["nodes"], row["orphans"], row["objects"], row["resources"], row["static_memory_bytes"], timing.get("median", 0.0), timing.get("p95", 0.0)])
		samples.clear()
		round_index += 1
		await _settle()
		previous_frame_usec = 0
		_sampling(true)
	phase = "report"
	if native: RenderingServer.frame_post_draw.disconnect(_sample_frame)
	else: process_frame.disconnect(_sample_frame)
	var errors: Array[String]
	if check_plateau:
		errors = Metrics.replay_plateau_errors(rows) if replay_policy_cycles else Metrics.plateau_errors(rows)
	if check_plateau and not Metrics.census(self)["orphans"].is_empty(): errors.append("Live orphan histogram must be empty")
	if replay_policy_cycles and cards_played < round_count: errors.append("Policy replay soak must commit at least one card per requested round")
	if cards_played == 0 or enemy_rounds == 0: errors.append("Workload failed to play cards and enemy rounds")
	report = {"schema_version": 1, "options": _options, "native": native, "replay_policy_cycles": replay_policy_cycles, "headless_time_scale": headless_time_scale if not native else 1.0, "viewport": [1920, 1080], "ui_scale": 1.0, "cel_environment": OS.get_environment("LABYRINTH_CEL_LOOK"), "engine": Engine.get_version_info(), "machine": {"model": OS.get_model_name(), "processor": OS.get_processor_name(), "os": OS.get_name()}, "debug_build": OS.is_debug_build(), "display": DisplayServer.get_name(), "renderer": RenderingServer.get_video_adapter_name(), "rounds": rows, "cards_played": cards_played, "enemy_rounds": enemy_rounds, "bouts": bouts + 1, "initial_census": first_census, "requested_rounds": round_count, "bot_cards_per_round": BOT_CARDS_PER_ROUND, "process_count_scope": "board _process and _draw section instrumentation; scene/engine section timers", "native_focus_samples": focus_samples, "runtime_sections": scene.call("runtime_performance_instrumentation_snapshot"), "errors": errors}
	board = scene.get("board_view")
	if board.has_method("render_instrumentation_snapshot"): report["board_sections"] = board.call("render_instrumentation_snapshot")
	_write_report()
	scene.queue_free()
	await _settle()
	report["teardown"] = {"counts": Metrics.counts(), "census": Metrics.census(self)}
	if check_plateau and int(report["teardown"]["counts"]["orphans"]) > 2: errors.append("Scene teardown leaked orphan nodes")
	_write_report()
	for error: String in errors: push_error(error)
	print("FIGHT SOAK: %s (%s; %d rounds; %d cards; %d enemy rounds)" % ["PASS" if errors.is_empty() else "FAIL", _options["scenario"], rows.size(), cards_played, enemy_rounds])
	print("FIGHT SOAK REPORT: " + ProjectSettings.globalize_path(output.path_join("report.json")))
	quit(0 if errors.is_empty() else 1)

func _install(run: Dictionary) -> void:
	scene.call("_reset_card_resolution")
	scene.set("_run_state", run)
	scene.set("_combat_state", run["combat_state"])
	scene.set("_animation_lock", false)
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_refresh_ui")

# Attribution companions can substitute instrumented subclasses before the
# scene enters the tree, without altering the production workload or clocks.
func _make_scene() -> Node:
	return (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()

func _hand_sweep_phase(state: Dictionary) -> void:
	phase = "hand_sweep"
	var hand: Array = (state.get("deck", {}) as Dictionary).get("hand", [])
	# This workload deliberately has no board target. Only adjacent hand cards
	# exchange ownership, with leave then enter before the next frame boundary.
	scene.set("_hovered_board_tile", Vector2i(-1, -1))
	for index: int in range(hand.size()):
		if index > 0:
			_hover_action("sweep_leave", Vector2i(-1, -1), true)
			scene.call("_on_card_hover_ended", index - 1)
			_hover_action("sweep_leave", Vector2i(-1, -1), false)
		_hover_action("sweep_enter", Vector2i(-1, -1), true)
		scene.call("_on_card_hover_started", index)
		_hover_action("sweep_enter", Vector2i(-1, -1), false)
		await process_frame
	if not hand.is_empty():
		_hover_action("sweep_leave", Vector2i(-1, -1), true)
		scene.call("_on_card_hover_ended", hand.size() - 1)
		_hover_action("sweep_leave", Vector2i(-1, -1), false)
		await process_frame

func _hover_action(_kind: String, _tile: Vector2i, _begin: bool) -> void:
	pass

func _send_hover_motion(board: Control, motion: InputEventMouseMotion) -> void:
	board.call("_gui_input", motion)

func _hover_frame(_board: Control, _motion: InputEventMouseMotion) -> void:
	await process_frame

func _terminal() -> bool:
	return str((scene.get("_run_state") as Dictionary).get("mode", "")) != "combat" or not _combat_engine.combat_outcome(scene.get("_combat_state")).is_empty()

func _close_prompts() -> void:
	scene.set("_progression", Tutorial.dismiss_tutorial(scene.get("_progression")))
	scene.set("_guided_tutorial_phase_id", "")
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	scene.call("_close_large_map")
	scene.call("_close_menu_overlay")

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES): await process_frame

func _sample_frame() -> void:
	if native:
		var focus_key: String = "focused" if root.has_focus() else "unfocused"
		focus_samples[focus_key] = int(focus_samples.get(focus_key, 0)) + 1
	if not samples.has(phase): samples[phase] = {"process_ms": [], "frame_interval_ms": []}
	var now: int = Time.get_ticks_usec()
	(samples[phase]["process_ms"] as Array).append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	if previous_frame_usec > 0: (samples[phase]["frame_interval_ms"] as Array).append(float(now - previous_frame_usec) / 1000.0)
	previous_frame_usec = now

func _phase_stats() -> Dictionary:
	var result: Dictionary = {}
	for key: String in samples:
		result[key] = {"process_ms": Metrics.stats(samples[key]["process_ms"]), "frame_interval_ms": Metrics.stats(samples[key]["frame_interval_ms"])}
	return result

func _write_report() -> void:
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	file = FileAccess.open(output.path_join("rounds.tsv"), FileAccess.WRITE)
	file.store_line("round\tbout\tturn\tnodes\torphans\tobjects\tresources\tstatic_memory_bytes\tenemy_process_median_ms\tenemy_process_p95_ms")
	for row: Dictionary in rows:
		var timing: Dictionary = row["phases"].get("enemy_turn", {}).get("process_ms", {})
		file.store_line("%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%.3f\t%.3f" % [row["round"], row["bout"], row["turn"], row["nodes"], row["orphans"], row["objects"], row["resources"], row["static_memory_bytes"], timing.get("median", 0.0), timing.get("p95", 0.0)])
	file.close()

func _headless_draw_boundary() -> void:
	RenderingServer.frame_post_draw.emit()

func _capture_round_proof(_round_index: int) -> void:
	pass

func _sampling(enabled: bool) -> void:
	var boundary: Signal = RenderingServer.frame_post_draw if native else process_frame
	if enabled and not boundary.is_connected(_sample_frame): boundary.connect(_sample_frame)
	elif not enabled and boundary.is_connected(_sample_frame): boundary.disconnect(_sample_frame)

func _memo_entries() -> Dictionary:
	var rules: GDScript = preload("res://scripts/battlefield_rules/dispatcher.gd")
	var view: GDScript = preload("res://scripts/battlefield_rule_view.gd")
	return {"rule_forecast": rules._forecast_memo._entries.size(), "rule_tiles": view._memo._entries.size(), "rule_ghosts": view._ghost_memo._entries.size()}
