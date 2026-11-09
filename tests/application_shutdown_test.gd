extends SceneTree

const Shutdown = preload("res://scripts/application_shutdown.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Recovery = preload("res://scripts/opening_boon_recovery.gd")
const DemoEnd = preload("res://scripts/demo_end_panel.gd")
const Bindings = preload("res://scripts/card_display_bindings.gd")
const Display = preload("res://scripts/card_display_overrides.gd")
const Data = preload("res://scripts/game_data.gd")
const Measurements = preload("res://scripts/card_summary_measurements.gd")
const Clock = preload("res://scripts/presentation_clock.gd")
const Writer = preload("res://scripts/ordered_background_writer.gd")
const CHECKPOINT: int = 84
const MEASUREMENT_FONT_SIZE: int = 20
var _failures: Array[String]
var _assertions: int = 0
var _flush_order: Array[String]
var _font: Font

class ExitProducer extends Node:
	func _exit_tree() -> void:
		Progression.queue_run_state({"surface_rules_version": Progression.SURFACE_RULES_VERSION, "checkpoint": CHECKPOINT})
		var events := Analytics.new()
		events.deferred_writes = true
		events.write_event("qa84_final_exit")

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	Progression.set_run_storage_path("user://qa84_shutdown/run.save")
	Analytics.set_storage_dir("user://qa84_shutdown/analytics")
	_font = ThemeDB.fallback_font
	Measurements.text_width(_font, MEASUREMENT_FONT_SIZE, "shutdown")
	var connection: Callable = Measurements._font_changed.bind(_font.get_instance_id())
	_check(_font.changed.is_connected(connection), "retained font really owns a script callback")
	var resolver: Callable = func(state: Dictionary) -> Dictionary: return Data.card_def_for_progression("quick_stab", state)
	Bindings.projection(Bindings.context({}), "quick_stab", resolver, null, Display.for_card)
	_check(Bindings.definition_count() > 0, "projection fixture retains a lambda identity")
	DemoEnd.shell_open = func(_url: String) -> int: return OK
	DemoEnd.store_page_override_for_test = func() -> void: pass
	Clock._ticker = Clock.MovieTicker.new()
	Clock._ticker.set("sync", Clock._sync_movie_frame)
	var ticker: Node = Clock._ticker
	root.add_child(ticker)
	# A final failed callback must be attempted before its closure is released.
	# This does not touch disk or replace existing failure assertions.
	Progression._run_writer.submit(func() -> bool: _flush_order.append("save"); return false)
	Analytics._writer.submit(func() -> bool: _flush_order.append("analytics"); return true)
	var other_writer := Writer.new()
	other_writer.submit(func() -> bool: _flush_order.append("other_namespace"); return true)
	Analytics._writers_by_directory["qa84_other_namespace"] = other_writer
	_check(not Shutdown.finish(), "final barrier reports the original save failure")
	_check(_flush_order == ["save", "analytics", "other_namespace"], "save attempt precedes every analytics namespace even when it fails")
	_check(not other_writer.busy(), "inactive analytics namespace flushed before release")
	_check(not Progression._run_writer.busy() and not Analytics._writer.busy(), "failed jobs release only after the final attempt")
	_check(not Recovery.profile_writer.is_valid(), "default cross-script profile writer released")
	_check(not DemoEnd.shell_open.is_valid() and not DemoEnd.store_page_override_for_test.is_valid(), "both demo-driver static lambdas released")
	_check(Bindings._contexts.is_empty() and Bindings._definitions.is_empty() and Bindings._definition_order.is_empty(), "all projection identity owners released")
	_check(not _font.changed.is_connected(connection) and Measurements._fonts.is_empty(), "font callback disconnected before cache release")
	_check(Clock._ticker == null and not (ticker.get("sync") as Callable).is_valid(), "movie ticker callable released while node is valid")
	_check(Shutdown.finish(), "repeated empty shutdown is safe")
	# Re-populate after the direct helper test. Observe the real root exit hook,
	# installed by SteamService, without explicitly flushing these final writes.
	Recovery.profile_writer = Progression.save_data
	DemoEnd.store_page_override_for_test = func() -> void: pass
	Measurements.text_height(_font, MEASUREMENT_FONT_SIZE)
	Bindings.projection(Bindings.context({}), "quick_stab", resolver, null, Display.for_card)
	root.add_child(ExitProducer.new())
	Shutdown.install(root) # Idempotent: one callback across service test doubles.
	var hook_count: int = 0
	for entry: Dictionary in root.tree_exiting.get_connections():
		if entry["callable"] == Shutdown.finish: hook_count += 1
	_check(hook_count == 1, "one root shutdown hook")
	root.tree_exiting.connect(_after_shutdown)
	quit(0 if _failures.is_empty() else 1)

func _after_shutdown() -> void:
	_check(Progression.load_saved_run().get("checkpoint") == CHECKPOINT, "scene exit checkpoint durable before release")
	var events: Array[Dictionary] = Analytics.load_all_events()
	_check(events.size() == 1 and events[0]["event_type"] == "qa84_final_exit", "scene exit analytics durable before release")
	_check(not Recovery.profile_writer.is_valid() and not DemoEnd.store_page_override_for_test.is_valid(), "real engine quit invokes callable cleanup")
	_check(Bindings.definition_count() == 0 and Measurements._fonts.is_empty(), "real engine quit clears static cache and font callbacks")
	_check(not Progression._run_writer.busy() and not Analytics._writer.busy() and Analytics._writers_by_directory.is_empty(), "real engine quit drains all writer owners")
	print("QA84 APPLICATION SHUTDOWN TEST RESULT: %s (%d assertions; %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _assertions, _failures.size()])
	for failure: String in _failures: push_error(failure)
	if not _failures.is_empty(): quit(1)

func _check(ok: bool, message: String) -> void:
	_assertions += 1
	if not ok: _failures.append(message)
