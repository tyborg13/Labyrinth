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
	expect.call(SkillTreeLibrary.definitions().size() == 30, "The skill tree should define exactly 30 skills")
	var validation_errors: Array[String] = SkillTreeLibrary.validation_errors()
	expect.call(validation_errors.is_empty(), "The skill graph should have valid data, positions, prerequisites, and a complete level-20 route: %s" % str(validation_errors))
	var caller_order: Array[String] = SkillTreeLibrary.ordered_ids()
	caller_order.clear()
	expect.call(SkillTreeLibrary.ordered_ids().size() == 30, "The cached authored order should return an isolated copy to callers")
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
	expect.call(roots.size() == 5, "The tree should begin with five distinct roots")
	expect.call(keystones.size() == 5, "The tree should end with five exclusive keystones")
	expect.call(SkillTreeLibrary.available_ids([]).size() == 5, "A new character should be able to learn any root")
	expect.call(SkillTreeLibrary.description("long_dawn") == "Temporary @icon(illuminate), @icon(vision), and @icon(truesight) you create last @icon(time) +1. Permanent and tethered effects are unchanged.", "Long Dawn should state the exact temporary-effect boundary")
	expect.call(SkillTreeLibrary.description("sunpath") == "The first @icon(move) or @icon(blink) 3+ each turn leaves @icon(illuminate) 1 @icon(time) 2 on every tile entered. @icon(blink) also covers its origin and destination.", "Sunpath should explain its path and Blink endpoint behavior without introducing a new interaction")
	expect.call(SkillTreeLibrary.description("witchlight") == "Each living @icon(illusion) adds +1 to its tethered @icon(illuminate).", "Witchlight should describe its additive tethered board effect concisely")
	expect.call(SkillTreeLibrary.description("dawnbrand") == "The first direct attack each turn against an enemy in @icon(illuminate) inflicts @icon(expose) 1.", "Dawnbrand should disclose its once-per-turn Light condition")
	expect.call(SkillTreeLibrary.description("afterglow") == "When @icon(illusion) is removed during combat, it leaves @icon(illuminate) 1 @icon(time) 2 at its final tile.", "Afterglow should disclose removal timing and duration")
	expect.call(SkillTreeLibrary.description("open_sky") == "While you stand in @icon(illuminate), you have @icon(truesight).", "Open Sky should state its conditional Truesight rule")
	var afterimage_health: int = GameData.fixed_point_amount(int(SkillTreeLibrary.effect("afterimage").get("health_visible", 0)))
	var reserve_health: int = GameData.fixed_point_amount(int(SkillTreeLibrary.effect("last_reserve").get("minimum_health_visible", 0)))
	var last_door_health: int = GameData.fixed_point_amount(int(SkillTreeLibrary.effect("last_door").get("minimum_health_visible", 0)))
	expect.call(SkillTreeLibrary.description("afterimage").contains(str(afterimage_health)), "Afterimage copy should match the health shown on its illusion")
	expect.call(SkillTreeLibrary.description("last_reserve").contains(str(reserve_health)), "Last Reserve copy should match the surviving health shown in combat")
	expect.call(SkillTreeLibrary.description("last_door").contains(str(last_door_health)), "Last Door copy should match the returning health shown in the run UI")
	expect.call(SkillTreeLibrary.description("ghost_stride") == "Once per combat, arm so your next movement becomes @icon(blink) 2.", "Ghost Stride copy should describe its translated independent-movement trigger")
	expect.call(SkillTreeLibrary.description("pain_remembers") == "After you first lose @icon(health) each combat, the next non-item card discarded while your hand has room returns to it.", "Pain Remembers copy should disclose that a full hand delays its recall")
	expect.call(SkillTreeLibrary.description("prismatic_instinct") == "Once per combat, name a card with an @icon(elemental_intensity) condition in hand. The next printed play of any copy satisfies all such conditions.", "Prismatic Instinct copy should describe its card-name scope and printed-play trigger")
	expect.call(SkillTreeLibrary.description("curators_patience") == "After choosing a relic, save one unchosen relic for your next relic offer.", "Curator's Patience copy should identify the next relic offer")
	expect.call(SkillTreeLibrary.description("living_shadow") == "Once between your turns, when @icon(illusion) is destroyed or dispelled, return your most recently discarded non-item card to hand—or put it atop your draw pile if your hand is full.", "Living Shadow copy should use turn cadence, identify both illusion-removal triggers, and define a full hand")
	expect.call(SkillTreeLibrary.description("layaway") == "Once between bosses, hold one ware for the next Scavenger visit. A pending hold blocks future uses until it returns.", "Layaway copy should identify the unified Scavenger and disclose that an unresolved hold blocks another use")
	expect.call(SkillTreeLibrary.description("open_arsenal") == "Equip any equipment in your trinket slot, ignoring its normal slot.", "Open Arsenal copy should explain which equipment restriction it ignores")
	expect.call(SkillTreeLibrary.description("confluence") == "@icon(elemental_intensity) conditions use your highest value, regardless of element. @icon(draw) enabled solely by Confluence stops before it would trigger @icon(fatigue).", "Confluence copy should distinguish condition substitution from real intensity")
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
	var learn_attempts: int = 0
	while ProgressionStore.unspent_skill_points(profile) > 0 and learn_attempts < SkillTreeLibrary.COMPLETE_BUILD_SIZE:
		learn_attempts += 1
		var available: Array[String] = ProgressionStore.available_skill_ids(profile)
		var choice: String = available[0] if not available.is_empty() else ""
		if choice.is_empty():
			expect.call(false, "A completion-aware build should never strand banked points: selected=%s" % [ProgressionStore.selected_skill_ids(profile)])
			break
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
	var legacy_selection: Array[String] = _topological_non_keystone_selection(SkillTreeLibrary.COMPLETE_BUILD_SIZE)
	expect.call(legacy_selection.size() == SkillTreeLibrary.COMPLETE_BUILD_SIZE, "The expanded tree should still admit a topologically complete no-keystone legacy fixture")
	expect.call(not SkillTreeLibrary.selection_is_valid(legacy_selection, SkillTreeLibrary.COMPLETE_BUILD_SIZE), "A maximum build without a keystone should be rejected")
	var repaired: Array[String] = SkillTreeLibrary.repaired_selection(legacy_selection, SkillTreeLibrary.COMPLETE_BUILD_SIZE, legacy_selection)
	expect.call(SkillTreeLibrary.selection_is_valid(repaired, SkillTreeLibrary.COMPLETE_BUILD_SIZE), "A legacy maximum build should repair to a complete legal selection")
	expect.call(_keystone_count(repaired) == 1, "Repairing a legacy maximum build should insert exactly one eligible keystone")
	var preserved_legacy_count: int = 0
	for repaired_id: String in repaired:
		if legacy_selection.has(repaired_id):
			preserved_legacy_count += 1
	expect.call(preserved_legacy_count == SkillTreeLibrary.COMPLETE_BUILD_SIZE - 1, "Legacy repair should preserve the maximum deterministic subset before inserting one legal keystone")

	var partial: Array[String] = _topological_non_keystone_selection(SkillTreeLibrary.COMPLETE_BUILD_SIZE - 1)
	var available: Array[String] = SkillTreeLibrary.available_ids(partial)
	expect.call(not available.is_empty(), "An 18-point no-keystone build should retain at least one keystone continuation")
	for available_id: String in available:
		expect.call(SkillTreeLibrary.is_keystone(available_id), "The final point of a complete build should offer only keystones")
	for non_keystone_id: String in non_keystone_ids:
		var final_non_keystone: Array[String] = partial.duplicate()
		final_non_keystone.append(non_keystone_id)
		if not partial.has(non_keystone_id) and _selection_is_topologically_valid_without_capstone(final_non_keystone):
			expect.call(SkillTreeLibrary.locked_reason(non_keystone_id, partial) == "Your final skill must be a keystone", "A blocked final non-keystone should explain the capstone requirement")

	var safe_seventeen: Array[String]
	safe_seventeen.append_array([
		"quick_wits", "measured_breath", "ghost_stride", "discerning_eye", "long_dawn",
		"rehearsed_escape", "makeshift_tool", "carry_the_guard", "pain_remembers",
		"sure_footed", "afterimage", "deferred_choice", "salvager", "sunpath", "witchlight",
		"last_reserve", "plunderers_step"
	])
	expect.call(SkillTreeLibrary.selection_is_valid(safe_seventeen, 17), "The capstone reachability fixture should be a legal 17-point selection")
	expect.call(not SkillTreeLibrary.is_available("curators_patience", safe_seventeen), "A legal-looking 18th non-keystone that strands every capstone should be blocked before purchase")
	expect.call(SkillTreeLibrary.locked_reason("curators_patience", safe_seventeen) == "This choice would leave no path to a keystone", "A dead-ending earlier choice should explain why it is blocked")
	var safe_eighteen: Array[String] = safe_seventeen.duplicate()
	safe_eighteen.append("borrowed_time")
	expect.call(SkillTreeLibrary.is_available("encore", safe_eighteen), "An authored-prerequisite-valid keystone should remain available as the final point")
	for unavailable_keystone_id: String in ["open_arsenal", "confluence", "last_door", "open_sky"]:
		expect.call(not SkillTreeLibrary.is_available(unavailable_keystone_id, safe_eighteen), "%s should remain locked at point 19 when its authored parents are missing" % unavailable_keystone_id)
		expect.call(SkillTreeLibrary.locked_reason(unavailable_keystone_id, safe_eighteen).begins_with("Requires "), "%s should name its missing authored prerequisite at point 19" % unavailable_keystone_id)

	for keystone_id: String in SkillTreeLibrary.ordered_ids():
		if not SkillTreeLibrary.is_keystone(keystone_id):
			continue
		var preference: Array[String] = _recursive_prerequisites(keystone_id)
		for non_keystone_id: String in non_keystone_ids:
			if not preference.has(non_keystone_id):
				preference.append(non_keystone_id)
		var keystone_partial: Array[String] = SkillTreeLibrary.repaired_selection([], SkillTreeLibrary.COMPLETE_BUILD_SIZE - 1, preference)
		expect.call(SkillTreeLibrary.available_ids(keystone_partial).has(keystone_id), "%s should remain a legal final-point keystone when its branch is deliberately assembled" % keystone_id)
		for partial_count: int in range(SkillTreeLibrary.COMPLETE_BUILD_SIZE):
			var reachable_partial: Array[String] = SkillTreeLibrary.repaired_selection([], partial_count, preference)
			expect.call(reachable_partial.size() == partial_count, "%s preference should admit a reachable %d-point partial build" % [keystone_id, partial_count])
			if _keystone_count(reachable_partial) == 0:
				var reachable_completion: Array[String] = SkillTreeLibrary.repaired_selection(reachable_partial, SkillTreeLibrary.COMPLETE_BUILD_SIZE, preference)
				expect.call(SkillTreeLibrary.selection_is_valid(reachable_completion, SkillTreeLibrary.COMPLETE_BUILD_SIZE), "Every reachable no-keystone %s partial at %d points should retain a legal complete path" % [keystone_id, partial_count])

	var legacy_profile: Dictionary = ProgressionStore.default_data()
	legacy_profile["progression_schema"] = 3
	legacy_profile["level"] = 20
	legacy_profile["skill_ids"] = legacy_selection.duplicate()
	legacy_profile["progression_revision"] = 7
	var migrated_profile: Dictionary = ProgressionStore.normalized_data(legacy_profile)
	expect.call(int(migrated_profile.get("progression_schema", 0)) == ProgressionStore.PROGRESSION_SCHEMA, "No-keystone maximum profiles should migrate to the current progression schema")
	expect.call(int(migrated_profile.get("progression_revision", 0)) == 8, "Changing a legacy maximum build during migration should advance its progression revision")
	expect.call(SkillTreeLibrary.selection_is_valid(ProgressionStore.selected_skill_ids(migrated_profile), SkillTreeLibrary.COMPLETE_BUILD_SIZE), "The migrated maximum profile should remain complete and legal")
	expect.call(_keystone_count(ProgressionStore.selected_skill_ids(migrated_profile)) == 1, "The migrated maximum profile should contain exactly one keystone")

