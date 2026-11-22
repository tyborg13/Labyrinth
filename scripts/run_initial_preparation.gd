extends RefCounted

# Loading owns this operation and all input until every original UI phase is
# ready. Static continuations can check cancellation after each rendered frame
# without resuming a freed RunScene. Normal direct scene loading remains sync.
const Assets = preload("res://scripts/asset_loader.gd")
const StateAssets = preload("res://scripts/encounter_asset_preparation.gd")
const InitialGraph = preload("res://scripts/initial_run_graph.gd")
const SectionArt = preload("res://scripts/run_section_art.gd")
const RoomAssets = preload("res://scripts/room_asset_preparation.gd")
const RigData = preload("res://scripts/protagonist_cutout/rig_data.gd")
const EmaciatedMan = preload("res://scripts/emaciated_man_cutout/renderer.gd")
const OpeningNpc = preload("res://scripts/emaciated_man_cutout/presentation.gd")
const SfxBank = preload("res://scripts/sfx_bank.gd")
static var _hitch_trace_enabled: bool = OS.get_environment("LABYRINTH_HITCH_TRACE") == "1"

static func owner_is_active(scene: Variant, still_active: Callable) -> bool:
	return is_instance_valid(scene) and not scene.is_queued_for_deletion() and bool(still_active.call())

static func _finish_boot(scene: Node, request: Dictionary, present: Callable, still_active: Callable) -> bool:
	if not owner_is_active(scene, still_active): return false
	if not request.is_empty():
		var installed: bool = await _finish_new_run(scene, request, present, still_active)
		if not owner_is_active(scene, still_active): return false
		if not installed: return false
	scene._defer_initial_run_presentation = false
	return scene.has_installed_run()

static func _finish_new_run(scene: Node, request: Dictionary, present: Callable, still_active: Callable) -> bool:
	var root := scene.get_tree().root
	while owner_is_active(scene, still_active):
		_update_requested_seed(root, request)
		var job: InitialGraph.Preparation = scene._initial_run_graph
		if job == null or not job.matches(request["seed"], request["depth"]):
			scene.cancel_initial_run_graph()
			job = InitialGraph.start_for(root, request["seed"], request["depth"], present)
			scene._initial_run_graph = job
		while job.pending and job.matches(request["seed"], request["depth"]):
			await present.call()
			if not owner_is_active(scene, still_active): return false
			_update_requested_seed(root, request)
		await Assets.wait_for_preparation_slice(present, owner_is_active.bind(scene, still_active), &"commit_new_run", Assets.PREPARATION_SLICE_USEC)
		if not owner_is_active(scene, still_active): return false
		_update_requested_seed(root, request)
		if job.cancellation.is_cancelled(): return false
		if not job.matches(request["seed"], request["depth"]): continue
		scene._initial_run_graph = null
		if job.graph.is_empty(): return false
		var work_started: int = Time.get_ticks_usec()
		var _hitch_span: RefCounted
		if _hitch_trace_enabled: _hitch_span = _phase("commit_new_run")
		var installed: bool = scene._commit_new_run(request, job.graph)
		_hitch_span = null
		Assets.count_preparation_work(work_started, &"commit_new_run")
		return installed
	return false

static func _update_requested_seed(root: Window, request: Dictionary) -> void:
	request["seed"] = InitialGraph.resolve_seed(root, request["automatic_seed"])

