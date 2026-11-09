extends RefCounted

## The root exits after scenes and autoloads, including their persistence and
## telemetry barriers. Release cross-script Callables here, while every script's
## update mutex is still alive, rather than in GDScriptLanguage::finish().
const Persistence = preload("res://scripts/run_persistence.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Bindings = preload("res://scripts/card_display_bindings.gd")
const Measurements = preload("res://scripts/card_summary_measurements.gd")
const Recovery = preload("res://scripts/opening_boon_recovery.gd")
const DemoEnd = preload("res://scripts/demo_end_panel.gd")
const Clock = preload("res://scripts/presentation_clock.gd")

static func install(root: Window) -> void:
	if not root.tree_exiting.is_connected(finish):
		root.tree_exiting.connect(finish, CONNECT_ONE_SHOT)

static func finish() -> bool:
	# Scene-owned barriers keep their original ordering and retry policy. This
	# final barrier also covers direct SceneTree.quit() from automation/startup.
	var flushed: bool = Persistence.flush()
	# Failed I/O already preserves the preceding durable checkpoint and reports
	# its original failure. At final root exit there can be no further retry;
	# release even failed jobs, never cancel them before the last flush attempt.
	Progression._run_writer.cancel_pending()
	Analytics._writer.cancel_pending()
	for writer: RefCounted in Analytics._writers_by_directory.values():
		writer.cancel_pending()
	Analytics._writers_by_directory.clear()
	Bindings.reset_cache()
	Measurements.release_shutdown_connections()
	Recovery.release_shutdown_callables()
	DemoEnd.release_shutdown_callables()
	Clock.release_shutdown_callables()
	return flushed
