extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Display = preload("res://scripts/card_display_overrides.gd")
const State = preload("res://scripts/card_display_state.gd")
const Keywords = preload("res://scripts/card_keyword_rules.gd")
const Fixture = preload("res://tests/helpers/card_display_fixture.gd")
const Audit = preload("res://tests/helpers/card_legibility_audit.gd")
const Shop = preload("res://scripts/scavenger_shop_view.gd")
const CardScene = preload("res://scenes/card_widget.tscn")
const FULL_HEALTH: int = 24
const INJURED_HEALTH: int = 12
const EMPOWER_CARD: String = "shatterline"
const CONDITIONAL_CASES: Array = [
	{"kind": "first_attack_bonus", "card": "quick_stab", "effect": {"value": 1}, "on": {}, "off": {"turn_flags": {"first_attack_bonus_used": true}}},
	{"kind": "glass_attack_bonus", "card": "quick_stab", "effect": {"value": 1}, "on": {}, "off": {"player_block": 1}},
	{"kind": "bloodied_glass_attack_bonus", "card": "quick_stab", "effect": {"value": 1}, "on": {"player_hp": 12}, "off": {"player_hp": 24}},
	{"kind": "bloodied_attack_bonus", "card": "quick_stab", "effect": {"value": 1}, "on": {"player_hp": 12}, "off": {"player_hp": 24}},
	{"kind": "room_element_attack_bonus", "card": "frostbolt", "effect": {"value": 1}, "on": {"room_element": "ice"}, "off": {"room_element": "fire"}},
	{"kind": "moved_tiles_card_attack_bonus", "card": "gust_step", "effect": {"requires_any_action_types": ["move"], "amount": 1, "max": 3}, "on": {"turn_flags": {"tiles_moved": 2}}, "off": {"turn_flags": {}}},
	{"kind": "first_card_attack_bonus", "card": "gust_step", "effect": {"value": 1}, "on": {}, "off": {"used_first_card": true}},
	{"kind": "player_state_action_mod", "card": "quick_stab", "effect": {"player_min_block": 1, "action_types": ["melee"], "field": "damage", "amount": 1}, "on": {"player_statuses": {"block": 1}}, "off": {"player_statuses": {"block": 0}}}
]

static func run(tree: SceneTree, host: Node, expect: Callable) -> void:
	await _production_health(tree, expect)
	_bound_room_transition(tree, expect)
	_conditional_kinds(expect)
	await _pile_reopen(tree, host, expect)
	await _empower_time(tree, host, expect)
	await cache_lifecycle(tree, expect)
	preload("res://tests/helpers/card_display_cache_regressions.gd").run(tree, expect)

static func _production_health(tree: SceneTree, expect: Callable) -> void:
	var engine := preload("res://scripts/run_engine.gd").new()
	var shop := Shop.new()
	tree.root.add_child(shop)
	var face: Control
	for fixture: Array in [[24, 24, 6], [12, 24, 13], [24, 48, 13], [48, 48, 6]]:
		var health: int = fixture[0]
		var max_health: int = fixture[1]
		var run: Dictionary = Fixture.bloodglass_shop(engine, health, max_health)
		expect.call(not run.has("player"), "Production health fixture uses run health, not an injected combat player")
		if face == null:
			shop.configure(run, engine, true)
			shop.call("_select_item", "training_sword", false, shop.find_child("GearOffer_training_sword", true, false))
			face = Audit.find_card(shop.get("_detail_card_host"))
		else:
			Display.refresh(shop, run)
		expect.call(face != null and face.card_id == "quick_stab", "Production shop inspects Training Sword's Quick Stab")
		if face == null: continue
		expect.call(first_damage(face.display_summary_rows()) == fixture[2], "Bound production shop Bloodglass reads %d/%d HP honestly" % [health, max_health])
		print("CARD02 HEALTH SHOP hp=%d/%d Quick Stab=%d" % [health, max_health, first_damage(face.display_summary_rows())])
	shop.free()

