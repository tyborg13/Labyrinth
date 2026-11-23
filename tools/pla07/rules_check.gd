extends SceneTree

const Rites = preload("res://scripts/rite_rules.gd")
const Retaliate = preload("res://scripts/retaliate_rules.gd")
const Tempo = preload("res://scripts/tempo_rules.gd")
const Mirrors = preload("res://scripts/illusion_relic_rules.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Data = preload("res://scripts/game_data.gd")
const Glossary = preload("res://scripts/glossary.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const Store = preload("res://scripts/progression_store.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Fixture = preload("res://tests/suites/en01_enemies_suite.gd")
const HERO_TILE := Vector2i(3, 4)
const ENEMY_TILE := Vector2i(4, 4)
const FIXTURE_HP: int = 30
const SLIP_TARGET_BLOCK: int = 6
const SLIP_EXPOSE_CASES: Array = [0, 2]
const NAILS_BLOCK_CASES: Array = [0, 4, 5]
const CALTROPS_EXISTING_EXPOSE: int = 3
const ARCHIVED_RUN := "user://pla07_legacy.save"

const INTENTS := {
	"crawler": ["skitter_strike", 1, 5],
	"harrier": ["pelt", 0, 5],
	"tharokh": ["worldspine_claw", 1, 15],
	"vaeloryx": ["razor_dive", 1, 7],
	"gallows_roc": ["grave_dive", 1, 9],
	"craghide": ["crushing_rush", 1, 8],
	"briar_weaver": ["lash_of_thorns", 0, 4],
	"gust_shrike": ["talon_rake", 1, 4],
}

var _checks: int = 0
var _failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Runtime.apply_from_environment()
	_check_data()
	_check_legacy_save()
	_check_serrated_slip()
	_check_caltrops()
	_check_caltrops_and_next_attack()
	_check_status_only_echo()
	_check_enemy_hit_and_coffin_nails()
	print("PLA07 RULES: %d checks, %d failures" % [_checks, _failures])
	print("TEST RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)

func _check_data() -> void:
	for filename: String in ["cards", "enemies", "relics", "card_faces", "card_panel_text", "glossary", "grimoire", "pattern_rule_text", "sfx_cues"]:
		var content: String = FileAccess.get_file_as_string("res://data/%s.json" % filename)
		var retired := RegEx.create_from_string("(?i)\\b(bleed|bleeding|sunder)\\b")
		_expect(not content.is_empty() and retired.search(content) == null, "%s has no retired combat terms" % filename)
	for term: String in ["bleed", "sunder"]:
		_expect(not Icons.KEYWORDS.has(term), "%s absent from live icon registry" % term)
		_expect(Glossary.lookup(term).is_empty(), "%s absent from glossary" % term)
		_expect(not Grimoire.entry_map().has("keyword:" + term), "%s absent from Grimoire" % term)
	var enemies: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	for id: String in INTENTS:
		var expected: Array = INTENTS[id]
		var intent: Dictionary = _intent(enemies[id]["intents"], expected[0])
		var action: Dictionary = intent["actions"][expected[1]]
		_expect(int(action["damage"]) == int(expected[2]), "%s %s attack gains exactly 1 damage" % [id, expected[0]])
		var badge: Dictionary = Badges.descriptor(action, intent)
		_expect(str(badge["number"]) == str(expected[2]) and str(badge["secondary_icon"]) not in ["bleed", "sunder"], "%s renders the revised strike" % intent["name"])

func _check_legacy_save() -> void:
	var save: Dictionary = {
		"mode": "combat",
		"combat_units_schema": 1,
		"combat_state": {
			"player": {"bleed": 3, "sunder": 2, "expose": 4, "hp": FIXTURE_HP},
			"enemies": [{"id": 1, "type": "crawler", "bleed": 2, "expose": 1, "intent": {
				"id": "skitter_strike", "actions": [{"type": "move_toward", "range": 2}, {"type": "melee", "damage": 6, "bleed": 1}],
			}}],
			"player_bleed_loss_totals": {"hp": 2},
			"active_rites": [{
				"card_id": "thorn_crown_pact", "name": "Thorn Crown Pact",
				"description": "Rite: enemies that hit you in melee take 3 and Bleed 1.",
				"effects": [{"type": "thorns", "damage": 3, "bleed": 1}],
			}],
		},
		"analytics_events": [{"payload": {"sunder_actions": 1, "bleed": 2}}],
	}
	Store.set_run_storage_path(ARCHIVED_RUN)
	var file := FileAccess.open(ARCHIVED_RUN, FileAccess.WRITE)
	file.store_var(save)
	file.close()
	var restored: Dictionary = Store.load_saved_run()
	_expect(not restored.is_empty(), "legacy save loads through the checkpoint reader")
	var combat: Dictionary = restored.get("combat_state", {})
	var player: Dictionary = combat.get("player", {})
	var enemies: Array = combat.get("enemies", [])
	_expect(not player.has("bleed") and not player.has("sunder") and int(player.get("expose", 0)) == 4, "migration drops retired hero statuses and preserves Expose")
	_expect(not combat.has("player_bleed_loss_totals"), "migration clears retired runtime receipts")
	if not enemies.is_empty():
		var enemy: Dictionary = enemies[0]
		var strike: Dictionary = enemy["intent"]["actions"][1]
		_expect(not enemy.has("bleed") and int(enemy.get("expose", 0)) == 1, "migration drops retired enemy statuses and preserves Expose")
		_expect(not strike.has("bleed") and int(strike["damage"]) == 6 + Data.fixed_point_amount(1), "migration folds rider into held scaled attack")
		_expect(Store._migrate_run_dictionary(restored.duplicate(true)) == restored and int(strike["damage"]) == 6 + Data.fixed_point_amount(1), "migration is idempotent")
	var fresh: Dictionary = {"retaliate": {"amount": 4}}
	Rites.start(fresh, "thorn_crown_pact", Data.card_def("thorn_crown_pact"))
	combat["retaliate"] = {"amount": 4}
	_expect(Retaliate.totals(combat, Rites.effects(combat))["amount"] == 8, "Saved Thorn Crown Pact and Barbed Mail total 8 Retaliate")
	_expect(Rites.hud_entries(combat) == Rites.hud_entries(fresh), "Saved Thorn Crown Pact uses the current Rite tooltip")
	_expect(restored.get("analytics_events", []) == save["analytics_events"], "retired fields remain readable in saved event history")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ARCHIVED_RUN))

func _check_serrated_slip() -> void:
	var engine := Combat.new()
	var cents: int = Data.fixed_point_amount(1)
	for expose: int in SLIP_EXPOSE_CASES:
		var state: Dictionary = _state()
		state["enemies"][0]["block"] = SLIP_TARGET_BLOCK * cents
		state["enemies"][0]["expose"] = expose * cents
		var action: Dictionary = engine.card_play_actions("serrated_slip", state)[1]
		var expected: int = (3 if expose == 0 else 9) * cents
		var preview: Dictionary = engine.surface_preview_for_player_action(state, action, ENEMY_TILE)
		var hits: Array = preview["chain_hits"]
		var predicted: Dictionary = preview["state"]["enemies"][0]
		var resolved: Dictionary = engine.apply_player_action(state, action, ENEMY_TILE)["enemies"][0]
		_expect(hits.size() == 1 and int(hits[0].get("damage", 0)) == expected, "Serrated Slip preview shows one combined hit with starting Expose %d" % expose)
		_expect(predicted == resolved, "Serrated Slip preview agrees with the resolver")
		_expect(int(resolved["block"]) == maxi(0, SLIP_TARGET_BLOCK * cents - expected) and int(resolved["hp"]) == FIXTURE_HP * cents - maxi(0, expected - SLIP_TARGET_BLOCK * cents), "Serrated Slip spends Block once using the combined damage")
		_expect(int(resolved["expose"]) == 3 * cents, "Serrated Slip applies fresh Expose after the hit")

func _check_caltrops() -> void:
	var engine := Combat.new()
	var state: Dictionary = _state()
	state["enemies"][0]["expose"] = CALTROPS_EXISTING_EXPOSE
	var action: Dictionary = engine.card_play_actions("caltrops", state)[0]
	var resolved: Dictionary = engine.apply_player_action(state, action, ENEMY_TILE)
	var enemy: Dictionary = resolved["enemies"][0]
	_expect(int(enemy["hp"]) == FIXTURE_HP and int(enemy["expose"]) == CALTROPS_EXISTING_EXPOSE, "Caltrops preserves existing Expose without dealing a hit")

func _play(engine: RefCounted, state: Dictionary, card_id: String, target: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	state["deck"]["hand"] = [card_id]
	var result: Dictionary = engine.prepare_player_card(state, 0)
	for action: Dictionary in engine.card_play_actions(card_id, result):
		result = engine.apply_player_action(result, action, target)
	return engine.finish_player_card(result, 0)

func _check_caltrops_and_next_attack() -> void:
	var engine := Combat.new()
	var state: Dictionary = _play(engine, _state(), "sworn_oath")
	var before: Array = Tempo.next_attack_buffs(state).duplicate(true)
	state = _play(engine, state, "caltrops", ENEMY_TILE)
	_expect(not before.is_empty() and Tempo.next_attack_buffs(state) == before, "Caltrops preserves the Sworn Oath pool")
	state = _play(engine, state, "cleaver_hook", ENEMY_TILE)
	_expect(int(state["enemies"][0]["hp"]) == FIXTURE_HP - 11, "Cleaver Hack deals 6 base, 3 from Sworn Oath and 2 from Expose")
	_expect(Tempo.next_attack_buffs(state).is_empty(), "Cleaver Hack spends the preserved bonus")

func _check_status_only_echo() -> void:
	var engine := Combat.new()
	var state: Dictionary = _state()
	state["relics"] = ["mirror_triptych"]
	state["deck"]["hand"] = ["caltrops"]
	state = engine._create_illusion(state, ENEMY_TILE + Vector2i.UP, 3)
	state = engine.prepare_player_card(state, 0)
	var action: Dictionary = engine.card_play_actions("caltrops", state)[0]
	var resolved: Dictionary = engine.apply_player_action(state, action, ENEMY_TILE)
	var trace: Dictionary = {"echoes": []}
	var forecast: Dictionary = Mirrors.finish_echoes(engine, resolved.duplicate(true), trace)
	var committed: Dictionary = engine.finish_player_card(resolved, 0)
	_expect(trace["echoes"].size() == 1 and trace["echoes"][0]["choice"]["action"].get("status_only", false), "Mirror Triptych forecasts a status-only echo")
	_expect(committed["enemies"] == forecast["enemies"] and int(committed["enemies"][0]["hp"]) == FIXTURE_HP and int(committed["enemies"][0]["expose"]) == 2, "Caltrops echo preserves Health and Expose in forecast and commit")
	_expect(int(committed["illusions"][0]["hp"]) == 2, "Mirror Triptych pays the ordinary one-Health echo cost")

func _check_enemy_hit_and_coffin_nails() -> void:
	var engine := Combat.new()
	var cents: int = Data.fixed_point_amount(1)
	for block: int in NAILS_BLOCK_CASES:
		var state: Dictionary = _state()
		state["relics"] = ["coffin_nails"]
		state["player"]["block"] = block * cents
		var intent: Dictionary = _intent(Data.enemy_def("crawler")["intents"], "skitter_strike")
		var result: Dictionary = engine._resolve_enemy_action(state, 0, intent["actions"][1])
		_expect(int(result["player"]["hp"]) == (FIXTURE_HP - (5 - block)) * cents and int(result["player"]["block"]) == 0, "Skitter Strike deals 5 through ordinary Block %d" % block)
		_expect(int(result["enemies"][0].get("expose", 0)) == (2 * cents if block == 5 else 0), "Coffin Nails Exposes for 2 only when Block stops all Health loss")

func _state() -> Dictionary:
	var state: Dictionary = Fixture.fixture(["crawler"])
	var hp: int = Data.fixed_point_amount(FIXTURE_HP)
	state["current_actor"] = {"kind": "player", "key": "player"}
	state["player"].merge({"pos": HERO_TILE, "hp": hp, "max_hp": hp}, true)
	state["enemies"][0].merge({"pos": ENEMY_TILE, "hp": hp, "max_hp": hp}, true)
	return state

func _intent(intents: Array, id: String) -> Dictionary:
	for intent: Dictionary in intents:
		if intent["id"] == id:
			return intent
	return {}

func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)
