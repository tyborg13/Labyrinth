extends RefCounted

const Ground = preload("res://scripts/board_surface_rules.gd")
const Attack = preload("res://tests/pixel_fx_fixture.gd")
const SIZE := Vector2i(1920, 1080)
const BIOMES: PackedStringArray = ["stone", "iskaldra"]
const KINDS: PackedStringArray = ["fire", "ice", "electrified", "rubble"]
const DEPTH := Vector2i(3, 3)
const PATCH := Rect2i(3, 3, 3, 3)
const HERO_ON_PATCH := Vector2i(3, 4)
const ENEMY_ON_PATCH := Vector2i(5, 4)
const MIXED_CLEAR := Rect2i(1, 2, 4, 4)
const MIXED_HIDDEN := Rect2i(5, 2, 4, 4)
const MIXED_BLOCK := Vector2i(2, 2)
const SHARED_PATCH := Rect2i(2, 3, 2, 2)
const MANY := Rect2i(2, 2, 5, 5)
const PROOF_SECONDS: float = 12.0
const NO_TILE := Vector2i(-1, -1)

static func make_view(size_px: Vector2i, logical_size: Vector2i, msaa: Viewport.MSAA) -> SubViewport:
	var view := SubViewport.new()
	view.size = size_px
	view.size_2d_override = logical_size
	view.size_2d_override_stretch = true
	view.msaa_2d = msaa
	view.disable_3d = true
	view.gui_disable_input = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return view

static func submit(board: Control, state: Dictionary, shown: Dictionary) -> void:
	board.call("set_combat_state", state, [], [], NO_TILE, "", "", {}, {}, shown)

static func gallery_cases() -> Array[Dictionary]:
	var result: Array[Dictionary]
	for biome: String in BIOMES:
		for kind: String in KINDS:
			for occupied: bool in [false, true]:
				result.append(patch_case(biome, kind, occupied))
	var mixed: Dictionary = _state(false)
	_place_blocks(mixed, MIXED_CLEAR)
	_place_blocks(mixed, MIXED_HIDDEN)
	var mixed_shown: Dictionary = _shown(BIOMES[0])
	mixed_shown["umbra_stage"] = "pressing"
	var left_half := Rect2i(0, 0, MIXED_HIDDEN.position.x, mixed["grid"].size())
	mixed_shown["umbra_visible_tiles"] = tiles_in(left_half)
	var mixed_crops: Dictionary = {"clear": tiles_in(MIXED_CLEAR), "fog": tiles_in(MIXED_HIDDEN)}
	for i: int in range(KINDS.size()):
		var offset := Vector2i(i % 2, i / 2) * MIXED_BLOCK
		mixed_crops["clear_" + KINDS[i]] = tiles_in(Rect2i(MIXED_CLEAR.position + offset, MIXED_BLOCK))
		mixed_crops["fog_" + KINDS[i]] = tiles_in(Rect2i(MIXED_HIDDEN.position + offset, MIXED_BLOCK))
	result.append({"id": "mixed_umbra", "state": mixed, "shown": mixed_shown,
		"crops": mixed_crops})
	var shared: Dictionary = _state(false)
	var shared_crops: Dictionary = {}
	for kind: String in ["fire", "ice", "electrified"]:
		var patch: Rect2i = SHARED_PATCH
		patch.position.x += shared_crops.size() * SHARED_PATCH.size.x
		place_rect(shared, patch, "rubble")
		place_rect(shared, patch, kind)
		shared_crops[kind] = tiles_in(patch)
	result.append({"id": "shared_ground", "state": shared, "shown": _shown(BIOMES[0]), "crops": shared_crops})
	var stormcoal: Dictionary = _state(false)
	stormcoal["surface_rule_overrides"] = {"conductive_fire": true}
	var electric_patch := Rect2i(SHARED_PATCH.position + Vector2i(SHARED_PATCH.size.x, 0), SHARED_PATCH.size)
	place_rect(stormcoal, SHARED_PATCH, "fire")
	place_rect(stormcoal, electric_patch, "electrified")
	result.append({"id": "stormcoal", "state": stormcoal, "shown": _shown(BIOMES[0]),
		"crops": {"patch": tiles_in(SHARED_PATCH) + tiles_in(electric_patch)}})
	for element: String in Attack.ELEMENTS:
		var shown: Dictionary = _shown(BIOMES[0])
		var effect: Dictionary = Attack.effect(element)
		var frames: int = Attack.Fx.animation_frame_count(effect, 6, false)
		# Use vfx-01's original mid-travel sample for visible projectiles.
		var progress: float = float(Attack.key_frames(element)["20_travel"]) / frames
		shown.merge(Attack.presentation(element, progress), true)
		result.append({"id": "attack_" + element, "state": _state(true), "shown": shown,
			"crops": {"effect": [Attack.SOURCE, Attack.TARGET]}})
	return result

