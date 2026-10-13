extends SceneTree

const Board = preload("res://scripts/combat_board_view.gd")
const Facing = preload("res://scripts/static_enemy_facing.gd")
const CutoutFacing = preload("res://scripts/enemy_cutout_facing.gd")
const Data = preload("res://scripts/game_data.gd")
const Assets = preload("res://scripts/asset_loader.gd")
# Headless fixture defaults only.
const FIXTURE_BOARD_SIZE: int = 9
const FIXTURE_ENEMY_TILE := Vector2i(4, 4)
const FIXTURE_PLAYER_HP: int = 100
const FIXTURE_BOARD_PIXELS := Vector2(1920, 1080)
const DIRECTIONS: Array[Vector2i] = [Vector2i(0, 2), Vector2i(2, 0), Vector2i(0, -2), Vector2i(-2, 0)]
var _failures: Array[String]
var _checks: int = 0

static func fixture(type: String = "arc_thrall") -> Dictionary:
	var grid: Array
	for y: int in range(FIXTURE_BOARD_SIZE):
		var row: Array[String]
		for x: int in range(FIXTURE_BOARD_SIZE): row.append("stone")
		grid.append(row)
	var definition: Dictionary = Data.enemy_def(type)
	return {"grid": grid, "player": {"pos": FIXTURE_ENEMY_TILE + Vector2i(0, 2), "hp": FIXTURE_PLAYER_HP, "max_hp": FIXTURE_PLAYER_HP},
		"enemies": [{"id": 1, "type": type, "pos": FIXTURE_ENEMY_TILE, "hp": definition["max_hp"], "max_hp": definition["max_hp"], "intent": {}}],
		"terrain": [], "traps": [], "loot": [], "illusions": [], "npcs": []}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for type: String in ["arc_thrall", "slag_mortar", "gust_shrike"]:
		var board: Control = Board.new()
		board.size = FIXTURE_BOARD_PIXELS
		board._ensure_unit_assets_for_type(type)
		var state: Dictionary = fixture(type)
		var unit: Dictionary = state["enemies"][0].duplicate()
		unit["key"] = "enemy_1"
		unit["role"] = "enemy"
		var logical: Rect2
		for delta: Vector2i in DIRECTIONS:
			state = state.duplicate(true)
			state["player"]["pos"] = FIXTURE_ENEMY_TILE + delta
			board.set_combat_state(state)
			var expected: Dictionary = CutoutFacing.direction_for_delta(delta)
			_expect(board.presentation["static_enemy_facings"]["enemy_1"] == expected, type + " follows hero on each diagonal side")
			var texture: Texture2D = board._texture_for_unit(unit)
			var source_path: String = str(Data.enemy_def(type)["art_rear_path" if expected["facing"] == "rear" else "art_path"])
			var source: Image = Image.load_from_file(source_path)
			if expected["mirrored"]: source.flip_x()
			_expect(texture.get_image().get_data() == source.get_data(), type + " exact front/rear/mirrored source pixels")
			var rect: Rect2 = board._unit_draw_rect(unit)
			if logical == Rect2(): logical = rect
			_expect(rect == logical, type + " logical rect stays fixed across facings")
			board._install_unit_shadow_precomputed_data(texture)
			_expect(not board._unit_shadow_data_for_texture(texture)["polygons"].is_empty(), type + " facing has a shadow silhouette")
		# A pending hero destination is not the displayed destination.
		var previous: Dictionary = board.presentation["static_enemy_facings"]["enemy_1"]
		var destination := FIXTURE_ENEMY_TILE + Vector2i(2, 0)
		var moving: Dictionary = {"unit_world_positions": {"player": board._tile_center(destination)}, "unit_draw_tiles": {"player": destination}}
		board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, moving)
		_expect(board.presentation["static_enemy_facings"]["enemy_1"] == previous, "Observer waits until player movement completes")
		state = state.duplicate(true)
		state["player"]["pos"] = destination
		board.set_combat_state(state)
		_expect(board.presentation["static_enemy_facings"]["enemy_1"] == CutoutFacing.direction_for_delta(Vector2i(2, 0)), "Player-only movement completion turns observer")
		# Move away from the player; action direction wins over idle direction.
		var from: Vector2 = board._tile_center(FIXTURE_ENEMY_TILE)
		var to: Vector2 = board._tile_center(FIXTURE_ENEMY_TILE + Vector2i(-1, 0))
		moving = {"unit_world_positions": {"enemy_1": from.lerp(to, 0.5)}, "unit_draw_tiles": {"enemy_1": FIXTURE_ENEMY_TILE + Vector2i(-1, 0)}}
		board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, moving)
		_expect(board.presentation["static_enemy_facings"]["enemy_1"] == CutoutFacing.direction_for_delta(Vector2i(-1, 0)), "Mid-move follows its own direction")
		state = state.duplicate(true)
		state["enemies"][0]["pos"] += Vector2i(-1, 0)
		board.set_combat_state(state)
		_expect(board.presentation["static_enemy_facings"]["enemy_1"] == CutoutFacing.direction_for_delta(destination - state["enemies"][0]["pos"]), "Enemy movement completion returns to watching hero")
		var attack: Dictionary = {"effect": {"kind": "projectile", "actor_key": "enemy_1", "from": state["enemies"][0]["pos"], "to": state["enemies"][0]["pos"] + Vector2i(0, -1)}, "effect_progress": 0.5}
		board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, attack)
		var terminal: Dictionary = board.presentation["static_enemy_facings"]["enemy_1"]
		_expect(terminal == CutoutFacing.direction_for_delta(Vector2i(0, -1)), "Attack faces its own target")
		attack["reduced_motion"] = true
		board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, attack)
		_expect(board.presentation["static_enemy_facings"]["enemy_1"] == terminal, "Reduced motion keeps action-facing policy")
		var dead: Dictionary = state["enemies"][0].duplicate()
		dead["death_animation"] = true
		dead["death_progress"] = 0.5
		dead["hp"] = 0
		state = state.duplicate(true)
		state["enemies"] = []
		state["player"]["pos"] = Vector2i(7, 7)
		board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"death_animation_units": [dead]})
		_expect(board.presentation["static_enemy_facings"]["enemy_1"] == terminal, "Death retains the preceding facing despite hero movement")
		dead["key"] = "enemy_1"
		dead["role"] = "enemy"
		_expect(board._enemy_shadow_dissolve_source_texture(dead) == board._texture_for_unit(dead), "Death shader and body share facing texture")
		board.free()
	_expect(not Facing.handles("storm_capacitor") and Facing.handles("gust_shrike"), "Capacitor stays fixed; approved Gust Shrike enters directional path")
	var capacitor: Control = Board.new()
	capacitor._ensure_unit_assets_for_type("storm_capacitor")
	_expect(capacitor._unit_art_scale({"type": "storm_capacitor"}) == Data.enemy_def("storm_capacitor")["art_scale"], "Explicit approved capacitor scale supersedes old canvas compensation")
	capacitor.free()
	for failure: String in _failures: push_error(failure)
	print("STATIC FACING TEST RESULT: %s (%d checks, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition: _failures.append(message)
