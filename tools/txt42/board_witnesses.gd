extends RefCounted

# Targeting and Fatigue cases adapted from txt-40 board_witnesses.gd.
const F = preload("res://tools/txt42/fixture.gd")
const ADJACENT := Vector2i(4, 4)


static func targeting(f: F) -> void:
	var state: Dictionary = f.fight()
	var bolt: Dictionary = f.action(state, "arc_flash")
	var beacon: Dictionary = f.action(state, "beacon")
	var in_range: bool = f.engine.valid_targets_for_player_action(state, bolt).has(F.ENEMY)
	var distant := Vector2i(7, 4)
	var far: Dictionary = f.fight([f.unit(distant)])
	var out_of_range: bool = not f.engine.valid_targets_for_player_action(far, bolt).has(distant)
	var wall: Dictionary = state.duplicate(true)
	wall["grid"][ADJACENT.y][ADJACENT.x] = "wall"
	wall["umbra"]["vision_activations"] = 1
	var blocked: bool = not f.engine.valid_targets_for_player_action(wall, bolt).has(F.ENEMY)
	var bypass: bool = f.engine.valid_targets_for_player_action(wall, f.action(wall, "skybolt")).has(F.ENEMY)
	state["umbra"]["stage"] = "eclipse"
	var hidden: bool = not f.engine.is_enemy_visible_to_player(state, state["enemies"][0])
	var hidden_rejected: bool = not f.engine.valid_targets_for_player_action(state, bolt).has(F.ENEMY)
	var light_legal: bool = f.engine.valid_targets_for_player_action(state, beacon).has(F.ENEMY)
	var walk: Dictionary = {"type": "move", "range": 3}
	var empty_hidden := Vector2i(3, 2)
	var walk_legal: bool = f.engine.valid_targets_for_player_action(state, walk).has(empty_hidden)
	var unlit: bool = not f.engine.is_tile_visible_to_player(state, empty_hidden)
	var light: Dictionary = f.engine.apply_player_action(state, beacon, F.ENEMY)
	var legal_after_light: bool = f.engine.valid_targets_for_player_action(light, bolt).has(F.ENEMY)
	f.observe("targeting", in_range and out_of_range and blocked and bypass and hidden and hidden_rejected and light_legal
		and legal_after_light and walk_legal and unlit,
		"Arc Flash legal: visible/in range=%s, out of range=%s, behind wall=%s, hidden=%s, after Beacon=%s. Skybolt behind wall=%s. Hidden Beacon target=%s, unseen Walk destination=%s" %
			[in_range, not out_of_range, not blocked, not hidden_rejected, legal_after_light, bypass, light_legal, walk_legal])


static func fatigue(f: F) -> void:
	var state: Dictionary = f.fight()
	var draw: Dictionary = f.action(state, "beacon", 1)
	f.deck(state, [], [], ["brace", "quick_stab"])
	var reshuffled: Dictionary = f.engine.apply_player_action(state, draw)
	var loss: int = F.HEALTH - int(reshuffled["player"]["hp"])
	f.deck(state, ["beacon"])
	var empty_piles: Dictionary = f.engine.prepare_player_card(state, 0)
	var no_cards: Dictionary = f.engine.apply_player_action(empty_piles, draw)
	f.observe("fatigue", loss > 0 and reshuffled["deck"]["hand"].size() == 1 and reshuffled["deck"]["draw"].size() == 1
		and reshuffled["deck"]["discard"].is_empty() and no_cards["player"]["hp"] == F.HEALTH and no_cards["deck"]["cycles"] == 0
		and no_cards["deck"]["hand"] == empty_piles["deck"]["hand"],
		"discard available: drew %s, draw remainder=%d, Health loss=%d. Both piles empty: Health loss=%d, reshuffles=%d" %
			[reshuffled["deck"]["hand"], reshuffled["deck"]["draw"].size(), loss, F.HEALTH - int(no_cards["player"]["hp"]), no_cards["deck"]["cycles"]])



