extends RefCounted
class_name ChronicleRules

const Score = preload("res://scripts/run_score_rules.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Elements = preload("res://scripts/element_data.gd")
const GameData = preload("res://scripts/game_data.gd")
const RECORD_LIMIT: int = 50
const PATH_KEY: String = "chronicle_path"
const TODO_DESIGN_UNKNOWN_KILLER: String = "TODO_DESIGN_UNKNOWN_KILLER"
const TODO_DESIGN_UNKNOWN_INTENT: String = "TODO_DESIGN_UNKNOWN_INTENT"
const TODO_DESIGN_TRAP_NAME: String = "TODO_DESIGN_TRAP_NAME"
const TODO_DESIGN_SURFACE_NAME: String = "TODO_DESIGN_SURFACE_NAME"
const TODO_DESIGN_SECTION_NAME: String = "TODO_DESIGN_SECTION_NAME"
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

static var _terminal_snapshots: Dictionary = {}

# The existing terminal adapters request their result ID immediately before
# passing score-only metrics to the store. Carry the complete terminal snapshot
# across that synchronous boundary without changing the legacy metrics contract.
static func record_id(state: Dictionary) -> String:
	return "run:%d:seed:%d" % [int(state.get("run_index", 0)), int(state.get("seed", 0))]

static func stage_terminal_snapshot(state: Dictionary) -> void:
	_terminal_snapshots.erase(record_id(state))
	var outcome: String = str(state.get("mode", ""))
	var record: Dictionary = build_record(state, outcome, Score.score(state, outcome)) if outcome in ["defeat", "victory", "embrace"] else {}
	if record.is_empty():
		return
	_terminal_snapshots[record["run_id"]] = record
	while _terminal_snapshots.size() > RECORD_LIMIT:
		_terminal_snapshots.erase(_terminal_snapshots.keys()[0])

static func terminal_snapshot(run_id: String) -> Dictionary:
	return (_terminal_snapshots.get(run_id, {}) as Dictionary).duplicate(true)

# Only new runs have this marker. Resumed pre-Chronicle runs never manufacture
# an incomplete history from unordered room dictionaries.
static func begin_path(state: Dictionary) -> void:
	state[PATH_KEY] = []
	state["chronicle_dragon_ids"] = []
	state["chronicle_section_names"] = []
	enter_room(state, Graph.room(state, state.get("current_room", Vector2i.ZERO)))

static func enter_room(state: Dictionary, room: Dictionary) -> void:
	if not state.has(PATH_KEY) or room.is_empty():
		return
	var section_index: int = maxi(0, int(room.get("section_index", 0)))
	var path: Array = state[PATH_KEY]
	var dragons: Array = state["chronicle_dragon_ids"]
	var names: Array = state["chronicle_section_names"]
	while path.size() <= section_index:
		var section: Dictionary = Graph.section(state, path.size())
		path.append([])
		dragons.append(str(section.get("boss_id", "")))
		var location_state: Dictionary = state.duplicate(false)
		location_state["current_room"] = section.get("entry", state.get("current_room", Vector2i.ZERO))
		var section_name: String = str(Score.location(location_state).get("biome_name", ""))
		names.append(section_name if not section_name.is_empty() else TODO_DESIGN_SECTION_NAME)
	var kind: String = str(room.get("type", ""))
	if kind in ["start", "threshold", ""]:
		return
	if kind == "mystery":
		kind = str(room.get("mystery_type", "event"))
	(path[section_index] as Array).append(kind)

static func build_record(state: Dictionary, outcome: String, scored: Dictionary, date: Dictionary = {}) -> Dictionary:
	if not state.has(PATH_KEY) or outcome not in ["defeat", "victory", "embrace"] or bool(state.get("debug_boss_run", false)):
		return {}
	var location: Dictionary = Score.location(state)
	var section_index: int = maxi(0, int(location["section"]) - 1)
	var path: Array = (state.get(PATH_KEY, []) as Array).duplicate(true)
	var stats: Dictionary = Score.normalized_stats(state.get("run_stats", {}))
	var feats: Array = []
	for feat: Dictionary in scored.get("feats", []):
		feats.append({"title": str(feat.get("label", "")), "detail": str(feat.get("detail", ""))})
	var gear: Array = []
	for item: Variant in (state.get("equipped_equipment", {}) as Dictionary).values():
		if not str(item).is_empty():
			gear.append(str(item))
	var record: Dictionary = {
		"run_id": record_id(state), "outcome": outcome,
		"ended_at": local_date(date), "run_seconds": float(stats["run_seconds"]),
		"section_index": section_index, "section_name": str(location["biome_name"]) if not str(location["biome_name"]).is_empty() else TODO_DESIGN_SECTION_NAME,
		"room_index": (path[section_index] as Array).size() if section_index < path.size() else 0,
		"room_total": int(location["room_count"]), "score_total": int(scored.get("total", 0)),
		"feats": feats, "killer_text": killer_text(stats["killer"], outcome), "path": path,
		"dragon_ids": state.get("chronicle_dragon_ids", []).duplicate(),
		"section_names": state.get("chronicle_section_names", []).duplicate(),
		"gear": gear, "deck": deck_counts(state.get("deck_cards", [])),
		"deck_card_definitions": deck_card_definitions(state),
		"relics": state.get("relics", []).duplicate(),
		"dragons_slain": (stats["dragons_slain"] as Array).size()
	}
	if state.has("umbra_depth"):
		record["umbra_depth"] = maxi(0, int(state["umbra_depth"]))
	return record

static func local_date(date: Dictionary = {}) -> String:
	var local: Dictionary = Time.get_datetime_dict_from_system() if date.is_empty() else date
	return "%d %s" % [int(local.get("day", 1)), MONTHS[clampi(int(local.get("month", 1)) - 1, 0, 11)]]

static func killer_text(killer: Dictionary, outcome: String) -> String:
	if outcome == "victory":
		return "Noctyrax falls"
	if outcome == "embrace":
		return "Withdrew at the Ember Hearth"
	match str(killer.get("cause", "")):
		"fatigue": return "Worn down by fatigue"
		"surface":
			var surface: String = str(killer.get("surface", ""))
			return "Slain by %s" % (surface.capitalize() if not surface.is_empty() else TODO_DESIGN_SURFACE_NAME)
		"trap":
			var trap_name: String = str(killer.get("name", ""))
			if trap_name.is_empty() and Elements.is_elemental(str(killer.get("element", ""))):
				trap_name = "%s Trap" % Elements.name(str(killer["element"]))
			return "Slain by %s" % (trap_name if not trap_name.is_empty() else TODO_DESIGN_TRAP_NAME)
	var enemy: Dictionary = GameData.enemy_def(str(killer.get("enemy_type", "")))
	var intent_name: String = TODO_DESIGN_UNKNOWN_INTENT
	for intent: Dictionary in enemy.get("intents", []):
		if str(intent.get("id", "")) == str(killer.get("intent_id", "")):
			intent_name = str(intent.get("name", intent_name))
	if enemy.is_empty():
		return TODO_DESIGN_UNKNOWN_KILLER
	return "Felled by a %s's %s" % [str(enemy.get("name", TODO_DESIGN_UNKNOWN_KILLER)), intent_name]

static func deck_counts(value: Variant) -> Array:
	var result: Array = []
	if not value is Array:
		return result
	var indices: Dictionary = {}
	for card: Variant in value:
		var id: String = str(card)
		if indices.has(id):
			result[int(indices[id])][1] += 1
		else:
			indices[id] = result.size()
			result.append([id, 1])
	return result

# IDs/counts remain the save contract. Only run-specific printed definitions
# need a snapshot (for example relic-modified rules); legacy records without
# this additive field continue to resolve their IDs through GameData.
static func deck_card_definitions(state: Dictionary) -> Dictionary:
	var definitions: Dictionary = {}
	for pair: Array in deck_counts(state.get("deck_cards", [])):
		var id: String = str(pair[0])
		var card: Dictionary = GameData.card_def_for_progression(id, state)
		var base: Dictionary = GameData.card_def(id)
		if not base.has("id"):
			card.erase("id")
		if card != base and not base.is_empty():
			definitions[id] = card
	# Profile persistence is JSON: canonicalize its number representation before
	# comparing records, so a restart does not change nested int/float variants.
	return JSON.parse_string(JSON.stringify(definitions)) as Dictionary

static func normalized_records(value: Variant) -> Array[Dictionary]:
	var records: Array[Dictionary]
	var seen: Dictionary = {}
	if value is Array:
		for raw: Variant in value:
			if not raw is Dictionary:
				continue
			var record: Dictionary = normalized_record(raw)
			if not record.is_empty() and not seen.has(record["run_id"]):
				records.append(record)
				seen[record["run_id"]] = true
			if records.size() == RECORD_LIMIT:
				break
	return records

static func normalized_record(value: Dictionary) -> Dictionary:
	if str(value.get("run_id", "")).is_empty() or str(value.get("outcome", "")) not in ["defeat", "victory", "embrace"]:
		return {}
	var record: Dictionary = value.duplicate(true)
	for key: String in ["section_index", "room_index", "room_total", "score_total", "dragons_slain"]:
		record[key] = maxi(0, int(record.get(key, 0)))
	record["run_seconds"] = maxf(0, float(record.get("run_seconds", 0)))
	for key: String in ["section_name", "ended_at", "killer_text"]:
		record[key] = str(record.get(key, ""))
	for key: String in ["dragon_ids", "section_names", "gear", "relics"]:
		record[key] = _string_array(record.get(key, []))
	var path: Array = []
	if record.get("path") is Array:
		for row: Variant in record["path"]:
			if row is Array:
				path.append(_string_array(row))
	record["path"] = path
	var feats: Array = []
	if record.get("feats") is Array:
		for feat: Variant in record["feats"]:
			if feat is Dictionary:
				feats.append({"title": str(feat.get("title", "")), "detail": str(feat.get("detail", ""))})
	record["feats"] = feats
	var deck: Array = []
	if record.get("deck") is Array:
		for pair: Variant in record["deck"]:
			if pair is Array and pair.size() == 2:
				deck.append([str(pair[0]), maxi(1, int(pair[1]))])
	record["deck"] = deck
	if record.has("deck_card_definitions"):
		var definitions: Dictionary = {}
		if record["deck_card_definitions"] is Dictionary:
			for pair: Array in deck:
				var definition: Variant = record["deck_card_definitions"].get(pair[0])
				if definition is Dictionary and not definition.is_empty():
					definitions[pair[0]] = definition.duplicate(true)
		record["deck_card_definitions"] = JSON.parse_string(JSON.stringify(definitions)) as Dictionary
	if record.has("umbra_depth"):
		record["umbra_depth"] = maxi(0, int(record["umbra_depth"]))
	return record

static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item: Variant in value:
			result.append(str(item))
	return result

static func normalized_totals(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var totals: Dictionary = {}
	for key: String in ["runs", "escapes", "best_score", "dragons_slain"]:
		totals[key] = maxi(0, int(source.get(key, 0)))
	if source.has("deepest_depth"):
		totals["deepest_depth"] = maxi(0, int(source["deepest_depth"]))
	return totals

static func add_to_totals(totals: Dictionary, record: Dictionary) -> Dictionary:
	var result: Dictionary = normalized_totals(totals)
	result["runs"] += 1
	result["escapes"] += 1 if record["outcome"] == "victory" else 0
	result["best_score"] = maxi(int(result["best_score"]), int(record["score_total"]))
	result["dragons_slain"] += int(record.get("dragons_slain", 0))
	if record.has("umbra_depth"):
		result["deepest_depth"] = maxi(int(result.get("deepest_depth", 0)), int(record["umbra_depth"]) if record["outcome"] == "victory" else 0)
	return result

static func result_word(record: Dictionary) -> String:
	return str(Score.DEFAULT_TITLES.get(record.get("outcome", ""), ""))

static func where_text(record: Dictionary) -> String:
	if record.get("outcome") == "victory":
		return "Noctyrax falls"
	return section_text(record)

static func section_text(record: Dictionary) -> String:
	return "Section %s · %s" % [Score.roman(int(record.get("section_index", 0)) + 1), str(record.get("section_name", TODO_DESIGN_SECTION_NAME))]

static func subline(record: Dictionary) -> String:
	var text: String = "%s, room %d of %d · %d min" % [where_text(record), int(record.get("room_index", 0)), int(record.get("room_total", 0)), floori(float(record.get("run_seconds", 0)) / 60)]
	if int(record.get("umbra_depth", 0)) > 0:
		text += " · Umbra Depth %d" % int(record["umbra_depth"])
	return text + " · " + str(record.get("killer_text", ""))

# Whole spell entries wrap together. The eighth line is reserved for overflow
# only when the complete text needs more than eight lines.
static func spells_text(deck: Array, font: Font, width: float) -> String:
	var entries: Array[String]
	for pair: Array in deck:
		entries.append(str(GameData.card_def(str(pair[0])).get("name", str(pair[0]))) + (" ×%d" % int(pair[1]) if int(pair[1]) > 1 else ""))
	var lines: Array[String]
	var counts: Array[int]
	for entry: String in entries:
		if lines.is_empty() or font.get_string_size(lines.back() + " · " + entry, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x > width:
			lines.append(entry)
			counts.append(1)
		else:
			lines[-1] += " · " + entry
			counts[-1] += 1
	if lines.size() > 8:
		var shown: int = 0
		for index: int in range(7):
			shown += counts[index]
		lines.resize(7)
		lines.append("+%d more" % (entries.size() - shown))
	return "\n".join(lines)