static func _topological_non_keystone_selection(limit: int) -> Array[String]:
	var result: Array[String]
	while result.size() < limit:
		var added: bool = false
		for skill_id: String in SkillTreeLibrary.ordered_ids():
			if result.has(skill_id) or SkillTreeLibrary.is_keystone(skill_id):
				continue
			var prerequisites_met: bool = true
			for prerequisite_id: String in SkillTreeLibrary.prerequisites(skill_id):
				if not result.has(prerequisite_id):
					prerequisites_met = false
					break
			if prerequisites_met and result.size() >= SkillTreeLibrary.minimum_owned(skill_id):
				result.append(skill_id)
				added = true
				if result.size() >= limit:
					break
		if not added:
			break
	return result

static func _recursive_prerequisites(skill_id: String) -> Array[String]:
	var result: Array[String]
	for prerequisite_id: String in SkillTreeLibrary.prerequisites(skill_id):
		for ancestor_id: String in _recursive_prerequisites(prerequisite_id):
			if not result.has(ancestor_id):
				result.append(ancestor_id)
		if not result.has(prerequisite_id):
			result.append(prerequisite_id)
	return result

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
	var original_completion_cache: Dictionary = SkillTreeLibrary._completion_cache.duplicate(true)
	SkillTreeLibrary._cache = altered_definitions
	SkillTreeLibrary._ordered_ids_cache.clear()
	SkillTreeLibrary._completion_cache.clear()
	var errors: Array[String] = SkillTreeLibrary.validation_errors()
	SkillTreeLibrary._cache = original_cache
	SkillTreeLibrary._ordered_ids_cache = original_order
	SkillTreeLibrary._completion_cache = original_completion_cache
	return errors

static func _contains_error_fragment(errors: Array[String], fragment: String) -> bool:
	for error: String in errors:
		if error.to_lower().contains(fragment.to_lower()):
			return true
	return false
