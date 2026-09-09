extends "res://tests/protagonist_cutout_gameplay_probe.gd"

const RangedAction = preload("res://scripts/protagonist_cutout/ranged_action.gd")
const Fx = preload("res://scripts/attack_fx_library.gd")
const PROOF_OUTPUT: String = "user://probes/protagonist_ranged_v01"
var _ranged_records: Array[Dictionary] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_capture = DisplayServer.get_name() != "headless"
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = SIZE
	root.size = SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROOF_OUTPUT))
	ProgressionStore.set_storage_path("user://ranged_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://ranged_probe_run.save")
	ProgressionStore.clear_saved_run()
	_instance = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_render_viewport = root
	if _capture:
		var surface := SubViewport.new()
		surface.size = SIZE
		surface.disable_3d = true
		surface.world_2d = World2D.new()
		surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(surface)
		_render_viewport = surface
	_render_viewport.add_child(_instance)
	await _settle()
	_board = _instance.get("board_view") as Control
	_texture_id = int(_snapshot()["texture_id"])
	var directions: Array[Vector2i] = [Vector2i(0,2), Vector2i(2,0), Vector2i(0,-2), Vector2i(-2,0)]
	for index: int in range(directions.size()):
		await _play_ranged("guiding_flare", "cast_" + _direction_name(index), directions[index], 37)
		await _play_ranged("pale_spark", "shoot_" + _direction_name(index), directions[index], 37)
	for entry: Array in [["root_snare",38],["razor_gale",38],["spark_dart",36],["frostbolt",36]]:
		await _play_ranged(entry[0], entry[0], Vector2i(2,0), entry[1])
	await _play_ranged("cinderburst", "physical_targeted_aoe", Vector2i(2,0), 33)
	await _play_ranged("guiding_flare", "reduced_cast", Vector2i(0,-2), 37, true)
	await _play_ranged("pale_spark", "reduced_shoot", Vector2i(-2,0), 37, true)
	# The same selection/activation handlers serve pointer and controller input.
	# Exercise focus/cancel and input handoff on the real changed pre-action state.
	await _fixture(Vector2i(3,3),Vector2i(5,3),false,["guiding_flare","pale_spark","brace","quick_stab","patch_up"])
	var router: Node = root.get_node_or_null("InputRouter")
	if router != null:
		router.call("set_forced_state_for_test", InputRouter.MODALITY_CONTROLLER, InputRouter.FAMILY_STEAM_DECK)
		_instance.call("_refresh_controller_interface")
		await _instance.call("_on_card_pressed",0)
		_instance.call("_on_board_tile_hovered",Vector2i(5,3))
		await _settle()
		await _ranged_still("controller_target")
		var before: Dictionary = (_instance.get("_combat_state") as Dictionary).duplicate(true)
		var cancel := InputEventAction.new()
		cancel.action = InputRouter.ACTION_CANCEL
		cancel.pressed = true
		_assert(await _instance.call("_handle_controller_input",cancel), "Controller cancel is handled during ranged targeting")
		_assert(before == _instance.get("_combat_state"), "Controller cancellation preserves combat")
		router.call("set_forced_state_for_test", InputRouter.MODALITY_POINTER, InputRouter.FAMILY_STEAM_DECK)
		_instance.call("_refresh_controller_interface")
		await _settle()
		await _ranged_still("pointer_handoff")
		router.call("clear_forced_state_for_test")
	var file := FileAccess.open(PROOF_OUTPUT + "/manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"size":[1920,1080],"ui_scale":1.0,"records":_ranged_records,"errors":_errors},"\t"))
	file.close()
	_instance.queue_free()
	await process_frame
	for error: String in _errors: push_error(error)
	print("PROTAGONIST RANGED GAMEPLAY PROBE: " + ("PASS" if _errors.is_empty() else "FAIL"))
	print(ProjectSettings.globalize_path(PROOF_OUTPUT))
	quit(0 if _errors.is_empty() else 1)

func _play_ranged(card: String, label: String, delta: Vector2i, expected_hp: int, reduced: bool = false) -> void:
	await _fixture(Vector2i(3,3),Vector2i(3,3)+delta,reduced,[card,"brace","quick_stab","pale_spark","patch_up"])
	await _instance.call("_on_card_pressed",0)
	_instance.call("_on_board_tile_hovered",Vector2i(3,3)+delta)
	await _settle()
	if label == "cast_southwest": await _ranged_still("pre_action")
	_instance.call("_on_board_tile_clicked",Vector2i(3,3)+delta)
	await _record_ranged(label,delta,reduced)
	var state: Dictionary = _instance.get("_combat_state")
	_assert(int(state["enemies"][0]["hp"]) == expected_hp, label + " applies its exact damage once")
	_assert(not bool(_instance.get("_animation_lock")),label + " returns input")
	_assert(not bool(_snapshot()["crossbow_visible"]),label + " removes the temporary crossbow after recovery")
	_assert(_snapshot()["facing"] == "front" and not bool(_snapshot()["mirrored"]),label + " returns to front idle")

func _record_ranged(label: String, delta: Vector2i, reduced: bool) -> void:
	var started: int = Time.get_ticks_usec()
	var finished: int = 0
	var images: Array[Image] = []
	var samples: Array[Dictionary] = []
	var last_capture: int = 0
	var saw_prepare: bool = false
	var saw_effect: bool = false
	var saw_charge: bool = false
	var saw_crossbow: bool = false
	var wanted: Dictionary = Cutout.direction_for_delta(delta)
	while Time.get_ticks_usec() - started < 8000000:
		if _capture: await RenderingServer.frame_post_draw
		else: await process_frame
		var now: int = Time.get_ticks_usec()
		var animation: Dictionary = _snapshot()
		var presentation: Dictionary = _board.get("presentation")
		var effect: Dictionary = presentation.get("effect", {})
		var motion: Dictionary = presentation.get("protagonist_motion", {})
		var clip: String = str(animation.get("clip", ""))
		var charge: float = float(motion.get("charge",0.0))
		saw_charge = saw_charge or charge > 0.1
		saw_crossbow = saw_crossbow or bool(animation.get("crossbow_visible",false))
		var progress: float = float(presentation.get("effect_progress",0.0))
		var origin := Vector2.ZERO
		if clip in ["cast","shoot"]:
			_assert(animation["facing"] == wanted["facing"] and animation["mirrored"] == wanted["mirrored"], label + " faces its selected target throughout preparation and release")
			if effect.is_empty(): saw_prepare = true
		if not str(effect.get("protagonist_ranged", "")).is_empty():
			saw_effect = true
			origin = _board.call("_protagonist_launch_point",effect,Vector2.ZERO)
			var style: String = Fx.style_for_effect(effect)
			var release: float = 0.18 if style == Fx.STYLE_DEFAULT else Fx.anticipation_end_progress(style)
			if not reduced and progress <= release:
				var visible_socket: Vector2 = _board.call("_protagonist_socket_world",clip == "shoot")
				_assert(origin.distance_to(visible_socket)<0.01,label + " releases from its actual visible hand or muzzle")
		_assert(int(animation["texture_id"]) == _texture_id,label + " retains one live cutout texture")
		var sample: Dictionary = {"seconds":float(now-started)/1000000.0,"animation":animation,"charge":charge,"effect":effect,"effect_progress":progress,"launch_point":origin}
		if not _capture or reduced or now - last_capture >= 30000:
			last_capture = now
			samples.append(sample)
			if _capture: images.append(_render_viewport.get_texture().get_image())
		if not bool(_instance.get("_animation_lock")) and finished == 0: finished = now
		if finished > 0 and now-finished > 100000: break
	_assert(saw_effect,label + " exercises the actual effect descriptor")
	if not reduced:
		_assert(saw_prepare,label + " raises its offhand before existing FX starts")
		if label.begins_with("cast") or label in ["root_snare","razor_gale","spark_dart","frostbolt"]:
			_assert(saw_charge,label + " charges briefly around the raised hand")
	if label.begins_with("shoot") or label in ["physical_targeted_aoe","reduced_shoot"]:
		_assert(saw_crossbow,label + " visibly equips a crossbow")
	var folder: String = PROOF_OUTPUT.path_join(label)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	if _capture:
		for index: int in range(images.size()): images[index].save_jpg(folder.path_join("frame_%04d.jpg"%index),0.96)
		for stage: String in ["raise","charge","release","recovery"]:
			var best: int = -1
			var gap: float = INF
			for index: int in range(samples.size()):
				var sample: Dictionary = samples[index]
				var active: String = str(sample["animation"].get("clip",""))
				if active not in ["cast","shoot"]: continue
				var score: float = absf(float(sample["animation"]["phase"]) - {"raise":0.20,"charge":0.34,"release":0.44,"recovery":0.83}[stage])
				if score < gap: best = index; gap = score
			if best >= 0: images[best].save_png(PROOF_OUTPUT.path_join(label+"_"+stage+".png"))
	_ranged_records.append({"label":label,"frames":samples,"prepare":saw_prepare,"effect":saw_effect,"charge":saw_charge,"crossbow":saw_crossbow,"reduced":reduced})

func _ranged_still(label: String) -> void:
	if not _capture: return
	await RenderingServer.frame_post_draw
	var image: Image = _render_viewport.get_texture().get_image()
	_assert(image.get_size() == SIZE,"Real renderer uses 1920x1080")
	image.save_png(PROOF_OUTPUT.path_join(label+".png"))