static func patch_case(biome: String, kind: String, occupied: bool) -> Dictionary:
	var state: Dictionary = _state(occupied)
	if occupied:
		state["player"]["pos"] = HERO_ON_PATCH
		state["enemies"][0]["pos"] = ENEMY_ON_PATCH
	if kind == "stormcoal":
		state["surface_rule_overrides"] = {"conductive_fire": true}
	place_rect(state, PATCH, "fire" if kind == "stormcoal" else kind)
	return {"id": "%s_%s_%s" % [biome, kind, "occupied" if occupied else "empty"],
		"state": state, "shown": _shown(biome), "crops": {"patch": tiles_in(PATCH)}}

static func baseline_cases(include_stormcoal: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary]
	result.append({"id": "none", "state": _state(false)})
	for kind: String in KINDS:
		var one: Dictionary = _state(false)
		Ground.place(one, PATCH.get_center(), kind)
		result.append({"id": kind + "_one", "state": one})
		var many: Dictionary = _state(false)
		place_rect(many, MANY, kind)
		result.append({"id": kind + "_many", "state": many})
	if include_stormcoal:
		var stormcoal: Dictionary = _state(false)
		stormcoal["surface_rule_overrides"] = {"conductive_fire": true}
		place_rect(stormcoal, MANY, "fire")
		result.append({"id": "stormcoal_many", "state": stormcoal})
		var dense_mixed: Dictionary = _state(false)
		dense_mixed["surface_rule_overrides"] = {"conductive_fire": true}
		var stripe_kinds: PackedStringArray = ["electrified", "electrified", "ice", "rubble", "fire"]
		for tile: Vector2i in tiles_in(MANY):
			Ground.place(dense_mixed, tile, stripe_kinds[tile.x - MANY.position.x])
		result.append({"id": "mixed_many", "state": dense_mixed})
	var mixed: Dictionary = _state(false)
	_place_blocks(mixed, MIXED_CLEAR)
	_place_blocks(mixed, MIXED_HIDDEN)
	result.append({"id": "mixed", "state": mixed})
	return result

static func place_rect(state: Dictionary, rect: Rect2i, kind: String) -> void:
	for tile: Vector2i in tiles_in(rect):
		Ground.place(state, tile, kind)

static func tiles_in(rect: Rect2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i]
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			tiles.append(Vector2i(x, y))
	return tiles

static func counts(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for kind: String in KINDS:
		result[kind] = Ground.tiles(state, kind).size()
	return result

static func _place_blocks(state: Dictionary, area: Rect2i) -> void:
	for i: int in range(KINDS.size()):
		var offset := Vector2i(i % 2, i / 2) * MIXED_BLOCK
		place_rect(state, Rect2i(area.position + offset, MIXED_BLOCK), KINDS[i])

static func _state(actors: bool) -> Dictionary:
	var state: Dictionary = Attack.combat_state()
	state["room_coord"] = DEPTH
	if not actors:
		state["player"] = {}
		state["enemies"] = []
	return state

static func _shown(biome: String) -> Dictionary:
	return {"biome_id": biome, "ambient_time_seconds": PROOF_SECONDS, "umbra_time_seconds": PROOF_SECONDS}
