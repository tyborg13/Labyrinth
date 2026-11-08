extends RefCounted

# Owner-approved round-1 area-card sets supersede the protected historical capture.
static var _txt02_panels: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/txt02_approved_card_panels.json"))["panels"]

static func entries(id: String, historical: Dictionary) -> Array:
	if _txt02_panels.has(id):
		var approved: Array = (_txt02_panels[id] as Array).duplicate(true)
		# crd-08 (owner-approved 2026-11-08): Spear Thrust pays off Immobilized targets.
		if id == "spear_thrust": approved.append({"icon": "immobilize", "body_lines": 1})
		return approved
	var expected: Array = (historical[id] as Array).duplicate(true)
	if id == "petrify":
		# fix-07: the keyword owns its Block; the card prints only Petrify + range.
		expected.pop_back()
	if id == "skybolt":
		# bal-01 (owner-approved 2026-10-23): Skybolt Exhausts; its panel follows Time like other Exhaust cards.
		expected.insert(1, (historical["worldspine"][1] as Dictionary).duplicate(true))
	if id == "immolation":
		# CBT-01 (5e20c1099) added adjacent damage before the existing Detonate.
		# Retain the pre-glossary capture; compose the new damage/pattern prefix
		# from independent historical entries instead of the formatter under test.
		var pattern: Dictionary = expected.pop_at(2)
		expected.insert(1, (historical["quick_stab"][1] as Dictionary).duplicate(true))
		expected.insert(2, pattern)
	# tt-01 drops only the automatic card-cost Time panel, after composing the
	# historical card changes above. Duration tokens still keep their own panel.
	if not expected.is_empty() and expected[0]["icon"] == "time":
		expected.pop_front()
	# qa-35 (owner-approved 2026-11-04): Updraft and Crosswind hit at range, so
	# their hit shows the Ranged keyword instead of Melee.
	if id in ["updraft", "crosswind"]:
		for entry: Dictionary in expected:
			if entry["icon"] == "melee": entry["icon"] = "ranged"
	# crd-02/crd-03 (owner-approved 2026-11-07): Ember Guard leaves Fire under
	# adjacent enemies instead of at range; Cloudstep Loop and Frozen Bite add
	# Draw 1; Shrug Off gains Block before turning all of it into Stoneskin.
	if id == "ember_guard":
		expected = expected.filter(func(entry: Dictionary) -> bool: return entry["icon"] != "range")
	# crd-06 (owner-approved 2026-11-08): Glide and Skate also draw 1.
	if id in ["frozen_bite", "glide", "skate"]:
		expected.append((historical["shrug_off"][3] as Dictionary).duplicate(true))
	if id == "shrug_off":
		expected.insert(0, (historical["brace"][1] as Dictionary).duplicate(true))
	# crd-08/09/11 (owner-approved 2026-11-08): status payoffs show their
	# condition's panel; Hotfoot gains Block (more on Fire) before its move;
	# Joust's hit pushes; Cloudstep Loop draws, then Follow-up grants the Card Play.
	var payoff_conditions: Dictionary = {"serrated_slip": "bleed", "hobnail_drive": "stagger", "jolt": "shock", "spear_thrust": "immobilize"}
	if payoff_conditions.has(id):
		expected.append({"icon": payoff_conditions[id], "body_lines": 1})
	if id == "hotfoot":
		expected = [{"icon": "block", "body_lines": 1}, {"icon": "surface_fire", "body_lines": 1}, {"icon": "move", "body_lines": 1}]
	if id == "joust":
		expected.append({"icon": "push", "body_lines": 1})
	if id == "cloudstep_loop":
		expected = [{"icon": "blink", "body_lines": 1}, {"icon": "draw", "body_lines": 1}, {"icon": "follow_up", "body_lines": 1}, {"icon": "card_play", "body_lines": 1}]
	# tt-02 R1 gives every panel a nonempty, single-line body. R3/R7
	# collapse repeated ground/area meanings; R5 suppresses Cleanse statuses.
	var removed_indexes: Dictionary = {
		"tectonic_maul": [5], "threadbare_guard": [1, 2, 3],
		"cinder_trail": [3], "fan_the_flames": [4], "meteorfall": [3],
		"rockburst": [4], "smelling_salts": [2, 3, 4],
	}
	var indexes: Array = removed_indexes.get(id, [])
	for index: int in range(expected.size() - 1, -1, -1):
		if indexes.has(index): expected.remove_at(index)
	# flu-01 retires the Flurry cost panel without rewriting the historical capture.
	expected = expected.filter(func(entry: Dictionary) -> bool: return entry["icon"] != "flurry")
	for entry: Dictionary in expected: entry["body_lines"] = 1
	return expected