static func _bound_room_transition(tree: SceneTree, expect: Callable) -> void:
	var engine := preload("res://scripts/run_engine.gd").new()
	var run: Dictionary = engine.create_new_run(Fixture.FIXTURE_SEED, Fixture.profile())
	var destination := Vector2i.ZERO
	var found: bool = false
	# Use an existing generated connection into a different elemental room.
	# Only map knowledge is revealed for this fixture; no board/edge is invented.
	for room: Dictionary in run["rooms"].values():
		for connection: Dictionary in room.get("connections", []):
			var coord: Vector2i = connection["coord"]
			var target: Dictionary = run["rooms"].get("%d,%d" % [coord.x, coord.y], {})
			if str(target.get("element", "none")) != "ice" or str(room.get("element", "none")) == "ice": continue
			run["current_room"] = room["coord"]
			run["mode"] = "room"
			target["revealed"] = true
			if not engine.available_moves(run).has(coord): continue
			destination = coord
			found = true
			break
		if found: break
	expect.call(found, "Generated map supplies a legal transition to a different elemental room")
	if not found: return
	const RELIC: String = "card02_bound_room"
	Data.relics()[RELIC] = {"effects": [{"type": "room_element_attack_bonus", "value": 1}]}
	run["relics"] = [RELIC]
	var host := Control.new()
	tree.root.add_child(host)
	var face: Control = CardScene.instantiate()
	face.configure("frostbolt")
	host.add_child(face)
	Display.bind(face, run)
	var before: Array = face.display_summary_rows()
	var moved: Dictionary = engine.move_to_room(run, destination)
	expect.call(moved["current_room"] == destination and not moved.has("room_element"), "Production transition changes the current room without injecting room_element")
	Display.refresh(host, moved)
	# Independent combat-shape oracle derives the destination from RunEngine.
	var oracle: Dictionary = moved.duplicate(true)
	oracle["room_element"] = engine.room_metadata(moved, destination)["element"]
	oracle["player"] = {"hp": moved["player_hp"], "max_hp": moved["player_max_hp"]}
	var expected: Array = Display.for_card("frostbolt", oracle)["summary_rows"]
	expect.call(face.display_summary_rows() == expected and expected != before, "Bound card refresh follows the real room-element transition")
	expect.call(first_damage(expected) == first_damage(before) + 1, "Matching room adds the authored bonus to the retained face")
	print("CARD02 BOUND ROOM TRANSITION: %s -> %s Frostbolt=%d -> %d" % [run["current_room"], destination, first_damage(before), first_damage(face.display_summary_rows())])
	host.free()
	Data.relics().erase(RELIC)

static func _conditional_kinds(expect: Callable) -> void:
	var engine := preload("res://scripts/run_engine.gd").new()
	var host := preload("res://scripts/run_scene.gd").new()
	for index: int in range(CONDITIONAL_CASES.size()):
		var row: Dictionary = CONDITIONAL_CASES[index]
		var relic: String = "card02_condition_" + str(index)
		var effect: Dictionary = row["effect"].duplicate(true)
		effect["type"] = row["kind"]
		Data.relics()[relic] = {"name": relic, "effects": [effect]}
		var damages: Array = []
		for active: bool in [true, false]:
			var run: Dictionary = Fixture.shop(engine)
			run["relics"] = [relic]
			run["player_hp"] = FULL_HEALTH
			run["player_max_hp"] = FULL_HEALTH
			var patch: Dictionary = row["on"] if active else row["off"]
			run.merge(patch, true)
			if run.has("used_first_card"): run["turn_flags"] = {relic + "::first_card_attack_bonus": true}
			# Independent combat-shape oracle: never use the normaliser under test.
			var combat: Dictionary = run.duplicate(true)
			combat["player"] = {"hp": run["player_hp"], "max_hp": run["player_max_hp"]}
			(combat["player"] as Dictionary).merge(run.get("player_statuses", {}), true)
			for field: String in ["block", "stoneskin", "bleed", "expose", "freeze", "shock", "immobilize", "chilled", "petrify"]:
				if run.has("player_" + field): combat["player"][field] = run["player_" + field]
			var actual: Dictionary = Display.for_card(row["card"], run)
			var hand: Dictionary = host.call("_card_widget_display", row["card"], combat)
			expect.call(actual == hand, "%s active=%s uses the canonical hand state" % [row["kind"], active])
			damages.append(first_damage(actual["summary_rows"]))
		expect.call(damages[0] > damages[1], "Conditional fixture exercises both sides: " + str(row["kind"]))
		Data.relics().erase(relic)
	host.free()
	print("CARD02 CONDITIONAL BONUS KINDS: %d active/inactive pairs" % CONDITIONAL_CASES.size())

static func _pile_reopen(tree: SceneTree, host: Node, expect: Callable) -> void:
	host.call("_close_card_upgrade_overlay")
	var run: Dictionary = Fixture.combat(preload("res://scripts/run_engine.gd").new())
	host.call("_load_run_state", run)
	host.call("_close_dialogue")
	host.set("_animation_lock", false)
	var combat: Dictionary = host.get("_combat_state")
	# Pile contents are test-only; the board and combat come from the real run.
	combat["deck"]["draw"] = ["nail_bomb"]
	combat["relics"].append("bloodglass_knife")
	combat["player"]["hp"] = INJURED_HEALTH
	combat["player"]["max_hp"] = FULL_HEALTH
	host.call("_open_pile_view", "draw")
	var face: Control = _visible_pile_card(host)
	expect.call(face != null, "Real pile opens a visible card")
	if face == null: return
	var instance: int = face.get_instance_id()
	var before: Array = face.display_summary_rows()
	host.call("_close_pile_view")
	combat["relics"] = []
	# No general UI refresh: reopening itself must bind the current source.
	host.call("_open_pile_view", "draw")
	var reopened: Control = _visible_pile_card(host)
	expect.call(reopened != null and reopened.get_instance_id() == instance, "Pile reopens the existing pooled face")
	if reopened != null:
		expect.call(reopened.display_summary_rows() == Display.for_card("nail_bomb", combat)["summary_rows"] and reopened.display_summary_rows() != before, "Pile reopening recomputes rows after hidden relic changes")
	host.call("_close_pile_view")
	await tree.process_frame

