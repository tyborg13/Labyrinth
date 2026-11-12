extends RefCounted

const ForecastPanel = preload("res://scripts/pass_forecast_focus_tooltip.gd")

static func inks(scene: Node) -> Dictionary:
	return {
		"block": scene.call("_pass_preview_damage_entries", {"block": 1})[0]["color"],
		"stoneskin": scene.call("_pass_preview_damage_entries", {"stoneskin": 1})[0]["color"],
		"health": scene.call("_pass_preview_damage_entries", {"hp": 1})[0]["color"],
		"defiance": scene.call("_pass_preview_damage_entries", {"defiance_spent": 1})[0]["color"],
		"unknown": scene.call("_pass_preview_forecast_entries", {"umbra_unknown_before_player": true})[0]["color"]
	}

static func text(scene: Node, summary: Dictionary, portraits: Array[Dictionary] = []) -> String:
	var lines := PackedStringArray()
	for row: Dictionary in ForecastPanel.rows(summary, portraits, inks(scene)):
		var parts := PackedStringArray()
		if row.has("portrait"): parts.append("portrait:" + str(row["portrait"]["actor_key"]))
		for part: Dictionary in row["parts"]: parts.append(str(part["icon"]) + ":" + str(part["text"]))
		lines.append(" ".join(parts))
	return "\n".join(lines)

static func run(scene: Node, expect: Callable) -> void:
	var portraits: Array[Dictionary]
	for key: String in ["enemy:a", "enemy:b", "enemy:c"]:
		portraits.append({"actor_key": key, "path": "res://assets/art/portraits/tunnel_crawler.png", "aspect": 4.0 / 3.0})
	var summary: Dictionary = {"wait_time": 5, "block_loss": 2, "hp_loss": 3, "fatigue_loss": 15, "defiance_spent": 1, "projected_hp": 4, "projected_max_hp": 24, "umbra_unknown_before_player": true, "forecast_limit_reached": true}
	expect.call(text(scene, summary, portraits) == "time:+5\nblock:−2 health:−3\nportrait:enemy:a :×2 :?\nportrait:enemy:b :×2 :?\nfatigue:−15\ndefiance:−1 → 4/24\numbra:?\nturn_clock:?", "Icon rows preserve exact order, values and two-foe cap without sentences")
	expect.call(text(scene, {}) == ":Safe", "Safe is the only zero-loss part; no unused-play Time row")
	expect.call(text(scene, {"hp_loss": 5}) == "health:−5", "Health-only loss omits zero Block")
	expect.call(text(scene, {"block_loss": 5}) == "block:−5", "Block-only loss omits zero Health")
	expect.call(text(scene, {"defiance_spent": 2}).contains("defiance:−2 → ?/?"), "Unknown projected Health never displays privacy sentinels")
	var rows: Array[Dictionary] = ForecastPanel.rows(summary, portraits, inks(scene))
	expect.call(rows[1]["parts"][0]["color"] == inks(scene)["block"] and rows[1]["parts"][1]["color"] == inks(scene)["health"] and rows[2]["parts"][0]["color"] == inks(scene)["unknown"], "Panel uses existing forecast cell inks")
	for key: String in ["time", "block", "health", "fatigue", "defiance", "umbra", "turn_clock"]:
		expect.call(preload("res://scripts/action_icon_library.gd").icon_texture(key) != null, "Approved icon resolves: " + key)

	var saved_entries: Array[Dictionary] = scene.get("_turn_order_all_entries")
	var projection: Array[Dictionary]
	projection.append({"kind": "player", "active": true})
	projection.append({"kind": "enemy", "actor_key": "a", "name": "Same", "type": "crawler"})
	projection.append({"kind": "enemy", "actor_key": "b", "name": "Same", "type": "crawler"})
	projection.append({"kind": "enemy", "actor_key": "a", "name": "Same", "type": "crawler"})
	projection.append({"kind": "player", "active": false})
	scene.set("_turn_order_all_entries", projection)
	var resolved: Array[Dictionary] = preload("res://scripts/turn_order_slots.gd").pass_repeat_portraits(scene, {"repeated_enemy_names": ["Same"]})
	expect.call(resolved.size() == 1 and str(resolved[0]["actor_key"]) == "enemy:a", "Shared enemy names cannot badge an actor that acts only once")
	scene.set("_turn_order_all_entries", saved_entries)
