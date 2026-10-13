extends RefCounted

const Sfx = preload("res://scripts/attack_sfx_library.gd")
const PROP_PATH: String = "res://assets/props/enemies/bramble_thicket.png"
const BROWN := Color("3b2a1c")
const LEAF := Color("6f8f4e")
const TRANSITION_SECONDS: float = 0.25
const BRAMBLE_HEIGHT_TILES: float = 0.6 # Director's rise-height reference.
const CRATE_HEIGHT_RATIO: float = 1.1
const FLECK_COUNT: int = 3
const FLECK_SIZE: float = 3.0 # Reuse the approved small leaf-fleck size.

static func tooltip(terrain: Dictionary) -> String:
	return "Bramble: blocks movement for %d more round(s). A unit pushed into it takes 2 damage and Bleeds." % int(terrain.get("rounds_left", 0))

static func full_rect(view: Control, tile: Vector2i, texture: Texture2D) -> Rect2:
	var crate: Texture2D = view._terrain_textures.get("wooden_crate", null)
	if crate == null or texture == null: return Rect2()
	var crate_rect: Rect2 = view._terrain_rect_for_tile(tile, crate, "wooden_crate")
	var used: Rect2i = view._texture_used_rect(crate)
	var crate_visible_height: float = crate_rect.size.y * float(used.size.y) / crate.get_height()
	var outcrop: Rect2 = view._terrain_rect_for_tile(tile, view._terrain_textures.get("crag_outcrop", null), "crag_outcrop")
	var source: Vector2 = texture.get_size()
	var scale: float = minf(outcrop.size.x / source.x, crate_visible_height * CRATE_HEIGHT_RATIO / source.y)
	var size: Vector2 = source * scale
	var base: Vector2 = Vector2(view._tile_center(tile).x, crate_rect.position.y + crate_rect.size.y * float(used.end.y) / crate.get_height())
	return Rect2(base - Vector2(size.x * 0.5, size.y), size)

static func vertical_scale(progress: float, expiring: bool = false, reduced: bool = false) -> float:
	if reduced: return 0.0 if expiring else 1.0
	var t: float = clampf(progress, 0.0, 1.0)
	# Time reversal of grow's ease-out cubic, retaining a fixed planted base.
	return 1.0 - pow(t, 3.0) if expiring else 1.0 - pow(1.0 - t, 3.0)

static func transition(presentation: Dictionary, tile: Vector2i) -> Dictionary:
	var effect: Dictionary = presentation.get("effect", {})
	var kind: String = str(effect.get("en04_mechanic", ""))
	if kind == "grow_bramble" and (effect.get("tiles", []) as Array).has(tile): return {"expiring": false}
	if kind == "bramble_expiry":
		for terrain: Dictionary in effect.get("expired_bramble", []):
			if terrain.get("pos") == tile: return {"expiring": true}
	return {}

static func rect(view: Control, tile: Vector2i, texture: Texture2D) -> Rect2:
	var result: Rect2 = full_rect(view, tile, texture)
	var active: Dictionary = transition(view.presentation, tile)
	if active.is_empty(): return result
	var scale: float = vertical_scale(float(view.presentation.get("effect_progress", 1.0)), bool(active["expiring"]), bool(view.presentation.get("reduced_motion", false)))
	var base_y: float = result.end.y
	result.size.y *= scale
	result.position.y = base_y - result.size.y
	return result

static func fleck_records(base: Vector2, width: float, rise_height: float, progress: float) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var t: float = clampf(progress, 0.0, 1.0)
	if t <= 0.0 or t >= 1.0: return result
	for index: int in range(FLECK_COUNT):
		var point: Vector2 = base + Vector2(float(index - 1) * width / float(FLECK_COUNT), -rise_height * sin(PI * t))
		result.append({"pos": point, "color": BROWN if index == 1 else LEAF})
	return result

static func draw_flecks(view: Control, tile: Vector2i, texture: Texture2D) -> void:
	if bool(view.presentation.get("reduced_motion", false)) or transition(view.presentation, tile).is_empty(): return
	var full: Rect2 = full_rect(view, tile, texture)
	var base := Vector2(full.get_center().x, full.end.y)
	for fleck: Dictionary in fleck_records(base, full.size.x, view._tile_height() * BRAMBLE_HEIGHT_TILES, float(view.presentation.get("effect_progress", 1.0))):
		view.draw_line(fleck["pos"], fleck["pos"] + Vector2(0, -FLECK_SIZE), fleck["color"], FLECK_SIZE, true)

static func draw_effect(_view: Control, effect: Dictionary, _progress: float) -> bool:
	# Paint and flecks draw in the ordinary sorted terrain layer, never over units.
	return str(effect.get("en04_mechanic", "")) in ["grow_bramble", "bramble_expiry"]

static func presentation_for_step(step: Dictionary, progress: float, reduced: bool = false) -> Dictionary:
	var result: Dictionary = {"effect": step, "effect_progress": progress, "reduced_motion": reduced}
	if str(step.get("en04_mechanic", "")) == "bramble_expiry" and not reduced:
		result["terrain_destruction_units"] = step.get("expired_bramble", []).duplicate(true)
	return result

static func animate(scene: Control, state: Dictionary, step: Dictionary) -> void:
	var reduced: bool = scene._reduced_motion_enabled()
	scene._apply_animation_step(state, step)
	if str(step.get("en04_mechanic", "")) == "grow_bramble": scene._play_sfx(Sfx.entry_for_enemy_action({"type": "ranged", "element": "earth"}))
	if not reduced:
		scene._render_board_state(state, presentation_for_step(step, 0.0))
		await scene._play_timed_animation_frames(scene.ATTACK_FRAMES, TRANSITION_SECONDS / float(scene.ATTACK_FRAMES), func(frame: int) -> void:
			scene._render_board_state(state, presentation_for_step(step, float(frame) / float(scene.ATTACK_FRAMES))))
	scene._render_board_state(state, {})
