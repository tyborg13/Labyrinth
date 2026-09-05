extends "res://tests/aoe_targeting_preview_probe.gd"

const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const ARROW_OUTPUT := "user://probes/player_aim_curve_ownership"

var _ownership_metrics: Dictionary = {}
var _render_cases: Array[Dictionary]
var _pixel_board: Control

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.size = VIEWPORT_SIZE
	ProgressionStore.set_storage_path("user://aim_curve_progression.json")
	ProgressionStore.set_run_storage_path("user://aim_curve_run.save")
	SettingsStore.set_storage_path("user://aim_curve_settings.json")
	ProgressionStore.clear_saved_run()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARROW_OUTPUT))
	await _capture_states()
	var file := FileAccess.open(ProjectSettings.globalize_path(ARROW_OUTPUT.path_join("ownership-proof.json")), FileAccess.WRITE)
	file.store_string(JSON.stringify(_ownership_metrics, "\t"))
	file.close()
	print(ProjectSettings.globalize_path(ARROW_OUTPUT))
	if _failures.is_empty():
		print("PLAYER AIM CURVE OWNERSHIP PROBE: PASS")
		quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		print("PLAYER AIM CURVE OWNERSHIP PROBE: FAIL")
		quit(1)

func _capture_states() -> void:
	_capture_viewport = SubViewport.new()
	_capture_viewport.size = VIEWPORT_SIZE
	_capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_capture_viewport)
	var instance: Node = load("res://scenes/run_scene.tscn").instantiate()
	_capture_viewport.add_child(instance)
	await _settle()
	var router: Node = root.get_node_or_null("InputRouter")
	if router != null:
		router.call("set_forced_state_for_test", "pointer", "steam_deck")
	for reduced_motion: bool in [false, true]:
		var settings: Dictionary = SettingsStore.default_settings()
		settings["ui_scale"] = 1.0
		settings["reduced_motion"] = reduced_motion
		instance.set("_settings", settings)
		for card_id: String in ["cinderburst", "bone_dart", "updraft"]:
			await _capture_player_case(instance, card_id, reduced_motion)
		await _capture_enemy_case(instance, reduced_motion)
	instance.queue_free()
	await _settle()
	_pixel_board = CombatBoardView.new()
	_pixel_board.size = Vector2(VIEWPORT_SIZE)
	_capture_viewport.add_child(_pixel_board)
	await _settle()
	_pixel_board.set_process(false)
	_pixel_board.set("_idle_elapsed", 0.0)
	for sample: Dictionary in _render_cases:
		await _verify_native_curve_pixels(sample)
	_pixel_board.queue_free()
	await _settle()
	_capture_viewport.queue_free()

func _capture_player_case(instance: Node, card_id: String, reduced_motion: bool) -> void:
	await _install_combat_fixture(instance, card_id, 9811)
	await _arm_printed_card(instance)
	var target := Vector2i(4, 4) if card_id == "cinderburst" else Vector2i(5, 4)
	var board: Control = instance.get("board_view") as Control
	var point: Vector2 = board.get_global_transform() * (board.call("world_position_for_tile", target) as Vector2)
	instance.call("_sync_click_targeting_arrow", point)
	instance.call("_on_board_tile_hovered", target)
	await _settle()
	var label: String = ("reduced_" if reduced_motion else "normal_") + card_id
	var presentation: Dictionary = (board.get("presentation") as Dictionary).duplicate(true)
	var effect: Dictionary = presentation.get("effect", {}) as Dictionary
	var arrow: Control = instance.get("_drag_target_arrow") as Control
	_expect(arrow != null and arrow.visible, label + " must retain the actual hand targeting arrow")
	_expect(bool(effect.get("preview", false)), label + " must produce a legal preview through real card selection")
	_expect(not bool(effect.get("target_curve_visible", true)), label + " production payload must yield the board curve")
	_expect(not (effect.get("damage_preview", {}) as Dictionary).is_empty() or card_id == "updraft", label + " must keep damage evidence")
	if card_id == "cinderburst":
		_expect((presentation.get("focus_tiles", []) as Array).size() == 5, label + " must retain the full cross footprint")
	for action_type: String in ["ranged", "aoe", "push", "pull"]:
		_expect(not bool(instance.call("_player_preview_target_curve_visible", action_type)), label + " active hand arrow must own " + action_type + " aim")
	await _save_screenshot(ARROW_OUTPUT.path_join(label + ".png"))
	_ownership_metrics[label] = {"hand_arrow_visible": arrow != null and arrow.visible, "curve_flag": effect.get("target_curve_visible"), "focus_tiles": presentation.get("focus_tiles", []), "force_tiles": effect.get("force_tiles", [])}
	if card_id != "updraft":
		_render_cases.append({"label": label, "state": (board.get("combat_state") as Dictionary).duplicate(true), "presentation": presentation, "targets": (board.get("attack_tiles") as Array).duplicate()})
	else:
		# A direct Push click commits using the default direction. Exercise the
		# same production oriented payload without committing or changing rules.
		var active: Dictionary = instance.call("_active_card_preview")
		var preview_state: Dictionary = active.get("state", {}) as Dictionary
		var action: Dictionary = instance.call("_shortcut_action_with_default_force_direction", preview_state, active.get("action", {}), target)
		var oriented_effect: Dictionary = instance.call("_preview_effect_for_target", preview_state, PLAYER_TILE, target, action)
		var force_tiles: Array = oriented_effect.get("force_tiles", []) as Array
		_expect(not force_tiles.is_empty(), label + " oriented production payload must preserve forced floor destinations")
		_expect(not bool(oriented_effect.get("target_curve_visible", true)), label + " oriented production payload must still yield the aim curve")
		presentation["effect"] = oriented_effect
		instance.call("_render_board_state", preview_state, presentation)
		await _settle()
		await _save_screenshot(ARROW_OUTPUT.path_join(label + "_force_payload.png"))
		_ownership_metrics[label]["oriented_force_tiles"] = force_tiles
	instance.call("_on_cancel_requested")
	await _settle()

