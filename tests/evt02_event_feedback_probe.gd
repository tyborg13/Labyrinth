extends SceneTree
## Windowed only. --check-only and --write-proof-contract never render.
const Suite = preload("res://tests/suites/event_feedback_suite.gd")
const Fixtures = preload("res://tests/suites/event_view_suite.gd")
const Events = preload("res://scripts/event_rules.gd")
const Data = preload("res://scripts/game_data.gd")
const Feedback = preload("res://scripts/event_scene_feedback.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const PROOF_SIZE: Vector2i = Vector2i(1920, 1080)
const PROOF_DIRECTORY: String = "user://evt-02-feedback"
const PROOF_SETTLE_FRAMES: int = 3
const PROOF_MID_BEAT_SECONDS: float = 0.09
const TYPOGRAPHY_DIRECTORY: String = "user://qa66-event-typography"
const TYPOGRAPHY_HOVER_SETTLE_SECONDS: float = 0.2
const PROOF_BEATS: Array = [
	["whispering_well", "ember", "card"], ["fallen_lantern_bearer", "satchel", "item"],
	["bloodletters_basin", "bleed", "relic"], ["ossuary_gamblers", "wager_embers", "equipment"],
	["lost_cartographer", "embers", "embers"], ["bloodletters_basin", "bleed", "hp"],
	["whispering_well", "drink", "heal"], ["weeping_statue", "pray", "heal_percent"],
	["starving_pilgrim", "item", "max_hp_up"], ["ossuary_gamblers", "wager_blood", "max_hp_down"],
	["hanged_knight", "cut", "bane"], ["shrine_last_door", "candle", "blessing"],
	["shrine_last_door", "kneel", "defiance"], ["starving_pilgrim", "item", "lose_item"],
	["mirror_of_skins", "hand", "transform_magic"], ["abandoned_forge", "weapon", "reforge"],
	["lost_cartographer", "survey", "reveal"], ["evt02_scout_fixture", "take", "scout"]
]
var failures: Array[String]
var scene: Node
var viewport: SubViewport

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--write-proof-contract"):
		var file := FileAccess.open(args[args.find("--write-proof-contract") + 1], FileAccess.WRITE)
		if file == null: quit(1); return
		file.store_string(JSON.stringify(proof_contract(), "\t") + "\n")
		print("EVT02 proof contract written")
		quit()
	elif args.has("--qa66-typography"):
		_typography_proof.call_deferred()
	elif args.has("--check-only"):
		_check_fixtures.call_deferred()
	else: _probe.call_deferred()

static func proof_contract() -> Dictionary:
	var images: Array = []
	for fixture: Array in Suite.CASES:
		for input: String in ["hover", "focus"]: images.append(_image("preview_%s_%s.png" % [fixture[2], input]))
	for beat: Array in PROOF_BEATS: images.append(_image("beat_%s.png" % beat[2]))
	for name: String in ["preview_transform_three", "preview_disabled", "preview_plain", "preview_reduced", "beat_reduced", "beat_skipped", "combat_omen_start"]: images.append(_image(name + ".png"))
	return {"min_images": images.size(), "expected_sizes": ["1920x1080"], "required_images": images}

static func _image(filename: String) -> Dictionary:
	return {"pattern": "*" + filename, "width": 1920, "height": 1080, "regions": [{"rect": [166, 176, 1062, 728], "min_luma_range": 8, "min_luma_stdev": 2}]}

func _add_debug_scout() -> void:
	# No authored Scout outcome currently exists. This debug-only catalog entry
	# exercises the production preview/resolver without changing protected data.
	var definition: Dictionary = Data.event_def("lost_cartographer").duplicate(true)
	definition["choices"] = [{"id": "take", "label": "Scout fixture", "effects": [{"type": "scout", "amount": 1}], "result": "Scout fixture"}]
	Data.events()["evt02_scout_fixture"] = definition

func _typography_proof() -> void:
	var semantics: bool = OS.get_cmdline_user_args().has("--semantics-only")
	if DisplayServer.get_name() == "headless" and not semantics:
		push_error("Typography captures require the native renderer")
		quit(1)
		return
	Settings.set_storage_path("user://qa66_typography_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	root.size = PROOF_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = PROOF_SIZE
	root.content_scale_factor = 1.0
	viewport = SubViewport.new()
	viewport.size = PROOF_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TYPOGRAPHY_DIRECTORY))
	var measurements: Array[Dictionary]
	for scale_case: String in ["current", "1_35"]:
		for baseline: bool in [true, false]:
			var view := preload("res://scripts/event_view.gd").new()
			viewport.add_child(view)
			if baseline:
				# Reconstruct only the old warm-up context in memory. The checkout
				# and every production asset remain identical in both captures.
				var script := GDScript.new()
				script.source_code = view.hover_preview.get_script().source_code.replace("_preparation_viewport.size_2d_override = Vector2i(get_viewport_rect().size)", "_preparation_viewport.size_2d_override = Vector2i.ZERO")
				if script.reload() != OK:
					quit(1)
					return
				view.hover_preview.set_script(script)
				view.hover_preview.view = view
			if scale_case == "1_35":
				view.hover_preview.child_entered_tree.connect(func(child: Node) -> void:
					if not child is SubViewport: return
					for work: Dictionary in view.hover_preview._builds:
						for job: Dictionary in work.jobs: job.factor = Suite.UPCOMING_PREVIEW_CARD_SCALE)
			var state: Dictionary = Fixtures.fixture("whispering_well", true)
			view.present(state, false)
			view.finish_animation_for_test()
			for frame: int in range(Suite.FIXTURE_READY_FRAMES):
				if not view.hover_preview.preparation_snapshot().active: break
				await process_frame
			_expect(not view.hover_preview.preparation_snapshot().active, "Typography warm-up finishes")
			view.preview_choice(Suite._choice_index(view, "ember"))
			await create_timer(TYPOGRAPHY_HOVER_SETTLE_SECONDS).timeout
			var card: Control = view.hover_preview.current.find_child("CardWidget", true, false)
			var metrics: Dictionary = Suite._card_typography(card)
			var effective_scale: float = card.get_global_transform_with_canvas().get_scale().x
			var prefix: String = ("before" if baseline else "after") + "_" + scale_case
			measurements.append({"capture": prefix + ".png", "baseline_reconstructed": baseline, "fonts_local_px": metrics, "card_scale": effective_scale, "rules_screen_px": float(metrics.rules) * effective_scale, "viewport": str(card.get_viewport_rect().size), "ui_scale": preload("res://scripts/ui_typography.gd").ui_scale(card)})
			_expect(int(metrics.rules) == (17 if baseline else 16), "Typography measurement " + prefix + ": " + str(metrics))
			if not semantics:
				await RenderingServer.frame_post_draw
				var path: String = TYPOGRAPHY_DIRECTORY.path_join(prefix + ".png")
				var capture: Image = viewport.get_texture().get_image()
				_expect(capture.get_size() == PROOF_SIZE and capture.save_png(path) == OK, "Typography capture saves")
				print("Saved " + ProjectSettings.globalize_path(path))
			view.queue_free()
			await process_frame
	var file := FileAccess.open(TYPOGRAPHY_DIRECTORY.path_join("font_measurements.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(measurements, "\t"))
	print("QA66 TYPOGRAPHY: %d failures; %s" % [failures.size(), JSON.stringify(measurements)])
	viewport.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _check_fixtures() -> void:
	_add_debug_scout()
	for fixture: Array in Suite.CASES:
		var state: Dictionary = _fixture(fixture[0])
		var line: Dictionary = preload("res://scripts/event_reward_preview.gd").first_concrete(Events.preview_lines(state, fixture[0], fixture[1]))
		_expect(line.get("kind", "") == fixture[2], "Preview fixture: " + fixture[2])
	for fixture: Array in PROOF_BEATS:
		_expect(_outcome_index(Events.preview_choice(_fixture(fixture[0]), fixture[1]), fixture[2]) >= 0, "Mid-beat fixture: " + fixture[2])
	_finish("EVT02 proof fixtures")

func _fixture(id: String) -> Dictionary:
	var state: Dictionary = Fixtures.fixture(id, true)
	# Leave room for heals and make health changes legible. Debug-only values.
	state["player_hp"] = 24
	state["player_max_hp"] = 30
	if id == "lost_cartographer":
		var graph = preload("res://scripts/section_map_graph.gd")
		for coord: Vector2i in graph.descendants(state, state["current_room"], 4):
			var room: Dictionary = graph.room(state, coord)
			room["type"] = "mystery"
			room["visited"] = false
			room["scouted"] = false
			room["revealed"] = false
	return state

func _probe() -> void:
	_add_debug_scout()
	Store.set_storage_path("user://evt02_probe_profile.json")
	Store.set_run_storage_path("user://evt02_probe_run.save")
	Settings.set_storage_path("user://evt02_probe_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	root.size = PROOF_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = PROOF_SIZE
	root.content_scale_factor = 1.0
	viewport = SubViewport.new()
	viewport.size = PROOF_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	viewport.add_child(scene)
	for frame: int in range(Suite.FIXTURE_READY_FRAMES):
		if scene.call("initial_presentation_is_ready"): break
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROOF_DIRECTORY))
	for fixture: Array in Suite.CASES:
		var view: Control = await _present(_fixture(fixture[0]))
		var index: int = Suite._choice_index(view, fixture[1])
		view.choices[index].mouse_entered.emit()
		await create_timer(0.12).timeout
		await _capture("preview_%s_hover.png" % fixture[2])
		view.choices[index].mouse_exited.emit()
		view.choices[index].focus_entered.emit()
		await create_timer(0.12).timeout
		await _capture("preview_%s_focus.png" % fixture[2])
	var view: Control = await _present(_fixture("mirror_of_skins"))
	view.preview_choice(Suite._choice_index(view, "trade"))
	await create_timer(0.12).timeout
	await _capture("preview_transform_three.png")
	var disabled: Dictionary = _fixture("bloodletters_basin")
	disabled["player_hp"] = 1
	view = await _present(disabled)
	view.choices[0].grab_focus()
	await _capture("preview_disabled.png")
	view = await _present(_fixture("lost_cartographer"))
	view.preview_choice(0)
	await _capture("preview_plain.png")
	for fixture: Array in PROOF_BEATS:
		var before: Dictionary = _fixture(fixture[0])
		view = await _present(before)
		var outcomes: Array[Dictionary] = Events.preview_choice(before, fixture[1])
		var index: int = _outcome_index(outcomes, fixture[2])
		_expect(index >= 0, "Beat outcome exists: " + fixture[2])
		scene.call("_on_section_map_event", fixture[1])
		await create_timer(view.result_beats.start_times[index] + PROOF_MID_BEAT_SECONDS).timeout
		await _capture("beat_%s.png" % fixture[2])
		view.finish_result_beats()
	settings["reduced_motion"] = true
	Settings.apply_settings(settings, null, false)
	scene.call("_on_settings_changed", settings)
	view = await _present(_fixture("shrine_last_door"))
	view.preview_choice(Suite._choice_index(view, "candle"))
	await _capture("preview_reduced.png")
	scene.call("_on_section_map_event", "candle")
	await create_timer(PROOF_MID_BEAT_SECONDS).timeout
	await _capture("beat_reduced.png")
	view.finish_result_beats()
	await _capture("beat_skipped.png")
	view = await _present(Fixtures.combat_fixture())
	Feedback.combat_start(scene)
	await create_timer(PROOF_MID_BEAT_SECONDS).timeout
	await _capture("combat_omen_start.png")
	_finish("EVT02 event feedback probe")

func _present(state: Dictionary) -> Control:
	scene.call("_close_dialogue")
	scene.call("_load_run_state", state)
	for frame: int in range(PROOF_SETTLE_FRAMES): await process_frame
	var view: Control = scene.get("_event_view")
	if view != null and view.visible: view.finish_animation_for_test()
	return view

func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var capture: Image = viewport.get_texture().get_image()
	_expect(capture.get_size() == PROOF_SIZE and capture.save_png(PROOF_DIRECTORY.path_join(filename)) == OK, "Capture writes " + filename)

func _outcome_index(outcomes: Array, name: String) -> int:
	for index: int in range(outcomes.size()):
		var outcome: Dictionary = outcomes[index]
		if name in ["bane", "blessing"] and outcome["type"] == "omen" and Data.omen_def(outcome["id"])["kind"] == name: return index
		if name in ["max_hp_up", "max_hp_down"] and outcome["type"] == "max_hp" and (int(outcome["amount"]) > 0) == (name == "max_hp_up"): return index
		if outcome["type"] == name: return index
	return -1

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _finish(label: String) -> void:
	for failure: String in failures: push_error(failure)
	print("%s: %d failures" % [label, failures.size()])
	if viewport != null: print("EVT02 captures: " + ProjectSettings.globalize_path(PROOF_DIRECTORY))
	quit(0 if failures.is_empty() else 1)
