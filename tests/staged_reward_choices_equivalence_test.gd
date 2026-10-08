extends "res://tests/retained_character_inventory_equivalence_test.gd"

const RewardReference = preload("res://tests/fixtures/reward_choice_reference.gd")
const Initial = preload("res://scripts/run_initial_preparation.gd")
const Card = preload("res://scripts/card_widget.gd")
var _loading_scene: Node
var _loading_state: Dictionary
var _loading_active: bool = true
var _free_at_boundary: bool = false
var _cancel_at_boundary: bool = false
var _boundary_count: int = 0
var _native: bool = false

func _initialize() -> void:
	Parallel.apply_from_environment()
	_native = DisplayServer.get_name().to_lower() != "headless"
	Profile.set_storage_path("user://staged_reward_profile.json")
	Profile.set_run_storage_path("user://staged_reward_run.save")
	Profile.clear_saved_run()
	Profile.save_data(Tutorial.complete_tutorial(Profile.default_data()))
	Settings.set_storage_path("user://staged_reward_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = "windowed"
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	Settings.apply_settings(settings, null, false)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920, 1080)
	_run.call_deferred()

func _run() -> void:
	for original: bool in [false, true]:
		var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
		if original: scene.set_script(RewardReference)
		root.add_child(scene)
		scenes.append(scene)
	await _settle(8)
	if _native: await _settle_native_window()
	for scene: Node in scenes:
		scene._initial_ui_complete = false
		scene._close_dialogue()
		scene._large_map_scrim.hide()
		scene._pre_battle_scrim.hide()
		scene.set_process(false)
	var engine := Run.new()
	var flow = load("res://tests/ui_flow_performance_workload.gd").new()
	flow._probe = self
	var state: Dictionary = engine.repair_loaded_run_state(flow._reward_state())
	var fixtures: Array[Dictionary]
	fixtures.assign([
		{"cards": [], "heal": 5, "reroll": false},
		{"cards": ["spark_dart"], "heal": 0, "reroll": false},
		{"cards": ["frostbolt", "frostbolt"], "heal": 5, "reroll": false},
		{"cards": ["spark_dart", "frostbolt", "gust_step", "wildfire_halo"], "heal": 5, "reroll": true},
	])
	for reduced: bool in [false, true]:
		var settings: Dictionary = Settings.load_settings()
		settings["reduced_motion"] = reduced
		Settings.save_settings(settings)
		Settings.apply_settings(settings, null, false)
		for reveal: bool in [false, true]:
			for fixture: Dictionary in fixtures:
				var current: Dictionary = state.duplicate(true)
				current["pending_reward"]["cards"] = fixture["cards"].duplicate()
				current["pending_reward"]["heal_amount"] = fixture["heal"]
				current["pending_reward"]["intro_pending"] = false
				current["skill_ids"] = ["discerning_eye"] if fixture["reroll"] else []
				current["progression"]["skill_ids"] = current["skill_ids"].duplicate()
				current["magic_inventory"] = ["frostbolt"]
				current["reward_cards"] = ["frostbolt"]
				for scene: Node in scenes:
					scene._run_state = current.duplicate(true)
					scene._settings = settings.duplicate(true)
					scene._sync_progression_from_run()
					scene._reward_intro_suppressed = false
					scene._reward_reveal_pending = reveal
				_loading_scene = scenes[0]
				_loading_state = scenes[0]._run_state.duplicate(true)
				_loading_active = true
				_boundary_count = 0
				root.gui_disable_input = true
				await Initial.prepare_reward_choices_for(scenes[0], _present_loading, _loading_alive)
				_check(_boundary_count > 0, "Staged choices must yield while loading still owns input")
				root.gui_disable_input = false
				scenes[1]._refresh_ui_choices()
				await _settle(8)
				var label: String = "cards=%s heal=%s reroll=%s reduced=%s reveal=%s" % [fixture["cards"], fixture["heal"], fixture["reroll"], reduced, reveal]
				_compare_choices(label)
				_check(scenes[0]._run_state == _loading_state and scenes[0]._run_state == scenes[1]._run_state, "Choice jobs must preserve the full committed state: " + label)
				_check(not scenes[0]._initial_ui_complete, "Choice jobs must not independently declare the whole run ready")
				cases += 1
				if _native and not reduced and not reveal and bool(fixture["reroll"]):
					scenes[1].hide()
					await RenderingServer.frame_post_draw
					_check(root.size == Vector2i(1920, 1080) and DisplayServer.window_get_size(root.get_window_id()) == Vector2i(1920, 1080) and is_equal_approx(root.content_scale_factor, 1.0), "Native reward proof must render at 1920x1080 and 100% before Retina normalization")
					var image: Image = root.get_texture().get_image()
					if image.get_size() != Vector2i(1920, 1080): image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
					var image_path: String = ProjectSettings.globalize_path("user://staged_reward_choices.png")
					image.save_png(image_path)
					print("STAGED REWARD CHOICES IMAGE: " + image_path)
					scenes[1].show()
	# The default path remains a complete synchronous refresh, even when repeated
	# before queued deletes drain. Compare that path with the frozen original too.
	for scene: Node in scenes:
		scene._reward_reveal_pending = false
		for repeat: int in range(3): scene._refresh_ui_choices()
	await _settle(8)
	_compare_choices("ordinary same-frame repeated synchronous refresh")
	cases += 1
	# Cancellation happens at the initial rendered boundary before any cards.
	_loading_scene = scenes[0]
	_loading_state = scenes[0]._run_state.duplicate(true)
	_loading_active = true
	_cancel_at_boundary = true
	root.gui_disable_input = true
	await Initial.prepare_reward_choices_for(_loading_scene, _present_loading, _loading_alive)
	_check(_loading_scene.find_child("RewardCardRow", true, false).get_child_count() == 0, "Canceled loading must not execute queued card jobs")
	cases += 1
	# A freed destination must not resume its bound per-card callables.
	_loading_active = true
	_free_at_boundary = true
	await Initial.prepare_reward_choices_for(_loading_scene, _present_loading, _loading_alive)
	_check(not is_instance_valid(_loading_scene), "Freeing the loading destination must stop before any further native UI work")
	root.gui_disable_input = false
	cases += 1
	for scene: Node in scenes:
		if is_instance_valid(scene): scene.free()
	await _settle(8)
	_check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "Staged/canceled reward choices must release all owned controls")
	print("STAGED REWARD CHOICES RESULT: " + JSON.stringify({"cases": cases, "differences": differences, "errors": errors, "native": _native, "orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}))
	quit(0 if errors.is_empty() else 1)

func _present_loading() -> void:
	_boundary_count += 1
	_check(root.gui_disable_input, "Every card preparation boundary must retain the public loading input lock")
	_check(is_instance_valid(_loading_scene) and _loading_scene._run_state == _loading_state, "Every preparation boundary must preserve the full run snapshot")
	if _cancel_at_boundary:
		_cancel_at_boundary = false
		_loading_active = false
	if _free_at_boundary:
		_free_at_boundary = false
		_loading_scene.free()
	await process_frame

func _loading_alive() -> bool:
	return _loading_active

func _compare_choices(label: String) -> void:
	var actual: Dictionary = _snapshot(scenes[0]._relic_choice_overlay, scenes[0]._relic_choice_overlay)
	var original: Dictionary = _snapshot(scenes[1]._relic_choice_overlay, scenes[1]._relic_choice_overlay)
	if actual != original: _print_differences(actual, original, label)
	_check(actual == original, "Staged choice geometry, rules, styles, art, badges and native callbacks must equal the complete original: " + label)

func _snapshot(node: Node, origin: Control) -> Dictionary:
	var result: Dictionary = super._snapshot(node, origin)
	if node is Control:
		for property: String in ["focus_neighbor_left", "focus_neighbor_right", "focus_neighbor_top", "focus_neighbor_bottom"]:
			var path: NodePath = node.get(property)
			result[property] = "" if path.is_empty() else _callback_argument(node.get_node_or_null(path), origin)
		for signal_name: String in ["gui_input", "focus_entered", "focus_exited"]:
			result[signal_name + "_callbacks"] = _callbacks(node, signal_name, origin)
	if node is Card:
		for property: String in ["card_id", "_card_override", "_selected", "_dimmed", "_usable", "_previewed", "_interactive", "_printed_playable", "_rules_text_face", "_hover_lift", "_hover_scale", "_summary_bbcode", "_summary_rows"]:
			result[property] = node.get(property)
		result["activated_callbacks"] = _callbacks(node, "activated", origin)
	if node is RichTextLabel:
		for property: String in ["text", "bbcode_enabled", "fit_content", "scroll_active", "autowrap_mode"]: result[property] = node.get(property)
		result["rich_font"] = node.get_theme_font("normal_font").get_instance_id()
		result["rich_font_size"] = node.get_theme_font_size("normal_font_size")
		result["rich_outline_size"] = node.get_theme_constant("outline_size")
	return result

func _callbacks(node: Node, signal_name: String, origin: Control) -> Array[Dictionary]:
	var callbacks: Array[Dictionary]
	for connection: Dictionary in node.get_signal_connection_list(signal_name):
		var callback: Callable = connection["callable"]
		var arguments: Array
		for argument: Variant in callback.get_bound_arguments(): arguments.append(_callback_argument(argument, origin))
		callbacks.append({"method": callback.get_method(), "arguments": arguments})
	return callbacks

func _settle_native_window() -> void:
	var stable: int = 0
	var deadline: int = Time.get_ticks_msec() + 5000
	while stable < 20 and Time.get_ticks_msec() < deadline:
		if root.mode != Window.MODE_WINDOWED or root.size != Vector2i(1920, 1080) or DisplayServer.window_get_size(root.get_window_id()) != Vector2i(1920, 1080):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			root.mode = Window.MODE_WINDOWED
			root.size = Vector2i(1920, 1080)
			DisplayServer.window_set_size(Vector2i(1920, 1080))
			stable = 0
		else: stable += 1
		await create_timer(0.05).timeout
	_check(stable == 20, "Native reward equivalence must retain its authored geometry for a full second before cases")
