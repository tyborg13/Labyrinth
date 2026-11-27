extends RefCounted

# Intent and board comparisons adapted from txt-39 enemy_witnesses.gd.
const F = preload("res://tools/txt42/fixture.gd")
const Guardian = preload("res://scripts/guardian_combat_rules.gd")
const Capacitor = preload("res://scripts/enemy_mechanics/capacitor.gd")
const Rise = preload("res://scripts/battlefield_rules/upheaval_rise.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Glossary = preload("res://scripts/glossary.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const KnownMoves = preload("res://scripts/known_move_text.gd")
const ECLIPSE_SINGULAR: String = "This enemy starts Eclipse for your next turn, then hits you and your Illusions on Marked tiles."
const ECLIPSE_PLURAL: String = "This enemy starts Eclipse for your next %d turns, then hits you and your Illusions on Marked tiles."
const ECLIPSE_SUMMARY: String = "Marked: Ranged 8 · Eclipse 1, then Summon Veilbound Acolyte"
const ECLIPSE_TEST_COUNTERS: Array = [1, 2, 3, 4]

const NEAR := Vector2i(4, 4)
const DRAGON := Vector2i(6, 5)
const DIRECTIONS: Array = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const CARD_MARK_START := Vector2i(3, 4)
const CARD_MARK_ALLY := Vector2i(4, 4)
const CARD_MARK_ENEMY := Vector2i(5, 4)
const EMPTY_CINDER_MARK := Vector2i(3, 3)
const TRAP_DAMAGE: int = 4


static func cinder_card_display(f: F) -> void:
	var generic: String = Glossary.definition("cinder_marks")
	var contextual: Array[String]
	var offenders: Array[String]
	var catalog: Dictionary = {}
	for id: String in F.Data.cards():
		catalog[id] = F.Data.card_def(id)
	for id: String in F.Data.card_upgrade_ids():
		catalog[id] = F.Data.upgraded_card_def(id)
	for id: String in catalog:
		var card: Dictionary = catalog[id]
		for entry: Dictionary in Icons.tooltip_entries_for_rows(Icons.rows_for_card(card)):
			if entry.get("glossary_key") != "cinder_marks":
				continue
			var description: String = entry["description"]
			contextual.append("%s: %s" % [id, description])
			if description == generic or description.is_empty():
				offenders.append(id)
	f.observe("cinder_card_display", offenders.is_empty() and not contextual.is_empty(),
		"Cards with the Cinder Marks icon use contextual copy %s. Generic entry shown by %s" % [contextual, offenders])


static func cinder_marks(f: F) -> void:
	var ally := Vector2i(4, 5)
	var state: Dictionary = f.fight([f.unit(DRAGON, 0, "vyraketh"), f.unit(NEAR, 1)])
	state = f.engine._create_illusion(state, ally, F.HEALTH)
	var intent: Dictionary = F.Base.intent("vyraketh", "kindle_ground")
	var action: Dictionary = intent["actions"][0].duplicate(true)
	action["declared_tiles"] = [F.PLAYER, NEAR, ally, EMPTY_CINDER_MARK]
	state["damage_context"] = {"actor_kind": "enemy", "actor_id": 0, "source_kind": "direct_attack"}
	var after: Dictionary = f.engine._enemy_create_cinder_marks(state.duplicate(true), 0, action)
	var losses: Array = [_hero_loss(state, after), _illusion_loss(state, after), _enemy_loss(state, after, 1)]
	var fire: Array[Vector2i] = F.Ground.tiles(after, "fire")
	var damage: int = action["damage"]
	f.observe("cinder_marks", losses == [damage, damage, 0] and fire.size() == 4
		and F.PLAYER in fire and NEAR in fire and ally in fire and EMPTY_CINDER_MARK in fire,
		"Vyraketh damage to hero / Illusion / enemy=%s, Fire=%s" % [losses, fire])


static func meteorfall(f: F) -> void:
	var state: Dictionary = f.fight([f.unit(CARD_MARK_ENEMY), f.unit(DRAGON, 1)])
	var action: Dictionary = f.action(state, "meteorfall")
	# Mark from a legal tile, then put the occupants onto the held marks.
	state["player"]["pos"] = CARD_MARK_START + Vector2i.UP
	var marked: Dictionary = f.engine.apply_player_action(state, action, CARD_MARK_ALLY)
	marked["player"]["pos"] = CARD_MARK_START
	marked = f.engine._create_illusion(marked, CARD_MARK_ALLY, F.HEALTH)
	var landed: Dictionary = f.engine.prepare_next_player_turn(marked)
	var loss: Array = [_hero_loss(marked, landed), _illusion_loss(marked, landed),
		_enemy_loss(marked, landed, 0), _enemy_loss(marked, landed, 1)]
	var fire: Array[Vector2i] = F.Ground.tiles(landed, "fire")
	f.observe("meteorfall_body_1", _enemy_loss(state, marked, 0) == 0 and F.Ground.tiles(marked, "fire").is_empty()
		and loss[0] > 0 and loss[1] > 0 and loss[2] > 0 and loss[3] == 0
		and CARD_MARK_START in fire and CARD_MARK_ALLY in fire and CARD_MARK_ENEMY in fire,
		"Next turn damage to marked hero / Illusion / enemy and unmarked enemy=%s, Fire=%s" % [loss, fire])


static func charge(f: F) -> void:
	var state: Dictionary = f.fight([f.unit(F.ENEMY, 0, "storm_capacitor")])
	state["enemies"][0]["charge"] = 2
	var charged: Dictionary = _enemy_turn(f, state, "charge")
	var ready: int = charged["enemies"][0]["charge"]
	var intent: Dictionary = Capacitor.choose(charged["enemies"][0], F.Data.enemy_def("storm_capacitor")["intents"])
	var fired: Dictionary = _enemy_turn(f, charged.duplicate(true), intent["id"])
	var shock: Dictionary = {"type": "ranged", "damage": 0, "range": 3, "shock": 1}
	var shocked: Dictionary = f.engine.apply_player_action(charged, shock, F.ENEMY)
	var repeated: Dictionary = f.engine.apply_player_action(shocked, shock, F.ENEMY)
	var first: int = shocked["enemies"][0]["charge"]
	var second: int = repeated["enemies"][0]["charge"]
	f.observe("charge", ready == 3 and intent["name"] == "Arc Lash" and _hero_loss(charged, fired) > 0 and first == 2 and second == 2,
		"Charge reached %d, selected %s, first and repeated Shock left %d / %d Charge" % [ready, intent["name"], first, second])


static func upheaval(f: F) -> void:
	var state: Dictionary = f.fight([f.unit(Vector2i(6, 4), 0, "craghide")])
	var instance: Dictionary = Rules.instance_for("craghide", 0)
	var sites: Array[Vector2i] = F.Typed.vector2i([F.PLAYER, NEAR])
	var rose: Dictionary = Rise.attempt(f.engine, state.duplicate(true), instance, sites)["state"]
	var blocked: Dictionary = state.duplicate(true)
	for direction: Vector2i in DIRECTIONS:
		var wall: Vector2i = F.PLAYER + direction
		if wall != NEAR:
			blocked["grid"][wall.y][wall.x] = "wall"
	blocked["traps"] = [{"pos": NEAR, "element": "fire", "damage": TRAP_DAMAGE}]
	# A unit on the trap blocks the last displacement square as well.
	blocked["enemies"].append(f.unit(NEAR, 1))
	var stayed: Dictionary = Rise.attempt(f.engine, blocked, instance, sites)["state"]
	var trap_only: Dictionary = state.duplicate(true)
	trap_only["traps"] = blocked["traps"]
	var blocked_trap: Dictionary = Rise.attempt(f.engine, trap_only, instance, sites)["state"]
	var cut: Dictionary = f.engine._damage_terrain(rose.duplicate(true), 0, F.HEALTH)
	var outcrop: Vector2i = rose["terrain"][0]["pos"]
	var walk: Dictionary = {"type": "move", "range": 1}
	var route: bool = (outcrop not in f.engine.valid_targets_for_player_action(rose, walk)
		and outcrop in f.engine.valid_targets_for_player_action(cut, walk))
	f.observe("upheaval", rose["terrain"].size() == 2 and stayed["terrain"].is_empty()
		and stayed["player"]["pos"] == F.PLAYER and blocked_trap["terrain"].size() == 1
		and blocked_trap["terrain"][0]["pos"] != NEAR and route,
		"Outcrops on open marks=%d, with blocked unit and trapped mark=%d, with trap only=%s. Destroying one opens tile=%s" %
		[rose["terrain"].size(), stayed["terrain"].size(), blocked_trap["terrain"], route])


static func last_eclipse(f: F) -> void:
	var state: Dictionary = f.fight([f.unit(DRAGON, 0, "noctyrax")])
	state = f.engine._create_illusion(state, NEAR, F.HEALTH)
	var initial: String = f.engine.effective_umbra_stage(state)
	_commit(f, state, "last_eclipse")
	var dark: Dictionary = _enemy_turn(f, state)
	var next: Dictionary = f.engine.prepare_next_player_turn(dark)
	var second: Dictionary = f.engine.prepare_next_player_turn(next)
	var stages: Array = [f.engine.effective_umbra_stage(dark), f.engine.effective_umbra_stage(next),
		f.engine.effective_umbra_stage(second)]
	var at_hit: Dictionary = f.engine.stages_at_hit
	var ordered: bool = at_hit.get("player", []) == ["eclipse"] and at_hit.get("illusion", []) == ["eclipse"]
	f.observe("last_eclipse_order", ordered and _hero_loss(state, dark) > 0 and _illusion_loss(state, dark) > 0,
		"Before the move=%s, stages at marked hero and Illusion damage=%s, Health lost=%s" %
		[initial, at_hit, [_hero_loss(state, dark), _illusion_loss(state, dark)]])
	f.observe("last_eclipse_duration", initial == "clear" and stages == ["eclipse", "eclipse", "clear"],
		"On cast / at first player turn / at second player turn=%s, counters=%s" %
		[stages, [dark["umbra"]["boss_eclipse_activations"], next["umbra"]["boss_eclipse_activations"],
		second["umbra"]["boss_eclipse_activations"]]])


static func eclipse_copy(f: F) -> void:
	var consumers: Array[String]
	var summaries: Array[String]
	var lines: Array[String]
	for id: String in F.Data.enemies():
		var intents: Array = F.Data.enemy_def(id).get("intents", [])
		for raw: Dictionary in intents:
			for action: Dictionary in raw.get("actions", []):
				if action.get("type") != "umbra_eclipse": continue
				consumers.append(id + "/" + raw["id"])
				lines.append(Icons.token_tooltip(_eclipse_token([Icons.tokens_for_action(action)])))
				var intent: Dictionary = KnownMoves.base_intent(raw, intents)
				var rows: Array = KnownMoves.rows(intent, {"type": id}, {}, true)
				lines.append(Icons.token_tooltip(_eclipse_token(rows)))
				summaries.append(KnownMoves.summary(intent, rows))
	f.observe("last_eclipse_consumers", consumers == ["noctyrax/last_eclipse"]
		and lines == [ECLIPSE_SINGULAR, ECLIPSE_SINGULAR] and summaries == [ECLIPSE_SUMMARY],
		"Authored actions=%s, live intent and Known Move token=%s, shared Grimoire/bestiary summary=%s" % [consumers, lines, summaries])

	var state: Dictionary = f.fight([f.unit(DRAGON, 0, "noctyrax")])
	for counter: int in ECLIPSE_TEST_COUNTERS:
		var action: Dictionary = {"type": "umbra_eclipse", "duration": counter, "damage": 0}
		var cast: Dictionary = f.engine._enemy_umbra_eclipse(state.duplicate(true), 0, action)
		var on_cast: String = f.engine.effective_umbra_stage(cast)
		var turns: int = 0
		for activation: int in range(counter):
			cast = f.engine.prepare_next_player_turn(cast)
			if f.engine.effective_umbra_stage(cast) == "eclipse":
				turns += 1
		var expected: String = Icons.label("eclipse")
		if turns == 1: expected = ECLIPSE_SINGULAR
		if turns > 1: expected = ECLIPSE_PLURAL % turns
		var token: Dictionary = _eclipse_token([Icons.tokens_for_action(action)])
		var tooltip: String = Icons.token_tooltip(token)
		f.observe("last_eclipse_counter_%d" % counter, on_cast == "eclipse" and turns == counter - 1
			and int(token.get("value", 0)) == turns and tooltip == expected,
			"Cast counter=%d, upcoming turns in Eclipse=%d, tooltip=%s" % [counter, turns, tooltip])


static func _eclipse_token(rows: Array) -> Dictionary:
	for row: Array in rows:
		for token: Dictionary in row:
			if token.get("icon") == "eclipse": return token
	return {}


static func hollow_gale(f: F) -> void:
	var ally := Vector2i(5, 3)
	var enemy := Vector2i(4, 5)
	var outside := F.PLAYER + Vector2i.LEFT
	var state: Dictionary = f.fight([f.unit(F.ENEMY, 0, "vaeloryx"), f.unit(enemy, 1)])
	state = f.engine._create_illusion(state, ally, F.HEALTH)
	state["battlefield_rule"] = {} # Isolate the move from the separately announced Gust.
	var beyond: Dictionary = state.duplicate(true)
	beyond["player"]["pos"] = outside
	_commit(f, state, "hollow_gale")
	var held: Array = state["enemies"][0]["intent"]["actions"][0]["declared_tiles"]
	var destination: Vector2i = ally + Vector2i.UP
	var open: bool = (destination not in f.engine._occupied_actor_tiles(state)
		and f.engine._tile_is_passable(state, destination))
	var after: Dictionary = _enemy_turn(f, state)
	var hero: Vector2i = after["player"]["pos"]
	var illusion: Vector2i = after["illusions"][0]["pos"]
	var losses: Array = [_hero_loss(state, after), _illusion_loss(state, after), _enemy_loss(state, after, 1)]
	var hp_before_push: Array = f.engine.gale_hero_hp_before_push
	f.observe("hollow_gale", open and F.PLAYER in held and ally in held and enemy in held and losses[0] > 0
		and losses[1] > 0 and losses[2] == 0 and hero == outside and illusion == ally,
		"Marked targets: hero / Illusion / enemy Health lost=%s, Health before Push=%s, hero landing=%s, Illusion stays at %s" %
		[losses, hp_before_push, hero, illusion])
	f.observe("hollow_gale_order", not hp_before_push.is_empty() and hp_before_push.all(func(hp: int) -> bool: return hp == F.HEALTH - losses[0]),
		"Hero's Health had already dropped to %s when Push was processed" % [hp_before_push])
	_commit(f, beyond, "hollow_gale")
	var outside_held: Array = beyond["enemies"][0]["intent"]["actions"][0]["declared_tiles"]
	var miss: Dictionary = _enemy_turn(f, beyond)
	var free_push_tile: Vector2i = outside + Vector2i.LEFT
	var free: bool = (free_push_tile not in f.engine._occupied_actor_tiles(beyond)
		and f.engine._tile_is_passable(beyond, free_push_tile))
	var source: Dictionary = beyond["enemies"][0]
	var distance: int = f.tile_distance(f.engine._closest_enemy_tile_to(source, outside), outside)
	f.observe("hollow_gale_outside", free and distance == 3 and outside not in outside_held
		and _hero_loss(beyond, miss) == 0 and miss["player"]["pos"] == outside
		and ally in outside_held and _illusion_loss(beyond, miss) > 0 and miss["illusions"][0]["pos"] == ally,
		"Outside reach at distance %d: hero Health lost=%d, tile=%s -> %s, landing tile free=%s, in-range Illusion Health lost=%d" %
		[distance, _hero_loss(beyond, miss), outside, miss["player"]["pos"], free, _illusion_loss(beyond, miss)])


static func splits(f: F) -> void:
	var state: Dictionary = f.fight([f.unit(F.ENEMY, 0, "cinder_ooze")])
	var spawn: Dictionary = F.Data.enemy_def("cinder_ooze")["death_spawn"]
	var counts: Array[int]
	var landings_ok: bool = true
	for blocked: int in [0, 3, 4]:
		var setup: Dictionary = state.duplicate(true)
		for index: int in range(blocked):
			setup["enemies"].append(f.unit(F.ENEMY + DIRECTIONS[index], index + 1))
		var before: int = setup["enemies"].size()
		var after: Dictionary = f.engine._damage_enemy_hit(setup, 0, F.HEALTH)
		var children: Array = after["enemies"].slice(before)
		counts.append(children.size())
		landings_ok = landings_ok and after["enemies"][0]["hp"] == 0
		for child: Dictionary in children:
			landings_ok = landings_ok and child["type"] == spawn["enemy_type"] and f.tile_distance(child["pos"], F.ENEMY) == 1
			for index: int in range(blocked):
				landings_ok = landings_ok and child["pos"] != F.ENEMY + DIRECTIONS[index]
	f.observe("splits", landings_ok and counts == [int(spawn["count"]), 1, 0],
		"Cinder Ooze spawns with 4 / 1 / 0 free adjacent tiles=%s. Free adjacent landings and child type verified=%s" %
		[counts, landings_ok])


static func _commit(f: F, state: Dictionary, id: String) -> void:
	state["enemies"][0]["intent"] = Guardian.commit_owned(f.engine, state, 0, F.Base.intent(state["enemies"][0]["type"], id))


static func _enemy_turn(f: F, state: Dictionary, id: String = "") -> Dictionary:
	if not id.is_empty():
		state["enemies"][0]["intent"] = F.Base.intent(state["enemies"][0]["type"], id)
	return f.engine.resolve_enemy_turn_with_steps(state, 0, true, false)["state"]


static func _hero_loss(before: Dictionary, after: Dictionary) -> int:
	return int(before["player"]["hp"]) - int(after["player"]["hp"])


static func _enemy_loss(before: Dictionary, after: Dictionary, index: int) -> int:
	return int(before["enemies"][index]["hp"]) - int(after["enemies"][index]["hp"])


static func _illusion_loss(before: Dictionary, after: Dictionary) -> int:
	return int(before["illusions"][0]["hp"]) - int(after["illusions"][0]["hp"])
