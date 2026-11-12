extends SceneTree
const Bar = preload("res://scripts/segmented_health_bar.gd")
const Tracker = preload("res://scripts/health_ghost_tracker.gd")
const Dissolve = preload("res://scripts/enemy_shadow_dissolve_effect.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const HealthSuite = preload("res://tests/suites/health_ghost_suite.gd")
const TooltipSuite = preload("res://tests/suites/tooltip_consistency_suite.gd")
const GateSuite = preload("res://tests/suites/cutout_render_gate_suite.gd")
const RuntimeSuite = preload("res://tests/maquette_cutout/runtime_suite.gd")
const FIXTURE_SIZE := Vector2(160, 16)
const FIXTURE_HP: float = 24.0
const FIXTURE_DAMAGE: float = 6.0
const SETTLE_FRAMES: int = 3
var _failures: Array[String]
var _checks: int = 0
var _draws: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--existing-only"):
		await _health_invalidations()
		await _dissolve_invalidations()
	if OS.get_cmdline_user_args().has("--regression-only"):
		_finish()
		return
	HealthSuite.run(_expect)
	await HealthSuite.run_integration(self, _expect)
	TooltipSuite.run(_expect)
	GateSuite.run(self, _expect)
	await RuntimeSuite.run(self, _expect, "lightning_wisp")
	await RuntimeSuite.run(self, _expect, "bile_bloomer")
	_finish()

func _finish() -> void:
	for failure: String in _failures: push_error(failure)
	print("PERF110 FOCUSED: checks=%d failures=%d %s" % [_checks, _failures.size(), "PASS" if _failures.is_empty() else "FAIL"])
	quit(0 if _failures.is_empty() else 1)

func _health_invalidations() -> void:
	var tracker := Tracker.new()
	tracker.observe("actor", FIXTURE_HP, FIXTURE_HP)
	var bar := Bar.new()
	bar.size = FIXTURE_SIZE
	bar.set_health(FIXTURE_HP, FIXTURE_HP)
	bar.bind_ghost(tracker, "actor", true)
	root.add_child(bar)
	bar.draw.connect(func() -> void: _draws += 1)
	await _settle()
	_draws = 0
	bar.set_health(FIXTURE_HP, FIXTURE_HP)
	bar.set_fill(bar.fill_color, bar.fill_highlight_color)
	bar.set_appearance(bar.background_color, bar.border_color, bar.separator_color)
	bar.set_segment_count(bar.segment_count)
	bar.bind_ghost(tracker, "actor", true)
	tracker.observe("other", FIXTURE_HP, FIXTURE_HP)
	await _settle()
	_expect(_draws == 0, "Equal health/binding/style setters and another actor's sample retain draw commands")
	tracker.observe("actor", FIXTURE_HP, FIXTURE_HP * 2.0)
	bar.bind_ghost(tracker, "actor", true)
	await _settle()
	_expect(_draws == 1 and bar.ghost_sample()["max_hp"] == FIXTURE_HP * 2.0, "An unchanged binding samples silent tracker input changes in the same draw flush")
	tracker.observe("actor", FIXTURE_HP, FIXTURE_HP)
	bar.bind_ghost(tracker, "actor", true)
	await _settle()
	_draws = 0
	tracker.observe("actor", FIXTURE_HP - FIXTURE_DAMAGE, FIXTURE_HP)
	await _settle()
	_expect(_draws == 1 and bar.ghost_sample()["hp"] == FIXTURE_HP - FIXTURE_DAMAGE, "Damage updates the bound bar in the same draw flush")
	_draws = 0
	tracker.advance(0.1)
	await _settle()
	_expect(_draws == 0, "The unchanged damage hold retains the existing commands")
	tracker.advance(Tracker.HOLD_SECONDS)
	await _settle()
	_expect(_draws == 1, "The first changed drain sample redraws immediately")
	_draws = 0
	tracker.reduced_motion = true
	bar.bind_ghost(tracker, "actor", true)
	await _settle()
	_expect(_draws == 1 and bar.ghost_sample()["ghost_range"] == Vector2(FIXTURE_HP - FIXTURE_DAMAGE, FIXTURE_HP - FIXTURE_DAMAGE), "Rebinding applies a silent reduced-motion change in the same draw flush")
	tracker.reduced_motion = false
	bar.bind_ghost(tracker, "actor", true)
	await _settle()
	_draws = 0
	tracker.observe("actor", FIXTURE_HP, FIXTURE_HP)
	await _settle()
	tracker.advance(Tracker.HEAL_FLASH_SECONDS * 0.5)
	await _settle()
	_expect(_draws == 2, "Healing and the changing heal flash both redraw")
	var replacement := Tracker.new()
	replacement.observe("actor", FIXTURE_HP, FIXTURE_HP)
	bar.bind_ghost(replacement, "actor", false)
	await _settle()
	_draws = 0
	tracker.changed.emit()
	await _settle()
	_expect(_draws == 0, "Rebinding disconnects the previous tracker")
	bar.hide()
	replacement.observe("actor", FIXTURE_HP - FIXTURE_DAMAGE, FIXTURE_HP)
	await _settle()
	bar.show()
	await _settle()
	_expect(_draws == 1 and bar.ghost_sample()["hp"] == FIXTURE_HP - FIXTURE_DAMAGE, "Showing a hidden changed bar draws its current sample")
	bar.free()

func _dissolve_invalidations() -> void:
	var effect := Dissolve.new()
	root.add_child(effect)
	var texture: Texture2D = AssetLoader.load_texture("res://assets/units/crawler_cutout/front/rest.png")
	var rect := Rect2(Vector2.ZERO, FIXTURE_SIZE)
	effect.configure(texture, rect, 0.0, 1.0, false)
	effect.draw.connect(func() -> void: _draws += 1)
	await _settle()
	_draws = 0
	effect.configure(texture, rect, 0.5, 2.0, true)
	await _settle()
	_expect(_draws == 0 and effect.dissolve_progress() == 0.5, "Dissolve uniforms update without redrawing the retained texture rectangle")
	effect.configure(texture, Rect2(Vector2.ZERO, FIXTURE_SIZE * 2.0), 0.5, 2.0, true)
	await _settle()
	_expect(_draws == 1, "A changed dissolve rectangle resubmits the draw commands")
	effect.free()

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES): await process_frame

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition: _failures.append(message)
