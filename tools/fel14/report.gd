extends RefCounted

const PATH := "res://tools/fel14/"
const WORST_COUNT := 15
const PHASES := ["rest", "hover", "enemy_turn"]
const KINDS := [
	"unit_health", "terrain_health", "status_chip", "defense_chip", "charge_pip", "intent_badge", "intent_tab",
	"expanded_intent", "tile_damage_badge", "intent_compass", "leader_crest", "mark_medallion", "collision_badge", "lethal_icon",
	"damage_popup", "heal_popup", "block_popup", "stoneskin_popup", "draw_popup", "card_play_popup",
	"effect_popup", "intent_result", "action_caption", "objective_threshold", "objective_leader",
	"door_medallion", "door_focus_chevron", "summon_marker", "brazier_callout", "seals_pill", "friendly_damage_chip", "movement_risk_chip",
	"loot_icon", "trap_icon", "npc_name", "board_status", "boss_name", "boss_health", "boss_status", "turn_banner"
]

var states: Array[Dictionary]
var fixtures: Array[Dictionary]
var worst: Array[Dictionary]
var label_count: int = 0
var collision_count: int = 0
var failure: String
var _matrix: Dictionary = {}
var _overlaps: Array[Dictionary]
var _counts: Dictionary = {}

func add(state: Dictionary) -> void:
	states.append(state)
	var labels: Array = state["labels"]
	label_count += labels.size()
	for row: Dictionary in labels:
		var kind: String = row["kind"]
		_counts[kind] = int(_counts.get(kind, 0)) + 1
	for pair: Array in state["pairs"]:
		if float(pair[2]) <= 0.0 and float(pair[4]) <= 0.0: continue
		var lower: Dictionary = labels[int(pair[0])]
		var upper: Dictionary = labels[int(pair[1])]
		_overlaps.append({"fixture": state["fixture"], "phase": state["phase"], "samples": state["samples"],
			"frame": state["frame"], "beat": state["beat"], "state_index": states.size() - 1, "lower": lower,
			"upper": upper, "area_px2": pair[2], "overlap_share": pair[3], "text_loss": pair[4], "counts": pair[5]})
		if not pair[5]: continue
		collision_count += 1
		var key: String = _key(lower["kind"], upper["kind"])
		var split: Dictionary = _matrix.get_or_add(key, {"rest": 0, "hover": 0, "enemy_turn": 0})
		split[state["phase"]] += 1

func finish(write: bool) -> bool:
	_overlaps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["counts"] != b["counts"]: return a["counts"]
		if a["text_loss"] != b["text_loss"]: return a["text_loss"] > b["text_loss"]
		if a["overlap_share"] != b["overlap_share"]: return a["overlap_share"] > b["overlap_share"]
		if a["area_px2"] != b["area_px2"]: return a["area_px2"] > b["area_px2"]
		if a["state_index"] != b["state_index"]: return a["state_index"] < b["state_index"]
		if a["lower"]["order"] != b["lower"]["order"]: return a["lower"]["order"] < b["lower"]["order"]
		return a["upper"]["order"] < b["upper"]["order"])
	for index: int in range(mini(WORST_COUNT, _overlaps.size())):
		var row: Dictionary = _overlaps[index]
		row["rank"] = index + 1
		worst.append(row)
	if not write: return true
	var kinds: Array[String]
	kinds.assign(KINDS)
	for kind: String in _counts:
		if not kinds.has(kind): kinds.append(kind)
	var never: Array
	for i: int in range(kinds.size()):
		for j: int in range(i, kinds.size()):
			if not _matrix.has(_key(kinds[i], kinds[j])): never.append([kinds[i], kinds[j]])
	var payload := {"schema": 1, "size": [1920, 1080], "ui_scale": 1.0,
		"pair_columns": ["lower_order", "upper_order", "overlap_px2", "overlap_share_of_smaller", "text_loss", "collision"],
		"unit_hit_columns": ["label_order", "unit_id", "opaque_pixels", "share_of_text_or_glyph_rect", "at_least_15_percent"],
		"fixtures": fixtures, "states": states, "kinds": kinds, "kind_instances": _counts,
		"collision_matrix": _matrix, "never_collided": never, "worst": worst}
	return _write_json(PATH + "census.json", payload) and _write(PATH + "census.md", _markdown(kinds, never))

