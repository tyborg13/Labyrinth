extends RefCounted

const Assets = preload("res://scripts/asset_loader.gd")
const Cards = preload("res://scripts/card_widget.gd")
const Data = preload("res://scripts/game_data.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Compass = preload("res://scripts/enemy_intent_compass.gd")
const Ink = preload("res://scripts/turn_order_ink.gd")
const Dependencies = preload("res://scripts/maquette_cutout_runtime/dependencies.gd")
const Objective = preload("res://scripts/combat_objective_rules.gd")
const Portraits = preload("res://scripts/turn_order_portraits.gd")
const Maquette = preload("res://scripts/maquette_cutout_runtime/presentation.gd")
const BattlefieldItems = preload("res://scripts/battlefield_item_rules.gd")

# This switch is used by the native census for matched takes of the same build.
const BASELINE_META: StringName = &"labyrinth_combat_texture_baseline"
static var _hitch_trace_enabled: bool = OS.get_environment("LABYRINTH_HITCH_TRACE") == "1"

static func enabled(scene: Node, state: Dictionary, combat: Dictionary) -> bool:
	return not combat.is_empty() and str(state.get("mode", "")) in ["pre_battle", "combat"] and not scene.get_tree().root.has_meta(BASELINE_META)

static func prepare_for(scene: Node, state: Dictionary, combat: Dictionary, present: Callable, still_active: Callable, rig_textures: Dictionary = {}) -> void:
	if not bool(still_active.call()): return
	var root: Node = scene.get_tree().root
	var alive: Callable = Assets.preparation_is_active.bind(root, still_active)
	if not bool(alive.call()): return
	var telemetry: Node = root.get_node("PerformanceTelemetry") if _hitch_trace_enabled else null
	var wall: RefCounted = telemetry.hitch_phase("combat_texture_preparation:wall") if telemetry != null else null
	await Assets.wait_for_preparation_slice(present, alive)
	if not bool(alive.call()): return
	var started: int = Time.get_ticks_usec()
	var scope: Assets.TexturePreparationScope = Assets.new_texture_preparation_scope()
	var rewards: Array[String] = scene._run_engine.room_reward_texture_card_ids(state)
	var paths: Dictionary = texture_manifest(scene, state, combat, rewards)
	paths.merge(rig_textures, true)
	scene._add_combat_hud_textures(paths)
	var overlays: Array[Texture2D] = scene.board_view.room_overlay_flip_sources(combat)
	Assets.count_preparation_work(started, &"combat_texture_manifest")
	await Assets.prepare_textures_for(root, paths, present, alive, Callable(), false, scope)
	if not bool(alive.call()): return
	for texture: Texture2D in overlays:
		await Assets.wait_for_preparation_slice(present, alive, &"combat_overlay_flip")
		if not bool(alive.call()): return
		started = Time.get_ticks_usec()
		Assets.flip_texture_h(texture, scope)
		Assets.count_preparation_work(started, &"combat_overlay_flip")
	await Assets.wait_for_preparation_slice(present, alive, &"", 0)
	if not bool(alive.call()): return
	var board: Control = scene.board_view
	await board.get_script().prepare_trap_assets_for(board, combat, present, alive)
	if not bool(alive.call()): return
	scene._combat_texture_scope = scope
	wall = null
	if telemetry != null: telemetry.hitch_combat_texture_scope(scene._encounter_preparation_generation, scope.textures)

static func texture_manifest(scene: Node, state: Dictionary, combat: Dictionary, rewards: Array = []) -> Dictionary:
	var paths: Dictionary = {}
	scene.board_view.add_trap_texture_paths(paths, combat)
	var cards: Dictionary = {}
	var deck: Dictionary = combat.get("deck", {})
	for pile: String in ["draw", "hand", "discard", "burned", "consumed"]:
		for id: String in deck.get(pile, []): cards[id] = true
	for id: String in combat.get("equipped_items", state.get("equipped_items", [])): cards[id] = true
	for id: String in rewards: cards[id] = true
	for equipment: String in (combat.get("equipped_equipment", state.get("equipped_equipment", {})) as Dictionary).values():
		_add_path(paths, str(Data.equipment_def(equipment).get("icon_path", "")))
	for loot: Dictionary in combat.get("loot", []):
		if bool(loot.get("claimed", false)): continue
		_add_path(paths, BattlefieldItems.loot_icon_path(loot))
		if str(loot.get("kind", "")) == "item": cards[str(loot.get("card_id", ""))] = true
	for id: String in cards:
		var card: Dictionary = scene._card_def(id, combat)
		if not card.is_empty(): add_card_textures(paths, id, card)
	Ink.add_brush_textures(paths)
	# Details can disclose any family as the encounter's intents change.
	for path: String in Compass.TEXTURE_PATHS.values(): _add_path(paths, path)
	_add_path(paths, Cards.TimeCostBadge.WATCH_TEXTURE_PATH)
	_add_path(paths, str(Portraits.PATHS.get("player", "")))
	if not (combat.get("umbra", {}) as Dictionary).is_empty(): _add_path(paths, Portraits.UMBRA_PRESENCE_PATH)
	_add_path(paths, Objective.icon_path(str((combat.get("objective", {}) as Dictionary).get("type", Objective.KILL_ALL))))
	for type: String in Dependencies.types_for(combat, true):
		_add_enemy_textures(scene, paths, type)
	for enemy: Dictionary in combat.get("enemies", []):
		_add_intent_icons(paths, enemy.get("intent", {}))
	return paths

## One card face: art, item icon, rarity frame, role emblem and action icons.
static func add_card_textures(paths: Dictionary, id: String, card: Dictionary) -> void:
	_add_path(paths, str(card.get("art_path", "")))
	_add_path(paths, Data.item_icon_path(id))
	_add_path(paths, Cards._card_frame_path(str(card.get("rarity", "common"))))
	_add_path(paths, Icons.card_role_emblem_path(card))
	for action: Dictionary in card.get("actions", []): _add_action_icons(paths, action)

static func _add_enemy_textures(scene: Node, paths: Dictionary, type: String) -> void:
	var definition: Dictionary = Data.enemy_def(type)
	_add_path(paths, scene._combat_portrait_path(type))
	_add_path(paths, str(definition.get("art_path", "")))
	for intent: Dictionary in definition.get("intents", []): _add_intent_icons(paths, intent)
	if Maquette.handles(type):
		var directory: String = Maquette.asset_directory(type)
		for view: String in ["front", "rear"]:
			var rest: String = directory.path_join(view + "/rest.png")
			if FileAccess.file_exists(rest) or ResourceLoader.exists(rest): paths[rest] = true

static func _add_intent_icons(paths: Dictionary, intent: Dictionary) -> void:
	for action: Dictionary in intent.get("actions", []):
		var type: String = str(action.get("type", ""))
		if type == "lob_mark":
			# The raw marking intent has no damage. Its visible row gets the
			# surface from the paired landing, which is also in the manifest.
			for key: String in [Icons.action_icon_key(action), "aoe_pattern", "marked", "aoe"]:
				_add_path(paths, Icons.icon_path(key))
			continue
		_add_action_icons(paths, action)
		if type == "lob_land":
			_add_path(paths, Icons.icon_path(Icons.surface_icon_key(str(action["surface"]))))

static func _add_action_icons(paths: Dictionary, action: Dictionary) -> void:
	_add_path(paths, Icons.icon_path(Icons.action_icon_key(action)))
	for token: Dictionary in Icons.tokens_for_action(action):
		_add_path(paths, Icons.icon_path(str(token.get("icon", ""))))

static func _add_path(paths: Dictionary, path: String) -> void:
	if not path.is_empty() and not paths.has(path): paths[path] = false
