extends RefCounted

## A dragon fight opens on the dragon's roar. The fight-preview music fades out
## while the room comes into view, the dragon roars once, the board shudders
## under it, and the dragon's theme rises out of the roar. Then the objective
## and the hand arrive as usual. The roar is the dragon's first of the fight,
## so its first action does not repeat it; big area attacks still roar.
## Presentation only: no combat state, no RNG, no save data.
const Dragon = preload("res://scripts/dragon_presentation.gd")
const Music = preload("res://scripts/music_library.gd")
# The room is seen in quiet first; the objective rises as the roar starts to fade.
const HOLD_SECONDS: float = 0.40
const CARRY_SECONDS: float = 1.50
const CLIP_SECONDS: float = HOLD_SECONDS + CARRY_SECONDS
const TIME_EPSILON_SECONDS: float = 0.000001
# The snap starts on the 0.40 s cue and peaks at 0.513 s: the voice leads,
# the body follows.
const MUSIC_FADE_IN_SECONDS: float = 1.8
# The roar holds for about 1.4 s; the shudder fades evenly across it at the
# rate of a hit's shake (about 11 a second).
const RUMBLE_PX: float = 7.0
const RUMBLE_SECONDS: float = 1.5
const RUMBLE_OSCILLATIONS: float = 16.0

static func dragon(state: Dictionary) -> Dictionary:
	for enemy: Variant in state.get("enemies", []):
		if enemy is Dictionary and Dragon.TYPES.has(str((enemy as Dictionary).get("type", ""))):
			return enemy
	return {}

# Called before the opening's first board submission, including its layout wait.
static func prepare(host: Node) -> void:
	var state: Dictionary = host.get("_combat_state")
	var enemy: Dictionary = dragon(state)
	if not enemy.is_empty():
		_write_motion(host, enemy, opening_motion(state, enemy, 0.0))

static func opening_motion(state: Dictionary, enemy: Dictionary, phase: float) -> Dictionary:
	var origin: Vector2i = enemy.get("pos", Vector2i.ZERO)
	var footprint: Vector2i = enemy.get("footprint", Vector2i(2, 2))
	var player: Vector2i = (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	# Screen x is board x - y. Compare centers, including the dragon's footprint.
	var center: Vector2i = origin * 2 + footprint - Vector2i.ONE
	var hero_is_left: bool = (player.x - player.y) * 2 < center.x - center.y
	return {"clip": "roar", "phase": clampf(phase, 0.0, 1.0),
		"direction": Vector2i(0, 1) if hero_is_left else Vector2i(1, 0)}

static func _write_motion(host: Node, enemy: Dictionary, motion: Dictionary) -> void:
	var presentation: Dictionary = host.get("_board_presentation")
	var key: String = str(enemy["type"]) + "_motion"
	var motions: Dictionary = (presentation.get(key, {}) as Dictionary).duplicate(false)
	var actor_key: String = "enemy_%d" % int(enemy.get("id", -1))
	if motion.is_empty():
		motions.erase(actor_key)
	else:
		motions[actor_key] = motion
	if motions.is_empty():
		presentation.erase(key)
	else:
		presentation[key] = motions

static func finish(host: Node) -> void:
	var enemy: Dictionary = dragon(host.get("_combat_state") as Dictionary)
	if not enemy.is_empty():
		_write_motion(host, enemy, {})
		host.call("_refresh_stage_view")

static func play(host: Node) -> void:
	var enemy: Dictionary = dragon(host.get("_combat_state") as Dictionary)
	if enemy.is_empty():
		return
	var run_state: Dictionary = host.get("_run_state")
	var room: Dictionary = host.get("_run_engine").room_metadata(run_state, run_state.get("current_room", Vector2i.ZERO))
	var theme: Dictionary = Music.entry_for_context("combat", room, host.get("_combat_state"), false)
	# The old track fades over the hold; the theme starts from silence on the roar.
	host.call("_transition_music", theme, HOLD_SECONDS, MUSIC_FADE_IN_SECONDS)
	# Process delta shares the game clock with timers, rumble and movie capture.
	var elapsed: float = 0.0
	var cue_played: bool = false
	while is_instance_valid(host) and host.is_inside_tree():
		if not bool(host.call("_card_fx_can_continue_combat")):
			break
		# Avoid a one-frame overshoot from summing fixed-fps decimal deltas.
		var finished: bool = elapsed >= CLIP_SECONDS - TIME_EPSILON_SECONDS
		_write_motion(host, enemy, opening_motion(host.get("_combat_state"), enemy, 1.0 if finished else elapsed / CLIP_SECONDS))
		host.call("_refresh_stage_view")
		if not cue_played and elapsed >= HOLD_SECONDS - TIME_EPSILON_SECONDS:
			cue_played = true
			host.call("_ensure_sfx_bank")
			host.get("_sfx_router").call("dragon_arrival", "enemy_%d" % int(enemy.get("id", -1)))
			if not bool(host.call("_reduced_motion_enabled")):
				host.get("board_view").call("rumble", RUMBLE_PX, RUMBLE_SECONDS, RUMBLE_OSCILLATIONS)
		if finished:
			break
		await host.get_tree().process_frame
		if is_instance_valid(host) and host.is_inside_tree() and host.can_process():
			elapsed += host.get_process_delta_time()
	if is_instance_valid(host) and host.is_inside_tree():
		# Clear the original actor even if a cancelled opening changed combat state.
		_write_motion(host, enemy, {})
		host.call("_refresh_stage_view")
