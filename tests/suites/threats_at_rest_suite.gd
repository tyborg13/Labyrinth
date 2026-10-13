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
const FIXTURE_BOX_OFFSET := Vector2i(1, -2)
const FIXTURE_BOX_HP: int = 10
const PLACEMENT_TEST_ANCHOR := Vector2(600, 500)
const PLACEMENT_TEST_HEALTH := Rect2(100, 100, 140, 20)
const ZONE_PREVIEW_OFFSET := Vector2i.UP
const WAVE_E2_ROSTER: Array = [
	{"type": "briar_weaver", "offset": Vector2i.RIGHT, "intent": "thornwall", "icon": "bramble"},
	{"type": "slag_mortar", "offset": Vector2i(-3, 0), "intent": "lob_slag", "icon": "lob"},
	{"type": "glacial_mirror", "offset": Vector2i(0, -3), "intent": "refraction", "icon": "aoe"},
	{"type": "gust_shrike", "offset": Vector2i(3, 0), "intent": "dive", "icon": "dive"},
]

static func run(expect: Callable) -> void:
	expect.call(Badges.Icons.token_value_text({"icon": "chilled", "value": true}).is_empty(), "flag riders render no number (was \"true\" on the glacial mirror chip)")
	_test_order_and_tiles(expect)
	_test_projection_repeats_and_inactive(expect)
	_test_previews_and_privacy(expect)
	_test_callouts(expect)
	_test_style_and_overlap(expect)
	_test_chip_content(expect)
	_test_danger(expect)
	_test_zone_tags(expect)
	_test_stage_plumbing(expect)
	_test_wave_e2(expect)

static func wave_e2_state(combat: RefCounted) -> Dictionary:
	var state: Dictionary = staged_state(combat)
	var enemies: Array[Dictionary]
	for index: int in range(WAVE_E2_ROSTER.size()):
		var entry: Dictionary = WAVE_E2_ROSTER[index]
		enemies.append(foe(index + 1, entry["type"], entry["offset"], entry["intent"]))
	state["enemies"] = enemies
	return state

