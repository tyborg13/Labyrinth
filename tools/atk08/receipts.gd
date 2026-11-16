extends "res://tools/run_hunt.gd"
## atk-08 hit receipts (proof tool; not a test, never in default test groups).
## A seeded run-hunt (the atk-01 seeds and route) plays real fights through the
## production RunScene playback at a chosen combat speed and reduced-motion
## setting. For every hero Health/Block/Stoneskin loss it writes the truth (from
## the engine states each real playback call receives) and, separately, what the
## presentation layer actually drew: every damage number the board's effects
## layer laid out at the hero, the health-ghost tracker, the rail, the banner and
## the animating actors. Classification happens in tools/atk08/receipts.py.
## Nothing here writes game state.
##   ATK08_SPEED=normal|fast|fastest  ATK08_REDUCED=0|1  ATK08_TIME_SCALE=<float>
# The production RunScene source, unchanged, plus observation hooks: each hooked
# function is renamed _atk08_base_<name> and a wrapper with the original name
# tells the recorder, then awaits the production body. A copy of the same
# script (not a subclass) keeps get_script_constant_map() complete for the
# helpers that read the host's constants. Nested calls (hidden Umbra spans,
# Stalker strikes) record only at the outermost level.
const HOOKED: Array = ["_resolve_enemy_round", "_animate_enemy_phase_steps", "_animate_fatigue_damage", "_animate_turn_start_fire", "_animate_player_action_step", "_set_turn_order_bar_entries", "_animate_turn_order_transition"]
const HOOKS: String = """

var receipt: Object = null
var _atk08_slice_depth: int = 0

func _resolve_enemy_round(end_reason: String = "auto") -> void:
	if receipt != null: receipt.call("on_round_begin", self)
	await _atk08_base_resolve_enemy_round(end_reason)
	if receipt != null: receipt.call("on_round_end", self)

func _animate_enemy_phase_steps(animated_state: Dictionary, steps: Array, resolved_state: Dictionary = {}) -> void:
	_atk08_slice_depth += 1
	var outer: bool = _atk08_slice_depth == 1
	if outer and receipt != null: receipt.call("on_slice_begin", self, animated_state, steps, resolved_state)
	await _atk08_base_animate_enemy_phase_steps(animated_state, steps, resolved_state)
	if outer and receipt != null: receipt.call("on_slice_end", self, animated_state, steps, resolved_state)
	_atk08_slice_depth -= 1

func _animate_fatigue_damage(display_state: Dictionary, fatigue_events: Array[Dictionary]) -> void:
	if receipt != null: receipt.call("on_beat_begin", self, "fatigue", fatigue_events.size())
	await _atk08_base_animate_fatigue_damage(display_state, fatigue_events)
	if receipt != null: receipt.call("on_beat_end", self, "fatigue")

func _animate_turn_start_fire(display_state: Dictionary, burn: Dictionary) -> void:
	if receipt != null: receipt.call("on_beat_begin", self, "fire", int(burn.get("health_lost", 0)))
	await _atk08_base_animate_turn_start_fire(display_state, burn)
	if receipt != null: receipt.call("on_beat_end", self, "fire")

func _animate_player_action_step(before_state: Dictionary, after_state: Dictionary, card_id: String, action: Dictionary, target_tile: Vector2i, chain_hits: Array = []) -> void:
	if receipt != null: receipt.call("on_action_step", self, card_id, str(action.get("type", "")))
	await _atk08_base_animate_player_action_step(before_state, after_state, card_id, action, target_tile, chain_hits)

func _set_turn_order_bar_entries(entries: Array[Dictionary]) -> void:
	_atk08_base_set_turn_order_bar_entries(entries)
	if receipt != null: receipt.call("on_rail_set", self, entries)

func _animate_turn_order_transition(before_order: Array[Dictionary], after_order: Array[Dictionary], defeated_actor_keys: Dictionary = {}) -> void:
	if receipt != null: receipt.call("on_rail_transition", self, before_order, after_order, "begin")
	await _atk08_base_animate_turn_order_transition(before_order, after_order, defeated_actor_keys)
	if receipt != null: receipt.call("on_rail_transition", self, before_order, after_order, "end")
"""
# Hooked only where the scene has them (atk-10: the late-number clock offset).
const HOOKED_OPTIONAL: Array = ["_carry_floating_text_birth"]
const HOOKS_OPTIONAL: Dictionary = {"_carry_floating_text_birth": """

func _carry_floating_text_birth(presentation: Dictionary, birth: Dictionary) -> void:
	_atk08_base_carry_floating_text_birth(presentation, birth)
	if receipt != null and presentation.has("floating_text_delay_seconds"): receipt.call("on_text_delay", self, float(presentation["floating_text_delay_seconds"]))
"""}
static var _hooked_script: GDScript = null

static func hooked_scene_script() -> GDScript:
	if _hooked_script != null: return _hooked_script
	var source: String = FileAccess.get_file_as_string("res://scripts/run_scene.gd")
	for name: String in HOOKED:
		var head: String = "\nfunc %s(" % name
		if source.count(head) != 1:
			push_error("atk08 receipts: cannot hook %s" % name)
			return null
		source = source.replace(head, "\nfunc _atk08_base%s(" % name)
	var hooks: String = HOOKS
	for name: String in HOOKED_OPTIONAL:
		var head: String = "\nfunc %s(" % name
		if source.count(head) != 1: continue
		source = source.replace(head, "\nfunc _atk08_base%s(" % name)
		hooks += str(HOOKS_OPTIONAL[name])
	var script := GDScript.new()
	script.source_code = source + hooks
	if script.reload() != OK:
		push_error("atk08 receipts: hooked RunScene failed to compile")
		return null
	_hooked_script = script
	return script
const BleedReceipts = preload("res://scripts/status_tick_receipts.gd")
const INVALID := Vector2i(-1, -1)
const OVERLAP_MIN_FRACTION: float = 0.15
const OCCLUDER_MIN_FRACTION: float = 0.10

