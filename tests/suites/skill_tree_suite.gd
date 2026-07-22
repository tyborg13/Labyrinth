extends RefCounted

const GameData = preload("res://scripts/game_data.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SkillTreeLibrary = preload("res://scripts/skill_tree_library.gd")

static func run(expect: Callable) -> void:
	_test_skill_data_and_topology(expect)
	_test_layout_validation_requires_bounded_coordinates(expect)
	_test_topology_validation_rejects_unknown_prerequisites(expect)
	_test_topology_validation_rejects_cycles(expect)
	_test_topology_validation_rejects_dead_ends(expect)
	_test_leveling_banks_points_and_learning_is_immediate(expect)
	_test_keystones_are_exclusive(expect)
	_test_max_build_requires_keystone(expect)
	_test_reset_is_immediate_and_refunds_points(expect)
	_test_legacy_profile_migration(expect)

static func _test_skill_data_and_topology(expect: Callable) -> void:
	expect.call(SkillTreeLibrary.definitions().size() == 24, "The skill tree should define exactly 24 skills")
	expect.call(SkillTreeLibrary.validation_errors().is_empty(), "The skill graph should have valid data, positions, prerequisites, and a complete level-20 route")
	var caller_order: Array[String] = SkillTreeLibrary.ordered_ids()
	caller_order.clear()
	expect.call(SkillTreeLibrary.ordered_ids().size() == 24, "The cached authored order should return an isolated copy to callers")
	var roots: Array[String]
	var keystones: Array[String]
	for skill_id: String in SkillTreeLibrary.ordered_ids():
		var skill_def: Dictionary = SkillTreeLibrary.definition(skill_id)
		expect.call(ActionIcons.icon_texture(SkillTreeLibrary.icon_key(skill_id)) != null, "%s should have a loadable tree icon" % skill_id)
		expect.call(not SkillTreeLibrary.description(skill_id).to_lower().contains("sequence"), "%s should describe its refresh cadence in player language" % skill_id)
		if str(skill_def.get("tier", "")) == "root":
			roots.append(skill_id)
		if SkillTreeLibrary.is_keystone(skill_id):
			keystones.append(skill_id)
	expect.call(roots.size() == 4, "The tree should begin with four distinct roots")
	expect.call(keystones.size() == 4, "The tree should end with four exclusive keystones")
	expect.call(SkillTreeLibrary.available_ids([]).size() == 4, "A new character should be able to learn any root")
	var afterimage_health: int = GameData.fixed_point_amount(int(SkillTreeLibrary.effect("afterimage").get("health_visible", 0)))
	var reserve_health: int = GameData.fixed_point_amount(int(SkillTreeLibrary.effect("last_reserve").get("minimum_health_visible", 0)))
	var last_door_health: int = GameData.fixed_point_amount(int(SkillTreeLibrary.effect("last_door").get("minimum_health_visible", 0)))
	expect.call(SkillTreeLibrary.description("afterimage").contains(str(afterimage_health)), "Afterimage copy should match the health shown on its illusion")
	expect.call(SkillTreeLibrary.description("last_reserve").contains(str(reserve_health)), "Last Reserve copy should match the surviving health shown in combat")
	expect.call(SkillTreeLibrary.description("last_door").contains(str(last_door_health)), "Last Door copy should match the returning health shown in the run UI")
	expect.call(SkillTreeLibrary.description("ghost_stride") == "Once per combat, you may use a card's basic Move as Blink 2.", "Ghost Stride copy should preserve the choice to use the normal basic Move")
	expect.call(SkillTreeLibrary.description("pain_remembers") == "After you first lose health each combat, the next non-item card discarded while your hand has room returns to it.", "Pain Remembers copy should disclose that a full hand delays its recall")
	expect.call(SkillTreeLibrary.description("prismatic_instinct") == "Once per combat, name a card with an intensity condition in hand. The next printed play of any copy satisfies all its intensity conditions. Basic Attack, Move, and Blink uses do not consume the effect.", "Prismatic Instinct copy should describe its card-name scope, printed-play trigger, and non-consuming basic actions")
	expect.call(SkillTreeLibrary.description("curators_patience") == "After choosing a relic, save one unchosen relic for your next relic offer.", "Curator's Patience copy should identify the next relic offer")
	expect.call(SkillTreeLibrary.description("living_shadow") == "Once between your activations, when an illusion is destroyed or dispelled, return your most recently discarded non-item card to hand—or put it atop your draw pile if your hand is full.", "Living Shadow copy should use activation cadence, identify both illusion-removal triggers, and define a full hand")
	expect.call(SkillTreeLibrary.description("layaway") == "Once between bosses, hold one offer for the next merchant of that type. A pending hold blocks future uses until it returns.", "Layaway copy should disclose that an unresolved hold blocks another use")
	expect.call(SkillTreeLibrary.description("open_arsenal") == "Equip any equipment in your trinket slot, ignoring its normal slot.", "Open Arsenal copy should explain which equipment restriction it ignores")
	expect.call(SkillTreeLibrary.description("confluence") == "Intensity conditions use your highest intensity, regardless of element. A draw enabled solely by Confluence stops before it would trigger Fatigue.", "Confluence copy should distinguish condition substitution from real intensity")
	expect.call(SkillTreeLibrary.activation_kind("open_arsenal") == "passive" and SkillTreeLibrary.activation_kind("confluence") == "passive", "Always-on keystone rules should be classified as passive rather than automatic triggers")
	var selected_keystone_build: Array[String] = SkillTreeLibrary.repaired_selection([], 9, [
		"quick_wits", "measured_breath", "rehearsed_escape", "makeshift_tool",
		"carry_the_guard", "pain_remembers", "borrowed_time", "ghost_stride", "encore",
	])
	expect.call(SkillTreeLibrary.locked_reason("open_arsenal", selected_keystone_build) == "Another keystone is selected", "Excluded keystones should explain that another keystone is selected, not learned")

static func _test_layout_validation_requires_bounded_coordinates(expect: Callable) -> void:
	var missing_layout: Dictionary = SkillTreeLibrary.definitions().duplicate(true)
	(missing_layout["quick_wits"] as Dictionary).erase("layout_position")
	var missing_errors: Array[String] = _validation_errors_with_definitions(missing_layout)
	expect.call(_contains_error_fragment(missing_errors, "layout_position must contain exactly two integer coordinates"), "Topology validation should reject a node without an explicit visual coordinate")
	var clipped_layout: Dictionary = SkillTreeLibrary.definitions().duplicate(true)
	(clipped_layout["quick_wits"] as Dictionary)["layout_position"] = [2, 30]
	var clipped_errors: Array[String] = _validation_errors_with_definitions(clipped_layout)
	expect.call(_contains_error_fragment(clipped_errors, "outside the"), "Topology validation should reject a medallion that extends beyond the fixed canvas")

static func _test_topology_validation_rejects_unknown_prerequisites(expect: Callable) -> void:
	var altered_definitions: Dictionary = SkillTreeLibrary.definitions().duplicate(true)
	(altered_definitions["quick_wits"] as Dictionary)["prerequisites"] = ["missing_skill"]
	var errors: Array[String] = _validation_errors_with_definitions(altered_definitions)
	expect.call(_contains_error_fragment(errors, "requires unknown skill missing_skill"), "Topology validation should inspect raw prerequisites before runtime filtering")

static func _test_topology_validation_rejects_cycles(expect: Callable) -> void:
	var altered_definitions: Dictionary = SkillTreeLibrary.definitions().duplicate(true)
	(altered_definitions["quick_wits"] as Dictionary)["prerequisites"] = ["rehearsed_escape"]
	var errors: Array[String] = _validation_errors_with_definitions(altered_definitions)
	expect.call(_contains_error_fragment(errors, "prerequisite cycle"), "Topology validation should reject indirect prerequisite cycles")

static func _test_topology_validation_rejects_dead_ends(expect: Callable) -> void:
	var gated_definitions: Dictionary = SkillTreeLibrary.definitions().duplicate(true)
	for skill_id: String in gated_definitions:
		(gated_definitions[skill_id] as Dictionary)["minimum_owned"] = 1
	var gated_errors: Array[String] = _validation_errors_with_definitions(gated_definitions)
	expect.call(_contains_error_fragment(gated_errors, "cannot be extended"), "Topology validation should reject an empty legal build with no legal first choice")
	var altered_definitions: Dictionary = SkillTreeLibrary.definitions().duplicate(true)
	for skill_id: String in altered_definitions:
		(altered_definitions[skill_id] as Dictionary)["exclusive_group"] = "test_lock"
	var errors: Array[String] = _validation_errors_with_definitions(altered_definitions)
	expect.call(_contains_error_fragment(errors, "cannot be extended"), "Topology validation should reject a legal partial build with no legal next choice")

static func _test_leveling_banks_points_and_learning_is_immediate(expect: Callable) -> void:
	var profile: Dictionary = ProgressionStore.set_embers(ProgressionStore.default_data(), GameData.progression_level_total_cost(20))
	expect.call(not ProgressionStore.can_learn_skill(profile, "quick_wits"), "A level-one profile should not spend a skill it has not earned")
	for _target_level: int in range(2, 5):
		profile = ProgressionStore.purchase_level(profile)
	expect.call(int(profile.get("level", 1)) == 4, "Level purchase should advance without forcing a skill choice")
	expect.call(ProgressionStore.selected_skill_ids(profile).is_empty(), "Banking levels should not silently learn skills")
	expect.call(ProgressionStore.unspent_skill_points(profile) == 3, "Three purchased levels should bank three independent skill points")
	profile = ProgressionStore.normalized_data(profile)
	expect.call(ProgressionStore.unspent_skill_points(profile) == 3, "Save normalization should preserve banked points")
	var rejected: Dictionary = ProgressionStore.learn_skill(profile, "borrowed_time")
	expect.call(rejected == profile, "Learning should reject a skill with missing prerequisites without spending a point")
	profile = ProgressionStore.learn_skill(profile, "quick_wits")
	expect.call(ProgressionStore.has_skill(profile, "quick_wits"), "Learning an available skill should persist it immediately")
	expect.call(ProgressionStore.unspent_skill_points(profile) == 2, "Learning should spend exactly one banked point")
	for _target_level: int in range(5, 21):
		profile = ProgressionStore.purchase_level(profile)
	expect.call(int(profile.get("level", 1)) == 20, "Independent level purchases should reach level 20")
	expect.call(ProgressionStore.unspent_skill_points(profile) == 18, "Unspent points should accumulate without a cap")
	var chosen_keystone: String = ""
	while ProgressionStore.unspent_skill_points(profile) > 0:
		var available: Array[String] = ProgressionStore.available_skill_ids(profile)
		var choice: String = available[0] if not available.is_empty() else ""
		if ProgressionStore.selected_skill_ids(profile).size() >= 8 and chosen_keystone.is_empty():
			for candidate_id: String in available:
				if SkillTreeLibrary.is_keystone(candidate_id):
					choice = candidate_id
					chosen_keystone = candidate_id
					break
		var count_before: int = ProgressionStore.selected_skill_ids(profile).size()
		profile = ProgressionStore.learn_skill(profile, choice)
		expect.call(ProgressionStore.selected_skill_ids(profile).size() == count_before + 1, "Each immediate learn should spend exactly one point")
		expect.call(ProgressionStore.has_skill(profile, choice), "The chosen skill should be retained after normalization")
	expect.call(ProgressionStore.selected_skill_ids(profile).size() == 19, "A level-20 profile should own exactly 19 skills")
	expect.call(ProgressionStore.unspent_skill_points(profile) == 0, "A complete allocation should consume all earned points")
	expect.call(not chosen_keystone.is_empty(), "A legal progression route should be able to choose a keystone")
	expect.call(not ProgressionStore.can_level_up(profile), "A level-20 profile should not be able to buy another level")

static func _test_keystones_are_exclusive(expect: Callable) -> void:
	var profile: Dictionary = ProgressionStore.default_data()
	profile["level"] = 20
	profile["skill_ids"] = SkillTreeLibrary.repaired_selection([], 19, [
		"quick_wits", "measured_breath", "ghost_stride", "discerning_eye",
		"rehearsed_escape", "makeshift_tool", "carry_the_guard", "pain_remembers",
		"borrowed_time", "encore"
	])
	profile = ProgressionStore.normalized_data(profile)
	var keystone_count: int = 0
	for skill_id: String in ProgressionStore.selected_skill_ids(profile):
		if SkillTreeLibrary.is_keystone(skill_id):
			keystone_count += 1
	expect.call(keystone_count == 1, "A normalized level-20 build should contain exactly one keystone")
	if keystone_count == 1:
		for available_id: String in ProgressionStore.available_skill_ids(profile):
			expect.call(not SkillTreeLibrary.is_keystone(available_id), "Learning one keystone should lock the other keystones")

static func _test_max_build_requires_keystone(expect: Callable) -> void:
	var non_keystone_ids: Array[String]
	for skill_id: String in SkillTreeLibrary.ordered_ids():
		if not SkillTreeLibrary.is_keystone(skill_id):
			non_keystone_ids.append(skill_id)
	var legacy_max_builds: Array = []
	for omitted_index: int in range(non_keystone_ids.size()):
		var legacy_selection: Array[String] = non_keystone_ids.duplicate()
		legacy_selection.remove_at(omitted_index)
		if not _selection_is_topologically_valid_without_capstone(legacy_selection):
			continue
		legacy_max_builds.append(legacy_selection)
		expect.call(not SkillTreeLibrary.selection_is_valid(legacy_selection, SkillTreeLibrary.COMPLETE_BUILD_SIZE), "A maximum build without a keystone should be rejected")
		var repaired: Array[String] = SkillTreeLibrary.repaired_selection(legacy_selection, SkillTreeLibrary.COMPLETE_BUILD_SIZE, legacy_selection)
		expect.call(SkillTreeLibrary.selection_is_valid(repaired, SkillTreeLibrary.COMPLETE_BUILD_SIZE), "A legacy maximum build should repair to a complete legal selection")
		expect.call(_keystone_count(repaired) == 1, "Repairing a legacy maximum build should insert exactly one eligible keystone")
	expect.call(legacy_max_builds.size() == 11, "The capstone migration proof should cover every formerly legal no-keystone maximum build")

	var legal_eighteen_count: int = 0
	for first_omitted: int in range(non_keystone_ids.size()):
		for second_omitted: int in range(first_omitted + 1, non_keystone_ids.size()):
			var partial: Array[String] = non_keystone_ids.duplicate()
			partial.erase(non_keystone_ids[second_omitted])
			partial.erase(non_keystone_ids[first_omitted])
			if not SkillTreeLibrary.selection_is_valid(partial, SkillTreeLibrary.COMPLETE_BUILD_SIZE - 1):
				continue
			legal_eighteen_count += 1
			var available: Array[String] = SkillTreeLibrary.available_ids(partial)
			var available_keystones: int = 0
			for available_id: String in available:
				if SkillTreeLibrary.is_keystone(available_id):
					available_keystones += 1
			expect.call(available_keystones == available.size() and available_keystones >= 2, "Every 18-point no-keystone build should have multiple keystone continuations and no invalid final non-keystone")
			expect.call(SkillTreeLibrary.locked_reason(non_keystone_ids[first_omitted], partial) == "Your final skill must be a keystone", "A blocked final non-keystone should explain the capstone requirement")
	expect.call(legal_eighteen_count == 58, "The capstone proof should exhaust every legal 18-point no-keystone build")

	var legacy_profile: Dictionary = ProgressionStore.default_data()
	legacy_profile["progression_schema"] = 3
	legacy_profile["level"] = 20
	legacy_profile["skill_ids"] = (legacy_max_builds[0] as Array).duplicate()
	legacy_profile["progression_revision"] = 7
	var migrated_profile: Dictionary = ProgressionStore.normalized_data(legacy_profile)
	expect.call(int(migrated_profile.get("progression_schema", 0)) == 5, "No-keystone maximum profiles should migrate to progression schema 5")
	expect.call(int(migrated_profile.get("progression_revision", 0)) == 8, "Changing a legacy maximum build during migration should advance its progression revision")
	expect.call(SkillTreeLibrary.selection_is_valid(ProgressionStore.selected_skill_ids(migrated_profile), SkillTreeLibrary.COMPLETE_BUILD_SIZE), "The migrated maximum profile should remain complete and legal")
	expect.call(_keystone_count(ProgressionStore.selected_skill_ids(migrated_profile)) == 1, "The migrated maximum profile should contain exactly one keystone")

static func _selection_is_topologically_valid_without_capstone(skill_ids: Array[String]) -> bool:
	for skill_id: String in skill_ids:
		for prerequisite_id: String in SkillTreeLibrary.prerequisites(skill_id):
			if not skill_ids.has(prerequisite_id):
				return false
		if skill_ids.size() - 1 < SkillTreeLibrary.minimum_owned(skill_id):
			return false
	return true

static func _keystone_count(skill_ids: Array[String]) -> int:
	var result: int = 0
	for skill_id: String in skill_ids:
		if SkillTreeLibrary.is_keystone(skill_id):
			result += 1
	return result

static func _test_reset_is_immediate_and_refunds_points(expect: Callable) -> void:
	var profile: Dictionary = ProgressionStore.default_data()
	profile["level"] = 6
	profile["skill_ids"] = SkillTreeLibrary.repaired_selection([], 5)
	profile["moltshards"] = 1
	profile = ProgressionStore.normalized_data(profile)
	var original_skills: Array[String] = ProgressionStore.selected_skill_ids(profile)
	expect.call(ProgressionStore.can_reset_skills(profile), "A learned profile with a Moltshard should be resettable")
	var revision_before: int = int(profile.get("progression_revision", 0))
	var reset: Dictionary = ProgressionStore.reset_skills(profile)
	expect.call(ProgressionStore.moltshard_count(reset) == 0, "Reset should consume exactly one Moltshard")
	expect.call(ProgressionStore.selected_skill_ids(reset).is_empty(), "Reset should clear every learned skill in one operation")
	expect.call(ProgressionStore.unspent_skill_points(reset) == 5, "Reset should refund every earned point for later spending")
	expect.call(int(reset.get("progression_revision", 0)) == revision_before + 1, "Reset should advance the profile revision exactly once")
	expect.call(not ProgressionStore.can_reset_skills(reset), "Reset should be unavailable without a Moltshard and learned skills")
	var unchanged: Dictionary = ProgressionStore.reset_skills(reset)
	expect.call(unchanged == reset, "A rejected reset should leave the profile unchanged")
	expect.call(not ProgressionStore.can_respec_skills(profile, original_skills), "The retired replacement-build adapter should never create a hidden draft transaction")

static func _test_legacy_profile_migration(expect: Callable) -> void:
	var legacy: Dictionary = {
		"progression_schema": 2,
		"level": 6,
		"embers": 75,
		"stats": {"agility": 3, "air_magick": 2},
		"unspent_stat_points": 0
	}
	var migrated: Dictionary = ProgressionStore.normalized_data(legacy)
	expect.call(int(migrated.get("progression_schema", 0)) == ProgressionStore.PROGRESSION_SCHEMA, "Legacy profiles should migrate to the current schema")
	expect.call(ProgressionStore.selected_skill_ids(migrated).size() == 5, "A migrated level-six profile should retain five progression choices")
	expect.call(ProgressionStore.moltshard_count(migrated) == 0, "Profile migration should not create respec currency that was not earned in play")
	expect.call(int(migrated.get("embers", 0)) == 75, "Skill migration should preserve held embers")
	expect.call(not migrated.has("stats") and not migrated.has("unspent_stat_points"), "Legacy stat fields should not survive skill migration")
	expect.call(SkillTreeLibrary.selection_is_valid(ProgressionStore.selected_skill_ids(migrated), 5), "Migrated choices should satisfy every dependency")
	expect.call(ProgressionStore.normalized_data(migrated) == migrated, "Profile migration should be idempotent")
	var chained_legacy: Dictionary = {
		"progression_schema": 1,
		"level": 3,
		"embers": 20,
		"card_mods": {"quick_stab": [{"type": "damage", "amount": 2, "cost_paid": 37}]},
		"stats": {"might": 2}
	}
	var chained_migration: Dictionary = ProgressionStore.normalized_data(chained_legacy)
	expect.call(int(chained_migration.get("embers", 0)) == 57, "Schema-one migration should refund retired card growth before converting progression choices")
	expect.call(ProgressionStore.selected_skill_ids(chained_migration).size() == 2, "Schema-one migration should complete both chained migrations")
	var forged_current: Dictionary = ProgressionStore.default_data()
	forged_current["card_mods"] = {"quick_stab": [{"type": "damage", "amount": 500, "cost_paid": 11}]}
	forged_current["purchased_upgrades"] = ["unknown_upgrade"]
	var sanitized: Dictionary = ProgressionStore.normalized_data(forged_current)
	expect.call(not sanitized.has("card_mods") and not sanitized.has("card_upgrades") and not sanitized.has("purchased_upgrades"), "Current profiles should remove every retired permanent card-growth field")
	var printed_action: Dictionary = (GameData.card_def("quick_stab").get("actions", []) as Array)[0]
	var sanitized_action: Dictionary = (GameData.card_def_for_progression("quick_stab", forged_current).get("actions", []) as Array)[0]
	expect.call(int(sanitized_action.get("damage", 0)) == int(printed_action.get("damage", 0)), "Forged permanent card growth must not change printed combat numbers")

static func _validation_errors_with_definitions(altered_definitions: Dictionary) -> Array[String]:
	var original_cache: Dictionary = SkillTreeLibrary._cache
	var original_order: Array[String] = SkillTreeLibrary.ordered_ids()
	SkillTreeLibrary._cache = altered_definitions
	SkillTreeLibrary._ordered_ids_cache.clear()
	var errors: Array[String] = SkillTreeLibrary.validation_errors()
	SkillTreeLibrary._cache = original_cache
	SkillTreeLibrary._ordered_ids_cache = original_order
	return errors

static func _contains_error_fragment(errors: Array[String], fragment: String) -> bool:
	for error: String in errors:
		if error.to_lower().contains(fragment.to_lower()):
			return true
	return false
