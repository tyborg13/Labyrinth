extends RefCounted

const Glossary = preload("res://scripts/glossary.gd")

const Rules = preload("res://scripts/enemy_mechanics/death_burst.gd")
const Data = preload("res://scripts/game_data.gd")
const BURST_ICON: String = "burst"
const BURST_CHAIN_SECONDS: float = 0.18
const BURST_RING_WIDTH: float = 2.0
const BURST_RING_DASH: float = 8.0
const BURST_RING_GAP: float = 6.0
const FIRE: Color = Color("e8722c")
const BURST_RING_ALPHA: float = 0.85
# Existing generic dissolve duration, used by standalone preview/proof callers.
const FALLBACK_DEATH_SECONDS: float = 0.975
const FALLBACK_FRAME_SECONDS: float = 0.065
const TIME_BOUNDARY_EPSILON: float = 0.000001

static func badges(unit: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if int(unit.get("hp", 0)) > 0 and Data.enemy_def(str(unit.get("type", ""))).has("death_burst"):
		var amount: int = Rules.damage(unit)
		result.append({"icon": BURST_ICON, "count": amount, "icon_tint": Color.WHITE, "fill": FIRE, "border": FIRE,
			"tooltip": Glossary.name_for("burst") + "\n" + Glossary.definition("burst") + "\n%d damage" % amount})
	return result

static func pre_battle_summary(enemy_type: String, fallback: String) -> String:
	if enemy_type == "burrow_grub": return "Burrow / Erupt / Melee"
	if enemy_type == "ember_tick": return "Bursts 4 / Kindle / Melee"
	return fallback

static func focused_tiles(view: Control) -> Array[Vector2i]:
	var result: Array[Vector2i]
	var focus: Vector2i = view._controller_focus_tile if view._controller_focus_tile.x >= 0 else view._hover_tile
	for enemy: Dictionary in view.combat_state.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0 or not Data.enemy_def(str(enemy.get("type", ""))).has("death_burst") or not view._board_tile_is_visible_to_player(enemy.get("pos", Vector2i(-1, -1))): continue
		var key: String = "enemy_%d" % int(enemy["id"])
		if enemy.get("pos") != focus and not bool((view._damage_preview_map().get(key, {}) as Dictionary).get("lethal", false)): continue
		for tile: Vector2i in Rules.tiles(view.combat_state, enemy):
			if not result.has(tile): result.append(tile)
	return result

static func draw_ring(view: Control, tile: Vector2i) -> void:
	if not focused_tiles(view).has(tile): return
	# Reuse the existing collision marker's dashed geometry and fire tint.
	var points: PackedVector2Array = view._tile_polygon(tile)
	for index: int in range(points.size()):
		var start: Vector2 = points[index]
		var finish: Vector2 = points[(index + 1) % points.size()]
		var length: float = start.distance_to(finish)
		var direction: Vector2 = start.direction_to(finish)
		var distance: float = 0.0
		while distance < length:
			view.draw_line(start + direction * distance, start + direction * minf(length, distance + BURST_RING_DASH), Color(FIRE, BURST_RING_ALPHA), BURST_RING_WIDTH)
			distance += BURST_RING_DASH + BURST_RING_GAP

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
	if count > 0 and scene != null:
		for unit: Dictionary in units: death_frames[str(unit.get("key", ""))] = scene._enemy_death_frame_count_for_unit(unit)
	return {"death_frames": death_frames, "frames": frames, "frame_seconds": frame_seconds, "duration": float(frames - 1) * frame_seconds, "death_seconds": death_seconds, "first_start": frame_seconds}

static func event_slot(before: Dictionary, after: Dictionary, progress: float, clock: Dictionary = {}) -> int:
	var count: int = (after.get("death_burst_events", []) as Array).size() - (before.get("death_burst_events", []) as Array).size()
	if count <= 0: return -1
	var elapsed: float = elapsed_seconds(progress, count, clock)
	var first: float = float(clock.get("first_start", FALLBACK_FRAME_SECONDS))
	if elapsed + TIME_BOUNDARY_EPSILON < first: return -1
	return mini(count - 1, int(floor((elapsed - first) / BURST_CHAIN_SECONDS + TIME_BOUNDARY_EPSILON)))

static func elapsed_seconds(progress: float, count: int, clock: Dictionary) -> float:
	return progress * float(clock.get("duration", FALLBACK_DEATH_SECONDS + float(maxi(0, count - 1)) * BURST_CHAIN_SECONDS))

static func decorate(before: Dictionary, after: Dictionary, presentation: Dictionary, progress: float, clock: Dictionary = {}) -> Dictionary:
	var baseline: int = (before.get("death_burst_events", []) as Array).size()
	var events: Array = after.get("death_burst_events", [])
	if events.size() <= baseline: return presentation
	var slot: int = event_slot(before, after, progress, clock)
	var elapsed: float = elapsed_seconds(progress, events.size() - baseline, clock)
	if slot >= 0:
		presentation["en01_burst"] = events[baseline + slot]
		presentation["en01_burst_progress"] = progress
	var frame_state: Dictionary = state_for_frame(before, after, progress, clock)
	var visible_deaths: Array[Dictionary]
	for unit: Dictionary in presentation.get("death_animation_units", []):
		var live: bool = false
		var delay: float = 0.0
		for index: int in range(baseline, events.size()):
			var snapshot: Dictionary = events[index]["before"]
			var was_alive: bool = int(snapshot.get("player", {}).get("hp", 0)) > 0 if str(unit.get("role", "")) == "player" else false
			for enemy: Dictionary in snapshot.get("enemies", []):
				if str(unit.get("role", "")) != "player" and int(enemy.get("id", -1)) == int(unit.get("id", -2)): was_alive = int(enemy.get("hp", 0)) > 0
			if not was_alive: break
			delay = float(clock.get("first_start", FALLBACK_FRAME_SECONDS)) + float(index - baseline) * BURST_CHAIN_SECONDS
		if str(unit.get("role", "")) == "player": live = int(frame_state.get("player", {}).get("hp", 0)) > 0
		else:
			for enemy: Dictionary in frame_state.get("enemies", []):
				if int(enemy.get("id", -1)) == int(unit.get("id", -2)): live = int(enemy.get("hp", 0)) > 0
		if live: continue
		var shown: Dictionary = unit.duplicate(true)
		shown["death_progress"] = clampf((elapsed - delay) / maxf(0.01, float(clock.get("death_seconds", FALLBACK_DEATH_SECONDS))), 0.0, 1.0)
		var frames: int = int(clock.get("death_frames", {}).get(str(unit.get("key", "")), 16))
		shown["death_frame"] = int(round(float(shown["death_progress"]) * float(maxi(0, frames - 1))))
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

static func draw_resolution(view: Control) -> void:
	var event: Dictionary = view.presentation.get("en01_burst", {})
	if event.is_empty(): return
	for tile: Vector2i in event.get("tiles", []):
		if view._board_tile_is_visible_to_player(tile): view._draw_tile_ring(tile, FIRE, 3.2, 0.80)
