extends SceneTree

const Assets = preload("res://scripts/asset_loader.gd")
const Textures = preload("res://scripts/combat_texture_preparation.gd")
const Encounter = preload("res://scripts/encounter_asset_preparation.gd")
const Compass = preload("res://scripts/enemy_intent_compass.gd")
const Data = preload("res://scripts/game_data.gd")
const Card = preload("res://scripts/card_widget.gd")
const Ink = preload("res://scripts/turn_order_ink.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Element = preload("res://scripts/element_data.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const PILLAR_TILE := Vector2i(2, 1)
const OVERLAY_COORD := Vector2i.ZERO
const REAR_THAROKH := "res://assets/units/tharokh_cutout/rear/rest.png"
const REAR_SPLIT_DROPLET := "res://assets/units/cinder_droplet_cutout/rear/rest.png"
const SPLIT_DROPLET_PART := "res://assets/units/cinder_droplet_cutout/front/left_outer.png"
const INSPECTED_GEAR := "duelist_rapier"
const INSPECTED_CARD := "battle_rhythm"

class EncounterHost extends Node:
	var board_view: Control
	var _combat_texture_scope: Assets.TexturePreparationScope
	var _encounter_preparation_generation: int = 1
	var _encounter_cpu_asset_holds: Array[RefCounted]
	var _run_engine := RunEngine.new()

	func _card_def(id: String, state: Dictionary) -> Dictionary:
		return Data.card_def_for_progression(id, state)

	func _combat_portrait_path(type: String) -> String:
		return str(preload("res://scripts/turn_order_portraits.gd").PATHS.get(type, ""))

	func _add_combat_hud_textures(_paths: Dictionary) -> void:
		pass

var failures: Array[String]
var checks: int = 0

func _initialize() -> void:
	Runtime.apply_from_environment()
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _run() -> void:
	var host := EncounterHost.new()
	root.add_child(host)
	var board := Board.new()
	host.board_view = board
	board._load_floor_overlay_assets(Element.EARTH, "pillar", Board.MOSS_PILLAR_OVERLAY_PATHS)
	var state: Dictionary = {"mode": "pre_battle", "magic_inventory": ["worldbreak"],
		"item_inventory": ["crimson_draught"], "equipment_inventory": [INSPECTED_GEAR]}
	var combat: Dictionary = {
		"deck": {"draw": ["rockburst", "vortex", "vortex"], "hand": ["quick_stab"], "discard": ["dull_bolt"]},
		"equipped_items": ["nail_bomb"],
		"loot": [{"kind": "item", "card_id": "bottled_gale"}, {"kind": "equipment", "equipment_id": "rime_locket"},
			{"kind": "item", "card_id": "crimson_draught", "claimed": true}],
		"enemies": [{"type": "tharokh"}, {"type": "crawler"}, {"type": "cinder_ooze"}],
		"room_coord": OVERLAY_COORD, "room_element": Element.FIRE, "moss": {"pillar": [PILLAR_TILE]},
	}
	var manifest: Dictionary = Textures.texture_manifest(host, state, combat)
	for path: String in Compass.TEXTURE_PATHS.values():
		_check(manifest.has(path), "Details compass path absent: " + path)
	for path: String in [Data.card_def("rockburst")["art_path"], Data.card_def("vortex")["art_path"], Data.card_def("dull_bolt")["art_path"],
		Card.CARD_FRAME_EPIC_PATH, Card.CARD_FRAME_RARE_PATH, Data.item_icon_path("bottled_gale"), Data.item_icon_path("nail_bomb"),
		Data.equipment_def("rime_locket")["icon_path"], Ink.BRUSH_DIR + Ink.HERO_BRUSH, Ink.BRUSH_DIR + "brush_a.png",
		"res://assets/art/icons/melee.png"]:
		_check(manifest.has(path), "Encounter path absent: " + path)
	for path: String in [Data.card_def("worldbreak")["art_path"], Card.CARD_FRAME_LEGENDARY_PATH,
		Data.item_icon_path("crimson_draught"), host._combat_portrait_path("iskaldra")]:
		_check(not manifest.has(path), "Unrelated path was included: " + path)
	var rig_textures: Dictionary = {}
	board.unit_rig_preparation_manifest(combat, rig_textures)
	_check(rig_textures.has(REAR_THAROKH), "Rear rest pose absent from rig preparation")
	_check(rig_textures.has(REAR_SPLIT_DROPLET), "Death-spawn rear rest pose absent from rig preparation")
	var before: Dictionary = combat.duplicate(true)
	var source: Texture2D = board.room_overlay_flip_sources(combat).front()
	_check(source != null and str(source.get_meta("asset_source_path", "")) == Board.MOSS_PILLAR_OVERLAY_PATHS[0],
		"Fire room pillar should use the authored earth overlay")
	var active: Callable = Encounter.active.bind(host, host._encounter_preparation_generation)
	var loadout: Dictionary = Encounter.state_texture_manifest(host, state, combat)
	var inspected_art: String = str(Data.card_def(INSPECTED_CARD)["art_path"])
	_check(loadout.has(inspected_art), "Unequipped gear inspection card was missing from the loadout pass")
	_check(not Assets.has_cached_texture(SPLIT_DROPLET_PART), "Unspawned rig started warm")
	await Encounter.prepare_rig_textures_for(host, combat, loadout, _present, active, rig_textures)
	_check(Assets.has_cached_texture(inspected_art), "Unequipped gear inspection card was still cold after preparation")
	_check(not Assets.has_cached_texture(SPLIT_DROPLET_PART), "Speculative body entered the session cache during rig preparation")
	await Textures.prepare_for(host, state, combat, _present, active, rig_textures)
	_check(Assets.has_cached_texture(SPLIT_DROPLET_PART), "Speculative body was still cold after encounter preparation")
	for path: String in Compass.TEXTURE_PATHS.values():
		_check(Assets.has_cached_texture(path), "Details compass still cold after encounter preparation: " + path)
	_check(combat == before, "Preparation mutated the encounter state")
	_check(host._combat_texture_scope != null, "Preparation did not publish its scope")
	var test_path: String = str(Data.card_def("vortex")["art_path"])
	_check(Assets.has_cached_texture(test_path), "Later draw is still cold")
	var identity: WeakRef
	if host._combat_texture_scope != null and host._combat_texture_scope.textures.has(test_path):
		var held: Texture2D = host._combat_texture_scope.textures[test_path]
		_check(Assets.load_texture(test_path) == held, "Ordinary card art did not reuse the staged asset")
		identity = weakref(held)
		held = null
	else:
		_check(false, "Later card art is missing from the scoped cache")
	if source != null:
		var expected: Texture2D = Assets.flip_texture_h(source)
		board.combat_state = combat
		_check(board._moss_texture_for_surface("pillar", PILLAR_TILE) == expected, "Ordinary board draw did not reuse the staged flip")
	var scope_id: int = host._combat_texture_scope.get_instance_id() if host._combat_texture_scope != null else 0
	await Textures.prepare_for(host, state, combat, _present, func() -> bool: return false)
	_check(host._combat_texture_scope != null and host._combat_texture_scope.get_instance_id() == scope_id,
		"Canceled preparation replaced the active scope")
	board.free()
	host.queue_free()
	await process_frame
	_check(not Assets._texture_cache.has(test_path), "Scoped card entered the session texture cache")
	_check(identity != null and identity.get_ref() == null and not Assets.has_cached_texture(test_path), "Scoped card survived after the last owner released it")
	_check(not Assets.has_cached_texture(SPLIT_DROPLET_PART), "Speculative body survived scene teardown")
	await _test_shutdown()
	for failure: String in failures: push_error(failure)
	print("TEST RESULT: %s (%d checks)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _present() -> void:
	await process_frame

func _test_shutdown() -> void:
	var host := EncounterHost.new()
	root.add_child(host)
	var board := Board.new()
	host.board_view = board
	board._load_floor_overlay_assets(Element.EARTH, "pillar", Board.MOSS_PILLAR_OVERLAY_PATHS)
	var combat: Dictionary = {"room_coord": OVERLAY_COORD, "room_element": Element.FIRE, "moss": {"pillar": [PILLAR_TILE]}}
	var source: Texture2D = board.room_overlay_flip_sources(combat).front()
	var flip_key: String = Assets._texture_processing_cache_key(source) + "|flip_h"
	_check(Assets._prepared_texture(flip_key) == null, "Shutdown test started with a prepared overlay flip")
	Assets.count_preparation_work(Time.get_ticks_usec() - Assets.PREPARATION_SLICE_USEC)
	await Textures.prepare_for(host, {"mode": "pre_battle"}, combat, _cancel_and_present,
		func() -> bool: return true)
	_check(Assets.preparation_is_stopping(root), "Shutdown did not cancel the paused preparation")
	_check(Assets._prepared_texture(flip_key) == null, "Overlay flip published after shutdown")
	_check(host._combat_texture_scope == null, "Encounter texture scope published after shutdown")
	board.free()
	host.free()

func _cancel_and_present() -> void:
	Assets.cancel_preparation_for(root)
	await process_frame
