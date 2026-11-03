extends RefCounted

const Glossary = preload("res://scripts/glossary.gd")

const Rules = preload("res://scripts/enemy_mechanics/death_burst.gd")
const Data = preload("res://scripts/game_data.gd")
const BURST_ICON: String = "burst"
const BURST_CHAIN_SECONDS: float = 0.18
const FIRE: Color = Color("e8722c")
const TileGlow = preload("res://scripts/tile_glow.gd")
const Fx = preload("res://scripts/enemy_mechanics/burst_fx.gd")
const EMPTY_EFFECTS: Array = []
const PREVIEW_CENTRE_ALPHA: float = 0.34
const PREVIEW_CORNER_ALPHA: float = 0.08
# Existing generic dissolve duration, used by standalone preview/proof callers.
const FALLBACK_DEATH_SECONDS: float = 0.975
const FALLBACK_FRAME_SECONDS: float = 0.065
const TIME_BOUNDARY_EPSILON: float = 0.000001

static func badges(unit: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if int(unit.get("hp", 0)) > 0 and Data.enemies().get(str(unit.get("type", "")), {}).has("death_burst"):
		var amount: int = Rules.damage(unit)
		result.append({"status_class": "trait", "icon": BURST_ICON, "count": amount, "icon_tint": Color.WHITE, "fill": FIRE, "border": FIRE,
			"tooltip": Glossary.name_for("burst") + "\n" + Glossary.definition("burst") + "\n%d damage" % amount})
	return result

static func trait_token(unit: Dictionary) -> Dictionary:
	if not Data.enemies().get(str(unit.get("type", "")), {}).has("death_burst"): return {}
	var amount: int = Rules.damage(unit)
	var token: Dictionary = preload("res://scripts/action_icon_library.gd").icon_text_token(BURST_ICON, "Bursts %d" % amount, "When it dies, it hits every unit next to it for %d and leaves Fire." % amount)
	token["burst_trait"] = true
	return token

static func focused_tiles(view: Control) -> Array[Vector2i]:
	var result: Array[Vector2i]
	var focus: Vector2i = view._controller_focus_tile if view._controller_focus_tile.x >= 0 else view._hover_tile
	for enemy: Dictionary in view.combat_state.get("enemies", []):
		# This is a presence check. Fixed-point scaling/deep-copying every enemy's
		# complete intent catalog on every board tile dominated overlay drawing.
		if int(enemy.get("hp", 0)) <= 0 or not Data.enemies().get(str(enemy.get("type", "")), {}).has("death_burst") or not view._board_tile_is_visible_to_player(enemy.get("pos", Vector2i(-1, -1))): continue
		var key: String = "enemy_%d" % int(enemy["id"])
		if enemy.get("pos") != focus and not bool((view._damage_preview_map().get(key, {}) as Dictionary).get("lethal", false)): continue
		for tile: Vector2i in Rules.tiles(view.combat_state, enemy):
			if not result.has(tile): result.append(tile)
	return result

static func draw_preview(view: Control, tile: Vector2i, draw_tiles: Variant = null) -> void:
	if not (focused_tiles(view) if draw_tiles == null else draw_tiles).has(tile): return
	TileGlow.draw(view, view._tile_polygon(tile), FIRE, PREVIEW_CENTRE_ALPHA, PREVIEW_CORNER_ALPHA)

# Each FIFO event starts after its source dissolve begins. Chain starts are
# spaced by the director's 0.18 s, independently of dissolve duration/frame rate.
static func timing(before: Dictionary, after: Dictionary, frames: int, seconds: float, scene: Node = null, units: Array[Dictionary] = []) -> Dictionary:
	var count: int = (after.get("death_burst_events", []) as Array).size() - (before.get("death_burst_events", []) as Array).size()
	var death_seconds: float = float(frames - 1) * seconds
	var frame_seconds: float = seconds
	if count > 0:
		# Sample every chain boundary exactly; preserve individual dissolve duration.
		frame_seconds = BURST_CHAIN_SECONDS / ceilf(BURST_CHAIN_SECONDS / seconds)
		frames = ceili((death_seconds + float(count - 1) * BURST_CHAIN_SECONDS) / frame_seconds) + 1
	var death_frames: Dictionary = {}
	var death_delays: Dictionary = {}
	if count > 0 and scene != null:
		for unit: Dictionary in units:
			death_frames[str(unit.get("key", ""))] = scene._enemy_death_frame_count_for_unit(unit)
			death_delays[str(unit.get("key", ""))] = death_delay(unit, before, after, frame_seconds)
	return {"death_frames": death_frames, "death_delays": death_delays, "frames": frames, "frame_seconds": frame_seconds, "duration": float(frames - 1) * frame_seconds, "death_seconds": death_seconds, "first_start": frame_seconds, "burst_count": count, "burst_chain_seconds": BURST_CHAIN_SECONDS}

static func death_delay(unit: Dictionary, before: Dictionary, after: Dictionary, first_start: float) -> float:
	var baseline: int = (before.get("death_burst_events", []) as Array).size()
	var events: Array = after.get("death_burst_events", [])
	var delay: float = 0.0
	for index: int in range(baseline, events.size()):
		var snapshot: Dictionary = events[index]["before"]
		var was_alive: bool = int(snapshot.get("player", {}).get("hp", 0)) > 0 if str(unit.get("role", "")) == "player" else false
		for enemy: Dictionary in snapshot.get("enemies", []):
			if str(unit.get("role", "")) != "player" and int(enemy.get("id", -1)) == int(unit.get("id", -2)): was_alive = int(enemy.get("hp", 0)) > 0
		if not was_alive: break
		delay = first_start + float(index - baseline) * BURST_CHAIN_SECONDS
	return delay

static func event_slot(before: Dictionary, after: Dictionary, progress: float, clock: Dictionary = {}) -> int:
	var count: int = (after.get("death_burst_events", []) as Array).size() - (before.get("death_burst_events", []) as Array).size()
	if count <= 0: return -1
	var elapsed: float = elapsed_seconds(progress, count, clock)
	var first: float = float(clock.get("first_start", FALLBACK_FRAME_SECONDS))
	if elapsed + TIME_BOUNDARY_EPSILON < first: return -1
	return mini(count - 1, int(floor((elapsed - first) / BURST_CHAIN_SECONDS + TIME_BOUNDARY_EPSILON)))

static func elapsed_seconds(progress: float, count: int, clock: Dictionary) -> float:
	return progress * float(clock.get("duration", FALLBACK_DEATH_SECONDS + float(maxi(0, count - 1)) * BURST_CHAIN_SECONDS))

static func decorate(before: Dictionary, after: Dictionary, presentation: Dictionary, progress: float, clock: Dictionary = {}, scene: Node = null) -> Dictionary:
	var baseline: int = (before.get("death_burst_events", []) as Array).size()
	var events: Array = after.get("death_burst_events", [])
	if events.size() <= baseline: return presentation
	var slot: int = event_slot(before, after, progress, clock)
	presentation["burst_playback_count"] = baseline + slot + 1
	var elapsed: float = elapsed_seconds(progress, events.size() - baseline, clock)
	if slot >= 0:
		presentation["en01_burst"] = events[baseline + slot]
		presentation["en01_burst_progress"] = progress
	var effects: Array[Dictionary]
	for index: int in range(baseline, events.size()):
		var age: float = elapsed - float(clock.get("first_start", FALLBACK_FRAME_SECONDS)) - float(index - baseline) * BURST_CHAIN_SECONDS
		if age < 0.0 or age >= Fx.GLOW_SECONDS: continue
		var effect: Dictionary = events[index].duplicate(false)
		effect["elapsed"] = age
		effects.append(effect)
	presentation["burst_effects"] = effects
	if scene != null:
		var texts: Array[Dictionary]
		for index: int in range(baseline, events.size()):
			var age: float = elapsed - float(clock.get("first_start", FALLBACK_FRAME_SECONDS)) - float(index - baseline) * BURST_CHAIN_SECONDS
			if age < 0.0: continue
			var base: Array = scene._burst_playback.floating_texts(scene, events[index])
			if age < preload("res://scripts/floating_combat_text.gd").total_duration(base):
				texts.append_array(preload("res://scripts/floating_combat_text.gd").animate_entries(base, age, scene._reduced_motion_enabled()))
		# These labels ride the existing dissolve clock. Submitting them as new
		# combat-feel hits would add hit-stop waits and change Burst timing.
		presentation["burst_floating_texts"] = texts
	var frame_state: Dictionary = state_for_frame(before, after, progress, clock)
	var visible_deaths: Array[Dictionary]
	for unit: Dictionary in presentation.get("death_animation_units", []):
		var live: bool = false
		var delay: float = death_delay(unit, before, after, float(clock.get("first_start", FALLBACK_FRAME_SECONDS)))
		if str(unit.get("role", "")) == "player": live = int(frame_state.get("player", {}).get("hp", 0)) > 0
		else:
			for enemy: Dictionary in frame_state.get("enemies", []):
				if int(enemy.get("id", -1)) == int(unit.get("id", -2)): live = int(enemy.get("hp", 0)) > 0
		if live: continue
		var shown: Dictionary = unit.duplicate(true)
		shown["death_progress"] = clampf((elapsed - delay) / maxf(0.01, float(clock.get("death_seconds", FALLBACK_DEATH_SECONDS))), 0.0, 1.0)
		var frames: int = int(clock.get("death_frames", {}).get(str(unit.get("key", "")), 16))
		shown["death_frame"] = int(round(float(shown["death_progress"]) * float(maxi(0, frames - 1))))
		preload("res://scripts/maquette_cutout_runtime/death_sequence.gd").sample(shown, elapsed - delay, clock)
		visible_deaths.append(shown)
	presentation["death_animation_units"] = visible_deaths
	return presentation

static func state_for_frame(before: Dictionary, after: Dictionary, progress: float, clock: Dictionary = {}) -> Dictionary:
	var baseline: int = (before.get("death_burst_events", []) as Array).size()
	var events: Array = after.get("death_burst_events", [])
	if events.size() <= baseline: return after
	var frame: Dictionary = after.duplicate(true)
	var slot: int = event_slot(before, after, progress, clock)
	var snapshot: Dictionary = events[baseline]["before"] if slot < 0 else events[baseline + slot]["after"]
	frame.merge(snapshot.duplicate(true), true)
	return frame

static func play_cue(scene: Node, before: Dictionary, after: Dictionary, progress: float, clock: Dictionary = {}) -> void:
	var slot: int = event_slot(before, after, progress, clock)
	if slot < 0:
		scene.set_meta("en01_last_burst_cue", -1)
		return
	if int(scene.get_meta("en01_last_burst_cue", -1)) == slot: return
	scene.set_meta("en01_last_burst_cue", slot)
	scene._play_sfx(preload("res://scripts/attack_sfx_library.gd").entry_for_enemy_action({"type": "aoe", "element": "fire"}))

# Called in the floor pass; overlapping chain events retain their own age.
static func draw_glows(view: Control, tile: Vector2i) -> void:
	for effect: Dictionary in view.presentation.get("burst_effects", EMPTY_EFFECTS):
		if not (effect.get("tiles", EMPTY_EFFECTS) as Array).has(tile): continue
		var alpha: float = Fx.glow_alpha(float(effect["elapsed"]))
		if alpha > 0.0: TileGlow.draw(view, view._tile_polygon(tile), FIRE, alpha, Fx.GLOW_CORNER_ALPHA * alpha / Fx.GLOW_PEAK_ALPHA)

static func draw_flames(view: Control) -> void:
	if bool(view.presentation.get("reduced_motion", false)): return
	for effect: Dictionary in view.presentation.get("burst_effects", EMPTY_EFFECTS):
		if effect["tile"].x < 0 or not view._board_tile_is_visible_to_player(effect["tile"]): continue
		Fx.draw(view, effect)
