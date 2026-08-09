extends RefCounted

const CombatEngine = preload("res://scripts/combat_engine.gd")
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
	"bloodied_glass_attack_bonus",
	"blink_draw_once_per_turn",
	"blink_intensity_gain_once_per_turn",
	"blink_origin_illusion",
	"card_action_mod",
	"card_append_action",
	"card_play_reward",
	"damage_vs_status",
	"defiance_capacity",
	"defiance_trigger_reward",
	"end_turn_block_to_stoneskin",
	"enemy_death_reward",
	"first_card_attack_bonus",
	"illusion_damage_cap",
	"illusion_light_aura",
	"intensity_threshold_reward",
	"light_source_umbra_suppression",
	"long_move_card_play",
	"movement_end_reward",
	"opening_draw_bonus",
	"overheal_to_stoneskin",
	"player_state_action_mod",
	"resolved_action_light",
	"start_combat_stoneskin_per_deck_element",
	"status_count_reward",
	"status_intensity_gain",
	"stoneskin_intensity_gain_once_per_turn",
	"stoneskin_thorns",
	"target_state_action_mod",
	"umbra_transition_reward"
]

static func run(expect: Callable) -> void:
	_test_complete_set_contract(expect)
	_test_conditional_card_mutations(expect)
	_test_new_common_and_rare_relics(expect)
	_test_new_epic_and_legendary_relics(expect)
	_test_spatial_radiance_relics(expect)
	_test_package_transforming_relics(expect)
	_test_radiance_offer_distribution(expect)
	_test_status_and_enemy_death_engines(expect)
	_test_intensity_engines(expect)
	_test_defense_risk_and_mobility_engines(expect)
	_test_defiance_and_mono_earth_payoffs(expect)
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
		expect.call(int(raw_relic.get("design_version", 0)) == 2, "%s should be migrated to the complete-set relic design version" % relic_id)
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
	expect.call(radiance_by_rarity == {"common": 6, "rare": 8, "epic": 4, "legendary": 2}, "Radiance relics should preserve the approved 6/8/4/2 rarity mix")

