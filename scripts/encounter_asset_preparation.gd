extends RefCounted

const Glyphs = preload("res://scripts/ui_glyph_preparation.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const GameData = preload("res://scripts/game_data.gd")
const RigData = preload("res://scripts/protagonist_cutout/rig_data.gd")

# Travel already owns the action's committed destination. Preparation never
# gates input or changes its authored timing; a cold direct-entry path retains
# the existing synchronous fallback. CPU workers own source JSON/mesh arrays.
static func active(scene: Variant, generation: int) -> bool:
	return is_instance_valid(scene) and scene.is_inside_tree() and not scene.is_queued_for_deletion() and scene._encounter_preparation_generation == generation

static func begin_for(scene: Node, state: Dictionary, generation: int) -> void:
	if not active(scene, generation): return
	var combat_state: Dictionary = state.get("combat_state", {})
	if str(state.get("mode", "")) == "pre_battle":
		# RunEngine and its shared definitions remain main-thread-owned.
		var factory: Dictionary = await prepare_combat_factory_for(scene, state, generation)
		if not active(scene, generation) or factory.is_empty(): return
		scene._prepared_pre_battle_factory = factory
		var preview: Dictionary = scene._run_engine.pre_battle_preview_state(state, scene._prepared_pre_battle_factory)
		combat_state = preview.get("combat_state", {})
	var manifest: Dictionary = scene.board_view.unit_rig_preparation_manifest(combat_state)
	var sources: PackedStringArray = manifest["sources"]
	var textures: Dictionary = manifest["textures"]
	textures.merge(state_texture_manifest(scene, state, combat_state))
	if sources.is_empty():
		await Assets.prepare_textures_for(scene.get_tree().root, textures, present_frame.bind(scene.get_tree()), active.bind(scene, generation))
		if active(scene, generation): await prepare_hidden_shop_for(scene, state, present_frame.bind(scene.get_tree()), active.bind(scene, generation))
		return
	var result: Variant = await Assets.prepare_cpu_value_for(scene.get_tree().root, _prepare_sources.bind(sources), present_frame.bind(scene.get_tree()), active.bind(scene, generation))
	if not active(scene, generation) or not result is Array: return
	for entry: Dictionary in result:
		var path: String = entry["path"]
		var published: RefCounted = RigData.publish_owned_source(path, entry["data"])
		if published != null:
			scene._encounter_cpu_asset_holds.append(published)
			textures.merge(RigData.source_texture_manifest(published, path))
	await Assets.prepare_textures_for(scene.get_tree().root, textures, present_frame.bind(scene.get_tree()), active.bind(scene, generation))
	if not active(scene, generation): return
	if str(state.get("mode", "")) == "pre_battle":
		scene._schedule_opening_hand_pool_preparation(combat_state)
		var preview: Dictionary = scene._run_engine.pre_battle_preview_state(state, scene._prepared_pre_battle_factory)
		await prepare_hidden_pre_battle_for(scene, state, preview, generation, present_frame.bind(scene.get_tree()), active.bind(scene, generation))
		if opening_active(scene, generation):
			var started: int = Time.get_ticks_usec() if scene._runtime_performance_instrumentation_enabled else 0
			await Glyphs.prepare_jobs_for(scene, scene._combat_objective_hud.opening_glyph_preparation_jobs(opening_objective_hud_state(scene, combat_state)), present_frame.bind(scene.get_tree()), opening_active.bind(scene, generation))
			if opening_active(scene, generation): scene._record_runtime_performance_phase("opening_objective_glyph_preparation", started)

# Keep this factory local across yields. Only the completed owned result can
# reach the existing full-input preview guard; a canceled or invalid catalog
# drops the cursor without publishing its partial RNG/combat state.
static func prepare_combat_factory_for(scene: Node, state: Dictionary, generation: int) -> Dictionary:
	if not active(scene, generation): return {}
	var tree: SceneTree = scene.get_tree()
	var started: int = Time.get_ticks_usec() if scene._runtime_performance_instrumentation_enabled else 0
	var factory: Dictionary = scene._run_engine.begin_pre_battle_combat_preparation(state)
	scene._record_runtime_performance_phase("travel_combat_factory_preparation", started)
	if factory.is_empty(): return {}
	await present_frame(tree)
	while active(scene, generation):
		started = Time.get_ticks_usec() if scene._runtime_performance_instrumentation_enabled else 0
		var complete: bool = scene._run_engine.advance_pre_battle_combat_preparation(factory)
		scene._record_runtime_performance_phase("travel_combat_factory_preparation", started)
		if complete: return factory
		await present_frame(tree)
	return {}

static func opening_active(scene: Variant, generation: int) -> bool:
	return active(scene, generation) and str(scene._run_state.get("mode", "")) != "combat"

# The opening animation displays the committed snapshot under its input lock.
# Match its Umbra-safe HUD copy while leaving all authoritative data untouched.
static func opening_objective_hud_state(scene: Node, combat_state: Dictionary) -> Dictionary:
	if not combat_state.has("umbra") or scene._combat_engine.effective_umbra_radius(combat_state) >= preload("res://scripts/combat_engine.gd").UMBRA_UNLIMITED_RADIUS:
		return combat_state
	var hud_state: Dictionary = combat_state.duplicate(false)
	hud_state["visible_enemy_ids"] = scene._combat_engine.visible_enemy_ids(combat_state)
	return hud_state

static func hand_active(scene: Variant, generation: int, revision: int) -> bool:
	return active(scene, generation) and scene._opening_hand_pool_preparation_revision == revision and str(scene._run_state.get("mode", "room")) != "combat"

static func prepare_opening_hand_for(scene: Node, combat_state: Dictionary, generation: int, revision: int) -> void:
	if not hand_active(scene, generation, revision): return
	var tree: SceneTree = scene.get_tree()
	var renderer_jobs: Array[Dictionary] = scene.board_view.begin_unit_renderer_preparation(combat_state)
	var hand: Array = (combat_state.get("deck", {}) as Dictionary).get("hand", [])
	var card_size: Vector2 = scene._hand_card_size(hand.size(), false)
	var copies: Dictionary = {}
	for card_id: String in hand:
		if not hand_active(scene, generation, revision): return
		var started: int = Time.get_ticks_usec() if scene._runtime_performance_instrumentation_enabled else 0
		var copy_index: int = int(copies.get(card_id, 0))
		scene._prepare_opening_hand_pool_entry(card_id, card_size, combat_state, copy_index)
		copies[card_id] = copy_index + 1
		scene._record_runtime_performance_phase("opening_hand_pool_preparation", started)
		await present_frame(tree)
	for job: Dictionary in renderer_jobs:
		if not hand_active(scene, generation, revision): return
		var started: int = Time.get_ticks_usec() if scene._runtime_performance_instrumentation_enabled else 0
		scene.board_view.prepare_unit_renderer(job, scene._reduced_motion_enabled())
		scene._record_runtime_performance_phase("opening_unit_renderer_preparation", started)
		await present_frame(tree)

static func _prepare_sources(paths: PackedStringArray) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for path: String in paths:
		result.append({"path": path, "data": RigData.prepare_owned_source(path)})
	return result

static func present_frame(tree: SceneTree) -> void:
	if DisplayServer.get_name() == "headless": await tree.process_frame
	else: await RenderingServer.frame_post_draw

static func state_texture_manifest(scene: Node, state: Dictionary, combat_state: Dictionary = {}) -> Dictionary:
	var textures: Dictionary = {}
	for field: String in ["deck_cards", "magic_inventory", "item_inventory"]:
		for card: String in state.get(field, []):
			_add_card_textures(textures, card)
	for equipment: String in (state.get("equipped_equipment", {}) as Dictionary).values():
		_add_equipment_textures(textures, equipment, state)
	for equipment: String in state.get("equipment_inventory", []):
		_add_equipment_textures(textures, equipment, state)
	for enemy: Dictionary in combat_state.get("enemies", []):
		_add_path(textures, str(GameData.enemy_def(str(enemy.get("type", ""))).get("art_path", "")))
	var room: Dictionary = scene._run_engine.room_metadata(state, state.get("current_room", Vector2i.ZERO))
	if str(room.get("type", "")) == "scavenger":
		for id: String in scene._run_engine.merchant_offer_ids(state, "scavenger"):
			if scene._run_engine.merchant_item_kind(id) == "gear": _add_equipment_textures(textures, id, state)
			else: _add_card_textures(textures, id)
	return textures

static func _add_card_textures(textures: Dictionary, card: String) -> void:
	_add_path(textures, str(GameData.card_def(card).get("art_path", "")))
	if GameData.card_is_item(card): _add_path(textures, GameData.item_icon_path(card))

static func _add_equipment_textures(textures: Dictionary, equipment: String, state: Dictionary) -> void:
	_add_path(textures, str(GameData.equipment_def(equipment).get("icon_path", "")))
	for card: String in GameData.equipment_cards(equipment, state): _add_card_textures(textures, card)

static func _add_path(textures: Dictionary, path: String) -> void:
	if not path.is_empty() and not textures.has(path): textures[path] = false

static func prepare_hidden_shop_for(scene: Node, state: Dictionary, present_frame: Callable, still_active: Callable) -> void:
	var room: Dictionary = scene._run_engine.room_metadata(state, state.get("current_room", Vector2i.ZERO))
	if str(room.get("type", "")) != "scavenger": return
	var shop: Control = scene._scavenger_shop_view
	if not is_instance_valid(shop): return
	await shop.get_script().prepare_hidden_for(shop, state, scene._run_engine, scene._reduced_motion_enabled(), present_frame, still_active, scene._record_runtime_performance_phase if scene._runtime_performance_instrumentation_enabled else Callable())

static func pre_battle_view_active(scene: Variant, generation: int, revision: int, still_active: Callable) -> bool:
	return active(scene, generation) and scene._prepared_pre_battle_view_revision == revision and bool(still_active.call()) and is_instance_valid(scene._pre_battle_scrim) and not scene._pre_battle_scrim.visible

static func prepare_hidden_pre_battle_for(scene: Node, state: Dictionary, preview: Dictionary, generation: int, present: Callable, still_active: Callable) -> void:
	if not active(scene, generation) or not bool(still_active.call()) or not is_instance_valid(scene._pre_battle_scrim) or scene._pre_battle_scrim.visible or (preview.get("combat_state", {}) as Dictionary).is_empty(): return
	var revision: int = scene._prepared_pre_battle_view_revision
	var jobs: Array[Callable] = scene._begin_hidden_pre_battle_view(state, preview)
	var slice_started: int = Time.get_ticks_usec()
	for job: Callable in jobs:
		if not pre_battle_view_active(scene, generation, revision, still_active): return
		job.call()
		await Glyphs.prepare_controls_for(scene, scene._pre_battle_panel, present, pre_battle_view_active.bind(scene, generation, revision, still_active))
		if not pre_battle_view_active(scene, generation, revision, still_active): return
		if Time.get_ticks_usec() - slice_started >= 4000:
			await present.call()
			if not pre_battle_view_active(scene, generation, revision, still_active): return
			slice_started = Time.get_ticks_usec()
	if pre_battle_view_active(scene, generation, revision, still_active): scene._prepared_pre_battle_view_ready = true
