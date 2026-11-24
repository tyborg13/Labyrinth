extends SceneTree

const Panels = preload("res://scripts/ui_tooltip_panel.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Consistency = preload("res://tests/suites/tooltip_consistency_suite.gd")

var _failures: int
var _checks: int

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	for sentence: String in ["Hits each Marked tile.", "Ready!", "Which tile?"]:
		_check_labels(Panels.make_plain_text(" \t" + sentence + "\r\n "), [sentence], [false])
	_check_labels(Panels.make_plain_text(" Settings "), ["SETTINGS"], [true])
	_check_labels(Panels.make_plain_text("First line.\nText stays as written."),
		["FIRST LINE.", "Text stays as written."], [true, false])
	_check_labels(Panels.make_lines("Explicit title.", PackedStringArray(["Body."])),
		["EXPLICIT TITLE.", "Body."], [true, false])

	var markup: String = "Draw @icon(draw) 1 card."
	var plain: PanelContainer = Panels.make_plain_text(markup)
	var titled: PanelContainer = Panels.make_text("Draw\n" + markup)
	var body: RichTextLabel = plain.get_child(0).get_child(0) as RichTextLabel
	var expected_body: RichTextLabel = titled.get_child(0).get_child(1) as RichTextLabel
	_expect(plain.get_child(0).get_child_count() == 1 and body != null, "One rich body and no title")
	if body != null and expected_body != null:
		_expect(body.get_parsed_text() == expected_body.get_parsed_text()
			and body.get_meta("inline_icon_keys", []) == ["draw"],
			"Inline icon and surrounding text use the existing body path")
		_expect(body.get_theme_color("default_color") == Panels.BODY_COLOR
			and body.get_theme_font_size("normal_font_size") == expected_body.get_theme_font_size("normal_font_size")
			and body.custom_minimum_size == expected_body.custom_minimum_size,
			"Inline body retains the existing styling and width")
	plain.free()
	titled.free()
	print("POL83 PLAIN TOOLTIP: %d checks, %d failed" % [_checks, _failures])
	_checks = 0
	var failures_before: int = _failures
	Consistency.run(_expect)
	print("TOOLTIP CONSISTENCY: %d checks, %d failed" % [_checks, _failures - failures_before])
	quit(int(_failures > 0))

func _check_labels(panel: PanelContainer, expected: Array, titles: Array) -> void:
	var labels: Array[Node] = panel.find_children("*", "Label", true, false)
	_expect(labels.size() == expected.size(), "Label count for %s" % [expected])
	for index: int in mini(labels.size(), expected.size()):
		var label: Label = labels[index]
		var title: bool = titles[index]
		_expect(label.text == expected[index], "Exact text for %s" % expected[index])
		_expect(label.get_theme_color("font_color") == (Panels.TITLE_COLOR if title else Panels.BODY_COLOR),
			"Expected color for %s" % expected[index])
		_expect(label.get_theme_font_size("font_size") == (Typography.SIZE_BODY_LARGE if title else Typography.SIZE_BODY),
			"Expected size for %s" % expected[index])
	panel.free()

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition: return
	_failures += 1
	push_error(message)
