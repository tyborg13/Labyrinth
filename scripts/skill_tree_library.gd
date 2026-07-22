extends RefCounted
class_name SkillTreeLibrary

const SKILLS_PATH: String = "res://data/skills.json"
const KEYSTONE_GROUP: String = "keystone"
const COMPLETE_BUILD_SIZE: int = 19
const BRANCH_ORDER = ["tactics", "resolve", "traverse", "foresight", "keystone"]
const LAYOUT_CANVAS_SIZE: Vector2i = Vector2i(1000, 540)
const LAYOUT_NODE_SIZES: Dictionary = {
	"root": Vector2i(56, 56),
	"branch": Vector2i(52, 52),
	"junction": Vector2i(56, 56),
	"keystone": Vector2i(64, 64),
}

static var _cache: Dictionary = {}

static func definitions() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	if not FileAccess.file_exists(SKILLS_PATH):
		push_error("Skill data is missing at %s." % SKILLS_PATH)
		return {}
	var file: FileAccess = FileAccess.open(SKILLS_PATH, FileAccess.READ)
	if file == null:
		push_error("Skill data could not be opened at %s." % SKILLS_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Skill data must be a dictionary.")
		return {}
	_cache = (parsed as Dictionary).duplicate(true)
	return _cache

static func clear_cache() -> void:
	_cache.clear()

static func ordered_ids() -> Array[String]:
	var result: Array[String]
	for skill_id_var: Variant in definitions().keys():
		result.append(str(skill_id_var))
	result.sort_custom(func(left: String, right: String) -> bool:
		var left_def: Dictionary = definitions().get(left, {}) as Dictionary
		var right_def: Dictionary = definitions().get(right, {}) as Dictionary
		var left_pos: Vector2i = position(left)
		var right_pos: Vector2i = position(right)
		if left_pos.y != right_pos.y:
			return left_pos.y < right_pos.y
		if left_pos.x != right_pos.x:
			return left_pos.x < right_pos.x
		return str(left_def.get("name", left)) < str(right_def.get("name", right))
	)
	return result

static func definition(skill_id: String) -> Dictionary:
	return (definitions().get(skill_id, {}) as Dictionary).duplicate(true)

static func has_definition(skill_id: String) -> bool:
	return definitions().has(skill_id)

static func display_name(skill_id: String) -> String:
	return str((definitions().get(skill_id, {}) as Dictionary).get("name", skill_id))

static func description(skill_id: String) -> String:
	return str((definitions().get(skill_id, {}) as Dictionary).get("description", ""))

static func icon_key(skill_id: String) -> String:
	return str((definitions().get(skill_id, {}) as Dictionary).get("icon", ""))

static func tier(skill_id: String) -> String:
	return str((definitions().get(skill_id, {}) as Dictionary).get("tier", "branch"))

static func position(skill_id: String) -> Vector2i:
	var raw: Variant = (definitions().get(skill_id, {}) as Dictionary).get("position", [])
	if typeof(raw) != TYPE_ARRAY or (raw as Array).size() < 2:
		return Vector2i.ZERO
	return Vector2i(int((raw as Array)[0]), int((raw as Array)[1]))

static func layout_position(skill_id: String) -> Vector2i:
	var raw: Variant = (definitions().get(skill_id, {}) as Dictionary).get("layout_position", [])
	if not _is_valid_layout_position(raw):
		return Vector2i.ZERO
	return Vector2i(int((raw as Array)[0]), int((raw as Array)[1]))

static func layout_node_size(skill_id: String) -> Vector2i:
	return LAYOUT_NODE_SIZES.get(tier(skill_id), LAYOUT_NODE_SIZES["branch"]) as Vector2i

static func prerequisites(skill_id: String) -> Array[String]:
	return _unique_known_ids((definitions().get(skill_id, {}) as Dictionary).get("prerequisites", []))

static func minimum_owned(skill_id: String) -> int:
	return maxi(0, int((definitions().get(skill_id, {}) as Dictionary).get("minimum_owned", 0)))

static func exclusive_group(skill_id: String) -> String:
	return str((definitions().get(skill_id, {}) as Dictionary).get("exclusive_group", ""))

static func is_keystone(skill_id: String) -> bool:
	return tier(skill_id) == "keystone"

static func activation_kind(skill_id: String) -> String:
	return str((definitions().get(skill_id, {}) as Dictionary).get("activation", "automatic"))

static func effect(skill_id: String) -> Dictionary:
	return ((definitions().get(skill_id, {}) as Dictionary).get("effect", {}) as Dictionary).duplicate(true)

static func effect_type(skill_id: String) -> String:
	return str(effect(skill_id).get("type", ""))

static func skill_id_for_effect(effect_id: String) -> String:
	for skill_id: String in ordered_ids():
		if effect_type(skill_id) == effect_id:
			return skill_id
	return ""

static func normalized_ids(value: Variant) -> Array[String]:
	return _unique_known_ids(value)

static func selection_is_valid(value: Variant, exact_count: int = -1) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return exact_count == 0
	var raw: Array = value as Array
	var selected: Array[String] = normalized_ids(raw)
	if selected.size() != raw.size():
		return false
	if exact_count >= 0 and selected.size() != exact_count:
		return false
	var selected_lookup: Dictionary = _lookup(selected)
	var exclusive_counts: Dictionary = {}
	for skill_id: String in selected:
		for prerequisite_id: String in prerequisites(skill_id):
			if not selected_lookup.has(prerequisite_id):
				return false
		if selected.size() - 1 < minimum_owned(skill_id):
			return false
		var group_id: String = exclusive_group(skill_id)
		if group_id.is_empty():
			continue
		exclusive_counts[group_id] = int(exclusive_counts.get(group_id, 0)) + 1
		if int(exclusive_counts[group_id]) > 1:
			return false
	if selected.size() == COMPLETE_BUILD_SIZE and int(exclusive_counts.get(KEYSTONE_GROUP, 0)) != 1:
		return false
	return true

static func is_available(skill_id: String, selected_value: Variant) -> bool:
	if not has_definition(skill_id):
		return false
	var selected: Array[String] = normalized_ids(selected_value)
	if selected.has(skill_id):
		return false
	var selected_lookup: Dictionary = _lookup(selected)
	for prerequisite_id: String in prerequisites(skill_id):
		if not selected_lookup.has(prerequisite_id):
			return false
	if selected.size() < minimum_owned(skill_id):
		return false
	var group_id: String = exclusive_group(skill_id)
	if not group_id.is_empty():
		for selected_id: String in selected:
			if exclusive_group(selected_id) == group_id:
				return false
	var proposed: Array[String] = selected.duplicate()
	proposed.append(skill_id)
	return selection_is_valid(proposed)

static func available_ids(selected_value: Variant) -> Array[String]:
	var result: Array[String]
	for skill_id: String in ordered_ids():
		if is_available(skill_id, selected_value):
			result.append(skill_id)
	return result

static func locked_reason(skill_id: String, selected_value: Variant) -> String:
	if not has_definition(skill_id):
		return "Unknown skill."
	var selected: Array[String] = normalized_ids(selected_value)
	if selected.has(skill_id):
		return "Learned"
	if selected.size() == COMPLETE_BUILD_SIZE - 1 and not _selection_has_keystone(selected) and not is_keystone(skill_id):
		return "Your final skill must be a keystone"
	var group_id: String = exclusive_group(skill_id)
	if not group_id.is_empty():
		for selected_id: String in selected:
			if exclusive_group(selected_id) == group_id:
				return "Another keystone is selected"
	var missing_names: Array[String]
	for prerequisite_id: String in prerequisites(skill_id):
		if not selected.has(prerequisite_id):
			missing_names.append(display_name(prerequisite_id))
	if not missing_names.is_empty():
		return "Requires %s" % ", ".join(missing_names)
	var required_owned: int = minimum_owned(skill_id)
	if selected.size() < required_owned:
		return "Requires %d learned skills" % required_owned
	return "Available"

static func _selection_has_keystone(selected: Array[String]) -> bool:
	for skill_id: String in selected:
		if is_keystone(skill_id):
			return true
	return false

static func dependent_ids(skill_id: String, selected_value: Variant) -> Array[String]:
	var selected: Array[String] = normalized_ids(selected_value)
	var selected_lookup: Dictionary = _lookup(selected)
	var result: Array[String]
	var changed: bool = true
	while changed:
		changed = false
		for candidate_id: String in selected:
			if candidate_id == skill_id or result.has(candidate_id):
				continue
			for prerequisite_id: String in prerequisites(candidate_id):
				if prerequisite_id == skill_id or result.has(prerequisite_id):
					result.append(candidate_id)
					changed = true
					break
	for candidate_id: String in result.duplicate():
		if not selected_lookup.has(candidate_id):
			result.erase(candidate_id)
	return result

static func repaired_selection(value: Variant, target_count: int, preferred_order: Variant = []) -> Array[String]:
	var safe_target: int = clampi(target_count, 0, maxi(0, definitions().size()))
	var source: Array[String] = normalized_ids(value)
	var preference: Array[String] = _unique_known_ids(preferred_order)
	for skill_id: String in source:
		if not preference.has(skill_id):
			preference.append(skill_id)
	for skill_id: String in ordered_ids():
		if not preference.has(skill_id):
			preference.append(skill_id)
	var result: Array[String]
	var progress: bool = true
	while result.size() < safe_target and progress:
		progress = false
		for skill_id: String in preference:
			if result.size() >= safe_target:
				break
			if result.has(skill_id) or not source.has(skill_id):
				continue
			if is_available(skill_id, result):
				result.append(skill_id)
				progress = true
	while result.size() < safe_target:
		var available: Array[String] = available_ids(result)
		if available.is_empty():
			break
		var chosen_id: String = ""
		for skill_id: String in preference:
			if available.has(skill_id):
				chosen_id = skill_id
				break
		if chosen_id.is_empty():
			chosen_id = available[0]
		result.append(chosen_id)
	return result

static func validation_errors() -> Array[String]:
	var errors: Array[String]
	var seen_positions: Dictionary = {}
	var seen_layout_positions: Dictionary = {}
	for skill_id: String in ordered_ids():
		var skill_def: Dictionary = definitions().get(skill_id, {}) as Dictionary
		if str(skill_def.get("name", "")).strip_edges().is_empty():
			errors.append("%s has no name." % skill_id)
		if str(skill_def.get("description", "")).strip_edges().is_empty():
			errors.append("%s has no description." % skill_id)
		if str(skill_def.get("icon", "")).strip_edges().is_empty():
			errors.append("%s has no icon." % skill_id)
		if effect_type(skill_id).is_empty():
			errors.append("%s has no effect type." % skill_id)
		var position_key: String = str(position(skill_id))
		if seen_positions.has(position_key):
			errors.append("%s shares a position with %s." % [skill_id, str(seen_positions[position_key])])
		seen_positions[position_key] = skill_id
		var raw_layout_position: Variant = skill_def.get("layout_position", null)
		if not _is_valid_layout_position(raw_layout_position):
			errors.append("%s layout_position must contain exactly two integer coordinates." % skill_id)
		else:
			var skill_layout_position: Vector2i = layout_position(skill_id)
			var layout_key: String = str(skill_layout_position)
			if seen_layout_positions.has(layout_key):
				errors.append("%s shares a layout position with %s." % [skill_id, str(seen_layout_positions[layout_key])])
			seen_layout_positions[layout_key] = skill_id
			var half_size: Vector2i = layout_node_size(skill_id) / 2
			if (
				skill_layout_position.x - half_size.x < 0
				or skill_layout_position.y - half_size.y < 0
				or skill_layout_position.x + half_size.x > LAYOUT_CANVAS_SIZE.x
				or skill_layout_position.y + half_size.y > LAYOUT_CANVAS_SIZE.y
			):
				errors.append("%s layout_position places its medallion outside the %s canvas." % [skill_id, LAYOUT_CANVAS_SIZE])
		var raw_prerequisites: Variant = skill_def.get("prerequisites", [])
		if typeof(raw_prerequisites) != TYPE_ARRAY:
			errors.append("%s prerequisites must be an array." % skill_id)
			continue
		for prerequisite_var: Variant in raw_prerequisites as Array:
			var prerequisite_id: String = str(prerequisite_var)
			if prerequisite_id == skill_id:
				errors.append("%s requires itself." % skill_id)
			elif not has_definition(prerequisite_id):
				errors.append("%s requires unknown skill %s." % [skill_id, prerequisite_id])
			elif layout_position(prerequisite_id).y >= layout_position(skill_id).y:
				errors.append("%s must render below prerequisite %s." % [skill_id, prerequisite_id])
		var known_prerequisites: Array[String] = prerequisites(skill_id)
		if known_prerequisites.size() > 1:
			var minimum_parent_x: int = layout_position(known_prerequisites[0]).x
			var maximum_parent_x: int = minimum_parent_x
			for prerequisite_id: String in known_prerequisites:
				minimum_parent_x = mini(minimum_parent_x, layout_position(prerequisite_id).x)
				maximum_parent_x = maxi(maximum_parent_x, layout_position(prerequisite_id).x)
			var child_x: int = layout_position(skill_id).x
			if child_x < minimum_parent_x or child_x > maximum_parent_x:
				errors.append("%s should render between its prerequisites." % skill_id)
	var cycle_errors: Array[String] = _prerequisite_cycle_errors()
	errors.append_array(cycle_errors)
	if cycle_errors.is_empty():
		var dead_end_result: Dictionary = _first_unextendable_selection(COMPLETE_BUILD_SIZE)
		if bool(dead_end_result.get("found", false)):
			var dead_end: Array = dead_end_result.get("selection", []) as Array
			errors.append("A legal progression state with %d skills cannot be extended: %s." % [dead_end.size(), ", ".join(dead_end)])
	if repaired_selection([], COMPLETE_BUILD_SIZE).size() != COMPLETE_BUILD_SIZE:
		errors.append("The graph cannot produce a legal %d-skill build." % COMPLETE_BUILD_SIZE)
	return errors

static func _is_valid_layout_position(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY or (value as Array).size() != 2:
		return false
	for coordinate: Variant in value as Array:
		if typeof(coordinate) not in [TYPE_INT, TYPE_FLOAT]:
			return false
		if not is_equal_approx(float(coordinate), float(int(coordinate))):
			return false
	return true

static func _prerequisite_cycle_errors() -> Array[String]:
	var errors: Array[String]
	var visit_states: Dictionary = {}
	var active_path: Array[String]
	for skill_id: String in ordered_ids():
		if int(visit_states.get(skill_id, 0)) != 0:
			continue
		var cycle: Array[String] = _find_prerequisite_cycle(skill_id, visit_states, active_path)
		if cycle.is_empty():
			continue
		errors.append("Prerequisite cycle detected: %s." % " -> ".join(cycle))
		break
	return errors

static func _find_prerequisite_cycle(
	skill_id: String,
	visit_states: Dictionary,
	active_path: Array[String]
) -> Array[String]:
	visit_states[skill_id] = 1
	active_path.append(skill_id)
	for prerequisite_id: String in prerequisites(skill_id):
		var prerequisite_state: int = int(visit_states.get(prerequisite_id, 0))
		if prerequisite_state == 0:
			var nested_cycle: Array[String] = _find_prerequisite_cycle(prerequisite_id, visit_states, active_path)
			if not nested_cycle.is_empty():
				return nested_cycle
		elif prerequisite_state == 1:
			var cycle: Array[String]
			var cycle_start: int = active_path.find(prerequisite_id)
			for path_index: int in range(maxi(0, cycle_start), active_path.size()):
				cycle.append(active_path[path_index])
			cycle.append(prerequisite_id)
			return cycle
	active_path.pop_back()
	visit_states[skill_id] = 2
	var no_cycle: Array[String]
	return no_cycle

static func _first_unextendable_selection(target_count: int) -> Dictionary:
	var skill_ids: Array[String] = ordered_ids()
	var bit_indices: Dictionary = {}
	for skill_index: int in range(skill_ids.size()):
		bit_indices[skill_ids[skill_index]] = skill_index
	var pending_masks: Array[int]
	pending_masks.append(0)
	var seen_masks: Dictionary = {0: true}
	while not pending_masks.is_empty():
		var selection_mask: int = pending_masks.pop_back()
		var selected: Array[String]
		for skill_index: int in range(skill_ids.size()):
			if (selection_mask & (1 << skill_index)) != 0:
				selected.append(skill_ids[skill_index])
		if selected.size() >= target_count:
			continue
		var available: Array[String] = available_ids(selected)
		if available.is_empty():
			return {"found": true, "selection": selected}
		if selected.size() + 1 >= target_count:
			continue
		for available_id: String in available:
			var next_mask: int = selection_mask | (1 << int(bit_indices[available_id]))
			if seen_masks.has(next_mask):
				continue
			seen_masks[next_mask] = true
			pending_masks.append(next_mask)
	return {"found": false}

static func _unique_known_ids(value: Variant) -> Array[String]:
	var result: Array[String]
	if typeof(value) != TYPE_ARRAY:
		return result
	for skill_id_var: Variant in value as Array:
		var skill_id: String = str(skill_id_var)
		if skill_id.is_empty() or result.has(skill_id) or not definitions().has(skill_id):
			continue
		result.append(skill_id)
	return result

static func _lookup(ids: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for skill_id: String in ids:
		result[skill_id] = true
	return result
