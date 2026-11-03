extends SceneTree

const Fixture = preload("res://tests/fixtures/boss_health_preview_fixture.gd")
const BoardView = preload("res://scripts/combat_board_view.gd")
const BossPreview = preload("res://scripts/boss_health_damage_preview.gd")
const PULSE_PEAK_SECONDS: float = PI / 20.0
const PULSE_TROUGH_SECONDS: float = 3.0 * PI / 20.0
const SETTLE_FRAMES: int = 4
const REDRAW_SAMPLE_FRAMES: int = 6
const REDRAW_TEST_SIZE := Vector2(100.0, 35.0)
const EXPECTED_REDUCED_AMBER_ALPHA: float = 0.641
const EXPECTED_REDUCED_LETHAL_ALPHA: float = 0.763
var _failures: Array[String]
var _preview_draw_count: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	await _test_live_pulse_redraw()
	_test_reduced_motion_mean()
	var settings: Dictionary = Fixture.prepare_storage()
	var viewport := SubViewport.new()
	viewport.size = Fixture.SIZE
	root.add_child(viewport)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	viewport.add_child(scene)
	await _settle()
	scene.set("_settings", settings)
	Fixture.install(scene)
	await _settle()
	scene.call("_on_board_tile_hovered", Fixture.BOSS_TILE)
	await _settle()
	scene.call("_on_card_hover_started", 0)
	await _settle()
	_report(scene, "card_hover")
	_assert_band(scene)
	scene.call("_on_card_hover_ended", 0)
	await _settle()
	_expect(not (scene.get("_boss_health_damage_preview") as Control).visible, "Ending card hover clears its boss forecast")
	await scene.call("_on_card_pressed", 0)
	scene.call("_on_board_tile_hovered", Fixture.BOSS_TILE)
	await _settle()
	_report(scene, "selected_attack_target")
	scene.call("_refresh_stage_view")
	_report(scene, "after_stage_refresh")
	scene.call("_refresh_turn_order_bar")
	_report(scene, "after_turn_rail_refresh")
	_assert_band(scene)
	scene.call("_cancel_card_selection")
	await _settle()
	_expect(not (scene.get("_boss_health_damage_preview") as Control).visible, "Deselecting clears the boss damage segment")
	await _test_lethal_and_motion(scene)
	await _test_targets_and_empower(scene)
	await _test_accumulated_damage(scene)
	await _test_suppression(scene)
	scene.call("_cancel_card_selection")
	await _settle()
	scene.queue_free()
	await process_frame
	viewport.queue_free()
	await process_frame
	for failure: String in _failures: push_error(failure)
	print("BOSS HEALTH PREVIEW TEST: %s (%d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _test_live_pulse_redraw() -> void:
	var prior_failures: int = _failures.size()
	var band := BossPreview.new()
	band.size = REDRAW_TEST_SIZE
	band.draw.connect(_count_preview_draw)
	root.add_child(band)
	band.configure(false, {})
	await _settle()
	var first: int = _preview_draw_count
	# No configure, presentation-clock override, resize or manual redraw occurs
	# while sampling. Only the production _process can keep drawing this band.
	for frame: int in range(REDRAW_SAMPLE_FRAMES): await process_frame
	var later: int = _preview_draw_count
	_expect(first > 0 and later > first, "A live boss preview emits draw signals across unchanged frames without input")
	band.configure(false, {"reduced_motion": true})
	await _settle()
	var steady: int = _preview_draw_count
	for frame: int in range(REDRAW_SAMPLE_FRAMES): await process_frame
	_expect(_preview_draw_count == steady, "Reduced-motion boss preview does not redraw across unchanged frames")
	band.queue_free()
	await process_frame
	print("BOSS LIVE PULSE REDRAW: %s (live %d -> %d; reduced %d -> %d)" % ["PASS" if _failures.size() == prior_failures else "FAIL", first, later, steady, _preview_draw_count])

func _count_preview_draw() -> void:
	_preview_draw_count += 1

func _test_reduced_motion_mean() -> void:
	var prior_failures: int = _failures.size()
	for time_seconds: float in [PULSE_PEAK_SECONDS, PULSE_TROUGH_SECONDS]:
		var presentation: Dictionary = {"reduced_motion": true, "damage_preview_time_seconds": time_seconds}
		var amber: Dictionary = BoardView.health_damage_preview_colors(false, presentation)
		var lethal: Dictionary = BoardView.health_damage_preview_colors(true, presentation)
		_expect(is_equal_approx((amber["fill"] as Color).a, EXPECTED_REDUCED_AMBER_ALPHA), "Reduced-motion amber alpha is the authored pulse mean 0.641")
		_expect(is_equal_approx((lethal["fill"] as Color).a, EXPECTED_REDUCED_LETHAL_ALPHA), "Reduced-motion lethal alpha is the authored pulse mean 0.763")
	print("BOSS REDUCED MOTION MEAN: %s (amber 0.641; lethal 0.763)" % ["PASS" if _failures.size() == prior_failures else "FAIL"])

func _test_lethal_and_motion(scene: Node) -> void:
	var amber: Dictionary = BoardView.health_damage_preview_colors(false, {"damage_preview_time_seconds": PULSE_PEAK_SECONDS})
	_expect((amber["fill"] as Color).is_equal_approx(Color(1.0, 0.72, 0.34, 0.74)), "Nonlethal boss/regular previews use the authored amber at pulse peak")
	Fixture.install(scene, "quick_stab", true)
	await scene.call("_on_card_pressed", 0)
	scene.call("_on_board_tile_hovered", Fixture.BOSS_TILE)
	await _settle()
	_assert_band(scene)
	var band: ColorRect = scene.get("_boss_health_damage_preview")
	_expect(band.anchor_left == 0.0, "Lethal forecast starts at zero HP")
	_set_preview_frame(scene, false, PULSE_PEAK_SECONDS)
	var peak: Color = band.preview_colors()["fill"]
	_expect(peak.is_equal_approx(Color(0.72, 0.18, 0.14, 0.88)), "Lethal boss forecast uses the authored red at pulse peak")
	_set_preview_frame(scene, false, PULSE_TROUGH_SECONDS)
	var trough: Color = band.preview_colors()["fill"]
	_expect(not peak.is_equal_approx(trough), "Boss damage preview pulses without preview-data changes")
	_set_preview_frame(scene, true, PULSE_PEAK_SECONDS)
	var steady: Dictionary = band.preview_colors()
	_set_preview_frame(scene, true, PULSE_TROUGH_SECONDS)
	_expect(steady == band.preview_colors() and not band.is_processing(), "Reduced-motion boss preview remains steady across clocks and stops continuous redraw")
	for lethal: bool in [false, true]:
		var first: Dictionary = BoardView.health_damage_preview_colors(lethal, {"reduced_motion": true, "damage_preview_time_seconds": PULSE_PEAK_SECONDS})
		var later: Dictionary = BoardView.health_damage_preview_colors(lethal, {"reduced_motion": true, "damage_preview_time_seconds": PULSE_TROUGH_SECONDS})
		_expect(first == later, "The shared regular/boss preview renderer is steady under reduced motion")
		_expect((first["outline"] as Color).is_equal_approx(Color(1.0, 0.93, 0.62, 0.45)), "Both preview variants use the authored outline colour")
	_set_preview_frame(scene, false, PULSE_PEAK_SECONDS)

func _test_targets_and_empower(scene: Node) -> void:
	Fixture.install(scene, "blood_price")
	await scene.call("_on_card_pressed", 0)
	scene.call("_on_board_tile_hovered", Fixture.BOSS_TILE)
	await _settle()
	_assert_band(scene)
	var before_hp: int = _boss_preview(scene).get("hp", Fixture.BOSS_HP)
	await scene.call("_toggle_pending_empower")
	scene.call("_on_board_tile_hovered", Fixture.BOSS_TILE)
	await _settle()
	_assert_band(scene)
	_expect(int(_boss_preview(scene).get("hp", Fixture.BOSS_HP)) < before_hp, "Empower increases the dragon's forecast damage and updates its overlay")
	Fixture.install(scene, "hurl_spear")
	await scene.call("_on_card_pressed", 0)
	scene.call("_on_board_tile_hovered", Fixture.BOSS_TILE)
	await _settle()
	_assert_band(scene)
	scene.call("_on_board_tile_hovered", Fixture.REGULAR_TILE)
	await _settle()
	_expect(_boss_preview(scene).is_empty() and not (scene.get("_boss_health_damage_preview") as Control).visible, "Moving to another valid enemy target clears only the boss preview")
	scene.call("_on_board_tile_hovered", Fixture.BOSS_TILE)
	await _settle()
	_assert_band(scene)

func _test_accumulated_damage(scene: Node) -> void:
	Fixture.install(scene, "chain_bolt")
	await scene.call("_on_card_pressed", 0)
	scene.call("_on_board_tile_hovered", Fixture.REGULAR_TILE)
	await _settle()
	_assert_band(scene)
	_expect(not _boss_preview(scene).is_empty(), "Chain from the regular enemy reaches the dragon and uses the on-board total")
	Fixture.install(scene, "phoenix_cleave")
	await scene.call("_on_card_pressed", 0)
	await _settle()
	var state: Dictionary = scene.get("_combat_state")
	var actions: Array = scene.get("_pending_actions")
	_expect(actions.size() >= 2 and scene.call("_pending_card_requires_confirmation"), "The two-hit card resolves both preview actions before confirmation")
	var first_hit: Dictionary = (scene.get("_combat_engine") as RefCounted).apply_player_action(state, actions[0])
	var first_loss: int = Fixture.BOSS_HP - int(first_hit["enemies"][0]["hp"])
	print("MULTI-HIT REPRO: hits=%d first_loss=%d total=%s" % [actions.size(), first_loss, _boss_preview(scene)])
	_assert_band(scene)
	_expect(Fixture.BOSS_HP - int(_boss_preview(scene).get("hp", Fixture.BOSS_HP)) > first_loss, "Multi-hit card forecast carries both hits to the boss bar")
	_expect(int((scene.get("_combat_state") as Dictionary)["enemies"][0]["hp"]) == Fixture.BOSS_HP, "Previewing multiple hits never commits dragon damage")

func _test_suppression(scene: Node) -> void:
	var state: Dictionary = scene.get("_combat_state")
	var board: Control = scene.get("board_view")
	var source: Dictionary = (board.get("presentation") as Dictionary).duplicate(true)
	scene.set("_animation_lock", true)
	scene.call("_refresh_boss_health_overlay", state, source)
	_expect(not (scene.get("_boss_health_damage_preview") as Control).visible, "Animations suppress stale planning previews")
	scene.set("_animation_lock", false)
	state["current_actor"] = {"kind": "enemy", "key": "enemy_1"}
	scene.call("_refresh_boss_health_overlay", state, source)
	_expect(not (scene.get("_boss_health_damage_preview") as Control).visible, "Enemy turns suppress stale planning previews")
	state["current_actor"] = {"kind": "player", "key": "player"}
	scene.call("_refresh_boss_health_overlay", state, source)
	_assert_band(scene)
	scene.call("_refresh_boss_health_overlay", state, {})
	_expect(not (scene.get("_boss_health_damage_preview") as Control).visible, "Empty preview maps clear the boss segment")
	# The nested effect map has the same precedence as the on-board map.
	scene.call("_refresh_boss_health_overlay", state, {"damage_preview": {"enemy_1": {"hp": 40}}, "effect": {"damage_preview": {"enemy_1": {"hp": 32}}}})
	_expect(is_equal_approx((scene.get("_boss_health_damage_preview") as Control).anchor_left, 32.0 / Fixture.BOSS_MAX_HP), "Boss lookup preserves the board's effect-map precedence")
	scene.call("_refresh_boss_health_overlay", {"enemies": []}, {})
	_expect(not (scene.get("_boss_health_overlay") as Control).visible, "Removing the encounter hides the boss overlay")

func _set_preview_frame(scene: Node, reduced: bool, time_seconds: float) -> void:
	var settings: Dictionary = scene.get("_settings")
	settings["reduced_motion"] = reduced
	var source: Dictionary = scene.get("_board_presentation")
	source["damage_preview_time_seconds"] = time_seconds
	scene.call("_refresh_stage_view")
	var band: ColorRect = scene.get("_boss_health_damage_preview")
	var colors: Dictionary = BoardView.health_damage_preview_colors(bool(_boss_preview(scene).get("lethal", false)), (scene.get("board_view") as Control).get("presentation"))
	_expect(band.preview_colors() == colors, "Boss and on-board damage previews share colours, outline and clock")

func _boss_preview(scene: Node) -> Dictionary:
	return ((scene.get("board_view") as Control).call("_damage_preview_map") as Dictionary).get("enemy_1", {})

func _assert_band(scene: Node) -> void:
	var board: Control = scene.get("board_view")
	var preview: Dictionary = board.call("_damage_preview_map")
	var boss_preview: Dictionary = preview.get("enemy_1", {})
	_expect(not boss_preview.is_empty(), "The real attack forecast carries damage for the dragon")
	var band: Control = scene.get("_boss_health_damage_preview")
	var host: Control = scene.get("_boss_health_host")
	_expect(band.visible and band.size.x > 0.0 and band.size.y > 0.0, "Dragon targeting shows a nonempty boss overlay damage segment")
	var presentation: Dictionary = board.get("presentation")
	if not bool(presentation.get("reduced_motion", false)) and not presentation.has("damage_preview_time_seconds"):
		_expect(band.is_processing(), "A live boss preview keeps redrawing between input changes")
	var state: Dictionary = scene.get("_combat_state")
	var boss: Dictionary = state["enemies"][0]
	var hp: int = int(boss["hp"])
	var maximum: int = int(boss["max_hp"])
	var expected_width: float = host.size.x * float(hp - int(boss_preview.get("hp", hp))) / maximum
	_expect(is_equal_approx(band.size.x, expected_width), "Boss segment spans preview HP to committed HP")
	_expect(is_equal_approx(band.position.x, host.size.x * float(boss_preview.get("hp", hp)) / maximum), "Boss segment starts at the exact projected HP endpoint")
	_expect(is_equal_approx(band.size.y, host.size.y), "Boss preview spans the entire fill height")
	_expect((scene.get("_boss_health_hp_label") as Label).text == "%d/%d" % [hp, maximum], "Boss label retains committed HP during forecasts")

func _report(scene: Node, label: String) -> void:
	var board: Control = scene.get("board_view")
	var band: Control = scene.get("_boss_health_damage_preview")
	print("REPRO %s: board=%s overlay_visible=%s rect=%s anchors=%s" % [label, board.call("_damage_preview_map"), band.visible, band.get_rect(), Vector2(band.anchor_left, band.anchor_right)])

func _settle() -> void:
	await preload("res://tests/helpers/presentation_test_clock.gd").rendered_frames(self, SETTLE_FRAMES)

func _expect(ok: bool, message: String) -> void:
	if not ok: _failures.append(message)
