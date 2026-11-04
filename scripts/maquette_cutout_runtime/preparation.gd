extends RefCounted

const Presentation = preload("presentation.gd")
const Construction = preload("construction.gd")
const Dependencies = preload("dependencies.gd")
const Retention = preload("retention.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const RigData = preload("res://scripts/protagonist_cutout/rig_data.gd")

static func active(scene: Variant, generation: int) -> bool:
	return is_instance_valid(scene) and scene.is_inside_tree() and not scene.is_queued_for_deletion() and scene._encounter_preparation_generation == generation

static func request(scene: Node, state: Dictionary, generation: int) -> void:
	var window: Node = Retention.for_scene(scene)
	window.current(scene._run_state, Dependencies.families_for(Dependencies.types_for(scene._combat_state)))
	window.request(state, generation)

static func prepare_encounter_for(scene: Node, state: Dictionary, generation: int) -> void:
	if not active(scene, generation): return
	var window: Node = Retention.for_scene(scene)
	var types: PackedStringArray = Dependencies.types_for(state)
	window.next_families = Dependencies.families_for(types)
	window.retain()
	await prepare_types_for(scene.get_tree().root, types, present_frame.bind(scene.get_tree()), active.bind(scene, generation))
	if active(scene, generation): window.complete = true

## Called before committing the destination to the visible board. A slow
## worker extends the existing covered travel, never the first visible build.
static func finish_for(scene: Node, state: Dictionary, generation: int) -> bool:
	# A load can invalidate travel during the door/map await, before entry here.
	# Reject it before even requesting or committing a preparation window.
	if not active(scene, generation): return false
	var window: Node = Retention.for_scene(scene)
	if window.generation != generation:
		request(scene, state, generation)
		load("res://scripts/encounter_asset_preparation.gd").begin_for.call_deferred(scene, state, generation)
	while active(scene, generation) and not window.complete:
		await present_frame(scene.get_tree())
	if not active(scene, generation): return false
	window.commit()
	return true

# Capture only across this unit's added preparation wait. The existing UI
# bootstrap intentionally advances the generation when it loads the run.
static func prepare_initial_ui_for(scene: Node, present: Callable, still_active: Callable) -> void:
	var generation: int = scene._encounter_preparation_generation
	var alive: Callable = loading_active.bind(scene, generation, still_active)
	await prepare_loaded_for(scene, present, alive)
	if not bool(alive.call()): return
	await load("res://scripts/run_initial_preparation.gd").prepare_ui_for(scene, present, still_active)

static func loading_active(scene: Variant, generation: int, still_active: Callable) -> bool:
	return active(scene, generation) and bool(still_active.call())

## Continue already owns the loading cover here. New Run has no room to
## prepare, and must not pay for any maquette family before the first travel.
static func prepare_loaded_for(scene: Node, present: Callable, alive: Callable) -> void:
	if not bool(scene.get_tree().root.get_meta("labyrinth_resume_saved_run", false)): return
	var state: Dictionary = preload("res://scripts/progression_store.gd").load_saved_run()
	state = scene._run_engine.repair_loaded_run_state(scene._run_engine.migrate_renamed_content_ids(state))
	var battle: Dictionary = state.get("combat_state", {})
	if str(state.get("mode", "")) == "pre_battle":
		var factory: Dictionary = scene._run_engine.begin_pre_battle_combat_preparation(state)
		while not factory.is_empty() and bool(alive.call()):
			if scene._run_engine.advance_pre_battle_combat_preparation(factory): break
			await present.call()
		if not bool(alive.call()): return
		battle = (scene._run_engine.pre_battle_preview_state(state, factory) as Dictionary).get("combat_state", {})
	var types: PackedStringArray = Dependencies.types_for(battle)
	var window: Node = Retention.for_scene(scene)
	window.current(state, Dependencies.families_for(types))
	await prepare_types_for(scene.get_tree().root, types, present, alive)

static func prepare_types_for(root: Node, types: PackedStringArray, present_frame: Callable, still_active: Callable) -> void:
	for type: String in types:
		if not bool(still_active.call()): return
		var renderer: Node = Presentation.renderer_script(type).new()
		renderer.motion_data()
		var paths := PackedStringArray()
		for view: String in renderer._rig_views():
			var rig: Node2D = renderer._new_rig()
			paths.append(rig._layout_path(view))
			rig.free()
		renderer.free()
		var textures: Dictionary = {}
		for path: String in paths:
			if not bool(still_active.call()): return
			var source: Construction.Source = Construction.cached(path)
			if source == null:
				var value: Variant = await Assets.prepare_cpu_value_for(root, Construction.prepare_owned_source.bind(path), present_frame, still_active)
				if not bool(still_active.call()): return
				source = Construction.publish(path, value as Construction.Source)
			if source == null: continue
			textures.merge(RigData.source_texture_manifest(source.data, path))
		await Assets.prepare_textures_for(root, textures, present_frame, still_active)
		if not bool(still_active.call()): return
		await present_frame.call()

static func present_frame(tree: SceneTree) -> void:
	if DisplayServer.get_name() == "headless": await tree.process_frame
	else: await RenderingServer.frame_post_draw
