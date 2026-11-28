extends SceneTree
## Repeat each settled scenario in the same engine process and profile.

const Fixture = preload("res://tools/qa149/fixtures.gd")
const Store = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const RUN_SCENE := "res://scenes/run_scene.tscn"
const CYCLE_COUNT := 5
const SETTLE_FRAMES := 60
const SETTLE_MSEC := 150
const BOUNDARY_TIMEOUT_MSEC := 75000
const TIME_SCALE := 4.0
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const MIB := 1048576.0

var _route: String
var _object_counts: Array[int]
var _orphan_counts: Array[int]

func _initialize() -> void:
	_route = OS.get_environment("QA149_ROUTE")
	if _route not in ["A", "B", "C"] or DisplayServer.get_name() != "headless":
		_fail("set QA149_ROUTE to A, B or C and use the headless driver")
		return
	Runtime.apply_from_environment()
	Store.set_storage_path("user://qa149/progression.json")
	Store.set_run_storage_path("user://qa149/run.save")
	preload("res://scripts/analytics_store.gd").set_storage_dir("user://qa149/analytics")
	preload("res://scripts/recent_event_store.gd").set_storage_path("user://qa149/recent_events.json")
	var settings = preload("res://scripts/settings_store.gd")
	settings.set_storage_path("user://qa149/settings.json")
	settings.save_settings(settings.default_settings())
	Store.save_data(Tutorial.complete_tutorial(Store.load_data()))
	root.size = VIEWPORT_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = VIEWPORT_SIZE
	root.set_meta("labyrinth_performance_probe_seed", Fixture.DEMO_SEED if _route == "B" else Fixture.CARD_SEED)
	Engine.time_scale = TIME_SCALE
	# qa144's headless post-draw pump preserves the first VICTORY-frame cut.
	process_frame.connect(_headless_draw)
	_run.call_deferred()

func _headless_draw() -> void:
	RenderingServer.frame_post_draw.emit()

func _run() -> void:
	if change_scene_to_file(RUN_SCENE) != OK or not await _wait_for(_run_ready, "initial run"):
		_fail("could not open the initial run")
		return
	for cycle: int in range(1, CYCLE_COUNT + 1):
		if _route == "B":
			if not await _demo_cycle(cycle): return
		else:
			if not await _card_cycle(cycle): return
		if not await _wait_for(func() -> bool: return not root.has_node("DepartedRunCleanup"), "departed-run drain"): return
		await _settle()
		_sample(cycle)
		if cycle < CYCLE_COUNT and _route != "B":
			# Set up a fresh scene for the same card fixture on both routes.
			if change_scene_to_file(RUN_SCENE) != OK or not await _wait_for(_run_ready, "next card fixture"):
				_fail("could not open the next card fixture")
				return
	var objects := _median_delta(_object_counts)
	var orphans := _median_delta(_orphan_counts)
	print("QA149 GROWTH %s per_cycle_objects=%s per_cycle_orphans=%s %s" % [
		_route, objects, orphans, "GROWS" if objects > 0.0 else "FLAT"])
	# Match qa144's close on the completed screen, then give deferred frees time.
	current_scene.queue_free()
	await _settle()
	quit()

func _card_cycle(cycle: int) -> bool:
	var original_id := current_scene.get_instance_id()
	Fixture.install_card_fight(current_scene)
	if not await _wait_for(_combat_ready, "card fixture ready"): return false
	current_scene._on_card_pressed(0)
	current_scene._on_board_tile_clicked(Fixture.HERO)
	if current_scene._selected_card_index >= 0 and not current_scene._animation_lock:
		current_scene._on_confirm_card_play_pressed()
	if not await _wait_for(func() -> bool: return current_scene._post_combat_victory_overlay.visible, "first VICTORY frame"): return false
	var offer: Dictionary = _reward_offer(current_scene._committed_run_state())
	if _route == "A":
		current_scene._on_save_and_quit_pressed()
		if not await _wait_for(_continue_ready, "title Continue"): return false
		if _reward_offer(Store.load_saved_run()) != offer: return _fail("departure changed the saved offer")
		current_scene.continue_button.pressed.emit()
	if not await _wait_for(_card_reward_ready, "card reward ready"): return false
	var resumed := current_scene.get_instance_id() != original_id
	if resumed != (_route == "A") or (resumed and is_instance_id_valid(original_id)):
		return _fail("unexpected scene ownership at the reward")
	if offer.is_empty() or _reward_offer(current_scene._run_state) != offer:
		return _fail("the visible card reward changed")
	print("QA149 BOUNDARY %s cycle=%d reward=%s resumed=%s" % [_route, cycle, JSON.stringify(offer), resumed])
	return true

