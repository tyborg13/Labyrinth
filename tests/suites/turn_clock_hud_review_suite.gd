extends RefCounted

const CombatEngine = preload("res://scripts/combat_engine.gd")
const Strip = preload("res://scripts/turn_order_landing_strip.gd")
const ForecastLine = preload("res://scripts/turn_clock_forecast_line.gd")
const CountedScene = preload("res://tests/helpers/turn_clock_counted_run_scene.gd")
const UiPalette = preload("res://scripts/ui_palette.gd")

static func run(tree: SceneTree, scene: Node, engine: CombatEngine, expect: Callable, fixture: Dictionary, install: Callable, hover: Callable, capture: Callable) -> void:
	_test_projection_tooltips(scene, engine, fixture, expect)
	_test_forecast_copy(scene, expect)
	_test_tutorial_placement(expect)
	await _test_expensive_paths(tree, scene.get_viewport(), fixture, expect)
	await _test_modals(tree, scene, fixture, install, hover, expect, capture)
	await _test_tutorial(tree, scene, fixture, install, hover, expect, capture)
	await _test_long_order(tree, scene, fixture, install, hover, expect, capture)

static func _projection(engine: CombatEngine, state: Dictionary, kind: String) -> Dictionary:
	for entry: Dictionary in engine.current_turn_order(state, 100):
		if str(entry.get("kind", "")) == "player" and str(entry.get("projection_kind", "")) == kind:
			return entry
	return {}

static func _test_projection_tooltips(scene: Node, engine: CombatEngine, fixture: Dictionary, expect: Callable) -> void:
	var end_now: Dictionary = _projection(engine, fixture, "end_now")
	var text: String = scene.call("_turn_order_tooltip", end_now, 0)
	expect.call(not end_now.is_empty() and text.contains("Base 9 + cards 0 + unused plays 10") and not text.contains("Carried") and not text.contains("Relics"), "End-now tooltip describes only the current activation's actual costs")
	var ended: Dictionary = engine.finish_player_activation(fixture)
	var follow_up: Dictionary = _projection(engine, ended, "follow_up")
	text = scene.call("_turn_order_tooltip", follow_up, 0)
	expect.call(not follow_up.is_empty() and text.contains("If that turn ends without a card") and not text.contains("Base ") and not text.contains("Carried") and not text.contains("Relics"), "Follow-up tooltip does not invent carried Time from the upcoming turn's ETA")
	var borrowed: Dictionary = fixture.duplicate(true)
	borrowed["relics"] = ["borrowed_hourglass"]
	var immediate: Dictionary = _projection(engine, borrowed, "end_now")
	text = scene.call("_turn_order_tooltip", immediate, 0)
	expect.call(bool(immediate.get("projected_extra_turn", false)) and int(immediate.get("eta", -1)) == 0 and int(immediate.get("projected_carried_time", -1)) == 10, "Turn-start Hourglass projection is immediate and carries exactly ten Wait")
	expect.call(text.contains("Borrowed Hourglass: another turn at once (+10 carried)") and not text.contains("Base ") and not text.contains("Carried +") and not text.contains("Relics"), "Immediate Hourglass tooltip reports carried Time without an invented relic reduction")

static func _test_forecast_copy(scene: Node, expect: Callable) -> void:
	var summary: Dictionary = {"wait_time": 0, "unrevealed_before_player": true, "hp_loss": 5, "entries": [{"text": "-5", "color": Color("f39779")}]}
	var entries: Array[Dictionary] = scene.call("_pass_preview_forecast_entries", summary)
	var line := ForecastLine.new()
	line.configure(0, entries)
	var cells: Array = line.get("_cells")
	expect.call(line.text == "TURN END  •  -5 +?" and cells[0]["color"] == Color("f39779") and cells[1]["color"] == Color("f39779") and cells.back()["color"] == Color("c89be3"), "Zero-Wait TURN END and bullet inherit known damage ink, while only +? stays violet")
	line.configure(5, entries)
	cells = line.get("_cells")
	expect.call(cells[0]["color"] == UiPalette.GOLD_BRIGHT and cells[1]["color"] == UiPalette.GOLD_BRIGHT and cells.back()["color"] == Color("c89be3"), "Pending Wait keeps its gold lead even with the violet suffix")
	line.free()
	summary["defiance_spent"] = 1
	summary["defiance_restored"] = 24
	summary["projected_hp"] = 24
	summary["projected_max_hp"] = 24
	summary["defiance_remaining_after"] = 0
	summary["net_hp_change"] = 19
	var text: String = scene.call("_pass_preview_tooltip", summary)
	expect.call(text.contains("A revealed lethal hit will spend 1 Defiance") and text.ends_with("Enemies have unrevealed actions before your next turn, you may take additional damage."), "Defiance tooltip retains its known outcome and appends the unrevealed-lap warning")
	expect.call(bool(scene.call("_pass_preview_known_damage_suffix", summary)), "Defiance plus an unrevealed lap retains the same +? plate semantics")

