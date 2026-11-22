extends RefCounted
## Exercise the real prepare, target validation, action resolver, and finish calls.

const Fx = preload("res://tools/qa122/fixture.gd")
const Data = Fx.Data
const Icons = preload("res://scripts/action_icon_library.gd")
const Keywords = preload("res://scripts/card_keyword_rules.gd")
const Display = preload("res://scripts/card_display_overrides.gd")
const Inline = preload("res://scripts/inline_icon_text.gd")
const Surface = Fx.Surface
const Paths = preload("res://scripts/path_utils.gd")
const CardArea = preload("res://scripts/card_area_presentation.gd")
const FarFoe := Vector2i(8, 5)
const OtherFoes: Array = [Vector2i(5, 4), Vector2i(6, 5), Vector2i(5, 6), Vector2i(7, 5)]
const SetupBlock: int = 12
const SetupFrost: int = 1
const PaintDepth: int = 3

static func catalog(engine: RefCounted, filter: String) -> Array:
	var output: Array = []
	for id: String in Data.cards():
		if not filter.is_empty() and id != filter: continue
		var base: Dictionary = Data.card_def(id)
		if bool((Data.cards()[id] as Dictionary).get("retired", false)) or not base.has("name"): continue
		var mods: Array = [[]]
		for option_element: Dictionary in Data.upgradeable_elements_for_card(id, {}):
			for option: Dictionary in Data.upgrade_options_for_element(id, option_element, {}):
				mods.append([option])
		for modification: Array in mods:
			var profiles: Array = ["neutral", "primed", "far"] if modification.is_empty() else ["neutral", "primed"]
			for profile: String in profiles:
				for mode: String in ["play", "empower"] if Keywords.has_empower(base) else ["play"]:
					output.append(play(engine, id, modification, profile, mode))
	return output

static func _prepare_board(engine: RefCounted, state: Dictionary, actions: Array, profile: String) -> void:
	var primary: Dictionary = state["enemies"][0]
	if profile == "primed":
		state["player"]["block"] = SetupBlock
		state["player"]["stoneskin"] = SetupBlock
		state["turn_flags"]["cards_finished"] = 1
		state["deck"]["discard"] = ["quick_stab"]
		primary["freeze"] = SetupFrost
		primary["bleed"] = SetupFrost
		primary["chilled"] = true
		for pos: Vector2i in OtherFoes:
			state["enemies"].append(Fx.enemy(pos, state["enemies"].size() + 1))
	for action: Dictionary in actions:
		var kind: String = str(action.get("type", ""))
		var condition: Dictionary = action.get("surface_condition", {})
		var ground: String = str(condition.get("surface", ""))
		var consumption: Dictionary = action.get("consume", {})
		if bool(consumption.get("required", false)): ground = str(consumption.get("surface", ground))
		if bool(action.get("destination_requires_light", false)):
			engine._create_umbra_light_source(state, Fx.Hero + Vector2i.UP, {"radius": 2, "duration": PaintDepth})
		match kind:
			"detonate": ground = str(action.get("detonate_surface", "fire"))
			"consume_surface", "convert_surface": ground = str(action.get("surface", "ice"))
			"discharge": ground = "electrified"
			"all_enemies":
				var selector: String = str(action.get("selector", ""))
				if profile == "primed":
					match selector:
						"on_fire", "on_electrified": ground = selector.trim_prefix("on_")
						"chilled": primary["freeze"] = 0
						"in_light": engine._create_umbra_light_source(state, primary["pos"], {"radius": 1, "duration": PaintDepth})
			"force_area": ground = str(action.get("consume_center", ground))
			"burst_terrain":
				state["terrain"] = [{"id": 1, "kind": "crag_outcrop", "owner_kind": "player",
					"pos": Fx.Hero + Vector2i.UP, "hp": 3, "max_hp": 3}]
				primary["pos"] = Fx.Hero + Vector2i.UP * 2
			"illusion_swap", "destroy_illusion":
				state["illusions"] = [{"id": 40, "type": "illusion", "pos": Fx.Hero + Vector2i.UP,
					"hp": 3, "max_hp": 3, "block": 0, "stoneskin": 0}]
		if not ground.is_empty():
			if kind in ["detonate", "consume_surface", "convert_surface", "discharge", "force_area"] or bool(consumption.get("required", false)) or profile == "primed":
				Surface.place(state, primary["pos"], ground)
				Surface.place(state, primary["pos"] + Vector2i.RIGHT, ground)

static func _target(state: Dictionary, action: Dictionary, legal: Array, previous: Vector2i, profile: String, next: Dictionary) -> Vector2i:
	if legal.is_empty(): return Fx.Invalid
	if (str(action.get("target", "")) == "previous_target" or bool(action.get("reuse_previous_target", false))) and legal.has(previous):
		return previous
	var foe: Vector2i = state["enemies"][0]["pos"]
	if str(action.get("type", "")) in ["move", "blink"]:
		var chosen: Vector2i = legal[0]
		var origin: Vector2i = state["player"]["pos"]
		for pos: Vector2i in legal:
			if _movement_score(pos, origin, foe, next) > _movement_score(chosen, origin, foe, next): chosen = pos
		return chosen
	if foe in legal: return foe
	if profile == "primed":
		for actor: Dictionary in state["enemies"]:
			if actor["pos"] in legal: return actor["pos"]
	return legal[0]