func _markdown(kinds: Array[String], never: Array) -> String:
	var out := PackedStringArray(["# Board label overlap census", "",
		"%d fixtures · %d sampled frames · %d label instances · %d counted collisions." % [
			fixtures.size(), states.size(), label_count, collision_count], "",
		"See [the label inventory and measurement notes](result.md). Each matrix cell is **rest / hover / enemy turn**. A dot means zero in all three phases. The matrix is symmetric.", "",
		"| ID | Label kind | Instances |", "|---:|---|---:|"])
	for i: int in range(kinds.size()): out.append("| %d | %s | %d |" % [i + 1, kinds[i], _counts.get(kinds[i], 0)])
	var header := PackedStringArray(["Kind"])
	var divider := PackedStringArray(["---:"])
	for i: int in range(kinds.size()):
		header.append(str(i + 1))
		divider.append("---:")
	out.append_array(["", "## Collision matrix", "", _table_row(header), _table_row(divider)])
	for i: int in range(kinds.size()):
		var cells := PackedStringArray([str(i + 1)])
		for kind: String in kinds:
			var split: Dictionary = _matrix.get(_key(kinds[i], kind), {})
			cells.append("·" if split.is_empty() else "%d / %d / %d" % [split["rest"], split["hover"], split["enemy_turn"]])
		out.append(_table_row(cells))
	out.append_array(["", "## Worst 15", "",
		"Ranked by lower-label text loss, then smaller-label overlap and overlap area. Below-threshold overlaps fill any remaining ranks.", "",
		"| Rank | Fixture | Frame | State | Lower | Upper | Overlap px² | Smaller | Text loss | Counts |",
		"|---:|---|---:|---|---|---|---:|---:|---:|---|"])
	for row: Dictionary in worst:
		var state: String = row["phase"]
		if not (row["beat"] as Dictionary).is_empty():
			state += " %s %s %s" % [row["beat"]["number"], row["beat"]["kind"], ", ".join(row["samples"])]
		out.append("| %d | %s | %d | %s | %s | %s | %.1f | %.1f%% | %.1f%% | %s |" % [
			row["rank"], row["fixture"], row["frame"], state, _label(row["lower"]), _label(row["upper"]),
			row["area_px2"], row["overlap_share"] * 100.0, row["text_loss"] * 100.0, "yes" if row["counts"] else "no"])
	out.append_array(["", "## Pairs with zero counted collisions", "",
		"%d unordered kind pairs had zero counts. Each line lists its peers in the matrix’s upper triangle. Kinds with zero instances had no opportunity to collide." % never.size(), ""])
	for kind: String in kinds:
		var peers := PackedStringArray()
		for pair: Array in never:
			if pair[0] == kind: peers.append(pair[1])
		if not peers.is_empty(): out.append("- **%s** — %s" % [kind, ", ".join(peers)])
	out.append_array(["", "## Text and upper-body silhouette overlap", "",
		"| Fixture | Rest ≥15% | Hover ≥15% | Enemy turn ≥15% | Any positive overlap |", "|---|---:|---:|---:|---:|"])
	for fixture: Dictionary in fixtures:
		var tallies: Dictionary = {"rest": 0, "hover": 0, "enemy_turn": 0}
		var body_count: int = 0
		for state: Dictionary in states:
			if state["fixture"] != fixture["id"]: continue
			for hit: Array in state["unit_hits"]:
				body_count += 1
				tallies[state["phase"]] += int(hit[4])
		out.append("| %s | %d | %d | %d | %d |" % [fixture["id"], tallies["rest"], tallies["hover"], tallies["enemy_turn"], body_count])
	return "\n".join(out) + "\n"

static func _key(a: String, b: String) -> String:
	return a + "|" + b if a <= b else b + "|" + a

static func _label(row: Dictionary) -> String:
	var owner: Dictionary = row["owner"]
	var source: String = str(owner["id"])
	if source.is_empty() and not (owner["tile"] as Array).is_empty(): source = str(owner["tile"])
	var detail: String = ", ".join(row["text"])
	if detail.is_empty(): detail = row["detail"]
	return ("%s %s %s" % [row["kind"], source, detail]).strip_edges().replace("|", "\\|").replace("\n", " ")

static func _table_row(cells: PackedStringArray) -> String:
	return "| " + " | ".join(cells) + " |"

func _write_json(destination: String, payload: Dictionary) -> bool:
	# Keep the all-pairs table machine readable without a line per scalar.
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		failure = "cannot write " + destination
		return false
	var sections := PackedStringArray()
	for key: String in payload:
		if key == "states": continue
		sections.append(JSON.stringify(key) + ": " + JSON.stringify(payload[key], "", false))
	file.store_line("{")
	file.store_line(",\n".join(sections) + ",")
	file.store_line('"states": [')
	for i: int in range(states.size()):
		file.store_line(JSON.stringify(states[i], "", false) + ("," if i + 1 < states.size() else ""))
	file.store_line("]}")
	return file.get_error() == OK

func _write(destination: String, contents: String) -> bool:
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		failure = "cannot write " + destination
		return false
	return file.store_string(contents)