# Optional ATK08_PREFER=<card ids>: play these cards whenever the hand offers
# them (self-inflicted card costs, which the default route rarely plays). Every
# other choice stays the hunt policy's own; the route then differs from atk-01's.
# With ATK08_EMPOWER=1 it also Empowers a selected card (the scene's keyboard
# Empower input) once, to cover Empower Health costs.
class PreferPolicy extends "res://tools/run_hunt_policy.gd":
	var prefer: PackedStringArray = []
	var empower: bool = false
	func choose(scene: Node, candidates: Array) -> Dictionary:
		if empower and int(scene.get("_selected_card_index")) >= 0 and bool(scene.call("_empower_toggle_available")) and not bool(scene.call("_selected_card_empowered")):
			return {"kind": "empower", "method": "_toggle_pending_empower", "args": ["keyboard"]}
		for candidate: Dictionary in candidates:
			if str(candidate.get("kind", "")) == "card" and prefer.has(str(candidate.get("card_id", ""))): return candidate
		return super.choose(scene, candidates)
var prefer_cards: PackedStringArray = OS.get_environment("ATK08_PREFER").split(",", false)
var prefer_empower: bool = OS.get_environment("ATK08_EMPOWER") == "1"

var speed: String = OS.get_environment("ATK08_SPEED") if not OS.get_environment("ATK08_SPEED").is_empty() else "normal"
var reduced: bool = OS.get_environment("ATK08_REDUCED") == "1"
var time_scale: float = float(OS.get_environment("ATK08_TIME_SCALE")) if not OS.get_environment("ATK08_TIME_SCALE").is_empty() else 4.0
var receipts: FileAccess
var frame_index: int = 0
var last_clock: int = -1
var popups: Dictionary = {}
var tracks: Dictionary = {}
var in_round: bool = false
var round_index: int = 0
var round_t0: int = 0
var round_counts: Dictionary = {}
var round_frame0: int = 0
var round_begin_state: Dictionary = {}
var round_begin_enemy_ids: Dictionary = {}
var slice_prev: Dictionary = {}
var slice_ctx: Dictionary = {}
var pending_beats: Dictionary = {}
var beat_windows: Dictionary = {}
var hero_baseline: Dictionary = {}
var hero_actions: Array = []
var loss_count: int = 0
var popup_count: int = 0
# Real saves for native frame strips: the run saved at the last idle combat
# decision (production persistence path), plus the decisions replayed since.
# ATK08_REPRO_PER_CATEGORY raises the cap (atk-10: a save before every foe hit).
var REPRO_PER_CATEGORY: int = int(OS.get_environment("ATK08_REPRO_PER_CATEGORY")) if not OS.get_environment("ATK08_REPRO_PER_CATEGORY").is_empty() else 10
var anchor_decision: int = -1
var anchor_decisions: Array = []
var repro_counts: Dictionary = {}
# ATK08_REPRO_AT=<decision,...>: also keep the save at these clean decisions
# (with every decision replayed until the next clean one) for a native strip.
var repro_at: PackedStringArray = OS.get_environment("ATK08_REPRO_AT").split(",", false)
var forced_repro: String = ""

func _start() -> void:
	var settings: Dictionary = Settings.load_settings()
	settings["combat_speed"] = speed
	settings["reduced_motion"] = reduced
	Settings.save_settings(settings)
	Engine.time_scale = time_scale
	receipts = FileAccess.open(output.path_join("receipts.jsonl"), FileAccess.WRITE)
	_write({"kind": "config", "speed": speed, "reduced_motion": reduced, "time_scale": time_scale, "seed": hunt_seed, "health": hunt_health, "prefer": ",".join(prefer_cards)})
	await super._start()

func _enter_scene(resume: bool) -> void:
	if resume: root.set_meta("labyrinth_resume_saved_run", true)
	scene = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	var hooked: GDScript = hooked_scene_script()
	if hooked == null:
		_finish("hook_failure")
		return
	scene.set_script(hooked)
	scene.set("receipt", self)
	root.add_child(scene)
	current_scene = scene
	settle_frames = SETTLE_FRAMES

# The settings under test stay fixed for the whole run: the hunt's random
# Reduced Motion toggle still consumes its roll (same route), but is not pressed.
func _run_side(kind: String) -> void:
	if kind == "reduced_motion":
		busy = false
		return
	await super._run_side(kind)

func _record(action: Dictionary) -> void:
	super._record(action)
	if not is_instance_valid(scene) or str((scene.get("_run_state") as Dictionary).get("mode", "")) != "combat" or policy.browsing(scene): return
	var clean: bool = not bool(scene.get("_animation_lock")) and int(scene.get("_selected_card_index")) < 0 and not bool(scene.get("_player_movement_selected"))
	if clean:
		scene.call("_save_run_progress")
		var anchor: String = output.path_join("anchor")
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(anchor))
		for name: String in ["run.save", "progression.json"]:
			DirAccess.copy_absolute(ProjectSettings.globalize_path(output.path_join(name)), ProjectSettings.globalize_path(anchor.path_join(name)))
		var file := FileAccess.open(anchor.path_join("combat_state.txt"), FileAccess.WRITE)
		file.store_string(var_to_str(scene.get("_combat_state")))
		file.close()
		anchor_decision = decision
		anchor_decisions = []
		forced_repro = ""
		if repro_at.has(str(decision)):
			forced_repro = output.path_join("repro").path_join("%d-%d-forced" % [hunt_seed, decision])
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(forced_repro))
			for name: String in ["run.save", "progression.json", "combat_state.txt"]:
				DirAccess.copy_absolute(ProjectSettings.globalize_path(anchor.path_join(name)), ProjectSettings.globalize_path(forced_repro.path_join(name)))
	if anchor_decision < 0: return
	var replay: Dictionary = {}
	for field: String in ["kind", "method", "args", "tile", "card_id"]:
		if action.has(field): replay[field] = action[field]
	anchor_decisions.append(replay)
	for directory: String in [output.path_join("anchor"), forced_repro]:
		if directory.is_empty(): continue
		var replay_file := FileAccess.open(directory.path_join("decisions.txt"), FileAccess.WRITE)
		if replay_file != null:
			replay_file.store_string(var_to_str(anchor_decisions))
			replay_file.close()

