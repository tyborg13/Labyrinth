extends RefCounted

## A dragon fight opens on the dragon's roar. The fight-preview music fades out
## while the room comes into view, the dragon roars once, the board shudders
## under it, and the dragon's theme rises out of the roar. Then the objective
## and the hand arrive as usual. The roar is the dragon's first of the fight,
## so its first action does not repeat it; big area attacks still roar.
## Presentation only: no combat state, no RNG, no save data.
const Dragon = preload("res://scripts/dragon_presentation.gd")
const Guardians = preload("res://scripts/guardian_library.gd")
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
# Guardian challenge timings are independent of the unchanged dragon opening.
const GuardianMotion = preload("res://scripts/guardian_cutout/motion.gd")
const Maquette = preload("res://scripts/maquette_cutout_runtime/presentation.gd")
const GUARDIAN_DURATION_SCALE: float = 0.6
const GUARDIAN_HOLD_SECONDS: float = GuardianMotion.CHALLENGE_CUE_SECONDS
const GUARDIAN_CLIP_SECONDS: float = GuardianMotion.CHALLENGE_SECONDS
const GUARDIAN_CARRY_SECONDS: float = GUARDIAN_CLIP_SECONDS - GUARDIAN_HOLD_SECONDS
const GUARDIAN_RUMBLE_SCALE: float = 0.5
const GUARDIAN_CUE: String = "step.enemy.heavy"

static func dragon(state: Dictionary) -> Dictionary:
	for enemy: Variant in state.get("enemies", []):
		if enemy is Dictionary and Dragon.TYPES.has(str((enemy as Dictionary).get("type", ""))):
			return enemy
	return {}

# Room identity matters: an ordinary Craghide or a guardian helper never owns
# this beat. Resolve the living encounter Guardian from the shared registry.
static func guardian(state: Dictionary) -> Dictionary:
	if str(state.get("room_type", "")) != "guardian": return {}
	var id: String = str(state.get("guardian_id", ""))
	if Guardians.for_guardian(id).is_empty(): return {}
	for enemy: Variant in state.get("enemies", []):
		if enemy is Dictionary and str(enemy.get("type", "")) == id and int(enemy.get("hp", 0)) > 0:
			return enemy
	return {}

# Called before the opening's first board submission, including its layout wait.
static func prepare(host: Node) -> void:
	var state: Dictionary = host.get("_combat_state")
	var enemy: Dictionary = dragon(state)
	if enemy.is_empty(): enemy = guardian(state)
	if not enemy.is_empty():
		_write_motion(host, enemy, opening_motion(state, enemy, 0.0))

static func opening_motion(state: Dictionary, enemy: Dictionary, phase: float) -> Dictionary:
	var origin: Vector2i = enemy.get("pos", Vector2i.ZERO)
	var footprint: Vector2i = enemy.get("footprint", Vector2i(2, 2))
	var player: Vector2i = (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	# Screen x is board x - y. Compare centers, including the dragon's footprint.
	var center: Vector2i = origin * 2 + footprint - Vector2i.ONE
	var hero_is_left: bool = (player.x - player.y) * 2 < center.x - center.y
	return {"clip": "challenge" if not Guardians.for_guardian(str(enemy.get("type", ""))).is_empty() else "roar", "phase": clampf(phase, 0.0, 1.0),
		"direction": Vector2i(0, 1) if hero_is_left else Vector2i(1, 0)}

static func _write_motion(host: Node, enemy: Dictionary, motion: Dictionary) -> void:
	var presentation: Dictionary = host.get("_board_presentation")
	var key: String = _motion_key(str(enemy["type"]))
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

static func _motion_key(type: String) -> String:
	return "guardian_motion" if not Guardians.for_guardian(type).is_empty() and not Maquette.handles(type) else type + "_motion"

static func finish(host: Node) -> void:
	var state: Dictionary = host.get("_combat_state")
	var enemy: Dictionary = dragon(state)
	if not enemy.is_empty():
		_write_motion(host, enemy, {})
	# A cancelled pre-layout opening may already have replaced its combat state.
	# Only erase our challenge entries; concurrent walk/attack descriptors survive.
	var presentation: Dictionary = host.get("_board_presentation")
	var cleared_challenge: bool = false
	for channel: String in ["guardian_motion", "ashen_reaver_motion", "storm_cantor_motion", "last_lamplighter_motion"]:
		var motions: Dictionary = (presentation.get(channel, {}) as Dictionary).duplicate(false)
		for key: String in motions.keys():
			if str((motions[key] as Dictionary).get("clip", "")) == "challenge":
				motions.erase(key)
				cleared_challenge = true
		if motions.is_empty(): presentation.erase(channel)
		else: presentation[channel] = motions
	if not enemy.is_empty() or cleared_challenge: host.call("_refresh_stage_view")

static func play(host: Node) -> void:
	var state: Dictionary = host.get("_combat_state")
	var enemy: Dictionary = dragon(state)
	var is_guardian: bool = enemy.is_empty()
	if is_guardian:
		enemy = guardian(state)
	if enemy.is_empty(): return
	var duration_scale: float = GUARDIAN_DURATION_SCALE if is_guardian else 1.0
	var hold_seconds: float = GUARDIAN_HOLD_SECONDS if is_guardian else HOLD_SECONDS
	var clip_seconds: float = GUARDIAN_CLIP_SECONDS if is_guardian else CLIP_SECONDS
	var run_state: Dictionary = host.get("_run_state")
	var room: Dictionary = host.get("_run_engine").room_metadata(run_state, run_state.get("current_room", Vector2i.ZERO))
	var theme: Dictionary = Music.entry_for_context("combat", room, host.get("_combat_state"), false)
	# The old track fades over the hold; the theme starts from silence on the roar.
	host.call("_transition_music", theme, hold_seconds, MUSIC_FADE_IN_SECONDS * duration_scale)
	# Process delta shares the game clock with timers, rumble and movie capture.
	var elapsed: float = 0.0
	var cue_played: bool = false
	while is_instance_valid(host) and host.is_inside_tree():
		if not bool(host.call("_card_fx_can_continue_combat")):
			break
		# Avoid a one-frame overshoot from summing fixed-fps decimal deltas.
		var finished: bool = elapsed >= clip_seconds - TIME_EPSILON_SECONDS
		_write_motion(host, enemy, opening_motion(host.get("_combat_state"), enemy, 1.0 if finished else elapsed / clip_seconds))
		host.call("_refresh_stage_view")
		if not cue_played and elapsed >= hold_seconds - TIME_EPSILON_SECONDS:
			cue_played = true
			host.call("_ensure_sfx_bank")
			if is_guardian:
				host.get("_sfx_router").call("request", GUARDIAN_CUE)
			else:
				host.get("_sfx_router").call("dragon_arrival", "enemy_%d" % int(enemy.get("id", -1)))
			if not bool(host.call("_reduced_motion_enabled")):
				var amplitude: float = RUMBLE_PX * (GUARDIAN_RUMBLE_SCALE if is_guardian else 1.0)
				host.get("board_view").call("rumble", amplitude, RUMBLE_SECONDS * duration_scale, RUMBLE_OSCILLATIONS)
		if finished:
			break
		await host.get_tree().process_frame
		if is_instance_valid(host) and host.is_inside_tree() and host.can_process():
			elapsed += host.get_process_delta_time()
	if is_instance_valid(host) and host.is_inside_tree():
		# Clear the original actor even if a cancelled opening changed combat state.
		_write_motion(host, enemy, {})
		host.call("_refresh_stage_view")
