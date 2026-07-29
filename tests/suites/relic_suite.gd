extends RefCounted

const CombatEngine = preload("res://scripts/combat_engine.gd")
const ElementData = preload("res://scripts/element_data.gd")
const GameData = preload("res://scripts/game_data.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")

const NEW_RELIC_IDS := [
	"duelist_whetstone",
	"hollow_die",
	"chorus_mask",
	"hourglass_splinter",
	"widow_thread",
	"funeral_bell",
	"bloodmoon_chalice",
	"moonless_compass",
	"fivefold_knot",
	"borrowed_hourglass"
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
	"card_action_mod",
	"card_play_reward",
	"damage_vs_status",
	"defiance_capacity",
	"defiance_trigger_reward",
	"end_turn_block_to_stoneskin",
	"enemy_death_reward",
	"first_card_attack_bonus",
	"intensity_threshold_reward",
	"long_move_card_play",
	"opening_draw_bonus",
	"overheal_to_stoneskin",
	"player_state_action_mod",
	"start_combat_stoneskin_per_deck_element",
	"status_count_reward",
	"status_intensity_gain",
	"stoneskin_intensity_gain_once_per_turn",
	"stoneskin_thorns"
]

static func run(expect: Callable) -> void:
	_test_complete_set_contract(expect)
	_test_conditional_card_mutations(expect)
	_test_new_common_and_rare_relics(expect)
	_test_new_epic_and_legendary_relics(expect)
	_test_status_and_enemy_death_engines(expect)
	_test_intensity_engines(expect)
	_test_defense_risk_and_mobility_engines(expect)
	_test_defiance_and_mono_earth_payoffs(expect)
	_test_state_sequence_bridges(expect)
	_test_player_facing_turn_terminology(expect)

static func _test_complete_set_contract(expect: Callable) -> void:
	var relics: Dictionary = GameData.relics()
	expect.call(relics.size() == 47, "The complete relic rework should contain 37 redesigned relics plus exactly 10 new relics")
	for relic_id: String in NEW_RELIC_IDS:
		expect.call(relics.has(relic_id), "New relic %s should be present" % relic_id)
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

static func _test_conditional_card_mutations(expect: Callable) -> void:
	_expect_action_delta(expect, "ricochet_knife", "ember_lens", "ranged", "damage", 3)
	_expect_action_delta(expect, "threaded_path", "pilgrim_boots", "move", "range", 1)
	_expect_action_delta(expect, "riposte_lunge", "reinforced_shield", "block", "amount", 3)
	_expect_action_delta(expect, "hearth_rush", "flint_edge", "melee", "burn", 2)
	_expect_action_delta(expect, "chain_bolt", "storm_capacitor", "ranged", "chain", 1)
	_expect_action_delta(expect, "gust_step", "tailwind_fletching", "pull", "damage", 1)
	_expect_action_delta(expect, "gust_step", "tailwind_fletching", "pull", "amount", 1)
	_expect_action_delta(expect, "rime_shard", "widow_thread", "ranged", "expose", 3)
	var iron_wheel_with_boots: Dictionary = GameData.card_def_for_progression("iron_wheel", {"relics": ["pilgrim_boots"]})
	expect.call(
		int(_first_action_of_type(iron_wheel_with_boots, "move").get("range", 0)) == int(_first_action_of_type(GameData.card_def("iron_wheel"), "move").get("range", 0)),
		"Pilgrim Boots should leave move-and-attack cards to Duelist Whetstone"
	)
	var plain_stab: Dictionary = GameData.card_def_for_progression("quick_stab", {"relics": ["ember_lens", "reinforced_shield", "widow_thread"]})
	var plain_action: Dictionary = _first_action_of_type(plain_stab, "melee")
	var base_plain_action: Dictionary = _first_action_of_type(GameData.card_def("quick_stab"), "melee")
	expect.call(int(plain_action.get("damage", 0)) == int(base_plain_action.get("damage", 0)), "Conditional card relics should leave cards without their required build traits unchanged")

