extends RefCounted

const SkillTreeLibrary = preload("res://scripts/skill_tree_library.gd")


# Preserve the original exhaustive candidate construction as an independent
# search oracle. It shares only unchanged data/validity predicates with the
# production library and never calls the optimized completion routine/cache.
class OriginalCompletion:
	extends RefCounted

	var cache: Dictionary = {}
	var last_path: Array[String]
	var authored_checks: int = 0

	func available_ids(selected_value: Variant) -> Array[String]:
		var result: Array[String]
		for skill_id: String in SkillTreeLibrary.ordered_ids():
			if not SkillTreeLibrary.is_player_visible(skill_id):
				continue
			var selected: Array[String] = SkillTreeLibrary.normalized_ids(selected_value)
			if selected.size() >= SkillTreeLibrary.COMPLETE_BUILD_SIZE or not _authored_available(skill_id, selected):
				continue
			var proposed: Array[String] = selected.duplicate()
			proposed.append(skill_id)
			if can_reach_complete_build(proposed):
				result.append(skill_id)
		return result

	func can_reach_complete_build(selected_value: Variant) -> bool:
		var selected: Array[String] = SkillTreeLibrary.normalized_ids(selected_value)
		if selected.size() > SkillTreeLibrary.COMPLETE_BUILD_SIZE or not SkillTreeLibrary.selection_is_valid(selected):
			return false
		var cache_key: String = SkillTreeLibrary._selection_cache_key(selected)
		if cache.has(cache_key):
			return bool(cache[cache_key])
		if selected.size() == SkillTreeLibrary.COMPLETE_BUILD_SIZE:
			cache[cache_key] = true
			return true
		cache[cache_key] = false
		for keystone_id: String in SkillTreeLibrary._completion_keystone_candidates(selected):
			if can_complete_with_keystone(selected, keystone_id):
				cache[cache_key] = true
				return true
		return false

	func can_complete_with_keystone(selected: Array[String], keystone_id: String) -> bool:
		var cache_key: String = "keystone:%s:%s" % [keystone_id, SkillTreeLibrary._selection_cache_key(selected)]
		if cache.has(cache_key):
			return bool(cache[cache_key])
		var working: Array[String] = selected.duplicate()
		var prerequisite_lookup: Dictionary = SkillTreeLibrary._recursive_prerequisite_lookup(keystone_id)
		while working.size() < SkillTreeLibrary.COMPLETE_BUILD_SIZE:
			var priority_candidates: Array[String]
			var filler_candidates: Array[String]
			for candidate_id: String in SkillTreeLibrary.ordered_ids():
				if SkillTreeLibrary.is_keystone(candidate_id) and candidate_id != keystone_id:
					continue
				if not _authored_available(candidate_id, working):
					continue
				if candidate_id == keystone_id or (prerequisite_lookup.has(candidate_id) and not working.has(candidate_id)):
					priority_candidates.append(candidate_id)
				else:
					filler_candidates.append(candidate_id)
			var candidates: Array[String] = priority_candidates if not priority_candidates.is_empty() else filler_candidates
			if candidates.is_empty():
				cache[cache_key] = false
				last_path = working.duplicate()
				return false
			working.append(candidates[0])
		var complete: bool = working.has(keystone_id) and SkillTreeLibrary.selection_is_valid(working, SkillTreeLibrary.COMPLETE_BUILD_SIZE)
		cache[cache_key] = complete
		last_path = working.duplicate()
		return complete

	func _authored_available(skill_id: String, selected: Array[String]) -> bool:
		authored_checks += 1
		return SkillTreeLibrary._is_authored_available(skill_id, selected)


static func run(expect: Callable) -> void:
	SkillTreeLibrary._completion_cache.clear()
	_test_authored_selections(expect)
	_test_blocked_graphs(expect)
	SkillTreeLibrary._completion_cache.clear()