func _persist_repro(row: Dictionary) -> void:
	if anchor_decision < 0: return
	var category: String = "%s:%s" % [str(row.get("category", "")), str(row.get("path", ""))]
	if int(repro_counts.get(category, 0)) >= REPRO_PER_CATEGORY: return
	var directory: String = output.path_join("repro").path_join("%d-%d" % [hunt_seed, anchor_decision])
	row["repro"] = directory
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory)): return
	repro_counts[category] = int(repro_counts.get(category, 0)) + 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	for name: String in ["run.save", "progression.json", "combat_state.txt"]:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(output.path_join("anchor").path_join(name)), ProjectSettings.globalize_path(directory.path_join(name)))
	var file := FileAccess.open(directory.path_join("decisions.txt"), FileAccess.WRITE)
	file.store_string(var_to_str(anchor_decisions))
	file.close()

func _tick() -> void:
	if policy != null and (not prefer_cards.is_empty() or prefer_empower) and not (policy is PreferPolicy):
		var replacement := PreferPolicy.new()
		replacement.rng = policy.rng
		replacement.no_embrace = policy.no_embrace
		replacement.prefer = prefer_cards
		replacement.empower = prefer_empower
		policy = replacement
	if not finished and is_instance_valid(scene) and scene.is_inside_tree() and not scene.is_queued_for_deletion():
		_sample()
	super._tick()

func _finish(outcome: String) -> void:
	if receipts != null:
		if is_instance_valid(scene) and not hero_baseline.is_empty() and not in_round and str((scene.get("_run_state") as Dictionary).get("mode", "")) == "combat":
			_emit_hero_window(scene.get("_combat_state"), last_clock)
		for key: String in popups.keys(): _finalize_popup(key, last_clock)
		_write({"kind": "totals", "losses": loss_count, "popups": popup_count, "frames": frame_index, "outcome": outcome, "frame_dt_ms_hist": tracks.get("dt_hist", {})})
		receipts.flush()
	await super._finish(outcome)

# --- per-frame observation ------------------------------------------------------

func _sample() -> void:
	frame_index += 1
	var run: Dictionary = scene.get("_run_state")
	if str(run.get("mode", "")) != "combat":
		for key: String in popups.keys(): _finalize_popup(key, last_clock)
		hero_baseline = {}
		return
	var pacing: Node = scene.get("_combat_pacing")
	var board: Control = scene.get("board_view")
	if pacing == null or board == null: return
	var layer: Control = board.get("_effects_render_layer")
	if not is_instance_valid(layer): return
	var now: int = _now()
	var dt: int = now - last_clock if last_clock >= 0 else 0
	last_clock = now
	if not in_round and not bool(scene.get("_animation_lock")): _hero_idle(now)
	var hero: Dictionary = (layer.get("combat_state") as Dictionary).get("player", {})
	var hero_tile: Vector2i = hero.get("pos", INVALID)
	var xform: Transform2D = layer.get_global_transform_with_canvas()
	_track_context(now, board, layer, pacing, hero_tile, xform)
	var drawn: Array[Dictionary]
	for popup: Dictionary in _drawn_layout(layer):
		var entry: Dictionary = popup.get("entry", {})
		var rect: Rect2 = popup.get("rendered_rect", Rect2())
		rect.position += popup.get("layout_offset", Vector2.ZERO) as Vector2
		var color: Color = entry.get("color", Color.WHITE)
		drawn.append({"key": str(popup.get("key", "")), "entry": entry, "rect": xform * rect, "tile": popup.get("tile", INVALID),
			"alpha": clampf(float(entry.get("alpha", 1.0)), 0.0, 1.0) * color.a, "progress": float(entry.get("animation_progress", -1.0))})
	var seen: Dictionary = {}
	for d: Dictionary in drawn:
		var entry: Dictionary = d["entry"]
		if str(entry.get("reaction_actor_key", "")) != "player" and d["tile"] != hero_tile: continue
		var key: String = d["key"]
		if seen.has(key):
			(popups[key] as Dictionary)["duplicates"] = int((popups[key] as Dictionary).get("duplicates", 0)) + 1
			continue
		seen[key] = true
		if not popups.has(key):
			popups[key] = _new_popup(d, now, hero_tile, layer, xform)
			(popups[key] as Dictionary)["first_dt"] = dt
		var record: Dictionary = popups[key]
		record["last_t"] = now
		record["last_frame"] = frame_index
		record["last_progress"] = d["progress"]
		record["frames"] = int(record["frames"]) + 1
		(record["samples"] as Array).append([roundi(float(now - int(record["first_t"])) / 1000.0), snappedf(float(d["progress"]), 0.01), snappedf(float(d["alpha"]), 0.01)])
		record["max_alpha"] = maxf(float(record["max_alpha"]), float(d["alpha"]))
		if float(d["alpha"]) >= 0.5:
			record["last_readable_t"] = now
			record["last_readable_progress"] = d["progress"]
			if int(record["first_readable_t"]) < 0: record["first_readable_t"] = now
		if not bool(record["mid_scanned"]) and float(d["progress"]) >= 0.35:
			record["mid_scanned"] = true
			record["occluders_mid"] = _occluders(d["rect"])
		if float(d["alpha"]) >= 0.3:
			for other: Dictionary in drawn:
				if other["key"] == key or float(other["alpha"]) < 0.3: continue
				var a: Rect2 = d["rect"]
				var b: Rect2 = other["rect"]
				var smaller: float = minf(a.get_area(), b.get_area())
				if smaller <= 0.0: continue
				var fraction: float = a.intersection(b).get_area() / smaller
				if fraction < OVERLAP_MIN_FRACTION: continue
				var overlaps: Dictionary = record["overlaps"]
				var other_entry: Dictionary = other["entry"]
				var previous: Dictionary = overlaps.get(other["key"], {})
				if fraction > float(previous.get("fraction", 0.0)):
					overlaps[other["key"]] = {"text": str(other_entry.get("text", "")), "tile": str(other["tile"]), "reaction": str(other_entry.get("reaction_actor_key", "")), "fraction": snappedf(fraction, 0.01), "t": now, "frames": int(previous.get("frames", 0)) + 1}
				else:
					previous["frames"] = int(previous.get("frames", 0)) + 1
	for key: String in popups.keys():
		if not seen.has(key): _finalize_popup(key, now)
	if dt > 0: _bump_track("dt_hist", str(mini(int(dt / 10000) * 10, 200)))

