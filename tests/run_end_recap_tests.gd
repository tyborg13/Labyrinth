extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const AnalyticsStore = preload("res://scripts/analytics_store.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const DeathEngulfOverlay = preload("res://scripts/death_engulf_overlay.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const RunEndRecapOverlay = preload("res://scripts/run_end_recap_overlay.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const RUN_SCENE = preload("res://scenes/run_scene.tscn")

var _failures: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://run_end_recap_progression_test.json")
	ProgressionStore.set_run_storage_path("user://run_end_recap_saved_run_test.save")
	AnalyticsStore.set_storage_dir("user://run_end_recap_analytics_test")
	call_deferred("_run")

func _run() -> void:
	ProgressionStore.clear_saved_run()
	ProgressionStore.save_data(ProgressionStore.default_data())
	AnalyticsStore.clear_storage()
	_test_recap_model_values()
	_test_combat_stat_sources_and_snapshot_exactly_once()
	_test_personal_best_restart_persistence_and_policy()
	await _test_overlay_action_signals()
	await _test_shroud_animation_and_reduced_motion()
	await _test_run_scene_progression_and_actions()
	if _failures.is_empty():
		print("RUN END RECAP TEST RESULT: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("RUN END RECAP TEST RESULT: FAIL (%d failure(s))" % _failures.size())
	quit(1)

func _test_recap_model_values() -> void:
	var run_state: Dictionary = {
		"current_room": Vector2i(4, 0),
		"rooms": {
			"0,0": {"depth": 0, "type": "start", "cleared": true},
			"1,0": {"depth": 1, "type": "combat", "cleared": true},
			"2,0": {"depth": 2, "type": "treasure", "cleared": true},
			"3,0": {"depth": 3, "type": "boss", "cleared": true},
			"4,0": {"depth": 4, "type": "combat", "cleared": false}
		},
		"deck_cards": ["quick_stab", "patch_up", "pale_spark", "guarded_step"],
		"attuned_magic_cards": ["pale_spark"],
		"relics": ["iron_lung", "ember_lens", "pilgrim_boots"],
		"equipped_equipment": {"weapon": "training_sword"},
		"run_stats": {"enemies_killed": 11, "damage_dealt": 830, "damage_received": 270},
		"run_result": {"new_bests": ["enemies_killed", "damage_dealt", "depth"]}
	}
	var progression: Dictionary = ProgressionStore.record_lost_embers(
		ProgressionStore.default_data(),
		37,
		Vector2i(4, 0),
		2
	)
	var defeat: Dictionary = RunEndRecapOverlay.build_model(run_state, progression, "defeat", 37)
	_assert(str(defeat.get("kicker", "")) == "THE UMBRA CLOSES IN", "Defeat recap should use the approved Umbra takeover kicker")
	_assert(str(defeat.get("summary", "not empty")).is_empty(), "Defeat recap should omit the rejected cute summary tagline")
	_assert(int(defeat.get("depth", -1)) == 4, "Defeat recap should use current-room depth")
	_assert(int(defeat.get("rooms_cleared", -1)) == 3, "Rooms cleared should count committed non-start cleared rooms")
	_assert(str(defeat.get("boss_result", "")) == "1 guardian defeated", "Defeat recap should derive prior boss clears")
	_assert(str(defeat.get("ember_label", "")) == "EMBERS LOST" and int(defeat.get("ember_amount", -1)) == 37, "Defeat recap should show the committed lost ember amount")
	_assert(str(defeat.get("recovery_status", "")) == "Recovery marker set · Depth 4 · 37 embers", "Defeat recap should match the committed recovery marker")
	var stats: Dictionary = defeat.get("stats", {}) as Dictionary
	_assert(int(stats.get("enemies_killed", -1)) == 11, "Defeat recap should reliably report enemies killed")
	_assert(int(stats.get("damage_dealt", -1)) == 830, "Defeat recap should reliably report actual enemy HP damage")
	_assert(int(stats.get("damage_received", -1)) == 270, "Defeat recap should reliably report actual player HP damage")
	_assert(int(stats.get("bosses_defeated", -1)) == 1, "Defeat recap should retain a compact numeric boss result")
	_assert(not defeat.has("build_highlights"), "Recap model should omit prose build inventories")
	var new_bests: Array = defeat.get("new_bests", []) as Array
	_assert(new_bests.has("enemies_killed") and new_bests.has("damage_dealt") and new_bests.has("depth"), "Recap should carry only the persisted strict-best decisions for this run")

	var zero_defeat: Dictionary = RunEndRecapOverlay.build_model(
		run_state,
		ProgressionStore.record_lost_embers(ProgressionStore.default_data(), 0, Vector2i(4, 0), 2),
		"defeat",
		0
	)
	_assert(str(zero_defeat.get("recovery_status", "")) == "No marker · no embers left behind", "Zero-ember defeat should not promise a recovery marker")
	var victory: Dictionary = RunEndRecapOverlay.build_model(run_state, ProgressionStore.default_data(), "victory", 0)
	_assert(str(victory.get("ember_label", "")) == "EMBERS BANKED" and int(victory.get("ember_amount", -1)) == 0, "Zero-ember victory should explicitly show a zero banked result")
	_assert(str(victory.get("boss_result", "")) == "Final boss defeated", "Victory recap should report the final boss result")
	var expiring_marker_progression: Dictionary = ProgressionStore.record_lost_embers(
		ProgressionStore.default_data(),
		19,
		Vector2i(3, 0),
		0
	)
	expiring_marker_progression = ProgressionStore.prepare_for_new_run(expiring_marker_progression)
	var marker_victory: Dictionary = RunEndRecapOverlay.build_model(run_state, expiring_marker_progression, "victory", 28)
	_assert(str(marker_victory.get("recovery_status", "")) == "Marker expires · 19 embers unrecovered", "Victory recap should preview recovery-marker expiry on New Run")

func _test_combat_stat_sources_and_snapshot_exactly_once() -> void:
	var combat := CombatEngine.new()
	var combat_state: Dictionary = {
		"run_stats": {"enemies_killed": 2, "damage_dealt": 30, "damage_received": 10},
		"player": {"pos": Vector2i(1, 1), "hp": 100, "max_hp": 100, "block": 15, "stoneskin": 0},
		"enemies": [{"id": 1, "type": "crawler", "pos": Vector2i(2, 1), "hp": 50, "max_hp": 50, "block": 10, "stoneskin": 0}],
		"relics": [],
		"death_rewards": [],
		"room_embers": 0,
		"death_bonus_card_plays_this_turn": 0,
		"log": []
	}
	var untouched_preview_source: Dictionary = combat_state.duplicate(true)
	var preview_only: Dictionary = combat.call("_damage_enemy", combat_state.duplicate(true), 0, 20, false, true) as Dictionary
	_assert(int((untouched_preview_source.get("run_stats", {}) as Dictionary).get("damage_dealt", -1)) == 30, "Preview/replay hooks must not mutate their source stat snapshot")
	_assert(int((preview_only.get("run_stats", {}) as Dictionary).get("damage_dealt", -1)) == 50, "Enemy HP loss should be the deterministic damage-dealt source")

	combat_state = preview_only
	combat_state = combat.call("_damage_enemy", combat_state, 0, 999, false, true) as Dictionary
	var stats: Dictionary = combat.run_stats(combat_state)
	_assert(int(stats.get("damage_dealt", -1)) == 80, "Overkill should count only the enemy HP actually removed")
	_assert(int(stats.get("enemies_killed", -1)) == 3, "An alive-to-dead transition should increment enemies killed once")
	combat_state = combat.call("_damage_enemy", combat_state, 0, 999, false, true) as Dictionary
	_assert(combat.run_stats(combat_state) == stats, "Repeated damage against an already-dead enemy must not double count damage or kills")

	combat_state = combat.call("_damage_player", combat_state, 40, false, false) as Dictionary
	stats = combat.run_stats(combat_state)
	_assert(int(stats.get("damage_received", -1)) == 35, "Damage received should count HP loss after block and stoneskin")
	combat_state = combat.call("_damage_player", combat_state, 999, true, false) as Dictionary
	stats = combat.run_stats(combat_state)
	_assert(int(stats.get("damage_received", -1)) == 110, "Lethal overkill should count only remaining player HP")

	var engine := RunEngine.new()
	var run_state: Dictionary = engine.create_new_run(4401, ProgressionStore.default_data())
	run_state["run_stats"] = {"enemies_killed": 2, "damage_dealt": 30, "damage_received": 10}
	var checkpoint_once: Dictionary = engine.set_combat_state(run_state, combat_state)
	var checkpoint_twice: Dictionary = engine.set_combat_state(checkpoint_once, combat_state)
	_assert((checkpoint_once.get("run_stats", {}) as Dictionary) == (checkpoint_twice.get("run_stats", {}) as Dictionary), "Applying the same committed combat snapshot twice must overwrite, never add, run stats")
	_assert(ProgressionStore.save_run_state(checkpoint_once), "Run-stat checkpoint fixture should save")
	var repaired: Dictionary = engine.repair_loaded_run_state(ProgressionStore.load_saved_run())
	_assert((repaired.get("run_stats", {}) as Dictionary) == stats, "Save/resume should preserve the exact cumulative stat snapshot")
	var terminal_once: Dictionary = engine.finish_combat(run_state, combat_state)
	var terminal_again: Dictionary = engine.finish_combat(run_state, combat_state)
	_assert((terminal_once.get("run_stats", {}) as Dictionary) == (terminal_again.get("run_stats", {}) as Dictionary), "Replaying a terminal transition from the same committed input must produce identical, not doubled, stats")
	ProgressionStore.clear_saved_run()

func _test_personal_best_restart_persistence_and_policy() -> void:
	var first_stats: Dictionary = {
		"enemies_killed": 3,
		"damage_dealt": 120,
		"damage_received": 80,
		"depth": 2,
		"rooms_cleared": 2,
		"bosses_defeated": 0
	}
	var first_record: Dictionary = ProgressionStore.record_run_result(ProgressionStore.default_data(), "run:first", first_stats)
	var first_result: Dictionary = first_record.get("result", {}) as Dictionary
	_assert((first_result.get("new_bests", []) as Array).is_empty(), "First-ever values should establish a baseline without inventing a prior best")
	var progression: Dictionary = first_record.get("data", {}) as Dictionary
	_assert(ProgressionStore.save_data(progression), "First-run best baseline should persist locally")

	var restarted: Dictionary = ProgressionStore.load_data()
	_assert(ProgressionStore.run_bests(restarted) == {
		"enemies_killed": 3,
		"damage_dealt": 120,
		"depth": 2,
		"rooms_cleared": 2,
		"bosses_defeated": 0
	}, "Process-restart load should preserve every eligible personal-best baseline")
	var tie_record: Dictionary = ProgressionStore.record_run_result(restarted, "run:tie", first_stats)
	_assert(((tie_record.get("result", {}) as Dictionary).get("new_bests", []) as Array).is_empty(), "A tie must never be labeled NEW BEST")

	var improved_stats: Dictionary = first_stats.duplicate(true)
	improved_stats["enemies_killed"] = 4
	improved_stats["damage_dealt"] = 121
	improved_stats["damage_received"] = 999
	improved_stats["depth"] = 3
	improved_stats["rooms_cleared"] = 3
	improved_stats["bosses_defeated"] = 1
	var improved_record: Dictionary = ProgressionStore.record_run_result(tie_record.get("data", {}) as Dictionary, "run:improved", improved_stats)
	var improved_result: Dictionary = improved_record.get("result", {}) as Dictionary
	var improved_bests: Array = improved_result.get("new_bests", []) as Array
	for stat_id: String in ["enemies_killed", "damage_dealt", "depth", "rooms_cleared", "bosses_defeated"]:
		_assert(improved_bests.has(stat_id), "Strictly exceeding %s should earn NEW BEST" % stat_id)
	_assert(not improved_bests.has("damage_received"), "Damage taken is reported but should not celebrate a higher value as a personal best")

	var replay_stats: Dictionary = improved_stats.duplicate(true)
	replay_stats["enemies_killed"] = 999
	var replay_record: Dictionary = ProgressionStore.record_run_result(improved_record.get("data", {}) as Dictionary, "run:improved", replay_stats)
	_assert(not bool(replay_record.get("recorded", true)), "Repeating the same run-result id should be an idempotent no-op")
	_assert(int(ProgressionStore.run_bests(replay_record.get("data", {}) as Dictionary).get("enemies_killed", -1)) == 4, "A replay/testing hook must not replace already-recorded stats for the same run")
	_assert(ProgressionStore.save_data(replay_record.get("data", {}) as Dictionary), "Improved bests should persist locally")
	var second_restart: Dictionary = ProgressionStore.load_data()
	_assert(ProgressionStore.last_run_result(second_restart) == improved_result, "NEW BEST eligibility should survive a process restart for the just-finished run")

	var ledger_a: Dictionary = ProgressionStore.record_run_result(ProgressionStore.default_data(), "ledger:A", first_stats)
	var ledger_a_result: Dictionary = (ledger_a.get("result", {}) as Dictionary).duplicate(true)
	var ledger_b: Dictionary = ProgressionStore.record_run_result(ledger_a.get("data", {}) as Dictionary, "ledger:B", improved_stats)
	var ledger_b_bests: Dictionary = ProgressionStore.run_bests(ledger_b.get("data", {}) as Dictionary)
	_assert(ProgressionStore.save_data(ledger_b.get("data", {}) as Dictionary), "A → B result ledger should persist before replay")
	var ledger_restart: Dictionary = ProgressionStore.load_data()
	var forged_a_stats: Dictionary = improved_stats.duplicate(true)
	forged_a_stats["enemies_killed"] = 999
	var replay_a: Dictionary = ProgressionStore.record_run_result(ledger_restart, "ledger:A", forged_a_stats)
	_assert(not bool(replay_a.get("recorded", true)), "A → B → replay A should be recognized after save/reload")
	_assert((replay_a.get("result", {}) as Dictionary) == ledger_a_result, "A → B → replay A should return A's original silent-baseline badge decision")
	_assert(ProgressionStore.run_bests(replay_a.get("data", {}) as Dictionary) == ledger_b_bests, "Replaying non-adjacent A must not alter the monotonic bests established by B")
	_assert(ProgressionStore.last_run_result(replay_a.get("data", {}) as Dictionary) == ledger_a_result, "A replay should restore A's original result for recap presentation")

	var bounded_data: Dictionary = replay_a.get("data", {}) as Dictionary
	for index: int in range(ProgressionStore.RUN_RESULT_LEDGER_LIMIT + 3):
		var bounded_record: Dictionary = ProgressionStore.record_run_result(bounded_data, "ledger:bounded:%02d" % index, first_stats)
		bounded_data = bounded_record.get("data", {}) as Dictionary
	_assert(ProgressionStore.completed_run_results(bounded_data).size() == ProgressionStore.RUN_RESULT_LEDGER_LIMIT, "Completed result history should remain durably bounded")

func _test_overlay_action_signals() -> void:
	var overlay := RunEndRecapOverlay.new()
	root.add_child(overlay)
	await process_frame
	var model: Dictionary = RunEndRecapOverlay.build_model(
		{"current_room": Vector2i.ZERO, "rooms": {}, "deck_cards": []},
		ProgressionStore.default_data(),
		"victory",
		12
	)
	overlay.present(model)
	var action_counts: Dictionary = {"new_run": 0, "main_menu": 0}
	overlay.new_run_pressed.connect(func() -> void: action_counts["new_run"] = int(action_counts["new_run"]) + 1)
	overlay.main_menu_pressed.connect(func() -> void: action_counts["main_menu"] = int(action_counts["main_menu"]) + 1)
	var new_run_button: Button = overlay.find_child("NewRunButton", true, false) as Button
	var main_menu_button: Button = overlay.find_child("MainMenuButton", true, false) as Button
	_assert(new_run_button != null and new_run_button.text == "New Run", "Recap should expose a clear New Run action")
	_assert(main_menu_button != null and main_menu_button.text == "Main Menu", "Recap should expose a clear Main Menu action")
	if new_run_button != null:
		new_run_button.pressed.emit()
	if main_menu_button != null:
		main_menu_button.pressed.emit()
	_assert(int(action_counts["new_run"]) == 1, "New Run button should emit exactly one action")
	_assert(int(action_counts["main_menu"]) == 1, "Main Menu button should emit exactly one action")
	overlay.set_motion_enabled(false)
	_assert(not overlay.motion_enabled(), "Recap should expose a decoupled motion switch for future reduced-motion settings")
	overlay.queue_free()
	await process_frame

func _test_shroud_animation_and_reduced_motion() -> void:
	var overlay := RunEndRecapOverlay.new()
	overlay.size = Vector2(1280.0, 720.0)
	root.add_child(overlay)
	await process_frame
	var run_state: Dictionary = {
		"current_room": Vector2i(4, 0),
		"rooms": {
			"0,0": {"depth": 0, "type": "start", "cleared": true},
			"1,0": {"depth": 1, "type": "combat", "cleared": true},
			"4,0": {"depth": 4, "type": "combat", "cleared": false}
		},
		"run_stats": {"enemies_killed": 8, "damage_dealt": 640, "damage_received": 230},
		"run_result": {"new_bests": ["enemies_killed", "damage_dealt", "depth"]}
	}
	var model: Dictionary = RunEndRecapOverlay.build_model(run_state, ProgressionStore.default_data(), "defeat", 0)
	var death_site := Vector2(0.31, 0.62)
	overlay.present(model, death_site)
	overlay.seek_presentation(0.0)
	_assert(is_zero_approx(overlay.shroud_progress()), "Defeat should begin with the authored room fully visible before edge engulf")
	_assert(is_zero_approx(overlay.sample_shroud_alpha(death_site)), "Pre-engulf death site should have no dark cover")
	_assert(overlay.death_site_normalized().is_equal_approx(death_site), "Defeat effect should retain the exact supplied player death location")

	overlay.seek_presentation(DeathEngulfOverlay.ENGULF_SECONDS * 0.5)
	var mid_edge_alpha: float = overlay.sample_shroud_alpha(Vector2(0.99, 0.50))
	var mid_center_alpha: float = overlay.sample_shroud_alpha(death_site)
	_assert(overlay.shroud_progress() > 0.45 and overlay.shroud_progress() < 0.60, "Mid-engulf seek should land in the inward edge progression")
	_assert(mid_edge_alpha > mid_center_alpha + 0.35, "Mid-engulf darkness should advance from the far room edge toward the death site")
	_assert(mid_center_alpha < 0.05, "The ember-lit death site should remain visible while the Umbra advances")

	overlay.seek_presentation(overlay.presentation_duration())
	var final_center_alpha: float = overlay.sample_shroud_alpha(death_site)
	var final_edge_alpha: float = overlay.sample_shroud_alpha(Vector2(0.99, 0.50))
	_assert(is_equal_approx(overlay.shroud_progress(), 1.0), "Final defeat recap should retain the completed engulf state")
	_assert(final_center_alpha < 0.08 and final_edge_alpha > 0.84, "Final Umbra should leave only the ember-lit death site readable")
	_assert(overlay.final_shroud_alpha() > 0.84, "Final shroud should decisively take over the unlit room")
	_assert(not overlay.has_decorative_edge_strokes(), "Defeat presentation must not draw arbitrary red edge strokes or decorative noise")
	_assert(overlay.find_child("BuildRecap", true, false) == null, "Defeat recap should omit the prose build inventory")
	_assert(overlay.find_child("RunStatGrid", true, false) == null, "Defeat recap should not regress to a default UI stat grid")
	var stat_ledger: Control = overlay.find_child("DefeatStatLedger", true, false) as Control
	_assert(stat_ledger != null and stat_ledger.get_child_count() == 6, "Defeat recap should expose one asymmetric contoured stat narrative")
	_assert(overlay.find_child("OutcomeSummary", true, false) == null, "Defeat layout should not recreate the removed summary tagline")
	_assert(overlay.find_child("DefeatCornerTop", true, false) == null and overlay.find_child("RecoveryRailRaster", true, false) == null, "Defeat UI should not repurpose unrelated frame-kit fragments")
	var title_raster: TextureRect = overlay.find_child("DefeatTitleRaster", true, false) as TextureRect
	_assert(title_raster != null and title_raster.texture != null and title_raster.material is ShaderMaterial, "RUN ENDED should use the authored obsidian raster treatment")
	var title_glow: TextureRect = overlay.find_child("DefeatTitleGlow", true, false) as TextureRect
	_assert(title_glow != null and title_glow.texture == title_raster.texture and title_glow.material is ShaderMaterial, "RUN ENDED should retain its raster source while gaining a restrained purple glow layer")
	if stat_ledger != null:
		var expected_metrics: Array[String] = ["EnemiesKilledMetric", "DamageDealtMetric", "DamageReceivedMetric", "DepthMetric", "RoomsClearedMetric", "BossesDefeatedMetric"]
		for index: int in range(expected_metrics.size()):
			_assert(stat_ledger.get_child(index).name == expected_metrics[index], "Stats should flow in the concept's single vertical reading order")
		var first_row: Control = stat_ledger.get_child(0) as Control
		var middle_row: Control = stat_ledger.get_child(3) as Control
		var last_row: Control = stat_ledger.get_child(5) as Control
		_assert(first_row.position.x < middle_row.position.x and last_row.position.x < middle_row.position.x, "Stat origins should arc around the Last Light window instead of sharing one left edge")
		var ember_result: Control = overlay.find_child("EmberResult", true, false) as Control
		_assert(ember_result != null and ember_result.position.y - last_row.position.y < 90.0, "The separate ember consequence should remain visually connected to the stat arc")
	var kills_best: Label = overlay.find_child("EnemiesKilledBest", true, false) as Label
	var received_best: Label = overlay.find_child("DamageReceivedBest", true, false) as Label
	var kills_heading: Label = overlay.find_child("EnemiesKilledHeading", true, false) as Label
	_assert(kills_best != null and kills_best.visible and kills_best.text == "NEW BEST", "Strict eligible improvements should show the restrained NEW BEST badge")
	_assert(received_best != null and not received_best.visible, "Damage taken should remain a neutral reported stat")
	_assert(kills_heading != null and kills_heading.text == "ENEMIES KILLED", "Kill count should use an unambiguous player-facing label")

	var recap_layout: Control = overlay.find_child("LastLightRecap", true, false) as Control
	overlay.size = Vector2(1920.0, 1080.0)
	overlay.call("_update_presentation")
	var viewport_rect := Rect2(Vector2.ZERO, overlay.size)
	_assert(recap_layout != null and viewport_rect.encloses(recap_layout.get_rect()), "1920×1080 Last Light recap should remain within the authored surface")
	overlay.size = Vector2(1280.0, 720.0)
	overlay.call("_update_presentation")
	var new_run_button: Button = overlay.find_child("NewRunButton", true, false) as Button
	var main_menu_button: Button = overlay.find_child("MainMenuButton", true, false) as Button
	_assert(new_run_button != null and Rect2(Vector2.ZERO, overlay.size).encloses(new_run_button.get_rect()), "Compact Last Light recap should contain its primary action")
	_assert(main_menu_button != null and Rect2(Vector2.ZERO, overlay.size).encloses(main_menu_button.get_rect()), "Compact Last Light recap should contain its secondary action")
	_assert(str(new_run_button.get_meta("button_variant", "")) == UiSkin.VARIANT_UMBRA, "Run-end actions should use the raster Umbra Obsidian treatment")
	_assert(new_run_button.position.x < main_menu_button.position.x and absf(new_run_button.get_rect().get_center().y - main_menu_button.get_rect().get_center().y) < 1.0, "Actions should share one lower baseline with New Run first")
	var source_aspect: float = 1024.0 / 224.0
	_assert(absf((new_run_button.size.x + 4.0) / (new_run_button.size.y + 10.0) - source_aspect) < 0.01, "Primary action raster should retain its authored aspect instead of stretching")
	_assert(absf((main_menu_button.size.x + 4.0) / (main_menu_button.size.y + 10.0) - source_aspect) < 0.01, "Secondary action raster should retain its authored aspect instead of stretching")
	var traversal_counts := {"new_run": 0, "main_menu": 0}
	overlay.new_run_pressed.connect(func() -> void: traversal_counts["new_run"] = int(traversal_counts["new_run"]) + 1)
	overlay.main_menu_pressed.connect(func() -> void: traversal_counts["main_menu"] = int(traversal_counts["main_menu"]) + 1)
	new_run_button.grab_focus()
	await process_frame
	await _press_ui_action(&"ui_right")
	_assert(main_menu_button.has_focus(), "ui_right should move horizontally from New Run to Main Menu")
	await _press_ui_action(&"ui_accept")
	_assert(int(traversal_counts["main_menu"]) == 1, "ui_accept should activate Main Menu after horizontal traversal")
	await _press_ui_action(&"ui_left")
	_assert(new_run_button.has_focus(), "ui_left should return horizontally from Main Menu to New Run")
	await _press_ui_action(&"ui_accept")
	_assert(int(traversal_counts["new_run"]) == 1, "ui_accept should activate New Run after horizontal traversal")

	var animated_final_alpha: float = final_center_alpha
	overlay.set_motion_enabled(false)
	overlay.reset()
	overlay.present(model, death_site)
	await process_frame
	_assert(is_equal_approx(overlay.shroud_progress(), 1.0), "Reduced motion should skip directly to the completed shroud")
	_assert(is_equal_approx(overlay.sample_shroud_alpha(death_site), animated_final_alpha), "Reduced motion must preserve the same final localized shroud")
	_assert(recap_layout != null and is_equal_approx(recap_layout.modulate.a, 1.0), "Reduced motion must preserve the same fully readable recap")
	_assert(new_run_button != null and new_run_button.has_focus(), "Defeat recap should place keyboard/controller focus on New Run")

	var victory_model: Dictionary = RunEndRecapOverlay.build_model(run_state, ProgressionStore.default_data(), "victory", 12)
	overlay.present(victory_model)
	await process_frame
	_assert(is_zero_approx(overlay.shroud_progress()), "Victory should remain coherent without inheriting the defeat shroud")
	_assert(str(new_run_button.get_meta("button_variant", "")) == UiSkin.VARIANT_LARGE and str(main_menu_button.get_meta("button_variant", "")) == UiSkin.VARIANT_LARGE, "Victory should retain its established large action treatment instead of inheriting defeat's Obsidian raster")
	overlay.queue_free()
	await process_frame

func _test_run_scene_progression_and_actions() -> void:
	var engine := RunEngine.new()
	var progression: Dictionary = ProgressionStore.record_lost_embers(
		ProgressionStore.default_data(),
		19,
		Vector2i(3, 0),
		0
	)
	progression = ProgressionStore.prepare_for_new_run(progression)
	ProgressionStore.save_data(progression)
	var instance: Node = RUN_SCENE.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	var living_player: Dictionary = {"player": {"pos": Vector2i(3, 4), "hp": 18, "max_hp": 100}}
	var defeated_player: Dictionary = {"player": {"pos": Vector2i(3, 4), "hp": 0, "max_hp": 100}}
	var player_death_units: Array = instance.call("_defeated_player_units_between_states", living_player, defeated_player) as Array
	_assert(player_death_units.size() == 1 and str((player_death_units[0] as Dictionary).get("key", "")) == "player", "A lethal transition should retain the player for one authored death animation")
	_assert((player_death_units[0] as Dictionary).get("pos", Vector2i(-1, -1)) == Vector2i(3, 4), "Player death animation should remain on the exact lethal tile")

	var victory_state: Dictionary = _terminal_state(engine, progression, Vector2i(8, 0), "victory", 53)
	var helper_source: Dictionary = victory_state.duplicate(true)
	var live_state_before_helper: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	var helper_state: Dictionary = instance.call("_terminal_state_with_recorded_run_result", helper_source, progression) as Dictionary
	var helper_progression: Dictionary = helper_state.get("progression", {}) as Dictionary
	var helper_result: Dictionary = helper_state.get("run_result", {}) as Dictionary
	_assert(not helper_result.is_empty() and not ProgressionStore.run_result_for_id(helper_progression, RunEngine.run_result_id(helper_state)).is_empty(), "Terminal result helper should return a supplied state with its durable result decision embedded")
	_assert(engine.held_embers(helper_state) == 53, "Terminal result helper must preserve held embers for the caller's victory/defeat finalization")
	_assert(not helper_source.has("run_result") and (instance.get("_run_state") as Dictionary) == live_state_before_helper, "Terminal result helper should not mutate its supplied source or live RunScene state")
	var helper_replay: Dictionary = instance.call("_terminal_state_with_recorded_run_result", helper_state, helper_progression) as Dictionary
	_assert((helper_replay.get("run_result", {}) as Dictionary) == helper_result, "Terminal finalization retries should reuse the original result decision")
	instance.call("_load_run_state", victory_state)
	await process_frame
	var recap: Control = instance.get("_run_end_recap") as Control
	_assert(recap != null and recap.visible, "Victory should display the run recap over the board")
	var victory_model: Dictionary = recap.call("recap_model") if recap != null else {}
	_assert(int(victory_model.get("ember_amount", -1)) == 53, "Victory display should preserve the pre-clear carried amount")
	_assert(str(victory_model.get("recovery_status", "")) == "Marker expires · 19 embers unrecovered", "Victory display should communicate the marker consequence of starting the next run")
	_assert(int(ProgressionStore.load_data().get("embers", -1)) == 53, "Victory should commit banked embers before displaying the recap")
	_assert(engine.held_embers(instance.get("_run_state")) == 0, "Victory should clear embers from the ended run after banking")
	var victory_new_run_button: Button = recap.find_child("NewRunButton", true, false) as Button if recap != null else null
	if victory_new_run_button != null:
		victory_new_run_button.pressed.emit()
	await process_frame
	var restarted_state: Dictionary = instance.get("_run_state") as Dictionary
	_assert(str(restarted_state.get("mode", "")) == "room", "Victory New Run should begin a fresh run")
	_assert(engine.held_embers(restarted_state) == 53, "Victory New Run should carry the banked ember result")
	_assert(ProgressionStore.recovery_marker(restarted_state.get("progression", {}) as Dictionary).is_empty(), "Victory New Run should expire the marker exactly as the recap promises")

	progression = restarted_state.get("progression", {}) as Dictionary
	var defeat_state: Dictionary = _terminal_state(engine, progression, Vector2i(2, 0), "defeat", 41)
	instance.call("_load_run_state", defeat_state)
	await process_frame
	await process_frame
	recap = instance.get("_run_end_recap") as Control
	var defeat_model: Dictionary = recap.call("recap_model") if recap != null else {}
	_assert(int(defeat_model.get("ember_amount", -1)) == 41, "Defeat display should preserve the pre-clear lost amount")
	var defeat_stats: Dictionary = defeat_model.get("stats", {}) as Dictionary
	_assert(int(defeat_stats.get("enemies_killed", -1)) == 7 and int(defeat_stats.get("damage_dealt", -1)) == 620 and int(defeat_stats.get("damage_received", -1)) == 140, "Terminal recap should use the durable cumulative run-stat snapshot")
	var defeat_new_bests: Array = defeat_model.get("new_bests", []) as Array
	_assert(defeat_new_bests.has("enemies_killed") and defeat_new_bests.has("damage_dealt") and not defeat_new_bests.has("damage_received"), "Later strict improvements should surface only eligible NEW BEST fields")
	var board: Control = instance.get_node("BoardUnderlay/CombatBoard") as Control
	var death_tile: Vector2i = (defeat_state.get("current_room_layout", {}) as Dictionary).get("player_start", Vector2i(-1, -1))
	var ember_snapshot: Dictionary = board.call("death_site_embers_snapshot") as Dictionary
	_assert(ember_snapshot.get("tile", Vector2i(-1, -1)) == death_tile and ember_snapshot.get("texture", null) is Texture2D, "Death embers should be raster art owned by the exact terminal board tile")
	var ember_rect: Rect2 = ember_snapshot.get("rect", Rect2()) as Rect2
	var ember_tile_center: Vector2 = ember_snapshot.get("tile_center", Vector2.ZERO) as Vector2
	var ember_tile_width: float = float(ember_snapshot.get("tile_width", 0.0))
	_assert(ember_rect.size.x <= ember_tile_width * 0.40 and absf(ember_rect.get_center().x - ember_tile_center.x) < ember_tile_width * 0.03, "Death embers should fit the tile footprint instead of floating as a screen-space sticker")
	var reframe_start: Vector2 = instance.get("_run_end_board_reframe_start") as Vector2
	var reframe_target: Vector2 = instance.get("_run_end_board_reframe_target") as Vector2
	_assert(reframe_start.distance_to(reframe_target) > 1.0, "Defeat should author a real board translation toward the fixed Last Light window")
	instance.call("_seek_run_end_board_reframe", 0.5)
	_assert(board.position.distance_to(reframe_start.lerp(reframe_target, 0.5)) < 0.01, "Board reframing should interpolate continuously rather than snapping")
	instance.call("_seek_run_end_board_reframe", 1.0)
	var settled_board_position: Vector2 = board.position
	await process_frame
	await process_frame
	_assert(board.position.distance_to(settled_board_position) < 0.01, "The completed reframe should remain locked when subsequent UI focus frames render")
	var fixed_window: Vector2 = recap.call("death_site_normalized") as Vector2
	var centered_death_site: Vector2 = instance.call("_run_end_death_site_normalized") as Vector2
	_assert(centered_death_site.distance_to(fixed_window) < 0.004, "The translated board should settle with the actual death tile beneath the fixed Last Light window")
	var committed_defeat: Dictionary = ProgressionStore.load_data()
	var marker: Dictionary = ProgressionStore.recovery_marker(committed_defeat)
	_assert(int(committed_defeat.get("embers", -1)) == 0, "Defeat should commit zero carried embers")
	_assert(int(marker.get("amount", -1)) == 41 and ProgressionStore.recovery_coord(committed_defeat) == Vector2i(2, 0), "Defeat should commit the displayed recovery marker")
	var bests_before_replay: Dictionary = ProgressionStore.run_bests(committed_defeat)
	var result_before_replay: Dictionary = ProgressionStore.last_run_result(committed_defeat)
	instance.call("_load_run_state", defeat_state)
	await process_frame
	recap = instance.get("_run_end_recap") as Control
	var replay_model: Dictionary = recap.call("recap_model") if recap != null else {}
	_assert(ProgressionStore.run_bests(ProgressionStore.load_data()) == bests_before_replay, "Repeated terminal refresh/load must not double count or replace best values")
	_assert(ProgressionStore.last_run_result(ProgressionStore.load_data()) == result_before_replay, "Repeated terminal refresh/load must preserve the original just-finished result decision")
	_assert((replay_model.get("new_bests", []) as Array) == defeat_new_bests, "A repeated recap after profile reload should preserve NEW BEST eligibility")
	instance.call("_analytics_log_run_ended", "defeat")
	var events: Array[Dictionary] = AnalyticsStore.load_all_events()
	var run_ended_payload: Dictionary = {}
	for event: Dictionary in events:
		if str(event.get("event_type", "")) == "run_ended":
			run_ended_payload = (event.get("payload", {}) as Dictionary).duplicate(true)
	_assert(int(run_ended_payload.get("enemies_killed", -1)) == 7 and int(run_ended_payload.get("damage_dealt", -1)) == 620 and int(run_ended_payload.get("damage_received", -1)) == 140, "run_ended analytics should append all canonical performance stats")
	var defeat_new_run_button: Button = recap.find_child("NewRunButton", true, false) as Button if recap != null else null
	if defeat_new_run_button != null:
		defeat_new_run_button.pressed.emit()
	await process_frame
	var recovery_run: Dictionary = instance.get("_run_state") as Dictionary
	_assert(str(recovery_run.get("mode", "")) == "room" and engine.held_embers(recovery_run) == 0, "Defeat New Run should begin fresh without lost embers")
	var recovery_room: Dictionary = engine.room_metadata(recovery_run, Vector2i(2, 0))
	_assert(bool(recovery_room.get("recovery_marker", false)) and int(recovery_room.get("recovery_amount", 0)) == 41, "Defeat New Run should stage the committed recovery marker")

	var menu_state: Dictionary = _terminal_state(engine, recovery_run.get("progression", {}) as Dictionary, Vector2i(1, 0), "defeat", 0)
	instance.call("_load_run_state", menu_state)
	await process_frame
	current_scene = instance
	recap = instance.get("_run_end_recap") as Control
	var menu_button: Button = recap.find_child("MainMenuButton", true, false) as Button if recap != null else null
	if menu_button != null:
		menu_button.pressed.emit()
	await process_frame
	await process_frame
	await create_timer(0.14, true, false, true).timeout
	await process_frame
	_assert(current_scene != null and current_scene.scene_file_path == "res://scenes/main_menu.tscn", "Main Menu action should leave the ended run for the main menu")
	_assert(not ProgressionStore.has_saved_run(), "Main Menu action should clear any ended-run save")
	if current_scene != null:
		var finished_scene: Node = current_scene
		var music_player: AudioStreamPlayer = finished_scene.get_node_or_null("MusicPlayer") as AudioStreamPlayer
		if music_player != null:
			music_player.stop()
			music_player.stream = null
		current_scene = null
		finished_scene.free()
		await process_frame
		await create_timer(0.08).timeout

func _terminal_state(engine: RunEngine, progression: Dictionary, coord: Vector2i, outcome: String, held_embers: int) -> Dictionary:
	var state: Dictionary = engine.create_new_run(7319 + coord.x * 17 + held_embers, progression)
	var room: Dictionary = engine.room_metadata(state, coord).duplicate(true)
	room["revealed"] = true
	room["visited"] = true
	room["cleared"] = outcome == "victory"
	if outcome == "victory":
		room["type"] = "boss"
	var rooms: Dictionary = (state.get("rooms", {}) as Dictionary).duplicate(true)
	rooms[_room_key(coord)] = room
	state["rooms"] = rooms
	state["current_room"] = coord
	state["current_room_layout"] = engine.call("_display_layout_for_room", int(state.get("seed", 0)), room, Vector2i(1, 0))
	state["mode"] = outcome
	state["victory"] = outcome == "victory"
	state["game_over"] = outcome == "defeat"
	state["player_hp"] = 0 if outcome == "defeat" else int(state.get("player_max_hp", 1))
	state["held_embers"] = held_embers
	state["unbanked_embers"] = held_embers
	state["run_stats"] = {
		"enemies_killed": 5 if outcome == "victory" else 7,
		"damage_dealt": 500 if outcome == "victory" else 620,
		"damage_received": 120 if outcome == "victory" else 140
	}
	state["progression"] = progression.duplicate(true)
	return state

func _room_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

func _press_ui_action(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		event.strength = 1.0 if pressed else 0.0
		root.push_input(event)
		await process_frame
	await process_frame

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
