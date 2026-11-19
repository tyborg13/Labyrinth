extends RefCounted
## Production room definitions and pre-battle factory inputs used by the probes.

const Board = preload("res://tools/brd01/fixture.gd")
const Census = preload("res://tools/hitch_census/fixtures.gd")
const Dragons = preload("res://scripts/dragon_boss_library.gd")
const KINDS := ["normal", "guardian", "warband", "tharokh", "umbra"]
const WARBAND_BIOME: String = "earth"
const WARBAND_TIER: int = 2
const UMBRA_SECTION: int = 5
const BOSS_ID: String = "tharokh"

static func pre_battle(kind: String) -> Dictionary:
	var seed_value: int = Board.Dragon.seed_for_options({"seed": Board.SEED_START, "dragon_id": BOSS_ID, "dragon_depth": Board.DRAGON_DEPTH})
	var engine := Board.Run.new()
	if kind == "warband":
		var fixture := Census.new()
		var run: Dictionary = fixture.make("warband", seed_value, {"warband_case": "pre_battle", "warband_biome": WARBAND_BIOME, "warband_tier": WARBAND_TIER})
		fixture.free()
		return run
	var state: Dictionary = engine.create_new_run(seed_value, Board.Tutorial.complete_tutorial(Board.Store.default_data()))
	var room_type: String = "boss" if Dragons.BOSS_ELEMENTS.has(kind) else ("guardian" if kind == "guardian" else "combat")
	for room: Dictionary in state["rooms"].values():
		if room.get("type") != room_type: continue
		if room_type == "boss" and room.get("boss_id") != kind: continue
		if kind == "umbra" and int(room.get("section_index", -1)) != UMBRA_SECTION: continue
		state["current_room"] = room["coord"]
		room["revealed"] = true
		room["visited"] = true
		state["current_room_layout"] = engine._display_layout_for_room(seed_value, room, Board.ENTRANCE)
		state["mode"] = "pre_battle"
		state["pre_battle_pending"] = true
		state["pre_battle_travel_dir"] = Board.ENTRANCE
		return state
	return {}

static func combat(kind: String) -> Dictionary:
	return Board.Run.new().begin_pre_battle_combat(pre_battle(kind))

static func motion(viewport: Viewport, point: Vector2, held: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	if held: event.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(event, true)

static func button(viewport: Viewport, point: Vector2, index: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = index
	event.pressed = pressed
	viewport.push_input(event, true)