# The effects layer draws its numbers itself, or (while the board isolates a
# threat, which every animated submission requests) from the retained slice
# canvas whose ordered operations include _draw_floating_texts.
func _drawn_layout(layer: Control) -> Array:
	var result: Array = []
	var canvases: Array[Control]
	var sliced: bool = (layer.get("presentation") as Dictionary).has("isolated_enemy_actor_keys")
	if not sliced or _draws_floating(layer): canvases.append(layer)
	for child: Node in layer.get_children():
		if child is Control and bool(child.get("_is_layer_slice_canvas")) and _draws_floating(child as Control) and (child as Control).visible: canvases.append(child as Control)
	for canvas: Control in canvases:
		result.append_array(canvas.get("_floating_text_last_layout") as Array)
	return result

func _draws_floating(canvas: Control) -> bool:
	for operation: Variant in canvas.get("_render_slice_ops") as Array:
		if typeof(operation) == TYPE_ARRAY and not (operation as Array).is_empty() and str((operation as Array)[0]) == "_draw_floating_texts": return true
	return false

func _new_popup(d: Dictionary, now: int, hero_tile: Vector2i, layer: Control, xform: Transform2D) -> Dictionary:
	popup_count += 1
	var entry: Dictionary = d["entry"]
	var color: Color = entry.get("color", Color.WHITE)
	var hero_rect := Rect2()
	for unit: Dictionary in layer.call("_visible_units"):
		if str(unit.get("key", "")) == "player": hero_rect = xform * (layer.call("_unit_draw_rect", unit) as Rect2)
	var tracker: RefCounted = layer.get("health_ghost_tracker")
	var ghost: Dictionary = tracker.sample("player") if tracker != null else {}
	var board: Control = scene.get("board_view")
	return {"kind": "popup", "key": d["key"], "text": str(entry.get("text", "")), "popup_kind": str(entry.get("kind", "effect")), "color": color.to_html(false), "icon": str(entry.get("icon", "")),
		"reaction": str(entry.get("reaction_actor_key", "")), "tile": str(d["tile"]), "hero_tile": str(hero_tile), "at_hero": d["tile"] == hero_tile,
		"first_t": now, "first_frame": frame_index, "first_progress": d["progress"], "last_t": now, "last_frame": frame_index, "last_progress": d["progress"],
		"first_readable_t": -1, "last_readable_t": -1, "last_readable_progress": -1.0, "frames": 0, "max_alpha": 0.0, "sequence": int(entry.get("sequence_index", 0)),
		"rect": _rect_json(d["rect"]), "hero_rect": _rect_json(hero_rect), "overlaps": {}, "duplicates": 0, "samples": [],
		"occluders": _occluders(d["rect"]), "occluders_mid": [], "mid_scanned": false,
		"ghost_hp": float((ghost.get("ghost_range", Vector2.ZERO) as Vector2).x) if not ghost.is_empty() else -1.0,
		"ghost_top": float((ghost.get("ghost_range", Vector2.ZERO) as Vector2).y) if not ghost.is_empty() else -1.0,
		"plate_alpha": snappedf(float(board.get("plate_visibility").opacity("player")), 0.01) if board != null else -1.0,
		"modal": bool(scene.call("_controller_modal_visible")), "in_round": in_round, "round": round_index, "fight": _fight_id(), "turn": int((scene.get("_combat_state") as Dictionary).get("turn", 0))}

func _finalize_popup(key: String, now: int) -> void:
	if not popups.has(key): return
	var record: Dictionary = popups[key]
	popups.erase(key)
	record["gone_t"] = now
	record.erase("mid_scanned")
	var overlaps: Array = []
	for other_key: String in (record["overlaps"] as Dictionary):
		var o: Dictionary = (record["overlaps"] as Dictionary)[other_key]
		o["key"] = other_key
		overlaps.append(o)
	record["overlaps"] = overlaps
	_write(record)

# Change streams for the context a player sees: animating actors, the acting
# foe in the pacing clock, the action banner, the rail's active slot, the hero's
# health ghost and plate, the played card, and modals.
func _track_context(now: int, board: Control, layer: Control, pacing: Node, hero_tile: Vector2i, xform: Transform2D) -> void:
	var presentation: Dictionary = board.get("presentation")
	var animating: Dictionary = {}
	var effect: Dictionary = presentation.get("effect", {}) if typeof(presentation.get("effect", {})) == TYPE_DICTIONARY else {}
	for field: String in ["actor_key", "source_actor_key"]:
		if _actor_like(str(effect.get(field, ""))): animating[str(effect.get(field, ""))] = true
	for field: String in presentation:
		var value: Variant = presentation[field]
		if field.ends_with("_motion") and typeof(value) == TYPE_DICTIONARY:
			for actor: Variant in value as Dictionary:
				if _actor_like(str(actor)): animating[str(actor)] = true
		elif typeof(value) == TYPE_STRING and "actor" in field and _actor_like(str(value)):
			animating[str(value)] = true
	var names: Array = animating.keys()
	names.sort()
	_set_track(now, "animating", ",".join(names))
	_set_track(now, "effect", "%s:%s" % [str(effect.get("kind", "")), str(effect.get("actor_key", ""))])
	var focus: PackedStringArray = []
	if typeof(presentation.get("focus_actor_keys", [])) == TYPE_ARRAY:
		for actor: Variant in presentation.get("focus_actor_keys", []): focus.append(str(actor))
	_set_track(now, "focus", ",".join(focus))
	_set_track(now, "pacing", "%s|%s" % [str(pacing.get("_actor")), str(pacing.get("_phase"))])
	var banner: Label = scene.get("action_banner")
	_set_track(now, "banner", banner.text if banner != null and banner.is_visible_in_tree() else "")
	var turn_banner: Control = scene.get("_turn_banner")
	_set_track(now, "turn_banner", str(is_instance_valid(turn_banner) and turn_banner.is_visible_in_tree()))
	_set_track(now, "rail", _rail_active())
	var tracker: RefCounted = layer.get("health_ghost_tracker")
	var ghost: Dictionary = tracker.sample("player") if tracker != null else {}
	if not ghost.is_empty():
		var range_value: Vector2 = ghost["ghost_range"]
		_set_track(now, "ghost", "%d|%d|%d" % [roundi(range_value.x), roundi(range_value.y), int(ghost.get("max_hp", 0))])
	var plate: float = float(board.get("plate_visibility").opacity("player"))
	_set_track(now, "plate", "0" if plate <= 0.01 else "1" if plate >= 0.99 else "part")
	_set_track(now, "hero_tile", str(hero_tile))
	_set_track(now, "hand_animating", str(scene.get("_animating_hand_card_index")))
	_set_track(now, "modal", str(scene.call("_controller_modal_visible")))
	var events: Array = presentation.get("surface_feedback_events", []) if typeof(presentation.get("surface_feedback_events", [])) == TYPE_ARRAY else []
	var surface_tiles: PackedStringArray = []
	for event: Variant in events:
		if typeof(event) == TYPE_DICTIONARY: surface_tiles.append(str((event as Dictionary).get("tile", INVALID)))
	_set_track(now, "surface", ";".join(surface_tiles))

