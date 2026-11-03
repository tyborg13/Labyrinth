extends SceneTree

# el-04: the battlefield rule's beat token in the turn-order rail and its board preview.
# el-05: the due beat's move ghosts (Upheaval throw, Shadowstep Blink) and beats in the card landing strip.
# The rule panel itself is covered by en02_enemies_suite and snare_ui_test.
const Fixture = preload("res://tools/warband_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const BattlefieldRules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const RuleView = preload("res://scripts/battlefield_rule_view.gd")
const Slots = preload("res://scripts/turn_order_slots.gd")
const LandingStrip = preload("res://scripts/turn_order_landing_strip.gd")
const SceneScript = preload("res://scripts/run_scene.gd")
const WindView = preload("res://scripts/enemy_mechanics/wind_view.gd")
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	_test_beat_entries()
	_test_beat_identity()
	_test_beat_slot()
	_test_board_preview()
	_test_move_ghosts()
	_test_shade_texture()
	_test_strip_beat_slot()
	_test_ghost_boundaries()
	_test_snare_survivor_and_overflow()
	await _test_panel_height()
	await _test_intro_dock()
	print("EL04 RULE VIEWS RESULT: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)

# The panel docks by its computed height; the laid-out container must agree for every rule sentence.
func _test_panel_height() -> void:
	var hud: PanelContainer = preload("res://scripts/battlefield_rule_hud.gd").new()
	root.add_child(hud)
	var engine := Combat.new()
	for element: String in ["air", "fire", "ice", "lightning", "earth", "shadow"]:
		var state: Dictionary = _warband(element, false)
		hud.set_combat_state(state, engine)
		for width: float in [350.0, 420.0]:
			var height: float = hud.preferred_height(width)
			hud.set_hud_rect(Rect2(0.0, 0.0, width, height))
			await process_frame
			await process_frame
			_expect(is_equal_approx(hud.size.y, height), "%s rule panel at %d px settles at its docking height (%.1f vs %.1f)" % [element, int(width), hud.size.y, height])
	hud.free()

# After the objective intro settles, the rule panel shows docked exactly above the objective.
func _test_intro_dock() -> void:
	var engine := Run.new()
	var run: Dictionary = Fixture.build(engine, Combat.new(), engine.create_new_run(Fixture.FIXTURE_SEED, Store.default_data()), {"warband_biome": "ice", "warband_tier": 2})
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.call("_load_run_state", run)
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	# The full-motion intro: its travel ends without any other HUD refresh.
	await scene.call("_animate_combat_objective_intro")
	var objective: Control = scene.get("_combat_objective_hud")
	var rule: Control = scene.get("_battlefield_rule_hud")
	_expect(objective != null and not bool(objective.get("intro_active")) and objective.visible, "The objective intro settles")
	_expect(rule != null and rule.visible, "The rule panel shows once the objective intro settles, without another refresh")
	if rule != null and objective != null:
		await process_frame
		var gap: float = objective.get_global_rect().position.y - rule.get_global_rect().end.y
		_expect(is_equal_approx(gap, scene.BATTLEFIELD_RULE_DOCK_GAP), "The rule panel docks exactly %d px above the objective (gap %.1f)" % [int(scene.BATTLEFIELD_RULE_DOCK_GAP), gap])
		_expect(is_equal_approx(rule.get_global_rect().position.x, objective.get_global_rect().position.x) and is_equal_approx(rule.size.x, objective.size.x), "The rule panel shares the objective's column")
	scene.queue_free()
	await process_frame

# A beat keeps its rail identity when an unrelated actor leaves the order.
func _test_beat_identity() -> void:
	var engine := Combat.new()
	var state: Dictionary = _warband("air", false)
	var before: Array[Dictionary] = _beats(engine.current_turn_order(state, 12))
	var source_id: int = int(state["battlefield_rule"]["source"]["id"])
	var trimmed: Dictionary = state.duplicate(true)
	for index: int in range(trimmed["enemies"].size()):
		if int(trimmed["enemies"][index]["id"]) != source_id:
			trimmed["enemies"].remove_at(index)
			break
	var after: Array[Dictionary] = _beats(engine.current_turn_order(trimmed, 12))
	_expect(not before.is_empty() and not after.is_empty() and str(before[0]["actor_key"]) == str(after[0]["actor_key"]), "A beat's rail key survives an unrelated actor leaving")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _warband(element: String, due: bool) -> Dictionary:
	var engine := Run.new()
	var combat: Dictionary = Fixture.build(engine, Combat.new(), engine.create_new_run(Fixture.FIXTURE_SEED, Store.default_data()), {"warband_biome": element, "warband_tier": 2})["combat_state"]
	var rule: Dictionary = combat["battlefield_rule"]
	if due: rule["counter"] = int(rule["cadence"]["every"]) - 1
	# These controls isolate already-announced danger/ghost rendering.
	preload("res://tests/suites/battlefield_rules_suite.gd").mature_fuel(combat)
	return combat

func _beats(entries: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for entry: Dictionary in entries:
		if str(entry.get("kind", "")) == "beat": result.append(entry)
	return result

func _test_beat_entries() -> void:
	var engine := Combat.new()
	var state: Dictionary = _warband("air", false)
	var order: Array[Dictionary] = engine.current_turn_order(state, 12)
	var beats: Array[Dictionary] = _beats(order)
	_expect(not beats.is_empty(), "The Stormcaller's every-turn Gust shows a beat in the rail")
	var beat: Dictionary = beats[0] if not beats.is_empty() else {}
	var panel: Dictionary = BattlefieldRules.panel(state)
	_expect(str(beat.get("name", "")) == "Gust" and str(beat.get("icon", "")) == "wind" and str(beat.get("sentence", "")) == str(panel.get("sentence", "x")), "A beat entry names its rule, icon and sentence")
	_expect(int(beat.get("time", -1)) == int(beat.get("at", -2)), "A beat sits at the clock of the turn it follows")
	var keys: Dictionary = {}
	for entry: Dictionary in beats: keys[str(entry.get("actor_key", ""))] = true
	_expect(keys.size() == beats.size() and not keys.has(""), "Every beat entry has its own rail key")
	# el-05: a beat landing before you shows in the strip as its rule token, but only actors cancel ACT AGAIN.
	var hero: Dictionary = {"kind": "player", "actor_key": "player", "projected": true}
	var foe: Dictionary = {"kind": "enemy", "actor_key": "enemy_1"}
	var active: Dictionary = {"kind": "player", "actor_key": "player", "active": true}
	var with_foe: Dictionary = LandingStrip.roles_for(_entries([active, foe, beat, hero]))
	_expect((with_foe.get("before", []) as Array).has(beat) and not bool(with_foe.get("act_again", true)), "A beat lands in the strip beside the actors before you")
	var beat_only: Dictionary = LandingStrip.roles_for(_entries([active, beat, hero]))
	_expect((beat_only.get("before", []) as Array) == [beat] and bool(beat_only.get("act_again", false)), "With only a beat ahead, you still act again")
	_expect(beat.has("eta"), "A beat carries its anchor's time numeral")

# Windows-safe typed array (AGENTS: never assign a bare literal to Array[T]).
func _entries(items: Array) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for item: Dictionary in items: result.append(item)
	return result

func _test_beat_slot() -> void:
	var scene: Control = SceneScript.new()
	var engine := Combat.new()
	scene._combat_state = _warband("air", false)
	var beats: Array[Dictionary] = _beats(engine.current_turn_order(scene._combat_state, 12))
	if beats.is_empty():
		scene.free()
		return
	var slot: Control = Slots.update(scene, beats[0], 3)
	var token: Control = slot.find_child("TurnOrderBeatToken", true, false)
	_expect(token != null and token.find_child("TurnOrderBeatIcon", true, false) != null, "A beat slot draws the rule token with its icon")
	_expect(slot.find_child("TurnOrderPortraitCrop", true, false) == null, "A beat slot has no portrait (it never falls back to the hero)")
	_expect(slot.tooltip_text == "Gust — " + str(beats[0]["sentence"]), "A beat slot's tooltip names the rule and its sentence")
	_expect(slot.find_child("TurnOrderTimeNumeral", true, false) != null, "A beat slot keeps the rail's time numeral")
	slot.free()
	scene.free()

func _test_board_preview() -> void:
	var engine := Combat.new()
	var due: Dictionary = _warband("earth", true)
	_expect(RuleView.beat_before_next_player_turn(due), "A primed Thornmother beat lands before the hero acts again")
	var expected: Array = []
	for group: Array in BattlefieldRules.forecast(engine, due)["tiles"].values():
		for tile: Vector2i in group:
			if not expected.has(tile): expected.append(tile)
	var shown: Dictionary = RuleView.presentation_for(due, {})
	var threats: Array = shown.get("threats_at_rest", {}).get("threats", [])
	var marked: Array = []
	for threat: Dictionary in threats:
		if str(threat.get("key", "")) == RuleView.THREAT_KEY: marked = threat["tiles"]
	_expect(not expected.is_empty() and marked == expected, "A due Upheaval marks exactly the forecast tiles as a threat at rest")
	var later: Dictionary = _warband("earth", false)
	_expect(not RuleView.beat_before_next_player_turn(later) and RuleView.presentation_for(later, {}).is_empty(), "A beat that isn't due before the hero's next turn marks nothing")
	var enemy_turn: Dictionary = due.duplicate(true)
	enemy_turn["current_actor"] = {"kind": "enemy", "id": 1}
	_expect(RuleView.presentation_for(enemy_turn, {}).is_empty(), "No beat preview during enemy turns")

# The three board members the ghost builder reads; every tile counts as visible here.
class GhostView extends Control:
	var combat_state: Dictionary
	var presentation: Dictionary = {}
	var tiles_visible: bool = true
	func _board_tile_is_visible_to_player(_tile: Vector2i) -> bool: return tiles_visible

func _test_move_ghosts() -> void:
	var engine := Combat.new()
	var view := GhostView.new()
	view.combat_state = _warband("shadow", true)
	var state: Dictionary = view.combat_state
	var forecast: Dictionary = BattlefieldRules.forecast(engine, state)
	var hidden: Dictionary = {}
	for enemy: Dictionary in state["enemies"]:
		if int(enemy.get("hp", 0)) > 0 and not engine.is_enemy_visible_to_player(state, enemy): hidden["enemy_%d" % int(enemy["id"])] = true
	var emergences: Array = forecast.get("emergences", [])
	_expect(not hidden.is_empty() and not emergences.is_empty(), "The shadow Warband's hidden followers have landings you will see")
	for move: Dictionary in forecast.get("moves", []):
		_expect(not hidden.has(str(move["actor_key"])), "A hidden mover never appears in the forecast's moves")
	var ghosts: Array[Dictionary] = RuleView.move_ghosts(view)
	_expect(ghosts.size() == emergences.size(), "One shade stands at each Blink landing")
	for ghost: Dictionary in ghosts:
		_expect(str(ghost["type"]) == RuleView.SHADE_TYPE and str(ghost["role"]) == RuleView.ENEMY_MOVE_ROLE and int(ghost["id"]) == -1 and emergences.has(ghost["pos"]), "A Blink ghost is the anonymous shade at its landing")
	view.combat_state = _warband("shadow", false)
	_expect(RuleView.move_ghosts(view).is_empty(), "No ghosts until the beat lands before you act")
	var earth: Dictionary = _warband("earth", true)
	var rise: Array = BattlefieldRules.forecast(engine, earth).get("tiles", {}).get("rise", [])
	var occupant: Dictionary = {}
	for enemy: Dictionary in earth["enemies"]:
		# Keep the source at its authored anchor: bos-01 now rejects a held
		# rise that would leave a relocated source with fewer than two exits.
		if int(enemy.get("id", -1)) != int(earth["battlefield_rule"]["source"]["id"]) and int(enemy.get("hp", 0)) > 0 and enemy.get("footprint", Vector2i.ONE) == Vector2i.ONE:
			occupant = enemy
			break
	_expect(not rise.is_empty() and not occupant.is_empty(), "The earth Warband marks tiles and has a single-tile enemy to stand on one")
	if not rise.is_empty() and not occupant.is_empty():
		occupant["pos"] = rise[0]
		view.combat_state = earth
		ghosts = RuleView.move_ghosts(view)
		_expect(ghosts.size() == 1 and str(ghosts[0]["type"]) == str(occupant["type"]) and str(ghosts[0]["role"]) == WindView.GHOST_ROLE and ghosts[0]["pos"] != rise[0], "An Upheaval throw shows the occupant's pale ghost where it lands")
	view.free()

# The shade ghost is the figure alone, standing on its tile at about the hero's height.
func _test_shade_texture() -> void:
	var image: Image = RuleView.shade_texture().get_image()
	var used: Rect2i = image.get_used_rect()
	_expect(used.end.y == image.get_height(), "The shade stands on its tile")
	var share: float = float(used.size.y) / float(image.get_height())
	_expect(share > 0.40 and share < 0.50, "The shade fills about 45% of the unit frame's height")

func _test_strip_beat_slot() -> void:
	var strip: Control = LandingStrip.new()
	var target := Control.new()
	root.add_child(target)
	root.add_child(strip)
	var beat: Dictionary = {"kind": "beat", "rule": "shadowstep", "actor_key": "beat_shadowstep_enemy_1_12_0", "icon": "shadowstep", "eta": 4, "time": 12}
	var entries: Array[Dictionary] = _entries([{"kind": "player", "actor_key": "player", "active": true}, {"kind": "enemy", "actor_key": "enemy_1", "type": "gloam_stalker"}, beat, {"kind": "player", "actor_key": "player", "projected": true, "eta": 9}])
	strip.call("present", entries, 0, target, null, func(_entry: Dictionary) -> String: return "res://assets/art/icons/umbra_presence.png", Callable(), true)
	var slot: Node = strip.get_node_or_null("LandingStripSlot_1")
	var numeral: Label = slot.get_node_or_null("LandingStripTimeNumeral") as Label if slot != null else null
	_expect(slot != null and slot.get_node_or_null("LandingStripBeatToken/LandingStripBeatIcon") != null and numeral != null and numeral.text == "4", "The strip draws the beat as its rule token with its time numeral")
	strip.queue_free()
	target.queue_free()

# el-05 review (Codex, 4a1e…66769a3a8): privacy, guards, Snare boundary, illusions, texture override, strip roles.
func _test_ghost_boundaries() -> void:
	var engine := Combat.new()
	var view := GhostView.new()
	var shadow: Dictionary = _warband("shadow", true)
	view.combat_state = shadow
	_expect(not RuleView.move_ghosts(view).is_empty(), "Positive shadow ghost control")
	view.combat_state = shadow.duplicate(true)
	view.combat_state["current_actor"] = {"kind": "enemy", "id": 1}
	_expect(RuleView.move_ghosts(view).is_empty(), "Enemy turns have no move ghosts")
	view.combat_state = shadow
	view.tiles_visible = false
	_expect(RuleView.move_ghosts(view).is_empty(), "Hidden board landings have no move ghosts")
	view.tiles_visible = true
	_expect(RuleView.shade_texture() == RuleView.shade_texture(), "Shade texture identity is reused")
	var before: Dictionary = shadow.duplicate(true)
	var hidden_id: int = -1
	for enemy: Dictionary in before["enemies"]:
		if int(enemy.get("hp", 0)) > 0 and not engine.is_enemy_visible_to_player(before, enemy):
			hidden_id = int(enemy["id"])
			break
	var after: Dictionary = before.duplicate(true)
	engine._surface_actor(after, "enemy", hidden_id)["pos"] = before["player"]["pos"]
	var projected: Dictionary = preload("res://scripts/battlefield_rules/outcomes.gd").project(engine, before, after)
	_expect(projected["emergences"] == [before["player"]["pos"]] and projected["moves"].is_empty(), "Hidden emergence projection contains exactly its visible Vector2i landing")
	var invisible_destination := Vector2i(-1, -1)
	for y: int in range(before["grid"].size()):
		for x: int in range(before["grid"][y].size()):
			var candidate := Vector2i(x, y)
			if candidate != engine._surface_actor(before, "enemy", hidden_id)["pos"] and not engine.is_tile_visible_to_player(before, candidate): invisible_destination = candidate
	engine._surface_actor(after, "enemy", hidden_id)["pos"] = invisible_destination
	projected = preload("res://scripts/battlefield_rules/outcomes.gd").project(engine, before, after)
	_expect(projected["emergences"].is_empty() and projected["moves"].is_empty(), "An invisible hidden-mover destination remains private")
	var anchor: Dictionary = {"kind": "enemy", "enemy_id": int(_warband("air", false)["battlefield_rule"]["source"]["id"]), "actor_key": "enemy_source", "time": 123, "eta": 47}
	var order: Array[Dictionary] = BattlefieldRules.project_turn_order(engine, _warband("air", false), _entries([anchor]), 12)
	_expect(order.size() == 2 and int(order[1].get("eta", -1)) == 47, "Beat ETA equals a nonzero anchor ETA")
	var board := preload("res://scripts/combat_board_view.gd").new()
	board.size = Vector2(1920, 1080)
	root.add_child(board)
	var shown_ids: Array
	for enemy: Dictionary in shadow["enemies"]:
		if engine.is_enemy_visible_to_player(shadow, enemy): shown_ids.append(int(enemy["id"]))
	board.call("set_combat_state", shadow, [], [], Vector2i(-1, -1), "", "", {}, {}, {"reduced_motion": true, "umbra_visible_tiles": engine.umbra_visible_tiles(shadow), "visible_enemy_ids": shown_ids})
	var board_units: Array = board.call("_visible_units")
	var shade_units: Array = board_units.filter(func(unit: Dictionary) -> bool: return unit.get("type", "") == RuleView.SHADE_TYPE)
	_expect(shade_units.size() == RuleView.move_ghosts(view).size() and not shade_units.is_empty(), "Board integrates each rule shade ghost")
	var hud_units: Array = board.call("_hud_layout_units")
	for shade: Dictionary in shade_units:
		_expect(board.call("_unit_is_preview_echo", shade) and not hud_units.has(shade), "Rule shades are preview echoes excluded from HUD")
		_expect(board.call("_texture_for_unit", shade) == RuleView.shade_texture(), "Shade texture override reaches its preview unit")
		board.set("_controller_focus_tile", shade["pos"])
		_expect(str(board.call("_hud_hover_actor_key", hud_units)).is_empty(), "Rule shade has no hover identity")
		_expect((board.get("_units_by_draw_tile_cache") as Dictionary).get(shade["pos"], []).has(shade), "Rule shade belongs to its landing's depth group")
	var marker: Texture2D = ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
	var real: Dictionary = {"role": "enemy", "type": "crawler", "id": 1, "key": "enemy_1", "pos": Vector2i(3, 3), "hp": 10}
	var original_texture: Texture2D = board.call("_texture_for_unit", real)
	real["ghost_texture"] = marker
	var overridden: Texture2D = board.call("_texture_for_unit", real)
	_expect(overridden == original_texture, "Ghost_texture must not override a real enemy")
	board.free()
	var earth: Dictionary = _warband("earth", true)
	var rise: Array = BattlefieldRules.forecast(engine, earth).get("tiles", {}).get("rise", [])
	var illusion: Dictionary = earth["player"].duplicate(true)
	illusion.merge({"id": 99, "hp": 10, "max_hp": 10, "pos": rise[0], "footprint": Vector2i.ONE}, true)
	earth["illusions"] = [illusion]
	view.combat_state = earth
	var predicted: Dictionary = BattlefieldRules.forecast(engine, earth)
	var ghosts: Array[Dictionary] = RuleView.move_ghosts(view)
	_expect((predicted["moves"] as Array).any(func(move: Dictionary) -> bool: return move["actor_key"] == "illusion_99"), "Positive displaced illusion control")
	_expect(ghosts.any(func(ghost: Dictionary) -> bool: return int(ghost.get("id", -1)) == 99), "Upheaval needs a ghost for the displaced illusion")
	var snare: Dictionary = preload("res://tests/suites/snare_pressure_suite.gd").battle("earth")
	preload("res://tests/suites/battlefield_rules_suite.gd").mature_fuel(snare)
	var marked: Array = BattlefieldRules.forecast(engine, snare)["tiles"]["rise"]
	var tick: Dictionary = snare["enemies"][0]
	tick["type"] = "ember_tick"
	tick["hp"] = 1
	tick["block"] = 0
	tick["stoneskin"] = 0
	tick["pos"] = marked[0]
	tick.erase("snare_sealbinder")
	snare["player"]["pos"] = marked[0] + Vector2i.LEFT
	snare["relics"] = ["worldheart"]
	snare["player"]["block"] = 2
	view.combat_state = snare
	ghosts = RuleView.move_ghosts(view)
	var prepared: Dictionary = engine.prepare_player_activation_end(snare)
	var prepared_projection: Dictionary = BattlefieldRules.forecast(engine, prepared)
	var ended: Dictionary = engine.finish_player_activation(snare)
	_expect(int(ended["enemies"][0]["hp"]) == 0, "Real Worldheart preparation kills the tick before Upheaval")
	_expect(not ghosts.any(func(ghost: Dictionary) -> bool: return int(ghost.get("id", -1)) == int(tick["id"])), "Snare ghost must use the prepared boundary, excluding the tick killed before the beat")
	var many: Array[Dictionary] = _entries([{"kind": "player", "active": true}])
	for index: int in range(6): many.append({"kind": "beat", "actor_key": "beat_%d" % index, "eta": index, "icon": "upheaval"})
	many.append({"kind": "player", "projected": true})
	var roles: Dictionary = LandingStrip.roles_for(many)
	_expect(roles["before"].size() == 6 and int(roles["overflow"]) == 2 and roles["act_again"], "Beats preserve the overflow count and ACT AGAIN")
	var old_signature: String = LandingStrip.content_signature(roles, 0)
	roles["before"][0]["eta"] = 55
	_expect(old_signature != LandingStrip.content_signature(roles, 0), "Beat changes invalidate the strip content signature")
	view.free()

	_test_shade_pixels()

# The shade is the dark figure only, as one pale Umbra colour; the violet aura and sparks are dropped.
func _test_shade_pixels() -> void:
	var image: Image = RuleView.shade_texture().get_image()
	var pale: Color = preload("res://scripts/ui_palette.gd").UMBRA.lightened(RuleView.SHADE_LIGHTEN)
	var source: Image = preload("res://scripts/asset_loader.gd").load_texture_source_first(RuleView.SHADE_SOURCE_PATH).get_image()
	if source.is_compressed(): source.decompress()
	var dark: int = 0
	for y: int in range(source.get_height()):
		for x: int in range(source.get_width()):
			var pixel: Color = source.get_pixel(x, y)
			if pixel.a > 0.08 and pixel.v < RuleView.SHADE_BODY_MAX_VALUE: dark += 1
	var opaque: int = 0
	var off_colour: int = 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a <= 0.0: continue
			opaque += 1
			# Stored as 8-bit RGBA: allow one step of quantisation per channel.
			if absf(pixel.r - pale.r) > 1.5 / 255.0 or absf(pixel.g - pale.g) > 1.5 / 255.0 or absf(pixel.b - pale.b) > 1.5 / 255.0: off_colour += 1
	_expect(opaque == dark and off_colour == 0, "The shade keeps exactly the source's dark figure pixels, all in the pale Umbra colour")

# A surviving Snare occupant gets its prepared landing ghost; six beats render four slots plus +2 (el-05 re-review).
func _test_snare_survivor_and_overflow() -> void:
	var engine := Combat.new()
	var view := GhostView.new()
	var snare: Dictionary = preload("res://tests/suites/snare_pressure_suite.gd").battle("earth")
	preload("res://tests/suites/battlefield_rules_suite.gd").mature_fuel(snare)
	var marked: Array = BattlefieldRules.forecast(engine, snare)["tiles"]["rise"]
	var survivor: Dictionary = snare["enemies"][0]
	survivor["pos"] = marked[0]
	survivor.erase("snare_sealbinder")
	view.combat_state = snare
	var prepared: Dictionary = engine.prepare_player_activation_end(snare)
	var projected: Dictionary = BattlefieldRules.forecast(engine, prepared)
	var key: String = "enemy_%d" % int(survivor["id"])
	var moves: Array = projected.get("moves", [])
	var expected: Array = moves.filter(func(move: Dictionary) -> bool: return str(move["actor_key"]) == key)
	_expect(expected.size() == 1, "The Snare control has exactly one surviving displaced occupant")
	var ghosts: Array[Dictionary] = RuleView.move_ghosts(view)
	_expect(ghosts.any(func(ghost: Dictionary) -> bool: return int(ghost["id"]) == int(survivor["id"]) and ghost["pos"] == expected[0]["to"]), "A surviving Snare occupant receives its prepared landing ghost")
	view.free()
	var strip: Control = LandingStrip.new()
	var target := Control.new()
	root.add_child(target)
	root.add_child(strip)
	var entries: Array[Dictionary] = _entries([{"kind": "player", "active": true}])
	for index: int in range(6): entries.append({"kind": "beat", "actor_key": "beat_review_%d" % index, "eta": index, "icon": "upheaval"})
	entries.append({"kind": "player", "projected": true})
	strip.call("present", entries, 0, target, null, func(_entry: Dictionary) -> String: return "res://assets/art/icons/umbra_presence.png", Callable(), true)
	var slots: int = 0
	for child: Node in strip.get_children():
		if str(child.name).begins_with("LandingStripSlot_"): slots += 1
	var overflow: Label = strip.get_node_or_null("LandingStripOverflow")
	_expect(slots == 4 and overflow != null and overflow.text == "+2", "Six beats render four slots and one +2 overflow label")
	strip.free()
	target.free()
