extends "res://scripts/run_scene.gd"

# Independent pre-retention result control builder, preserving the original
# whole-list replacement while sharing the already verified search ranking.

func _rebuild_grimoire_search_results(unlocked: Array[String], unread: Array[String], sections: Array, preserved_scroll_vertical: int, scroll_revision: int) -> void:
	var grimoire_started: int = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
	if _grimoire_search_index.is_empty() or unlocked != _grimoire_search_index_unlocked:
		var unlocked_entries: Array = []
		var unlocked_lookup: Dictionary = {}
		for entry_id: String in unlocked: unlocked_lookup[entry_id] = true
		for entry_var: Variant in GrimoireLibrary.entries():
			if typeof(entry_var) == TYPE_DICTIONARY and unlocked_lookup.has(str((entry_var as Dictionary).get("id", ""))):
				unlocked_entries.append(entry_var)
		_grimoire_search_index = GrimoireSearch.build_index(unlocked_entries, sections)
		_grimoire_search_index_unlocked.assign(unlocked)
		_grimoire_cached_results_valid = false
	grimoire_started = _record_runtime_performance_phase("grimoire_search_catalog", grimoire_started)
	if not _grimoire_cached_results_valid or _grimoire_cached_result_query != _grimoire_search_query:
		_grimoire_cached_results = GrimoireSearch.search_index(_grimoire_search_index, _grimoire_search_query)
		_grimoire_cached_result_query = _grimoire_search_query
		_grimoire_cached_results_valid = true
	# Browsing clears its visible array; preserve a separate owned outer array
	# so selection/unread changes can reuse the same immutable ranking.
	_grimoire_search_results.assign(_grimoire_cached_results)
	grimoire_started = _record_runtime_performance_phase("grimoire_search_score", grimoire_started)
	_clear_children_now(_grimoire_section_list)
	var selected_still_matches: bool = false
	for result: Dictionary in _grimoire_search_results:
		var result_entry: Dictionary = result.get("entry", {}) as Dictionary
		if str(result_entry.get("id", "")) == _grimoire_selected_entry:
			selected_still_matches = true
			break
	if not selected_still_matches:
		_grimoire_selected_entry = "" if _grimoire_search_results.is_empty() else str((_grimoire_search_results[0].get("entry", {}) as Dictionary).get("id", ""))
	for result: Dictionary in _grimoire_search_results:
		_add_grimoire_search_result(result, unread)
	_update_grimoire_search_chrome(unlocked.size())
	if _grimoire_search_results.is_empty():
		call_deferred("_restore_grimoire_entry_list_scroll", 0, 0, scroll_revision)
	else:
		var selected_index: int = 0
		for index: int in range(_grimoire_search_results.size()):
			var result_entry: Dictionary = _grimoire_search_results[index].get("entry", {}) as Dictionary
			if str(result_entry.get("id", "")) == _grimoire_selected_entry:
				selected_index = index
				break
		if preserved_scroll_vertical > 0:
			call_deferred("_restore_grimoire_entry_list_scroll", preserved_scroll_vertical, 0, scroll_revision)
		else:
			call_deferred("_scroll_grimoire_entry_list_to_index", selected_index, 0, scroll_revision)
	grimoire_started = _record_runtime_performance_phase("grimoire_result_controls", grimoire_started)
	_refresh_grimoire_detail()
	_record_runtime_performance_phase("grimoire_detail_build", grimoire_started)
	_refresh_grimoire_badge()


func _add_grimoire_search_result(result: Dictionary, unread: Array[String]) -> void:
	var entry: Dictionary = result.get("entry", {}) as Dictionary
	var entry_id: String = str(entry.get("id", ""))
	var selected: bool = entry_id == _grimoire_selected_entry
	var button := _grimoire_nav_button(
		"",
		1,
		selected,
		false,
		_grimoire_search_result_tooltip(result),
		"search"
	)
	button.custom_minimum_size.y = 60.0
	button.focus_mode = Control.FOCUS_ALL
	button.set_meta("grimoire_nav_kind", "entry")
	button.set_meta("grimoire_nav_id", entry_id)
	button.pressed.connect(_on_grimoire_entry_pressed.bind(entry_id))
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = UiTypography.SPACE_MEDIUM
	content.offset_top = UiTypography.SPACE_TIGHT
	content.offset_right = -UiTypography.SPACE_SMALL
	content.offset_bottom = -UiTypography.SPACE_TIGHT
	content.add_theme_constant_override("separation", 0)
	button.add_child(content)
	var title := Label.new()
	title.text = "%s%s" % ["* " if unread.has(entry_id) else "", str(entry.get("title", entry_id))]
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTypography.apply_label_role(title, UiTypography.ROLE_BODY)
	title.add_theme_color_override("font_color", Color("2f1d10") if selected else Color("3d2818"))
	content.add_child(title)
	var breadcrumb := Label.new()
	breadcrumb.text = _grimoire_search_result_context(result)
	breadcrumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breadcrumb.clip_text = true
	breadcrumb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	breadcrumb.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	UiTypography.apply_label_role(breadcrumb, UiTypography.ROLE_CAPTION)
	breadcrumb.add_theme_color_override("font_color", Color(0.28, 0.18, 0.10, 0.76))
	content.add_child(breadcrumb)
	_add_grimoire_nav_button(button, 0)
	_grimoire_search_result_buttons.append(button)