static func _test_new_common_and_rare_relics(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var duelist_state: Dictionary = _state(combat, ["duelist_whetstone"])
	var duelist_card: Dictionary = GameData.card_def_for_progression("iron_wheel", {})
	var duelist_attack: Dictionary = _first_action_of_type(duelist_card, "melee")
	expect.call(combat.final_damage_for_player_action(duelist_state, duelist_attack) == 12, "Duelist Whetstone should add two damage to the first move-attack card")
	duelist_state = _trigger_card(combat, duelist_state, duelist_card, "iron_wheel")
	expect.call(combat.final_damage_for_player_action(duelist_state, duelist_attack) == 10, "Duelist Whetstone should apply only once per turn")

	var hollow_state: Dictionary = _state(combat, ["hollow_die"])
	hollow_state["deck"] = _deck([], ["brace"], [])
	hollow_state = _trigger_card(combat, hollow_state, _card("", 1, [{"type": "block", "amount": 3}]), "hollow")
	expect.call((hollow_state.get("deck", {}) as Dictionary).get("hand", []) == ["brace"], "Hollow Die should draw from a one-action card")
	var hollow_fatigue_state: Dictionary = _state(combat, ["hollow_die"], 10, 24)
	hollow_fatigue_state["deck"] = _deck([], [], ["brace"])
	hollow_fatigue_state = _trigger_card(combat, hollow_fatigue_state, _card("", 1, [{"type": "block", "amount": 3}]), "hollow")
	expect.call(
		int((hollow_fatigue_state.get("player", {}) as Dictionary).get("hp", 0)) == 10
		and int((hollow_fatigue_state.get("deck", {}) as Dictionary).get("cycles", 0)) == 0
		and ((hollow_fatigue_state.get("deck", {}) as Dictionary).get("hand", []) as Array).is_empty(),
		"Relic reward draws should stop instead of reshuffling the discard pile and inflicting Fatigue"
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

	var widow_card: Dictionary = GameData.card_def_for_progression("rime_shard", {"relics": ["widow_thread"]})
	expect.call(int(_first_action_of_type(widow_card, "ranged").get("expose", 0)) == 3, "Widow Thread should give illusion-attacks an Expose payoff")

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
	cinder_state["elemental_intensity"] = _intensities({ElementData.FIRE: 3})
	cinder_state = combat.call("_trigger_status_relics", cinder_state, "burn")
	expect.call(
		combat.elemental_intensity(cinder_state, ElementData.FIRE) == 2
		and int(((cinder_state.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0)) == 98
		and int(((cinder_state.get("enemies", []) as Array)[0] as Dictionary).get("burn", 0)) == 1,
		"Cinderbrand Tongs should cash out its Fire loop as damage and Burn"
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

	for relic_order: Array in [
		["ion_spool", "voltaic_tuning_fork"],
		["voltaic_tuning_fork", "ion_spool"]
	]:
		var stacked_state: Dictionary = _state(combat, relic_order)
		stacked_state["elemental_intensity"] = _intensities({ElementData.LIGHTNING: 3})
		stacked_state["deck"] = _deck([], ["brace", "quick_stab", "bone_dart"], [])
		stacked_state = combat.apply_player_action(stacked_state, {"type": "intensity", "element": ElementData.LIGHTNING, "amount": 1})
		expect.call(
			((stacked_state.get("deck", {}) as Dictionary).get("hand", []) as Array).size() == 2
			and int(((stacked_state.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0)) == 96,
			"Every relic sharing a crossed intensity threshold should resolve regardless of acquisition order"
		)
		expect.call(
			combat.elemental_intensity(stacked_state, ElementData.LIGHTNING) == 0,
			"Stacked intensity relics should aggregate and clamp their snapshotted consumption before rewards resolve"
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
