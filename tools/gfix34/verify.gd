extends "res://tools/gfix34/fixture.gd"
## Instrument the real reflection adapter and board without requiring GPU pixels.

const Shot = preload("res://scripts/shot_fx.gd")
const FxFixtures = preload("res://tools/fx14/fixtures.gd")
const CASES := [
	["spear", SHOT_CARD, false, false, "spear"],
	["push", PUSH_CARD, false, false, "blade"],
	["hidden_mirror", SHOT_CARD, true, false, "spear"],
	["reduced_motion", SHOT_CARD, false, true, "spear"],
	["legacy", "root_snare", false, false, ""],
	["pull", "vacuum_line", false, false, "hook"],
	["remote", SHOT_CARD, false, false, "spear"],
]

class DrawSpy extends Control:
	var board: Control
	var submitted: bool
	func _tile_center(tile: Vector2i) -> Vector2: return board._tile_center(tile)
	func _arc_control_point(start: Vector2, end: Vector2) -> Vector2: return board._arc_control_point(start, end)
	func _quadratic_bezier(start: Vector2, control: Vector2, end: Vector2, t: float) -> Vector2:
		return board._quadratic_bezier(start, control, end, t)
	func _projectile_element_id(element: String) -> String: return board._projectile_element_id(element)
	func _draw_projectile_sprite(_point: Vector2, _direction: Vector2, _element: String, _t: float) -> void:
		submitted = true

func _take() -> void:
	var base: String = _arg("--base")
	if not _expect(not base.is_empty(), "pass a staged base with --base (see native.sh --dry-run)"):
		quit(2)
		return
	for config: Array in CASES:
		var before: Vector2 = await _case(config, base)
		var after: Vector2 = await _case(config, "")
		_expect(before == after and before.x > 0.0, config[0] + " preserves clock and frame count")
		print("GFIX-34 TIMING %s before=%d after=%d total=%.6fs" % [config[0], before.x, after.x, after.x * after.y])
	_list_unmapped_cards()
	print("GFIX-34 VERIFY: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)

func _case(config: Array, base: String) -> Vector2:
	if not await _open(config[1], base, config[2], config[3], config[0] == "remote"):
		await _close()
		return Vector2.ZERO
	var board: Control = _scene.board_view
	var spy := DrawSpy.new()
	spy.board = board
	var count: Array[int] = [0]
	var revision: String = "after" if base.is_empty() else "before"
	_scene.proof_observer = func(shown: Dictionary) -> void:
		count[0] += 1
		_sample(config, revision, spy, board, shown)
	await _drive(config[1])
	_scene.proof_observer = Callable()
	var clock: Vector2 = _scene.proof_clock
	var baked: bool = base.is_empty() and not str(config[4]).is_empty()
	_expect(count[0] == int(clock.x) + int(baked), config[0] + " submits all timed frames and only the existing completion boundary")
	spy.free()
	await _close()
	return clock

func _sample(config: Array, revision: String, spy: DrawSpy, board: Control, shown: Dictionary) -> void:
	var effect: Dictionary = shown["effect"]
	var progress: float = shown["effect_progress"]
	var phase: Dictionary = View.projectile_frame(progress, effect["en05_outbound_seconds"])
	var leg: String = "return" if phase["returning"] else "outbound"
	if phase["flash"]: leg = "flash"
	if progress >= 1.0: leg = "contact"
	var fx: RefCounted = board._single_shot_fx
	var independent: int = int(fx._heads[0].visible) + int(fx._heads[1].visible)
	var reflected: Node2D = fx.get("_reflected_head") if revision == "after" else null
	var baked: bool = is_instance_valid(reflected) and reflected.visible
	var hit: Node2D = fx._hits[0] if fx._hits[0].visible else null
	spy.submitted = false
	_view_script.draw_effect(spy, effect, progress)
	print("GFIX-34 FRAME %s %s %-8s p=%.3f shot=%s reflection=%d independent=%d legacy=%d hit=%s" % [
		config[0], revision, leg, progress, fx._shot_id, int(baked), independent, int(spy.submitted),
		hit.hit_id if hit != null else "-",
	])
	if revision == "before":
		_expect(spy.submitted, "base reflection submits legacy art")
		return
	var should_bake: bool = not str(config[4]).is_empty()
	_expect(independent == 0 and spy.submitted != should_bake, config[0] + " has one rendering path")
	if not should_bake: return
	_expect(fx._shot_id == config[4] and baked == (not config[3] and leg in ["outbound", "return"]),
		config[0] + " submits the expected flight art")
	if config[2]:
		var visible_count: int = fx._ink.get_shader_parameter("visible_span_count")
		_expect(not board._board_tile_is_visible_to_player(MIRROR) and fx._clip_enabled
			and not Shot.span_contains(fx._clip_spans.slice(0, visible_count), 1.0), "hidden Mirror endpoint is clipped")
	if leg == "contact":
		_expect(hit != null and hit.hit_tile == HERO and hit.hit_id == Shot.metadata()["shots"][config[4]]["hit"] and hit.reduced == config[3],
			config[0] + " uses the authored hit on the hero")
	else:
		_expect(hit == null, config[0] + " does not submit a hit at the Mirror")
	if baked:
		var origin: Vector2i = REMOTE_ORIGIN if config[0] == "remote" else HERO
		var from: Vector2 = board._tile_center(origin) + fx._launch_offset
		if config[0] == "remote" and leg == "return": from = board._tile_center(HERO) + fx._end_offset
		var to: Vector2 = board._tile_center(MIRROR) + fx._end_offset
		var lift: float = Shot.metadata()["shots"][config[4]]["arc_tiles"] * board._tile_width()
		var ease: float = Shot.metadata()["shots"][config[4]]["ease"]
		var t: float = 1.0 - pow(1.0 - phase["travel"], ease) if leg == "return" else pow(phase["travel"], ease)
		var direction: Vector2 = Shot.tangent(from, to, lift, t) * (-1.0 if leg == "return" else 1.0)
		_expect(reflected.position.is_equal_approx(Shot.path(from, to, lift, t))
			and (fx._frames[config[4]]["kind"] != "heading"
				or reflected._frame_rect.x / reflected._frame_rect.z == Shot.heading(direction * fx._physical_scale)),
			config[0] + " follows the baked path and heading")

func _list_unmapped_cards() -> void:
	var unmapped := PackedStringArray()
	for id: String in FxFixtures.cards():
		var card: Dictionary = FxFixtures.cards()[id]
		for action: Dictionary in card["actions"]:
			if View.lone_shot(action) and int(action.get("damage", 0)) > 0 and int(action.get("range", 0)) > 1:
				if Shot.resolve(FxFixtures.card_effect(id, action)).is_empty():
					unmapped.append("%s (%s)" % [card["name"], id])
					break
	unmapped.sort()
	print("GFIX-34 NO BAKED SHOT: " + ", ".join(unmapped))
