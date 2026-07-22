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
	_test_leveling_requires_exactly_one_legal_skill(expect)
	_test_keystones_are_exclusive(expect)
	_test_respec_is_transactional(expect)
	_test_legacy_profile_migration(expect)

static func _test_skill_data_and_topology(expect: Callable) -> void:
	expect.call(SkillTreeLibrary.definitions().size() == 24, "The skill tree should define exactly 24 skills")
	expect.call(SkillTreeLibrary.validation_errors().is_empty(), "The skill graph should have valid data, positions, prerequisites, and a complete level-20 route")
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
	expect.call(SkillTreeLibrary.description("pain_remembers") == "After your first health loss each combat, when your hand has room, return your next non-item discard to it.", "Pain Remembers copy should disclose that a full hand delays its recall")
	expect.call(SkillTreeLibrary.description("prismatic_instinct") == "Once per combat, name a card with an intensity condition in hand. The next printed play of any copy satisfies all its intensity conditions. Basic uses do not consume this.", "Prismatic Instinct copy should describe its card-name scope and printed-play trigger")
	expect.call(SkillTreeLibrary.description("curators_patience") == "After choosing a relic, save one unchosen relic for your next relic offer.", "Curator's Patience copy should identify the next relic offer")
	expect.call(SkillTreeLibrary.description("living_shadow") == "Once until your next activation, a destroyed or dispelled illusion returns your latest non-item discard to hand, or atop your draw pile if full.", "Living Shadow copy should use activation cadence and identify both illusion-removal triggers")
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

static func _test_leveling_requires_exactly_one_legal_skill(expect: Callable) -> void:
	var profile: Dictionary = ProgressionStore.set_embers(ProgressionStore.default_data(), GameData.progression_level_total_cost(20))
	var before: Dictionary = profile.duplicate(true)
	profile = ProgressionStore.purchase_level_with_skill(profile, "borrowed_time")
	expect.call(profile == before, "A level purchase should reject a skill with missing prerequisites without spending embers")
	var chosen_keystone: String = ""
	for target_level: int in range(2, 21):
		var available: Array[String] = ProgressionStore.available_skill_ids(profile)
		var choice: String = available[0] if not available.is_empty() else ""
		if ProgressionStore.selected_skill_ids(profile).size() >= 8 and chosen_keystone.is_empty():
			for candidate_id: String in available:
				if SkillTreeLibrary.is_keystone(candidate_id):
					choice = candidate_id
					chosen_keystone = candidate_id
					break
		var level_before: int = int(profile.get("level", 1))
		var count_before: int = ProgressionStore.selected_skill_ids(profile).size()
		profile = ProgressionStore.purchase_level_with_skill(profile, choice)
		expect.call(int(profile.get("level", 1)) == level_before + 1, "Each paid level should advance exactly once")
		expect.call(ProgressionStore.selected_skill_ids(profile).size() == count_before + 1, "Each paid level should learn exactly one skill")
		expect.call(ProgressionStore.has_skill(profile, choice), "The chosen skill should be retained after normalization")
	expect.call(int(profile.get("level", 0)) == 20, "The skill flow should reach level 20")
	expect.call(ProgressionStore.selected_skill_ids(profile).size() == 19, "A level-20 profile should own exactly 19 skills")
	expect.call(not chosen_keystone.is_empty(), "A legal progression route should be able to choose a keystone")
	expect.call(not ProgressionStore.can_level_up(profile), "A level-20 profile should not be able to buy another skill")

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
	expect.call(keystone_count <= 1, "A normalized build should never contain more than one keystone")
	if keystone_count == 1:
		for available_id: String in ProgressionStore.available_skill_ids(profile):
			expect.call(not SkillTreeLibrary.is_keystone(available_id), "Learning one keystone should lock the other keystones")

static func _test_respec_is_transactional(expect: Callable) -> void:
	var profile: Dictionary = ProgressionStore.default_data()
	profile["level"] = 6
	profile["skill_ids"] = SkillTreeLibrary.repaired_selection([], 5)
	profile["moltshards"] = 1
	profile = ProgressionStore.normalized_data(profile)
	var original_skills: Array[String] = ProgressionStore.selected_skill_ids(profile)
	var invalid: Array = original_skills.duplicate()
	invalid.pop_front()
	var rejected: Dictionary = ProgressionStore.respec_skills(profile, invalid)
	expect.call(ProgressionStore.moltshard_count(rejected) == 1, "An invalid respec should not consume its Moltshard")
	expect.call(ProgressionStore.selected_skill_ids(rejected) == original_skills, "An invalid respec should not partially change the build")
	expect.call(not ProgressionStore.can_respec_skills(profile, original_skills), "Rebuilding the identical set should not waste a Moltshard")
	var unchanged: Dictionary = ProgressionStore.respec_skills(profile, original_skills)
	expect.call(ProgressionStore.moltshard_count(unchanged) == 1 and int(unchanged.get("progression_revision", 0)) == int(profile.get("progression_revision", 0)), "An identical rebuild should preserve its resource and revision")
	var duplicate: Array = original_skills.duplicate()
	duplicate[duplicate.size() - 1] = duplicate[0]
	expect.call(not ProgressionStore.can_respec_skills(profile, duplicate), "A duplicate-id replacement build should be rejected")
	var unknown: Array = original_skills.duplicate()
	unknown[unknown.size() - 1] = "unknown_skill"
	expect.call(not ProgressionStore.can_respec_skills(profile, unknown), "An unknown-id replacement build should be rejected")
	var oversized: Array = original_skills.duplicate()
	for available_id: String in SkillTreeLibrary.available_ids(original_skills):
		oversized.append(available_id)
		break
	expect.call(not ProgressionStore.can_respec_skills(profile, oversized), "An oversized replacement build should be rejected")
	var alternate_order: Array[String]
	alternate_order.append_array(["discerning_eye", "ghost_stride", "sure_footed", "deferred_choice", "salvager"])
	var alternate: Array[String] = SkillTreeLibrary.repaired_selection([], 5, alternate_order)
	expect.call(ProgressionStore.can_respec_skills(profile, alternate), "A different complete legal build should be confirmable")
	var respecced: Dictionary = ProgressionStore.respec_skills(profile, alternate)
	expect.call(ProgressionStore.moltshard_count(respecced) == 0, "A confirmed respec should consume exactly one Moltshard")
	expect.call(ProgressionStore.selected_skill_ids(respecced) == alternate, "A confirmed respec should replace the whole build atomically")
	expect.call(not ProgressionStore.can_respec_skills(respecced, original_skills), "A profile without a Moltshard should not begin another respec")

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
	SkillTreeLibrary._cache = altered_definitions
	var errors: Array[String] = SkillTreeLibrary.validation_errors()
	SkillTreeLibrary._cache = original_cache
	return errors

static func _contains_error_fragment(errors: Array[String], fragment: String) -> bool:
	for error: String in errors:
		if error.to_lower().contains(fragment.to_lower()):
			return true
	return false
