extends RefCounted
const View = preload("res://scripts/event_view.gd")
const Events = preload("res://scripts/event_rules.gd")
const Data = preload("res://scripts/game_data.gd")
const Run = preload("res://scripts/run_engine.gd")
const Preview = preload("res://scripts/event_reward_preview.gd")
const Feedback = preload("res://scripts/event_scene_feedback.gd")
const Fixtures = preload("res://tests/suites/event_view_suite.gd")
const Clock = preload("res://tests/helpers/presentation_test_clock.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Omens = preload("res://scripts/omen_rules.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Rooms = preload("res://scripts/room_generator.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Beats = preload("res://scripts/event_result_beats.gd")
const Gain = preload("res://scripts/event_gain_effect.gd")
const Floating = preload("res://scripts/floating_combat_text.gd")
const PROOF_SIZE: Vector2i = Vector2i(1920, 1080)
const FIXTURE_READY_FRAMES: int = 240
const BEAT_FIXTURE_SEED: int = 15000
const ARRIVAL_SETTLE_SECONDS: float = 0.28
const LIFECYCLE_FIXTURE_SEED: int = 9000
const SKIP_INPUT_FIXTURE_SEED: int = 9010
const DEBUG_BEAT_STEP: float = 0.30
const DEBUG_FRAME_STEP: float = 0.01
const DEBUG_BEFORE_STAGGER: float = 0.24
const DEBUG_CROSS_STAGGER: float = 0.02
const DEBUG_DRAIN_STEP: float = 2.0
const DEBUG_EFFECT_FINISH_STEP: float = 3.0
const DEBUG_COUNTER_TARGET: Vector2 = Vector2(1800, 80)
const BEAT_CASES: Array = [
	["whispering_well", "ember"], ["fallen_lantern_bearer", "satchel"],
	["bloodletters_basin", "bleed"], ["ossuary_gamblers", "wager_embers"],
	["lost_cartographer", "embers"], ["whispering_well", "drink"],
	["weeping_statue", "pray"], ["starving_pilgrim", "item"],
	["ossuary_gamblers", "wager_blood"], ["hanged_knight", "cut"],
	["shrine_last_door", "candle"], ["shrine_last_door", "kneel"],
	["mirror_of_skins", "trade"], ["abandoned_forge", "weapon"]
]
const CASES: Array = [
	["whispering_well", "ember", "card"], ["moth_library", "search", "card_choice"],
	["fallen_lantern_bearer", "satchel", "item"], ["bloodletters_basin", "bleed", "relic"],
	["ossuary_gamblers", "wager_embers", "equipment"], ["shrine_last_door", "candle", "omen"],
	["mirror_of_skins", "hand", "transform"], ["abandoned_forge", "weapon", "reforge"],
	["starving_pilgrim", "item", "lose_item"]
]

static func run(expect: Callable) -> void:
	var tree: SceneTree = Engine.get_main_loop()
	await Clock.run_scoped(tree, func(_scope: Clock.GlobalScope) -> void:
		Store.set_storage_path("user://evt02_profile.json")
		Store.set_run_storage_path("user://evt02_run.save")
		Settings.set_storage_path("user://evt02_settings.json")
		await _checks(tree, expect))

static func _checks(tree: SceneTree, expect: Callable) -> void:
	var viewport := SubViewport.new()
	viewport.size = PROOF_SIZE
	tree.root.add_child(viewport)
	var view := View.new()
	viewport.add_child(view)
	var engine := Run.new()
	# Receipts and previews own deep copies; no case writes the base run.
	var fixture_base: Dictionary = engine.create_new_run(Fixtures.FIXTURE_SEED, Store.default_data())
	var cases: int = 0
	var kinds: Dictionary = {}
	# Check every authored concrete line against resolver output without new rolls.
	for id: String in Data.events():
		var state: Dictionary = _fixture(fixture_base, id, true)
		for choice: Dictionary in Data.event_def(id)["choices"]:
			var cid: String = str(choice["id"])
			if not Events.choice_available(state, id, cid): continue
			var bytes: PackedByteArray = var_to_bytes(state)
			var outcomes: Array[Dictionary] = Events.preview_choice(state, cid)
			var result: Dictionary = engine.resolve_map_event(state, cid)
			expect.call(result["event_state"]["outcomes"] == outcomes and var_to_bytes(state) == bytes, "Concrete preview equals committed outcome without mutation: " + id + "/" + cid)
			var all_ids: Array = []
			for outcome: Dictionary in outcomes: all_ids.append_array(Preview.outcome_line(outcome)["ids"])
			for line: Dictionary in Events.preview_lines(state, id, cid):
				for concrete_id: String in line["ids"]: expect.call(all_ids.has(concrete_id), "Preview id comes from preview_choice: " + concrete_id)
			cases += 1
	print("Event feedback content: %d authored choices match preview_choice" % cases)
	for fixture: Array in CASES:
		var state: Dictionary = _fixture(fixture_base, fixture[0], true)
		view.present(state, true)
		view.finish_animation_for_test()
		expect.call(view.hover_preview.cache.is_empty(), "Opening builds no preview widgets: " + fixture[2])
		var index: int = _choice_index(view, fixture[1])
		expect.call(index >= 0, "Choice fixture exists")
		view.choices[index].mouse_entered.emit()
		var shown: Control = view.hover_preview.current
		var line: Dictionary = Preview.first_concrete(Events.preview_lines(state, fixture[0], fixture[1]))
		expect.call(shown != null and shown.get_meta("preview_line") == line, "Hover shows first concrete line: " + fixture[2])
		if shown == null: continue
		kinds[str(line["kind"])] = true
		expect.call(line["kind"] == fixture[2], "Fixture covers " + fixture[2])
		var rendered_ids: Array[String]
		_rendered_ids(shown, rendered_ids)
		var expected_ids: Array[String]
		for concrete_id: String in line["ids"]:
			expected_ids.append(concrete_id)
			if line["kind"] in ["equipment", "reforge"]: expected_ids.append_array(Data.equipment_cards(concrete_id, state))
		expect.call(rendered_ids == expected_ids, "Actual widgets and icons match concrete ids: " + fixture[2])
		expect.call(shown.size.x <= Preview.MAX_WIDTH and shown.size.y <= view.ART_RECT.size.y, "Concrete preview fits painting: " + fixture[2] + " " + str(shown.size))
		expect.call(view.preview_brightness == 0.32, "Reduced hover dims instantly")
		view.choices[index].mouse_exited.emit()
		view.choices[index].focus_entered.emit()
		expect.call(view.hover_preview.current == shown and shown.visible and view.hover_preview.cache.size() == 1, "Focus reuses exact hover widget: " + fixture[2])
		_expect_ignores_input(shown, expect)
		expect.call(is_equal_approx(view.health.size.x, 240) and view.health.hp == state["player_hp"], "Choices show current Health")
		var after: Dictionary = engine.resolve_map_event(state, fixture[1])
		view.present(after, false)
		view.finish_animation_for_test()
		var committed_bytes: PackedByteArray = var_to_bytes(after)
		view.play_result_beats(state, {}, Callable())
		var beats: Control = view.result_beats
		expect.call(beats != null, "Result starts committed beat projection")
		beats.set_process(false)
		beats._process(DEBUG_BEAT_STEP)
		for child: Node in beats.get_children():
			if child.has_method("_process"): child._process(0.16)
		view.finish_result_beats()
		expect.call(beats.get_child_count() == 0 and view.result_beats == null, "Skip cleans all beat sprites: " + fixture[2])
		expect.call(view.health.hp == after["player_hp"] and view.health.cap == after["player_max_hp"], "Skip snaps exact Health")
		expect.call(var_to_bytes(after) == committed_bytes and view.run_state == after, "Beats never alter committed outcomes")
		view.play_result_beats(state, {}, Callable())
		expect.call(view.result_beats == null, "Stale visual receipt cannot replay")
		await tree.process_frame
	expect.call(kinds.size() == CASES.size(), "Every concrete preview kind is exercised")
	# Disabled and plain choices never build widgets.
	var blocked: Dictionary = _fixture(fixture_base, "bloodletters_basin")
	blocked["player_hp"] = 1
	view.present(blocked, true)
	view.finish_animation_for_test()
	view.preview_choice(0)
	expect.call(view.hover_preview.current_line.is_empty() and view.hover_preview.cache.is_empty(), "Disabled choice has no preview")
	view.present(_fixture(fixture_base, "lost_cartographer"), true)
	view.finish_animation_for_test()
	view.preview_choice(0)
	expect.call(view.hover_preview.cache.is_empty(), "Plain gain has no preview")
	await _lifecycle(view, tree, expect, fixture_base)
	await _all_beats(view, tree, expect, fixture_base)
	await _feedback1_ui(view, tree, expect, fixture_base)
	_omen_application_checks(expect)
	view.queue_free()
	await tree.process_frame
	await _integration(viewport, tree, expect, fixture_base)
	viewport.queue_free()
	await tree.process_frame

static func _lifecycle(view: Control, tree: SceneTree, expect: Callable, fixture_base: Dictionary) -> void:
	var before: Dictionary = _fixture(fixture_base, "hanged_knight", true)
	var after: Dictionary = Run.new().resolve_map_event(before, "cut")
	for reduced: bool in [false, true]:
		# Unique debug-only seed per independent receipt.
		before["seed"] = LIFECYCLE_FIXTURE_SEED + int(reduced)
		after["seed"] = before["seed"]
		view.present(before, reduced)
		view.finish_animation_for_test()
		view.present(after, reduced)
		view.finish_animation_for_test()
		view.play_result_beats(before, {}, Callable())
		var beats: Control = view.result_beats
		beats.set_process(false)
		beats._process(DEBUG_BEAT_STEP)
		if reduced:
			for effect: Node in beats.get_children():
				expect.call(effect.reduced_motion, "Reduced effect uses fade path")
				effect._process(0.13)
		else:
			var key := InputEventKey.new()
			key.keycode = KEY_SPACE
			key.pressed = true
			view.handle_input(key)
			expect.call(view.result_beats == null, "Any pressed key finishes all beats")
		view.finish_result_beats()
		await tree.process_frame
		expect.call(beats == null or not is_instance_valid(beats), "Finished receipt releases nodes")
		view.present(after, reduced)
		expect.call(view.result_beats == null and view.health.hp == after["player_hp"], "Reloaded result stays final without replay")
	for input_kind: String in ["mouse", "controller", "pause"]:
		before["seed"] = SKIP_INPUT_FIXTURE_SEED + ["mouse", "controller", "pause"].find(input_kind)
		after["seed"] = before["seed"]
		view.present(before, false)
		view.finish_animation_for_test()
		view.present(after, false)
		view.finish_animation_for_test()
		view.play_result_beats(before, {}, Callable())
		var event: InputEvent
		if input_kind == "mouse":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = MOUSE_BUTTON_LEFT
			mouse.pressed = true
			event = mouse
		elif input_kind == "controller":
			var button := InputEventJoypadButton.new()
			button.button_index = JOY_BUTTON_A
			button.pressed = true
			event = button
		else:
			var pause := InputEventKey.new()
			pause.keycode = KEY_ESCAPE
			pause.pressed = true
			event = pause
		view.handle_input(event)
		expect.call(view.result_beats == null and view.health._popups.is_empty(), "Pressed %s finishes all beats and floating numbers" % input_kind)
		await tree.process_frame

static func _integration(viewport: SubViewport, tree: SceneTree, expect: Callable, fixture_base: Dictionary) -> void:
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	viewport.add_child(scene)
	for frame: int in range(FIXTURE_READY_FRAMES):
		if scene.call("initial_presentation_is_ready"): break
		await tree.process_frame
	var before: Dictionary = _fixture(fixture_base, "hanged_knight", true)
	scene.call("_load_run_state", before)
	var view: Control = scene.get("_event_view")
	view.finish_animation_for_test()
	scene.call("_on_section_map_event", "cut")
	expect.call(view.result_beats != null, "Production event choice starts result beats")
	var bounds := Rect2(Vector2.ZERO, Vector2(PROOF_SIZE))
	for key: String in Feedback.destinations(scene):
		var target: Dictionary = Feedback.destinations(scene)[key]
		expect.call(bounds.has_point(target["position"]), "HUD destination is on screen at 1920x1080: " + key + " " + str(target["position"]))
	expect.call(Feedback.destinations(scene)["deck"]["control"] == scene.get("loadout_button"), "Cards fly to the visible loadout button")
	var committed: Dictionary = scene.get("_run_state").duplicate(true)
	scene.call("_save_run_progress")
	expect.call(view.result_beats == null, "Explicit save finishes beats")
	var saved: Dictionary = Store.load_saved_run()
	expect.call(not saved.is_empty() and saved.get("event_state") == committed["event_state"], "Saved file contains the committed result without presentation state")
	scene.call("_load_run_state", saved)
	expect.call(view.result_beats == null and scene.get("_run_state")["event_state"] == committed["event_state"], "Load preserves committed result without replay")
	scene.call("_on_section_map_event", "cut")
	expect.call(view.result_beats == null and scene.get("_run_state")["event_state"] == committed["event_state"], "Stale event request cannot reapply outcomes or beats")
	var combat: Dictionary = Fixtures.combat_fixture()
	expect.call(not Feedback.firing_omens(combat["combat_state"]).is_empty(), "Combat start identifies applying omens")
	scene.call("_load_run_state", combat)
	Feedback.combat_start(scene)
	var feedback: Control = scene.get("ui_root").get_node_or_null("CombatOmenFeedback")
	expect.call(feedback != null and feedback.entries.size() == Feedback.firing_omens(combat["combat_state"]).size(), "Every applying omen has one combat popup")
	if feedback != null:
		feedback.set_process(false)
		feedback._process(DEBUG_FRAME_STEP)
		expect.call(feedback.next == 1, "First omen fires at fight start")
		feedback._process(Feedback.START_STAGGER)
		expect.call(feedback.next == mini(2, feedback.entries.size()), "Combat omens stagger at 0.12 seconds")
	scene.queue_free()
	await tree.process_frame

static func _all_beats(view: Control, tree: SceneTree, expect: Callable, fixture_base: Dictionary) -> void:
	var seed_value: int = BEAT_FIXTURE_SEED
	var exercised: Dictionary = {}
	var counter := Label.new()
	view.get_parent().add_child(counter)
	var counts: Array[int]
	var target: Dictionary = {"control": counter, "position": DEBUG_COUNTER_TARGET, "update": func(value: int) -> void: counts.append(value)}
	for reduced: bool in [false, true]:
		for fixture: Array in BEAT_CASES:
			var before: Dictionary = _fixture(fixture_base, fixture[0], true)
			before["seed"] = seed_value
			seed_value += 1
			before["player_hp"] = 24
			before["player_max_hp"] = 30
			var after: Dictionary = Run.new().resolve_map_event(before, fixture[1])
			view.present(before, reduced)
			view.finish_animation_for_test()
			view.present(after, reduced)
			view.finish_animation_for_test()
			view.play_result_beats(before, {"embers": target, "map": target}, Callable())
			var beats: Control = view.result_beats
			beats.set_process(false)
			expect.call(beats._next == 1, "Only first outcome starts immediately")
			beats._process(DEBUG_BEFORE_STAGGER)
			expect.call(beats._next == 1, "Next outcome waits the full 0.25 seconds")
			beats._process(DEBUG_CROSS_STAGGER)
			var expected_next: int = 2 if beats.start_times.size() > 1 and beats.start_times[1] <= DEBUG_BEFORE_STAGGER + DEBUG_CROSS_STAGGER else 1
			expect.call(beats._next == expected_next, "Next outcome respects its stagger and centre occupancy")
			beats._process(DEBUG_DRAIN_STEP)
			for outcome: Dictionary in after["event_state"]["outcomes"]: exercised[outcome["type"]] = true
			for effect: Node in beats.get_children():
				if effect.has_method("_process"):
					effect.set_process(false)
					var node_count: int = effect.get_child_count()
					effect._process(DEBUG_FRAME_STEP)
					expect.call(effect.get_child_count() == node_count, "A beat frame retains its sprite subtree")
					effect._process(DEBUG_EFFECT_FINISH_STEP)
			await tree.create_timer(ARRIVAL_SETTLE_SECONDS).timeout
			if is_instance_valid(beats): beats._process(DEBUG_DRAIN_STEP)
			await tree.process_frame
			expect.call(view.result_beats == null and not is_instance_valid(beats), "All beats finish and release nodes, reduced=%s: %s" % [reduced, fixture[0]])
			expect.call(counter.scale == Vector2.ONE and counter.modulate == Color.WHITE, "HUD pulse and Ember feedback restore final state")
			expect.call(view.health.hp == after["player_hp"] and view.health.cap == after["player_max_hp"], "Natural completion restores committed Health")
			expect.call(view.panel.position == view.PANEL_RECT.position and float(view.art.material.get_shader_parameter("saturation")) == 1, "Shake and bane painting drain finish cleanly")
	for kind: String in ["card", "item", "relic", "equipment", "embers", "hp", "heal", "heal_percent", "max_hp", "omen", "defiance", "lose_item", "transform_magic", "reforge"]:
		expect.call(exercised.has(kind), "Natural/reduced completion matrix covers " + kind)
	expect.call(not counts.is_empty(), "Embers use the shared rolling feedback values")
	counter.queue_free()
	print("Event feedback beats: %d real choices × normal/reduced completion" % BEAT_CASES.size())

static func _expect_ignores_input(node: Node, expect: Callable) -> void:
	if node is Control: expect.call(node.mouse_filter == Control.MOUSE_FILTER_IGNORE and node.focus_mode == Control.FOCUS_NONE and node.tooltip_text.is_empty(), "Preview is input transparent: " + str(node.name))
	for child: Node in node.get_children(): _expect_ignores_input(child, expect)

static func _feedback1_ui(view: Control, tree: SceneTree, expect: Callable, fixture_base: Dictionary) -> void:
	var before: Dictionary = _fixture(fixture_base, "bloodletters_basin", true)
	view.present(before, false)
	view.finish_animation_for_test()
	var strip: Control = view.health
	var after: Dictionary = Run.new().resolve_map_event(before, "bleed")
	view.present(after, false)
	var transition: Tween = view.get("_transition")
	transition.pause()
	transition.custom_step(0.04)
	expect.call(view.column.modulate.a == 0 and view.get("_old_column").modulate.a > 0, "Result stays transparent throughout the old page's 0.08-second fade")
	expect.call(view.health == strip and strip.modulate == Color.WHITE, "Health is persistent and never joins the page fade")
	transition.custom_step(0.04)
	var old_page: Control = view.get("_old_column")
	expect.call((old_page == null or is_zero_approx(old_page.modulate.a)) and is_zero_approx(view.column.modulate.a), "Old page is fully invisible before result fade starts")
	transition.custom_step(0.07)
	expect.call(is_equal_approx(view.column.modulate.a, 0.5), "New page fades over 0.14 seconds after the old page")
	transition.custom_step(0.07)
	expect.call(is_equal_approx(view.column.modulate.a, 1.0) and view.health == strip, "Sequential page fade retains one Health node")
	view.finish_animation_for_test()
	for sample: Array in [["hp", -5], ["heal", 8], ["max_hp", -2]]:
		strip.finish(24, 30)
		strip.beat(sample[0], sample[1], false)
		var label: Label = strip._popups.back()
		var entry: Dictionary = Floating.damage_entry(Vector2i.ZERO, label.text, Color.WHITE)
		for progress: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
			entry["font_size"] = Floating.DAMAGE_BASE_FONT_SIZE
			Floating._animate_damage_entry(entry, progress, false)
			strip._pose_number(label, entry, strip._bar.position, progress, false)
			var rect := Rect2(label.position, label.get_combined_minimum_size() * label.scale)
			# ui-12 (director): a big number may rise past the panel's top edge
			# over the backdrop; it stays within the panel's sides and above its bottom.
			var bounds: Rect2 = strip.panel_bounds
			expect.call(rect.position.x >= bounds.position.x - 0.01 and rect.end.x <= bounds.end.x + 0.01 and rect.end.y <= bounds.end.y + 0.01, "Health popup stays within the panel's sides: " + label.text)
			expect.call(label.scale.x < 0.8 or is_equal_approx(label.scale.x, 0.8), "Health popup uses at most 0.8 of its previous size")
			expect.call(is_equal_approx(rect.get_center().x, strip._bar.position.x), "Health popup is anchored at the bar's left end")
			var bottom_rise: float = strip._bar.position.y - strip.NUMBER_BAR_GAP - rect.end.y
			expect.call(bottom_rise >= -0.01 and bottom_rise <= strip.NUMBER_MAX_RISE + 0.01, "Health popup rises no more than 34 pixels from its bottom anchor")
		strip.finish(24, 30)
	for fixture: Array in CASES:
		if fixture[2] not in ["relic", "equipment", "omen"]: continue
		var state: Dictionary = _fixture(fixture_base, fixture[0], true)
		view.present(state, true)
		view.finish_animation_for_test()
		view.preview_choice(_choice_index(view, fixture[1]))
		var stage: Control = view.hover_preview.current
		var panels: Array[Node] = stage.find_children("*", "PanelContainer", true, false)
		var detail: PanelContainer
		for node: Node in panels:
			if bool(node.get_meta("tooltip_surface", false)): detail = node
		expect.call(detail != null and is_equal_approx(detail.get_combined_minimum_size().x, 420), "Preview uses the shared 420-pixel tooltip material: " + fixture[2])
		if detail != null:
			var icon: TextureRect = detail.get_parent().get_child(0)
			expect.call(icon.custom_minimum_size == Vector2(128, 128) and icon.get_parent() == detail.get_parent(), "128-pixel icon sits above the detail panel")
			expect.call(detail.z_index + detail.get_node("ThemedInsetOrnament").z_index >= 0, "Embedded tooltip ornament paints above the event painting")
		var line: Dictionary = Preview.first_concrete(view.cached_preview_lines(fixture[1]))
		var beat: Control = Preview.build(line, state, true)
		var names: Array[Node] = beat.find_children("*", "Label", true, false)
		expect.call(names.size() == 1 and not str(names[0].get("text")).is_empty(), "Beat shows an icon and name without rules or gear cards: " + fixture[2])
		var effect := Gain.new()
		effect.kind = fixture[2]
		effect.content = beat
		effect.origin = Rect2(view.painting_center() - beat.size * 0.5, beat.size)
		(view.get("_canvas") as Control).add_child(effect)
		effect.set_process(false)
		effect._process(Gain.RISE_SECONDS)
		var glow: ColorRect = effect.get("_radial_glow")
		var art_rect: Rect2 = beat.get_meta("reward_art_rect")
		expect.call(glow != null and is_equal_approx(glow.size.x * 0.5, maxf(art_rect.size.x, art_rect.size.y) * 1.4), "Event glow has the exact radial extent around the reward art")
		expect.call(is_equal_approx(float(glow.material.get_shader_parameter("glow_color").a), 0.4) and effect._glow_layers.is_empty(), "Event glow uses 0.40 alpha and no merchant rectangle")
		effect.free()
	var overlap: Array[float] = Beats.schedule([{"type": "equipment", "id": "fixture"}, {"type": "omen", "id": "hunted"}, {"type": "relic", "id": "fixture"}], false)
	expect.call(is_equal_approx(overlap[1], 0.38) and is_equal_approx(overlap[2], 0.80), "Each centre reward begins when the previous reward starts flight")
	var loss: Array[float] = Beats.schedule([{"type": "lose_item", "id": "fixture"}, {"type": "card", "id": "fixture"}], false)
	expect.call(is_equal_approx(loss[1], 0.4), "A dissolving item owns the centre until its dissolve finishes")
	# Hover during the opening never constructs its widgets on that frame path.
	var opening := View.new()
	view.get_parent().add_child(opening)
	opening.present(before, false)
	opening.preview_choice(0)
	expect.call(opening.hover_preview.cache.is_empty(), "Opening hover defers widget construction until the surface is ready")
	var intro: Tween = opening.get("_opening")
	intro.pause()
	intro.custom_step(0.23)
	expect.call(opening.hover_preview.cache.size() == 1, "Pending opening hover builds exactly once after opening")
	opening.queue_free()
	await tree.process_frame
	for fixture: Array in [["lost_cartographer", "embers"], ["starving_pilgrim", "item"]]:
		var state: Dictionary = _fixture(fixture_base, fixture[0], true)
		var resolved: Dictionary = Run.new().resolve_map_event(state, fixture[1])
		view.present(state, false)
		view.finish_animation_for_test()
		view.present(resolved, false)
		view.finish_animation_for_test()
		var cues: Array[String]
		view.play_result_beats(state, {}, func(id: String) -> void: cues.append(id))
		if fixture[0] == "lost_cartographer": expect.call(cues.size() == 1 and cues[0] == "pickup.item", "Ember beat plays the director's pickup.item cue")
		else: expect.call(cues.is_empty(), "Item dissolve remains silent")
		view.finish_result_beats()
		await tree.process_frame
	print("Event feedback 1 UI: sequential pages, persistent Health, bounded numbers, material, centre scheduling and radial glow checked")

static func _omen_application_checks(expect: Callable) -> void:
	var engine := Run.new()
	var combat := Combat.new()
	var generator := Rooms.new()
	var base_run: Dictionary = engine.create_new_run(BEAT_FIXTURE_SEED, Store.default_data())
	var room: Dictionary = {"coord": Vector2i(1, 2), "type": "combat", "depth": 1, "element": "fire", "connections": []}
	var plain: Dictionary = generator.generate_room(BEAT_FIXTURE_SEED, room, Vector2i.ZERO)
	var base: Dictionary = combat.create_combat(BEAT_FIXTURE_SEED, plain, engine._player_snapshot(base_run))
	var covered: Dictionary = {}
	for id: String in Data.omens():
		var effect: Dictionary = Data.omen_def(id)["effect"]
		var type: String = effect["type"]
		covered[type] = true
		var with_omen: Dictionary = Omens.add(base_run, id)
		var layout: Dictionary = plain
		if type == "extra_enemies":
			var extra_room: Dictionary = room.duplicate(true)
			extra_room["omen_extra_enemies"] = int(effect["amount"])
			layout = generator.generate_room(BEAT_FIXTURE_SEED, extra_room, Vector2i.ZERO)
		var created: Dictionary = combat.create_combat(BEAT_FIXTURE_SEED, layout, engine._player_snapshot(with_omen))
		var announced: Array[Dictionary] = Feedback.firing_omens(created)
		expect.call((not announced.is_empty()) == (type != "ember_drop_percent"), "Only an applied fight-start effect announces: " + type)
		expect.call(Feedback.firing_omens(bytes_to_var(var_to_bytes(created))) == announced, "Application receipt survives combat save roundtrip: " + type)
	expect.call(covered.size() == Omens.EFFECT_TYPES.size(), "Every omen effect type has application coverage")
	for special_type: String in ["boss", "guardian", "special"]:
		var special: Dictionary = room.duplicate(true)
		special["type"] = special_type
		special["boss_id"] = "zekarion" if special_type == "boss" else "vyraketh"
		var ordinary_layout: Dictionary = generator.generate_room(BEAT_FIXTURE_SEED, special, Vector2i.ZERO)
		special["omen_extra_enemies"] = 1
		var hunted_layout: Dictionary = generator.generate_room(BEAT_FIXTURE_SEED, special, Vector2i.ZERO)
		expect.call(hunted_layout["enemies"] == ordinary_layout["enemies"], "Hunted adds no enemy in " + special_type)
		var created: Dictionary = combat.create_combat(BEAT_FIXTURE_SEED, hunted_layout, engine._player_snapshot(Omens.add(base_run, "hunted")))
		expect.call(Feedback.firing_omens(created).is_empty(), "Hunted does not falsely fire in " + special_type)
	var full_layout: Dictionary = plain.duplicate(true)
	full_layout["grid"] = [[Rooms.TILE_WALL]]
	var full_room: Dictionary = room.duplicate(true)
	full_room["omen_extra_enemies"] = 1
	generator._add_omen_enemies(full_layout, full_room, BEAT_FIXTURE_SEED)
	expect.call(not full_layout.has("omen_extra_enemies_added"), "A full board records no added enemy")
	var full: Dictionary = Omens.start_combat(combat, base.duplicate(true), Omens.add(base_run, "hunted"), int(full_layout.get("omen_extra_enemies_added", 0)))
	expect.call(Feedback.firing_omens(full).is_empty(), "Hunted does not fire when no extra enemy could be placed")
	for type: String in ["start_block", "start_stoneskin", "start_expose", "start_vision_turns", "first_turn_card_plays", "first_turn_movement"]:
		var id: String = "evt02_noop_" + type
		var effect: Dictionary = {"type": type, "amount": -99 if type in ["first_turn_card_plays", "first_turn_movement"] else 0, "radius": 0}
		Data.omens()[id] = {"name": "No-op fixture", "kind": "bane", "fights": 1, "description": "Fixture", "effect": effect}
		var trial: Dictionary = base.duplicate(true)
		trial["cards_per_turn"] = 1
		trial["card_play_bonus_this_turn"] = 0
		trial["player_movement_capacity"] = 0
		trial["player_movement_remaining"] = 0
		trial["umbra"]["vision_bonus_activations"] = -1
		trial = Omens.start_combat(combat, trial, Omens.add(base_run, id))
		expect.call(Feedback.firing_omens(trial).is_empty(), "Zero/clamped effect does not fire: " + type)
		Data.omens().erase(id)
	var deepest: Dictionary = base.duplicate(true)
	deepest["umbra"]["stage"] = Combat.UMBRA_STAGE_HEART
	deepest = Omens.start_combat(combat, deepest, Omens.add(base_run, "deepening_dark"))
	expect.call(Feedback.firing_omens(deepest).is_empty(), "Clamped Umbra stage does not falsely fire")
	var burning: Dictionary = base.duplicate(true)
	Surfaces.place(burning, burning["player"]["pos"], "fire")
	burning = Omens.start_combat(combat, burning, Omens.add(base_run, "kindled"))
	expect.call(Feedback.firing_omens(burning).is_empty(), "Kindled on existing Fire does not falsely fire")
	var blocked: Dictionary = base.duplicate(true)
	blocked["player"]["pos"] = Vector2i(-1, -1)
	blocked = Omens.start_combat(combat, blocked, Omens.add(base_run, "kindled"))
	expect.call(Feedback.firing_omens(blocked).is_empty(), "Kindled on an invalid tile does not falsely fire")
	print("Event feedback 1 omens: all 10 effect types; boss/Guardian/special/full-board and clamped/no-op negatives checked")

static func _rendered_ids(node: Node, ids: Array[String]) -> void:
	if node.has_method("set_card_definition"): ids.append(str(node.get("card_id")))
	elif node is PanelContainer and node.has_meta("reward_id"): ids.append(str(node.get_meta("reward_id")))
	for child: Node in node.get_children(): _rendered_ids(child, ids)

static func _choice_index(view: Control, cid: String) -> int:
	for index: int in range(view.choices.size()):
		if view.choices[index].choice_id == cid: return index
	return -1

static func _fixture(template: Dictionary, id: String, rich: bool = false) -> Dictionary:
	return Fixtures.fixture(id, rich, template)
