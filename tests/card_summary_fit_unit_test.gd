extends SceneTree

const CardScene = preload("res://scenes/card_widget.tscn")
const Card = preload("res://scripts/card_widget.gd")
const Settle = preload("res://tests/helpers/card_legibility_settle.gd")
const Measure = preload("res://tests/helpers/card_summary_fit_measure.gd")
const FITTING_ITEM_WIDTH: float = 40.0
const TIGHTEN_ITEM_WIDTH: float = 53.0
const MINIMUM_GAP_ITEM_WIDTH: float = 54.0
const WRAP_ITEM_WIDTH: float = 55.0
const LEGACY_ITEM_WIDTH: float = 80.0
const FIXTURE_ITEM_HEIGHT: float = 20.0
const FIXTURE_ITEM_COUNT: int = 3
const FIXTURE_START_GAP: int = 6
const FIXTURE_LEGACY_GAP: int = 3
const CONTINUATION_GLYPH_WIDTH: float = 15.0
const CONTINUATION_ITEM_WIDTH: float = 153.0
const TALL_ICON_HEIGHT: float = 400.0
var failures: Array[String]
var checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	var frame := Control.new()
	frame.scale = Vector2.ONE * Card.MIN_READABLE_CARD_SCALE
	root.add_child(frame)
	var card: Control = CardScene.instantiate()
	frame.add_child(card)
	card.configure("worldbreak", false, false, true, false, false)
	await Settle.wait_for(self, [card])
	var parent: VBoxContainer = card.get("_summary_icon_box")
	for child: Node in parent.get_children(): child.free()
	var spacing: int = parent.get_theme_constant("separation")
	var fitting: HBoxContainer = _row(FITTING_ITEM_WIDTH)
	var original_items: Array[Node] = fitting.get_children()
	card.call("_fit_summary_segment", parent, fitting)
	_expect(parent.get_child_count() == 1 and fitting.get_theme_constant("separation") == 6, "Fitting rows keep their original gap and one-line layout")
	_expect(fitting.get_children() == original_items, "Fitting rows retain identical item nodes/order")
	_clear(parent)
	var tightened: HBoxContainer = _row(TIGHTEN_ITEM_WIDTH)
	card.call("_fit_summary_segment", parent, tightened)
	_expect(parent.get_child_count() == 1 and tightened.get_theme_constant("separation") == 5, "Tighten only as far as necessary before wrapping")
	_clear(parent)
	var minimum_gap: HBoxContainer = _row(MINIMUM_GAP_ITEM_WIDTH)
	card.call("_fit_summary_segment", parent, minimum_gap)
	_expect(parent.get_child_count() == 1 and minimum_gap.get_theme_constant("separation") == 4, "A row that fits at the 4px minimum remains on one line")
	_clear(parent)
	var wrapped: HBoxContainer = _row(WRAP_ITEM_WIDTH)
	original_items = wrapped.get_children()
	card.call("_fit_summary_segment", parent, wrapped)
	_expect(parent.get_child_count() == 2, "A row still too wide at 4px wraps onto exactly two rows")
	var ordered: Array[Node]
	for row: HBoxContainer in parent.get_children():
		_expect(row.get_theme_constant("separation") == 4, "Wrapped rows keep the minimum gap")
		_expect(row.size_flags_horizontal == Control.SIZE_SHRINK_CENTER and row.alignment == BoxContainer.ALIGNMENT_CENTER, "Both wrapped rows are centred")
		ordered.append_array(row.get_children())
	_expect(ordered == original_items, "Wrapping preserves whole items and source order without adding a glyph")
	_expect(parent.get_theme_constant("separation") == spacing, "Wrapping preserves the existing vertical row spacing")
	_clear(parent)
	var legacy: HBoxContainer = _row(LEGACY_ITEM_WIDTH)
	legacy.add_theme_constant_override("separation", FIXTURE_LEGACY_GAP)
	card.call("_fit_summary_segment", parent, legacy)
	_expect(parent.get_child_count() == 2, "An overflowing legacy continuation wraps whole items")
	for row: HBoxContainer in parent.get_children():
		_expect(row.get_theme_constant("separation") == 4, "Repaired legacy continuation rows respect the 4px gap floor")
	_clear(parent)
	var continuation := HBoxContainer.new()
	continuation.size_flags_horizontal = Control.SIZE_SHRINK_END
	continuation.add_theme_constant_override("separation", FIXTURE_LEGACY_GAP)
	var glyph := Control.new()
	glyph.custom_minimum_size = Vector2(CONTINUATION_GLYPH_WIDTH, FIXTURE_ITEM_HEIGHT)
	glyph.set_meta("summary_continuation_glyph", true)
	var caption := Control.new()
	caption.custom_minimum_size = Vector2(CONTINUATION_ITEM_WIDTH, FIXTURE_ITEM_HEIGHT)
	continuation.add_child(glyph)
	continuation.add_child(caption)
	card.call("_fit_summary_segment", parent, continuation)
	await Settle.wait_for(self, [card])
	_expect(glyph.get_parent() == caption.get_parent(), "Continuation glyph and following item stay in one unit")
	_expect(glyph.get_parent().get_theme_constant("separation") == FIXTURE_LEGACY_GAP, "Continuation unit retains its internal spacing")
	_expect(parent.get_child_count() == 1, "A complete continuation unit never becomes two lines")
	var left: float = (card.size.x - float(card.call("_summary_parchment_width"))) * 0.5
	var start: Vector2 = card.get_global_transform_with_canvas().affine_inverse() * continuation.get_global_transform_with_canvas().origin
	_expect((start.x - left) * frame.scale.x >= 2.0, "Atomic continuation keeps the screen inset")
	# Reflow when the containing reading context changes scale, then retain the
	# fitting geometry unchanged across idle frames and position-only changes.
	frame.scale = Vector2.ONE
	card.configure("cloudstep_loop", false, false, true, false, false)
	await Settle.wait_for(self, [card])
	var full_rows: int = _row_count(parent)
	var full_row_id: int = parent.get_child(0).get_instance_id()
	var full_inset: float = card.get("_summary_fit_inset")
	frame.scale = Vector2.ONE * Card.MIN_READABLE_CARD_SCALE
	await Settle.wait_for(self, [card])
	# pol-32 (8ef546246) makes Cloudstep wrap at both scales. Observe the
	# actual refit; whole-item wrapping is exercised by the synthetic rows above.
	_expect(parent.get_child(0).get_instance_id() != full_row_id and float(card.get("_summary_fit_inset")) > full_inset, "A smaller context refits its summary to the larger local inset")
	frame.scale = Vector2.ONE
	await Settle.wait_for(self, [card])
	_expect(_row_count(parent) == full_rows, "Returning to a fitting scale restores the original layout")
	var first_row_id: int = parent.get_child(0).get_instance_id()
	frame.position.x += 1.0
	for index: int in range(30): await process_frame
	_expect(parent.get_child(0).get_instance_id() == first_row_id, "Idle and position changes do not rebuild fitting rows")
	_clear(parent)
	var token := Control.new()
	token.custom_minimum_size = Vector2.ONE * FIXTURE_ITEM_HEIGHT
	var icon := TextureRect.new()
	icon.size = Vector2(FIXTURE_ITEM_HEIGHT, TALL_ICON_HEIGHT)
	token.add_child(icon)
	parent.add_child(token)
	await Settle.wait_for(self, [card])
	_expect(float(Measure.measure(card, {})["overflow_y"]) > 0.0, "Vertical audit includes an icon extending beyond its token and text bounds")
	frame.free()
	for failure: String in failures: push_error(failure)
	print("CARD SUMMARY FIT UNIT RESULT: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _row(item_width: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", FIXTURE_START_GAP)
	for index: int in range(FIXTURE_ITEM_COUNT):
		var item := Control.new()
		item.name = "FixtureItem_%d" % index
		item.custom_minimum_size = Vector2(item_width, FIXTURE_ITEM_HEIGHT)
		row.add_child(item)
	return row

func _clear(parent: Node) -> void:
	for child: Node in parent.get_children(): child.free()

func _row_count(parent: Node) -> int:
	var count: int = 0
	for row: Node in parent.find_children("*", "HBoxContainer", true, false):
		if row.get_parent() == parent or row.get_parent().has_meta("summary_action_group"): count += 1
	return count

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