# Jolt's three target controls come from the txt-39 conduction witness.
static func electrified(f: F) -> void:
	var disconnected := Vector2i(6, 5)
	var state: Dictionary = f.fight([f.unit(ADJACENT), f.unit(F.ENEMY, 1), f.unit(disconnected, 2)])
	for tile: Vector2i in [ADJACENT, F.ENEMY, disconnected]:
		F.Ground.place(state, tile, "electrified")
	var strike: Dictionary = f.action(state, "jolt")
	var visible: Dictionary = f.engine.apply_player_action(state, strike, ADJACENT)
	state["umbra"]["stage"] = "eclipse"
	var hidden: bool = not f.engine.is_enemy_visible_to_player(state, state["enemies"][1])
	var dark: Dictionary = f.engine.apply_player_action(state, strike, ADJACENT)
	var losses: Array = [_enemy_loss(state, visible, 0), _enemy_loss(state, visible, 1),
		_enemy_loss(state, visible, 2), _enemy_loss(state, dark, 1)]
	f.observe("electrified", hidden and losses[0] > 0 and losses[1] > 0 and losses[2] == 0
		and losses[3] == 0 and _enemy_loss(state, dark, 0) > 0,
		"Jolt HP losses for primary / connected visible / disconnected / connected hidden: %s" % [losses])


static func _enemy_loss(before: Dictionary, after: Dictionary, index: int) -> int:
	return int(before["enemies"][index]["hp"]) - int(after["enemies"][index]["hp"])


static func swaps(f: F) -> void:
	var illusion_tile := Vector2i(3, 6)
	var state: Dictionary = f.engine._create_illusion(f.fight(), illusion_tile, F.HEALTH)
	var eclipsed: Dictionary = state.duplicate(true)
	eclipsed["umbra"]["stage"] = "eclipse"
	var cards: Dictionary = F.Data.cards()
	var swaps_found: Array[String]
	var hidden_accepted: Array[String]
	var controls_ok: bool = true
	for id: String in cards:
		controls_ok = _swap_card(f, state, eclipsed, illusion_tile, id, F.Data.card_def(id), swaps_found, hidden_accepted) and controls_ok
	for id: String in F.Data.card_upgrade_ids():
		controls_ok = _swap_card(f, state, eclipsed, illusion_tile, id, F.Data.upgraded_card_def(id), swaps_found, hidden_accepted) and controls_ok
	var enemy_trade: Dictionary = f.engine.apply_player_action(state, f.action(state, "changing_winds"), F.ENEMY)
	f.observe("swap", "empty_husk" in swaps_found and "changing_winds" in swaps_found and controls_ok
		and hidden_accepted.is_empty() and enemy_trade["player"]["pos"] == F.ENEMY
		and enemy_trade["enemies"][0]["pos"] == F.PLAYER,
		"Swap cards and upgrades=%s, visible swaps worked=%s, accepted a hidden Illusion=%s" %
		[swaps_found, controls_ok, hidden_accepted])


static func _swap_card(f: F, state: Dictionary, eclipsed: Dictionary, tile: Vector2i, id: String,
		card: Dictionary, found: Array[String], hidden_accepted: Array[String]) -> bool:
	var ok: bool = true
	for action: Dictionary in card.get("actions", []):
		var kind: String = action.get("type", "")
		if kind != "illusion_swap" and not (kind == "swap" and "illusion" in action.get("targets", ["enemy", "illusion"])):
			continue
		found.append(id)
		var visible: bool = f.engine.is_tile_visible_to_player(state, tile)
		var hidden: bool = not f.engine.is_tile_visible_to_player(eclipsed, tile)
		var legal: bool = tile in f.engine.valid_targets_for_player_action(state, action)
		var traded: Dictionary = f.engine.apply_player_action(state, action, tile)
		var rejected: Dictionary = f.engine.apply_player_action(eclipsed, action, tile)
		if tile in f.engine.valid_targets_for_player_action(eclipsed, action) or rejected["player"]["pos"] == tile:
			hidden_accepted.append(id)
		ok = ok and visible and hidden and legal and traded["player"]["pos"] == tile and traded["illusions"][0]["pos"] == F.PLAYER
	return ok
