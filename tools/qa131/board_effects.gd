extends "res://tools/fx12/verify.gd"
## Submit controlled board states and inspect retained effect nodes.

const Shot = preload("res://scripts/shot_fx.gd")
const Shots = preload("res://tools/fx14/fixtures.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const HERO := Vector2i(4, 4)
const SEED: int = 131010
const HEADINGS: Array[Vector2i] = [
	Vector2i(2, -2), Vector2i(2, 0), Vector2i(1, 1), Vector2i(0, 2),
	Vector2i(-2, 2), Vector2i(-2, 0), Vector2i(-1, -1), Vector2i(0, -2),
]
const AREA_OFFSETS: Array[Vector2i] = [
	Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1),
	Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2),
]
const SHOT_CARD: String = "hurl_spear"
const FIXTURE_HP: int = 24
const VICTIM_HP: int = 1
const TRAVEL_MIDPOINT: float = 0.5
const AREA_CONTACT_SECONDS: float = 0.10
const EXPIRE_SECONDS: float = 2.0

var _viewport: SubViewport
var _board: Control
var _decision: int = 0
var _case: String = ""
var _output: String

func _verify() -> void:
	_output = OS.get_environment("LABYRINTH_QA131_CAPTURE_DIR")
	root.content_scale_factor = 1.0
	_viewport = SubViewport.new()
	_viewport.size = BENCHMARK_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_board = Board.new()
	_board.size = Vector2(BENCHMARK_SIZE)
	_viewport.add_child(_board)
	_board.set_process(false)
	await process_frame
	var effect: Dictionary = Shots.named_card(SHOT_CARD)
	var state: Dictionary = Combat.new().create_combat(SEED, Shots.layout_for(effect), {
		"hp": FIXTURE_HP, "max_hp": FIXTURE_HP, "deck_cards": [SHOT_CARD], "hand_size": 1,
	})
	state.erase("umbra")
	state["player"]["pos"] = HERO
	state["enemies"][0]["pos"] = HERO + Vector2i.RIGHT
	state["enemies"][0]["hp"] = VICTIM_HP
	await _area(state, "clear")
	await _area(state, "umbra")
	await _area(state, "fog_mask")
	await _shots(state)
	_viewport.queue_free()
	await process_frame
	for message: String in _failures: push_error(message)
	print("QA131 BOARD EFFECTS: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _begin(label: String) -> void:
	_case = label
	_decision += 1
	print("QA131 BOARD seed=%d decision=%d %s" % [SEED, _decision, label])

func _check(ok: bool, message: String) -> void:
	_expect(ok, "seed=%d decision=%d %s: %s" % [SEED, _decision, _case, message])

func _show(state: Dictionary, presentation: Dictionary = {}) -> void:
	_board.set_combat_state(state, [], [], HERO, "", "", {}, {}, presentation)

func _area(seed_state: Dictionary, visibility_mode: String) -> void:
	_begin(visibility_mode + " overlapping areas and defeated target")
	var before: Dictionary = seed_state.duplicate(true)
	var after: Dictionary = before.duplicate(true)
	after["enemies"].clear()
	var visible: Array[Vector2i]
	var shown: Dictionary = {}
	if visibility_mode == "umbra":
		before["umbra"] = {"stage": "eclipse", "stage_reduction": 0, "light_sources": []}
		after["umbra"] = before["umbra"].duplicate(true)
		visible = Combat.new().umbra_visible_tiles(before)
	elif visibility_mode == "fog_mask":
		visible.append_array([HERO, HERO + Vector2i.RIGHT, HERO + Vector2i.UP])
	if visibility_mode != "clear":
		shown = {"umbra_visible_tiles": visible, "umbra_stage": "eclipse"}
	var tiles: Array[Vector2i]
	for offset: Vector2i in AREA_OFFSETS: tiles.append(HERO + offset)
	var other: Array[Vector2i] = [HERO, HERO + Vector2i.RIGHT, HERO + Vector2i(2, 0)]
	var specs: Array = [
		{"name": "earth", "center": HERO, "tiles": tiles},
		{"name": "fire", "center": other[1], "tiles": other},
	]
	_board.clear_tile_bursts()
	_show(before, shown)
	_board.present_tile_bursts(specs, before, after, false)
	var fx: Fx = _board._tile_bursts
	var expected: int = 0
	for spec: Dictionary in specs:
		for tile: Vector2i in spec["tiles"]:
			if visibility_mode == "clear" or visible.has(tile): expected += 2
	_check(expected >= 26 if visibility_mode == "clear" else expected < 32, "fixture exercises the required footprint or a nontrivial mask")
	_check(fx._stamps.size() == expected, "one rear/front pair per visible tile per area")
	var rows: Dictionary = Fx.metadata()["rows"]
	var hits: Dictionary = {}
	for stamp: Fx.Stamp in fx._stamps:
		_check(visibility_mode == "clear" or visible.has(stamp.tile), "hidden tiles never receive a stamp")
		if stamp.tile == other[1] and stamp.front: hits[stamp.sample.y] = true
	_check(hits.has(int(rows["earth_hit_front"])) and hits.has(int(rows["fire_hit_front"])), "both areas classify the removed enemy as a hit")
	var atlas: Texture2D = fx.ink.get_shader_parameter("atlas")
	_check(atlas != null, "tile burst atlas bound")
	print("QA131 AREA mode=%s expected=%d actual=%d hit_rows=%s" % [visibility_mode, expected, fx._stamps.size(), hits.keys()])
	fx.advance(AREA_CONTACT_SECONDS, -1)
	await _capture("area_" + visibility_mode)
	fx.advance(EXPIRE_SECONDS, -1)
	_check(not fx.has_active(), "area stamps expire")

func _shots(state: Dictionary) -> void:
	var fx: Shot = _board._single_shot_fx
	var headings: Dictionary = {}
	for direction: Vector2i in HEADINGS:
		_begin("empty target shot " + str(direction))
		var target: Vector2i = HERO + direction
		var effect: Dictionary = Shots.named_card(SHOT_CARD)
		effect["from"] = HERO
		effect["to"] = target
		_show(state)
		var middle: float = lerpf(Shot.release_for(Attack.style_for_effect(effect)), Shot.contact_for(effect), TRAVEL_MIDPOINT)
		_show(state, {"effect": effect, "effect_progress": middle})
		var frame: Vector3i = fx._heads[0]._frame_rect
		var details: Dictionary = fx._frames.get(fx._shot_id, {})
		var column: int = frame.x / maxi(1, int(details.get("frame_cells", 1)))
		headings[column] = true
		_check(fx._heads[0].visible and fx._shot_id == "spear", "spear sprite submitted in flight")
		_check(not fx._hits[0].visible, "no contact before arrival at an empty tile")
		print("QA131 FLIGHT target=%s shot=%s column=%d frame=%s" % [target, fx._shot_id, column, frame])
		await _capture("heading_%d" % _decision)
		if direction == HEADINGS[0]:
			_show(state, {"effect": effect, "effect_progress": 1.0})
			print("QA131 MISS empty=%s ground_contact=%s" % [target, fx._hits[0].visible])
			_check(fx._hits[0].visible and not fx._heads[0].visible, "empty ground gets contact only at arrival")
			await _capture("miss_ground")
		else:
			_show(state)
			_check(not fx._heads[0].visible and not fx._hits[0].visible, "withdrawn travel descriptor clears flight without impact")
		fx.advance(EXPIRE_SECONDS)
	_check(headings.size() == 8, "all eight atlas heading columns observed")
	_check(fx._ink.get_shader_parameter("atlas") is Texture2D, "shot atlas bound")

func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var frame: Image = _viewport.get_texture().get_image()
	_check(frame != null and frame.get_size() == BENCHMARK_SIZE, name + " viewport has the proof dimensions")
	if frame != null:
		var path: String = _output.path_join(name + ".png")
		_check(frame.save_png(path) == OK, "capture written")
		print(path)