static func _test_tutorial_placement(expect: Callable) -> void:
	var viewport := Rect2(0, 0, 1920, 1080)
	var card := Rect2(850, 650, 250, 352)
	var stack := Rect2(1120, 520, 300, 430)
	var callout := Rect2(650, 530, 430, 150)
	var rect: Rect2 = Strip.placement(card, stack, Vector2(490.4, 64), viewport, callout)
	expect.call(rect.has_area() and viewport.grow(-16).encloses(rect) and not rect.intersects(stack) and not rect.intersects(callout), "Placement clears a tutorial callout and tooltip stack simultaneously")
	rect = Strip.placement(card, Rect2(), Vector2(374.8, 64), viewport, Rect2(520, 520, 300, 430))
	expect.call(is_equal_approx(rect.position.x, card.position.x - 8), "A callout on the left gets the same away-side alignment as a left tooltip")
	expect.call(not Strip.placement(card, stack, Vector2(374.8, 64), viewport, viewport).has_area(), "A tutorial covering every safe position hides the strip")

static func _test_expensive_paths(tree: SceneTree, viewport: Viewport, fixture: Dictionary, expect: Callable) -> void:
	var counted := CountedScene.new()
	counted.source_snapshot = fixture.duplicate(true)
	counted.set("_combat_state", fixture.duplicate(true))
	counted.set("_run_state", {"mode": "combat"})
	counted.set("_hovered_card_index", 1)
	var map := ColorRect.new()
	map.visible = false
	counted.add_child(map)
	counted.set("_large_map_scrim", map)
	var target := Control.new()
	target.position = Vector2(850, 650)
	target.size = Vector2(250, 352)
	viewport.add_child(target)
	var strip := Strip.new()
	viewport.add_child(strip)
	var entries: Array[Dictionary] = CombatEngine.new().current_turn_order(fixture, 100)
	strip.present(entries, 1, target, null, func(_entry: Dictionary) -> String: return "res://assets/art/icons/umbra_presence.png", Callable(counted, "_turn_order_landing_strip_allowed").bind(1), true)
	for _frame: int in range(30):
		strip.call("_process", 0.0)
	expect.call(strip.visible and counted.card_preview_reads == 0, "Thirty strip follow frames build no card previews")
	counted.set("_hovered_card_index", 3)
	strip.call("_process", 0.0)
	expect.call(not strip.visible and counted.card_preview_reads == 0, "Per-frame guard hides stale focused indices without rebuilding a preview")
	counted.set("_hovered_card_index", 1)
	var chip := Button.new()
	chip.name = "PassPreviewChip"
	var row := Control.new()
	row.name = "PassPreviewDamageRow"
	var line := ForecastLine.new()
	row.add_child(line)
	chip.add_child(row)
	counted.add_child(chip)
	var summary: Dictionary = counted.call("_pass_preview_summary")
	counted.call("_refresh_selected_card_forecast")
	counted.call("_update_action_context_risk")
	var tooltip: String = counted.call("_pass_preview_tooltip", summary)
	expect.call(counted.source_reads == 1 and int(summary.get("wait_time", -1)) == 10 and int(line.get_meta("pass_preview_wait_time", -1)) == 10 and tooltip.begins_with("Ending now leaves 2 card plays unused: +10 Time."), "Forecast line, context and tooltip reuse Wait after one isolated source read")
	counted.source_snapshot["cards_played_this_turn"] = 2
	counted.set("_combat_preview_revision", int(counted.get("_combat_preview_revision")) + 1)
	counted.call("_refresh_selected_card_forecast")
	expect.call(counted.source_reads == 2 and int(line.get_meta("pass_preview_wait_time", -1)) == 0 and line.text.begins_with("TURN END"), "A revised forecast source recomputes Wait once and clears the plate lead")
	strip.queue_free()
	target.queue_free()
	counted.free()
	await tree.process_frame

