extends RefCounted
## Record the game projectile and verify that it survives the tooltip crop.
const ReflectView = preload("res://scripts/enemy_mechanics/reflect_view.gd")
const RangedAction = preload("res://scripts/protagonist_cutout/ranged_action.gd")
const Fx = preload("res://scripts/attack_fx_library.gd")
const Sfx = preload("res://scripts/attack_sfx_library.gd")
const FLIGHT_START: float = 0.25
const FLIGHT_END: float = 0.75
const PIXEL_RADIUS: int = 8
const MIN_ICE_PIXELS: int = 4
const MIN_BLUE_CHANGE: float = 0.12
const MIN_BLUE_SEPARATION: float = 0.10
const REVIEW_FPS: int = 12

var _baseline: Image
var _witnesses: Dictionary = {}

static func play(scene: Control, beat: Dictionary) -> void:
	var action: Dictionary = beat["action"]
	var before: Dictionary = beat["before"]
	var target: Vector2i = beat["target"]
	# Give both legs room to read at tooltip size using the existing Ice attack
	# timing and art, with the normal cast preparation and fast combat pacing.
	var outbound: float = Fx.animation_duration_seconds_for_style(Fx.STYLE_ICE_SHARDS)
	var effect: Dictionary = ReflectView.reflected_effect(before, action, target, outbound)
	effect["protagonist_ranged"] = RangedAction.clip_for_action(action)
	scene._hero_facing.begin_action(scene._combat_engine, before, action, target)
	scene._ensure_sfx_bank()
	scene._sfx_router.begin_player_action(before, action, scene._sfx_router.weapon_for_card(beat["card"], scene._run_state))
	await RangedAction.prepare(scene, before, effect, {})
	scene._play_sfx(Sfx.entry_for_player_action(scene._card_def(beat["card"], before), action))
	await ReflectView.play_projectile(scene, before, beat["after"], effect, Fx.ICE_FRAME_SECONDS)

static func flight_leg(effect: Dictionary, progress: float) -> String:
	if effect.get("action_type") != "reflected_projectile": return ""
	var phase: Dictionary = ReflectView.projectile_frame(progress, effect["en05_outbound_seconds"])
	if phase["flash"] or not (FLIGHT_START <= phase["travel"] and phase["travel"] <= FLIGHT_END): return ""
	return "return" if phase["returning"] else "outbound"

func observe_pixels(board: Control, crop: Rect2i, picture: Image, frame: int) -> String:
	if _baseline == null:
		_baseline = picture
		return ""
	var effect: Dictionary = board.presentation.get("effect", {})
	var progress: float = board.presentation.get("effect_progress", 0.0)
	var leg: String = flight_leg(effect, progress)
	if leg.is_empty(): return ""
	var pose: Dictionary = ReflectView.projectile_pose(board, effect, progress)
	var screen: Vector2 = board.get_global_transform_with_canvas() * (pose["point"] as Vector2)
	var pixel := Vector2i((screen - Vector2(crop.position)) / Vector2(crop.size) * Vector2(picture.get_size()))
	var area := Rect2i(pixel - Vector2i.ONE * PIXEL_RADIUS, Vector2i.ONE * (2 * PIXEL_RADIUS + 1))
	if not Rect2i(Vector2i.ZERO, picture.get_size()).encloses(area): return ""
	var matching: int = 0
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var color: Color = picture.get_pixel(x, y)
			if color.b - _baseline.get_pixel(x, y).b >= MIN_BLUE_CHANGE and color.b - color.r >= MIN_BLUE_SEPARATION:
				matching += 1
	if matching < MIN_ICE_PIXELS: return ""
	if not _witnesses.has(leg):
		_witnesses[leg] = {"first_frame": frame, "last_frame": frame - 1, "run": 0, "max_run": 0}
	var witness: Dictionary = _witnesses[leg]
	witness["run"] = int(witness["run"]) + 1 if frame == int(witness["last_frame"]) + 1 else 1
	witness["max_run"] = maxi(int(witness["max_run"]), int(witness["run"]))
	witness["last_frame"] = frame
	return leg if frame == witness["first_frame"] else ""

func report(fps: int, errors: Array[String]) -> Dictionary:
	# Each leg must be visible for a full 12-fps sampling interval even when
	# the review sampler starts between the recorder's frames.
	var minimum: int = ceili(float(fps) / REVIEW_FPS)
	for leg: String in ["outbound", "return"]:
		if int(_witnesses.get(leg, {}).get("max_run", 0)) < minimum:
			errors.append("Reflect %s projectile must be visible at tooltip size through a 12-fps sampling interval" % leg)
	return _witnesses
