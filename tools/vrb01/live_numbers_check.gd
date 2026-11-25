extends SceneTree

const Cards = preload("res://scripts/game_data.gd")
const Display = preload("res://scripts/card_display_overrides.gd")
const WidgetScene = preload("res://scenes/card_widget.tscn")
const Combat = preload("res://scripts/combat_engine.gd")
const Tempo = preload("res://scripts/tempo_rules.gd")
const PoolFixture = preload("res://tests/suites/card_pool_overhaul_suite.gd")
const WIDGET_SIZE := Vector2(250, 352)
const RUSH_DESTINATION := Vector2i(2, 3)
const COMBAT_ENEMY := {"id": 1, "type": "crawler", "pos": Vector2i(6, 4), "hp": 40, "max_hp": 40}

# Paths into the live action array, in the face's reading order.
const FIELDS: Dictionary = {
	"spike_mantle": [[0, "damage"], [0, "surface_bonus", "damage"], [1, "rewards", 0, "amount"]],
	"capacitor": [[0, "amount"], [1, "chain"]],
	"charged_orb": [[0, "amount"], [1, "chain"]],
	"headlong": [[0, "range"], [1, "per_tile_moved", "damage"], [1, "per_tile_moved", "max"]],
	"shadow_gate": [[0, "range"], [1, "damage"]],
	"sworn_oath": [[0, "amount"], [1, "damage"]],
	"whetstone": [[0, "damage"]],
	"galvanize": [[0, "amount"], [1, "amount"]],
	"hourglass_sand": [[0, "amount"], [1, "amount"]],
	"spur_spark": [[0, "range"], [1, "amount"]],
	"static_rush": [[0, "range"], [1, "amount"]],
	"stolen_moment": [[0, "amount"], [1, "amount"]],
}
const FIXTURE_FIELD_DELTA: int = 1
var _checks: int
var _failures: int

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var widget: CardWidget = WidgetScene.instantiate()
	widget.size = WIDGET_SIZE
	root.add_child(widget)
	var engine := Combat.new()
	var upgradeable: Array = Cards.upgradeable_card_ids()
	for id: String in FIELDS:
		var state: Dictionary = PoolFixture._queued_state(engine, [id], [COMBAT_ENEMY])
		var card: Dictionary = engine.card_def(id, state)
		var base: Array = _face_numbers(widget, id, card, state)
		_expect(base == _action_numbers(id, card), id + " base projection")
		var upgraded: Array = []
		for element: Dictionary in Cards.upgradeable_elements_for_card(id, state) if id in upgradeable else []:
			for option: Dictionary in Cards.upgrade_options_for_element(id, element, state):
				var preview: Dictionary = Cards.preview_card_with_mod(id, option, state)
				var numbers: Array = _face_numbers(widget, id, preview, state)
				if element["kind"] == "stat":
					_expect(numbers == _action_numbers(id, preview), id + " " + str(option.get("label", option)))
					if numbers != base and not upgraded.has(numbers): upgraded.append(numbers)
				elif element["kind"] in ["action", "pattern"]:
					_expect(numbers.is_empty(), id + " uses rows for the changed action or area")
		var modified: Dictionary = card.duplicate(true)
		for path: Array in FIELDS[id]:
			var holder: Variant = modified["actions"]
			for key: Variant in path.slice(0, -1): holder = holder[key]
			holder[path.back()] += FIXTURE_FIELD_DELTA
		var changed: Array = _face_numbers(widget, id, modified, state)
		_expect(changed == _action_numbers(id, modified), id + " each printed number binds after a numeric-only preview change")
		print("LIVE %s base=%s upgrades=%s numeric_preview=%s" % [id, base, upgraded, changed])
		if id in ["capacitor", "sworn_oath"]:
			state["relics"] = ["briar_throne"]
			var relic_card: Dictionary = engine.card_def(id, state)
			var relic_numbers: Array = _face_numbers(widget, id, relic_card, state)
			_expect(relic_numbers == _action_numbers(id, relic_card) and relic_numbers.front() == 0, id + " Briar Throne suppresses live Block")
			print("RELIC %s briar_throne=%s" % [id, relic_numbers])
		if not Cards.card_is_item(id):
			state["relics"] = ["crown_of_surplus"]
			var empowered: Dictionary = engine.card_def(id, state)
			_expect(empowered.has("empower") and _face_numbers(widget, id, empowered, state).is_empty(), id + " Crown of Surplus reveals Empower and its bonus in rows")
			var active: Dictionary = engine.prepare_player_card(state, 0, "empower")
			var modifiers: Dictionary = preload("res://scripts/card_keyword_rules.gd").play_modifiers(active, id, empowered)
			_expect(bool(modifiers.get("empowered", false)) and _face_numbers(widget, id, empowered, active).is_empty(), id + " keeps the active Empower preview in rows")
			print("EMPOWER %s crown_of_surplus=rows active=%s" % [id, modifiers.get("empowered", false)])
	_check_time_badge(widget, engine)
	print("VRB01 LIVE CHECKS: %d checks, %d failures" % [_checks, _failures])
	print("TEST RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)

func _face_numbers(widget: CardWidget, id: String, card: Dictionary, state: Dictionary) -> Array:
	widget.set_display_overrides()
	widget.configure(id, false, false, true, false, false, true, card)
	Display.apply_projection(widget, card, Display.for_card(id, state, card))
	var numbers: Array = []
	for line: Dictionary in widget.sentence_face_plan().get("lines", []):
		for piece: Dictionary in line["pieces"]:
			if piece["kind"] == "number": numbers.append(int(piece["text"]))
	return numbers

func _action_numbers(id: String, card: Dictionary) -> Array:
	var numbers: Array = []
	for path: Array in FIELDS[id]:
		var value: Variant = card["actions"]
		for key: Variant in path: value = value[key]
		numbers.append(int(value))
	return numbers

func _check_time_badge(widget: CardWidget, engine: CombatEngine) -> void:
	var before: Dictionary = PoolFixture._queued_state(engine, ["static_rush", "brace"], [COMBAT_ENEMY])
	var after: Dictionary = PoolFixture._play_first(engine, before, [RUSH_DESTINATION])
	var card: Dictionary = engine.card_def("brace", after)
	widget.set_display_overrides()
	widget.configure("brace", false, false, true, false, false, true, card)
	Display.apply_projection(widget, card, Display.for_card("brace", after, card))
	var badge: Control = widget.get_node("TimeCostBadge")
	var pending: int = Tempo.quicken_pending(after)
	var shown: int = badge.get("value")
	var cost: int = engine.card_time_cost("brace", after)
	var committed: Dictionary = PoolFixture._play_first(engine, after, [])
	var paid: int = int(committed["player_turn_time_spent"]) - int(after["player_turn_time_spent"])
	_expect(pending == 2 and badge.visible and shown == 1 and shown == cost and shown == paid, "Static Rush -> Brace displays and pays the 1 Time floor")
	_expect(not badge.tooltip_text.contains("less Time"), "Brace has zero realized discount")
	_expect(Tempo.player_badges(after)[0]["tooltip"] == "Your next card this turn costs 2 less Time.", "Static Rush shows the pending discount on the hero chip")
	_expect((after["log"] as Array).has("Your next card this turn costs 2 less Time."), "Static Rush logs the pending discount")
	print("TIME FLOOR Static Rush -> Brace pending=%d badge=%d calculated=%d paid=%d" % [pending, shown, cost, paid])

func _expect(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)
