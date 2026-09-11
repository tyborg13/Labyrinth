extends RefCounted

const CombatEngine = preload("res://scripts/combat_engine.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const SurfaceRelics = preload("res://scripts/surface_relic_rules.gd")
const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const ElementData = preload("res://scripts/element_data.gd")
const GameData = preload("res://scripts/game_data.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const RunScene = preload("res://scripts/run_scene.gd")

const NEW_RELIC_IDS := [
	"dawnbrand_filament",
	"glowstone_matrix",
	"briar_winch",
	"hourglass_awl",
	"beaconrunner_spurs",
	"true_north",
	"dawnstitch_cord",
	"starless_astrolabe",
	"witchglass_carapace",
	"witchglass_lantern",
	"sunlit_edge",
	"glassway_compass",
	"unclouded_sun"
]
const RARITY_TIERS := {
	"common": 1,
	"rare": 2,
	"epic": 3,
	"legendary": 4
}
const SUPPORTED_EFFECT_TYPES := [
  "blink_draw_once_per_turn",
  "blink_origin_illusion",
  "bloodied_glass_attack_bonus",
  "board_surface_types_reward",
  "card_action_mod",
  "card_append_action",
  "card_play_reward",
  "chain_hit_count_reward",
  "chain_swap_endpoints",
  "conductive_fire",
  "defiance_capacity",
  "defiance_trigger_reward",
  "end_turn_block_to_stoneskin",
  "enemy_death_reward",
  "first_card_attack_bonus",
  "freeze_relocate_ice",
  "frozen_kill_rubble",
  "illusion_damage_cap",
  "illusion_light_aura",
  "layered_surface_consumption_reward",
  "light_source_umbra_suppression",
  "long_move_card_play",
  "movement_end_reward",
  "movement_pool_bonus",
  "opening_draw_bonus",
  "overheal_to_stoneskin",
  "player_state_action_mod",
  "resolved_action_light",
  "resolved_action_surface",
  "rubble_attack_origin",
  "rubble_detonate",
  "rubble_redirect",
  "status_application_light",
  "status_count_reward",
  "stoneskin_melee_cross",
  "surface_conduction_reward",
  "surface_creation_reward",
  "target_state_action_mod",
  "transport_surface",
  "umbra_transition_reward"
]
static func run(expect: Callable) -> void:
	_test_complete_set_contract(expect)
	_test_conditional_card_mutations(expect)
	_test_new_common_and_rare_relics(expect)
	_test_new_epic_and_legendary_relics(expect)
	_test_spatial_radiance_relics(expect)
	_test_light_reveal_delta_equivalence(expect)
	_test_package_transforming_relics(expect)
	_test_radiance_offer_distribution(expect)
	_test_status_and_enemy_death_engines(expect)
	_test_surface_engines(expect)
	_test_defense_risk_and_mobility_engines(expect)
	_test_defiance_and_surface_transformations(expect)
	_test_state_sequence_bridges(expect)
	_test_damage_feedback_contract(expect)
	_test_player_facing_turn_terminology(expect)

static func _test_complete_set_contract(expect: Callable) -> void:
	var relics: Dictionary = GameData.relics()
	expect.call(relics.size() == 60, "The Radiance package redesign should contain exactly 60 relics")
	for relic_id: String in NEW_RELIC_IDS:
		expect.call(relics.has(relic_id), "New relic %s should be present" % relic_id)
	var radiance_count: int = 0
	var radiance_by_rarity: Dictionary = {"common": 0, "rare": 0, "epic": 0, "legendary": 0}
	var effect_types: Array[String]
	var forbidden_primary_effects: Array[String] = _string_array([
		"max_hp",
		"first_attack_bonus",
		"first_move_bonus",
		"combat_ember_bonus",
		"start_combat_block",
		"start_combat_stoneskin"
	])
	for relic_id_var: Variant in relics.keys():
		var relic_id: String = str(relic_id_var)
		var raw_relic: Dictionary = relics.get(relic_id, {}) as Dictionary
		var relic: Dictionary = GameData.relic_def(relic_id)
		var rarity: String = str(raw_relic.get("rarity", ""))
		if (raw_relic.get("build_tags", []) as Array).has("radiance"):
			radiance_count += 1
			radiance_by_rarity[rarity] = int(radiance_by_rarity.get(rarity, 0)) + 1
		var tier: int = int(RARITY_TIERS.get(rarity, 0))
		expect.call(int(raw_relic.get("design_version", 0)) >= 3, "%s should be migrated to the complete-set relic design version" % relic_id)
		expect.call(int(raw_relic.get("condition_tier", 0)) == tier, "%s conditionality should match its rarity tier" % relic_id)
		expect.call(int(raw_relic.get("upside_tier", 0)) == tier, "%s upside should match its rarity tier" % relic_id)
		expect.call((raw_relic.get("build_tags", []) as Array).size() >= 2, "%s should identify at least two build hooks" % relic_id)
		expect.call(str(raw_relic.get("accent", "")) == GameData.relic_rarity_accent(rarity), "%s should use its rarity accent" % relic_id)
		var description: String = str(relic.get("description", ""))
		expect.call(not description.contains("{") and not description.contains("}"), "%s should resolve every rules-text placeholder" % relic_id)
		expect.call(not description.is_empty() and description.length() <= 240, "%s should keep exact rules text within the relic choice copy budget" % relic_id)
		var icon_path: String = str(raw_relic.get("icon_path", ""))
		var image := Image.new()
		var load_error: Error = image.load(ProjectSettings.globalize_path(icon_path))
		expect.call(load_error == OK and image.get_width() == 96 and image.get_height() == 96 and image.get_format() in [Image.FORMAT_RGBA8, Image.FORMAT_RGBAF, Image.FORMAT_RGBAH], "%s should own a 96x96 RGBA icon" % relic_id)
		for effect_var: Variant in raw_relic.get("effects", []):
			if typeof(effect_var) != TYPE_DICTIONARY:
				continue
			var effect_type: String = str((effect_var as Dictionary).get("type", ""))
			expect.call(effect_type not in forbidden_primary_effects, "%s should not retain an unconditional flat-stat primary effect" % relic_id)
			if not effect_types.has(effect_type):
				effect_types.append(effect_type)
	effect_types.sort()
	var expected_effect_types: Array = SUPPORTED_EFFECT_TYPES.duplicate()
	expected_effect_types.sort()
	expect.call(effect_types == expected_effect_types, "Every live relic effect category should be intentionally covered by the focused suite")
	expect.call(radiance_count == 20, "Exactly one third of the 60-relic pool should meaningfully support Radiance")
	expect.call(radiance_by_rarity == {"common": 5, "rare": 9, "epic": 4, "legendary": 2}, "Radiance relics should preserve the reviewed 5/9/4/2 rarity mix")

static func _test_conditional_card_mutations(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var terrain_state: Dictionary = _state(combat, ["flint_edge", "venom_signet"])
	terrain_state["enemies"] = _two_enemies(Vector2i(3, 4), Vector2i(6, 2), 20)
	var plain: Dictionary = combat.call("_action_with_target_state_relic_modifiers", terrain_state, {"type": "melee", "damage": 3, "range": 1}, 0)
	expect.call(int(plain["damage"]) == 3, "Flint Edge and Quarry Signet need actual target terrain")
	Surface.place(terrain_state, Vector2i(3, 4), "fire")
	var burning_ground: Dictionary = combat.call("_action_with_target_state_relic_modifiers", terrain_state, {"type": "melee", "damage": 3, "range": 1}, 0)
	expect.call(int(burning_ground["damage"]) == 5, "Flint Edge enables only its own Fire condition")
	Surface.place(terrain_state, Vector2i(3, 4), "rubble")
	var layered: Dictionary = combat.call("_action_with_target_state_relic_modifiers", terrain_state, {"type": "melee", "damage": 3, "range": 1}, 0)
	expect.call(int(layered["damage"]) == 7, "Distinct Fire and Rubble target conditions may combine")
	_expect_action_delta(expect, "chain_bolt", "storm_capacitor", "ranged", "chain", 1)
	_expect_action_delta(expect, "gust_step", "tailwind_fletching", "pull", "damage", 1)
	_expect_action_delta(expect, "gust_step", "tailwind_fletching", "pull", "amount", 1)
	var awl_card: Dictionary = GameData.card_def_for_progression("bloody_lunge", {"relics": ["hourglass_awl"]})
	expect.call(bool(_first_action_of_type(awl_card, "melee").get("pierce", false)), "Hourglass Awl should add Pierce to attacks on 7+ Time cards")
	var glowstone_card: Dictionary = GameData.card_def_for_progression("spike_mantle", {"relics": ["glowstone_matrix"]})
	expect.call(int(_first_action_of_type(glowstone_card, "vision").get("duration", 0)) == 2, "Glowstone Matrix should append two-turn Vision to cards containing Stoneskin")
	var iron_wheel_with_boots: Dictionary = GameData.card_def_for_progression("iron_wheel", {"relics": ["pilgrim_boots"]})
	expect.call(
		int(_first_action_of_type(iron_wheel_with_boots, "move").get("range", 0)) == int(_first_action_of_type(GameData.card_def("iron_wheel"), "move").get("range", 0)),
		"Pilgrim Boots should leave move-and-attack cards to Duelist Whetstone"
	)
	var plain_stab: Dictionary = GameData.card_def_for_progression("quick_stab", {"relics": ["hourglass_awl", "glowstone_matrix"]})
	var plain_action: Dictionary = _first_action_of_type(plain_stab, "melee")
	var base_plain_action: Dictionary = _first_action_of_type(GameData.card_def("quick_stab"), "melee")
	expect.call(int(plain_action.get("damage", 0)) == int(base_plain_action.get("damage", 0)) and not bool(plain_action.get("pierce", false)), "Conditional card relics should leave cards without their required build traits unchanged")

static func _test_new_common_and_rare_relics(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var duelist_state: Dictionary = _state(combat, ["duelist_whetstone"])
	var duelist_card: Dictionary = GameData.card_def_for_progression("iron_wheel", {})
	var duelist_attack: Dictionary = _first_action_of_type(duelist_card, "melee")
	expect.call(combat.final_damage_for_player_action(duelist_state, duelist_attack) == 10, "Duelist Whetstone should add two damage to the first move-attack card")
	duelist_state = _trigger_card(combat, duelist_state, duelist_card, "iron_wheel")
	expect.call(combat.final_damage_for_player_action(duelist_state, duelist_attack) == 8, "Duelist Whetstone should apply only once per turn")

	var pin_state: Dictionary = _state(combat, ["hollow_die"])
	var pin_card: Dictionary = GameData.card_def("prism_sight")
	pin_state = _trigger_card(combat, pin_state, pin_card, "prism_sight")
	var pin_sources: Array = (pin_state.get("umbra", {}) as Dictionary).get("light_sources", []) as Array
	expect.call(
		pin_sources.size() == 1
		and (pin_sources[0] as Dictionary).get("pos", Vector2i.ZERO) == (pin_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
		and int((pin_sources[0] as Dictionary).get("remaining_activations", 0)) == 2,
		"Open-Eyed Pin should turn a Vision card into Light at the player for the same final duration"
	)

	var chorus_state: Dictionary = _state(combat, ["chorus_mask"])
	chorus_state["deck"] = _deck([], ["brace", "quick_stab"], [])
	chorus_state = _trigger_card(combat, chorus_state, _card(ElementData.FIRE, 3, [{"type": "block", "amount": 1}]), "chorus_fire")
	chorus_state = _trigger_card(combat, chorus_state, _card(ElementData.ICE, 3, [{"type": "block", "amount": 1}]), "chorus_ice")
	expect.call(
		int(chorus_state.get("card_play_bonus_this_turn", 0)) == 1
		and int((chorus_state.get("player", {}) as Dictionary).get("block", 0)) == 3,
		"Chorus Mask should turn a two-element sequence into usable tempo and defense"
	)

	var hourglass_state: Dictionary = _state(combat, ["hourglass_splinter"])
	hourglass_state = _trigger_card(combat, hourglass_state, _card("", 7, [{"type": "melee", "damage": 1}]), "hourglass")
	expect.call(int(hourglass_state.get("card_play_bonus_this_turn", 0)) == 1 and int((hourglass_state.get("player", {}) as Dictionary).get("block", 0)) == 4, "Hourglass Splinter should refund a high-Time card and add defense")

	var widow_state: Dictionary = _state(combat, ["widow_thread"])
	widow_state["illusions"] = [{"id": 99, "pos": Vector2i(3, 4), "hp": 2, "max_hp": 2}]
	var widow_attack: Dictionary = combat.call("_action_with_player_state_relic_modifiers", widow_state, {"type": "ranged", "damage": 3, "range": 4, "_card_action_types": ["ranged"]})
	expect.call(int(widow_attack.get("expose", 0)) == 1, "Widow Thread should make attacks expose while an illusion exists")
	var shield_state: Dictionary = _state(combat, ["reinforced_shield"])
	(shield_state.get("player", {}) as Dictionary)["stoneskin"] = 1
	var shield_action: Dictionary = combat.call("_action_with_player_state_relic_modifiers", shield_state, {"type": "block", "amount": 4, "_card_action_types": ["block"]})
	expect.call(int(shield_action.get("amount", 0)) == 7, "Reinforced Shield should improve Block actions while Stoneskin is active")

static func _test_new_epic_and_legendary_relics(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var funeral_state: Dictionary = _state(combat, ["funeral_bell"])
	funeral_state["damage_context"] = {"actor_kind": "player", "player_card": true, "source_kind": "direct_attack"}
	funeral_state["deck"] = _deck([], ["brace", "quick_stab", "bone_dart"], [])
	for index: int in range(3):
		funeral_state = combat.call("_trigger_enemy_death_relics", funeral_state, {"expose": 1, "hp": 0, "id": index})
	expect.call(((funeral_state.get("deck", {}) as Dictionary).get("hand", []) as Array).size() == 3 and int(funeral_state.get("card_play_bonus_this_turn", 0)) == 2, "Funeral Bell should pay only after a third statused death")
	var off_turn_funeral_state: Dictionary = _state(combat, ["funeral_bell"])
	off_turn_funeral_state["current_actor"] = {"kind": "enemy", "enemy_id": 1}
	off_turn_funeral_state["deck"] = _deck([], ["brace", "quick_stab", "bone_dart"], [])
	for index: int in range(3):
		off_turn_funeral_state = combat.call("_trigger_enemy_death_relics", off_turn_funeral_state, {"expose": 1, "hp": 0, "id": index})
	expect.call(
		int(off_turn_funeral_state.get("card_play_bonus_this_turn", 0)) == 0
		and int(off_turn_funeral_state.get("pending_relic_card_plays", 0)) == 0,
		"Funeral Bell must not bank card plays from passive enemy-turn deaths"
	)
	off_turn_funeral_state = combat.prepare_next_player_turn(off_turn_funeral_state)
	expect.call(
		int(off_turn_funeral_state.get("card_play_bonus_this_turn", 0)) == 0
		and int(off_turn_funeral_state.get("pending_relic_card_plays", -1)) == 0,
		"Passive deaths must not create a later Funeral Bell refund"
	)

	var chalice_state: Dictionary = _state(combat, ["bloodmoon_chalice"], 10, 24)
	chalice_state["deck"] = _deck([], ["brace", "quick_stab"], [])
	chalice_state = _trigger_card(combat, chalice_state, _card("", 6, [{"type": "melee", "damage": 4}], 1), "bloodmoon")
	expect.call(int((chalice_state.get("player", {}) as Dictionary).get("hp", 0)) == 15, "Bloodmoon Chalice should heal a bloodied health-cost build")
	expect.call(((chalice_state.get("deck", {}) as Dictionary).get("hand", []) as Array).size() == 2 and int(chalice_state.get("card_play_bonus_this_turn", 0)) == 1, "Bloodmoon Chalice should add draw and tempo at its risk threshold")

	var compass_state: Dictionary = _state(combat, ["moonless_compass"])
	compass_state["deck"] = _deck([], ["brace", "quick_stab"], [])
	compass_state = _trigger_card(combat, compass_state, _card(ElementData.AIR, 3, [{"type": "move", "range": 2}]), "compass_move")
	expect.call(int(compass_state.get("card_play_bonus_this_turn", 0)) == 0, "Moonless Compass should wait for the other half of its cross-card combo")
	compass_state = _trigger_card(combat, compass_state, _card(ElementData.FIRE, 4, [{"type": "illuminate", "radius": 2}]), "compass_light")
	expect.call(
		int((compass_state.get("player", {}) as Dictionary).get("stoneskin", 0)) == 6
		and int(compass_state.get("card_play_bonus_this_turn", 0)) == 2,
		"Moonless Compass should reward separate repositioning and Light cards in one turn"
	)

	var knot_state: Dictionary = _state(combat, ["fivefold_knot"])
	knot_state["deck"] = _deck([], ["brace", "quick_stab", "bone_dart", "brace", "quick_stab"], [])
	for element_id: String in ElementData.all_elements():
		knot_state = _trigger_card(combat, knot_state, _card(element_id, 3, [{"type": "block", "amount": 1}]), "knot_%s" % element_id)
	expect.call(((knot_state.get("deck", {}) as Dictionary).get("hand", []) as Array).size() == 5 and int(knot_state.get("card_play_bonus_this_turn", 0)) == 5, "Fivefold Knot should deliver a legendary payoff only after all five elements in one turn")

	var borrowed_state: Dictionary = _state(combat, ["borrowed_hourglass"])
	borrowed_state["deck"] = _deck([], ["brace", "quick_stab", "bone_dart", "brace"], [])
	borrowed_state = _trigger_card(combat, borrowed_state, _card("", 8, [{"type": "aoe", "damage": 4}]), "borrowed", true)
	expect.call(((borrowed_state.get("deck", {}) as Dictionary).get("hand", []) as Array).size() == 4 and int(borrowed_state.get("card_play_bonus_this_turn", 0)) == 3, "Borrowed Hourglass should turn a banked high-Time play into a mythic combo turn")

static func _test_spatial_radiance_relics(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var boots_state: Dictionary = _state(combat, ["pilgrim_boots"])
	boots_state = combat.apply_player_action(boots_state, {"type": "move", "range": 4, "_card_action_types": ["move"]}, Vector2i(5, 4))
	var boot_sources: Array = (boots_state.get("umbra", {}) as Dictionary).get("light_sources", []) as Array
	expect.call(boot_sources.size() == 3, "Pilgrim Boots should leave Light on every tile entered by a non-attack Move")
	var blink_boots_state: Dictionary = _state(combat, ["pilgrim_boots"])
	blink_boots_state = combat.apply_player_action(blink_boots_state, {"type": "blink", "range": 4, "_card_action_types": ["blink"]}, Vector2i(5, 4))
	expect.call(((blink_boots_state.get("umbra", {}) as Dictionary).get("light_sources", []) as Array).size() == 2, "Pilgrim Boots should light a Blink's origin and destination without inventing intermediate Blink tiles")
	var attack_move_state: Dictionary = _state(combat, ["pilgrim_boots"])
	attack_move_state = combat.apply_player_action(attack_move_state, {"type": "move", "range": 4, "_card_action_types": ["move", "melee"]}, Vector2i(4, 4))
	expect.call(((attack_move_state.get("umbra", {}) as Dictionary).get("light_sources", []) as Array).is_empty(), "Pilgrim Boots should not transform Move-and-attack cards")

	var filament_state: Dictionary = _state(combat, ["dawnbrand_filament"])
	filament_state["enemies"] = _two_enemies(Vector2i(4, 4), Vector2i(4, 2), 10)
	filament_state = combat.apply_player_action(filament_state, {"type": "ranged", "damage": 1, "range": 5, "_card_action_types": ["ranged"]}, Vector2i(4, 4))
	filament_state = combat.apply_player_action(filament_state, {"type": "ranged", "damage": 1, "range": 5, "_card_action_types": ["ranged"]}, Vector2i(4, 2))
	var filament_sources: Array = (filament_state.get("umbra", {}) as Dictionary).get("light_sources", []) as Array
	expect.call(filament_sources.size() == 1 and (filament_sources[0] as Dictionary).get("pos", Vector2i.ZERO) == Vector2i(4, 4), "Dawnbrand Filament should light only the first direct attack target each turn")

	var brightglass_state: Dictionary = _state(combat, ["ember_lens"])
	brightglass_state["enemies"] = _two_enemies(Vector2i(4, 4), Vector2i(5, 4), 10)
	brightglass_state = combat.apply_player_action(brightglass_state, {"type": "illuminate", "range": 5, "radius": 1, "duration": 2}, Vector2i(4, 4))
	brightglass_state = combat.apply_player_action(brightglass_state, {"type": "ranged", "damage": 2, "range": 5, "_card_action_types": ["ranged"]}, Vector2i(4, 4))
	expect.call(int(((brightglass_state.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0)) == 8 and int(((brightglass_state.get("enemies", []) as Array)[1] as Dictionary).get("hp", 0)) == 8, "Brightglass Lens should turn a ranged hit on an enemy in Light into Chain 1")

	var stormglass_state: Dictionary = _state(combat, ["voltaic_tuning_fork"])
	stormglass_state["enemies"] = _two_enemies(Vector2i(4, 4), Vector2i(5, 4), 10)
	stormglass_state = combat.apply_player_action(stormglass_state, {"type": "ranged", "damage": 1, "range": 5, "chain": 2, "_card_action_types": ["ranged"]}, Vector2i(4, 4))
	expect.call(((stormglass_state.get("umbra", {}) as Dictionary).get("light_sources", []) as Array).size() == 2, "Stormglass Beacon should create Light beneath every enemy hit by the first Chain attack")

	var noon_state: Dictionary = _state(combat, ["tectonic_abacus"])
	(noon_state.get("umbra", {}) as Dictionary)["stage"] = CombatEngine.UMBRA_STAGE_PRESSING
	for pos: Vector2i in [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)]:
		noon_state = combat.call("_create_umbra_light_source", noon_state, pos, {"radius": 1, "duration": 2, "silent": true})
	expect.call(combat.effective_umbra_stage(noon_state) == CombatEngine.UMBRA_STAGE_ADVANCING, "Captured Noon should suppress one Umbra stage at three active sources")
	for pos: Vector2i in [Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3)]:
		noon_state = combat.call("_create_umbra_light_source", noon_state, pos, {"radius": 1, "duration": 2, "silent": true})
	expect.call(combat.effective_umbra_stage(noon_state) == CombatEngine.UMBRA_STAGE_FRINGE, "Captured Noon should suppress two Umbra stages at six active sources")
	(noon_state.get("umbra", {}) as Dictionary)["light_sources"] = []
	expect.call(combat.effective_umbra_stage(noon_state) == CombatEngine.UMBRA_STAGE_PRESSING, "Captured Noon suppression should reverse immediately when its sources expire")

	var tether_state: Dictionary = _state(combat, ["witchglass_lantern", "tectonic_abacus"])
	(tether_state.get("umbra", {}) as Dictionary)["stage"] = CombatEngine.UMBRA_STAGE_PRESSING
	tether_state["illusions"] = [
		{"id": 41, "pos": Vector2i(2, 2), "hp": 2, "max_hp": 2},
		{"id": 42, "pos": Vector2i(4, 2), "hp": 2, "max_hp": 2},
		{"id": 43, "pos": Vector2i(6, 2), "hp": 2, "max_hp": 2}
	]
	expect.call(combat.effective_umbra_stage(tether_state) == CombatEngine.UMBRA_STAGE_ADVANCING, "Captured Noon should count tethered illusion Light as real active sources")
	expect.call(bool(combat.call("_light_source_covers_tile", tether_state, Vector2i(4, 4))), "Witchglass Lantern should provide real radius-two Light from a living illusion")
	var tethered_sources: Array[Dictionary] = combat.effective_light_sources(tether_state)
	var tooltip_board := CombatBoardView.new()
	var tethered_tooltip: String = tooltip_board.call("_tethered_light_tooltip", tethered_sources[0])
	expect.call(tethered_tooltip.contains("Witchglass Lantern: +2"), "A tethered Light tooltip should name the relic's additive contribution")
	tooltip_board.free()
	tether_state = combat._damage_illusion(tether_state, 42, 2)
	expect.call(not bool(combat.call("_light_source_covers_tile", tether_state, Vector2i(4, 4))), "Tethered Light should end immediately when its illusion is removed")

static func _test_light_reveal_delta_equivalence(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var limited_state: Dictionary = _state(combat, [])
	var limited_umbra: Dictionary = (limited_state.get("umbra", {}) as Dictionary).duplicate(true)
	limited_umbra["stage"] = CombatEngine.UMBRA_STAGE_DEEP
	limited_state["umbra"] = limited_umbra
	limited_state["enemies"] = [
		{"id": 11, "type": "crawler", "pos": Vector2i(6, 4), "hp": 10, "max_hp": 10, "footprint": Vector2i.ONE},
		{"id": 12, "type": "crawler", "pos": Vector2i(5, 6), "hp": 10, "max_hp": 10, "footprint": Vector2i(2, 2)},
	]
	limited_state = _expect_light_reveal_matches_generic(expect, combat, limited_state, Vector2i(6, 4), 1, "limited new source")
	limited_state = _expect_light_reveal_matches_generic(expect, combat, limited_state, Vector2i(6, 4), 3, "larger refreshed source")
	limited_state = _expect_light_reveal_matches_generic(expect, combat, limited_state, Vector2i(5, 5), 2, "overlapping source")

	var truesight_state: Dictionary = _state(combat, [])
	var truesight_umbra: Dictionary = (truesight_state.get("umbra", {}) as Dictionary).duplicate(true)
	truesight_umbra["stage"] = CombatEngine.UMBRA_STAGE_ECLIPSE
	truesight_umbra["truesight_activations"] = 2
	truesight_state["umbra"] = truesight_umbra
	truesight_state["enemies"] = limited_state.get("enemies", []).duplicate(true)
	_expect_light_reveal_matches_generic(expect, combat, truesight_state, Vector2i(6, 4), 2, "Truesight enemy visibility")

	var open_sky_state: Dictionary = _state(combat, [])
	open_sky_state["skill_ids"] = ["open_sky"]
	var open_sky_umbra: Dictionary = (open_sky_state.get("umbra", {}) as Dictionary).duplicate(true)
	open_sky_umbra["stage"] = CombatEngine.UMBRA_STAGE_DEEP
	open_sky_state["umbra"] = open_sky_umbra
	open_sky_state["enemies"] = limited_state.get("enemies", []).duplicate(true)
	var player_pos: Vector2i = (open_sky_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	_expect_light_reveal_matches_generic(expect, combat, open_sky_state, player_pos, 1, "Open Sky global Truesight transition")

	var suppression_state: Dictionary = _state(combat, ["tectonic_abacus"])
	var suppression_umbra: Dictionary = (suppression_state.get("umbra", {}) as Dictionary).duplicate(true)
	suppression_umbra["stage"] = CombatEngine.UMBRA_STAGE_DEEP
	suppression_umbra["light_sources"] = [
		{"id": 1, "pos": Vector2i(1, 1), "radius": 1, "remaining_activations": 2},
		{"id": 2, "pos": Vector2i(1, 6), "radius": 1, "remaining_activations": 2},
	]
	suppression_umbra["next_light_source_id"] = 3
	suppression_state["umbra"] = suppression_umbra
	suppression_state["enemies"] = limited_state.get("enemies", []).duplicate(true)
	_expect_light_reveal_matches_generic(expect, combat, suppression_state, Vector2i(6, 4), 1, "suppression-threshold source")

	var clear_state: Dictionary = _state(combat, [])
	var clear_umbra: Dictionary = (clear_state.get("umbra", {}) as Dictionary).duplicate(true)
	clear_umbra["stage"] = CombatEngine.UMBRA_STAGE_CLEAR
	clear_state["umbra"] = clear_umbra
	clear_state["enemies"] = limited_state.get("enemies", []).duplicate(true)
	_expect_light_reveal_matches_generic(expect, combat, clear_state, Vector2i(6, 4), 3, "unlimited-radius source")

static func _expect_light_reveal_matches_generic(
	expect: Callable,
	combat: CombatEngine,
	state: Dictionary,
	pos: Vector2i,
	radius: int,
	label: String
) -> Dictionary:
	var before_umbra: Dictionary = state.get("umbra", {}) as Dictionary
	var before_tile_lookup: Dictionary = {}
	for tile: Vector2i in combat.umbra_visible_tiles(state):
		before_tile_lookup[tile] = true
	var before_enemy_lookup: Dictionary = {}
	for enemy_id: int in combat.visible_enemy_ids(state, before_tile_lookup):
		before_enemy_lookup[enemy_id] = true
	var next_state: Dictionary = combat.call("_create_umbra_light_source", state, pos, {
		"radius": radius,
		"duration": 2,
		"silent": true,
	}) as Dictionary
	var after_tile_lookup: Dictionary = {}
	for tile: Vector2i in combat.umbra_visible_tiles(next_state):
		after_tile_lookup[tile] = true
	var expected_tiles: int = int(before_umbra.get("tiles_illuminated_total", 0))
	for tile_var: Variant in after_tile_lookup:
		if not before_tile_lookup.has(tile_var):
			expected_tiles += 1
	var expected_enemies: int = int(before_umbra.get("enemies_revealed_total", 0))
	for enemy_id: int in combat.visible_enemy_ids(next_state, after_tile_lookup):
		if not before_enemy_lookup.has(enemy_id):
			expected_enemies += 1
	var after_umbra: Dictionary = next_state.get("umbra", {}) as Dictionary
	expect.call(int(after_umbra.get("tiles_illuminated_total", 0)) == expected_tiles, "%s should match the generic visible-tile delta" % label)
	expect.call(int(after_umbra.get("enemies_revealed_total", 0)) == expected_enemies, "%s should match the generic visible-enemy delta" % label)
	return next_state

static func _test_package_transforming_relics(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var soles_state: Dictionary = _state(combat, ["static_soles"])
	soles_state = combat.apply_player_action(soles_state, {"type": "blink", "range": 3}, Vector2i(4, 4))
	expect.call(Surface.has_surface(soles_state, Vector2i(2, 4), "electrified") and int((soles_state.get("umbra", {}) as Dictionary).get("vision_bonus_activations", 0)) == 2, "Static Soles should leave a conductor at the movement origin and grant two-turn Vision")
	var mirror_state: Dictionary = _state(combat, ["mirror_shard"])
	mirror_state = _trigger_card(combat, mirror_state, GameData.card_def("mirror_feint"), "mirror_feint")
	expect.call(int(mirror_state.get("card_play_bonus_this_turn", 0)) == 1 and int((mirror_state.get("umbra", {}) as Dictionary).get("vision_bonus_activations", 0)) == 2, "Mirror Shard should bridge illusion cards into tempo and two-turn Vision")

	var thaw_state: Dictionary = _state(combat, ["thawing_charm"])
	thaw_state = combat.apply_player_action(thaw_state, {"type": "heal", "amount": 3})
	expect.call(int((thaw_state.get("player", {}) as Dictionary).get("stoneskin", 0)) == 3 and ((thaw_state.get("umbra", {}) as Dictionary).get("light_sources", []) as Array).size() == 1, "Thawing Charm should turn actual overheal conversion into Stoneskin and Light")

	var beacon_state: Dictionary = _state(combat, ["beaconrunner_spurs"])
	beacon_state = combat.apply_player_action(beacon_state, {"type": "illuminate", "range": 5, "radius": 1, "duration": 2}, Vector2i(4, 4))
	beacon_state = combat.apply_player_action(beacon_state, {"type": "move", "range": 3, "_card_action_types": ["move"]}, Vector2i(4, 4))
	expect.call(int(beacon_state.get("card_play_bonus_this_turn", 0)) == 1 and int((beacon_state.get("player", {}) as Dictionary).get("block", 0)) == 3, "Beaconrunner Spurs should reward movement that ends in existing Light")

	var north_state: Dictionary = _state(combat, ["true_north"])
	north_state = combat.apply_player_action(north_state, {"type": "truesight", "duration": 2})
	var north_action: Dictionary = combat.call("_resolved_surface_action", north_state, {"type": "ranged", "damage": 1, "range": 3, "_card_action_types": ["ranged"]})
	expect.call(int(north_action.get("range", 0)) == 4, "True North should transform ranged targeting while Truesight is active")

	var dawnstitch_state: Dictionary = _state(combat, ["dawnstitch_cord"])
	dawnstitch_state = _trigger_card(combat, dawnstitch_state, GameData.card_def("prism_sight"), "prism_sight")
	expect.call(int((dawnstitch_state.get("player", {}) as Dictionary).get("block", 0)) == 4, "Dawnstitch Cord should turn the first Radiance-action card into Block")

	var astrolabe_state: Dictionary = _state(combat, ["starless_astrolabe"])
	astrolabe_state["enemies"] = _two_enemies(Vector2i(4, 4), Vector2i(5, 4), 10)
	astrolabe_state = combat.apply_player_action(astrolabe_state, {"type": "truesight", "duration": 2})
	astrolabe_state = combat.apply_player_action(astrolabe_state, {"type": "aoe", "damage": 1, "range": 5, "pattern": [[0, 0], [1, 0]], "shock": 1, "element": "lightning", "_card_action_types": ["aoe"]}, Vector2i(4, 4))
	expect.call(((astrolabe_state.get("umbra", {}) as Dictionary).get("light_sources", []) as Array).size() == 2, "Starless Astrolabe should light every affected enemy of a Truesight Freeze or Shock attack")

	var carapace_state: Dictionary = _state(combat, ["witchglass_carapace"])
	carapace_state["illusions"] = [{"id": 61, "pos": Vector2i(3, 4), "hp": 3, "max_hp": 3}]
	carapace_state = combat.call("_damage_actor_target", carapace_state, {"kind": "illusion", "id": 61, "pos": Vector2i(3, 4)}, 5, false, {"type": "ranged"})
	expect.call(int(((carapace_state.get("illusions", []) as Array)[0] as Dictionary).get("hp", 0)) == 2, "Witchglass Carapace should cap ranged enemy damage to illusions at one")
	carapace_state = combat.call("_damage_actor_target", carapace_state, {"kind": "illusion", "id": 61, "pos": Vector2i(3, 4)}, 5, false, {"type": "melee"})
	expect.call(int(((carapace_state.get("illusions", []) as Array)[0] as Dictionary).get("hp", 0)) == 0, "Witchglass Carapace should leave melee enemy damage unchanged")

	var edge_state: Dictionary = _state(combat, ["sunlit_edge"])
	var edge_pos: Vector2i = (edge_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	edge_state = combat.apply_player_action(edge_state, {"type": "illuminate", "range": 5, "radius": 1, "duration": 2}, edge_pos)
	var edge_action: Dictionary = combat.call("_resolved_surface_action", edge_state, {"type": "melee", "damage": 2, "range": 1, "_card_action_types": ["melee"]})
	expect.call(bool(edge_action.get("pierce", false)), "Sunlit Edge should transform attacks into Pierce while the player stands in Light")

	var glassway_state: Dictionary = _state(combat, ["glassway_compass"])
	glassway_state = combat.apply_player_action(glassway_state, {"type": "blink", "range": 4, "_card_action_types": ["blink"]}, Vector2i(4, 4))
	glassway_state = combat.apply_player_action(glassway_state, {"type": "blink", "range": 4, "_card_action_types": ["blink"]}, Vector2i(5, 4))
	var glassway_illusions: Array = glassway_state.get("illusions", []) as Array
	expect.call(glassway_illusions.size() == 1 and int((glassway_illusions[0] as Dictionary).get("hp", 0)) == 2 and (glassway_illusions[0] as Dictionary).get("pos", Vector2i.ZERO) == Vector2i(2, 4), "Glassway Compass should create one two-health illusion at the first Blink origin each turn")

	var sun_state: Dictionary = _state(combat, ["unclouded_sun"])
	(sun_state.get("umbra", {}) as Dictionary)["stage"] = CombatEngine.UMBRA_STAGE_FRINGE
	sun_state["deck"] = _deck([], ["brace", "quick_stab", "bone_dart"], [])
	sun_state = combat.apply_player_action(sun_state, {"type": "dispel_umbra", "amount": 1})
	expect.call(int((sun_state.get("player", {}) as Dictionary).get("stoneskin", 0)) == 12 and ((sun_state.get("deck", {}) as Dictionary).get("hand", []) as Array).size() == 3 and int(sun_state.get("card_play_bonus_this_turn", 0)) == 3, "Unclouded Sun should pay once when authored Umbra first reaches Clear")

	var phoenix_state: Dictionary = _state(combat, ["phoenix_ember"], 2, 24)
	(phoenix_state.get("umbra", {}) as Dictionary)["stage"] = CombatEngine.UMBRA_STAGE_DEEP
	phoenix_state["defiance_capacity"] = 1
	phoenix_state["defiance_remaining"] = 1
	phoenix_state = combat.call("_damage_player", phoenix_state, 9, true)
	expect.call(int((phoenix_state.get("umbra", {}) as Dictionary).get("stage_reduction", 0)) == 2, "Phoenix Ember should add Dispel Umbra 2 to its existing Defiance comeback")

static func _test_radiance_offer_distribution(expect: Callable) -> void:
	var engine := RunEngine.new()
	var offers_with_radiance: int = 0
	var sample_count: int = 2000
	for sample: int in range(sample_count):
		var choices: Array = engine.call("_generate_relic_choices", {"seed": 7719, "relics": []}, Vector2i(sample % 100, sample / 100))
		var contains_radiance: bool = false
		for relic_id_var: Variant in choices:
			if (GameData.relic_def(str(relic_id_var)).get("build_tags", []) as Array).has("radiance"):
				contains_radiance = true
				break
		if contains_radiance:
			offers_with_radiance += 1
	var offer_rate: float = float(offers_with_radiance) / float(sample_count)
	expect.call(offer_rate >= 0.67 and offer_rate <= 0.75, "The weighted 60-relic pool should put Radiance in roughly 70%% of ordinary three-choice offers; observed %.2f%%" % (offer_rate * 100.0))

static func _test_status_and_enemy_death_engines(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var cold_state: Dictionary = _state(combat, ["cold_mirror"])
	cold_state = combat.call("_trigger_status_relics", cold_state, "freeze")
	expect.call(int((cold_state.get("player", {}) as Dictionary).get("stoneskin", 0)) == 0, "Cold Mirror should require block before Freeze")
	var cold_player: Dictionary = (cold_state.get("player", {}) as Dictionary).duplicate(true)
	cold_player["block"] = 8
	cold_state["player"] = cold_player
	cold_state = combat.call("_trigger_status_relics", cold_state, "freeze")
	expect.call(
		int((cold_state.get("player", {}) as Dictionary).get("block", 0)) == 2
		and int((cold_state.get("player", {}) as Dictionary).get("stoneskin", 0)) == 6,
		"Cold Mirror should convert up to six existing block on the first qualifying Freeze"
	)
	cold_state = combat.call("_trigger_status_relics", cold_state, "freeze")
	expect.call(int((cold_state.get("player", {}) as Dictionary).get("stoneskin", 0)) == 6, "Cold Mirror should trigger only once per turn")

	var ember_state: Dictionary = _state(combat, ["ember_siphon"], 10, 24)
	ember_state["enemies"] = _two_enemies(Vector2i(4, 4), Vector2i(6, 4), 2)
	Surface.place(ember_state, Vector2i(4, 4), "fire")
	ember_state = combat.apply_player_action(ember_state, {"type": "detonate", "damage": 3, "range": 5, "element": "fire"}, Vector2i(4, 4))
	expect.call(int(ember_state["player"]["hp"]) == 13, "Ember Siphon heals from a player-caused Detonate death")
	Surface.place(ember_state, Vector2i(6, 4), "fire")
	ember_state = combat.apply_player_action(ember_state, {"type": "detonate", "damage": 3, "range": 5, "element": "fire"}, Vector2i(6, 4))
	expect.call(int(ember_state["player"]["hp"]) == 13, "Ember Siphon pays only once per combat")

static func _test_surface_engines(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var tongs: Dictionary = _state(combat, ["cinderbrand_tongs"])
	tongs = combat.apply_player_action(tongs, {"type": "surface", "surface": "fire", "range": 4}, Vector2i(4, 4))
	var sources: Array = tongs["umbra"].get("light_sources", [])
	expect.call(sources.size() == 1 and sources[0]["pos"] == Vector2i(4, 4), "Cinderbrand Tongs lights the first tile actually changed to Fire")
	tongs = combat.apply_player_action(tongs, {"type": "surface", "surface": "fire", "range": 4}, Vector2i(5, 4))
	expect.call((tongs["umbra"].get("light_sources", []) as Array).size() == 1, "Cinderbrand Tongs is bounded once per turn")
	for conductor: String in ["electrified", "fire"]:
		var relic_ids: Array = ["ion_spool", "coalheart_crucible"] if conductor == "fire" else ["ion_spool"]
		var ion: Dictionary = _state(combat, relic_ids)
		ion["deck"] = _deck([], ["brace", "quick_stab", "pale_spark"], [])
		ion["enemies"] = _two_enemies(Vector2i(4, 4), Vector2i(5, 4), 10)
		Surface.place(ion, Vector2i(4, 4), conductor)
		Surface.place(ion, Vector2i(5, 4), conductor)
		ion = combat.apply_player_action(ion, {"type": "ranged", "damage": 1, "range": 5, "element": "lightning"}, Vector2i(4, 4))
		expect.call((ion["deck"]["hand"] as Array).size() == 1, "Ion Spool counts both native and hybrid conductive tiles")
		expect.call(Surface.has_surface(ion, Vector2i(4, 4), conductor) == (conductor == "electrified") and Surface.has_surface(ion, Vector2i(5, 4), conductor) == (conductor == "electrified"), "Lightning preserves Electrified and consumes Stormcoal Fire")
		Surface.place(ion, Vector2i(4, 4), conductor)
		Surface.place(ion, Vector2i(5, 4), conductor)
		ion = combat.apply_player_action(ion, {"type": "ranged", "damage": 1, "range": 5, "element": "lightning"}, Vector2i(4, 4))
		expect.call((ion["deck"]["hand"] as Array).size() == 1, "Ion Spool cannot loop its draw within a turn")
	var crown: Dictionary = _state(combat, ["storm_crown"])
	crown["deck"] = _deck([], ["brace", "quick_stab", "pale_spark", "brace"], [])
	crown["enemies"] = _two_enemies(Vector2i(3, 4), Vector2i(4, 4), 20)
	(crown["enemies"] as Array).append({"id": 3, "type": "crawler", "pos": Vector2i(5, 4), "hp": 20, "max_hp": 20})
	crown = combat.apply_player_action(crown, {"type": "ranged", "damage": 1, "range": 5, "chain": 1, "element": "lightning"}, Vector2i(3, 4))
	expect.call((crown["deck"]["hand"] as Array).size() == 2 and int(crown.get("card_play_bonus_this_turn", 0)) == 1, "Storm Crown rewards three distinct native Chain targets")
	crown = combat.apply_player_action(crown, {"type": "ranged", "damage": 1, "range": 5, "chain": 1, "element": "lightning"}, Vector2i(3, 4))
	expect.call((crown["deck"]["hand"] as Array).size() == 2 and int(crown.get("card_play_bonus_this_turn", 0)) == 1, "Storm Crown cannot form an unbounded play refund loop")
	var overflow: Dictionary = _state(combat, ["overflow_censer"])
	overflow["deck"] = _deck([], ["brace", "quick_stab", "pale_spark"], [])
	Surface.place(overflow, Vector2i(3, 4), "fire")
	Surface.place(overflow, Vector2i(4, 4), "rubble")
	overflow = combat.apply_player_action(overflow, {"type": "surface", "surface": "ice", "range": 4}, Vector2i(5, 4))
	expect.call(int(overflow["player"].get("stoneskin", 0)) == 6 and (overflow["deck"]["hand"] as Array).size() == 2, "Overflow Censer rewards three visible surface types once per combat")
	var black: Dictionary = _state(combat, ["black_sun_dial"])
	black["enemies"] = _two_enemies(Vector2i(4, 4), Vector2i(4, 3), 20)
	Surface.place(black, Vector2i(4, 4), "fire")
	Surface.place(black, Vector2i(4, 4), "rubble")
	black = combat.apply_player_action(black, {"type": "detonate", "damage": 1, "range": 5, "element": "fire"}, Vector2i(4, 4))
	expect.call(int(black["player"].get("stoneskin", 0)) == 6, "Black Sun Dial rewards spending an elemental surface over Rubble")
	expect.call(int(black["enemies"][0]["hp"]) == 13 and int(black["enemies"][1]["hp"]) == 13, "Black Sun Dial emits one local shared pulse in addition to the original blast")
	expect.call(Surface.has_surface(black, Vector2i(4, 4), "rubble"), "Black Sun Dial consumes the elemental layer and retains Rubble")

static func _test_defense_risk_and_mobility_engines(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var thaw_state: Dictionary = _state(combat, ["thawing_charm"], 24, 24)
	thaw_state = combat.apply_player_action(thaw_state, {"type": "heal", "amount": 5})
	thaw_state = combat.apply_player_action(thaw_state, {"type": "heal", "amount": 5})
	expect.call(int((thaw_state.get("player", {}) as Dictionary).get("stoneskin", 0)) == 8, "Thawing Charm should cap excess-heal conversion at eight stoneskin each turn")

	var glass_state: Dictionary = _state(combat, ["bloodglass_knife"], 12, 24)
	expect.call(combat.final_damage_for_player_action(glass_state, {"type": "melee", "damage": 2}) == 9, "Bloodglass Knife should add seven damage only at its full bloodied glass condition")
	var defended_player: Dictionary = (glass_state.get("player", {}) as Dictionary).duplicate(true)
	defended_player["block"] = 1
	glass_state["player"] = defended_player
	expect.call(combat.final_damage_for_player_action(glass_state, {"type": "melee", "damage": 2}) == 2, "Bloodglass Knife should turn off while any defense remains")

	var heart_state: Dictionary = _state(combat, ["obsidian_heart"])
	var heart_player: Dictionary = (heart_state.get("player", {}) as Dictionary).duplicate(true)
	heart_player["block"] = 6
	heart_state["player"] = heart_player
	heart_state = combat.finish_player_activation(heart_state)
	heart_player = heart_state.get("player", {}) as Dictionary
	expect.call(int(heart_player.get("block", 0)) == 0 and int(heart_player.get("stoneskin", 0)) == 6, "Obsidian Heart should carry remaining block into persistent stoneskin")

	var vault_state: Dictionary = _state(combat, ["vaulting_sigil"])
	vault_state = combat.call("_trigger_long_move_relics", vault_state, 3)
	expect.call(int(vault_state.get("card_play_bonus_this_turn", 0)) == 0, "Vaulting Sigil should ignore ordinary movement")
	vault_state = combat.call("_trigger_long_move_relics", vault_state, 4)
	expect.call(
		int(vault_state.get("card_play_bonus_this_turn", 0)) == 1
		and int((vault_state.get("player", {}) as Dictionary).get("block", 0)) == 4,
		"Vaulting Sigil should reward an achievable four-tile move with tempo and defense"
	)
	vault_state = combat.call("_trigger_blink_relics", vault_state, 4)
	expect.call(
		int(vault_state.get("card_play_bonus_this_turn", 0)) == 1
		and int((vault_state.get("player", {}) as Dictionary).get("block", 0)) == 4,
		"Vaulting Sigil should not retrigger from a later long Blink in the same turn"
	)
	var vault_blink_state: Dictionary = _state(combat, ["vaulting_sigil"])
	vault_blink_state = combat.call("_trigger_blink_relics", vault_blink_state, 4)
	expect.call(
		int(vault_blink_state.get("card_play_bonus_this_turn", 0)) == 1
		and int((vault_blink_state.get("player", {}) as Dictionary).get("block", 0)) == 4,
		"Vaulting Sigil should treat a four-tile Blink as a valid movement build payoff"
	)

	var gale_state: Dictionary = _state(combat, ["gale_tabi"])
	gale_state["deck"] = _deck([], ["brace", "quick_stab"], [])
	gale_state = combat.call("_trigger_blink_relics", gale_state, 2)
	expect.call(((gale_state.get("deck", {}) as Dictionary).get("hand", []) as Array).is_empty(), "Gale Tabi should ignore short blinks")
	gale_state = combat.call("_trigger_blink_relics", gale_state, 3)
	expect.call(
		((gale_state.get("deck", {}) as Dictionary).get("hand", []) as Array).size() == 1
		and int(gale_state.get("card_play_bonus_this_turn", 0)) == 1,
		"Gale Tabi should pair one drawn card with the play needed to use it"
	)
	var gale_fatigue_state: Dictionary = _state(combat, ["gale_tabi"], 10, 24)
	gale_fatigue_state["deck"] = _deck([], [], ["brace", "quick_stab"])
	gale_fatigue_state = combat.call("_trigger_blink_relics", gale_fatigue_state, 3)
	expect.call(
		int((gale_fatigue_state.get("player", {}) as Dictionary).get("hp", 0)) == 10
		and int((gale_fatigue_state.get("deck", {}) as Dictionary).get("cycles", 0)) == 0
		and ((gale_fatigue_state.get("deck", {}) as Dictionary).get("hand", []) as Array).is_empty(),
		"Gale Tabi's draw should stop before Fatigue even though its card play still resolves"
	)

static func _test_defiance_and_surface_transformations(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var phoenix_state: Dictionary = combat.create_combat(991, _room(), {
		"hp": 3,
		"max_hp": 24,
		"deck_cards": ["quick_stab", "brace", "bone_dart", "quick_stab"],
		"relics": ["phoenix_ember"],
		"hand_size": 1,
		"defiance_capacity": 1,
		"defiance_remaining": 1
	})
	phoenix_state["deck"] = _deck(["quick_stab"], ["brace", "bone_dart", "quick_stab"], [])
	phoenix_state = combat.call("_damage_player", phoenix_state, 9, true)
	expect.call(int((phoenix_state.get("player", {}) as Dictionary).get("hp", 0)) == 6 and int(phoenix_state.get("defiance_remaining", -1)) == 0, "Phoenix Ember should recover through its added Defiance")
	expect.call(Surface.has_surface(phoenix_state, Vector2i(5, 2), "fire") and int(phoenix_state["enemies"][0]["hp"]) == 100, "Phoenix Ember creates Fire beneath enemies without immediate placement damage")
	expect.call(((phoenix_state.get("deck", {}) as Dictionary).get("hand", []) as Array).size() == 4 and int(phoenix_state.get("card_play_bonus_this_turn", 0)) == 3, "Phoenix Ember should create a large comeback turn")
	var enemy_turn_phoenix_state: Dictionary = combat.create_combat(993, _room(), {
		"hp": 3,
		"max_hp": 24,
		"deck_cards": ["quick_stab", "brace", "bone_dart", "quick_stab"],
		"relics": ["phoenix_ember"],
		"hand_size": 1,
		"defiance_capacity": 1,
		"defiance_remaining": 1
	})
	enemy_turn_phoenix_state["current_actor"] = {"kind": "enemy", "enemy_id": 1}
	enemy_turn_phoenix_state["deck"] = _deck(["quick_stab"], ["brace", "bone_dart", "quick_stab"], [])
	enemy_turn_phoenix_state = combat.call("_damage_player", enemy_turn_phoenix_state, 9, true)
	expect.call(
		int(enemy_turn_phoenix_state.get("card_play_bonus_this_turn", 0)) == 0
		and int(enemy_turn_phoenix_state.get("pending_relic_card_plays", 0)) == 3,
		"Phoenix Ember should preserve its comeback plays when Defiance happens on an enemy turn"
	)
	enemy_turn_phoenix_state = combat.prepare_next_player_turn(enemy_turn_phoenix_state)
	expect.call(
		int(enemy_turn_phoenix_state.get("card_play_bonus_this_turn", 0)) == 3
		and int(enemy_turn_phoenix_state.get("pending_relic_card_plays", -1)) == 0,
		"Phoenix Ember should deliver all three comeback plays on the next player turn"
	)

	_test_surface_transformations(expect)

static func _test_surface_transformations(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var cross: Dictionary = _state(combat, ["thornmail_brooch"])
	cross["player"]["stoneskin"] = 4
	cross["enemies"] = _two_enemies(Vector2i(3, 4), Vector2i(3, 3), 20)
	cross = combat.apply_player_action(cross, {"type": "melee", "damage": 3, "range": 1, "_surface_relic_modes": ["cross"]}, Vector2i(3, 4))
	expect.call(int(cross["player"]["stoneskin"]) == 0 and int(cross["enemies"][0]["hp"]) == 17 and int(cross["enemies"][1]["hp"]) == 17, "Faultline Brooch spends defense to transform one melee strike into a cross")
	expect.call(Surface.has_surface(cross, Vector2i(3, 3), "rubble"), "Faultline Brooch leaves Rubble across its attack footprint")
	var transport: Dictionary = _state(combat, ["updraft_bottle"])
	transport["enemies"] = _two_enemies(Vector2i(3, 4), Vector2i(6, 2), 20)
	Surface.place(transport, Vector2i(3, 4), "fire")
	transport = combat.apply_player_action(transport, {"type": "push", "damage": 0, "amount": 1, "range": 2, "force_direction": Vector2i.RIGHT, "_surface_relic_modes": ["transport"]}, Vector2i(3, 4))
	expect.call(not Surface.has_surface(transport, Vector2i(3, 4), "fire") and Surface.has_surface(transport, Vector2i(4, 4), "fire"), "Updraft Bottle carries source terrain to the actual forced-movement endpoint")
	expect.call(int(transport["enemies"][0]["hp"]) == 20, "Carried Fire lands after movement and does not retroactively deal entry damage")
	var redirect: Dictionary = _state(combat, ["briar_winch"])
	redirect["enemies"] = _two_enemies(Vector2i(3, 4), Vector2i(6, 2), 20)
	Surface.place(redirect, Vector2i(3, 4), "rubble")
	redirect = combat.apply_player_action(redirect, {"type": "push", "damage": 0, "amount": 1, "range": 2, "force_direction": Vector2i.UP, "_surface_relic_modes": ["redirect"]}, Vector2i(3, 4))
	expect.call(redirect["enemies"][0]["pos"] == Vector2i(3, 3) and not Surface.has_surface(redirect, Vector2i(3, 4), "rubble"), "Quarry Winch spends target Rubble for a sideways displacement")
	var worldroot: Dictionary = _state(combat, ["worldroot_idol"])
	for tile: Vector2i in [Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4)]:
		Surface.place(worldroot, tile, "rubble")
	worldroot["enemies"] = _two_enemies(Vector2i(5, 4), Vector2i(6, 2), 20)
	worldroot = combat.apply_player_action(worldroot, {"type": "melee", "damage": 3, "range": 1, "_surface_relic_modes": ["remote"], "_origin_tile": Vector2i(4, 4)}, Vector2i(5, 4))
	expect.call(int(worldroot["enemies"][0]["hp"]) == 17 and not Surface.has_surface(worldroot, Vector2i(4, 4), "rubble"), "Worldroot Idol attacks through connected Rubble and consumes the remote origin")
	var kiln: Dictionary = _state(combat, ["basalt_calendar"])
	kiln["enemies"] = _two_enemies(Vector2i(4, 4), Vector2i(6, 2), 20)
	Surface.place(kiln, Vector2i(4, 4), "rubble")
	kiln = combat.apply_player_action(kiln, {"type": "detonate", "damage": 3, "range": 5, "element": "fire", "_surface_relic_modes": ["crush"]}, Vector2i(4, 4))
	expect.call(int(kiln["enemies"][0]["hp"]) == 17 and not Surface.has_surface(kiln, Vector2i(4, 4), "rubble") and Surface.has_surface(kiln, Vector2i(4, 4), "fire"), "Basalt Kiln turns consumed Rubble into a blast and fresh delayed Fire")
	var shatter: Dictionary = _state(combat, ["frost_prism"])
	shatter["enemies"] = _two_enemies(Vector2i(4, 4), Vector2i(6, 2), 4)
	shatter["enemies"][0]["freeze"] = 1
	shatter = combat.apply_player_action(shatter, {"type": "ranged", "damage": 2, "range": 5}, Vector2i(4, 4))
	expect.call(Surface.has_surface(shatter, Vector2i(4, 4), "rubble") and Surface.has_surface(shatter, Vector2i(4, 3), "rubble"), "Shatterglass Prism converts a direct Frozen kill into local Rubble")
	var rime: Dictionary = _state(combat, ["rimecatcher_vial"])
	rime["enemies"] = _two_enemies(Vector2i(4, 4), Vector2i(6, 2), 20)
	Surface.place(rime, Vector2i(4, 4), "ice")
	rime["enemies"][0]["chilled"] = true
	rime = combat.apply_player_action(rime, {"type": "ranged", "damage": 1, "range": 5, "element": "ice", "_ice_spill_direction": Vector2i.UP}, Vector2i(4, 4))
	expect.call(int(rime["enemies"][0].get("freeze", 0)) == 1 and not Surface.has_surface(rime, Vector2i(4, 4), "ice") and Surface.has_surface(rime, Vector2i(4, 3), "ice"), "Rimecatcher Vial redeploys one consumed Ice tile after a real Freeze")
	var swap: Dictionary = _state(combat, ["thunder_relay"])
	swap["enemies"] = _two_enemies(Vector2i(4, 4), Vector2i(5, 4), 20)
	swap = combat.apply_player_action(swap, {"type": "ranged", "damage": 1, "range": 5, "chain": 1, "element": "lightning", "_surface_relic_modes": ["swap"]}, Vector2i(4, 4))
	expect.call(swap["enemies"][0]["pos"] == Vector2i(5, 4) and swap["enemies"][1]["pos"] == Vector2i(4, 4), "Thunder Relay exchanges surviving native Chain endpoints after damage")

static func _test_state_sequence_bridges(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var anchor_state: Dictionary = _state(combat, ["anchor_chain"])
	var chain_catch: Dictionary = GameData.card_def_for_progression("chain_catch", {})
	var pull_action: Dictionary = _first_action_of_type(chain_catch, "pull")
	expect.call(combat.final_damage_for_player_action(anchor_state, pull_action) == 2, "Anchor Chain should stay dormant without prior block")
	var anchor_player: Dictionary = (anchor_state.get("player", {}) as Dictionary).duplicate(true)
	anchor_player["block"] = 1
	anchor_state["player"] = anchor_player
	var anchored_pull: Dictionary = combat.call("_resolved_surface_action", anchor_state, pull_action)
	expect.call(
		combat.final_damage_for_player_action(anchor_state, pull_action) == 4
		and int(anchored_pull.get("amount", 0)) == 3,
		"Anchor Chain should let a separate Block card empower later Push or Pull"
	)

	var coffin_state: Dictionary = _state(combat, ["coffin_nails"])
	var quick_stab: Dictionary = GameData.card_def_for_progression("quick_stab", {})
	var quick_attack: Dictionary = _first_action_of_type(quick_stab, "melee")
	expect.call(int((combat.call("_resolved_surface_action", coffin_state, quick_attack) as Dictionary).get("bleed", 0)) == 0, "Coffin Nails should require block")
	var coffin_player: Dictionary = (coffin_state.get("player", {}) as Dictionary).duplicate(true)
	coffin_player["block"] = 1
	coffin_state["player"] = coffin_player
	expect.call(int((combat.call("_resolved_surface_action", coffin_state, quick_attack) as Dictionary).get("bleed", 0)) == 1, "Coffin Nails should bridge existing block into Bleed attacks")

	var moss_state: Dictionary = _state(combat, ["mossbound_wraps"])
	moss_state = _trigger_card(combat, moss_state, _card(ElementData.EARTH, 4, [{"type": "melee", "damage": 3}]), "earth_without_block")
	expect.call(int((moss_state.get("player", {}) as Dictionary).get("stoneskin", 0)) == 0, "Mossbound Wraps should require a defended state")
	var moss_player: Dictionary = (moss_state.get("player", {}) as Dictionary).duplicate(true)
	moss_player["block"] = 2
	moss_state["player"] = moss_player
	moss_state = _trigger_card(combat, moss_state, _card(ElementData.EARTH, 4, [{"type": "melee", "damage": 3}]), "earth_with_block")
	expect.call(int((moss_state.get("player", {}) as Dictionary).get("stoneskin", 0)) == 3, "Mossbound Wraps should turn Block-then-Earth sequencing into persistent defense")
	for relic_order: Array in [
		["chorus_mask", "mossbound_wraps"],
		["mossbound_wraps", "chorus_mask"]
	]:
		var sequence_state: Dictionary = _state(combat, relic_order)
		sequence_state = _trigger_card(combat, sequence_state, _card(ElementData.FIRE, 3, [{"type": "melee", "damage": 1}]), "sequence_fire")
		sequence_state = _trigger_card(combat, sequence_state, _card(ElementData.EARTH, 3, [{"type": "melee", "damage": 1}]), "sequence_earth")
		expect.call(
			int((sequence_state.get("player", {}) as Dictionary).get("block", 0)) == 3
			and int((sequence_state.get("player", {}) as Dictionary).get("stoneskin", 0)) == 0,
			"Same-card relic rewards should not create conditions for another relic regardless of acquisition order"
		)

static func _test_damage_feedback_contract(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var scene := RunScene.new()
	var before: Dictionary = _state(combat, ["black_sun_dial"])
	before["enemies"] = _two_enemies(Vector2i(4, 4), Vector2i(4, 3), 20)
	Surface.place(before, Vector2i(4, 4), "fire")
	Surface.place(before, Vector2i(4, 4), "rubble")
	var after: Dictionary = combat.apply_player_action(before, {"type": "detonate", "damage": 1, "range": 5, "element": "fire"}, Vector2i(4, 4))
	var held: Dictionary = scene.call("_state_with_enemy_durability_from", after, before)
	expect.call(_enemy_durability(held, 1) == _enemy_durability(before, 1) and _enemy_durability(held, 2) == _enemy_durability(before, 2), "Surface blast presentation can hold exact pre-hit durability until impact")
	expect.call(Surface.element_at(held, Vector2i(4, 4)).is_empty() and Surface.has_rubble(held, Vector2i(4, 4)), "Holding durability preserves resolved terrain consumption")
	expect.call(int(after["enemies"][0]["hp"]) == 13 and int(after["enemies"][1]["hp"]) == 13, "The committed impact matches direct blast plus one local relic pulse")
	scene.free()

static func _floating_text_count(floating_texts: Array, expected_text: String) -> int:
	var count: int = 0
	for floating_text_var: Variant in floating_texts:
		if typeof(floating_text_var) != TYPE_DICTIONARY:
			continue
		if str((floating_text_var as Dictionary).get("text", "")) == expected_text:
			count += 1
	return count

static func _enemy_durability(state: Dictionary, enemy_id: int) -> Dictionary:
	for enemy_var: Variant in state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_var as Dictionary
		if int(enemy.get("id", -1)) != enemy_id:
			continue
		return {
			"hp": int(enemy.get("hp", 0)),
			"block": int(enemy.get("block", 0)),
			"stoneskin": int(enemy.get("stoneskin", 0))
		}
	return {}

static func _player_durability(state: Dictionary) -> Dictionary:
	var player: Dictionary = state.get("player", {})
	return {
		"hp": int(player.get("hp", 0)),
		"block": int(player.get("block", 0)),
		"stoneskin": int(player.get("stoneskin", 0))
	}

static func _test_player_facing_turn_terminology(expect: Callable) -> void:
	var relics: Dictionary = GameData.relics()
	for relic_id_var: Variant in relics.keys():
		var relic_id: String = str(relic_id_var)
		var relic: Dictionary = relics.get(relic_id, {}) as Dictionary
		var has_once_per_combat: bool = false
		for effect_var: Variant in relic.get("effects", []):
			if typeof(effect_var) == TYPE_DICTIONARY and str((effect_var as Dictionary).get("once", "")).begins_with("combat"):
				has_once_per_combat = true
				break
		if has_once_per_combat:
			expect.call(
				str(relic.get("description", "")).to_lower().contains("combat"),
				"%s should disclose its once-per-combat limit in player-facing copy" % relic_id
			)
	for data_path: String in [
		"res://data/cards.json",
		"res://data/relics.json",
		"res://data/skills.json",
		"res://data/grimoire.json"
	]:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
		expect.call(not _variant_contains_activation_copy(parsed), "%s should use turn terminology in player-facing strings" % data_path)
	for action: Dictionary in [
		{"type": "illuminate", "radius": 1, "duration": 2},
		{"type": "vision", "amount": 2, "duration": 2},
		{"type": "cinder_marks", "count": 3},
		{"type": "umbra_eclipse", "duration": 2}
	]:
		for token_var: Variant in ActionIcons.tokens_for_action(action):
			if typeof(token_var) != TYPE_DICTIONARY:
				continue
			expect.call(
				not ActionIcons.token_tooltip(token_var as Dictionary).to_lower().contains("activation"),
				"Action tooltips should describe duration in turns"
			)

static func _variant_contains_activation_copy(value: Variant) -> bool:
	match typeof(value):
		TYPE_STRING:
			return str(value).to_lower().contains("activation")
		TYPE_ARRAY:
			for child: Variant in value as Array:
				if _variant_contains_activation_copy(child):
					return true
		TYPE_DICTIONARY:
			for child: Variant in (value as Dictionary).values():
				if _variant_contains_activation_copy(child):
					return true
	return false

static func _expect_action_delta(expect: Callable, card_id: String, relic_id: String, action_type: String, field: String, expected_delta: int) -> void:
	var base_action: Dictionary = _first_action_of_type(GameData.card_def(card_id), action_type)
	var modified_action: Dictionary = _first_action_of_type(GameData.card_def_for_progression(card_id, {"relics": [relic_id]}), action_type)
	expect.call(int(modified_action.get(field, 0)) - int(base_action.get(field, 0)) == expected_delta, "%s should modify %s's %s %s by %d" % [relic_id, card_id, action_type, field, expected_delta])

static func _first_action_of_type(card: Dictionary, action_type: String) -> Dictionary:
	for action_var: Variant in card.get("actions", []):
		if typeof(action_var) == TYPE_DICTIONARY and str((action_var as Dictionary).get("type", "")) == action_type:
			return action_var as Dictionary
	return {}

static func _trigger_card(combat: CombatEngine, state: Dictionary, card: Dictionary, card_id: String, used_banked_play: bool = false) -> Dictionary:
	return combat.call("_trigger_card_play_relics", state, card, card_id, {"play_mode": "play"}, "discard", used_banked_play, int(state.get("cards_played_this_turn", 0)))

static func _card(element_id: String, time_cost: int, actions: Array, health_cost: int = 0, burn_card: bool = false) -> Dictionary:
	return {
		"name": "Relic Test Card",
		"element": element_id,
		"time": time_cost,
		"health_cost": health_cost,
		"burn": burn_card,
		"actions": actions.duplicate(true)
	}

static func _two_enemies(first_pos: Vector2i, second_pos: Vector2i, hp: int) -> Array[Dictionary]:
	var result: Array[Dictionary]
	result.append({"id": 1, "type": "crawler", "pos": first_pos, "hp": hp, "max_hp": hp, "block": 0, "stoneskin": 0})
	result.append({"id": 2, "type": "crawler", "pos": second_pos, "hp": hp, "max_hp": hp, "block": 0, "stoneskin": 0})
	return result

static func _state(combat: CombatEngine, relics: Array, hp: int = 24, max_hp: int = 24) -> Dictionary:
	return combat.create_combat(990, _room(), {
		"hp": hp,
		"max_hp": max_hp,
		"deck_cards": ["quick_stab"],
		"relics": relics,
		"hand_size": 1,
		"heal_bonus": 0
	})

static func _deck(hand: Array, draw: Array, discard: Array) -> Dictionary:
	return {
		"hand": hand.duplicate(),
		"draw": draw.duplicate(),
		"discard": discard.duplicate(),
		"burned": [],
		"consumed": [],
		"cycles": 0,
		"fatigue_base": CombatEngine.FATIGUE_BASE_DAMAGE
	}

static func _room() -> Dictionary:
	var grid: Array = []
	for y: int in range(8):
		var row: Array[String]
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return {
		"name": "Relic Test Room",
		"coord": Vector2i(1, 0),
		"depth": 1,
		"type": "combat",
		"element": ElementData.NONE,
		"grid": grid,
		"player_start": Vector2i(2, 4),
		"enemies": [{"id": 1, "type": "crawler", "pos": Vector2i(5, 2), "hp": 100, "max_hp": 100, "block": 0}],
		"loot": [],
		"traps": []
	}

static func _string_array(values: Array) -> Array[String]:
	var result: Array[String]
	for value_var: Variant in values:
		result.append(str(value_var))
	return result

static func _int_values(values: Array) -> Array[int]:
	var result: Array[int]
	for value_var: Variant in values:
		result.append(int(value_var))
	return result