func _actor_like(key: String) -> bool:
	return key == "player" or key.begins_with("enemy_") or key.begins_with("illusion_")

# The rail's own record of what it renders (combat_hud_right_column.gd), so a
# slot mid-transition still reports the entry it shows.
func _rail_active() -> String:
	var bar: Control = scene.get("_turn_order_bar")
	if not is_instance_valid(bar) or not bar.is_visible_in_tree(): return ""
	for entry: Dictionary in scene.get("_turn_order_rendered_entries") as Array:
		if bool(entry.get("active", false)): return str(entry.get("actor_key", entry.get("kind", "")))
	return ""

func _set_track(now: int, name: String, value: String) -> void:
	if tracks.get(name, null) == value: return
	tracks[name] = value
	_write({"kind": "track", "name": name, "value": value, "t": now, "frame": frame_index, "fight": _fight_id()})

func _bump_track(name: String, bucket: String) -> void:
	var counts: Dictionary = tracks.get(name, {}) if typeof(tracks.get(name, {})) == TYPE_DICTIONARY else {}
	counts[bucket] = int(counts.get(bucket, 0)) + 1
	tracks[name] = counts

# --- occlusion: painting UI drawn above the board, over a number ---------------

func _occluders(rect: Rect2) -> Array:
	var result: Array = []
	if rect.get_area() <= 0.0: return result
	for node: Node in scene.get_children():
		if node is CanvasLayer and (node as CanvasLayer).visible and (node as CanvasLayer).layer > 0:
			_scan_occluders(node, rect, 1.0, result)
	return result

func _scan_occluders(node: Node, rect: Rect2, alpha: float, result: Array) -> void:
	for child: Node in node.get_children():
		if child is CanvasLayer:
			if (child as CanvasLayer).visible and (child as CanvasLayer).layer > 0: _scan_occluders(child, rect, 1.0, result)
			continue
		if not (child is CanvasItem): continue
		var item: CanvasItem = child
		if not item.visible: continue
		var a: float = alpha * item.modulate.a
		if a < 0.05: continue
		if item is Control:
			var control: Control = item
			var global: Rect2 = control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)
			if control.name == &"HudSeatScrim":
				# A full-rect painter of two dark gradient bands; report the band
				# the number sits in, with the band's ink at the number's centre.
				var top: float = minf(150.0, global.size.y * 0.2)
				var bottom: float = minf(360.0, global.size.y * 0.38) if bool(control.get("show_bottom_band")) else 0.0
				var center_y: float = rect.get_center().y - global.position.y
				if center_y < top: result.append({"path": "HudSeatScrim/top_band", "class": "Control", "paints": "scrim", "fraction": 1.0, "alpha": snappedf(0.78 * (1.0 - center_y / top), 0.01), "screen_fraction": 0.0})
				elif bottom > 0.0 and center_y > global.size.y - bottom: result.append({"path": "HudSeatScrim/bottom_band", "class": "Control", "paints": "scrim", "fraction": 1.0, "alpha": snappedf(0.82 * (center_y - (global.size.y - bottom)) / bottom, 0.01), "screen_fraction": 0.0})
				_scan_occluders(item, rect, a, result)
				continue
			var overlap: float = global.intersection(rect).get_area() / rect.get_area()
			if overlap >= OCCLUDER_MIN_FRACTION:
				var paints: String = _paints(control, a * control.self_modulate.a)
				if not paints.is_empty():
					result.append({"path": str(scene.get_path_to(control)), "class": control.get_class(), "paints": paints, "fraction": snappedf(overlap, 0.01), "alpha": snappedf(a * control.self_modulate.a, 0.01), "screen_fraction": snappedf(global.get_area() / (1920.0 * 1080.0), 0.01)})
		_scan_occluders(item, rect, a, result)

func _paints(control: Control, alpha: float) -> String:
	if alpha < 0.3: return ""
	if control is Label: return "text" if not (control as Label).text.strip_edges().is_empty() else ""
	if control is RichTextLabel: return "text" if not (control as RichTextLabel).text.strip_edges().is_empty() else ""
	if control is ColorRect: return "fill" if (control as ColorRect).color.a * alpha >= 0.3 else ""
	if control is TextureRect: return "texture" if (control as TextureRect).texture != null else ""
	if control is NinePatchRect: return "texture" if (control as NinePatchRect).texture != null else ""
	if control is Panel or control is PanelContainer:
		var box: StyleBox = control.get_theme_stylebox("panel")
		if box == null or box is StyleBoxEmpty: return ""
		if box is StyleBoxFlat: return "panel" if (box as StyleBoxFlat).draw_center and (box as StyleBoxFlat).bg_color.a * alpha >= 0.3 else ""
		return "panel"
	if control is BaseButton:
		if control is Button and (control as Button).flat: return ""
		return "button"
	if control.get_script() != null and control.has_method("_draw"): return "custom"
	return ""

func _rect_json(rect: Rect2) -> Array:
	return [snappedf(rect.position.x, 0.1), snappedf(rect.position.y, 0.1), snappedf(rect.size.x, 0.1), snappedf(rect.size.y, 0.1)]

