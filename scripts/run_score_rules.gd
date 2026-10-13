extends RefCounted
class_name RunScoreRules

const GameData = preload("res://scripts/game_data.gd")
const Guardians = preload("res://scripts/guardian_library.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const TEXT_PATH: String = "res://data/run_end_text.json"
const BIOMES_PATH: String = "res://data/biomes.json"
const COUNTERS := ["enemies_killed", "damage_dealt", "damage_received", "rooms_explored", "enemies_slain", "guardians_slain", "max_single_hit", "max_kills_one_card", "mystery_rooms_entered", "events_resolved", "max_held_embers", "defiance_spent"]
const ID_LISTS := ["guardians_unscathed", "dragons_slain", "dragons_flawless"]
const UNKNOWN_KILLER: String = "The Umbra took your last breath."
const DEFAULT_TITLES := {"defeat": "SLAIN", "victory": "ESCAPED", "embrace": "WITHDRAWN"}
const FEAT_NAME_LIMIT: int = 3
static var _text: Dictionary = {}
static var _biomes: Dictionary = {}

# Scene-owned wall time stays outside resolver/saved state until a commit.
var _play_run_id: String = ""
var _play_last_usec: int = -1
var _play_active: bool = false
var play_seconds: float = 0.0

func reset_play_time() -> void:
	_play_run_id = ""
	_play_last_usec = -1
	_play_active = false
	play_seconds = 0.0

func sample_play_time(state: Dictionary, active: bool, now_usec: int = Time.get_ticks_usec()) -> void:
	if state.is_empty():
		reset_play_time()
		return
	var run_id: String = "run:%d:seed:%d" % [int(state.get("run_index", 0)), int(state.get("seed", 0))]
	var saved_seconds: float = maxf(0.0, float((state.get("run_stats", {}) as Dictionary).get("run_seconds", 0.0)))
	if run_id != _play_run_id:
		_play_run_id = run_id
		play_seconds = saved_seconds
	elif _play_active and _play_last_usec >= 0:
		play_seconds += float(maxi(0, now_usec - _play_last_usec)) / 1000000.0
	play_seconds = maxf(play_seconds, saved_seconds)
	_play_last_usec = now_usec
	_play_active = active and not bool(state.get("game_over", false)) and str(state.get("mode", "")) not in ["defeat", "victory", "embrace"]

func commit_play_time(state: Dictionary) -> void:
	if state.is_empty() or _play_run_id != "run:%d:seed:%d" % [int(state.get("run_index", 0)), int(state.get("seed", 0))]:
		return
	var stats: Dictionary = normalized_stats(state.get("run_stats", {}))
	stats["run_seconds"] = maxf(float(stats["run_seconds"]), play_seconds)
	state["run_stats"] = stats

func sample_scene_play_time(host: Control, committed_state: Dictionary = {}) -> void:
	var live_state: Dictionary = host.get("_run_state") as Dictionary
	var state: Dictionary = live_state if committed_state.is_empty() else committed_state
	var menu: Control = host.get("_menu_scrim") as Control
	sample_play_time(state, host.is_visible_in_tree() and not host.get_tree().paused and (menu == null or not menu.visible))
	if not committed_state.is_empty():
		commit_play_time(committed_state)
		commit_play_time(live_state)

static func normalized_stats(value: Variant) -> Dictionary:
	var stats: Dictionary = (value as Dictionary).duplicate(true) if value is Dictionary else {}
	for key: String in COUNTERS:
		stats[key] = maxi(0, int(stats.get(key, 0)))
	for key: String in ID_LISTS:
		stats[key] = string_ids(stats.get(key, []))
	stats["card_resolution_kills"] = maxi(0, int(stats.get("card_resolution_kills", 0)))
	stats["card_resolution_active"] = bool(stats.get("card_resolution_active", false))
	stats["run_seconds"] = maxf(0.0, float(stats.get("run_seconds", 0.0)))
	stats["killer"] = normalized_killer(stats.get("killer", {}))
	return stats

static func normalized_killer(value: Variant) -> Dictionary:
	var killer: Dictionary = (value as Dictionary).duplicate(true) if value is Dictionary else {}
	if killer.has("damage"):
		killer["damage"] = maxi(0, int(killer["damage"]))
	return killer

static func string_ids(value: Variant) -> Array[String]:
	var result: Array[String]
	if value is Array:
		for item: Variant in value:
			var id: String = str(item)
			if not id.is_empty() and not result.has(id):
				result.append(id)
	return result

static func score(run_state: Dictionary, outcome: String) -> Dictionary:
	var stats: Dictionary = normalized_stats(run_state.get("run_stats", {}))
	var lines: Array[Dictionary]
	var feats: Array[Dictionary]
	for spec: Array in [["rooms_explored", "Rooms explored", 5], ["enemies_slain", "Enemies slain", 2], ["guardians_slain", "Guardians slain", 25]]:
		var count: int = int(stats[spec[0]])
		_append(lines, str(spec[0]), str(spec[1]), "%d × %d" % [count, int(spec[2])], count * int(spec[2]))
	var dragons: Array[String] = string_ids(stats["dragons_slain"])
	var dragon_names: PackedStringArray = PackedStringArray()
	for id: String in dragons:
		dragon_names.append(dragon_name(id))
	var dragon_count: int = mini(6, dragons.size())
	_append(lines, "dragons_slain", "Dragons slain", ", ".join(dragon_names), 25 * dragon_count * (dragon_count + 1))
	var victory: bool = outcome == "victory"
	if victory:
		_append(lines, "escaped", "Escaped the Umbra", "", 250)
	_aggregate_feat(feats, "unscathed", "Unscathed", string_ids(stats["guardians_unscathed"]), 25)
	_aggregate_feat(feats, "flawless", "Flawless", string_ids(stats["dragons_flawless"]), 50)
	var hit: int = int(stats["max_single_hit"])
	if hit >= 20:
		_append(feats, "overkill", "Overkill", "%d damage in one hit" % hit, 25)
	var kills: int = int(stats["max_kills_one_card"])
	if kills >= 3:
		_append(feats, "chain_reaction", "Chain Reaction", "%d foes slain by one card" % kills, 25)
	var mysteries: int = int(stats["mystery_rooms_entered"])
	if mysteries >= 10:
		_append(feats, "seeker", "Seeker", "%d unknown rooms" % mysteries, 25)
	var events: int = int(stats["events_resolved"])
	if events >= 8:
		_append(feats, "bargainer", "Bargainer", "%d events" % events, 25)
	var embers: int = int(stats["max_held_embers"])
	if embers >= 600:
		_append(feats, "ember_hoard", "Ember Hoard", "%s Embers held at once" % grouped_number(embers), 50 if embers >= 1200 else 25)
	if victory:
		if int(stats["defiance_spent"]) >= 1:
			_append(feats, "last_light", "Last Light", "Escaped after Defiance saved you", 25)
		var seconds: float = float(stats["run_seconds"])
		if seconds < 3600.0:
			var minutes: int = floori(seconds / 60.0)
			_append(feats, "swift", "Swift", "Escaped in %d %s" % [minutes, "minute" if minutes == 1 else "minutes"], 50 if seconds < 2700.0 else 25)
		var relics: int = (run_state.get("relics", []) as Array).size()
		if relics <= 3:
			_append(feats, "ascetic", "Ascetic", ("Escaped with %d relic" if relics == 1 else "Escaped with %d relics") % relics, 50)
	var total: int = 0
	for row: Dictionary in lines:
		total += int(row["points"])
	for row: Dictionary in feats:
		row["feat"] = true
		total += int(row["points"])
	return {"lines": lines, "feats": feats, "total": total}

static func _append(rows: Array[Dictionary], id: String, label: String, detail: String, points: int, subject: String = "") -> void:
	if points > 0:
		rows.append({"id": id, "label": label, "detail": detail, "points": points, "subject": subject, "feat": false})

static func _aggregate_feat(rows: Array[Dictionary], id: String, label: String, subjects: Array[String], points_each: int) -> void:
	var names := PackedStringArray()
	for index: int in range(mini(FEAT_NAME_LIMIT, subjects.size())):
		names.append(guardian_name(subjects[index]) if id == "unscathed" else dragon_name(subjects[index]))
	var detail: String = ", ".join(names)
	if subjects.size() > FEAT_NAME_LIMIT:
		detail += " +%d" % (subjects.size() - FEAT_NAME_LIMIT)
	if subjects.size() == 1:
		_append(rows, id, label, "%s without losing Health" % detail, points_each)
	else:
		_append(rows, id, "%s ×%d" % [label, subjects.size()], detail, points_each * subjects.size())

static func dragon_name(id: String) -> String:
	var name: String = str(GameData.enemy_def(id).get("name", id))
	return name.split(",")[0]

static func guardian_name(id: String) -> String:
	return str(Guardians.for_guardian(id).get("name", GameData.enemy_def(id).get("name", id)))

static func grouped_number(value: int) -> String:
	var digits: String = str(value)
	var result: String = ""
	for index: int in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			result += ","
		result += digits[index]
	return result

static func identity(state: Dictionary) -> String:
	var analytics_id: String = str((state.get("analytics", {}) as Dictionary).get("run_id", ""))
	return analytics_id if not analytics_id.is_empty() else "run:%d:seed:%d" % [int(state.get("run_index", 0)), int(state.get("seed", 0))]

static func analytics_context(state: Dictionary) -> Dictionary:
	var progression: Dictionary = state.get("progression", {}) as Dictionary
	var room: Dictionary = Graph.room(state, state.get("current_room", Vector2i.ZERO))
	return {
		"run_id": identity(state),
		"room_depth": int(room.get("depth", 0)),
		"room_type": str(room.get("type", "")),
		"progression_level": int(progression.get("level", 1)),
		"progression_skills": progression.get("skill_ids", []).duplicate(),
		"relics": state.get("relics", []).duplicate(),
		"moltshards": int(progression.get("moltshards", 0)),
		"combat_unit_scale": 1
	}

static func seeded_text(run_id: String, outcome: String) -> Dictionary:
	if _text.is_empty():
		_text = _read_json(TEXT_PATH)
	return text_from_data(run_id, outcome, _text)

static func text_from_data(run_id: String, outcome: String, text_data: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_id.hash()
	var titles: Array = (text_data.get("titles", {}) as Dictionary).get(outcome, [])
	var quips: Array = (text_data.get("quips", {}) as Dictionary).get(outcome, [])
	return {"title": str(titles[rng.randi_range(0, titles.size() - 1)]) if not titles.is_empty() else str(DEFAULT_TITLES.get(outcome, DEFAULT_TITLES["defeat"])), "quip": str(quips[rng.randi_range(0, quips.size() - 1)]) if not quips.is_empty() else ""}

static func location(run_state: Dictionary) -> Dictionary:
	var room: Dictionary = Graph.room(run_state, run_state.get("current_room", Vector2i.ZERO))
	var index: int = int(room.get("section_index", 0))
	var section: Dictionary = Graph.section(run_state, index)
	var boss_id: String = str(section.get("boss_id", room.get("boss_id", "")))
	if _biomes.is_empty():
		_biomes = _read_json(BIOMES_PATH)
	var biome_id: String = str((_biomes.get("section_biomes", {}) as Dictionary).get(boss_id, boss_id))
	var biome: Dictionary = (_biomes.get("biomes", {}) as Dictionary).get(biome_id, {})
	return {"section": index + 1 if not section.is_empty() else 0, "biome": biome_id, "biome_name": str(biome.get("name", section.get("title", ""))), "step": int(room.get("map_step", 0)), "room_count": int(section.get("room_count", 0))}

static func roman(section: int) -> String:
	const NUMERALS := ["I", "II", "III", "IV", "V", "VI"]
	return str(NUMERALS[section - 1]) if section >= 1 and section <= NUMERALS.size() else str(section)

static func cause_text(killer: Dictionary, outcome: String, embers: int) -> String:
	if outcome == "victory":
		return "Noctyrax falls. The way out is open."
	if outcome == "embrace":
		return "You leave by the Ember Hearth, carrying %s Embers." % grouped_number(embers)
	match str(killer.get("cause", "")):
		"fatigue": return "Fatigue took your last breath."
		"surface":
			var surface: String = str(killer.get("surface", ""))
			return "%s took your last breath." % surface.capitalize() if not surface.is_empty() else "The ground itself took your last breath."
		"trap":
			var element: String = str(killer.get("element", ""))
			return "A %s trap took your last breath." % element if not element.is_empty() else "A trap took your last breath."
	var enemy_type: String = str(killer.get("enemy_type", ""))
	if enemy_type.is_empty():
		return UNKNOWN_KILLER
	var enemy: Dictionary = GameData.enemy_def(enemy_type)
	var intent_name: String = ""
	for intent: Dictionary in enemy.get("intents", []):
		if str(intent.get("id", "")) == str(killer.get("intent_id", "")):
			intent_name = str(intent.get("name", intent_name))
	if intent_name.is_empty():
		return "Felled by a %s, %d damage." % [str(enemy.get("name", enemy_type)), int(killer.get("damage", 0))]
	return "Felled by a %s's %s, %d damage." % [str(enemy.get("name", enemy_type)), intent_name, int(killer.get("damage", 0))]

static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value as Dictionary if value is Dictionary else {}