static func _test_wave_e2(expect: Callable) -> void:
	var combat := Combat.new()
	var state: Dictionary = wave_e2_state(combat)
	var original: Dictionary = state.duplicate(true)
	var rest: Dictionary = Badges.build(combat, state, state)
	var board := Board.new()
	board.size = Vector2(1920, 1080)
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"threats_at_rest": rest})
	var layouts: Array[Dictionary] = Badges.layouts(board, rest["badges"])
	var tags: Array[Dictionary] = Tiles.zone_tags(rest["threats"])
	expect.call(layouts.size() == 4 and tags.size() == 4, "All four wave E2 intents have feet chips and area zone tags")
	for index: int in range(WAVE_E2_ROSTER.size()):
		var key: String = "enemy_%d" % (index + 1)
		var entry: Dictionary = WAVE_E2_ROSTER[index]
		var badge: Dictionary = _badge(rest, key)
		expect.call(badge.get("icon") == entry["icon"], "%s at-rest chip uses its own %s icon" % [entry["type"], entry["icon"]])
		expect.call(not str(badge.get("order", "")).is_empty() and layouts.any(func(layout: Dictionary) -> bool: return layout["key"] == key and (layout["order_rect"] as Rect2).has_area()), "%s has an order disc at its actual health frame" % entry["type"])
		expect.call(tags.any(func(tag: Dictionary) -> bool: return tag["key"] == key and tag["tile"] in combat.enemy_threat_tiles(state, index)["projected_attack"]), "%s has a zone tag on its exact footprint" % entry["type"])
		expect.call(not str(badge.get("number", "")).contains(".") and not str(badge.get("secondary_number", "")).contains("."), "%s chip displays only integer numbers" % entry["type"])
	var presentation: Dictionary = board.presentation
	expect.call(presentation.get("enemy_threat_previews", []).is_empty(), "Wave E2 rest leaves detailed popups and compass disclosure off")
	expect.call(presentation.get("en05_dive_telegraphs", []).size() == 1 and presentation.get("displacement_paths", []).has(combat._vector2i_values([Vector2i(5, 4), Vector2i(5, 3)])), "Wave E2 Dive retains its dashed line and right-hand side-push preview through v2")
	expect.call(state == original, "Wave E2 threat presentation leaves combat, queue and events unchanged")
	board.free()

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
	expect.call((rest["badges"] as Array).size() == 4, "All four visible known intents have at-rest chips")
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
		expect.call(is_equal_approx(float(badge["alpha"]), 1.0 if badge["key"] == "enemy_1" else 0.4), "Hover/focus isolates chips at 40%")
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
			if badge["key"] == "enemy_1": expect.call(bool(badge["cancelled"]), "%s preview strikes the announced chip" % status)
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
		expect.call(combat.visible_enemy_ids(state).has(id), "Hidden enemies expose no chip or action order")
	for threat: Dictionary in rest["threats"]:
		var id: int = int(str(threat["key"]).trim_prefix("enemy_"))
		expect.call(combat.visible_enemy_ids(state).has(id), "Hidden enemies expose no threat tiles")
	for tag: Dictionary in Tiles.zone_tags(rest["threats"]):
		expect.call(tag["key"] != "enemy_2", "Hidden enemies expose no zone tags")
	var moved: Dictionary = known.duplicate(true)
	(moved["player"] as Dictionary)["pos"] += Vector2i.UP
	var movement: Dictionary = Badges.movement_preview(combat, state, moved)
	expect.call((movement["enemies"] as Array).size() == (state["enemies"] as Array).size(), "Known movement preview retains concealed actors for unchanged clock accounting")
	rest = Badges.build(combat, state, movement, "", view.call("_surface_preview_information_state", movement))
	for badge: Dictionary in rest["badges"]:
		expect.call(badge["key"] != "enemy_2", "Known movement preview cannot reveal a concealed intent")
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
	expect.call(is_equal_approx(Tiles.hero_fill_alpha(Tiles.PULSE_SECONDS * 0.25, false), 0.30), "Hero tile pulse reaches 30%")
	expect.call(is_equal_approx(Tiles.hero_fill_alpha(Tiles.PULSE_SECONDS * 0.75, false), 0.18), "Hero tile pulse reaches 18%")
	var overlapping: Dictionary = Tiles.tile_alphas([{ "tiles": [FIXTURE_HERO], "alpha": 0.4 }, { "tiles": [FIXTURE_HERO], "alpha": 1.0 }])
	expect.call(float(overlapping[FIXTURE_HERO]) == 1.0, "Overlapping threats use max fill, never additive")
	var font: Font = Typography.ui_font()
	var badge: Dictionary = Badges.descriptor({"type": "melee", "damage": 4})
	var anchor: Vector2 = PLACEMENT_TEST_ANCHOR
	var placed: Dictionary = Badges.place_chip(anchor, badge, font, [], [])
	var default_rect: Rect2 = placed["rect"]
	expect.call(placed["center"] == anchor + Vector2(26, 4) and placed["placement"] == "lower_right", "Default medallion is 26px right and 4px below feet")
	for blocker: String in ["unit", "prop", "chip"]:
		var obstacles: Array[Rect2]
		var previous: Array[Dictionary]
		if blocker == "chip": previous.append({"rect": default_rect})
		else: obstacles.append(default_rect)
		placed = Badges.place_chip(anchor, badge, font, obstacles, previous)
		expect.call(placed["placement"] == "lower_left" and not bool(placed["above_everything"]), "%s overlap flips chip to lower left" % blocker)
		expect.call(is_equal_approx((placed["rect"] as Rect2).end.x, anchor.x - 26.0) and is_equal_approx((placed["center"] as Vector2).y, anchor.y + 4.0), "Mirrored chip keeps its orientation and exact feet offset")
	var left_rect: Rect2 = placed["rect"]
	var blocked: Array[Rect2]
	blocked.append(default_rect)
	blocked.append(left_rect)
	placed = Badges.place_chip(anchor, badge, font, blocked, [])
	expect.call(placed["rect"] == default_rect and bool(placed["above_everything"]), "Both blocked retains lower-right chip above everything")
	var health: Rect2 = PLACEMENT_TEST_HEALTH
	var disc: Rect2 = Badges.order_rect(health, "1", font)
	expect.call(disc.size == Vector2(24, 24) and disc.get_center() == Vector2(86, 110), "24px order disc centres 14px left of health frame")
	var capsule: Rect2 = Badges.order_rect(health, "1·3", font)
	expect.call(capsule.size.x > 24 and capsule.size.y == 24 and capsule.get_center() == disc.get_center(), "1·3 extends the disc as a same-style capsule")
	expect.call(not Badges.order_rect(health, "", font).has_area(), "Non-acting enemy has no order disc")
	var combat := Combat.new()
	var state: Dictionary = crowded_state(combat)
	var board := Board.new()
	board.size = Vector2(1920, 1080)
	board.set_combat_state(state)
	var layouts: Array[Dictionary] = Badges.layouts(board, Badges.build(combat, state, state)["badges"])
	expect.call(layouts.size() == 4, "Crowded layout retains every chip at its feet")
	for layout: Dictionary in layouts:
		var unit: Dictionary = {}
		for candidate: Dictionary in board.call("_visible_units"):
			if candidate["key"] == layout["key"]: unit = candidate
		var feet: Vector2 = board.call("_unit_center", unit)
		expect.call(is_equal_approx((layout["center"] as Vector2).y, feet.y + 4.0), "Crowded chip never docks at the health bar")
		expect.call((layout["order_rect"] as Rect2).get_center() == Vector2(Badges.health_rect(board, unit).position.x - 14.0, Badges.health_rect(board, unit).get_center().y), "Disc follows collision-resolved health frame")
	var boss: Dictionary = {"key": "enemy_1", "role": "enemy", "boss_bar": true}
	board.set("presentation", {"boss_health_frame_global_rect": Rect2(570, 28, 780, 90)})
	expect.call(Badges.health_rect(board, boss) == Rect2(570, 28, 780, 90), "Boss disc uses its real global health frame")
	board.free()