# --- truth: hero losses from the states the real playback calls receive -------

func _hero_summary(state: Dictionary) -> Dictionary:
	var player: Dictionary = state.get("player", {})
	var bleed: Dictionary = state.get(BleedReceipts.PLAYER_BLEED_KEY, {})
	var deck: Dictionary = state.get("deck", {})
	return {"hp": int(player.get("hp", 0)), "max_hp": int(player.get("max_hp", 0)), "block": int(player.get("block", 0)), "stoneskin": int(player.get("stoneskin", 0)),
		"pos": player.get("pos", INVALID), "bleed_hp": int(bleed.get("hp", 0)), "bleed_block": int(bleed.get("block", 0)), "bleed_stoneskin": int(bleed.get("stoneskin", 0)),
		"cycles": int(deck.get("cycles", 0)), "fatigue_base": int(deck.get("fatigue_base", 2)), "surface_seq": int(state.get("surface_event_sequence", 0)),
		"received": int((state.get("run_stats", {}) as Dictionary).get("damage_received", 0)), "bleed_stacks": int(player.get("bleed", 0))}

func _hero_lost(before: Dictionary, after: Dictionary) -> bool:
	return after["hp"] < before["hp"] or after["block"] < before["block"] or after["stoneskin"] < before["stoneskin"] or after["received"] > before["received"]

func _hero_idle(now: int) -> void:
	var state: Dictionary = scene.get("_combat_state")
	var engine: RefCounted = scene.get("_combat_engine")
	if state.is_empty() or not engine.is_player_turn(state): return
	var summary: Dictionary = _hero_summary(state)
	if hero_baseline.is_empty() or hero_baseline.get("fight", "") != _fight_id():
		hero_baseline = {"state": state.duplicate(true), "summary": summary, "t": now, "frame": frame_index, "fight": _fight_id()}
		hero_actions.clear()
		return
	if summary == hero_baseline["summary"]:
		hero_baseline["t"] = now
		hero_baseline["frame"] = frame_index
		hero_actions.clear()
		return
	_emit_hero_window(state, now)

func _emit_hero_window(state: Dictionary, now: int) -> void:
	if hero_baseline.is_empty(): return
	var before: Dictionary = hero_baseline["state"]
	if _hero_lost(_hero_summary(before), _hero_summary(state)):
		var cards: Array = []
		for step: Dictionary in hero_actions: cards.append("%s:%s" % [step["card"], step["type"]])
		_emit_losses(before, state, {"t0": hero_baseline["t"], "t1": now, "frame0": hero_baseline["frame"], "frame1": frame_index},
			{"category": "self", "path": "hero_action", "actor": "player", "actions": cards})
	hero_baseline = {"state": state.duplicate(true), "summary": _hero_summary(state), "t": now, "frame": frame_index, "fight": _fight_id()}
	hero_actions.clear()

# Every entry list the rail is handed (the active entry it then highlights),
# with the caller, to tell which producer moved the highlight.
func on_rail_set(_scene: Node, entries: Array[Dictionary]) -> void:
	var active: String = ""
	for entry: Dictionary in entries:
		if bool(entry.get("active", false)):
			active = str(entry.get("actor_key", entry.get("kind", "")))
			break
	var stack: Array = get_stack()
	var callers: PackedStringArray = []
	for frame: Dictionary in stack.slice(1, 5): callers.append("%s:%d" % [str(frame.get("function", "")), int(frame.get("line", 0))])
	_write({"kind": "rail_set", "active": active, "t": _now(), "frame": frame_index, "fight": _fight_id(), "callers": ",".join(callers), "round": round_index if in_round else -1})

func on_rail_transition(_scene: Node, before_order: Array[Dictionary], after_order: Array[Dictionary], edge: String) -> void:
	var keys: Array = []
	for order: Array[Dictionary] in [before_order, after_order]:
		var active: String = ""
		for entry: Dictionary in order:
			if bool(entry.get("active", false)):
				active = str(entry.get("actor_key", entry.get("kind", "")))
				break
		keys.append(active)
	_write({"kind": "rail_transition", "edge": edge, "before": keys[0], "after": keys[1], "same_signature": scene.call("_turn_order_signature", before_order) == scene.call("_turn_order_signature", after_order),
		"rail_animating": bool(scene.get("_turn_order_animating")), "t": _now(), "frame": frame_index, "fight": _fight_id(), "round": round_index if in_round else -1})

# atk-10: a number first drawn after contact inside attack frames; its clock
# (and so the feedback wait) starts this much later than contact.
func on_text_delay(_scene: Node, seconds: float) -> void:
	_write({"kind": "text_delay", "seconds": seconds, "t": _now(), "frame": frame_index, "fight": _fight_id(), "round": round_index if in_round else -1})

func on_action_step(_scene: Node, card_id: String, action_type: String) -> void:
	hero_actions.append({"card": card_id if not card_id.is_empty() else "move", "type": action_type})

func on_round_begin(_scene: Node) -> void:
	var now: int = _now()
	var state: Dictionary = scene.get("_combat_state")
	if not hero_baseline.is_empty(): _emit_hero_window(state, now)
	hero_baseline = {}
	in_round = true
	round_index += 1
	round_t0 = now
	round_frame0 = frame_index
	round_counts = {}
	round_begin_state = state.duplicate(true)
	round_begin_enemy_ids = {}
	for enemy: Dictionary in state.get("enemies", []): round_begin_enemy_ids[int(enemy.get("id", -1))] = true
	slice_prev = {}
	pending_beats = {}
	beat_windows = {}
	_write({"kind": "round", "edge": "begin", "round": round_index, "t": now, "frame": frame_index, "fight": _fight_id(), "turn": int(state.get("turn", 0)), "hero": _hero_summary(state)})

