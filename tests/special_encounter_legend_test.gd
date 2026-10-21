extends SceneTree

const Fixture = preload("res://tests/helpers/special_map_proof_fixture.gd")
const MapPanelScript = preload("res://scripts/section_map_panel.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Settings = preload("res://scripts/settings_store.gd")
const LAYOUT_BOUNDARY_DELTA: float = 1.0
# Independent director contract, including disabled types. Production constants
# are the subject of this check, never its expected-value oracle.
const EXPECTED_ORDER: Array = ["combat", "special_warband", "special_umbral_snare", "special_ember_hoarder", "special_last_light", "guardian", "event", "scavenger", "graftwright", "treasure", "campfire", "boss", "unknown"]
const EXPECTED_LABELS: Array = ["Standard combat", "Warband", "Umbral Snare", "Ember Hoarder", "Last Light", "Guardian combat", "Event", "Scavenger", "Graftwright", "Relic", "Ember Hearth", "Boss", "Unknown room"]
var failures: Array[String]

func _initialize() -> void:
	Settings.set_storage_path("user://spx-legend-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	root.size = Fixture.PROOF_SIZE
	_run.call_deferred()

func _run() -> void:
	var state: Dictionary = Fixture.fullest_state()
	var panel := MapPanelScript.new()
	panel.position = Fixture.PANEL_POSITION
	panel.size = Fixture.PANEL_SIZE
	panel.set_run_state(state)
	root.add_child(panel)
	await process_frame
	await process_frame
	await process_frame
	var types: Dictionary = Fixture.section_types(state, Graph.active_section(state))
	_check(panel._legend_types.size() == types.size(), "Legend lists only the displayed section's types")
	_check(MapPanelScript.LEGEND_ORDER == EXPECTED_ORDER, "All thirteen legend concepts match the independent approved order")
	var ordered: Array[String]
	for type: String in EXPECTED_ORDER:
		if types.has(type): ordered.append(type)
	_check(panel._legend_types == ordered, "Legend follows the director's exact order")
	for index: int in range(panel._legend_types.size()):
		var expected_index: int = EXPECTED_ORDER.find(panel._legend_types[index])
		_check(expected_index >= 0 and panel._legend.get_child(index).get_child(1).text == EXPECTED_LABELS[expected_index], "Legend labels match the independent approved wording")
	_check_row_rule(panel)
	_check(panel._legend.get_global_rect().end.x <= panel._scout.get_global_rect().position.x, "Legend fits beside Scout")
	_check_bounds(panel)
	print("SPX fullest legend: seed=%d section=%d entries=%d rows=%d" % [state["seed"], Graph.active_section(state) + 1, types.size(), panel._legend.custom_minimum_size.y / 48])
	# Debug-only widths straddle the exact fit boundary, independent of how many
	# special types are enabled or the width of their approved labels.
	var content_width: float = _content_width(panel)
	var gaps: int = panel._legend.get_child_count() - 1
	for width: float in [content_width + 40.0 * gaps, content_width + 12.0 * gaps, content_width + 12.0 * gaps - LAYOUT_BOUNDARY_DELTA]:
		panel._legend.size.x = width
		panel._layout_legend()
		_check_row_rule(panel)
		_check_bounds(panel)
	panel.free()
	for failure: String in failures: push_error(failure)
	print("SPX special legend suite: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _content_width(panel: Control) -> float:
	var total: float = 0.0
	for item: Control in panel._legend.get_children(): total += item.get_combined_minimum_size().x
	return total

func _check_row_rule(panel: Control) -> void:
	var minimum_row_width: float = _content_width(panel) + 12.0 * (panel._legend.get_child_count() - 1)
	var expected_rows: int = 1 if minimum_row_width <= panel._legend.size.x else 2
	_check(panel._legend.custom_minimum_size.y == 48.0 * expected_rows, "Legend uses one row while 12px gaps fit, otherwise two centred rows")
	for row: int in range(expected_rows):
		var first: Control = null
		var last: Control = null
		var entries: Array[Control]
		var content: float = 0.0
		for item: Control in panel._legend.get_children():
			if is_equal_approx(item.position.y, row * 48.0):
				if first == null: first = item
				last = item
				entries.append(item)
				content += item.size.x
		_check(first != null and last != null, "Every required legend row contains entries")
		if first != null and last != null:
			_check(is_equal_approx(first.position.x, panel._legend.size.x - last.get_rect().end.x), "Each legend row is centred")
			var expected_gap: float = clampf((panel._legend.size.x - content) / maxi(1, entries.size() - 1), 12.0, 40.0)
			for index: int in range(1, entries.size()):
				_check(is_equal_approx(entries[index].position.x - entries[index - 1].get_rect().end.x, expected_gap), "Legend gaps shrink evenly from 40px to 12px before wrapping")

func _check_bounds(panel: Control) -> void:
	var items: Array[Node] = panel._legend.get_children()
	for index: int in range(items.size()):
		var item: Control = items[index]
		_check(item.position.x >= -0.01 and item.get_rect().end.x <= panel._legend.size.x + 0.01, "Legend entries stay inside their frame")
		_check(item.get_child(0).size.x >= 48, "Legend retains ordinary 48px medallions")
		if index == 0: continue
		var previous: Control = items[index - 1]
		if item.position.y != previous.position.y: continue
		var gap: float = item.position.x - previous.get_rect().end.x
		_check(gap >= 11.99 and gap <= 40.01, "Even legend gaps remain in the approved 12–40px range")

func _check(ok: bool, message: String) -> void:
	if not ok and not failures.has(message): failures.append(message)
