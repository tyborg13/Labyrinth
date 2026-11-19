extends RefCounted

const View = preload("res://scripts/event_view.gd")
const Fixtures = preload("res://tests/suites/event_view_suite.gd")
const Preview = preload("res://scripts/event_reward_preview.gd")
const Tooltips = preload("res://scripts/event_reward_tooltips.gd")
const Stack = preload("res://scripts/card_focus_tooltip_stack.gd")
const Data = preload("res://scripts/game_data.gd")
const TOLERANCE: float = 1.0
const LAYOUT_FRAMES: int = 2

static func bounds(view: Control, stage: Control, expect: Callable, context: String) -> Array[Rect2]:
	var art: Rect2 = Stack._visual_global_rect(view.art)
	var choices: Rect2 = Stack._visual_global_rect(view.column)
	var panel: Rect2 = Stack._visual_global_rect(view.panel)
	var reward: Rect2 = Stack._visual_global_rect(stage)
	var gap: float = Tooltips.GAP * stage.get_parent().get_global_transform_with_canvas().get_scale().x
	var usable: Rect2 = art
	usable.end.x = minf(usable.end.x, choices.position.x - gap)
	expect.call(panel.encloses(reward) and usable.grow(TOLERANCE).encloses(reward) and not choices.intersects(reward), "Reward fits the event art bounds: " + context)
	for plate: PanelContainer in stage.find_children("EventRewardPlate", "PanelContainer", true, false):
		var plate_rect: Rect2 = Stack._visual_global_rect(plate)
		expect.call(usable.grow(TOLERANCE).encloses(plate_rect) and not choices.intersects(plate_rect), "Each plate clears the event column: " + context)
		var description: RichTextLabel = plate.get_node_or_null("Contents/RewardDescription")
		if description != null:
			expect.call(description.get_content_height() <= description.size.y + TOLERANCE and plate_rect.grow(TOLERANCE).encloses(Stack._visual_global_rect(description)), "Full reward description fits: " + context)

	var columns: Array[Rect2]
	var host: Control = stage.get_node_or_null("EventRewardTooltips")
	if host == null: return columns
	var previous: Rect2
	for tooltip: Control in host.get_children():
		var rect: Rect2 = Stack._visual_global_rect(tooltip)
		expect.call(tooltip.get_meta("tooltip_surface", false) and usable.grow(TOLERANCE).encloses(rect) and panel.encloses(rect), "Tooltip stays in the panel's inner art bounds: " + context + " " + str(rect))
		expect.call(not choices.intersects(rect) and not reward.intersects(rect), "Tooltip clears reward and choice column: " + context)
		if columns.is_empty() or not is_equal_approx(previous.position.x, rect.position.x):
			columns.append(rect)
		else:
			expect.call(previous.end.y <= rect.position.y, "Tooltips follow reading order without touching: " + context)
			columns[-1] = columns[-1].merge(rect)
		previous = rect
	expect.call(columns.size() <= 2, "Tooltip stack uses at most two columns: " + context)
	if columns.is_empty(): return columns
	var first: Rect2 = columns[0]
	expect.call(absf(first.end.x + gap - reward.position.x) <= TOLERANCE, "First tooltip column has the 16-pixel gap on the left: " + context)
	var height: float = first.size.y
	if columns.size() == 2:
		var second: Rect2 = columns[1]
		height = maxf(height, second.size.y)
		expect.call(absf(first.position.y - second.position.y) <= TOLERANCE, "Wrapped tooltip columns share a top edge: " + context)
		var second_left: bool = absf(first.position.x - second.end.x - gap) <= TOLERANCE
		var second_right: bool = absf(second.position.x - reward.end.x - gap) <= TOLERANCE
		expect.call(second_left or second_right, "Second tooltip column has the 16-pixel gap: " + context)
		if second_right:
			expect.call(first.position.x - gap - second.size.x < usable.position.x + TOLERANCE, "Right fallback is used only when two columns cannot fit on the left: " + context)
	var expected_top: float = minf(reward.position.y, usable.end.y - height)
	expect.call(absf(first.position.y - expected_top) <= TOLERANCE, "Stack rises only enough to stay inside the art: " + context)
	return columns

static func sweep(viewport: SubViewport, expect: Callable) -> Dictionary:
	var view := View.new()
	viewport.add_child(view)
	var tree: SceneTree = view.get_tree()
	var previews: int = 0
	var choices: int = 0
	var tallest: Dictionary = {"height": 0.0}
	var template: Dictionary = Fixtures.Run.new().create_new_run(Fixtures.FIXTURE_SEED, Fixtures.Store.default_data())
	for id: String in Data.events():
		for rich: bool in [false, true]:
			view.present(Fixtures.fixture(id, rich, template), true)
			view.finish_animation_for_test()
			expect.call(Fixtures.Events.current_id(view.run_state) == id, "Sweep covers the requested authored event: " + id)
			for frame: int in range(LAYOUT_FRAMES): await tree.process_frame
			for index: int in range(view.choices.size()):
				var button: Button = view.choices[index]
				var line: Dictionary = Preview.hover_line(view.cached_preview_lines(button.choice_id))
				var context: String = "%s/%s rich=%s" % [id, button.choice_id, rich]
				choices += 1
				view.preview_choice(index)
				if line.is_empty() or not button.available:
					expect.call(view.hover_preview.current_line.is_empty(), "Unavailable or empty preview stays hidden: " + context)
					continue
				previews += 1
				for frame: int in range(LAYOUT_FRAMES): await tree.process_frame
				var stage: Control = view.hover_preview.current
				expect.call(stage != null and stage.is_visible_in_tree() and view.hover_preview.current_line == line, "Expected preview is visible: " + context)
				if stage == null: continue
				var columns: Array[Rect2] = bounds(view, stage, expect, context)
				var host: Control = stage.get_node_or_null("EventRewardTooltips")
				if host == null: continue
				var height: float = 0.0
				for tooltip: Control in host.get_children():
					height += tooltip.get_combined_minimum_size().y + Stack.STACK_SEPARATION
				height -= Stack.STACK_SEPARATION
				if height > tallest.height:
					tallest = {"height": height, "count": host.get_child_count(), "case": context, "ids": line.ids, "columns": columns}
	view.queue_free()
	await tree.process_frame
	return {"events": Data.events().size(), "choices": choices, "previews": previews, "tallest": tallest}