static func _test_chip_content(expect: Callable) -> void:
	var multi: Dictionary = Badges.descriptor({"type": "melee", "damage": 4, "hits": 2, "bleed": 1})
	expect.call(multi["number"] == "4×2" and multi["secondary_icon"] == "bleed" and multi["secondary_number"] == "1", "Multi-hit and single rider formatting follows the brief")
	for action: Dictionary in [{"type": "melee", "damage": 4}, {"type": "ranged", "damage": 5}, {"type": "aoe", "damage": 6}, {"type": "block", "amount": 3}, {"type": "heal_self", "amount": 2}, {"type": "summon_minions", "count": 2}, {"type": "move_away", "range": 3}]:
		var chip: Dictionary = Badges.descriptor(action)
		expect.call(chip["icon"] == Badges.Icons.action_icon_key(action), "%s uses its existing primary action icon" % action["type"])
		expect.call(chip["number"] == str(action.get("damage", action.get("amount", action.get("count", "")))), "%s retains its primary number" % action["type"])
		var family: String = str(chip["family"])
		expect.call(Badges.ring_color(chip) == (Badges.Palette.GOLD_DIM if family in ["defense", "support", "movement"] else Badges.Palette.GOLD), "%s uses its approved normal ring" % action["type"])
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
	var chip: Dictionary = {"number": "4", "secondary_icon": "push", "secondary_number": "2"}
	var end: float = 24.0 + font.get_string_size("4", HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 6.0 + 16.0 + font.get_string_size("2", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 12.0
	expect.call(is_equal_approx(Badges.plate_end(chip, font), end), "Plate content uses approved font sizes, 6px rider gap and 12px end padding")
	chip["number"] = ""
	expect.call(Badges.plate_end(chip, font) == 0.0 and Badges.chip_rect(Vector2.ZERO, chip, font).size == Vector2(32, 32), "Numberless intent has only its 32px medallion")
	expect.call(is_equal_approx(Badges.halo_alpha(0, false), 0.35) and is_equal_approx(Badges.halo_alpha(0.55, false), 0.75) and is_equal_approx(Badges.halo_alpha(1.1, false), 0.35), "Danger halo follows 35% to 75% to 35% over 1.1s")
	expect.call(is_equal_approx(Badges.halo_alpha(0, true), 0.55) and is_equal_approx(Badges.halo_alpha(0.55, true), 0.55), "Reduced motion is steady 55%")
	var halo: Dictionary = Badges.halo_texture(end)
	var image: Image = (halo["texture"] as Texture2D).get_image()
	var center: Vector2i = Vector2i(-(halo["offset"] as Vector2))
	expect.call(image.get_pixel(center.x, center.y).a > image.get_pixel(center.x - 25, center.y).a and image.get_pixel(center.x - 25, center.y).a > 0.0, "Gaussian halo has a soft nonzero tail outside the medallion")
	expect.call(Badges.halo_texture(end)["texture"] == halo["texture"], "Repeated halo drawing reuses its cached Gaussian mask")
	expect.call(not Badges.details_discloses_compass({}, "enemy_1"), "Ground compass is absent at rest")
	expect.call(Badges.details_discloses_compass({"show_all_enemy_intents": true}, "enemy_1"), "Details retains the ground compass")
	expect.call(Badges.details_discloses_compass({"expanded_enemy_actor_keys": ["enemy_1"]}, "enemy_1") and not Badges.details_discloses_compass({"expanded_enemy_actor_keys": ["enemy_1"]}, "enemy_2"), "Focus retains only its disclosed compass")

static func _test_danger(expect: Callable) -> void:
	var combat := Combat.new()
	for kind: String in ["melee", "ranged", "aoe"]:
		var state: Dictionary = staged_state(combat)
		var enemy: Dictionary = state["enemies"][0]
		enemy["pos"] = FIXTURE_HERO + Vector2i.RIGHT
		enemy["intent"] = {"actions": [{"type": kind, "damage": 4, "range": 3 if kind == "ranged" else 1}]}
		var badge: Dictionary = _badge(Badges.build(combat, state, state), "enemy_1")
		expect.call(bool(badge["danger"]), "%s hitting the hero's tile is danger" % kind)
		expect.call(Badges.ring_color(badge) == Badges.Palette.DANGER, "Danger ring/rims/finial use DANGER")
		var preview: Dictionary = state.duplicate(true)
		(preview["player"] as Dictionary)["pos"] = Vector2i(1, 1)
		badge = _badge(Badges.build(combat, state, preview), "enemy_1")
		expect.call(not bool(badge["danger"]), "%s preview moving hero out removes danger" % kind)
	var state: Dictionary = staged_state(combat)
	state["illusions"] = [{"id": 1, "pos": Vector2i(1, 3), "hp": 10, "max_hp": 10, "block": 0, "stoneskin": 0}]
	var badge: Dictionary = _badge(Badges.build(combat, state, state), "enemy_4")
	expect.call(not bool(badge["danger"]), "Attack aimed at an illusion is not danger to hero")
	var rest: Dictionary = Badges.build(combat, state, state)
	expect.call(Badges.needs_pulse({"threats_at_rest": rest}), "Danger chip requests retained HUD redraw")
	expect.call(not Badges.needs_pulse({"threats_at_rest": rest, "reduced_motion": true}), "Reduced motion does not animate chip halo")

static func _test_zone_tags(expect: Callable) -> void:
	var combat := Combat.new()
	var state: Dictionary = staged_state(combat)
	var rest: Dictionary = Badges.build(combat, state, state)
	var tags: Array[Dictionary] = Tiles.zone_tags(rest["threats"])
	expect.call(tags.size() == 1 and tags[0]["key"] == "enemy_3" and tags[0]["order"] == "2", "Only area attacker gets a zone tag with its order numeral")
	for threat: Dictionary in rest["threats"]:
		if not bool(threat["area"]): continue
		var source: Vector2i = threat["attacker_tile"]
		var nearest: Vector2i = tags[0]["tile"]
		var distance: int = absi(nearest.x - source.x) + absi(nearest.y - source.y)
		for tile: Vector2i in threat["tiles"]:
			expect.call(distance <= absi(tile.x - source.x) + absi(tile.y - source.y), "Tag tile is nearest its attacker")
	expect.call(Badges.is_area_intent({"actions": [{"type": "ranged", "pattern": [[0, 0]]}]}), "Pattern attacks qualify for a zone tag")
	var isolated: Array[Dictionary] = Tiles.zone_tags(Badges.build(combat, state, state, "enemy_1")["threats"])
	expect.call(is_equal_approx(float(isolated[0]["alpha"]), 0.4), "Other zone tags dim to 40% under isolation")
	var preview: Dictionary = state.duplicate(true)
	(preview["enemies"][2] as Dictionary)["pos"] += ZONE_PREVIEW_OFFSET
	var after: Dictionary = Badges.build(combat, state, preview)
	var after_tags: Array[Dictionary] = Tiles.zone_tags(after["threats"])
	expect.call(after_tags.size() == 1, "Re-aim fixture retains a real area zone tag")
	if not after_tags.is_empty(): expect.call(after_tags[0]["tile"] != tags[0]["tile"], "Displacing an area source re-aims its zone tag")
	for tag: Dictionary in after_tags:
		expect.call(tag["tile"] in combat.enemy_threat_tiles(preview, 2)["projected_attack"], "Preview zone tag stays on re-aimed area")

static func _badge(rest: Dictionary, key: String) -> Dictionary:
	for badge: Dictionary in rest["badges"]:
		if badge["key"] == key: return badge
	return {}

static func crowded_state(combat: RefCounted) -> Dictionary:
	var state: Dictionary = staged_state(combat)
	(state["enemies"][3] as Dictionary)["pos"] = FIXTURE_HERO + Vector2i(3, 1)
	state["terrain"] = [{"id": "proof_box", "kind": "wooden_box", "pos": FIXTURE_HERO + FIXTURE_BOX_OFFSET, "hp": FIXTURE_BOX_HP, "max_hp": FIXTURE_BOX_HP}]
	return state

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