func _capture_enemy_case(instance: Node, reduced_motion: bool) -> void:
	await _install_combat_fixture(instance, "bone_dart", 9811)
	instance.call("_on_board_tile_hovered", Vector2i(5, 4))
	await _settle()
	var board: Control = instance.get("board_view") as Control
	var presentation: Dictionary = board.get("presentation") as Dictionary
	var ranged_count: int = 0
	for threat: Dictionary in presentation.get("enemy_threat_previews", []):
		var effect: Dictionary = board.call("_enemy_threat_ranged_effect", threat)
		if effect.is_empty():
			continue
		ranged_count += 1
		_expect(bool(board.call("_target_preview_curve_visible", effect)), "Enemy intent must retain the airborne curve")
	_expect(ranged_count > 0, "Acolyte hover must expose its actual ranged intent")
	var label: String = "reduced_enemy_intent" if reduced_motion else "normal_enemy_intent"
	await _save_screenshot(ARROW_OUTPUT.path_join(label + ".png"))
	_ownership_metrics[label] = {"ranged_threats": ranged_count}

func _verify_native_curve_pixels(sample: Dictionary) -> void:
	var label: String = str(sample["label"])
	var actual: Dictionary = (sample["presentation"] as Dictionary).duplicate(true)
	actual["ambient_time_seconds"] = 42.0
	actual["umbra_time_seconds"] = 42.0
	actual["pulse_attack_tiles"] = false
	var baseline: Dictionary = actual.duplicate(true)
	# An unknown effect kind has no action drawing at all. Keeping its damage
	# payload, focused tiles and actor state makes this an independent no-curve
	# reference, rather than merely asserting that a flag was set correctly.
	baseline["effect"]["kind"] = "no_action_reference"
	var reference: Image = await _render_pixel_case(sample, baseline)
	var result: Image = await _render_pixel_case(sample, actual)
	var identical: bool = reference.get_data() == result.get_data()
	_expect(identical, label + " preview must match the native no-action-curve reference")
	var legacy: Dictionary = actual.duplicate(true)
	legacy["effect"]["target_curve_visible"] = true
	var positive_control: Image = await _render_pixel_case(sample, legacy)
	var curve_pixels: int = 0
	for y: int in range(0, VIEWPORT_SIZE.y, 2):
		for x: int in range(0, VIEWPORT_SIZE.x, 2):
			var a: Color = result.get_pixel(x, y)
			var b: Color = positive_control.get_pixel(x, y)
			if maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) > 0.04:
				curve_pixels += 1
	_expect(curve_pixels > 35, label + " positive control must prove the removed trajectory occupied native pixels")
	_ownership_metrics[label]["native_identical_to_no_curve_reference"] = identical
	_ownership_metrics[label]["removed_curve_samples"] = curve_pixels
	_expect(result.save_png(ProjectSettings.globalize_path(ARROW_OUTPUT.path_join(label + "_board_pixels.png"))) == OK, "Must save native board proof")
	print("PLAYER_CURVE_PIXEL_PROOF %s %s" % [label, JSON.stringify(_ownership_metrics[label])])

func _render_pixel_case(sample: Dictionary, presentation: Dictionary) -> Image:
	_pixel_board.call("set_combat_state", sample["state"], [], sample["targets"], Vector2i(-1, -1), "", "", {}, {}, presentation)
	await _settle()
	return _capture_viewport.get_texture().get_image()

func _room_layout() -> Dictionary:
	var layout: Dictionary = super._room_layout()
	layout["name"] = "Player Aim Ownership Proof"
	layout["enemies"] = [{"id": 1, "type": "acolyte", "pos": Vector2i(5, 4), "hp": 12, "max_hp": 12, "block": 0}]
	return layout