static func _test_modals(tree: SceneTree, scene: Node, fixture: Dictionary, install: Callable, hover: Callable, expect: Callable, capture: Callable) -> void:
	for selected: bool in [false, true]:
		for overlay: String in ["map", "pile"]:
			await install.call(tree, scene, fixture.duplicate(true))
			await hover.call(tree, scene, 1)
			if selected:
				await scene.call("_begin_card_preview", 1, scene.call("_card_preview_for_index", 1))
				await tree.process_frame
			var strip: Control = scene.get("_turn_order_landing_strip") as Control
			var phase: String = "%s_%s" % ["selected" if selected else "hover", overlay]
			expect.call(strip.visible and (not selected or int(scene.get("_selected_card_index")) == 1), "%s: the card preview and strip are active before opening the overlay" % phase)
			if overlay == "map":
				scene.call("_open_large_map", true)
			else:
				scene.call("_open_pile_view", "draw")
			await tree.process_frame
			await tree.process_frame
			expect.call((scene.get("_large_map_scrim" if overlay == "map" else "_pile_scrim") as Control).visible and not strip.visible, "%s: opening the actual modal hides the strip" % phase)
			await capture.call(phase)
			scene.call("_close_large_map" if overlay == "map" else "_close_pile_view")
	await install.call(tree, scene, fixture.duplicate(true))
	await hover.call(tree, scene, 1)
	var strip: Control = scene.get("_turn_order_landing_strip") as Control
	var temporary_confirmation: ColorRect
	if scene.get("_skill_reset_confirmation_scrim") == null:
		temporary_confirmation = ColorRect.new()
		temporary_confirmation.visible = false
		(scene.get("ui_root") as Control).add_child(temporary_confirmation)
		scene.set("_skill_reset_confirmation_scrim", temporary_confirmation)
	for property: String in ["_menu_scrim", "_grimoire_scrim", "_upgrade_scrim", "_pinned_tooltip_scrim", "_pre_battle_scrim", "_run_end_recap", "_skill_choice_scrim", "_skill_status_scrim", "_skill_reset_confirmation_scrim"]:
		var blocker: Control = scene.get(property) as Control
		expect.call(blocker != null, "Modal visibility fixture exists: %s" % property)
		if blocker == null:
			continue
		blocker.visible = true
		strip.call("_process", 0.0)
		expect.call(not strip.visible and not bool(scene.call("_turn_order_landing_strip_allowed")), "Strip hides while %s is visible" % property)
		blocker.visible = false
		scene.call("_refresh_turn_order_bar")
	for property: String in ["_dialogue_active", "_treasure_reveal_active", "_relic_claim_in_progress", "_loadout_acquisition_in_progress"]:
		scene.set(property, true)
		strip.call("_process", 0.0)
		expect.call(not strip.visible and not bool(scene.call("_turn_order_landing_strip_allowed")), "Strip respects the modal guard %s" % property)
		scene.set(property, false)
		scene.call("_refresh_turn_order_bar")
	if temporary_confirmation != null:
		scene.set("_skill_reset_confirmation_scrim", null)
		temporary_confirmation.queue_free()

