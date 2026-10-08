extends RefCounted

# Loading owns this operation and all input until every original UI phase is
# ready. Static continuations can check cancellation after each rendered frame
# without resuming a freed RunScene. Normal direct scene loading remains sync.
const Assets = preload("res://scripts/asset_loader.gd")
const RigData = preload("res://scripts/protagonist_cutout/rig_data.gd")
const ComponentSurface = preload("res://scripts/ui_component_surface.gd")
const StateAssets = preload("res://scripts/encounter_asset_preparation.gd")
const SurfaceFinish = preload("res://scripts/ui_surface_finish.gd")
const MapSkin = preload("res://scripts/section_map_skin.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const RunSfx = preload("res://scripts/run_sfx_library.gd")
const SLICE_USEC: int = 4000

static func owner_is_active(scene: Variant, still_active: Callable) -> bool:
	return is_instance_valid(scene) and not scene.is_queued_for_deletion() and bool(still_active.call())

static func prepare_ui_for(scene: Node, present_frame: Callable, still_active: Callable) -> void:
	var jobs: Array[Callable] = scene._initial_ui_jobs()
	await _run_jobs(scene, jobs, present_frame, still_active)
	if not owner_is_active(scene, still_active): return
	await Assets.prepare_textures_for(scene.get_tree().root, StateAssets.state_texture_manifest(scene, scene._run_state), present_frame, still_active)
	if not owner_is_active(scene, still_active): return
	await StateAssets.prepare_hidden_shop_for(scene, scene._run_state, present_frame, still_active)
	if not owner_is_active(scene, still_active): return
	# Boss order varies by run. Warm only the actual displayed section after
	# committing its state, rather than a fixed first-section background.
	if Graph.enabled(scene._run_state):
		var section: Dictionary = Graph.section(scene._run_state, Graph.active_section(scene._run_state))
		var path: String = "res://assets/art/backgrounds/sections/%s.png" % str(section.get("boss_id", "tharokh"))
		await Assets.prepare_textures_for(scene.get_tree().root, {path: false}, present_frame, still_active)
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

static func _run_jobs(scene: Node, jobs: Array[Callable], present_frame: Callable, still_active: Callable) -> void:
	var slice_started: int = Time.get_ticks_usec()
	for job: Callable in jobs:
		if not owner_is_active(scene, still_active) or not scene.is_inside_tree(): return
		var started: int = Time.get_ticks_usec() if scene._runtime_performance_instrumentation_enabled else 0
		job.call()
		scene._record_runtime_performance_phase("startup_" + str(job.get_method()), started)
		if Time.get_ticks_usec() - slice_started >= SLICE_USEC:
			await present_frame.call()
			if not owner_is_active(scene, still_active): return
			slice_started = Time.get_ticks_usec()

static func prepare_cpu_assets_for(scene: Node, root: Node, present_frame: Callable, still_active: Callable) -> void:
	var texture_manifest: Dictionary = {}
	for path: String in ["res://assets/units/protagonist_cutout/front.json", "res://assets/units/protagonist_cutout/rear.json", "res://assets/units/scavenger_cutout/front.json"]:
		var prepared: RefCounted = (await Assets.prepare_cpu_value_for(root, RigData.prepare_owned_source.bind(path), present_frame, still_active)) as RefCounted
		if not owner_is_active(scene, still_active): return
		var published: RefCounted = RigData.publish_owned_source(path, prepared)
		if published != null:
			scene._initial_cpu_asset_holds.append(published)
			texture_manifest.merge(RigData.source_texture_manifest(published, path))
	await Assets.prepare_textures_for(root, texture_manifest, present_frame, still_active)
	if not owner_is_active(scene, still_active): return
	await ComponentSurface.prepare_initial_assets_for(root, present_frame, still_active)
	if not owner_is_active(scene, still_active): return
	await SurfaceFinish.prepare_initial_assets_for(root, present_frame, still_active)
	if not owner_is_active(scene, still_active): return
	await MapSkin.prepare_initial_assets_for(root, present_frame, still_active)
	if not owner_is_active(scene, still_active): return
	var paths := PackedStringArray()
	for mode: String in ["room", "campfire"]:
		var ambient: Dictionary = RunSfx.ambient_entry_for_mode(mode)
		var path: String = str(ambient.get("path", ""))
		if not path.is_empty() and not paths.has(path): paths.append(path)
	await Assets.prepare_audio_for(root, paths, present_frame, still_active, true)