static func _test_conditional_card_mutations(expect: Callable) -> void:
	_expect_action_delta(expect, "threaded_path", "pilgrim_boots", "move", "range", 1)
	_expect_action_delta(expect, "hearth_rush", "flint_edge", "melee", "burn", 2)
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
	expect.call(combat.final_damage_for_player_action(duelist_state, duelist_attack) == 12, "Duelist Whetstone should add two damage to the first move-attack card")
	duelist_state = _trigger_card(combat, duelist_state, duelist_card, "iron_wheel")
	expect.call(combat.final_damage_for_player_action(duelist_state, duelist_attack) == 10, "Duelist Whetstone should apply only once per turn")

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
	funeral_state["deck"] = _deck([], ["brace", "quick_stab", "bone_dart"], [])
	for index: int in range(3):
		funeral_state = combat.call("_trigger_enemy_death_relics", funeral_state, {"burn": 1, "hp": 0, "id": index})
	expect.call(((funeral_state.get("deck", {}) as Dictionary).get("hand", []) as Array).size() == 3 and int(funeral_state.get("card_play_bonus_this_turn", 0)) == 2, "Funeral Bell should pay only after a third statused death")
	var off_turn_funeral_state: Dictionary = _state(combat, ["funeral_bell"])
	off_turn_funeral_state["current_actor"] = {"kind": "enemy", "enemy_id": 1}
	off_turn_funeral_state["deck"] = _deck([], ["brace", "quick_stab", "bone_dart"], [])
	for index: int in range(3):
		off_turn_funeral_state = combat.call("_trigger_enemy_death_relics", off_turn_funeral_state, {"burn": 1, "hp": 0, "id": index})
	expect.call(
		int(off_turn_funeral_state.get("card_play_bonus_this_turn", 0)) == 0
		and int(off_turn_funeral_state.get("pending_relic_card_plays", 0)) == 2,
		"Funeral Bell should hold enemy-turn card plays for the next player turn"
	)
	off_turn_funeral_state = combat.prepare_next_player_turn(off_turn_funeral_state)
	expect.call(
		int(off_turn_funeral_state.get("card_play_bonus_this_turn", 0)) == 2
		and int(off_turn_funeral_state.get("pending_relic_card_plays", -1)) == 0,
		"Funeral Bell should deliver exactly two held plays on the next player turn"
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

static func _test_package_transforming_relics(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var soles_state: Dictionary = _state(combat, ["static_soles"])
	soles_state = _trigger_card(combat, soles_state, GameData.card_def("static_pivot"), "static_pivot")
	expect.call(combat.elemental_intensity(soles_state, ElementData.LIGHTNING) == 1 and int((soles_state.get("umbra", {}) as Dictionary).get("vision_bonus_activations", 0)) == 2, "Static Soles should bridge Lightning mobility into intensity and two-turn Vision")
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
	var north_action: Dictionary = combat.call("_action_with_intensity_bonus", north_state, {"type": "ranged", "damage": 1, "range": 3, "_card_action_types": ["ranged"]})
	expect.call(int(north_action.get("range", 0)) == 5, "True North should transform ranged targeting while Truesight is active")

	var dawnstitch_state: Dictionary = _state(combat, ["dawnstitch_cord"])
	dawnstitch_state = _trigger_card(combat, dawnstitch_state, GameData.card_def("prism_sight"), "prism_sight")
	expect.call(int((dawnstitch_state.get("player", {}) as Dictionary).get("block", 0)) == 4, "Dawnstitch Cord should turn the first Radiance-action card into Block")

	var astrolabe_state: Dictionary = _state(combat, ["starless_astrolabe"])
	astrolabe_state["enemies"] = _two_enemies(Vector2i(4, 4), Vector2i(5, 4), 10)
	astrolabe_state = combat.apply_player_action(astrolabe_state, {"type": "truesight", "duration": 2})
	astrolabe_state = combat.call("_trigger_resolved_action_light", astrolabe_state, {"type": "aoe", "damage": 1, "shock": 1, "_card_action_types": ["aoe"]}, Vector2i(4, 4), _int_values([0, 1]))
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
	var edge_action: Dictionary = combat.call("_action_with_intensity_bonus", edge_state, {"type": "melee", "damage": 2, "range": 1, "_card_action_types": ["melee"]})
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

	var thunder_state: Dictionary = _state(combat, ["thunder_relay"])
	thunder_state["elemental_intensity"] = _intensities({ElementData.LIGHTNING: 1})
	thunder_state = combat.call("_trigger_status_relics", thunder_state, "shock")
	expect.call(int(((thunder_state.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0)) == 100, "Thunder Relay should require its Lightning setup")
	thunder_state["elemental_intensity"] = _intensities({ElementData.LIGHTNING: 2})
	thunder_state = combat.call("_trigger_status_relics", thunder_state, "shock")
	expect.call(int(((thunder_state.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0)) == 97, "Thunder Relay should discharge on the first feasible Shock each turn")
	thunder_state = combat.call("_trigger_status_relics", thunder_state, "shock")
	expect.call(int(((thunder_state.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0)) == 97, "Thunder Relay should discharge only once per turn")
	for relic_order: Array in [
		["ion_spool", "thunder_relay"],
		["thunder_relay", "ion_spool"]
	]:
		var relay_state: Dictionary = _state(combat, relic_order)
		relay_state["elemental_intensity"] = _intensities({ElementData.LIGHTNING: 1})
		relay_state = combat.call("_trigger_status_relics", relay_state, "shock")
		expect.call(
			combat.elemental_intensity(relay_state, ElementData.LIGHTNING) == 2
			and int(((relay_state.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0)) == 97,
			"Status intensity should resolve before status conditions regardless of relic acquisition order"
		)

	var ember_state: Dictionary = _state(combat, ["ember_siphon"], 10, 24)
	ember_state = combat.call("_trigger_enemy_death_relics", ember_state, {"burn": 2, "hp": 0})
	expect.call(int((ember_state.get("player", {}) as Dictionary).get("hp", 0)) == 13 and combat.elemental_intensity(ember_state, ElementData.FIRE) == 1, "Ember Siphon should convert a burning execute into healing and Fire intensity")
	ember_state = combat.call("_trigger_enemy_death_relics", ember_state, {"burn": 2, "hp": 0})
	expect.call(int((ember_state.get("player", {}) as Dictionary).get("hp", 0)) == 13 and combat.elemental_intensity(ember_state, ElementData.FIRE) == 1, "Ember Siphon should heal only once per combat")

static func _test_intensity_engines(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var cinder_state: Dictionary = _state(combat, ["cinderbrand_tongs"])
	cinder_state["elemental_intensity"] = _intensities({ElementData.FIRE: 0})
	var cinder_attack: Dictionary = {"type": "ranged", "damage": 3, "range": 5, "burn": 2}
	cinder_state = combat.call("_trigger_status_relics", cinder_state, "burn", cinder_attack)
	cinder_state = combat.call("_trigger_resolved_action_light", cinder_state, cinder_attack, Vector2i(5, 2), _int_values([0]))
	expect.call(
		combat.elemental_intensity(cinder_state, ElementData.FIRE) == 1
		and ((cinder_state.get("umbra", {}) as Dictionary).get("light_sources", []) as Array).size() == 1,
		"Cinderbrand Tongs should turn the first attack-applied Burn into Fire intensity and target Light"
	)

	var ion_state: Dictionary = _state(combat, ["ion_spool"])
	ion_state["elemental_intensity"] = _intensities({ElementData.LIGHTNING: 3})
	ion_state = combat.call("_trigger_status_relics", ion_state, "shock")
	expect.call(
		combat.elemental_intensity(ion_state, ElementData.LIGHTNING) == 2
		and int(((ion_state.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0)) == 96,
		"Ion Spool should cash out its Shock loop as an all-enemy discharge"
	)
	var frozen_ion_state: Dictionary = _state(combat, ["ion_spool"])
	frozen_ion_state["elemental_intensity"] = _intensities({ElementData.LIGHTNING: 3})
	var frozen_enemies: Array = (frozen_ion_state.get("enemies", []) as Array).duplicate(true)
	var frozen_enemy: Dictionary = (frozen_enemies[0] as Dictionary).duplicate(true)
	frozen_enemy["freeze"] = 1
	frozen_enemies[0] = frozen_enemy
	frozen_ion_state["enemies"] = frozen_enemies
	frozen_ion_state = combat.call("_trigger_status_relics", frozen_ion_state, "shock")
	expect.call(
		int(((frozen_ion_state.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0)) == 92,
		"Relic discharge damage should intentionally retain the cross-package Frozen damage multiplier"
	)

	var overflow_state: Dictionary = _state(combat, ["overflow_censer"])
	overflow_state["elemental_intensity"] = _intensities({ElementData.FIRE: 3, ElementData.ICE: 3, ElementData.LIGHTNING: 2})
	overflow_state = combat.apply_player_action(overflow_state, {"type": "intensity", "element": ElementData.LIGHTNING, "amount": 1})
	expect.call(int((overflow_state.get("player", {}) as Dictionary).get("stoneskin", 0)) == 12 and int(overflow_state.get("card_play_bonus_this_turn", 0)) == 2, "Overflow Censer should require three simultaneous intensity thresholds and pay in persistent defense")
	var off_turn_overflow_state: Dictionary = _state(combat, ["overflow_censer"])
	off_turn_overflow_state["current_actor"] = {"kind": "enemy", "enemy_id": 1}
	off_turn_overflow_state["elemental_intensity"] = _intensities({ElementData.FIRE: 3, ElementData.ICE: 3, ElementData.LIGHTNING: 2})
	off_turn_overflow_state = combat.apply_player_action(off_turn_overflow_state, {"type": "intensity", "element": ElementData.LIGHTNING, "amount": 1})
	expect.call(
		int(off_turn_overflow_state.get("card_play_bonus_this_turn", 0)) == 0
		and int(off_turn_overflow_state.get("pending_relic_card_plays", 0)) == 2,
		"Enemy-turn intensity threshold rewards should hold their card plays"
	)
	off_turn_overflow_state = combat.prepare_next_player_turn(off_turn_overflow_state)
	expect.call(
		int(off_turn_overflow_state.get("card_play_bonus_this_turn", 0)) == 2
		and int(off_turn_overflow_state.get("pending_relic_card_plays", -1)) == 0,
		"Held intensity-threshold plays should arrive on the next player turn"
	)

	var black_state: Dictionary = _state(combat, ["black_sun_dial"])
	var final_element: String = ElementData.EARTH
	black_state["elemental_intensity"] = _intensities({
		ElementData.FIRE: 2,
		ElementData.ICE: 2,
		ElementData.LIGHTNING: 2,
		ElementData.AIR: 2,
		final_element: 1
	})
	black_state["deck"] = _deck([], ["brace", "quick_stab", "bone_dart"], [])
	black_state = combat.apply_player_action(black_state, {"type": "intensity", "element": final_element, "amount": 1})
	var black_enemy: Dictionary = (black_state.get("enemies", []) as Array)[0]
	expect.call(int(black_enemy.get("hp", 0)) == 88, "Black Sun Dial should deal its 12-damage five-element payoff")
	for element_id: String in ElementData.all_elements():
		expect.call(combat.elemental_intensity(black_state, element_id) == 0, "Black Sun Dial should consume two from every qualifying element")
	expect.call(
		((black_state.get("deck", {}) as Dictionary).get("hand", []) as Array).size() == 3
		and int(black_state.get("card_play_bonus_this_turn", 0)) == 3
		and int((black_state.get("player", {}) as Dictionary).get("stoneskin", 0)) == 12,
		"Black Sun Dial should supply a dramatic but usable continuation turn"
	)

	var nested_intensity_state: Dictionary = _state(combat, ["black_sun_dial", "ember_siphon"], 20, 24)
	nested_intensity_state["elemental_intensity"] = _intensities({
		ElementData.FIRE: 2,
		ElementData.ICE: 2,
		ElementData.LIGHTNING: 2,
		ElementData.AIR: 2,
		ElementData.EARTH: 1
	})
	nested_intensity_state["deck"] = _deck([], ["brace", "quick_stab", "bone_dart"], [])
	var nested_enemies: Array = (nested_intensity_state.get("enemies", []) as Array).duplicate(true)
	var burning_enemy: Dictionary = (nested_enemies[0] as Dictionary).duplicate(true)
	burning_enemy["hp"] = 12
	burning_enemy["burn"] = 1
	nested_enemies[0] = burning_enemy
	nested_intensity_state["enemies"] = nested_enemies
	nested_intensity_state = combat.apply_player_action(nested_intensity_state, {"type": "intensity", "element": ElementData.EARTH, "amount": 1})
	expect.call(
		combat.elemental_intensity(nested_intensity_state, ElementData.FIRE) == 1,
		"Intensity threshold costs should resolve before rewards so nested payoff intensity is preserved"
	)

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

	var thorn_state: Dictionary = _state(combat, ["thornmail_brooch"])
	var thorn_player: Dictionary = (thorn_state.get("player", {}) as Dictionary).duplicate(true)
	thorn_player["pos"] = Vector2i(4, 4)
	thorn_state["player"] = thorn_player
	var enemies: Array = (thorn_state.get("enemies", []) as Array).duplicate(true)
	var adjacent_enemy: Dictionary = (enemies[0] as Dictionary).duplicate(true)
	adjacent_enemy["pos"] = Vector2i(5, 4)
	enemies[0] = adjacent_enemy
	thorn_state["enemies"] = enemies
	thorn_state = combat.apply_player_action(thorn_state, {"type": "stoneskin", "amount": 10})
	expect.call(int(((thorn_state.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0)) == 95, "Thornmail Brooch should deal half the stoneskin gained to adjacent enemies")

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

static func _test_defiance_and_mono_earth_payoffs(expect: Callable) -> void:
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
	expect.call(int(((phoenix_state.get("enemies", []) as Array)[0] as Dictionary).get("burn", 0)) == 6, "Phoenix Ember should burn every enemy for six")
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

	var earth_cards: Array[String]
	for index: int in range(6):
		earth_cards.append("venom_claw")
	var worldroot_state: Dictionary = combat.create_combat(992, _room(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": earth_cards,
		"relics": ["worldroot_idol"],
		"hand_size": 1
	})
	expect.call(int((worldroot_state.get("player", {}) as Dictionary).get("stoneskin", 0)) == 12, "Worldroot Idol should scale gradually at two stoneskin per Earth card")
	expect.call(combat.elemental_intensity(worldroot_state, ElementData.EARTH) == 0, "Worldroot Idol should not bypass Earth setup at combat start")
	worldroot_state = combat.apply_player_action(worldroot_state, {"type": "stoneskin", "amount": 4})
	expect.call(combat.elemental_intensity(worldroot_state, ElementData.EARTH) == 1, "Worldroot Idol should bridge active Stoneskin gain into Earth intensity")
	worldroot_state = combat.apply_player_action(worldroot_state, {"type": "stoneskin", "amount": 2})
	expect.call(combat.elemental_intensity(worldroot_state, ElementData.EARTH) == 1, "Worldroot Idol should raise Earth intensity only once per turn")

	for earth_count: int in [2, 3, 6, 9]:
		var calendar_cards: Array[String]
		for index: int in range(earth_count):
			calendar_cards.append("venom_claw")
		var calendar_state: Dictionary = combat.create_combat(1000 + earth_count, _room(), {
			"hp": 24,
			"max_hp": 24,
			"deck_cards": calendar_cards,
			"relics": ["basalt_calendar"],
			"hand_size": 1
		})
		expect.call(
			combat.elemental_intensity(calendar_state, ElementData.EARTH) == 0,
			"Basalt Calendar should never skip Earth setup at combat start"
		)
		calendar_state = _trigger_card(combat, calendar_state, _card(ElementData.EARTH, 4, [{"type": "melee", "damage": 3}]), "calendar_first_earth")
		var expected_intensity: int = mini(2, earth_count / 3)
		expect.call(
			combat.elemental_intensity(calendar_state, ElementData.EARTH) == expected_intensity
			and int((calendar_state.get("player", {}) as Dictionary).get("stoneskin", 0)) == mini(6, earth_count),
			"Basalt Calendar should reward every Earth card while capping its progressive intensity"
		)
		calendar_state = _trigger_card(combat, calendar_state, _card(ElementData.EARTH, 4, [{"type": "melee", "damage": 3}]), "calendar_second_earth")
		expect.call(
			combat.elemental_intensity(calendar_state, ElementData.EARTH) == expected_intensity,
			"Basalt Calendar should grant its progressive intensity only once per combat"
		)
	var live_calendar_state: Dictionary = combat.create_combat(1013, _room(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["venom_claw", "venom_claw", "venom_claw"],
		"relics": ["basalt_calendar"],
		"hand_size": 1
	})
	live_calendar_state["deck"] = _deck(["venom_claw"], ["venom_claw", "venom_claw"], [])
	live_calendar_state = combat.finish_player_card(live_calendar_state, 0)
	expect.call(
		combat.elemental_intensity(live_calendar_state, ElementData.EARTH) == 1
		and int((live_calendar_state.get("player", {}) as Dictionary).get("stoneskin", 0)) == 3,
		"Basalt Calendar should count the real triggering Earth card after it enters discard"
	)
	var carry_state: Dictionary = combat.create_combat(994, _room(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"skill_ids": ["carry_the_guard"],
		"relics": ["worldroot_idol"],
		"hand_size": 1
	})
	var carry_player: Dictionary = (carry_state.get("player", {}) as Dictionary).duplicate(true)
	carry_player["block"] = 4
	carry_state["player"] = carry_player
	carry_state = combat.arm_carry_the_guard(carry_state)
	carry_state = combat.finish_player_activation(carry_state)
	expect.call(
		int((carry_state.get("player", {}) as Dictionary).get("stoneskin", 0)) == 4
		and combat.elemental_intensity(carry_state, ElementData.EARTH) == 1,
		"Carry the Guard should announce its Stoneskin gain to Worldroot Idol"
	)

static func _test_state_sequence_bridges(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var anchor_state: Dictionary = _state(combat, ["anchor_chain"])
	var chain_catch: Dictionary = GameData.card_def_for_progression("chain_catch", {})
	var pull_action: Dictionary = _first_action_of_type(chain_catch, "pull")
	expect.call(combat.final_damage_for_player_action(anchor_state, pull_action) == 3, "Anchor Chain should stay dormant without prior block")
	var anchor_player: Dictionary = (anchor_state.get("player", {}) as Dictionary).duplicate(true)
	anchor_player["block"] = 1
	anchor_state["player"] = anchor_player
	var anchored_pull: Dictionary = combat.call("_action_with_intensity_bonus", anchor_state, pull_action)
	expect.call(
		combat.final_damage_for_player_action(anchor_state, pull_action) == 5
		and int(anchored_pull.get("amount", 0)) == 3,
		"Anchor Chain should let a separate Block card empower later Push or Pull"
	)

	var coffin_state: Dictionary = _state(combat, ["coffin_nails"])
	var quick_stab: Dictionary = GameData.card_def_for_progression("quick_stab", {})
	var quick_attack: Dictionary = _first_action_of_type(quick_stab, "melee")
	expect.call(int((combat.call("_action_with_intensity_bonus", coffin_state, quick_attack) as Dictionary).get("bleed", 0)) == 0, "Coffin Nails should require block")
	var coffin_player: Dictionary = (coffin_state.get("player", {}) as Dictionary).duplicate(true)
	coffin_player["block"] = 1
	coffin_state["player"] = coffin_player
	expect.call(int((combat.call("_action_with_intensity_bonus", coffin_state, quick_attack) as Dictionary).get("bleed", 0)) == 1, "Coffin Nails should bridge existing block into Bleed attacks")

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
	var intensity_action: Dictionary = {"type": "intensity", "element": ElementData.LIGHTNING, "amount": 1}
	var ion_before: Dictionary = _state(combat, ["ion_spool"])
	ion_before["elemental_intensity"] = _intensities({ElementData.LIGHTNING: 3})
	var ion_enemies: Array = (ion_before.get("enemies", []) as Array).duplicate(true)
	var defended_enemy: Dictionary = (ion_enemies[0] as Dictionary).duplicate(true)
	defended_enemy["id"] = 2
	defended_enemy["pos"] = Vector2i(4, 2)
	defended_enemy["block"] = 2
	ion_enemies.append(defended_enemy)
	ion_before["enemies"] = ion_enemies
	var ion_after: Dictionary = combat.apply_player_action(ion_before, intensity_action)
	var ion_presentation: Dictionary = scene.call(
		"_secondary_player_action_enemy_loss_presentation",
		ion_before,
		ion_after,
		"static_lash",
		intensity_action,
		[]
	) as Dictionary
	expect.call(
		(ion_presentation.get("impact_actor_keys", []) as Array).size() == 2,
		"Ion Spool should mark every discharged enemy for the standard hit reaction"
	)
	var ion_floats: Array = ion_presentation.get("floating_texts", [])
	expect.call(
		_floating_text_count(ion_floats, "-4") == 1
		and _floating_text_count(ion_floats, "-2") == 1
		and _floating_text_count(ion_floats, "-2 B") == 1,
		"Ion Spool should show exact per-target HP and defense losses"
	)
	expect.call(
		(ion_presentation.get("impact_decals", []) as Array).size() == 2,
		"Relic discharge feedback should reuse the standard attack-impact decals for every damaged enemy"
	)
	var ion_pre_impact_display: Dictionary = scene.call(
		"_state_with_enemy_durability_from",
		ion_after,
		ion_before
	) as Dictionary
	expect.call(
		_enemy_durability(ion_pre_impact_display, 1) == _enemy_durability(ion_before, 1)
		and _enemy_durability(ion_pre_impact_display, 2) == _enemy_durability(ion_before, 2),
		"Relic discharge setup should hold every enemy at its exact pre-hit HP, Block, and Stoneskin"
	)
	expect.call(
		combat.elemental_intensity(ion_pre_impact_display, ElementData.LIGHTNING)
		== combat.elemental_intensity(ion_after, ElementData.LIGHTNING)
		and (ion_pre_impact_display.get("player", {}) as Dictionary)
		== (ion_after.get("player", {}) as Dictionary),
		"Holding enemy durability should preserve the already-resolved intensity and player state"
	)
	expect.call(
		_enemy_durability(ion_after, 1) != _enemy_durability(ion_pre_impact_display, 1)
		and _enemy_durability(ion_after, 2) != _enemy_durability(ion_pre_impact_display, 2),
		"The impact state should commit the durability loss that its hit feedback communicates"
	)

	var attack_before: Dictionary = _state(combat, [])
	var ranged_action: Dictionary = {"type": "ranged", "damage": 4, "range": 8}
	var attack_target: Vector2i = ((attack_before.get("enemies", []) as Array)[0] as Dictionary).get("pos", Vector2i.ZERO)
	var attack_after: Dictionary = combat.apply_player_action(attack_before, ranged_action, attack_target)
	expect.call(
		(scene.call(
			"_secondary_player_action_enemy_loss_presentation",
			attack_before,
			attack_after,
			"bone_dart",
			ranged_action,
			[]
		) as Dictionary).is_empty(),
		"Attack actions should not duplicate their existing inline damage feedback"
	)
	expect.call(
		bool(scene.call("_player_action_enemy_losses_presented_inline", "move", [{"id": "trap"}]))
		and not bool(scene.call("_player_action_enemy_losses_presented_inline", "move", [])),
		"Movement should defer to trap feedback only when a trap already presents the losses"
	)
	var trap_before: Dictionary = _state(combat, [])
	var trap_player: Dictionary = (trap_before.get("player", {}) as Dictionary).duplicate(true)
	trap_player["block"] = 1
	trap_before["player"] = trap_player
	var trap_enemies: Array = (trap_before.get("enemies", []) as Array).duplicate(true)
	var blast_enemy: Dictionary = (trap_enemies[0] as Dictionary).duplicate(true)
	blast_enemy["pos"] = Vector2i(4, 4)
	blast_enemy["block"] = 1
	trap_enemies[0] = blast_enemy
	trap_before["enemies"] = trap_enemies
	trap_before["traps"] = [{
		"id": "timing_trap",
		"element": ElementData.FIRE,
		"pos": Vector2i(3, 4),
		"base_damage": 6,
		"damage": 6,
		"armed": true
	}]
	var move_action: Dictionary = {"type": "move", "range": 2}
	var trap_after: Dictionary = combat.apply_player_action(trap_before, move_action, Vector2i(3, 4))
	var triggered_traps: Array = scene.call("_triggered_traps_between", trap_before, trap_after) as Array
	var trap_setup_display: Dictionary = scene.call(
		"_player_action_primary_display_state",
		trap_before,
		trap_after,
		"move",
		triggered_traps,
		{}
	) as Dictionary
	expect.call(
		_enemy_durability(trap_setup_display, 1) == _enemy_durability(trap_before, 1)
		and _player_durability(trap_setup_display) == _player_durability(trap_before),
		"Movement into a trap should hold enemy and player durability until trap impact feedback"
	)
	expect.call(
		(trap_setup_display.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
		== (trap_after.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
		and (trap_setup_display.get("traps", []) as Array) == (trap_after.get("traps", []) as Array),
		"Trap setup should preserve the resolved destination and consumed-trap state"
	)
	expect.call(
		_enemy_durability(trap_after, 1) != _enemy_durability(trap_setup_display, 1)
		and _player_durability(trap_after) != _player_durability(trap_setup_display),
		"Trap impact should commit both enemy and player durability losses"
	)

	var thorn_before: Dictionary = _state(combat, ["thornmail_brooch"])
	var thorn_enemies: Array = (thorn_before.get("enemies", []) as Array).duplicate(true)
	var adjacent_enemy: Dictionary = (thorn_enemies[0] as Dictionary).duplicate(true)
	adjacent_enemy["pos"] = Vector2i(3, 4)
	thorn_enemies[0] = adjacent_enemy
	thorn_before["enemies"] = thorn_enemies
	var stoneskin_action: Dictionary = {"type": "stoneskin", "amount": 8}
	var thorn_after: Dictionary = combat.apply_player_action(thorn_before, stoneskin_action)
	var thorn_presentation: Dictionary = scene.call(
		"_secondary_player_action_enemy_loss_presentation",
		thorn_before,
		thorn_after,
		"stone_plate",
		stoneskin_action,
		[]
	) as Dictionary
	expect.call(
		_floating_text_count(thorn_presentation.get("floating_texts", []), "-4") == 1
		and (thorn_presentation.get("impact_actor_keys", []) as Array).size() == 1,
		"Thornmail Brooch should present retaliation nested under a Stoneskin action"
	)

	var enemy_intensity_after: Dictionary = combat.call(
		"_gain_elemental_intensity",
		ion_before.duplicate(true),
		ElementData.LIGHTNING,
		1,
		"Enemy builder"
	) as Dictionary
	var enemy_intensity_step: Dictionary = combat.call(
		"_enemy_action_step",
		ion_before,
		enemy_intensity_after,
		0,
		intensity_action,
		{}
	) as Dictionary
	expect.call(
		(enemy_intensity_step.get("enemy_losses", []) as Array).size() == 2
		and _floating_text_count(scene.call("_floating_texts_for_step", enemy_intensity_step) as Array, "-4") == 1,
		"Off-turn intensity gains should carry relic discharge losses into enemy-step feedback"
	)
	var animated_enemy_state: Dictionary = ion_before.duplicate(true)
	scene.call("_apply_animation_step", animated_enemy_state, enemy_intensity_step)
	var enemy_intensity_presentation: Dictionary = scene.call(
		"_enemy_phase_status_presentation",
		enemy_intensity_step
	) as Dictionary
	expect.call(
		(animated_enemy_state.get("enemies", []) as Array) == (enemy_intensity_after.get("enemies", []) as Array)
		and combat.elemental_intensity(animated_enemy_state, ElementData.LIGHTNING) == combat.elemental_intensity(enemy_intensity_after, ElementData.LIGHTNING),
		"Enemy intensity playback should commit every discharged enemy loss and the final contested intensity"
	)
	expect.call(
		(enemy_intensity_presentation.get("impact_decals", []) as Array).size() == 2,
		"Off-turn intensity discharges should reuse the standard impact decals for every damaged enemy"
	)

	var status_chain_before: Dictionary = _state(
		combat,
		["ember_siphon", "cinderbrand_tongs"],
		10,
		24
	)
	status_chain_before["elemental_intensity"] = _intensities({ElementData.FIRE: 3})
	var status_enemies: Array = (status_chain_before.get("enemies", []) as Array).duplicate(true)
	var burning_enemy: Dictionary = (status_enemies[0] as Dictionary).duplicate(true)
	burning_enemy["hp"] = 1
	burning_enemy["burn"] = 1
	status_enemies[0] = burning_enemy
	var defended_survivor: Dictionary = burning_enemy.duplicate(true)
	defended_survivor["id"] = 2
	defended_survivor["pos"] = Vector2i(4, 2)
	defended_survivor["hp"] = 20
	defended_survivor["max_hp"] = 20
	defended_survivor["burn"] = 0
	defended_survivor["stoneskin"] = 1
	status_enemies.append(defended_survivor)
	status_chain_before["enemies"] = status_enemies
	var status_result: Dictionary = combat.call(
		"_resolve_enemy_start_of_turn",
		status_chain_before.duplicate(true),
		0
	) as Dictionary
	var status_chain_after: Dictionary = status_result.get("state", {})
	var status_steps: Array = status_result.get("steps", [])
	var status_step: Dictionary = status_steps[0] if not status_steps.is_empty() else {}
	var status_floats: Array = scene.call("_floating_texts_for_step", status_step) as Array
	expect.call(
		(status_step.get("enemy_losses", []) as Array).size() == 1
		and (status_step.get("impact_actor_keys", []) as Array).size() == 1,
		"A lethal status tick should carry its primary loss without treating damage-over-time Burn as an attack-applied relic trigger"
	)
	expect.call(
		_floating_text_count(status_floats, "-1") == 1
		and _floating_text_count(status_floats, "-1 S") == 0,
		"Damage-over-time Burn should show only its own exact health loss"
	)
	var status_presentation: Dictionary = scene.call("_enemy_phase_status_presentation", status_step) as Dictionary
	expect.call(
		(status_presentation.get("impact_decals", []) as Array).size() == 1,
		"Damage-over-time Burn should reuse one standard impact decal"
	)
	var animated_status_state: Dictionary = status_chain_before.duplicate(true)
	scene.call("_apply_animation_step", animated_status_state, status_step)
	expect.call(
		(animated_status_state.get("enemies", []) as Array) == (status_chain_after.get("enemies", []) as Array)
		and (animated_status_state.get("player", {}) as Dictionary) == (status_chain_after.get("player", {}) as Dictionary)
		and combat.elemental_intensity(animated_status_state, ElementData.FIRE) == combat.elemental_intensity(status_chain_after, ElementData.FIRE),
		"Status playback should commit Burn damage and Ember Siphon healing without firing attack-only Cinderbrand effects"
	)

	var board := CombatBoardView.new()
	var impacted_unit: Dictionary = {"key": "enemy_1"}
	board.presentation = {
		"impact_actor_keys": ["enemy_1"],
		"impact_progress": 0.18,
		"reduced_motion": false
	}
	expect.call(
		float(board.call("_unit_impact_strength", impacted_unit)) > 0.0
		and float(board.call("_unit_impact_shake_strength", impacted_unit)) > 0.0,
		"Normal motion should retain the established hit flash and shake"
	)
	board.presentation["reduced_motion"] = true
	expect.call(
		float(board.call("_unit_impact_strength", impacted_unit)) > 0.0
		and is_zero_approx(float(board.call("_unit_impact_shake_strength", impacted_unit)))
		and not bool(board.call("_impact_animation_active")),
		"Reduced motion should retain a static hit flash while suppressing continuous shake"
	)
	board.free()
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

static func _intensities(overrides: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for element_id: String in ElementData.all_elements():
		result[element_id] = int(overrides.get(element_id, 0))
	return result

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
