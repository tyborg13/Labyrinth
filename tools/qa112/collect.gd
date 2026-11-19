extends SceneTree
## Read-only copy probe. Emits text from production controls and formatters.
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Data = preload("res://scripts/game_data.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Inline = preload("res://scripts/inline_icon_text.gd")
const Patterns = preload("res://scripts/pattern_text.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Runs = preload("res://scripts/run_engine.gd")
const Rooms = preload("res://scripts/room_generator.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const ObjectiveHud = preload("res://scripts/combat_objective_hud.gd")
const IntentBadges = preload("res://scripts/intent_badges.gd")
const Boons = preload("res://scripts/opening_boon_rules.gd")
const EventFixtures = preload("res://tests/suites/event_view_suite.gd")
const Events = preload("res://scripts/event_rules.gd")
const EventView = preload("res://scripts/event_view.gd")
const SectionMap = preload("res://scripts/section_map_panel.gd")
const Specials = preload("res://scripts/special_encounter_library.gd")
const Elements = preload("res://scripts/element_data.gd")
const EVENT_VIEWPORT := Vector2i(1920, 1080)
const SEEDS: Array = [321, 73491, 101451]
const BOSS_DEPTH: int = 20

var _rows: Array[Dictionary] = preload("res://scripts/typed_arrays.gd").dictionaries([])
var _events: int = 0
var _event_results: int = 0

func _initialize() -> void:
	Runtime.apply_from_environment()
	call_deferred("_run")

func _add(surface: String, location: String, value: String, kind: String = "formatted") -> void:
	if value.is_empty():
		return
	_rows.append({"surface": surface, "location": location, "text": value, "kind": kind})

func _run() -> void:
	var hud := ObjectiveHud.new()
	root.add_child(hud)
	var runs := Runs.new()
	for seed: int in SEEDS:
		var run: Dictionary = runs.create_new_run(seed, Progression.default_data())
		_boons(run, seed)
		var found: bool = false
		for destination: Vector2i in runs.available_moves(run):
			var entered: Dictionary = runs.move_to_room(run.duplicate(true), destination)
			if str(entered.get("mode", "")) != "combat":
				continue
			found = _objective(hud, entered["combat_state"], "first combat, seed %d" % seed)
			break
		if not found:
			hud.free()
			push_error("QA112: missing live objective for seed %d" % seed)
			quit(1)
			return
	var boss_run: Dictionary = runs.create_new_run(SEEDS[-1], Progression.default_data())
	var room: Dictionary = {"type": "boss", "boss_id": "zekarion", "element": "lightning",
		"depth": BOSS_DEPTH, "coord": Vector2i(BOSS_DEPTH, 0), "connections": []}
	var layout: Dictionary = Rooms.new().generate_room(SEEDS[-1], room, Vector2i.RIGHT)
	var boss_combat: Dictionary = Combat.new().create_combat(SEEDS[-1], layout,
		{"hp": boss_run["player_hp"], "max_hp": boss_run["player_max_hp"], "deck_cards": boss_run["deck_cards"]})
	if not _objective(hud, boss_combat, "Zekarion arena, seed %d" % SEEDS[-1]):
		hud.free()
		push_error("QA112: missing live Zekarion objective")
		quit(1)
		return
	_catalog()
	_map()
	await _event_pages(runs, boss_run)
	hud.free()
	print("QA112 EVENT PAGES: %d choice pages, %d result pages" % [_events, _event_results])
	print("QA112_JSON:" + JSON.stringify(_rows))
	print("QA112 COPY EXPORT: %d records, %d seeded combats, 1 Zekarion fixture" % [_rows.size(), SEEDS.size()])
	quit()

func _boons(run: Dictionary, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for id: String in Boons.definitions()["boons"]:
		var rolled: Dictionary = Boons.roll(id, run, rng)
		if not rolled.is_empty():
			_add("opening boons", "boon %s, seed %d" % [id, seed], Inline.plain_text(Boons.text(rolled)))

func _objective(hud: Control, state: Dictionary, location: String) -> bool:
	hud.call("set_combat_state", state)
	if not hud.visible:
		return false
	for node_name: String in ["ObjectiveTitle", "ObjectiveLiveDetail"]:
		var label: Label = hud.find_child(node_name, true, false) as Label
		if label == null or label.text.is_empty():
			return false
		_add("combat objectives", "%s / %s" % [location, node_name], label.text, "observed")
	_add("combat objectives", location + " / objective hover", hud.tooltip_text, "observed")
	return true

func _catalog() -> void:
	for id: String in Icons.all_icon_keys():
		_add("glossary and shared tooltips", "action icon " + id, Icons.tooltip(id))
	for id: String in Data.cards():
		var card: Dictionary = Data.card_def(id)
		if str(card.get("name", "")).is_empty():
			continue
		var rows: Array = Icons.rows_for_card(card)
		rows.append_array(Icons.keyword_rows_for_card(card))
		rows.append_array(Icons.cost_rows_for_card(card))
		rows.append_array(Icons.rules_text_rows_for_card(card))
		for row_index: int in rows.size():
			for token: Dictionary in rows[row_index]:
				var location: String = "card %s / row %d / %s" % [id, row_index + 1, token.get("icon", "text")]
				_add("card panel", location, str(token.get("text", "")))
				_add("card panel", location, Icons.token_value_text(token))
		var tips: Array = Icons.tooltip_entries_for_rows(rows)
		for index: int in tips.size():
			_add("card panel", "card %s / tooltip %d" % [id, index + 1], str(tips[index]["tooltip"]))
		if Icons.card_is_rite(card):
			_add("card panel", "card %s / Rite face" % id, Icons.rite_face_rules_text(card))
	for id: String in Data.relic_ids():
		var relic: Dictionary = Data.relic_def(id)
		_add("relics and items", "owned relic %s / description" % id,
			Inline.plain_text(Patterns.display_rules(str(relic.get("description", "")))))
	for entry: Dictionary in Grimoire.entries():
		for index: int in (entry["body"] as Array).size():
			_add("Grimoire", "entry %s / paragraph %d" % [entry["id"], index + 1],
				Inline.plain_text(Patterns.display_rules(str(entry["body"][index]))))
	for id: String in Data.enemies():
		var enemy: Dictionary = Data.enemy_def(id)
		for intent: Dictionary in enemy.get("intents", []):
			var location: String = "enemy %s / intent %s" % [id, intent.get("id", intent.get("name", ""))]
			_add("enemy intents and traits", location, str(intent.get("name", "")))
			for action: Dictionary in intent.get("actions", []):
				# The authored Lob mark has no damage until the live preview pairs it
				# with the landing action. It is not a format-ready catalog input.
				if str(action.get("type", "")) == "lob_mark" and not action.has("center_damage"):
					continue
				var descriptor: Dictionary = IntentBadges.descriptor(action, intent)
				_add("enemy intents and traits", location, str(descriptor.get("number", "")))
				for token: Dictionary in Icons.tokens_for_action(action):
					_add("enemy intents and traits", location, Icons.token_tooltip(token))

func _map() -> void:
	var map := SectionMap.new()
	for key: String in preload("res://scripts/room_icon_library.gd").all_icon_ids():
		var node: Dictionary = {"type": key, "revealed": true}
		if key.begins_with("guardian_"):
			node = {"type": "guardian", "guardian_id": key.trim_prefix("guardian_"), "revealed": true}
		elif key.begins_with("boss_"):
			node = {"type": "boss", "boss_id": key.trim_prefix("boss_"), "revealed": true}
		elif key.begins_with("special_"):
			var special_type: String = key.trim_prefix("special_")
			node = {"type": "special", "special_type": special_type, "revealed": true}
			var variants: Dictionary = Specials.definition(special_type).get("variants", {})
			if not variants.is_empty():
				for variant: String in variants:
					node["special_variant"] = variant
					_add("map node", "room icon %s / %s" % [key, variant], map.call("_room_label", node))
				continue
		var label: String = Elements.name(key) if Elements.is_elemental(key) else map.call("_room_label", node)
		_add("map node", "room icon " + key, label)
	map.free()

func _event_pages(runs: RefCounted, base: Dictionary) -> void:
	var viewport := SubViewport.new()
	viewport.size = EVENT_VIEWPORT
	root.add_child(viewport)
	var view := EventView.new()
	viewport.add_child(view)
	for rich: bool in [false, true]:
		for id: String in Data.events():
			var state: Dictionary = EventFixtures.fixture(id, rich, base)
			if str((state["event_state"] as Dictionary).get("event_id", "")) != id:
				push_error("QA112: Event fixture did not enter " + id)
				continue
			var location: String = "%s, %s, seed %d" % [id, "equipped/funded" if rich else "starter", int(base["seed"])]
			_read_event(view, state, location + " / choices", "event choice")
			_events += 1
			for choice: Dictionary in Data.event_def(id)["choices"]:
				var choice_id: String = str(choice["id"])
				if not Events.choice_available(state, id, choice_id):
					continue
				var result: Dictionary = runs.resolve_map_event(state, choice_id)
				_read_event(view, result, location + " / result " + choice_id, "event body")
				_event_results += 1
	viewport.queue_free()
	await process_frame

func _read_event(view: Control, state: Dictionary, location: String, surface: String) -> void:
	view.call("present", state, true)
	view.call("finish_animation_for_test")
	_read_controls(view, view, location, surface)

func _read_controls(node: Node, owner_view: Node, location: String, surface: String) -> void:
	if node is Control and not (node as Control).is_visible_in_tree():
		return
	if node is Label or node is RichTextLabel or node is Button:
		var value: String = str(node.get("text"))
		# Event view builds RichTextLabels with add_text/append_text. Their
		# .text property remains empty even after the reveal completes.
		if node is RichTextLabel and value.is_empty():
			value = (node as RichTextLabel).get_parsed_text()
		_add(surface, "%s / %s" % [location, owner_view.get_path_to(node)], value, "observed")
	for child: Node in node.get_children():
		_read_controls(child, owner_view, location, surface)
