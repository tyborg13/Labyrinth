extends RefCounted

const Sources = preload("res://tests/sfx_sync_sources.gd")
const Checks = preload("res://tests/helpers/magic_purge_focus_checks.gd")
const PileView = preload("res://scripts/pile_dialog_view.gd")
const RECONCILE_GUARD: String = "\tif not _following_focus: _reconcile_focus()"
const TEST_SCROLL_SIZE := Vector2(1484, 614)
const TEST_CELL_SIZE := Vector2(196, 276)
const TEST_CELL_GAP: int = 16
const TEST_HEADROOM: int = 18
const TEST_OVERFLOW: int = 24
const TEST_LAYOUT_FRAMES: int = 2

static func run(tree: SceneTree) -> bool:
	var source: String = FileAccess.get_file_as_string("res://scripts/magic_purge_row_scroll.gd")
	if source.count(RECONCILE_GUARD) != 1:
		push_error("Manual focus mutation must remove exactly one reconciliation call")
		return false
	var healthy: GDScript = Sources.compile_script("scripts/magic_purge_row_scroll.gd", source)
	var mutant: GDScript = Sources.compile_script("scripts/magic_purge_row_scroll_without_manual_focus.gd", source.replace(RECONCILE_GUARD, "\tpass # Manual page focus reconciliation removed."))
	if healthy == null or mutant == null: return false
	var passed: bool = true
	for count: int in Checks.TEST_IDENTITY_COUNTS:
		var baseline: Array[String] = await _failures(tree, healthy, count)
		var caught: Array[String] = await _failures(tree, mutant, count)
		for failure: String in baseline: push_error(failure)
		var killed: bool = baseline.is_empty() and caught.has("Focused card is on a visible row before activation")
		passed = passed and killed
		print("PURGE MANUAL FOCUS MUTATION (%d identities): %s" % [count, "KILLED" if killed else "SURVIVED"])
	return passed

static func _failures(tree: SceneTree, scroll_script: GDScript, count: int) -> Array[String]:
	var failures: Array[String]
	var expect: Callable = func(ok: bool, message: String) -> void:
		if not ok: failures.append(message)
	var scroll: ScrollContainer = scroll_script.new()
	scroll.size = TEST_SCROLL_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var padding := StyleBoxEmpty.new()
	padding.content_margin_top = TEST_HEADROOM
	scroll.add_theme_stylebox_override("panel", padding)
	var grid := Control.new()
	var rows: int = ceili(float(count) / Checks.TEST_COLUMNS)
	grid.custom_minimum_size = Vector2(Checks.TEST_COLUMNS * (TEST_CELL_SIZE.x + TEST_CELL_GAP), (rows - 1) * Checks.TEST_ROW_PITCH + TEST_CELL_SIZE.y + TEST_OVERFLOW)
	scroll.add_child(grid)
	for index: int in range(count):
		var cell := PileView.CardCell.new()
		cell.size = TEST_CELL_SIZE
		cell.position = Vector2((index % Checks.TEST_COLUMNS) * (TEST_CELL_SIZE.x + TEST_CELL_GAP), (index / Checks.TEST_COLUMNS) * Checks.TEST_ROW_PITCH)
		grid.add_child(cell)
	tree.root.add_child(scroll)
	scroll.call("configure", grid, Checks.TEST_COLUMNS, Checks.TEST_ROW_PITCH)
	for _frame: int in range(TEST_LAYOUT_FRAMES): await tree.process_frame
	(grid.get_child(0) as Control).grab_focus()
	scroll.scroll_vertical = Checks.TEST_ROW_PITCH
	Checks.assert_focus(scroll, grid, Checks.TEST_COLUMNS, expect)
	(grid.get_child(count - 1) as Control).grab_focus()
	scroll.scroll_vertical = 0
	Checks.assert_focus(scroll, grid, 0, expect)
	scroll.free()
	return failures
