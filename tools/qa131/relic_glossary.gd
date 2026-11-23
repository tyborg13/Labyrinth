extends "res://tools/inspection_fixture.gd"
## Isolate the treasure hover warning from campaign seed 131000.

const Settings = preload("res://scripts/settings_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const VENOM_SEED: int = 131000
const TALLOW_SEED: int = 131001
const SIZE := Vector2i(1920, 1080)
const OVERFLOW_VIEWPORT := Vector2i(1920, 1920)
const OVERFLOW_ROW_TOP: float = 1964.0
const WATCHDOG_MSEC: int = 12000

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_probe")

func _probe() -> void:
	var tallow: bool = OS.get_cmdline_user_args().has("--tallow")
	var seed_value: int = TALLOW_SEED if tallow else VENOM_SEED
	var relic_id: String = "tallow_candle" if tallow else "venom_signet"
	var hover_name: String = "RelicChoice_" + relic_id
	root.size = SIZE
	root.content_scale_size = SIZE
	var settings: Dictionary = Settings.default_settings()
	settings["reduced_motion"] = true
	settings["combat_speed"] = Settings.COMBAT_FASTEST
	Settings.save_settings(settings)
	_options = {"scenario": "treasure", "seed": seed_value,
		"relic_choices": relic_id + ",liturgy_of_ash,iron_lung"}
	var profile: Dictionary = Tutorial.complete_tutorial(_build_progression())
	var run: Dictionary = _build_run_state("treasure", profile)
	if not ProgressionStore.save_data(profile) or not ProgressionStore.save_run_state(run):
		push_error("QA131 RELIC fixture write failed")
		quit(1)
		return
	root.set_meta("labyrinth_resume_saved_run", true)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	var target: Control
	var cutoff: int = Time.get_ticks_msec() + WATCHDOG_MSEC
	while Time.get_ticks_msec() < cutoff:
		target = scene.find_child(hover_name, true, false) as Control
		if target != null and target.is_visible_in_tree(): break
		await process_frame
	if target == null or not target.is_visible_in_tree():
		push_error("QA131 RELIC card unavailable")
		quit(1)
		return
	if OS.get_cmdline_user_args().has("--overflow-geometry"):
		# Preserve the warning's headless viewport and bring the inspected row
		# to the logged position without changing any production UI settings.
		root.size = OVERFLOW_VIEWPORT
		root.content_scale_size = OVERFLOW_VIEWPORT
		await process_frame
		var row: Control = target.get_meta("glossary_choice_row")
		row.global_position.y += OVERFLOW_ROW_TOP - target.global_position.y
	print("QA131 RELIC seed=%d decision=1 hover %s" % [seed_value, hover_name])
	target.mouse_entered.emit()
	var stack: Node = scene.find_child("CardFocusTooltipStack", true, false)
	if stack != null:
		stack.show_relic(target, target.get_meta("glossary_relic"))
		stack._follow_target_now()
	print("QA131 RELIC overflow=%s target=%s viewport=%s" % [stack.get_meta("glossary_choice_overflow", false)
		if stack != null else null, target.get_global_rect(), target.get_viewport_rect()])
	scene.queue_free()
	await process_frame
	quit()