func _demo_cycle(cycle: int) -> bool:
	var owner := current_scene
	var previous_index: int = owner._run_state["run_index"]
	if owner._run_state.get("build_kind") != "demo": return _fail("expected a demo run")
	Fixture.install_demo_reward(owner)
	if not await _wait_for(func() -> bool: return _button_ready(owner, "DragonRewardContinue") and not owner._animation_lock, "Complete Ascent"): return false
	owner.find_child("DragonRewardContinue", true, false).pressed.emit()
	if not await _wait_for(func() -> bool: return _recap_ready(owner), "demo victory recap"): return false
	owner._run_end_recap.find_child("NewRunButton", true, false).pressed.emit()
	if not await _wait_for(func() -> bool: return _first_room_ready(owner, previous_index), "new run's first room"): return false
	print("QA149 BOUNDARY B cycle=%d outcome=victory next_run=%d same_scene=true" % [cycle, owner._run_state["run_index"]])
	return true

func _run_ready() -> bool:
	return is_instance_valid(current_scene) and current_scene.has_method("initial_presentation_is_ready") and current_scene.initial_presentation_is_ready()

func _combat_ready() -> bool:
	return _run_ready() and not current_scene._animation_lock and not current_scene._dialogue_active and current_scene._hand_layout_pending_revision < 0

func _continue_ready() -> bool:
	return (is_instance_valid(current_scene) and current_scene.has_method("_on_continue_button_pressed")
		and not current_scene.continue_button.disabled and not root.gui_disable_input)

func _card_reward_ready() -> bool:
	return (_run_ready() and current_scene._run_state.get("mode") == "reward" and not current_scene._animation_lock
		and not current_scene._reward_intro_pending() and current_scene._relic_choice_overlay.is_visible_in_tree())

func _recap_ready(owner: Node) -> bool:
	return (owner._run_state.get("mode") == "victory" and not owner._relic_claim_in_progress
		and owner._run_end_recap.is_visible_in_tree() and not owner._run_end_recap.is_processing()
		and owner._run_end_recap.find_child("DemoEndPanel", true, false) != null
		and _button_ready(owner._run_end_recap, "NewRunButton"))

func _first_room_ready(owner: Node, previous_index: int) -> bool:
	return (current_scene == owner and _run_ready() and int(owner._run_state["run_index"]) > previous_index
		and owner._run_state.get("mode") == "room" and not owner._animation_lock
		and owner._run_engine.room_metadata(owner._run_state, owner._run_state["current_room"]).get("type") == "start"
		and not owner._run_end_recap.visible)

static func _button_ready(parent: Node, name: String) -> bool:
	var button := parent.find_child(name, true, false) as BaseButton
	return button != null and button.is_visible_in_tree() and not button.disabled

static func _reward_offer(state: Dictionary) -> Dictionary:
	var reward: Dictionary = (state.get("pending_reward", {}) as Dictionary).duplicate(false)
	reward.erase("board_state")
	reward.erase("intro_pending")
	return reward

func _wait_for(predicate: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + BOUNDARY_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await RenderingServer.frame_post_draw
	return _fail("timed out waiting for " + label)

func _settle() -> void:
	var deadline := Time.get_ticks_msec() + SETTLE_MSEC
	for frame: int in range(SETTLE_FRAMES): await process_frame
	while Time.get_ticks_msec() < deadline: await process_frame

func _sample(cycle: int) -> void:
	var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var resources := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var static_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / MIB
	_object_counts.append(objects)
	_orphan_counts.append(orphans)
	print("QA149 GROWTH %s cycle=%d objects=%d resources=%d nodes=%d orphans=%d static_mb=%.3f" % [
		_route, cycle, objects, resources, nodes, orphans, static_mb])

static func _median_delta(counts: Array[int]) -> float:
	var deltas: Array[int]
	for index: int in range(1, counts.size()):
		deltas.append(counts[index] - counts[index - 1])
	deltas.sort()
	var middle := deltas.size() >> 1
	return (deltas[middle - 1] + deltas[middle]) / 2.0

func _fail(reason: String) -> bool:
	push_error("QA149 %s: %s" % [_route, reason])
	quit(1)
	return false