static func _test_authored_selections(expect: Callable) -> void:
	var oracle := OriginalCompletion.new()
	_assert_selection([], "empty root selection", oracle, expect)
	for skill_id: String in SkillTreeLibrary.ordered_ids():
		_assert_selection([skill_id], "single %s" % skill_id, oracle, expect)
	for malformed: Variant in [null, 7, "quick_wits", {}, ["unknown_skill"], ["quick_wits", "quick_wits"], ["quick_wits", "unknown_skill", 7], [[], {}, "long_dawn"], ["encore", "open_sky"], ["layaway"]]:
		_assert_selection(malformed, "malformed/legacy %s" % str(malformed), oracle, expect)

	for keystone_id: String in SkillTreeLibrary.ordered_ids():
		if not SkillTreeLibrary.is_keystone(keystone_id):
			continue
		var route_oracle := OriginalCompletion.new()
		var empty: Array[String]
		expect.call(route_oracle.can_complete_with_keystone(empty, keystone_id), "%s reference route should reach a full legal build" % keystone_id)
		var route: Array[String] = route_oracle.last_path.duplicate()
		expect.call(route.size() == SkillTreeLibrary.COMPLETE_BUILD_SIZE and route.has(keystone_id), "%s route must exercise its chosen keystone and the exact cap" % keystone_id)
		for prefix_size: int in range(route.size() + 1):
			var prefix: Array[String]
			prefix.assign(route.slice(0, prefix_size))
			_assert_selection(prefix, "%s prefix %d" % [keystone_id, prefix_size], oracle, expect)
			# Exercise each internal keystone branch independently, including an
			# existing different keystone and routes that cannot be completed.
			if prefix_size in [0, 1, 8, 17, 18, 19]:
				for target_id: String in SkillTreeLibrary._completion_keystone_candidates(empty):
					var original: bool = oracle.can_complete_with_keystone(prefix, target_id)
					expect.call(SkillTreeLibrary._selection_can_complete_with_keystone(prefix, target_id) == original, "%s prefix %d toward %s must retain the original completion result" % [keystone_id, prefix_size, target_id])
		var no_keystone: Array[String] = route.duplicate()
		no_keystone.erase(keystone_id)
		_assert_selection(no_keystone, "%s removed at cap" % keystone_id, oracle, expect)
		var over_cap: Array[String] = route.duplicate()
		for skill_id: String in SkillTreeLibrary.ordered_ids():
			if not over_cap.has(skill_id):
				over_cap.append(skill_id)
				break
		_assert_selection(over_cap, "%s over cap" % keystone_id, oracle, expect)
		var duplicate_at_cap: Array[String] = route.duplicate()
		duplicate_at_cap.append(route[0])
		_assert_selection(duplicate_at_cap, "%s duplicate at cap" % keystone_id, oracle, expect)

	var without_keystone: Array[String]
	while without_keystone.size() < SkillTreeLibrary.COMPLETE_BUILD_SIZE - 1:
		var chosen: String = ""
		for skill_id: String in SkillTreeLibrary.ordered_ids():
			if not SkillTreeLibrary.is_keystone(skill_id) and SkillTreeLibrary._is_authored_available(skill_id, without_keystone):
				chosen = skill_id
				break
		if chosen.is_empty():
			break
		without_keystone.append(chosen)
	expect.call(without_keystone.size() == 18, "The non-keystone fixture should reach the last available slot")
	_assert_selection(without_keystone, "18 skills without keystone", oracle, expect)


static func _test_blocked_graphs(expect: Callable) -> void:
	var authored: Dictionary = SkillTreeLibrary.definitions().duplicate(true)
	for blocker: String in ["minimum_owned", "exclusive_group"]:
		var altered: Dictionary = authored.duplicate(true)
		for skill_id: String in altered:
			if blocker == "minimum_owned":
				(altered[skill_id] as Dictionary)[blocker] = 1
			else:
				(altered[skill_id] as Dictionary)[blocker] = "test_lock"
		SkillTreeLibrary.clear_cache()
		SkillTreeLibrary._cache = altered
		var oracle := OriginalCompletion.new()
		_assert_selection([], "%s blocked empty graph" % blocker, oracle, expect)
		_assert_selection(["quick_wits"], "%s blocked single root" % blocker, oracle, expect)
		expect.call(not SkillTreeLibrary._selection_can_reach_complete_build([]), "%s fixture should have no complete route" % blocker)
	SkillTreeLibrary.clear_cache()
	SkillTreeLibrary._cache = authored


static func _assert_selection(value: Variant, label: String, oracle: OriginalCompletion, expect: Callable) -> void:
	var before: Variant = value.duplicate(true) if typeof(value) in [TYPE_ARRAY, TYPE_DICTIONARY] else value
	var expected_complete: bool = oracle.can_reach_complete_build(value)
	expect.call(SkillTreeLibrary._selection_can_reach_complete_build(value) == expected_complete, "%s must preserve completion reachability" % label)
	var expected_available: Array[String] = oracle.available_ids(value)
	var actual_available: Array[String] = SkillTreeLibrary.available_ids(value)
	expect.call(actual_available == expected_available, "%s must preserve exact availability ordering: expected %s, actual %s" % [label, expected_available, actual_available])
	expect.call(SkillTreeLibrary.available_ids(value) == expected_available, "%s warm completion cache must retain availability ordering" % label)
	expect.call(value == before, "%s completion checks must not mutate the caller's selection" % label)