func on_slice_begin(_scene: Node, animated_state: Dictionary, steps: Array, _resolved_state: Dictionary) -> void:
	var now: int = _now()
	var engine: RefCounted = scene.get("_combat_engine")
	var before: Dictionary = slice_prev if not slice_prev.is_empty() else animated_state.duplicate(true)
	if slice_prev.is_empty() and _hero_lost(_hero_summary(round_begin_state), _hero_summary(before)):
		_emit_losses(round_begin_state, before, {"t0": round_t0, "t1": now, "frame0": round_frame0, "frame1": frame_index}, {"category": "turn_end", "path": "finish_player_activation", "actor": "player"})
	var actor: Dictionary = _peek_actor(engine, before)
	var key: String = str(actor["key"])
	round_counts[key] = int(round_counts.get(key, 0)) + 1
	actor["n"] = int(round_counts[key])
	if actor["kind"] == "enemy":
		var enemy: Dictionary = _enemy(before, int(actor["id"]))
		actor["type"] = str(enemy.get("type", ""))
		actor["visible"] = enemy.is_empty() or engine.is_enemy_visible_to_player(before, enemy)
		actor["arrived"] = not round_begin_enemy_ids.has(int(actor["id"]))
	slice_ctx = {"t0": now, "frame0": frame_index, "before": before, "actor": actor, "steps": _steps_summary(steps)}
	_write({"kind": "slice", "round": round_index, "actor": actor, "t": now, "frame": frame_index, "fight": _fight_id(), "steps": slice_ctx["steps"]})

func on_slice_end(_scene: Node, animated_state: Dictionary, _steps: Array, resolved_state: Dictionary) -> void:
	if slice_ctx.is_empty(): return
	var now: int = _now()
	var after: Dictionary = resolved_state if not resolved_state.is_empty() else animated_state
	var actor: Dictionary = slice_ctx["actor"]
	var category: String = "turn_start"
	if actor["kind"] == "enemy":
		category = "arrived" if bool(actor.get("arrived", false)) else ("first" if int(actor["n"]) == 1 else "repeat")
	elif actor["kind"] != "player":
		category = "rule_beat"
	var hidden: bool = actor["kind"] == "enemy" and not bool(actor.get("visible", true))
	var actor_name: String = ""
	for step: Dictionary in slice_ctx["steps"]:
		if str(step.get("actor", "")) != str(actor["key"]): continue
		if bool(step.get("hidden", false)): hidden = true
		if actor_name.is_empty(): actor_name = str(step.get("name", ""))
	_emit_losses(slice_ctx["before"], after, {"t0": slice_ctx["t0"], "t1": now, "frame0": slice_ctx["frame0"], "frame1": frame_index},
		{"category": category, "path": "enemy_slice", "actor": str(actor["key"]), "actor_type": str(actor.get("type", "")), "actor_name": actor_name, "n": int(actor["n"]), "hidden": hidden, "steps": slice_ctx["steps"]}, true)
	slice_prev = after.duplicate(true)
	slice_ctx = {}

func on_beat_begin(_scene: Node, kind: String, amount: int) -> void:
	beat_windows[kind] = {"t0": _now(), "frame0": frame_index, "beat_shown_amount": amount}

func on_beat_end(_scene: Node, kind: String) -> void:
	if not beat_windows.has(kind): return
	var window: Dictionary = beat_windows[kind]
	window["t1"] = _now()
	window["frame1"] = frame_index
	for row: Dictionary in pending_beats.get(kind, []):
		row.merge(window, true)
		row["path"] = "%s_beat" % kind
		_write_loss(row)
	pending_beats.erase(kind)

func on_round_end(_scene: Node) -> void:
	var now: int = _now()
	for kind: String in pending_beats:
		for row: Dictionary in pending_beats[kind]:
			row["path"] = "%s_no_beat_call" % kind
			row["t1"] = now
			row["frame1"] = frame_index
			_write_loss(row)
	pending_beats = {}
	in_round = false
	hero_baseline = {}
	_write({"kind": "round", "edge": "end", "round": round_index, "t": now, "frame": frame_index, "fight": _fight_id(), "hero": _hero_summary(scene.get("_combat_state"))})

# Split one window's hero loss by source. Counters the engine keeps for
# presentation (Bleed receipts, deck cycles, surface events) separate Bleed,
# Fatigue and fire; the remainder belongs to the window's own source.
func _emit_losses(before_state: Dictionary, after_state: Dictionary, window: Dictionary, base: Dictionary, defer_beats: bool = false) -> void:
	var b: Dictionary = _hero_summary(before_state)
	var a: Dictionary = _hero_summary(after_state)
	var hp_total: int = maxi(maxi(0, b["hp"] - a["hp"]), a["received"] - b["received"])
	var parts: Array[Dictionary]
	var fatigue: int = 0
	for cycle: int in range(int(b["cycles"]) + 1, int(a["cycles"]) + 1): fatigue += int(a["fatigue_base"]) + cycle - 1
	fatigue = mini(fatigue, hp_total)
	var bleed_hp: int = mini(maxi(0, a["bleed_hp"] - b["bleed_hp"]), hp_total - fatigue)
	var fire: int = 0
	var traps: int = 0
	for event: Dictionary in after_state.get("surface_events", []):
		if int(event.get("sequence", 0)) <= int(b["surface_seq"]): continue
		if str(event.get("kind", "")) == "surface_damage" and str(event.get("actor_kind", "")) == "player": fire += int(event.get("health_lost", 0))
		if str(event.get("kind", "")) == "trap_triggered": traps += 1
	fire = mini(fire, hp_total - fatigue - bleed_hp)
	var rest: int = hp_total - fatigue - bleed_hp - fire
	var start_slice: bool = str(base.get("category", "")) == "turn_start"
	var own: String = "surface" if traps > 0 and str(base["category"]) == "self" else str(base["category"])
	if fatigue > 0: parts.append({"field": "hp", "amount": fatigue, "category": "fatigue", "beat": "fatigue"})
	if fire > 0: parts.append({"field": "hp", "amount": fire, "category": "surface", "sub": "fire", "beat": "fire" if start_slice else ""})
	if bleed_hp > 0: parts.append({"field": "hp", "amount": bleed_hp, "category": "bleed"})
	var remainders: Dictionary = {"hp": rest}
	for field: String in ["block", "stoneskin"]:
		var lost: int = maxi(0, int(b[field]) - int(a[field]))
		var bled: int = mini(lost, maxi(0, int(a["bleed_" + field]) - int(b["bleed_" + field])))
		if bled > 0: parts.append({"field": field, "amount": bled, "category": "bleed"})
		# Block resets as the hero's turn begins (before any turn-start burn):
		# that is expiry, not a hit.
		if lost - bled > 0 and start_slice and field == "block": parts.append({"field": field, "amount": lost - bled, "category": "block_expiry"})
		else: remainders[field] = lost - bled
	# One activation can hit more than once (a dragon's bite, then its marks).
	# Each damaging step's own hero loss is its own receipt; any remainder the
	# steps do not name stays with the activation.
	var fields: Array = ["hp", "block", "stoneskin"]
	for index: int in range((base.get("steps", []) as Array).size()):
		var step: Dictionary = (base["steps"] as Array)[index]
		var hit: Array = step.get("hero_loss", step.get("step_loss", []))
		if hit.is_empty(): continue
		for slot: int in range(3):
			var amount: int = mini(int(hit[slot]), int(remainders.get(fields[slot], 0)))
			if amount <= 0: continue
			remainders[fields[slot]] = int(remainders[fields[slot]]) - amount
			parts.append({"field": fields[slot], "amount": amount, "category": own, "step": index, "step_kind": str(step.get("kind", "")), "step_action": str(step.get("action", ""))})
	for field: String in fields:
		if int(remainders.get(field, 0)) > 0: parts.append({"field": field, "amount": int(remainders[field]), "category": own, "sub": "trap" if traps > 0 and field == "hp" else ""})
	for part: Dictionary in parts:
		var row: Dictionary = base.duplicate(true)
		row.merge(part, true)
		row.merge(window, true)
		row["kind"] = "loss"
		row["hero_before"] = {"hp": b["hp"], "block": b["block"], "stoneskin": b["stoneskin"], "max_hp": b["max_hp"], "pos": str(b["pos"]), "bleed": b["bleed_stacks"]}
		row["hero_after"] = {"hp": a["hp"], "block": a["block"], "stoneskin": a["stoneskin"], "pos": str(a["pos"])}
		row["fight"] = _fight_id()
		row["round"] = round_index if in_round else -1
		row["turn"] = int(after_state.get("turn", 0))
		var beat: String = str(part.get("beat", ""))
		row.erase("beat")
		if defer_beats and not beat.is_empty():
			if not pending_beats.has(beat): pending_beats[beat] = []
			(pending_beats[beat] as Array).append(row)
		else:
			_write_loss(row)

