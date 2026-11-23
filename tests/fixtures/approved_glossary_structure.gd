extends RefCounted

# Owner-approved round-1 area-card sets supersede the protected historical capture.
static var _txt02_panels: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/txt02_approved_card_panels.json"))["panels"]

# pla-04 (owner-approved playability plan 2026-11-20): the Burst cards show one
# Burst panel after their condition ground ("On Fire:"), with each card's v5
# behaviour (Frost Heave, Magma Vent, Rockburst and Dust Devil gain a baseline;
# Shatter's Ice replaces Freeze; Worldbreak's line becomes the Burst).
const PLA04_BURST_PANELS: Dictionary = {
	"cinderline_tempo": ["ranged", "range", "surface_fire", "burst"],
	"inferno_ritual": ["ranged", "range", "surface_fire", "burst"],
	"wildfire_halo": ["ranged", "range", "surface_fire", "burst"],
	"phoenix_cleave": ["exhaust", "health_cost", "melee", "surface_fire", "burst"],
	"rekindle_edge": ["melee", "surface_fire", "burst"],
	"cinder_second": ["block", "draw", "surface_fire", "burst", "range"],
	"discharge": ["surface_electrified", "burst", "range"],
	"dust_devil": ["surface_rubble", "burst", "range", "push"],
	"flashsteam": ["ranged", "range", "surface_ice", "burst"],
	"frost_heave": ["ranged", "range", "immobilize", "surface_ice", "burst"],
	"immolation": ["melee", "surface_fire", "burst", "empower", "health_cost"],
	"magma_vent": ["ranged", "range", "surface_rubble", "burst", "surface_fire"],
	"plasma_arc": ["ranged", "range", "chain", "surface_fire", "burst"],
	"powder_keg": ["consume", "raise_terrain", "range", "burst"],
	"pyroclasm": ["ranged", "range", "surface_fire", "burst"],
	"rockburst": ["ranged", "range", "burst", "surface_rubble"],
	"shatter": ["ranged", "range", "surface_ice", "burst"],
	"shatter_swing": ["melee", "surface_ice", "burst"],
	"shattered_reflection": ["burst", "range", "illuminate", "time"],
	"worldbreak": ["burst", "stagger"],
}

static var _ice_panels: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/pla06_ice_copy.json"))["card_panel_icons"]

const PLA07_PANELS: Dictionary = {
	"cleaver_hook": ["pierce"],
	"sawtooth_flurry": ["melee", "expose"],
	"serrated_slip": ["move", "melee", "expose", "expose"],
	"backhand_nick": ["melee", "expose", "draw"],
	"hookspine_reap": ["melee", "range", "pull"],
	"sweeping_haft": ["melee", "pierce"],
	"nail_parry": ["block", "pierce"],
	"anchor_slam": ["stoneskin", "melee", "range", "immobilize", "pull"],
	"rooted_kick": ["move", "melee", "push", "surface_rubble"],
	"royal_bramble": ["melee", "range", "pull", "empower", "health_cost", "expose"],
	"nail_bomb": ["consume", "ranged", "range", "pierce"],
	"caltrops": ["consume", "ranged", "range", "expose", "surface_rubble"],
	"barbed_mail": ["block", "retaliate"],
}

const PLA09_PANELS: Dictionary = {
	"tectonic_maul": ["melee", "stagger", "surface_rubble"],
	"frost_circuit": ["surface_electrified", "ranged", "range", "shock"],
	"grounding": ["stoneskin", "surface_consume", "surface_electrified"],
	"stoke": ["all_enemies", "surface_fire"],
}

# Gear-02's fresh starter cards supersede the historical panel stacks.
const GEAR02_PANELS: Dictionary = {
	"quick_stab": ["melee"],
	"guarded_step": ["move", "block"],
	"shadow_step": ["move"],
	"patch_up": ["block"],
	"bloody_lunge": ["move", "melee"],
	"hamstring_shot": ["move", "melee", "push"],
}

static var _pla09_copy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/pla09_card_copy.json"))

static func apply_pla09_copy(definitions: Dictionary, grimoire_bodies: Dictionary) -> void:
	definitions.merge(_pla09_copy["glossary_definitions"], true)
	for owner: String in _pla09_copy["grimoire_lines"]:
		if not grimoire_bodies.has(owner):
			continue
		var lines: Dictionary = _pla09_copy["grimoire_lines"][owner]
		for index: String in lines:
			grimoire_bodies[owner][int(index)] = lines[index]

static func entries(id: String, historical: Dictionary) -> Array:
	if id == "ember_jab":
		# Old decks resolve Measured Cut to Backhand Nick.
		id = "backhand_nick"
	if GEAR02_PANELS.has(id):
		return (GEAR02_PANELS[id] as Array).map(func(icon: String) -> Dictionary: return {"icon": icon, "body_lines": 1})
	if PLA09_PANELS.has(id):
		return (PLA09_PANELS[id] as Array).map(func(icon: String) -> Dictionary: return {"icon": icon, "body_lines": 1})
	if PLA07_PANELS.has(id):
		return (PLA07_PANELS[id] as Array).map(func(icon: String) -> Dictionary: return {"icon": icon, "body_lines": 1})
	if _ice_panels.has(id):
		var ice_panels: Array = []
		for icon: String in _ice_panels[id]:
			ice_panels.append({"icon": icon, "body_lines": 1})
		return ice_panels
	if PLA04_BURST_PANELS.has(id):
		var burst_panels: Array = []
		for icon: String in PLA04_BURST_PANELS[id]:
			burst_panels.append({"icon": icon, "body_lines": 1})
		return burst_panels
	if id == "worldspine":
		return [{"icon": "rite", "body_lines": 1}, {"icon": "raise_terrain", "body_lines": 1}, {"icon": "range", "body_lines": 1}]
	if id == "meteorfall":
		# txt-28 puts the damage explanation in Cinder Marks and retires the Ranged panel.
		return [{"icon": "cinder_marks", "body_lines": 1}, {"icon": "range", "body_lines": 1}, {"icon": "surface_fire", "body_lines": 1}]
	if _txt02_panels.has(id):
		var approved: Array = (_txt02_panels[id] as Array).duplicate(true)
		# crd-08 (owner-approved 2026-11-08): Spear Thrust pays off Immobilized targets.
		if id == "spear_thrust": approved.append({"icon": "immobilize", "body_lines": 1})
		return approved
	var expected: Array = (historical[id] as Array).duplicate(true)
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
	var payoff_conditions: Dictionary = {"hobnail_drive": "stagger", "jolt": "shock", "spear_thrust": "immobilize"}
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
		"threadbare_guard": [1, 2, 3],
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