static func _test_tutorial(tree: SceneTree, scene: Node, fixture: Dictionary, install: Callable, hover: Callable, expect: Callable, capture: Callable) -> void:
	await install.call(tree, scene, fixture.duplicate(true))
	await hover.call(tree, scene, 1)
	var strip: Control = scene.get("_turn_order_landing_strip") as Control
	var host: Control = scene.get("_contextual_combat_prompt_host") as Control
	var prompt: Control = scene.get("_contextual_combat_prompt") as Control
	host.visible = true
	prompt.call("configure", {"id": "strip_review", "title": "Watch the turn order", "message": "Time determines when you act again."}, [], [], true)
	await tree.process_frame
	await tree.process_frame
	var callout: Control = prompt.get_node("GuidedActionCallout") as Control
	callout.global_position = strip.global_position - Vector2(30, 30)
	scene.call("_refresh_turn_order_landing_strip")
	strip.call("_process", 0.0)
	var stack: Control = scene.get("_card_focus_tooltip_stack") as Control
	expect.call(strip.visible and not strip.get_global_rect().intersects(callout.get_global_rect()) and not strip.get_global_rect().intersects(stack.get_global_rect()), "Live tutorial callout and tooltip stack both stay clear of the strip")
	expect.call(strip.z_index + 8 < host.z_index and strip.z_index > 124, "Every strip child stays below the z1280 tutorial and above the board and hand")
	await capture.call("tutorial_callout")
	prompt.call("clear_prompt")
	host.visible = false

static func _test_long_order(tree: SceneTree, scene: Node, fixture: Dictionary, install: Callable, hover: Callable, expect: Callable, capture: Callable) -> void:
	var state: Dictionary = fixture.duplicate(true)
	# Six actors each contribute a scheduled turn and a revealed follow-up before
	# a heavy card's +20 hero. Keep one later actor for the dim after slot.
	state["enemies"] = []
	state["turn_queue"] = []
	for index: int in range(7):
		var enemy: Dictionary = (fixture["enemies"][0] as Dictionary).duplicate(true)
		enemy["id"] = index + 1
		enemy["pos"] = Vector2i(2 + index % 4, 2 + index / 4)
		enemy["intent"] = {"name": "Wait", "time": 0, "actions": []}
		state["enemies"].append(enemy)
		state["turn_queue"].append({"kind": "enemy", "enemy_id": index + 1, "time": 1 if index < 6 else 21, "seq": index + 1})
	await install.call(tree, scene, state)
	await hover.call(tree, scene, 3)
	var strip: Control = scene.get("_turn_order_landing_strip") as Control
	var roles: Dictionary = strip.role_entries()
	var all: Array[Dictionary] = scene.get("_turn_order_all_entries")
	var hero_index: int = -1
	for index: int in range(all.size()):
		if str(all[index].get("projection_kind", "")) == "end_now":
			hero_index = index
	var before: Array = roles.get("before", [])
	expect.call(hero_index > 10 and before.size() > 10 and strip.visible, "The strip finds a projected hero beyond ten preceding entries")
	var overflow: Label = strip.get_node_or_null("LandingStripOverflow") as Label
	expect.call(overflow != null and overflow.text == "+%d" % (before.size() - 4) and strip.has_node("LandingStripSlot_3") and not strip.has_node("LandingStripSlot_4"), "Long order remains four before portraits plus the exact +N count")
	var rail: Control = scene.get("_turn_order_bar") as Control
	var disclosed: int = 0
	for child: Node in rail.get_children():
		if child.has_meta("turn_order_actor_key"):
			disclosed += 1
	var rail_overflow: Label = rail.get_node_or_null("TurnOrderOverflowBadge") as Label
	var overflow_count: int = rail_overflow.text.to_int() if rail_overflow != null else 0
	expect.call(disclosed + overflow_count == 10, "The rail still discloses only ten entries while the strip sees the whole projection: %d slots plus %d overflow" % [disclosed, overflow_count])
	if rail_overflow != null:
		expect.call(rail_overflow.tooltip_text.split("\n").size() == 1 + overflow_count, "Rail overflow tooltip retains the same disclosure cap")
	var stack: Control = scene.get("_card_focus_tooltip_stack") as Control
	expect.call(not strip.get_global_rect().intersects(stack.get_global_rect()), "Long strip still clears the focused tooltip stack")
	await capture.call("beyond_rail_limit")
