extends SceneTree

const UiSkin = preload("res://scripts/ui_skin.gd")

const APPLY_ITERATIONS: int = 3000
const VARIANTS: Array[String] = [
	UiSkin.VARIANT_COMPACT,
	UiSkin.VARIANT_STANDARD,
	UiSkin.VARIANT_LARGE,
	UiSkin.VARIANT_DESTRUCTIVE,
	UiSkin.VARIANT_SELECTED,
	UiSkin.VARIANT_ICON,
]
const THEME_STATES: Array[String] = [
	"normal",
	"hover",
	"pressed",
	"hover_pressed",
	"focus",
	"disabled",
]

var _failures: Array[String] = []

func _initialize() -> void:
	var skin := UiSkin.new()
	_test_factory_resources_are_isolated(skin)
	_test_applied_styles_match_fresh_factory_styles(skin)
	_test_applied_styles_share_internal_templates(skin)

	# Warm script/type initialization so this measures steady-state dynamic UI churn.
	_measure_apply_overrides(skin, 120)
	var samples: Array[float] = []
	for _sample_index: int in range(3):
		samples.append(_measure_apply_overrides(skin, APPLY_ITERATIONS))
	samples.sort()
	print("UI_SKIN_APPLY_US_PER_BUTTON=%.3f" % samples[1])
	print("UI_SKIN_APPLY_ITERATIONS=%d" % APPLY_ITERATIONS)
	print("UI_SKIN_UNIQUE_APPLIED_STYLES=%d" % _unique_applied_style_count(skin))

	if _failures.is_empty():
		print("UI SKIN PERFORMANCE TEST: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("UI SKIN PERFORMANCE TEST: FAIL (%d failure(s))" % _failures.size())
	quit(1)

func _test_factory_resources_are_isolated(skin: UiSkin) -> void:
	var first: StyleBoxFlat = skin.make_button_style(UiSkin.VARIANT_STANDARD, UiSkin.STATE_NORMAL)
	var second: StyleBoxFlat = skin.make_button_style(UiSkin.VARIANT_STANDARD, UiSkin.STATE_NORMAL)
	_assert(first != second, "Public button style factories must return independent resources for safe caller customization")
	var original_background: Color = second.bg_color
	first.bg_color = Color.MAGENTA
	_assert(second.bg_color == original_background, "Mutating one public button style must not affect another factory result")

func _test_applied_styles_match_fresh_factory_styles(skin: UiSkin) -> void:
	for variant: String in VARIANTS:
		for toggle_mode: bool in [false, true]:
			var button := Button.new()
			button.toggle_mode = toggle_mode
			skin.apply_button_stylebox_overrides(button, variant)
			for theme_state: String in THEME_STATES:
				var expected_variant: String = variant
				var expected_state: String = theme_state
				match theme_state:
					"pressed":
						expected_state = UiSkin.STATE_SELECTED if toggle_mode else UiSkin.STATE_PRESSED
					"hover_pressed":
						expected_variant = UiSkin.VARIANT_SELECTED if toggle_mode and variant == UiSkin.VARIANT_STANDARD else variant
						expected_state = UiSkin.STATE_HOVER
				var actual: StyleBoxFlat = button.get_theme_stylebox(theme_state) as StyleBoxFlat
				var expected: StyleBoxFlat = skin.make_button_style(expected_variant, expected_state)
				_assert(
					_style_digest(actual) == _style_digest(expected),
					"Applied %s/%s style must remain visually identical to its fresh factory style" % [variant, theme_state]
				)
			button.free()

func _test_applied_styles_share_internal_templates(skin: UiSkin) -> void:
	var first := Button.new()
	var second := Button.new()
	skin.apply_button_stylebox_overrides(first, UiSkin.VARIANT_COMPACT)
	skin.apply_button_stylebox_overrides(second, UiSkin.VARIANT_COMPACT)
	var second_normal: StyleBox = second.get_theme_stylebox("normal")
	for theme_state: String in THEME_STATES:
		_assert(
			first.get_theme_stylebox(theme_state) == second.get_theme_stylebox(theme_state),
			"Applied %s styles should reuse UiSkin-owned immutable templates" % theme_state
		)
	skin.apply_button_stylebox_overrides(first, UiSkin.VARIANT_SELECTED)
	_assert(
		second.get_theme_stylebox("normal") == second_normal,
		"Restyling one button must not mutate another button's shared immutable template"
	)
	first.free()
	second.free()

func _unique_applied_style_count(skin: UiSkin) -> int:
	var instance_ids: Dictionary = {}
	for index: int in range(VARIANTS.size() * 2):
		var button := Button.new()
		button.toggle_mode = index >= VARIANTS.size()
		skin.apply_button_stylebox_overrides(button, VARIANTS[index % VARIANTS.size()])
		for theme_state: String in THEME_STATES:
			instance_ids[button.get_theme_stylebox(theme_state).get_instance_id()] = true
		button.free()
	_assert(instance_ids.size() <= VARIANTS.size() * 6, "Applied styles should be bounded by variant/state combinations")
	return instance_ids.size()

func _measure_apply_overrides(skin: UiSkin, iterations: int) -> float:
	var checksum: int = 0
	var started_us: int = Time.get_ticks_usec()
	for index: int in range(iterations):
		var button := Button.new()
		button.toggle_mode = index % 5 == 0
		var variant: String = VARIANTS[index % VARIANTS.size()]
		skin.apply_button_stylebox_overrides(button, variant)
		checksum += (button.get_theme_stylebox("normal") as StyleBoxFlat).border_width_bottom
		button.free()
	var elapsed_us: int = Time.get_ticks_usec() - started_us
	if checksum <= 0:
		_failures.append("Benchmark checksum should observe applied button styles")
	return float(elapsed_us) / float(iterations)

func _style_digest(style: StyleBoxFlat) -> Array:
	if style == null:
		return []
	return [
		style.bg_color,
		style.border_color,
		style.border_width_left,
		style.border_width_top,
		style.border_width_right,
		style.border_width_bottom,
		style.corner_radius_top_left,
		style.corner_radius_top_right,
		style.corner_radius_bottom_right,
		style.corner_radius_bottom_left,
		style.anti_aliasing,
		style.anti_aliasing_size,
		style.content_margin_left,
		style.content_margin_top,
		style.content_margin_right,
		style.content_margin_bottom,
		style.expand_margin_left,
		style.expand_margin_top,
		style.expand_margin_right,
		style.expand_margin_bottom,
		style.shadow_color,
		style.shadow_size,
		style.shadow_offset,
	]

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
