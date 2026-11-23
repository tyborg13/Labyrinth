extends SceneTree

const EngineRules = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const RiteRules = preload("res://scripts/rite_rules.gd")
const Store = preload("res://scripts/progression_store.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Scene = preload("res://scripts/run_scene.gd")
const Console = preload("res://tools/headless_playtest.gd")
const Slots = preload("res://scripts/turn_order_slots.gd")
const Areas = preload("res://scripts/boss_area_rules.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const COMBAT_SEED: int = 8031
const REVIEW_ORDER_LIMIT: int = 12
const HERO := Vector2i(1, 1)
const LIT_ENEMY := Vector2i(5, 3)
const HIDDEN_ENEMY := Vector2i(7, 7)

var _failures: Array[String]
var _checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var engine := EngineRules.new()
	var state: Dictionary = _combat(engine)
	var lit: Dictionary = engine._create_umbra_light_source(state.duplicate(true), Vector2i(3, 3), {"radius": 2, "duration": 1, "light_owner": "enemy"})
	_expect(engine._light_source_covers_tile(lit, LIT_ENEMY), "Light covers the edge of its radius")
	_expect(int(lit["enemies"][0].get("expose", 0)) == 0, "placing Light does not immediately Expose")
	var started: Dictionary = engine._resolve_enemy_start_of_turn(lit, 0)["state"]
	_expect(int(started["enemies"][0].get("expose", 0)) == 2, "enemy starts in Light and gains Expose 2")
	_expect(int(started["enemies"][1].get("expose", 0)) == 0, "enemy outside Light gains no Expose")
	var icy_light: Dictionary = Surface.place(lit.duplicate(true), LIT_ENEMY, "ice")
	icy_light = engine._resolve_enemy_start_of_turn(icy_light, 0)["state"]
	_expect(int(icy_light["enemies"][0].get("expose", 0)) == 2, "Ice and Light refresh the same Expose status")
	var overlapping: Dictionary = engine._create_umbra_light_source(started, HERO, {"radius": 8})
	overlapping["player"]["expose"] = 0
	overlapping["illusions"] = [{"id": 9, "pos": Vector2i(2, 1), "hp": 3, "max_hp": 3}]
	overlapping = engine._resolve_enemy_start_of_turn(overlapping, 0)["state"]
	_expect(int(overlapping["enemies"][0].get("expose", 0)) == 2, "overlapping Light applies Expose once")
	_expect(int(engine._resolve_player_start_of_turn(overlapping)["player"].get("expose", 0)) == 0, "Light does not Expose the hero at turn start")
	_expect(int(overlapping["illusions"][0].get("expose", 0)) == 0, "Light does not Expose illusions")
	var lasting: Dictionary = lit.duplicate(true)
	for turn: int in range(5):
		lasting = engine._tick_umbra_player_activation(lasting)
	_expect(engine._light_source_covers_tile(lasting, LIT_ENEMY), "placed Light lasts across player turns")
	var hidden: Dictionary = state["enemies"][1]
	var before_tiles: Array[Vector2i] = engine.umbra_visible_tiles(state)
	_expect(not engine.is_enemy_visible_to_player(state, hidden), "enemy is hidden before Vision")
	var vision: Dictionary = engine._apply_umbra_vision(state.duplicate(true), {"duration": 2})
	_expect(engine.is_enemy_visible_to_player(vision, hidden), "Vision shows a hidden enemy")
	_expect(engine.umbra_visible_tiles(vision) == before_tiles, "Vision leaves the dark tiles alone")
	vision = engine._tick_umbra_player_activation(vision)
	_expect(engine.is_enemy_visible_to_player(vision, hidden), "Vision lasts through the first turn boundary")
	vision = engine._tick_umbra_player_activation(vision)
	_expect(not engine.is_enemy_visible_to_player(vision, hidden), "Vision ends at its second turn boundary")
	var visible_targets: Array[Vector2i] = engine.valid_targets_for_player_action(state, {"type": "ranged", "range": 20, "damage": 1})
	_expect(not visible_targets.has(HIDDEN_ENEMY), "ordinary targeting hides the enemy")
	vision = engine._apply_umbra_vision(state.duplicate(true), {"duration": 1})
	visible_targets = engine.valid_targets_for_player_action(vision, {"type": "ranged", "range": 20, "damage": 1})
	_expect(visible_targets.has(HIDDEN_ENEMY), "Vision permits targeting the revealed enemy")
	_check_cards(engine, state)
	_check_light_lifetimes(engine, state)
	_check_ice_stagger_light(engine, state)
	_check_checkpoint_migration(engine, state)
	_check_old_rite(engine, state)
	_check_thornwall(engine, state)
	_check_intent_layout(engine, state)
	_check_turn_order(engine, state)
	_check_last_eclipse(engine, state)
	_check_hero_aura(engine, state)
	_check_card_play_analytics(engine, state)
	_check_contextual_grimoire()
	var legacy: Dictionary = state.duplicate(true)
	legacy["umbra"].erase("vision_activations")
	legacy["umbra"]["truesight_activations"] = 2
	legacy["umbra"]["light_sources"] = [{"id": 17, "pos": LIT_ENEMY, "radius": 1, "remaining_activations": 1}]
	var migrated: Dictionary = Store._migrate_run_dictionary({"combat_state": legacy, "pending_combat_checkpoints": [{"state": legacy.duplicate(true)}]})
	var saved: Dictionary = migrated["combat_state"]
	_expect(int(saved["umbra"].get("vision_activations", 0)) == 2 and not saved["umbra"].has("truesight_activations"), "save migrates active Truesight to Vision")
	_expect(int(saved["umbra"]["light_sources"][0]["remaining_activations"]) == -1, "save makes active Light lasting")
	_expect(engine.is_enemy_visible_to_player(saved, hidden), "migrated Vision reveals enemies")
	_expect(migrated["pending_combat_checkpoints"][0]["state"]["umbra"] == saved["umbra"], "pending combat checkpoint migrates Vision and Light")
	for file: String in ["cards", "relics", "skills", "glossary", "grimoire", "pattern_rule_text"]:
		var source: String = FileAccess.get_file_as_string("res://data/%s.json" % file).to_lower()
		_expect(not source.contains("truesight") and not source.contains("dispel_umbra") and not source.contains("dispel umbra"), "%s removes Truesight and Dispel Umbra" % file)
	for failure: String in _failures:
		print("FAIL " + failure)
	print("LIGHT AND VISION RULES: %d checks, %d failures" % [_checks, _failures.size()])
	print("TEST RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)

func _check_cards(engine: EngineRules, state: Dictionary) -> void:
	var seek: Dictionary = GameData.card_def("seek_the_light")["actions"][0]
	var near := Vector2i(2, 1)
	var far := Vector2i(5, 1)
	var beyond := Vector2i(7, 1)
	var targets: Array[Vector2i] = engine.valid_targets_for_player_action(state, seek)
	_expect(targets.has(near) and not targets.has(far), "Seek the Light has a short unlit Blink")
	var prepared: Dictionary = engine._create_umbra_light_source(state.duplicate(true), far, {"radius": 2})
	targets = engine.valid_targets_for_player_action(prepared, seek)
	_expect(targets.has(far) and not targets.has(beyond), "Seek the Light extends only to lit tiles within Range 5")
	var flashed: Dictionary = engine.apply_player_action(state, GameData.card_def("flash_powder")["actions"][0], Vector2i(3, 2))
	_expect(int(flashed["enemies"][0].get("expose", 0)) == 0 and engine._light_source_covers_tile(flashed, LIT_ENEMY),
		"Flash Powder creates Light without its former immediate Expose")
	for card_id: String in ["daybreak", "break_the_veil"]:
		var action: Dictionary = GameData.card_def(card_id)["actions"][0]
		var dawn: Dictionary = engine.apply_player_action(state, action)
		var lights: Array = dawn["umbra"]["light_sources"]
		var radius: int = 4 if card_id == "daybreak" else 3
		_expect(lights.size() == 1 and lights[0]["pos"] == HERO and int(lights[0]["radius"]) == radius,
			"%s creates its v5 Light where the hero stands" % card_id)
		_expect(engine.effective_umbra_stage(dawn) == engine.effective_umbra_stage(state),
			"%s leaves the Umbra stage alone" % card_id)
	var chains: Dictionary = Surface.place(state.duplicate(true), LIT_ENEMY, "ice")
	chains["player"]["pos"] = LIT_ENEMY + Vector2i.LEFT
	var actions: Array = engine.card_play_actions("icebound_chains", chains)
	chains = engine.apply_player_action(chains, actions[0], LIT_ENEMY)
	chains = engine.apply_player_action(chains, actions[1])
	var staggered: bool = (chains["surface_events"] as Array).any(func(event: Dictionary) -> bool:
		return event.get("status") == "stagger" and int(event.get("amount", 0)) == 6)
	_expect(staggered and int(chains["umbra"]["vision_activations"]) == 2, "Icebound Chains Staggers 6 on Ice and grants Vision for 2 turns")

func _check_light_lifetimes(engine: EngineRules, state: Dictionary) -> void:
	var brazier_state: Dictionary = state.duplicate(true)
	brazier_state["guardian_braziers"] = [{"id": 1, "pos": LIT_ENEMY, "lit": true}]
	_expect(engine.enemy_turn_start_light_expose(brazier_state, brazier_state["enemies"][0]) == 2, "A lit brazier supplies enemy turn-start Expose")
	brazier_state["guardian_braziers"][0]["lit"] = false
	_expect(engine.effective_light_sources(brazier_state).is_empty() and engine.enemy_turn_start_light_expose(brazier_state, brazier_state["enemies"][0]) == 0,
		"Snuff removes the brazier source and Expose coverage")
	brazier_state["guardian_braziers"][0]["lit"] = true
	_expect(engine.effective_light_sources(brazier_state).size() == 1 and engine.enemy_turn_start_light_expose(brazier_state, brazier_state["enemies"][0]) == 2,
		"Relight restores the brazier source and Expose coverage")

	var player_aura_state: Dictionary = state.duplicate(true)
	player_aura_state["player"]["pos"] = LIT_ENEMY + Vector2i.LEFT
	RiteRules.start(player_aura_state, "rite_of_noon", GameData.card_def("rite_of_noon"))
	_expect(engine.enemy_turn_start_light_expose(player_aura_state, player_aura_state["enemies"][0]) == 2, "Rite of Noon supplies Light around a living hero")
	player_aura_state["player"]["hp"] = 0
	_expect(engine.effective_light_sources(player_aura_state).is_empty() and engine.enemy_turn_start_light_expose(player_aura_state, player_aura_state["enemies"][0]) == 0,
		"A defeated hero ends the Rite of Noon aura")

	var illusion_state: Dictionary = state.duplicate(true)
	illusion_state["skill_ids"] = ["witchlight"]
	var illusion_tile: Vector2i = LIT_ENEMY + Vector2i.LEFT
	illusion_state["illusions"] = [{"id": 9, "pos": illusion_tile, "hp": 2, "max_hp": 2}]
	_expect(engine.enemy_turn_start_light_expose(illusion_state, illusion_state["enemies"][0]) == 2, "A living illusion aura supplies enemy turn-start Expose")
	var afterglow_state: Dictionary = illusion_state.duplicate(true)
	afterglow_state["skill_ids"].append("afterglow")
	illusion_state = engine._damage_illusion(illusion_state, 9, 2)
	_expect(engine.effective_light_sources(illusion_state).is_empty() and engine.enemy_turn_start_light_expose(illusion_state, illusion_state["enemies"][0]) == 0,
		"A defeated illusion ends the aura")
	afterglow_state = engine._damage_illusion(afterglow_state, 9, 2)
	afterglow_state = engine._tick_umbra_player_activation(afterglow_state)
	var afterglow_sources: Array[Dictionary] = engine.effective_light_sources(afterglow_state)
	_expect(afterglow_sources.size() == 1 and afterglow_sources[0]["pos"] == illusion_tile and int(afterglow_sources[0]["remaining_activations"]) == -1,
		"Afterglow places one lasting source when the illusion is removed")

func _check_ice_stagger_light(engine: EngineRules, state: Dictionary) -> void:
	var prepared: Dictionary = state.duplicate(true)
	var astrolabe: Dictionary = GameData.relics()["starless_astrolabe"]
	RiteRules.start(prepared, "status_light_fixture", {"rite": {"effects": astrolabe["effects"]}})
	var action: Dictionary = {"type": "melee", "element": "ice", "stagger": 6, "_card_id": "icebound_chains"}
	var without_vision: Dictionary = engine._apply_card_stagger(prepared.duplicate(true), 1, action)
	_expect(not engine._light_source_covers_tile(without_vision, LIT_ENEMY), "Ice Stagger alone leaves the Vision-gated effect inactive")
	var with_vision: Dictionary = engine._apply_umbra_vision(prepared, {"duration": 1})
	with_vision = engine._apply_card_stagger(with_vision, 1, action)
	_expect(engine._light_source_covers_tile(with_vision, LIT_ENEMY), "Ice Stagger with Vision creates Light through the status effect")

func _check_checkpoint_migration(engine: EngineRules, state: Dictionary) -> void:
	var top: Dictionary = state.duplicate(true)
	var checkpoint: Dictionary = state.duplicate(true)
	checkpoint["umbra"].erase("vision_activations")
	checkpoint["umbra"]["truesight_activations"] = 2
	checkpoint["umbra"]["light_sources"] = [{"pos": LIT_ENEMY, "radius": 1, "remaining_activations": 1}]
	var mixed: Dictionary = checkpoint.duplicate(true)
	mixed["umbra"]["vision_activations"] = 1
	var resume_marker: Dictionary = {"resume_enemy_phase": true}
	var run: Dictionary = Store._migrate_run_dictionary({
		"combat_state": top,
		"pending_combat_checkpoints": [{"state": checkpoint}, {"state": mixed}, resume_marker.duplicate()]
	})
	var pending: Array = run["pending_combat_checkpoints"]
	_expect(pending[2] == resume_marker, "Migration preserves the compact enemy-phase marker")
	for index: int in range(2):
		var resumed: Dictionary = pending[index]["state"]
		var umbra: Dictionary = resumed["umbra"]
		_expect(int(umbra["vision_activations"]) == 2 - index and not umbra.has("truesight_activations"),
			"Each checkpoint preserves the remaining Vision turns")
		_expect(int(umbra["light_sources"][0]["remaining_activations"]) == -1,
			"Checkpoint migration normalizes timed Light even when Vision is already present")
		_expect(engine.is_enemy_visible_to_player(resumed, resumed["enemies"][1]), "Vision works from the migrated checkpoint")

func _check_old_rite(engine: EngineRules, state: Dictionary) -> void:
	var saved: Dictionary = state.duplicate(true)
	var card: Dictionary = GameData.card_def("rite_of_noon")
	RiteRules.start(saved, "rite_of_noon", card)
	saved["active_rites"][0]["description"] = "Rite: you radiate radius-2 Light, and your attacks deal 2 more to enemies in Light."
	var unrelated: Dictionary = {"card_id": "other_rite", "effects": [], "description": ""}
	saved["active_rites"].append(unrelated)
	saved["active_rites"][0]["effects"].append({
		"type": "target_state_action_mod", "conditions": {"target_in_light": true}, "add": {"damage": 2}
	})
	var target: Vector2i = HERO + Vector2i.RIGHT
	saved["enemies"][0]["pos"] = target
	var attack: Dictionary = {"type": "melee", "range": 1, "damage": 3}
	var old_hit: Dictionary = EngineRules.new().apply_player_action(saved.duplicate(true), attack, target)
	var loaded: Dictionary = Store._migrate_run_dictionary({"combat_state": saved, "pending_combat_checkpoints": [{"state": saved.duplicate(true)}]})
	var migrated: Dictionary = loaded["combat_state"]
	var new_hit: Dictionary = engine.apply_player_action(migrated.duplicate(true), attack, target)
	var original_hp: int = int(state["enemies"][0]["hp"])
	var old_damage: int = original_hp - int(old_hit["enemies"][0]["hp"])
	var new_damage: int = original_hp - int(new_hit["enemies"][0]["hp"])
	_expect(old_damage == 5 and new_damage == 3,
		"Loaded Rite of Noon should change attack damage from 5 to 3 against a lit enemy, got %d to %d" % [old_damage, new_damage])
	_expect(migrated["active_rites"][0]["effects"] == card["rite"]["effects"] and migrated["active_rites"][1] == unrelated,
		"Rite migration preserves the Light aura and unrelated active Rites")
	_expect(migrated["active_rites"][0]["description"] == card["description"]
		and loaded["pending_combat_checkpoints"][0]["state"]["active_rites"] == migrated["active_rites"],
		"Rite migration refreshes the saved description and migrates queued copies")

func _check_thornwall(engine: EngineRules, state: Dictionary) -> void:
	var staged: Dictionary = state.duplicate(true)
	staged["player"]["pos"] = Vector2i(4, 4)
	staged["enemies"][0]["pos"] = Vector2i(5, 5)
	staged["enemies"][0]["type"] = "briar_weaver"
	RiteRules.start(staged, "rite_of_noon", GameData.card_def("rite_of_noon"))
	_expect(int(engine.enemy_threat_tiles(staged, 0).get("light_start_expose", 0)) == 2, "Board previews Expose for a lit enemy")
	staged["enemies"][0]["upheaval_pending"] = {
		"area_fixed": true, "marks": [Vector2i(4, 4)], "dials": {"health": 3}
	}
	var snapshot: Dictionary = staged.duplicate(true)
	_expect(int(engine.enemy_threat_tiles(staged, 0).get("light_start_expose", 0)) == 0, "Board previews Light after Thornwall displaces the hero")
	var next: Dictionary = _next_rail_enemy(engine, staged)
	_expect(not next.is_empty() and int(next.get("light_start_expose", 0)) == 0, "Next rail entry previews Light after Thornwall displacement")
	_expect(staged == snapshot, "Thornwall preview leaves combat and pending marks intact")
	var started: Dictionary = engine._resolve_enemy_start_of_turn(staged, 0)["state"]
	_expect(started["player"]["pos"] != snapshot["player"]["pos"] and int(started["enemies"][0].get("expose", 0)) == 0,
		"Enemy turn samples Expose after Thornwall moves the Light source")

func _check_intent_layout(engine: EngineRules, state: Dictionary) -> void:
	var board := Board.new()
	board.size = Vector2(1920, 1080)
	root.add_child(board)
	var actor_key: String = engine._enemy_key(state["enemies"][0])
	var base_rows: int = 0
	for amount: int in [0, 2, 0]:
		var shown: Dictionary = {
			"show_all_enemy_intents": true, "visible_enemy_ids": [1],
			"enemy_threat_previews": [{"enemy_key": actor_key, "light_start_expose": amount}]
		}
		board.set_combat_state(state, [], [], engine.INVALID_TILE, "", "", {}, {}, shown)
		var row_count: int = 0
		var displayed_light: bool = false
		for entry: Dictionary in board._hud_layout_entries_cache:
			if entry["actor_key"] != actor_key:
				continue
			var rows: Array = entry["layout"]["rows"]
			row_count = rows.size()
			displayed_light = _has_light_expose_row(rows)
		var inspection_light: bool = false
		for unit: Dictionary in board._visible_units():
			if board._enemy_hud_actor_key(unit) == actor_key:
				inspection_light = _has_light_expose_row(board._intent_rows_for_unit(unit, unit["intent"]))
				break
		if base_rows == 0:
			base_rows = row_count
		_expect(base_rows > 0 and row_count == base_rows and not displayed_light and inspection_light == (amount > 0),
			"Light Expose stays in inspection while the expanded intent shows the next move (%d)" % amount)
	board.free()

func _has_light_expose_row(rows: Array) -> bool:
	for row: Array in rows:
		if row.size() == 2 and row[0].get("icon") == "illuminate" and row[1].get("icon") == "expose":
			return true
	return false

func _next_rail_enemy(engine: EngineRules, state: Dictionary) -> Dictionary:
	for entry: Dictionary in engine.current_turn_order(state, REVIEW_ORDER_LIMIT):
		if int(entry.get("enemy_id", -1)) == 1 and bool(entry.get("next_enemy_turn", false)):
			return entry
	return {}

func _check_turn_order(engine: EngineRules, state: Dictionary) -> void:
	var lit: Dictionary = engine._create_umbra_light_source(state.duplicate(true), LIT_ENEMY, {"radius": 1})
	var turns: Array[Dictionary]
	for entry: Dictionary in engine.current_turn_order(lit, REVIEW_ORDER_LIMIT):
		if int(entry.get("enemy_id", -1)) == 1 and not bool(entry.get("active", false)):
			turns.append(entry)
	_expect(turns.size() >= 2, "Rail includes the next activation and a repeat turn for the lit enemy")
	if turns.size() < 2:
		return
	_expect(bool(turns[0].get("next_enemy_turn", false)) and int(turns[0].get("light_start_expose", 0)) == 2,
		"Rail forecasts Expose on the earliest upcoming enemy turn")
	_expect(not bool(turns[1].get("next_enemy_turn", false)) and not turns[1].has("light_start_expose"),
		"Rail omits Expose on the same enemy's repeat turn")
	var scene := Scene.new()
	scene._animation_lock = true
	for index: int in range(2):
		var slot: Control = Slots.update(scene, turns[index], index)
		var forecast: Array[Dictionary]
		forecast.append({"enemy_key": turns[index]["actor_key"], "light_start_expose": 2})
		slot.mouse_entered.emit()
		scene._apply_turn_order_light_hover(forecast)
		_expect(forecast[0].has("light_start_expose") == (index == 0), "Rail hover displays Light Expose only on the next enemy turn")
		slot.mouse_exited.emit()
		slot.free()
	scene.free()

func _check_last_eclipse(engine: EngineRules, state: Dictionary) -> void:
	var covered: Dictionary = engine._create_umbra_light_source(state.duplicate(true), HERO, {"radius": 1})
	covered = engine._apply_umbra_vision(covered, {"duration": 2})
	var attack: Dictionary = {"type": "umbra_eclipse", "damage": 8, "duration": 2, Areas.FIELD: [HERO]}
	var hit: Dictionary = engine._enemy_umbra_eclipse(covered.duplicate(true), 0, attack)
	covered["player"]["pos"] = HERO + Vector2i.RIGHT
	var escaped: Dictionary = engine._enemy_umbra_eclipse(covered, 0, attack)
	_expect(int(hit["player"]["hp"]) == 22 and int(escaped["player"]["hp"]) == 30,
		"Leaving the fixed marks avoids Last Eclipse damage, even after gaining Light and Vision")
	var copy: String = "This enemy hits you and your illusions on Marked tiles, then starts Eclipse for X turns."
	var token: Dictionary = Icons.tokens_for_action(attack)[-1]
	_expect(str(token.get("tooltip", "")) == copy.replace(" X ", " 2 ") and Icons.description("umbra_eclipse") == copy,
		"Last Eclipse tooltip and glossary describe fixed marks")

func _check_hero_aura(engine: EngineRules, state: Dictionary) -> void:
	var living: Dictionary = state.duplicate(true)
	RiteRules.start(living, "rite_of_noon", GameData.card_def("rite_of_noon"))
	living = engine._create_umbra_light_source(living, LIT_ENEMY, {"radius": 1})
	_expect(engine._light_source_covers_tile(living, HERO), "The living hero carries Rite of Noon Light")
	var dead: Dictionary = engine._damage_player(living, int(living["player"]["hp"]), true)
	var lights: Array[Dictionary] = engine.effective_light_sources(dead)
	_expect(int(dead["player"]["hp"]) == 0 and not engine._light_source_covers_tile(dead, HERO),
		"Rite of Noon Light stops covering tiles at 0 Health")
	_expect(lights.size() == 1 and lights[0]["pos"] == LIT_ENEMY and engine._light_source_covers_tile(dead, LIT_ENEMY),
		"Defeat removes only the hero's carried Light from the board")

func _check_card_play_analytics(engine: EngineRules, state: Dictionary) -> void:
	var actions: Array = GameData.card_def("prism_sight")["actions"]
	var after: Dictionary = engine._apply_umbra_vision(state.duplicate(true), actions[0])
	var targets: Array[Vector2i]
	var headless := Console.new()
	var scene := Scene.new()
	var console_payload: Dictionary = headless._card_play_payload("prism_sight", state, after, actions, targets)
	var live_payload: Dictionary = scene._analytics_card_play_payload("prism_sight", state, after, actions, targets)
	_expect(bool(live_payload["radiance_card"]) and console_payload.get("radiance_card") == live_payload["radiance_card"],
		"Headless and live analytics identify the Light/Vision cohort")
	_expect(int(live_payload["vision_enemies_revealed"]) == 2 and console_payload.get("vision_enemies_revealed") == live_payload["vision_enemies_revealed"],
		"Headless and live analytics count the same newly revealed enemies")
	headless.free()
	scene.free()

func _check_contextual_grimoire() -> void:
	var entries: Array[String] = Grimoire.entry_ids_for_card_def(GameData.card_def("seek_the_light"))
	_expect(entries.has("keyword:illuminate") and entries.has("keyword:blink"), "Seek the Light contextual Grimoire shows Light and Blink")

func _combat(engine: EngineRules) -> Dictionary:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if x in [0, 8] or y in [0, 8] else "stone")
		grid.append(row)
	var layout: Dictionary = {
		"type": "combat", "depth": 1, "element": "none", "umbra_stage": "eclipse",
		"grid": grid, "player_start": HERO, "terrain": [], "traps": [], "loot": [],
		"enemies": [
			{"id": 1, "type": "crawler", "pos": LIT_ENEMY, "hp": 20, "max_hp": 20},
			{"id": 2, "type": "crawler", "pos": HIDDEN_ENEMY, "hp": 20, "max_hp": 20},
		],
	}
	return engine.create_combat(COMBAT_SEED, layout, {"hp": 30, "max_hp": 30, "deck_cards": ["brace"], "hand_size": 1, "relics": []})

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
