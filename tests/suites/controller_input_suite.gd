extends RefCounted

const ControllerNavigationScript = preload("res://scripts/controller_navigation.gd")
const InputGlyphScript = preload("res://scripts/input_glyph.gd")
const InputRouterScript = preload("res://scripts/input_router.gd")
const SettingsStoreScript = preload("res://scripts/settings_store.gd")

static func run(expect: Callable) -> void:
	_test_controller_family_detection(expect)
	_test_controller_glyph_vocabulary(expect)
	_test_directional_navigation(expect)
	_test_input_map_contract(expect)
	_test_platform_ui_scale(expect)

static func _test_controller_family_detection(expect: Callable) -> void:
	expect.call(
		InputRouterScript.family_for_device_name("Microsoft Xbox Series X Controller") == InputRouterScript.FAMILY_XBOX,
		"Xbox controllers should select the Xbox glyph family"
	)
	expect.call(
		InputRouterScript.family_for_device_name("Steam Deck") == InputRouterScript.FAMILY_STEAM_DECK,
		"The integrated Steam Deck controller should select Deck glyphs"
	)
	expect.call(
		InputRouterScript.family_for_device_name("Steam Virtual Gamepad") == InputRouterScript.FAMILY_STEAM_DECK,
		"Steam Input's Deck virtual controller should retain Deck glyphs"
	)
	expect.call(
		InputRouterScript.family_for_device_name("Generic Gamepad", true) == InputRouterScript.FAMILY_STEAM_DECK,
		"A generic controller reported by SteamOS on Deck should use Deck glyphs"
	)
	expect.call(
		InputRouterScript.family_for_device_name("Xbox 360 Controller", true) == InputRouterScript.FAMILY_XBOX,
		"An external Xbox controller should keep Xbox glyphs even when connected to a Deck"
	)
	expect.call(
		InputRouterScript.family_for_steam_input_type(InputRouterScript.STEAM_INPUT_TYPE_STEAM_DECK_CONTROLLER) == InputRouterScript.FAMILY_STEAM_DECK,
		"Steam Input should identify the integrated Deck controller even when gamepad emulation masks its Godot device name"
	)
	expect.call(
		InputRouterScript.family_for_steam_input_type(InputRouterScript.STEAM_INPUT_TYPE_XBOXONE_CONTROLLER) == InputRouterScript.FAMILY_XBOX,
		"Steam Input should preserve Xbox glyphs for an external Xbox controller"
	)

static func _test_controller_glyph_vocabulary(expect: Callable) -> void:
	var router := InputRouterScript.new()
	expect.call(router.glyph_label(InputRouterScript.ACTION_ACCEPT, InputRouterScript.FAMILY_XBOX) == "A", "Confirm should use the physical A button")
	expect.call(router.glyph_label(InputRouterScript.ACTION_CANCEL, InputRouterScript.FAMILY_STEAM_DECK) == "B", "Back should use the physical B button")
	expect.call(router.glyph_label(InputRouterScript.ACTION_HAND_PREVIOUS, InputRouterScript.FAMILY_XBOX) == "LB", "Xbox previous-card glyph should say LB")
	expect.call(router.glyph_label(InputRouterScript.ACTION_HAND_PREVIOUS, InputRouterScript.FAMILY_STEAM_DECK) == "L1", "Deck previous-card glyph should say L1")
	expect.call(router.glyph_label(InputRouterScript.ACTION_HAND_NEXT, InputRouterScript.FAMILY_XBOX) == "RB", "Xbox next-card glyph should say RB")
	expect.call(router.glyph_label(InputRouterScript.ACTION_HAND_NEXT, InputRouterScript.FAMILY_STEAM_DECK) == "R1", "Deck next-card glyph should say R1")
	expect.call(router.glyph_label(InputRouterScript.ACTION_HAND_BUMPERS, InputRouterScript.FAMILY_XBOX) == "LB·RB", "Xbox card-cycle prompt should show both bumpers")
	expect.call(router.glyph_label(InputRouterScript.ACTION_HAND_BUMPERS, InputRouterScript.FAMILY_STEAM_DECK) == "L1·R1", "Deck card-cycle prompt should show both bumpers")
	expect.call(router.glyph_label(InputRouterScript.ACTION_MAP_ZOOM, InputRouterScript.FAMILY_XBOX) == "LT·RT", "Xbox map zoom should use the analog trigger glyphs")
	expect.call(router.glyph_label(InputRouterScript.ACTION_MAP_ZOOM, InputRouterScript.FAMILY_STEAM_DECK) == "L2·R2", "Deck map zoom should use the native trigger names")
	expect.call(InputGlyphScript.preferred_size(InputRouterScript.ACTION_ACCEPT).x >= 30.0, "Face glyphs should remain legible at handheld size")
	expect.call(InputGlyphScript.preferred_size(InputRouterScript.ACTION_HAND_PREVIOUS).x >= 42.0, "Shoulder glyphs should leave room for controller-specific labels")
	router.free()

