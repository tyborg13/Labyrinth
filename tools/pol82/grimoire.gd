extends RefCounted
## Measure the production title Grimoire at its settled page width.

const Library = preload("res://scripts/grimoire_library.gd")
const HOLD_SECONDS := 4.0
const EDGE_TOLERANCE := 1.0

static func check(probe: SceneTree, profile: Dictionary) -> void:
	var title: Control = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	probe.viewport.add_child(title)
	await probe._settle()
	title._on_grimoire_button_pressed()
	var book: Control = title._grimoire
	var creature_ids: Array[String]
	for entry: Dictionary in Library.entries():
		if not str(entry.get("enemy_id", "")).is_empty(): creature_ids.append(entry["id"])
	book.set_catalog({Library.UNLOCKED_KEY: creature_ids})
	book.open(title.grimoire_button)
	await probe._settle()
	var scroll: ScrollContainer = book._grimoire_detail_scroll
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	var tallest := ""
	var height := 0.0
	for id: String in creature_ids:
		_show(book, id)
		await probe._settle()
		var measured: float = book._grimoire_creature_stack.get_combined_minimum_size().y
		if measured > height:
			height = measured
			tallest = id
	if not probe._check(not tallest.is_empty(), "Could not measure a creature page."): return
	_show(book, tallest)
	await probe._settle()
	var bottom: float = bar.max_value - bar.page
	var visible_bar: bool = bar.visible
	var start: float = bar.value
	await _hold(probe, 1.0)
	var down: float = bar.value
	await _hold(probe, -1.0)
	var up: float = bar.value
	var reached: bool = visible_bar and bottom > EDGE_TOLERANCE and down >= bottom - EDGE_TOLERANCE and absf(up - start) <= EDGE_TOLERANCE
	print("POL-82 Grimoire: %d pages, tallest=%s, content=%.1f px, viewport=%.1f px, scrollbar=%s, range=%.1f, stick=%.1f -> %.1f -> %.1f, reached_end_and_back=%s" % [
		creature_ids.size(), tallest, height, scroll.size.y, visible_bar, bottom, start, down, up, reached])
	book.close()
	await probe.process_frame
	title.queue_free()
	await probe.process_frame

static func _show(book: Control, id: String) -> void:
	book._grimoire_selected_entry = id
	book._refresh_grimoire_detail()

static func _hold(probe: SceneTree, value: float) -> void:
	var axis := InputEventJoypadMotion.new()
	axis.device = probe.DEVICE
	axis.axis = JOY_AXIS_RIGHT_Y
	axis.axis_value = value
	probe._deliver(axis)
	await probe.create_timer(HOLD_SECONDS).timeout
	var release := InputEventJoypadMotion.new()
	release.device = probe.DEVICE
	release.axis = JOY_AXIS_RIGHT_Y
	probe._deliver(release)
	await probe.process_frame
