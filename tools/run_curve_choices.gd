extends RefCounted
## Offline route and out-of-combat decisions from the meas-06 director brief.
const Game = preload("res://scripts/game_data.gd")
const Events = preload("res://scripts/event_rules.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const HEALTHY_ROUTE: Array = ["combat", "event", "treasure", "merchant", "campfire", "special", "guardian", "boss"]
const WOUNDED_ROUTE: Array = ["campfire", "merchant", "event", "treasure", "combat", "special", "guardian", "boss"]
# The brief names a Strike tier but the catalog has no Strike card.
# Leave rather than inventing which of the starter spells the owner means.
const TODO_DESIGN_HEARTH_STRIKE_TIER_CARD_IDS: Array = []
var engine: RefCounted
var scores: Dictionary
var draft: String
var ladder: bool = false
var rng := RandomNumberGenerator.new()

func _init(run_engine: RefCounted, card_scores: Dictionary, draft_policy: String, seed_value: int, ladder_mode: bool = false) -> void:
	engine = run_engine
	scores = card_scores
	draft = draft_policy
	rng.seed = seed_value
	ladder = ladder_mode

func card(cards: Array) -> String:
	if cards.is_empty() or draft == "none": return ""
	if draft == "random": return str(cards[rng.randi_range(0, cards.size() - 1)])
	var best: String = str(cards[0])
	for id: String in cards:
		assert(scores.has(id), "Missing production heuristic score: " + id)
		if float(scores[id]) > float(scores[best]): best = id
	return best

func route_kind(room: Dictionary) -> String:
	var kind: String = str(room.get("type", "event"))
	if kind == "mystery":
		kind = Graph.display_type(room) if bool(room.get("scouted", false)) else "event"
	if not engine.merchant_kind_for_room({"type": kind}).is_empty(): return "merchant"
	return kind if HEALTHY_ROUTE.has(kind) else "event"

func destination(state: Dictionary) -> Vector2i:
	var moves: Array[Vector2i] = engine.available_moves(state)
	assert(not moves.is_empty(), "Whole run has no legal map destination")
	var wounded: bool = int(state["player_hp"]) * 2 <= int(state["player_max_hp"])
	var ranking: Array = WOUNDED_ROUTE if wounded else HEALTHY_ROUTE
	var best: Vector2i = moves[0]
	var best_rank: int = ranking.size() + 1
	for coord: Vector2i in moves:
		var kind: String = route_kind(engine.room_metadata(state, coord))
		var rank_value: int = ranking.find(kind)
		# A low-wallet merchant is excluded from the wounded priority; visit
		# it only if the engine makes it mandatory (the sole/best remaining exit).
		if wounded and kind == "merchant" and engine.held_embers(state) < 60: rank_value = ranking.size()
		if rank_value < best_rank:
			best_rank = rank_value
			best = coord
	return best

func equip_drops(state: Dictionary) -> Dictionary:
	if not engine.can_change_equipment(state): return state
	for id: String in state.get("equipment_inventory", []).duplicate():
		var slot: String = Game.equipment_slot(id)
		var current: String = str(state.get("equipped_equipment", {}).get(slot, ""))
		if current.is_empty() or Game.CARD_RARITY_TIERS.find(Game.equipment_rarity(id)) > Game.CARD_RARITY_TIERS.find(Game.equipment_rarity(current)):
			state = engine.equip_equipment(state, id)
	return state

func merchant(state: Dictionary) -> Dictionary:
	var kind: String = engine.merchant_kind_for_current_room(state)
	var cards: Array
	for id: String in engine.merchant_offer_ids(state, kind):
		if engine.merchant_item_kind(id) == engine.MERCHANT_ITEM_KIND_MAGIC and engine.merchant_buy_cost(kind, id, state) <= engine.held_embers(state): cards.append(id)
	var pick: String = card(cards)
	if not pick.is_empty(): state = engine.buy_merchant_item(state, kind, pick)
	for id: String in engine.merchant_offer_ids(state, kind):
		if engine.merchant_item_kind(id) != engine.MERCHANT_ITEM_KIND_GEAR: continue
		var slot: String = Game.equipment_slot(id)
		if str(state.get("equipped_equipment", {}).get(slot, "")).is_empty() and engine.merchant_buy_cost(kind, id, state) <= engine.held_embers(state):
			state = engine.buy_merchant_item(state, kind, id)
			state = engine.equip_equipment(state, id)
			break
	return state

func hearth(state: Dictionary) -> Dictionary:
	if ladder:
		if state["deck_cards"].size() > 10 and engine.can_purge_magic(state, "campfire"):
			var lowest: String = ""
			for id: String in state["deck_cards"]:
				if not (state.get("attuned_magic_cards", []) as Array).has(id) or not Game.magic_card_is_purgeable(id): continue
				assert(scores.has(id), "Missing heuristic purge score: " + id)
				if lowest.is_empty() or float(scores[id]) < float(scores[lowest]): lowest = id
			if not lowest.is_empty(): return engine.purge_magic_card(state, lowest, "campfire")
		return engine.leave_campfire(state)
	if int(state["player_hp"]) * 10 < int(state["player_max_hp"]) * 7:
		# REPL rest banks the wallet and ends the run. Linger is the production
		# healing-and-continue transition; do not synthesize a different rest.
		return engine.leave_campfire(state, engine.CAMPFIRE_LINGER_HEAL)
	# No production card-upgrade transition exists. Only owner-designated
	# starter Strike-tier cards may be purged; gear cards are not purgeable.
	for id: String in state.get("attuned_magic_cards", []):
		if bool(Game.card_def(id).get("starter", false)) and TODO_DESIGN_HEARTH_STRIKE_TIER_CARD_IDS.has(id) and Game.magic_card_is_purgeable(id) and engine.can_purge_magic(state, "campfire"):
			return engine.purge_magic_card(state, id, "campfire")
	return engine.leave_campfire(state)

func event_choice(state: Dictionary) -> String:
	var event_id: String = Events.current_id(state)
	var fallback: String = ""
	var leave: String = ""
	for choice: Dictionary in Game.event_def(event_id).get("choices", []):
		var id: String = str(choice["id"])
		if not Events.choice_available(state, event_id, id): continue
		fallback = id
		if id == "leave": leave = id
		# This is the same deterministic production transaction used by event
		# previews. Inspect actual deck size and gross Health costs, not a net
		# heal that could conceal an unaffordable sacrifice.
		var preview: Dictionary = Events.choose_event(state, id, engine)
		var cost: int = 0
		for outcome: Dictionary in preview.get("event_state", {}).get("outcomes", []):
			if str(outcome.get("type", "")) in ["hp", "heal", "heal_percent"]: cost += maxi(0, -int(outcome.get("amount", 0)))
		cost = maxi(cost, int(state["player_hp"]) - int(preview["player_hp"]))
		if cost * 4 < int(state["player_hp"]) and (preview["deck_cards"] as Array).size() >= (state["deck_cards"] as Array).size(): return id
	return leave if not leave.is_empty() else fallback