func _write_loss(row: Dictionary) -> void:
	loss_count += 1
	row["seed"] = hunt_seed
	row["speed"] = speed
	row["reduced_motion"] = reduced
	row["anchor_decision"] = anchor_decision
	row["replay_decisions"] = anchor_decisions.size()
	_persist_repro(row)
	_write(row)

func _steps_summary(steps: Array) -> Array:
	var result: Array = []
	for step_var: Variant in steps:
		if typeof(step_var) != TYPE_DICTIONARY: continue
		var step: Dictionary = step_var
		var row: Dictionary = {"kind": str(step.get("kind", "")), "actor": str(step.get("actor_key", "")), "hidden": bool(step.get("hidden_by_umbra", false))}
		if step.has("actor_name"): row["name"] = str(step.get("actor_name", ""))
		if step.has("source_actor_key"): row["source"] = str(step.get("source_actor_key", ""))
		if str(step.get("kind", "")) == "turn_order":
			for edge: String in ["before_order", "after_order"]:
				for entry: Dictionary in step.get(edge, []):
					if bool(entry.get("active", false)):
						row[edge.trim_suffix("_order") + "_active"] = str(entry.get("actor_key", entry.get("kind", "")))
						break
			row["label"] = str(step.get("label", ""))
		if step.has("action_type"): row["action"] = str(step.get("action_type", ""))
		for loss: Variant in step.get("target_losses", []):
			if typeof(loss) == TYPE_DICTIONARY and (str((loss as Dictionary).get("kind", "")) == "player" or str((loss as Dictionary).get("key", "")) == "player"):
				row["hero_loss"] = [int((loss as Dictionary).get("hp_loss", 0)), int((loss as Dictionary).get("block_loss", 0)), int((loss as Dictionary).get("stoneskin_loss", 0))]
		if int(step.get("hp_loss", 0)) > 0 or int(step.get("block_loss", 0)) > 0: row["step_loss"] = [int(step.get("hp_loss", 0)), int(step.get("block_loss", 0)), int(step.get("stoneskin_loss", 0))]
		result.append(row)
	return result

# The next actor exactly as the committed slice will pop it (read-only copy).
func _peek_actor(engine: RefCounted, state: Dictionary) -> Dictionary:
	var probe: Dictionary = state.duplicate(true)
	var popped: Dictionary = engine._pop_next_actor(probe)
	var entry: Dictionary = popped.get("entry", {})
	var kind: String = str(entry.get("kind", ""))
	if entry.is_empty() or kind == "player": return {"key": "turn_start", "kind": "player"}
	if kind == "enemy": return {"key": "enemy_%d" % int(entry.get("enemy_id", -1)), "kind": "enemy", "id": int(entry.get("enemy_id", -1))}
	return {"key": kind, "kind": kind}

func _enemy(state: Dictionary, id: int) -> Dictionary:
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("id", -1)) == id: return enemy
	return {}

func _fight_id() -> String:
	if not is_instance_valid(scene): return ""
	var run: Dictionary = scene.get("_run_state")
	return "%d:%d:%s" % [hunt_seed, int(run.get("run_index", 0)), str(run.get("current_room", Vector2i.ZERO))]

# The presentation clock (combat_pacing.gd), made monotonic across the hunt's
# save/resume side action, which builds a new scene and a new clock.
var clock_offset: int = 0
var clock_last: int = -1
func _now() -> int:
	var pacing: Node = scene.get("_combat_pacing") if is_instance_valid(scene) else null
	if pacing == null: return maxi(0, clock_last)
	var raw: int = pacing.presentation_usec()
	if clock_last >= 0 and raw + clock_offset < clock_last: clock_offset = clock_last - raw
	clock_last = raw + clock_offset
	return clock_last

func _write(row: Dictionary) -> void:
	if receipts == null: return
	receipts.store_line(JSON.stringify(row))