static func _test_directional_navigation(expect: Callable) -> void:
	var right_event := InputEventJoypadMotion.new()
	right_event.axis = JOY_AXIS_LEFT_X
	right_event.axis_value = 0.8
	expect.call(ControllerNavigationScript.direction_from_event(right_event) == Vector2.RIGHT, "Left-stick right should resolve to one navigation step")
	var noise_event := InputEventJoypadMotion.new()
	noise_event.axis = JOY_AXIS_LEFT_Y
	noise_event.axis_value = 0.2
	expect.call(ControllerNavigationScript.direction_from_event(noise_event) == Vector2.ZERO, "Stick noise inside the deadzone should not move focus")
	var dpad_event := InputEventJoypadButton.new()
	dpad_event.button_index = JOY_BUTTON_DPAD_UP
	dpad_event.pressed = true
	expect.call(ControllerNavigationScript.direction_from_event(dpad_event) == Vector2.UP, "D-pad up should resolve to one navigation step")
	var candidates: Array[Dictionary] = [
		{"key": "left", "point": Vector2(-100.0, 0.0)},
		{"key": "right", "point": Vector2(100.0, 0.0)},
		{"key": "down", "point": Vector2(0.0, 100.0)},
	]
	var selected: Dictionary = ControllerNavigationScript.best_candidate_in_direction(Vector2.ZERO, Vector2.RIGHT, candidates)
	expect.call(str(selected.get("key", "")) == "right", "Grid navigation should snap to the tile centered in the requested screen direction")
	var magnetic_candidates: Array[Dictionary] = [
		{"key": "tile", "point": Vector2(40.0, 0.0), "snap_radius": 46.0},
		{"key": "header", "point": Vector2(100.0, 0.0), "snap_radius": 34.0},
	]
	var nearby: Dictionary = ControllerNavigationScript.nearest_candidate_within_radius(Vector2.ZERO, magnetic_candidates, 46.0)
	expect.call(str(nearby.get("key", "")) == "tile", "The analog cursor should magnetize only to a candidate inside its authored assist radius")
	var no_mans_land: Dictionary = ControllerNavigationScript.nearest_candidate_within_radius(Vector2(50.0, 80.0), magnetic_candidates, 46.0)
	expect.call(no_mans_land.is_empty(), "The analog cursor should remain free in no man's land instead of snapping back to a distant target")
	var distant_header: Dictionary = ControllerNavigationScript.nearest_candidate_within_radius(Vector2(60.0, 0.0), [magnetic_candidates[1]], 46.0)
	expect.call(distant_header.is_empty(), "Header controls should use a tighter snap radius than board tiles")
	expect.call(ControllerNavigationScript.wrapped_index(0, -1, 5) == 4, "Previous card should wrap from the first hand card to the last")
	expect.call(ControllerNavigationScript.wrapped_index(4, 1, 5) == 0, "Next card should wrap from the last hand card to the first")
	var analog_velocity: Vector2 = ControllerNavigationScript.cursor_velocity(Vector2(0.8, 0.4))
	expect.call(analog_velocity.x > analog_velocity.y and analog_velocity.y > 0.0, "Free cursor motion should preserve both stick axes instead of collapsing input to a logical grid direction")
	expect.call(ControllerNavigationScript.cursor_velocity(Vector2(0.1, -0.1)) == Vector2.ZERO, "Free cursor stick noise should remain inside a radial deadzone")
	var first_repeat: Dictionary = ControllerNavigationScript.repeat_step(Vector2(0.82, 0.31), Vector2.ZERO, 0, 1000)
	expect.call(first_repeat.get("step", Vector2.ZERO) == Vector2.RIGHT, "A fresh card-navigation push should advance exactly one card")
	var held_repeat: Dictionary = ControllerNavigationScript.repeat_step(Vector2(0.82, 0.58), first_repeat.get("direction", Vector2.ZERO), int(first_repeat.get("next_repeat_msec", 0)), 1016)
	expect.call(held_repeat.get("step", Vector2.ZERO) == Vector2.ZERO, "A second axis event from the same angled stick push must not skip an extra card")
	var skewed_release: Dictionary = ControllerNavigationScript.repeat_step(Vector2(0.18, 0.58), held_repeat.get("direction", Vector2.ZERO), int(held_repeat.get("next_repeat_msec", 0)), 1032)
	expect.call(skewed_release.get("step", Vector2.ZERO) == Vector2.ZERO and skewed_release.get("direction", Vector2.ZERO) == Vector2.RIGHT, "Uneven axis decay must stay latched to the original push instead of creating a second card step")
	var centered: Dictionary = ControllerNavigationScript.repeat_step(Vector2(0.10, 0.12), skewed_release.get("direction", Vector2.ZERO), int(skewed_release.get("next_repeat_msec", 0)), 1048)
	expect.call(centered.get("direction", Vector2.ONE) == Vector2.ZERO, "Discrete navigation should re-arm only after the whole stick returns inside the release deadzone")
	var fresh_vertical: Dictionary = ControllerNavigationScript.repeat_step(Vector2(0.12, 0.82), centered.get("direction", Vector2.ZERO), int(centered.get("next_repeat_msec", 0)), 1064)
	expect.call(fresh_vertical.get("step", Vector2.ZERO) == Vector2.DOWN, "A new push may choose another direction after the stick is re-armed")
	var delayed_repeat: Dictionary = ControllerNavigationScript.repeat_step(Vector2(0.82, 0.58), held_repeat.get("direction", Vector2.ZERO), int(held_repeat.get("next_repeat_msec", 0)), 1360)
	expect.call(delayed_repeat.get("step", Vector2.ZERO) == Vector2.RIGHT, "A held stick should repeat only after the deliberate initial delay")

