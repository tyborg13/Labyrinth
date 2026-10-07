extends "res://tests/staged_reward_choices_equivalence_test.gd"
const RerollReference = preload("res://tests/fixtures/reward_reroll_reference.gd")
var _source_checks: int = 0
var _preparation_boundaries: int = 0
var _pixel_differences: Array[Dictionary]
var _fixture: Dictionary

func _initialize() -> void:
	Parallel.apply_from_environment()
	_native = DisplayServer.get_name().to_lower() != "headless"
	Profile.set_storage_path("user://prepared_reward_profile.json")
	Profile.set_run_storage_path("user://prepared_reward_run.save")
	Profile.clear_saved_run()
	Profile.save_data(Tutorial.complete_tutorial(Profile.default_data()))
	Settings.set_storage_path("user://prepared_reward_settings.json")
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
		if original: scene.set_script(RerollReference)
		root.add_child(scene)
		scenes.append(scene)
	await _settle(8)
	if _native: await _settle_native_window()
	var engine := Run.new()
	var flow = load("res://tests/all_surface_performance_workload.gd").new()
	flow._probe = self
	_fixture = flow._reward_state()
	_fixture["progression"]["level"] = 3
	_fixture["progression"]["skill_ids"] = ["discerning_eye", "deferred_choice"]
	_fixture = engine.apply_progression_update(_fixture, _fixture["progression"])
	_fixture["pending_reward"]["intro_pending"] = false
	_fixture["analytics"] = {"run_id": "prepared_reward_oracle", "combat_counter": 0}
	for reduced: bool in [false, true]:
		var settings: Dictionary = Settings.load_settings()
		settings["reduced_motion"] = reduced
		Settings.save_settings(settings)
		Settings.apply_settings(settings, null, false)
		for hp: int in [1, 11, int(_fixture.get("player_max_hp", 24))]:
			var state: Dictionary = _fixture.duplicate(true)
			state["player_hp"] = hp
			_setup(state)
			var source: Dictionary = scenes[0]._run_state.duplicate(true)
			var predicted: Dictionary = engine.reroll_card_reward(source)
			# Check a NEW card's owned badge using the future IDs, and preserve the
			# same presentation with duplicates already in each ownership source.
			var next_card: String = str((predicted["pending_reward"]["cards"] as Array)[0])
			state["magic_inventory"] = [next_card, next_card]
			state["reward_cards"] = [next_card]
			_setup(state)
			await _wait_ready()
			var prepared: Node = scenes[0]._reward_reroll_preparation.stack
			if not is_instance_valid(prepared):
				print("PREPARED REWARD CHOICES FAILED EARLY: " + JSON.stringify({"errors": errors, "mode": scenes[0]._run_state.get("mode"), "skill_ids": scenes[0]._run_state.get("skill_ids"), "skill_state": scenes[0]._run_state.get("skill_state"), "lock": scenes[0]._animation_lock, "intro": scenes[0]._reward_intro_in_progress, "reveal": scenes[0]._reward_reveal_pending}))
				quit(1)
				return
			_check(is_instance_valid(prepared) and not prepared.is_visible_in_tree(), "Ready future choices must remain invisible")
			_check(prepared.get_process_mode() == Node.PROCESS_MODE_INHERIT and not prepared.can_process(), "Hidden ancestor must suppress future processing")
			_check(not prepared.find_child("RewardRerollButton", true, false), "Future action row must reflect consumed Discerning Eye")
			_check(root.gui_get_focus_owner() == null or not prepared.is_ancestor_of(root.gui_get_focus_owner()), "Preparing choices must not steal live focus")
			await _reroll_both("prepared hp=%d reduced=%s" % [hp, reduced], prepared)
			if _native and hp == 11:
				await _compare_native_stack("reduced=%s" % reduced)
				if not reduced: await _save_image("prepared_reward_reroll.png")
			cases += 1
	# Fast clicks retain the synchronous path. No frame, timer or input lock is
	# inserted between the live button press and canonical generation/save.
	_setup(_fixture)
	_check(not scenes[0]._reward_reroll_preparation.ready, "Immediate path must precede preparation")
	await _reroll_both("immediate original fallback")
	cases += 1
	# Consume a partly built tree before its next rendered boundary.
	_setup(_fixture)
	await _settle(2)
	var partial: Node = scenes[0]._reward_reroll_preparation.stack
	_check(is_instance_valid(partial) and not scenes[0]._reward_reroll_preparation.ready, "Partial preparation must not be published")
	await _reroll_both("partial original fallback")
	_check(not is_instance_valid(partial), "Partial fallback must release speculative cards")
	cases += 1
	for mutation: String in ["ownership", "hp", "progression", "cards", "viewport", "scale", "settings", "skin", "definition", "navigation"]:
		_setup(_fixture)
		await _wait_ready()
		var stale: Node = scenes[0]._reward_reroll_preparation.stack
		var changed: Dictionary = scenes[0]._run_state.duplicate(true)
		var definition: Dictionary
		var original_definition: Dictionary
		match mutation:
			"ownership": changed["magic_inventory"] = [str(scenes[0]._reward_reroll_preparation.predicted["pending_reward"]["cards"][0])]
			"hp": changed["player_hp"] = 1
			"progression": changed["progression"]["card_upgrades"] = {"frostbolt": 1}
			"cards": changed["pending_reward"]["cards"] = ["spark_dart"]
			"viewport": root.size = Vector2i(1600, 900)
			"scale": root.content_scale_factor = 1.125
			"settings":
				for scene: Node in scenes: scene._settings["reduced_motion"] = not bool(scene._settings["reduced_motion"])
			"skin":
				for scene: Node in scenes: scene._ui_skin = load("res://scripts/ui_skin.gd").new()
			"definition":
				var id: String = str(scenes[0]._reward_reroll_preparation.predicted["pending_reward"]["cards"][0])
				definition = Data.cards()[id]
				original_definition = definition.duplicate(true)
				definition["description"] = "A mutable definition changed after preparation."
			"navigation": changed["mode"] = "room"; changed["pending_reward"] = {}
		for scene: Node in scenes:
			scene._run_state = changed.duplicate(true)
			if mutation == "progression": scene._sync_progression_from_run()
		_check(not scenes[0]._reward_reroll_preparation.matches_source(scenes[0]), "Changed source must reject readiness: " + mutation)
		if mutation == "navigation":
			scenes[0]._prepare_reward_reroll_choices()
			await _settle(3)
		else:
			await _reroll_both("stale fallback " + mutation)
		_check(not is_instance_valid(stale), "Rejected readiness must release its controls: " + mutation)
		if not definition.is_empty():
			definition.clear(); definition.merge(original_definition)
		root.size = Vector2i(1920, 1080)
		root.content_scale_factor = 1.0
		cases += 1
	# Canonical output mismatch is checked independently from the source guard.
	_setup(_fixture)
	await _wait_ready()
	scenes[0]._reward_reroll_preparation.predicted["notice"] = "corrupt speculative result"
	await _reroll_both("canonical prediction mismatch fallback")
	cases += 1
	# A freed owner cannot resume bound native card builders. Every surviving
	# prepared node belongs to the scene's hidden host and dies with that scene.
	_setup(_fixture)
	await _settle(8)
	scenes[0]._reward_reroll_preparation.cancel()
	scenes[0]._prepare_reward_reroll_choices()
	await _settle(2)
	var owner: Node = scenes[0]
	owner.free()
	await _settle(8)
	_check(not is_instance_valid(owner), "Freed owner must remain freed across preparation boundaries")
	cases += 1
	for scene: Node in scenes:
		if is_instance_valid(scene): scene.free()
	await _settle(8)
	_check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "All future, adopted and canceled reward controls must be released")
	print("PREPARED REWARD CHOICES RESULT: " + JSON.stringify({"cases": cases, "differences": differences, "pixel_differences": _pixel_differences, "errors": errors, "native": _native, "source_checks": _source_checks, "preparation_boundaries": _preparation_boundaries, "orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}))
	quit(0 if errors.is_empty() else 1)

func _setup(state: Dictionary) -> void:
	Profile.save_data(state.get("progression", {}))
	for scene: Node in scenes:
		scene._reward_reroll_preparation.cancel()
		scene._progression = (state.get("progression", {}) as Dictionary).duplicate(true)
		scene._initial_ui_complete = false
		scene._load_run_state(state.duplicate(true))
		scene._initial_ui_complete = false
		scene._settings = Settings.load_settings()
		scene._close_dialogue()
		scene._large_map_scrim.hide()
		scene._pre_battle_scrim.hide()
		scene._animation_lock = false
		scene._reward_intro_suppressed = false
		scene._reward_intro_in_progress = false
		scene._reward_reveal_pending = false
		scene._refresh_ui()
		scene.set_process(false)

func _wait_ready() -> void:
	var scene: Node = scenes[0]
	var source: Dictionary = scene._run_state.duplicate(true)
	var progression: Dictionary = scene._progression.duplicate(true)
	var saved: Dictionary = Profile.load_saved_run()
	seed(984716)
	var expected_random: int = randi()
	seed(984716)
	for frame: int in range(60):
		if scene._reward_reroll_preparation.ready: break
		await _settle(1)
		_preparation_boundaries += 1
		_check(scene._run_state == source and scene._progression == progression, "Every native preparation boundary must preserve all committed state")
		_check(Profile.load_saved_run() == saved, "Preparation must not write a speculative save")
		_check(not scene._animation_lock and not root.gui_disable_input, "Preparation must preserve immediate live input")
		_source_checks += 1
	_check(randi() == expected_random, "Prediction and hidden controls must not advance global RNG")
	_check(scene._reward_reroll_preparation.ready, "Bounded native preparation must eventually become ready")

func _reroll_both(label: String, prepared: Node = null) -> void:
	var engine := Run.new()
	var expected: Dictionary = engine.reroll_card_reward(scenes[0]._run_state)
	for scene: Node in scenes:
		var button: Button = scene._relic_choice_bar.find_child("RewardRerollButton", true, false)
		_check(button != null and not button.disabled, "Live ordinary reward must expose public Reroll: " + label)
		if button != null: button.emit_signal("pressed")
		_check(scene._run_state["pending_reward"] == expected["pending_reward"] and scene._run_state["skill_state"] == expected["skill_state"], "Real action must commit the canonical reward and skill event: " + label)
		var saved: Dictionary = Profile.load_saved_run()
		_check(saved.get("pending_reward") == expected["pending_reward"] and saved.get("skill_state") == expected["skill_state"], "Real reroll must preserve the strong save boundary: " + label)
	if is_instance_valid(prepared):
		_check(prepared.get_parent() == scenes[0]._relic_choice_bar, "Ready canonical choices must reuse the whole original stack: " + label)
	await _settle(8)
	_compare_choices(label)
	_check(scenes[0]._run_state == scenes[1]._run_state, "Full post-refresh committed state must match the independent reference: " + label)
	var stack: Control = scenes[0]._relic_choice_bar.get_child(0)
	_check(stack.can_process(), "Adopted controls must inherit live processing: " + label)
	for node: Node in stack.find_children("*", "Control", true, false):
		for side: Side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			var path: NodePath = (node as Control).get_focus_neighbor(side)
			_check(path.is_empty() or node.get_node_or_null(path) != null, "All adopted focus paths must resolve: " + label)

func _freeze_stack(stack: Node) -> void:
	for node: Node in stack.find_children("*", "Control", true, false):
		if node.get("material") is ShaderMaterial:
			var material: ShaderMaterial = node.get("material")
			if node.name == "RarityGemGlow":
				material.set_shader_parameter("animate", 0.0)
				material.set_shader_parameter("phase", 0.0)
				material.set_shader_parameter("sparkle", 0.0)
		if node.name == "TimeCostBadge": node.set_process(false)

func _set_scene_visibility(scene: Node, visible: bool) -> void:
	scene.visible = visible
	for layer: CanvasLayer in scene.find_children("*", "CanvasLayer", true, false):
		layer.visible = visible

func _compare_native_stack(label: String) -> void:
	var images: Array[Image]
	for index: int in range(scenes.size()):
		for other: Node in scenes: _set_scene_visibility(other, false)
		var scene: Node = scenes[index]
		_set_scene_visibility(scene, true)
		scene.get_node("BoardUnderlay").hide()
		Input.warp_mouse(Vector2(8, 8))
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(8, 8)
		root.push_input(motion)
		var stack: Control = scene._relic_choice_bar.get_child(0)
		_freeze_stack(stack)
		await _settle(3)
		await RenderingServer.frame_post_draw
		_check(root.size == Vector2i(1920, 1080) and DisplayServer.window_get_size(root.get_window_id()) == Vector2i(1920, 1080) and is_equal_approx(root.content_scale_factor, 1.0), "Native reward proof must render at actual 1920x1080 and 100%")
		var image: Image = root.get_texture().get_image()
		var ratio: Vector2 = Vector2(image.get_size()) / Vector2(root.size)
		var rectangle := Rect2i(stack.global_position * ratio, stack.size * ratio)
		var cropped: Image = image.get_region(rectangle)
		cropped.save_png(ProjectSettings.globalize_path("user://reward_crop_%s_%s.png" % [label.replace("=", "_"), index]))
		images.append(cropped)
		scene.get_node("BoardUnderlay").show()
	var changed: int = 0
	if images[0].get_size() == images[1].get_size():
		var a: PackedByteArray = images[0].get_data()
		var b: PackedByteArray = images[1].get_data()
		for index: int in range(a.size()):
			if a[index] != b[index]: changed += 1
	else: changed = -1
	if changed != 0: _pixel_differences.append({"case": label, "changed_channels": changed, "actual_size": images[0].get_size(), "reference_size": images[1].get_size()})
	_check(changed == 0, "Frozen native reward pixels must match the original stack exactly: " + label)
	for scene: Node in scenes: _set_scene_visibility(scene, true)

func _save_image(filename: String) -> void:
	_set_scene_visibility(scenes[1], false)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image.get_size() != Vector2i(1920, 1080): image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	var path: String = ProjectSettings.globalize_path("user://" + filename)
	image.save_png(path)
	print("PREPARED REWARD CHOICES IMAGE: " + path)
	_set_scene_visibility(scenes[1], true)
