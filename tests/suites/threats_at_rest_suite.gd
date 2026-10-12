extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const Tiles = preload("res://scripts/threat_tiles.gd")
const Callouts = preload("res://scripts/intent_callouts.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const FloatingText = preload("res://scripts/floating_combat_text.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const Board = preload("res://scripts/combat_board_view.gd")

# Test/proof-only choices, never production tuning.
const FIXTURE_SEED: int = 126065
const FIXTURE_HERO: Vector2i = Vector2i(4, 4)
const FIXTURE_QUEUE_TIMES: Array = [8, 11, 12, 13]
const FIXTURE_GRID_SIDE: int = 9

static func run(expect: Callable) -> void:
	_test_order_and_tiles(expect)
	_test_projection_repeats_and_inactive(expect)
	_test_previews_and_privacy(expect)
	_test_callouts(expect)
	_test_style_and_overlap(expect)
	_test_director_decisions(expect)
	_test_stage_plumbing(expect)

static func staged_layout() -> Dictionary:
	var grid: Array
	for y: int in range(FIXTURE_GRID_SIDE):
		var row: Array[String]
		for x: int in range(FIXTURE_GRID_SIDE):
			row.append("wall" if x == 0 or y == 0 or x == FIXTURE_GRID_SIDE - 1 or y == FIXTURE_GRID_SIDE - 1 else "stone")
		grid.append(row)
	# Same hero-relative roster/placement as b_enemy_turn.gd. Its generated
	# room normalizer is unavailable in this base; use a headless open fixture.
	return {"name": "Threats at Rest Proof", "coord": Vector2i(1, 0), "type": "combat", "depth": 2,
		"umbra_stage": "clear", "grid": grid, "player_start": FIXTURE_HERO,
		"terrain": [], "traps": [], "loot": [], "enemies": [
			foe(1, "crawler", Vector2i(2, 0), "skitter_strike"),
			foe(2, "acolyte", Vector2i(0, -3), "dust_bolt"),
			foe(3, "frostglass_lancer", Vector2i(0, 3), "glass_lunge"),
			foe(4, "harrier", Vector2i(-3, 0), "pelt")]}

static func foe(id: int, kind: String, offset: Vector2i, intent_id: String) -> Dictionary:
	var definition: Dictionary = GameData.enemy_def(kind)
	var intent: Dictionary = {}
	for candidate: Dictionary in definition.get("intents", []):
		if str(candidate.get("id", "")) == intent_id: intent = candidate.duplicate(true)
	return {"id": id, "type": kind, "pos": FIXTURE_HERO + offset,
		"hp": definition.get("max_hp", 14), "max_hp": definition.get("max_hp", 14), "intent": intent}

static func staged_state(combat: RefCounted) -> Dictionary:
	var layout: Dictionary = staged_layout()
	var state: Dictionary = combat.create_combat(FIXTURE_SEED, layout, {"hp": 21, "max_hp": 24,
		"deck_cards": ["brace"], "relics": [], "hand_size": 1})
	state["enemies"] = (layout["enemies"] as Array).duplicate(true)
	state["current_actor"] = {"kind": "player"}
	# Match the approved numeral sequence, independently of generated RNG.
	var ids: Array = [1, 3, 2, 4]
	var queue: Array[Dictionary]
	for index: int in range(ids.size()):
		queue.append({"kind": "enemy", "enemy_id": ids[index], "time": FIXTURE_QUEUE_TIMES[index], "seq": index + 1})
	state["turn_queue"] = queue
	state["cards_played_this_turn"] = 2
	state["player_turn_time_spent"] = 10
	return state

static func _test_order_and_tiles(expect: Callable) -> void:
	var combat := Combat.new()
	var state: Dictionary = staged_state(combat)
	var original: Dictionary = state.duplicate(true)
	var rest: Dictionary = Badges.build(combat, state, state)
	expect.call((rest["badges"] as Array).size() == 4, "All four visible known intents have at-rest pills")
	var expected: Dictionary = {"enemy_1": "1", "enemy_3": "2", "enemy_2": "3", "enemy_4": "4"}
	var damage: Dictionary = {"enemy_1": "4", "enemy_3": "6", "enemy_2": "5", "enemy_4": "4"}
	for badge: Dictionary in rest["badges"]:
		expect.call(str(badge["order"]) == expected[badge["key"]], "Mockup numeral for %s" % badge["key"])
		expect.call(str(badge["number"]) == damage[badge["key"]], "Mockup damage for %s" % badge["key"])
	var tile_set: Dictionary = Tiles.tile_alphas(rest["threats"])
	var attack_set: Dictionary = {}
	for index: int in range(4):
		var threat: Dictionary = combat.enemy_threat_tiles(state, index)
		for tile: Vector2i in threat.get("projected_attack", []): attack_set[tile] = 1.0
	expect.call(tile_set == attack_set, "Rest tiles equal exact attack footprints, excluding movement range")
	expect.call(state == original, "Rest presentation must not mutate combat, queue, RNG, saves or events")
	var isolated: Dictionary = Badges.build(combat, state, state, "enemy_1")
	for badge: Dictionary in isolated["badges"]:
		expect.call(is_equal_approx(float(badge["alpha"]), 1.0 if badge["key"] == "enemy_1" else 0.4), "Hover/focus isolates pills at 40%")
	for threat: Dictionary in isolated["threats"]:
		expect.call(is_equal_approx(float(threat["alpha"]), 1.0 if threat["key"] == "enemy_1" else 0.4), "Hover/focus isolates tiles at 40%")

static func _test_projection_repeats_and_inactive(expect: Callable) -> void:
	var combat := Combat.new()
	var state: Dictionary = staged_state(combat)
	state["player_turn_time_spent"] = 20
	state["turn_queue"] = [{"kind": "enemy", "enemy_id": 1, "time": 1, "seq": 1},
		{"kind": "enemy", "enemy_id": 2, "time": 5, "seq": 2},
		{"kind": "enemy", "enemy_id": 3, "time": 100, "seq": 3},
		{"kind": "enemy", "enemy_id": 4, "time": 100, "seq": 4}]
	var rest: Dictionary = Badges.build(combat, state, state)
	var order: Dictionary = Badges.enemy_orders(combat, state)
	expect.call("·".join(order.get("enemy_1", PackedStringArray())) == "1·3", "Double-action disc reads 1·3 from the clock's follow-up projection")
	var expected: Dictionary = {}
	var ordinal: int = 0
	for entry: Dictionary in combat.current_turn_order(combat.finish_player_activation(state), 64):
		if str(entry.get("kind", "")) == "player": break
		if str(entry.get("kind", "")) == "enemy":
			ordinal += 1
			var key: String = str(entry["actor_key"])
			expected[key] = str(expected.get(key, "")) + ("·" if expected.has(key) else "") + str(ordinal)
	for badge: Dictionary in rest["badges"]:
		expect.call(str(badge["order"]) == str(expected.get(badge["key"], "")), "Every numeral agrees with uncapped end-now clock projection")
		if badge["key"] in ["enemy_3", "enemy_4"]:
			expect.call(str(badge["order"]).is_empty() and is_equal_approx(float(badge["alpha"]), 0.55), "Non-acting enemy has no disc and 55% plate")
			for threat: Dictionary in rest["threats"]: expect.call(threat["key"] != badge["key"], "Non-acting enemy has no threat tiles")

static func _test_previews_and_privacy(expect: Callable) -> void:
	var combat := Combat.new()
	var state: Dictionary = staged_state(combat)
	var preview: Dictionary = combat.apply_player_action(state, {"type": "push", "range": 3, "amount": 1}, Vector2i(1, 4))
	var rest: Dictionary = Badges.build(combat, state, preview)
	var plan: Dictionary = combat.enemy_threat_tiles(preview, 3)
	for threat: Dictionary in rest["threats"]:
		if threat["key"] == "enemy_4": expect.call(threat["tiles"] == plan["projected_attack"], "Push preview re-aims the at-rest attack footprint")
	for status: String in ["shock", "freeze", "kill", "stagger"]:
		preview = state.duplicate(true)
		var enemy: Dictionary = preview["enemies"][0]
		if status == "kill": enemy["hp"] = 0
		elif status == "stagger":
			for entry: Dictionary in preview["turn_queue"]:
				if int(entry.get("enemy_id", -1)) == 1: entry["time"] = 100
		else: enemy[status] = 1
		rest = Badges.build(combat, state, preview)
		for badge: Dictionary in rest["badges"]:
			if badge["key"] == "enemy_1": expect.call(bool(badge["cancelled"]), "%s preview strikes the announced pill" % status)
		for threat: Dictionary in rest["threats"]: expect.call(threat["key"] != "enemy_1", "%s preview removes cancelled tiles" % status)
	state["umbra"] = {"stage": "heart", "light_sources": []}
	var hidden_id: int = 2
	(state["enemies"][1] as Dictionary)["pos"] = Vector2i(7, 1)
	expect.call(not combat.visible_enemy_ids(state).has(hidden_id), "Privacy fixture includes a truly concealed enemy")
	var view := RunScene.new()
	view.set("_combat_state", state)
	var known: Dictionary = view.call("_surface_preview_information_state", state)
	rest = Badges.build(combat, state, state, "", known)
	for badge: Dictionary in rest["badges"]:
		var id: int = int(str(badge["key"]).trim_prefix("enemy_"))
		expect.call(combat.visible_enemy_ids(state).has(id), "Hidden enemies expose no pill or action order")
	for threat: Dictionary in rest["threats"]:
		var id: int = int(str(threat["key"]).trim_prefix("enemy_"))
		expect.call(combat.visible_enemy_ids(state).has(id), "Hidden enemies expose no threat tiles")
	view.free()

static func _test_callouts(expect: Callable) -> void:
	var combat := Combat.new()
	for reason: String in ["normal", "shock", "freeze", "kill", "moved_target"]:
		var state: Dictionary = staged_state(combat)
		# Adjacent announced melee, then real resolver status/movement effects.
		(state["enemies"][0] as Dictionary)["pos"] = FIXTURE_HERO + Vector2i.RIGHT
		(state["enemies"][0] as Dictionary)["intent"] = {"actions": [{"type": "melee", "damage": 4, "range": 1}]}
		var callouts := Callouts.new()
		callouts.observe(combat, state)
		if reason in ["shock", "freeze"]: (state["enemies"][0] as Dictionary)[reason] = 1
		elif reason == "kill":
			(state["enemies"][0] as Dictionary)["hp"] = 1
			Surface.place(state, FIXTURE_HERO + Vector2i.RIGHT, "fire")
		elif reason == "moved_target": (state["player"] as Dictionary)["pos"] = FIXTURE_HERO + Vector2i.UP * 2
		var announced: Dictionary = (callouts.get("_announced") as Dictionary).duplicate(true)
		for include_commits: bool in [true, false]:
			callouts.set("_announced", announced.duplicate(true))
			var phase: Dictionary = combat.resolve_enemy_turn_with_steps(state, 0, include_commits)
			var annotated: Array[Dictionary] = callouts.decorate_steps(combat, state, phase["steps"])
			var texts: Array[String]
			for step: Dictionary in annotated:
				if str(step.get("kind", "")) == "intent_callout": texts.append(str(step["text"]))
			expect.call(texts.is_empty() if reason == "normal" else texts == ["Cancelled"], "%s (commits=%s) produces exactly the expected resolution callout" % [reason, include_commits])
	# A resolver step hitting a different actor after a push is redirected.
	var state: Dictionary = staged_state(combat)
	var callouts := Callouts.new()
	callouts.observe(combat, state)
	var announcement: Dictionary = (callouts.get("_announced") as Dictionary).get("enemy_2", {})
	(state["enemies"][1] as Dictionary)["pos"] += Vector2i.RIGHT
	var redirected: Array[Dictionary] = Callouts.classify(combat, state, "enemy_2", announcement,
		[{"kind": "ranged", "actor_key": "enemy_2", "target_key": "enemy_4", "target_losses": [{"key": "enemy_4"}]}])
	expect.call(redirected.size() == 1 and redirected[0]["text"] == "Redirected", "Push to a different resolved target produces one Redirected callout")
	var hidden: Array[Dictionary] = Callouts.classify(combat, state, "enemy_2", announcement,
		[{"kind": "ranged", "actor_key": "enemy_2", "hidden_by_umbra": true}])
	expect.call(hidden.is_empty(), "Hidden resolver actions emit no callouts")
	# A real Crosswind moves the source from an illusion to the hero.
	state = staged_state(combat)
	state["illusions"] = [{"id": 1, "pos": Vector2i(1, 3), "hp": 10, "max_hp": 10, "block": 0, "stoneskin": 0}]
	var original_plan: Dictionary = combat.enemy_threat_tiles(state, 3)
	expect.call(original_plan.get("projected_attack_target") == Vector2i(1, 3), "Redirect fixture announces the nearby illusion")
	callouts = Callouts.new()
	callouts.observe(combat, state)
	var push: Dictionary = (GameData.card_def("crosswind").get("actions", []) as Array)[0].duplicate(true)
	push["force_direction"] = Vector2i.RIGHT
	var displaced: Dictionary = combat.apply_player_action(state, push, Vector2i(1, 4))
	expect.call((displaced["enemies"][3] as Dictionary)["pos"] == Vector2i(3, 4), "Production push moves the source closer to the hero")
	var phase: Dictionary = combat.resolve_enemy_turn_with_steps(displaced, 3, false)
	var actual_redirects: int = 0
	for step: Dictionary in callouts.decorate_steps(combat, displaced, phase["steps"]):
		if str(step.get("kind", "")) == "intent_callout" and str(step.get("text", "")) == "Redirected": actual_redirects += 1
	print("THREATS PUSH REDIRECT PROOF: announced=%s after_push=%s callouts=%d" % [original_plan.get("projected_attack_target"), combat.enemy_threat_tiles(displaced, 3).get("projected_attack_target"), actual_redirects])
	expect.call(actual_redirects == 1, "A real pushed enemy resolves on a different target with exactly one Redirected callout")
	for progress: float in [0.0, 0.15, 0.3, 0.5, 0.8, 1.0]:
		var shared: Dictionary = FloatingText.animate_entry({"kind": FloatingText.KIND_EFFECT, "text": "Cancelled", "font_size": 22}, progress, false)
		var normal: Dictionary = Callouts.frame({"text": "Cancelled"}, progress * Callouts.DURATION_SECONDS, false)
		var reduced: Dictionary = Callouts.frame({"text": "Cancelled"}, progress * Callouts.DURATION_SECONDS, true)
		expect.call((normal["motion_offset"] as Vector2).is_equal_approx(shared["motion_offset"]), "Callout motion reuses the status popup curves at %s" % progress)
		expect.call(is_equal_approx(float(normal["alpha"]), float(shared["alpha"])), "Callout fade reuses the status popup curve at %s" % progress)
		expect.call(reduced["motion_offset"] == Vector2.ZERO and is_equal_approx(float(reduced["alpha"]), float(normal["alpha"])), "Reduced callout stays fixed with identical alpha at %s" % progress)

static func _test_style_and_overlap(expect: Callable) -> void:
	expect.call(is_equal_approx(Tiles.hero_fill_alpha(0.0, true), 0.24), "Reduced-motion hero threat is steady 24%")
	expect.call(is_equal_approx(Tiles.hero_fill_alpha(Tiles.PULSE_SECONDS * 0.25, false), 0.30), "Hero pulse reaches 30%")
	expect.call(is_equal_approx(Tiles.hero_fill_alpha(Tiles.PULSE_SECONDS * 0.75, false), 0.18), "Hero pulse reaches 18%")
	var overlapping: Dictionary = Tiles.tile_alphas([{ "tiles": [FIXTURE_HERO], "alpha": 0.4 }, { "tiles": [FIXTURE_HERO], "alpha": 1.0 }])
	expect.call(float(overlapping[FIXTURE_HERO]) == 1.0, "Overlapping threats use max fill, never additive")
	var multi: Dictionary = Badges.descriptor({"type": "melee", "damage": 4, "hits": 2, "bleed": 1})
	expect.call(multi["number"] == "4×2" and multi["secondary_icon"] == "bleed" and multi["secondary_number"] == "1", "Multi-hit and single rider formatting follows the brief")
	var combat := Combat.new()
	var state: Dictionary = staged_state(combat)
	var board := Board.new()
	board.size = Vector2(1920, 1080)
	board.set_combat_state(state)
	var badges: Array = Badges.build(combat, state, state)["badges"]
	# Coincident proof anchors exercise the specified two raised levels.
	var coincident: Dictionary = state.duplicate(true)
	for enemy: Dictionary in coincident["enemies"]:
		enemy["pos"] = FIXTURE_HERO + Vector2i.RIGHT
		enemy["type"] = "crawler"
	board.set_combat_state(coincident)
	var layouts: Array[Dictionary] = Badges.layouts(board, badges.slice(0, 3))
	expect.call(layouts.size() == 3, "Visible enemy pills have measured screen layouts")
	if layouts.size() == 3:
		expect.call(layouts[0]["stack_level"] == 0 and layouts[1]["stack_level"] == 1 and layouts[2]["stack_level"] == 2, "Later pills stack exactly 30px, at most two raised levels")
		for index: int in range(layouts.size()):
			expect.call(not layouts[index].has("overlap_unresolved"), "Layouts no longer expose an unresolved-overlap flag")
			for earlier: int in range(index):
				expect.call(not Badges._envelope(layouts[index]["rect"], str(layouts[index]["order"])).intersects(Badges._envelope(layouts[earlier]["rect"], str(layouts[earlier]["order"]))), "Stacked pill envelopes do not overlap")
	board.free()

static func _test_director_decisions(expect: Callable) -> void:
	var priority: Dictionary = Badges.descriptor({"type": "melee", "damage": 4, "bleed": 1, "shock": 1, "freeze": 1, "immobilize": true, "push": 2})
	expect.call(priority["secondary_icon"] == "push" and priority["secondary_number"] == "2", "Push distance wins over all lower-priority riders")
	var candidates: Array[Dictionary]
	for icon: String in ["stagger", "expose", "bleed", "shock", "chilled", "freeze", "immobilize", "pull", "push"]:
		candidates.append({"icon": icon})
	for icon: String in Badges.SECONDARY_PRIORITY:
		expect.call(Badges.secondary_rider(candidates).get("icon", "") == icon, "%s is the first present secondary" % icon)
		for index: int in range(candidates.size() - 1, -1, -1):
			if candidates[index]["icon"] == icon: candidates.remove_at(index)
	var icon_only: Dictionary = Badges.descriptor({"type": "melee", "damage": 4, "immobilize": true, "bleed": 1})
	expect.call(icon_only["secondary_icon"] == "immobilize" and icon_only["secondary_number"] == "", "Unnumbered secondary is icon-only")
	var font: Font = Typography.ui_font()
	var badge: Dictionary = {"number": "4", "order": "1", "secondary_icon": "push", "secondary_number": "2"}
	var expected_width: float = 12.0 + 20.0 + 4.0 + font.get_string_size("4", HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 7.0 + 16.0 + 3.0 + font.get_string_size("2", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 8.0
	expect.call(is_equal_approx(Badges.plate_width(badge, font), expected_width), "Pill measures 12px ordered left padding, 8px right padding and 4/7/3px gaps")
	badge["order"] = ""
	expect.call(is_equal_approx(Badges.plate_width(badge, font), expected_width - 4.0), "Disc-free pill has 8px padding on each side")
	badge["number"] = ""
	badge["secondary_number"] = ""
	expect.call(is_equal_approx(Badges.plate_width(badge, font), 8.0 + 20.0 + 7.0 + 16.0 + 8.0), "Icon-only content omits both number gaps")
	var occupied: Array[Dictionary]
	occupied.append({"rect": Rect2(100, 100, 80, 26), "order": "1"})
	var right: Rect2 = Badges.resolve_horizontal_overflow(Rect2(100, 100, 80, 26), "2", occupied, Rect2(0, 0, 400, 200))
	expect.call(is_equal_approx(right.position.x, 204.0), "Overflow shifts right by 98px envelope overlap plus 6px")
	expect.call(not Badges._overlaps(right, "2", occupied), "Right overflow solution clears prior pills")
	occupied[0]["rect"] = Rect2(300, 100, 80, 26)
	var left: Rect2 = Badges.resolve_horizontal_overflow(Rect2(300, 100, 80, 26), "2", occupied, Rect2(0, 0, 400, 200))
	expect.call(is_equal_approx(left.position.x, 196.0), "A viewport-clamped right shift instead moves left by overlap plus 6px")
	expect.call(not Badges._overlaps(left, "2", occupied) and Badges._envelope(left, "2").position.x >= 0.0 and left.end.x <= 400.0, "Overflow remains inside the viewport")
	occupied[0]["rect"] = Rect2(222, 100, 80, 26)
	var clamped_clear: Rect2 = Badges.resolve_horizontal_overflow(Rect2(300, 100, 80, 26), "2", occupied, Rect2(0, 0, 400, 200))
	expect.call(clamped_clear.position.x < 300.0 and not Badges._overlaps(clamped_clear, "2", occupied), "Any clamped right shift switches to the left even if its clipped position was clear")
	var combat := Combat.new()
	var state: Dictionary = staged_state(combat)
	for enemy: Dictionary in state["enemies"]:
		enemy["type"] = "crawler"
		enemy["pos"] = FIXTURE_HERO + Vector2i.RIGHT
	var board := Board.new()
	board.size = Vector2(1920, 1080)
	board.set_combat_state(state)
	var layouts: Array[Dictionary] = Badges.layouts(board, Badges.build(combat, state, state)["badges"])
	expect.call(layouts.size() == 4 and int(layouts[3]["stack_level"]) == 2, "A fourth coincident pill is retained at the +60px level")
	for index: int in range(layouts.size()):
		expect.call(not Badges._overlaps(layouts[index]["rect"], str(layouts[index]["order"]), _layouts_before(layouts, index)), "Horizontal overflow clears every earlier envelope")
	var boss: Dictionary = {"key": "enemy_1", "role": "enemy", "type": "tharokh", "pos": Vector2i(5, 1), "boss_bar": true}
	var visual: Rect2 = board.call("_unit_draw_rect", boss)
	board.set("presentation", {"boss_header_global_rect": Rect2(0, 0, 780, visual.position.y + 40.0)})
	var rect: Rect2 = Badges.base_rect(board, boss, 80.0)
	expect.call(is_equal_approx(rect.get_center().x, visual.get_center().x), "Boss pill is centred on its rendered visual bounds")
	expect.call(is_equal_approx(rect.position.y, visual.position.y + 48.0), "Boss pill top clamps 8px below the global header")
	board.set("presentation", {})
	rect = Badges.base_rect(board, boss, 80.0)
	expect.call(is_equal_approx(rect.end.y, visual.position.y - 8.0), "Unclamped boss pill bottom clears rendered bounds by 8px")
	var boss_enemies: Array[Dictionary]
	boss_enemies.append(foe(1, "tharokh", Vector2i(1, -3), str((GameData.enemy_def("tharokh")["intents"][0] as Dictionary)["id"])))
	state["enemies"] = boss_enemies
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"boss_header_global_rect": Rect2(570, 18, 780, 134)})
	layouts = Badges.layouts(board, Badges.build(combat, state, state)["badges"])
	expect.call(layouts.size() == 1, "Global-header bosses keep their visible pill in the actual board layout")
	if not layouts.is_empty(): expect.call((layouts[0]["rect"] as Rect2).position.y >= 160.0, "Boss layout respects the live 152px header bottom plus 8px")
	board.free()

static func _layouts_before(layouts: Array[Dictionary], count: int) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for index: int in range(count): result.append(layouts[index])
	return result

static func _test_stage_plumbing(expect: Callable) -> void:
	var view := RunScene.new()
	var combat := Combat.new()
	var state: Dictionary = staged_state(combat)
	view.set("_combat_state", state)
	view.set("_run_state", {"mode": "combat", "current_room_layout": staged_layout()})
	var source: Dictionary = view.call("_enemy_intent_preview_state", state)
	expect.call(source == state, "Rest and Details share the committed preview source")
	view.set("_selected_card_index", 0)
	var preview: Dictionary = state.duplicate(true)
	(preview["player"] as Dictionary)["pos"] += Vector2i.UP
	view.set("_preview_combat_state", preview)
	view.set("_pending_actions", [])
	view.set("_hovered_board_tile", Vector2i(-1, -1))
	source = view.call("_enemy_intent_preview_state", state)
	expect.call((source["player"] as Dictionary)["pos"] == (preview["player"] as Dictionary)["pos"], "Later-action preview source stays coupled to Pass and detailed intents")
	view.free()