static func _test_input_map_contract(expect: Callable) -> void:
	InputRouterScript.ensure_input_map()
	InputRouterScript.ensure_input_map()
	var expected_buttons: Dictionary = {
		InputRouterScript.ACTION_ACCEPT: JOY_BUTTON_A,
		InputRouterScript.ACTION_CANCEL: JOY_BUTTON_B,
		InputRouterScript.ACTION_HAND_TOGGLE: JOY_BUTTON_X,
		InputRouterScript.ACTION_PASS: JOY_BUTTON_Y,
		InputRouterScript.ACTION_HAND_PREVIOUS: JOY_BUTTON_LEFT_SHOULDER,
		InputRouterScript.ACTION_HAND_NEXT: JOY_BUTTON_RIGHT_SHOULDER,
		InputRouterScript.ACTION_MENU: JOY_BUTTON_START,
		InputRouterScript.ACTION_MAP: JOY_BUTTON_BACK,
	}
	for action_var: Variant in expected_buttons.keys():
		var action_name := StringName(action_var)
		var button_index: int = int(expected_buttons[action_name])
		expect.call(InputMap.has_action(action_name), "%s should exist in the runtime input map" % action_name)
		var matching_events: int = 0
		for event: InputEvent in InputMap.action_get_events(action_name):
			if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button_index:
				matching_events += 1
		expect.call(matching_events == 1, "%s should map its physical button exactly once" % action_name)
	var cancel_matches: int = 0
	for cancel_event: InputEvent in InputMap.action_get_events(&"ui_cancel"):
		if cancel_event is InputEventJoypadButton and (cancel_event as InputEventJoypadButton).button_index == JOY_BUTTON_B:
			cancel_matches += 1
	expect.call(cancel_matches == 1, "The B button should drive Godot's standard cancel action exactly once")

static func _test_platform_ui_scale(expect: Callable) -> void:
	expect.call(is_equal_approx(SettingsStoreScript.default_ui_scale(false), 1.00), "Desktop should retain the authored 100% UI scale")
	expect.call(is_equal_approx(SettingsStoreScript.default_ui_scale(true), 1.15), "Steam Deck should default to the more legible 115% UI scale")