static func _movement_score(pos: Vector2i, origin: Vector2i, foe: Vector2i, next: Dictionary) -> int:
	var travel: int = Paths.manhattan(pos, origin)
	if str(next.get("type", "")) not in ["melee", "ranged", "push", "pull"]: return travel
	var distance: int = Paths.manhattan(pos, foe)
	var reach: int = int(next.get("range", 1))
	return travel - Fx.BoardSize * absi(distance - clampi(distance, 1, reach))

static func token_rows(rows: Array) -> Array:
	var result: Array = []
	for row: Array in rows:
		var items: Array = []
		for token: Dictionary in row:
			var shown: Dictionary = {"icon": token.get("icon", ""), "kind": token.get("kind", ""),
				"value": Icons.token_value_text(token), "tooltip": Icons.token_tooltip(token, true)}
			for field: String in ["pattern", "keyword_segment", "text"]:
				if token.has(field): shown[field] = token[field]
			items.append(shown)
		result.append(items)
	return result

static func play(engine: RefCounted, id: String, mods: Array, profile: String, mode: String,
		relic: String = "", overrides: Dictionary = {}) -> Dictionary:
	var config: Dictionary = {}
	if not relic.is_empty(): config["relics"] = [relic]
	var state: Dictionary = Fx.state(engine, FarFoe if profile == "far" else Fx.Foe, "crawler", config)
	if not mods.is_empty(): state["qa122_card_mods"] = {id: mods}
	var card: Dictionary = engine.card_def(id, state)
	state["deck"]["hand"] = [id]
	state["deck"]["draw"] = ["quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab"]
	_prepare_board(engine, state, card.get("actions", []), profile)
	state.merge(overrides, true)
	if not overrides.is_empty(): card = engine.card_def(id, state)
	var before: Dictionary = Fx.receipt(state)
	var working: Dictionary = engine.prepare_player_card(state, 0, mode)
	var display: Dictionary = Display.for_card(id, working, card)
	var rows: Array = display["summary_rows"]
	var actions: Array = engine.card_play_actions(id, working)
	var previous: Vector2i = Fx.Invalid
	var steps: Array = []
	var complete: bool = true
	for index: int in range(actions.size()):
		var action: Dictionary = actions[index]
		var next: Dictionary = actions[index + 1] if index + 1 < actions.size() else {}
		var needed: bool = engine.player_action_needs_target(action)
		if engine.player_action_needs_orientation(action): action["orientation"] = Vector2i.RIGHT
		var legal: Array = engine.valid_targets_for_player_action(working, action) if needed else []
		var target: Vector2i = _target(working, action, legal, previous, profile, next)
		var eligible: bool = engine.player_action_can_resolve(working, action) and (not needed or target != Fx.Invalid)
		var prior: Dictionary = Fx.receipt(working)
		var hits: Array = []
		var events: Array = []
		if eligible:
			var outcome: Dictionary = engine.resolve_player_action_for_presentation(working, action, target)
			events = engine._surface_events_since(working, outcome["state"])
			working = outcome["state"]
			for hit: Dictionary in outcome["chain_hits"]:
				hits.append({"target": hit.get("target_tile", hit.get("tile", Fx.Invalid)), "kind": hit.get("kind", "")})
		else:
			complete = false
		steps.append({"type": action.get("type", ""), "tokens": token_rows([CardArea.tokens(Icons.tokens_for_action(action), action, actions, true)])[0],
			"target": Fx.tile(target), "legal": Fx.tiles(legal), "eligible": eligible, "hero_pos": prior["hero"]["pos"], "roster": prior["enemies"],
			"delta": Fx.delta(prior, Fx.receipt(working)), "hits": hits, "events": events})
		if target != Fx.Invalid: previous = target
	var pre_finish: Dictionary = Fx.receipt(working)
	if complete:
		working = engine.finish_player_card(working, 0, engine.card_plays_spent_for_actions(actions), {"play_mode": mode})
	return {"id": id, "mods": mods, "profile": profile, "mode": mode, "name": card.get("name", ""),
		"face": Icons.plain_text_for_rows(rows, true), "tokens": token_rows(rows),
		"tooltips": Icons.tooltip_entries_for_rows(rows).map(func(tip: Dictionary) -> String: return str(tip["tooltip"])),
		"time": str(int(card.get("time", 0)) + int(display.get("time_surcharge", 0))), "before": before, "steps": steps, "complete": complete,
		"finish": Fx.delta(pre_finish, Fx.receipt(working)),
		"item_text": Inline.plain_text(Display.rules_text(id, card, rows)) if Data.card_is_item(id) else ""}