static func _visible_pile_card(host: Node) -> Control:
	for entry: Dictionary in host.get("_pile_dialog_card_pool"):
		if entry["button"].is_visible_in_tree(): return entry["widget"]
	return null

static func _empower_time(tree: SceneTree, host: Node, expect: Callable) -> void:
	var combat: Dictionary = host.get("_combat_state").duplicate(true)
	combat["relics"] = []
	var definition: Dictionary = Data.card_def_for_progression(EMPOWER_CARD, combat)
	Keywords.stamp_card_start(combat, EMPOWER_CARD, definition, true)
	var widget: Control = CardScene.instantiate()
	widget.configure(EMPOWER_CARD)
	tree.root.add_child(widget)
	Display.bind(widget, combat)
	var surcharge: int = int(definition["empower"]["cost"]["time"])
	var badge: Control = widget.get("_time_badge")
	expect.call(int(Display.for_card(EMPOWER_CARD, combat).get("time_surcharge", 0)) == surcharge, "Empower projection returns its authored Time surcharge")
	expect.call(badge.value == int(definition["time"]) + surcharge and badge.tooltip_text.contains("Empower: +%d" % surcharge), "Empower displayed Time and tooltip include the surcharge")
	combat.erase(Keywords.PLAY_MODIFIERS_KEY)
	Display.bind(widget, combat)
	expect.call(badge.value == int(definition["time"]) and not badge.tooltip_text.contains("Empower:"), "Clearing Empower restores the card's displayed Time")
	widget.free()

static func first_damage(rows: Array) -> int:
	for row: Array in rows:
		for token: Dictionary in row:
			if str(token.get("field", "")) == "damage": return int(token.get("value", 0))
	return 0

static func cache_lifecycle(tree: SceneTree, expect: Callable) -> void:
	var bindings = preload("res://scripts/card_display_bindings.gd")
	bindings.reset_cache()
	var host := Control.new()
	host.hide()
	tree.root.add_child(host)
	var run: Dictionary = Fixture.shop(preload("res://scripts/run_engine.gd").new())
	var widgets: Array[Control]
	for index: int in range(60):
		var widget: Control = CardScene.instantiate()
		widget.configure("nail_bomb")
		host.add_child(widget)
		Display.bind(widget, run)
		widgets.append(widget)
	expect.call(bindings.calculations == 0, "Binding hidden faces does not project their text")
	run["relics"] = []
	Display.refresh(host, run)
	expect.call(bindings.calculations == 0, "Hidden relic invalidation stays lazy")
	host.show()
	expect.call(bindings.calculations == 1, "Sixty duplicate faces share one projection on reveal")
	for widget: Control in widgets:
		expect.call(widget.display_summary_rows() == Display.for_card("nail_bomb", run)["summary_rows"], "A revealed face uses the most recent hidden state")
	var before: int = bindings.calculations
	run["notice"] = "unrelated UI fixture"
	run["held_embers"] = 1
	Display.refresh(host, run)
	expect.call(bindings.calculations == before, "Currency and notices never invalidate rules text")
	var signature: int = State.signature(run)
	for patch: Dictionary in [{"player_hp": INJURED_HEALTH}, {"player_block": 1}, {"player_stoneskin": 1}, {"equipped_equipment": {}}, {"equipment_grafts": {"training_sword": {"index": 0, "card_id": "quick_stab"}}}, {"relics": ["bloodglass_knife"]}, {"card_mods": {"quick_stab": []}}, {"card_upgrades": {"quick_stab": "fixture"}}]:
		var changed: Dictionary = run.duplicate(true)
		changed.merge(patch, true)
		expect.call(State.signature(changed) != signature, "Relevant card source invalidates: " + str(patch.keys()[0]))
	var options: Array = Data.upgrade_options_for_element("quick_stab", Data.upgradeable_elements_for_card("quick_stab", {})[0], {})
	var option: Dictionary = options[0]
	var calls: Dictionary = {"count": 0}
	before = bindings.calculations
	for index: int in range(2):
		var upgraded: Control = CardScene.instantiate()
		upgraded.configure("quick_stab")
		host.add_child(upgraded)
		Display.bind(upgraded, run, func(state: Dictionary) -> Dictionary:
			calls["count"] += 1
			return Data.preview_card_with_mod("quick_stab", option, state)
		, option)
	expect.call(calls["count"] == 1 and bindings.calculations == before + 1, "The same upgrade option resolves and projects once across faces")
	host.free()