static func prepare_ui_for(scene: Node, present_frame: Callable, still_active: Callable, fight_textures: Dictionary = {}, loaded_factory: Dictionary = {}) -> void:
	var jobs: Array[Callable] = scene._initial_ui_jobs()
	if not await _run_jobs(scene, jobs, present_frame, still_active): return
	if not owner_is_active(scene, still_active): return
	var combat: Dictionary = scene._combat_state
	var pre_battle: bool = str(scene._run_state.get("mode", "")) == "pre_battle"
	if pre_battle:
		var generation: int = scene._encounter_preparation_generation
		var alive: Callable = func() -> bool:
			return StateAssets.active(scene, generation) and owner_is_active(scene, still_active)
		# The checkpoint's pre-boot build already named the maquette families.
		# Reuse it under the ordinary exact-input guard; otherwise build as before.
		var factory: Dictionary = loaded_factory
		if not scene._run_engine.prepared_pre_battle_matches_input(factory, scene._run_state):
			factory = await StateAssets.prepare_combat_factory_for(scene, scene._run_state, present_frame, alive)
		if not owner_is_active(scene, still_active): return
		scene._prepared_pre_battle_factory = factory
		var preview: Dictionary = scene._run_engine.pre_battle_preview_state(scene._run_state, factory)
		combat = preview.get("combat_state", {})
	var combat_textures = StateAssets.CombatTextures
	var prepare_combat_textures: bool = combat_textures.enabled(scene, scene._run_state, combat)
	var state_textures: Dictionary = StateAssets.state_texture_manifest(scene, scene._run_state, combat)
	# Room travel's preview manifest: the foes' ink pools draw from this cache.
	if str(scene._run_state.get("mode", "")) == "pre_battle" and not combat.is_empty():
		state_textures.merge(preload("res://scripts/pre_battle_view.gd").texture_manifest(combat))
	await StateAssets.prepare_rig_textures_for(scene, combat, state_textures, present_frame, still_active, fight_textures if prepare_combat_textures else null)
	if not owner_is_active(scene, still_active): return
	if prepare_combat_textures:
		await combat_textures.prepare_for(scene, scene._run_state, combat, present_frame, owner_is_active.bind(scene, still_active), fight_textures)
		if not owner_is_active(scene, still_active): return
	await RoomAssets.prepare_room_textures_for(scene, scene._run_state, present_frame, still_active)
	if not owner_is_active(scene, still_active): return
	await StateAssets.prepare_hidden_shop_for(scene, scene._run_state, present_frame, still_active)
	if not owner_is_active(scene, still_active): return
	await _prepare_opening_room_textures(scene, present_frame, still_active)
	if not owner_is_active(scene, still_active): return
	await SectionArt.prepare_for(scene.get_tree().root, scene._run_state, present_frame, still_active)
	if not owner_is_active(scene, still_active): return
	if str(scene._run_state.get("mode", "")) == "defeat":
		await preload("res://scripts/run_end_preparation.gd").prepare_defeat_portrait_for(scene, scene._run_state, present_frame, still_active)
		if not owner_is_active(scene, still_active): return
	scene._begin_ui_refresh(true)
	var refresh: Array[Callable]
	if str(scene._run_state.get("mode", "")) == "reward" and not scene._run_engine.is_dragon_reward(scene._run_state):
		for method: String in ["_refresh_ui_header", "_refresh_ui_navigation"]:
			refresh.append(Callable(scene, method))
		await _run_jobs(scene, refresh, present_frame, still_active)
		if not owner_is_active(scene, still_active): return
		# Only loading can defer card-choice construction. The same ordinary builders
		# run one card at a time while the menu still owns input and reveal readiness.
		# Gameplay refreshes build their complete choice stack synchronously.
		await prepare_reward_choices_for(scene, present_frame, still_active)
		if not owner_is_active(scene, still_active): return
		refresh.clear()
		for method: String in ["_refresh_ui_stage", "_refresh_ui_hand", "_refresh_ui_finish"]:
			refresh.append(Callable(scene, method))
	else:
		for method: String in ["_refresh_ui_header", "_refresh_ui_navigation", "_refresh_ui_choices", "_refresh_ui_stage", "_refresh_ui_hand", "_refresh_ui_finish"]:
			refresh.append(Callable(scene, method))
	await _run_jobs(scene, refresh, present_frame, still_active)
	if not owner_is_active(scene, still_active): return

	scene._end_ui_refresh(true)
	if pre_battle:
		var opening_active: Callable = StateAssets.hand_active.bind(scene, scene._encounter_preparation_generation, scene._opening_hand_pool_preparation_revision)
		StateAssets.prepare_opening_objective_for.call_deferred(scene, combat, present_frame, opening_active)
	# The ordinary refresh commits the final progression display inputs. Future
	# Character dialogs must use that ready-state snapshot, not the earlier
	# state which would force a full rebuild on the first public open.
	await preload("res://scripts/character_inventory_rows.gd").prepare_current_for(scene, scene._character_row_preparation_revision, present_frame, still_active)
	if not owner_is_active(scene, still_active): return
	await preload("res://scripts/grimoire_search_rows.gd").prepare_current_for(scene, scene._grimoire_row_preparation_revision, present_frame, still_active)
	if not owner_is_active(scene, still_active): return
	scene._queue_loaded_run_continuation()
	scene.call_deferred("_refresh_hand_panel_after_viewport_change")
	scene.call_deferred("_refresh_controller_interface")
	scene._initial_ui_complete = true
	# Live rigs now strongly own their immutable source; leave the weak cache.
	scene._initial_cpu_asset_holds.clear()

