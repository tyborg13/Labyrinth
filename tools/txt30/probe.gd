extends SceneTree
## Candidate 4 truth witnesses from txt-29, checked against the real outcomes.

const Combat = preload("res://scripts/combat_engine.gd")
const Objectives = preload("res://scripts/combat_objective_rules.gd")
const PreBattle = preload("res://scripts/pre_battle_view.gd")
const Scores = preload("res://scripts/run_score_rules.gd")
const InlineText = preload("res://scripts/inline_icon_text.gd")
const Run = preload("res://scripts/run_engine.gd")
const Scene = preload("res://scripts/run_scene.gd")
const Store = preload("res://scripts/progression_store.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const MapPanel = preload("res://scripts/section_map_panel.gd")
const Recap = preload("res://scripts/run_end_recap_overlay.gd")

const FIRST_SEED: int = 29
const NEXT_SEED: int = 30
const LOST_EMBERS: int = 37
const REWARD_HP: int = 12
const REWARD_MAX_HP: int = 26
const REWARD_CARD: String = "shatterline"
const SCOUT_SEED: int = 29
const LEGACY_REVISION: int = 4
const FOLLOWER_HP: int = 1
const NON_SCOUT_MODES: Array = ["", "campfire", "escape", "graftwright", "event",
	"scavenger", "shop", "merchant", "treasure", "reward", "defeat", "victory", "withdraw"]
const VIEW_SIZE := Vector2i(1920, 1080)

var witnessed: int
var missing: int

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	_recovery_map()
	_scout_at_hearth()
	_legacy_map_objective()
	await _reward_order()
	print("TXT30 WITNESSES: %d true, %d failed" % [witnessed, missing])
	quit(0 if missing == 0 else 1)

func _record(id: String, observed: bool, details: Dictionary) -> void:
	if observed: witnessed += 1
	else: missing += 1
	print("TXT30 %s %s | %s" % ["TRUE" if observed else "FALSE", id, JSON.stringify(details)])

func _recovery_map() -> void:
	var engine := Run.new()
	var profile: Dictionary = Store.prepare_for_new_run(Store.default_data())
	var run: Dictionary = engine.create_new_run(FIRST_SEED, profile)
	var next_map: Dictionary = engine.create_new_run(NEXT_SEED, Store.prepare_for_new_run(profile))
	# Check the first-step combats on the generated route, then reproduce one
	# actual death from a route whose room has moved in the next map.
	var candidate: Vector2i = Graph.INVALID
	for coord: Vector2i in engine.available_moves(run):
		if str(Graph.room(run, coord).get("type", "")) != "combat": continue
		var old_room: Dictionary = Graph.room(run, coord)
		var new_room: Dictionary = Graph.room(next_map, coord)
		if new_room.get("type") != old_room["type"] or new_room.get("element") != old_room["element"] or new_room.get("map_lane") != old_room["map_lane"]:
			candidate = coord
			break
	if candidate == Graph.INVALID:
		_record("recovery_location", false, {"reason": "seed pair has no different first-step combat"})
		return
	var combat_run: Dictionary = engine.begin_pre_battle_combat(engine.move_to_pre_battle(run, candidate))
	if str(combat_run.get("mode", "")) != "combat":
		_record("recovery_location", false, {"reason": "could not start generated combat", "coord": str(candidate)})
		return
	combat_run = engine.set_held_embers(combat_run, LOST_EMBERS)
	var fight: Dictionary = combat_run["combat_state"]
	var fallen: Dictionary = Combat.new()._lose_player_health(fight, int(fight["player"]["hp"]), true, false, "fatigue")
	var defeated: Dictionary = engine.finish_combat(combat_run, fallen)
	var loss: int = engine.held_embers(defeated)
	var after: Dictionary = Store.record_lost_embers(profile, loss, candidate, int(run["run_index"]))
	var model: Dictionary = Recap.build_model(defeated, after, "defeat", loss)
	var next_run: Dictionary = engine.create_new_run(NEXT_SEED, Store.prepare_for_new_run(after, defeated))
	var marker: Vector2i = next_run.get("map_recovery_coord", Graph.INVALID)
	var old: Dictionary = Graph.room(run, candidate)
	var replacement: Dictionary = Graph.room(next_run, marker)
	var same_room: bool = marker == candidate and old.get("type") == replacement.get("type") and old.get("element") == replacement.get("element") and old.get("map_lane") == replacement.get("map_lane")
	_record("recovery_location", defeated["mode"] == "defeat" and model["embers_text"] == (
		"Embers lost %s. They wait in Section %s of your next run." % [
			Scores.grouped_number(loss), Scores.roman(int(replacement.get("section_index", -1)) + 1)]) and replacement.get("recovery_amount") == loss and not same_room, {
		"text": model["embers_text"], "old_seed": FIRST_SEED, "new_seed": NEXT_SEED,
		"death": _room_identity(old), "marker": _room_identity(replacement), "marker_amount": replacement.get("recovery_amount")
	})

func _room_identity(room: Dictionary) -> Dictionary:
	return {"coord": str(room.get("coord")), "kind": room.get("type"), "element": room.get("element"), "lane": room.get("map_lane"), "section": int(room.get("section_index", -1)) + 1}

func _reward_order() -> void:
	root.content_scale_factor = 1.0
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	root.add_child(viewport)
	var scene: Control = preload("res://scenes/run_scene.tscn").instantiate()
	scene.request_staged_initial_ui()
	viewport.add_child(scene)
	scene._build_relic_choice_overlay(scene.stage_root)
	scene._build_skill_choice_dialog()
	var run: Dictionary = scene._run_engine.create_new_run(FIRST_SEED, Store.default_data())
	run["mode"] = "reward"
	run["progression"]["skill_ids"] = ["discerning_eye", "deferred_choice"]
	run["player_hp"] = REWARD_HP
	run["player_max_hp"] = REWARD_MAX_HP
	run["pending_reward"] = {"cards": [REWARD_CARD], "heal_amount": Run.REWARD_HEAL}
	scene._run_state = run
	scene._animation_lock = false
	var button: Button = scene._reward_recover_button(Run.REWARD_HEAL, run)
	# The real press opens the real skill dialog. Read HP before its option
	# callbacks settle anything, then use the same resolver as the callback.
	button.pressed.emit()
	var first: Button = scene._skill_choice_list.get_child(0) as Button if scene._skill_choice_list.get_child_count() > 0 else null
	var open: bool = scene._skill_choice_scrim.visible
	var hp_on_choice: int = int(scene._run_state["player_hp"])
	var settled: Dictionary = scene._run_engine.skip_reward_for_heal(scene._run_state, REWARD_CARD)
	_record("skip_heal_order", InlineText.plain_text(button.tooltip_text) == (
		"Recover %d Health and choose whether one offered card follows you to the next reward." % Run.REWARD_HEAL) and open and first != null and hp_on_choice == REWARD_HP and int(settled["player_hp"]) == REWARD_HP + Run.REWARD_HEAL, {
		"button": button.text, "tooltip": InlineText.plain_text(button.tooltip_text), "choice": first.text if first != null else "",
		"hp_when_asked": hp_on_choice, "hp_after_choice": settled["player_hp"]
	})
	button.free()
	viewport.queue_free()
	await process_frame

func _scout_at_hearth() -> void:
	var engine := Run.new()
	var run: Dictionary = engine.create_new_run(SCOUT_SEED, Store.default_data())
	var hearth: Vector2i = Graph.INVALID
	for room: Dictionary in run["rooms"].values():
		if room.get("type") != "campfire" or room.get("section_index") != 0: continue
		run["current_room"] = room["coord"]
		if not Graph.scout_options(run).is_empty():
			hearth = room["coord"]
			break
	if hearth == Graph.INVALID:
		_record("scout_disabled_at_hearth", false, {"reason": "no Section I Hearth has a mystery ahead"})
		return
	var panel := MapPanel.new()
	root.add_child(panel)
	Graph.refresh_knowledge(run)
	var mode_results: Dictionary = {}
	var correct: bool = true
	for mode: String in NON_SCOUT_MODES + Graph.SCOUT_MODES:
		run["mode"] = mode
		panel.set_run_state(run)
		var blocked: bool = mode in NON_SCOUT_MODES
		var expected: String = "Resolve the current room first." if blocked else "Reveal an unknown room."
		var shown: String = panel._scout._get_tooltip(Vector2.ZERO)
		mode_results[mode] = shown
		correct = correct and shown == expected and panel._scout.disabled == blocked and Graph.scout_options(run).is_empty() == blocked

	run["mode"] = "campfire"
	panel.set_run_state(run)
	var after: Dictionary = engine.leave_campfire(run, Run.CAMPFIRE_LINGER_HEAL)
	var targets: Array[Vector2i] = Graph.scout_options(after)
	panel.set_run_state(after)
	correct = correct and not panel._scout.disabled and not targets.is_empty() and run["current_room"] == after["current_room"]

	var empty: Dictionary = after.duplicate(true)
	for coord: Vector2i in targets:
		var room: Dictionary = Graph.room(empty, coord)
		room["scouted"] = true
		room["revealed"] = true
	panel.set_run_state(empty)
	var without_targets: String = panel._scout._get_tooltip(Vector2.ZERO)
	correct = correct and panel._scout.disabled and without_targets == "No unknown rooms in sight."

	Graph.section(empty, Graph.active_section(empty))["scouts"] = 0
	panel.set_run_state(empty)
	var without_uses: String = panel._scout._get_tooltip(Vector2.ZERO)
	correct = correct and panel._scout.disabled and without_uses == "No Scouts remaining."

	var history: Dictionary = after.duplicate(true)
	history["current_room"] = Graph.section(history, 1)["entry"]
	panel.set_run_state(history)
	panel.viewed_section = 0
	panel._refresh_actions()
	var completed: String = panel._scout._get_tooltip(Vector2.ZERO)
	correct = correct and panel._scout.disabled and completed == "Completed section."
	_record("scout_disabled_at_hearth", correct, {
		"hearth": str(hearth), "modes": mode_results, "targets_after_linger": targets.size(),
		"no_targets": without_targets, "exhausted": without_uses, "history": completed,
	})
	panel.free()

func _legacy_map_objective() -> void:
	var engine := Run.new()
	var run: Dictionary = engine.create_new_run(FIRST_SEED, Store.default_data())
	run["section_map_layout_revision"] = LEGACY_REVISION
	Graph.initialize(run)
	var panel := MapPanel.new()
	root.add_child(panel)
	var results: Dictionary = {}
	var correct: bool = true
	# Check the onboarding override through the same room transition as later fights.
	for coord: Vector2i in engine.available_moves(run):
		if Graph.room(run, coord).get("type") != "combat": continue
		var pre_battle: Dictionary = engine.move_to_pre_battle(run, coord)
		panel.set_run_state(pre_battle)
		var actual: String = _pre_battle_line(engine.pre_battle_preview_state(pre_battle))
		correct = actual == "Defeat each enemy." and _map_shows(panel, coord, actual)
		results["onboarding"] = actual
		Graph.room(run, coord)["visited"] = true
		Graph.room(run, coord)["cleared"] = true
		break

	for source: Vector2i in Graph.descendants(run, Vector2i.ZERO):
		if Graph.room(run, source).get("section_index") != 0: continue
		run["current_room"] = source
		for coord: Vector2i in engine.available_moves(run):
			var room: Dictionary = Graph.room(run, coord)
			if room.get("type") != "combat" or room.get("cleared", false): continue
			var pre_battle: Dictionary = engine.move_to_pre_battle(run, coord)
			var preview: Dictionary = engine.pre_battle_preview_state(pre_battle)
			if preview.is_empty(): continue
			var fight: Dictionary = preview["combat_state"]
			var objective: Dictionary = fight["objective"]
			var type: String = objective["type"]
			if results.has(type): continue
			var line: String = _pre_battle_line(preview)
			# The map must predict the objective before it has a combat state.
			panel.set_run_state(pre_battle)
			var matches: bool = _map_shows(panel, coord, line)
			if type == Objectives.KILL_LEADER:
				for unit: Dictionary in fight["enemies"]:
					unit["hp"] = 0 if unit.get("id") == objective.get("leader_id") else FOLLOWER_HP
				matches = matches and fight["enemies"].size() > 1 and Combat.new().combat_outcome(fight) == "victory"
			results[type] = {"room": str(coord), "pre_battle": line, "legend": panel._combat_legend_item.tooltip_text, "matches": matches}
			correct = correct and matches
		if results.has_all(["onboarding", Objectives.KILL_ALL, Objectives.KILL_LEADER, Objectives.REACH_EXIT]): break

	var modern: Dictionary = engine.create_new_run(FIRST_SEED, Store.default_data())
	panel.set_run_state(modern)
	var modern_line: String = panel._combat_legend_item.tooltip_text
	var fallback: String = "Defeat each enemy."
	correct = correct and modern_line == fallback
	for coord: Vector2i in engine.available_moves(modern):
		if Graph.room(modern, coord).get("type") == "combat":
			correct = correct and _map_shows(panel, coord, fallback)
	_record("legacy_map_objective", correct and results.has_all(["onboarding", Objectives.KILL_ALL, Objectives.KILL_LEADER, Objectives.REACH_EXIT]), {
		"map_revision": LEGACY_REVISION, "legacy": results, "candidate_4": modern_line,
	})
	panel.free()

func _pre_battle_line(preview: Dictionary) -> String:
	if preview.is_empty(): return ""
	var row: Control = PreBattle.build_objective(preview["combat_state"])
	var heading: Label = row.find_child("PreBattleObjectiveTitle", true, false)
	var line: String = heading.tooltip_text.get_slice("\n", 1)
	row.free()
	return line

func _map_shows(panel: Control, coord: Vector2i, line: String) -> bool:
	return not line.is_empty() and panel.room_description(coord).split("\n").has(line) and panel._combat_legend_item.tooltip_text.split("\n").has(line)