static func _prepare_opening_room_textures(scene: Node, present: Callable, still_active: Callable) -> void:
	var state: Dictionary = scene._run_state
	if str(state.get("mode", "")) != "room": return
	var root: Node = scene.get_tree().root
	var room: Dictionary = scene._run_engine.room_metadata(state, state.get("current_room", Vector2i.ZERO))
	var textures: Dictionary = {}
	var prepare_opening_npc: bool = false
	for npc: Dictionary in room.get("npcs", []):
		if str(npc.get("id", "")) != "emaciated_man": continue
		prepare_opening_npc = true
		var layout: String = EmaciatedMan.Rig.EMACIATED_BASE.path_join("front.json")
		var value: Variant = await Assets.prepare_cpu_value_for(root, RigData.prepare_owned_source.bind(layout), present, still_active)
		if not owner_is_active(scene, still_active): return
		var source: RefCounted = RigData.publish_owned_source(layout, value)
		if source != null:
			scene._initial_cpu_asset_holds.append(source)
			textures.merge(RigData.source_texture_manifest(source, layout))
		textures[EmaciatedMan.REST_PATH] = true
		break
	await Assets.prepare_textures_for(root, textures, present, still_active)
	if prepare_opening_npc and owner_is_active(scene, still_active):
		var trace_npc: Callable = _opening_npc_phase if _hitch_trace_enabled else Callable()
		await OpeningNpc.prepare_opening_for(scene.board_view, present, owner_is_active.bind(scene, still_active), trace_npc)

static func _opening_npc_phase(step: String) -> RefCounted:
	return _phase("opening_npc:" + step)

static func prepare_reward_choices_for(scene: Node, present_frame: Callable, still_active: Callable) -> void:
	if not owner_is_active(scene, still_active) or not scene.is_inside_tree(): return
	var reward_jobs: Array[Callable]
	scene._refresh_ui_choices(reward_jobs)
	await present_frame.call()
	if not owner_is_active(scene, still_active): return
	await _run_jobs(scene, reward_jobs, present_frame, still_active)
	if not owner_is_active(scene, still_active): return
	# The chrome's first layout preceded the cards. Refit the final native body
	# through the same immediate/deferred layout used by synchronous refreshes.
	scene._layout_relic_choice_overlay()
	scene.call_deferred("_layout_relic_choice_overlay")

static func _run_jobs(scene: Node, jobs: Array[Callable], present_frame: Callable, still_active: Callable) -> bool:
	var alive: Callable = owner_is_active.bind(scene, still_active)
	for job: Callable in jobs:
		var step: StringName = job.get_method()
		# First board submission can exceed a preparation interval even when
		# its resources are warm. Reserve a fresh presented frame for it.
		var estimate: int = Assets.PREPARATION_SLICE_USEC if step in [&"_refresh_ui_stage", &"_apply_style"] else Assets.DEFAULT_STEP_ESTIMATE_USEC
		await Assets.wait_for_preparation_slice(present_frame, alive, step, estimate)
		if not bool(alive.call()) or not scene.is_inside_tree(): return false
		if job == scene._ensure_sfx_bank:
			if scene._sfx_bank == null:
				var bank: Node = scene._make_sfx_bank()
				await SfxBank.warm_up_for(bank, scene, present_frame, still_active)
				if not owner_is_active(scene, still_active): return false
				scene._bind_sfx_bank(bank)
			continue
		var started: int = Time.get_ticks_usec()
		var _hitch_span: RefCounted
		if _hitch_trace_enabled: _hitch_span = _phase(str(job.get_method()))
		var result: Variant = job.call()
		_hitch_span = null
		scene._record_runtime_performance_phase("startup_" + str(job.get_method()), started)
		Assets.count_preparation_work(started, step)
		if job == scene._prepare_initial_run_state:
			if not await _finish_boot(scene, result, present_frame, still_active): return false
	await Assets.wait_for_preparation_slice(present_frame, alive, &"", 0)
	return bool(alive.call())

static func prepare_cpu_assets_for(scene: Node, root: Node, present_frame: Callable, still_active: Callable) -> void:
	await preload("res://scripts/run_initial_cpu_assets.gd").prepare_cpu_assets_for(scene, root, present_frame, still_active)

static func _phase(stage: String) -> RefCounted:
	return (Engine.get_main_loop() as SceneTree).root.get_node("PerformanceTelemetry").hitch_phase("startup:run_initial_preparation:" + stage)
