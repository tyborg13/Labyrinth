extends "res://tools/qa107/layout_sweep.gd"
## Reuse the QA-107 profiles, settling, geometry witnesses and native capture.
## UI33_CASE selects a single capture. With it unset, sweep the authored catalog.
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const HalfHealth = preload("res://scripts/battlefield_rules/half_health.gd")
const Hoarder = preload("res://scripts/hoarder_room_rules.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const PatternText = preload("res://scripts/pattern_text.gd")
const WARBAND_BIOMES := {"stormcaller": "air", "slagmaster": "fire", "oracle": "ice",
	"dynamo": "lightning", "thornmother": "earth", "prior": "shadow"}
const GUARDIANS := ["ashen_reaver", "rimejaw", "storm_cantor", "gallows_roc", "craghide", "last_lamplighter"]
const DRAGONS := ["vyraketh", "tharokh", "iskaldra", "vaeloryx", "zekarion", "noctyrax"]
const SPECIAL_TIER: int = 2
const FIRST_DRAGON_DEPTH: int = 4
const FINAL_DRAGON_DEPTH: int = 24
const RECT_TOLERANCE: float = 0.01
const REQUIRED_BOTTOM_MARGIN: float = 8.0
const REQUIRED_RELIC_GAP: float = 12.0
const RESIZE_HEIGHT: int = 704
const TRAVEL_WAIT_SECONDS: float = 4.0
const PSEUDO_LOCALE: String = "en_GB"
const PSEUDO_EXPANSION: float = 1.6
const SPECIAL_PROOFS := ["reach_exit/undo", "reach_exit/held_undo", "reach_exit/resize", "reach_exit/locale",
	"tharokh/switch", "ember_hoarder/tier_switch", "reach_exit/objective", "reach_exit/paragraph"]
const CROWDED_CASES := ["noctyrax/relics40", "noctyrax/relics60", "reach_exit/relics40", "reach_exit/relics60"]
const PROOF_HEIGHT_INCREASE: float = 19.0
const PROOF_PARAGRAPH_SPACING: int = 12

var selected_case: String
var baseline: bool
var clipped: int
var overlaps: int
var offscreen: int
var undo_passes: int

func _initialize() -> void:
	selected_case = OS.get_environment("UI33_CASE")
	baseline = OS.get_environment("UI33_BASELINE") == "1"
	# Select QA-107's Reach the Exit route to skip the unrelated census tour.
	# This override supplies the full set of battlefield fixtures on that route.
	OS.set_environment("QA107_STATE", "reach_exit")
	OS.set_environment("QA107_HOVER", "")
	super._initialize()

func _extra_fixtures() -> void:
	if native and selected_case.is_empty():
		errors.append("Set UI33_CASE to capture a single rule.")
		return
	var cases: Array[String] = preload("res://scripts/typed_arrays.gd").strings(["reach_exit"])
	for id: String in Rules.data()["instances"]:
		cases.append(id)
		if Rules.data()["instances"][id].has("at_half_health"):
			cases.append(id + "/half_health")
	for tier: int in [1, 2, 3]:
		cases.append("ember_hoarder/%d" % tier)
	if selected_case == "crowded":
		cases.assign(CROWDED_CASES)
	elif not selected_case.is_empty():
		if not cases.has(selected_case) and not SPECIAL_PROOFS.has(selected_case) and not CROWDED_CASES.has(selected_case):
			errors.append("Unknown UI33_CASE: " + selected_case)
			return
		cases.clear()
		cases.append(selected_case)
	var builder := Fixtures.new()
	for key: String in cases:
		await _visit_rule(builder, key)
	builder.free()
	print("UI33 RESULT: profile=%s cases=%d undo_passes=%d clipped=%d overlaps=%d offscreen=%d errors=%d" %
		[profile, states, undo_passes, clipped, overlaps, offscreen, errors.size()])

func _build_fixture(builder: Fixtures, id: String, variant: String) -> Dictionary:
	if WARBAND_BIOMES.has(id):
		return builder.make("warband", run_seed, {"warband_biome": WARBAND_BIOMES[id], "warband_tier": SPECIAL_TIER})
	if id.begins_with("snare_"):
		return builder.make("snare", run_seed, {"snare_biome": id.trim_prefix("snare_"), "snare_tier": SPECIAL_TIER})
	if id in GUARDIANS:
		return builder.make("guardian", run_seed, {"guardian_id": id})
	if id in DRAGONS:
		var depth: int = FINAL_DRAGON_DEPTH if id == "noctyrax" else FIRST_DRAGON_DEPTH
		return builder.make("dragon", run_seed, {"dragon_id": id, "dragon_depth": depth})
	if id == "ember_hoarder":
		return builder.make(id, run_seed, {"hoarder_tier": 1 if variant == "tier_switch" else int(variant)})
	if id == "gale_herald":
		return builder.make("combat", run_seed, {"enemy_types": id})
	return builder.make(id, run_seed)

func _visit_rule(builder: Fixtures, key: String) -> void:
	var id: String = key.get_slice("/", 0)
	var variant: String = key.get_slice("/", 1)
	var state: Dictionary = _build_fixture(builder, id, variant)
	if state.is_empty():
		errors.append(key + ": " + builder.census_error)
		return
	var stock: int = int(variant.trim_prefix("relics")) if variant.begins_with("relics") else 0
	if stock > 0:
		state["relics"] = GameData.relic_ids().slice(0, stock)
	var combat: Dictionary = state["combat_state"]
	if id == "gale_herald":
		# The ordinary Call is the only catalog entry absent at encounter start.
		var call: Dictionary = GameData.enemy_def(id)["intents"][0]["actions"][0]
		Rules.install_call(Combat.new(), combat, 0, call)
	if variant == "half_health" and not _switch_half_health(combat):
		errors.append(key + ": half-health rule did not switch")
		return
	var expected: Dictionary = Hoarder.panel(combat) if id == "ember_hoarder" else Rules.panel(combat)
	var authored_id: String = "snare_earth" if id == "reach_exit" else id
	var authored: Dictionary = Rules.data()["instances"].get(authored_id, {})
	if variant == "half_health":
		authored = authored["at_half_health"]
	if expected.is_empty() or (id != "ember_hoarder" and expected["sentence"] != authored.get("sentence")):
		errors.append(key + ": fixture did not install the authored sentence")
		return
	await _enter_scene("res://scenes/run_scene.tscn")
	scene.set("_progression", state["progression"])
	scene.call("_load_run_state", state)
	scene.call("_close_dialogue")
	await settle()
	await create_timer(SETTLE_SECONDS).timeout
	await _frames(SETTLE_FRAMES)
	if variant in ["undo", "resize"]:
		await _check_entry(key, variant == "resize")
	if variant in ["undo", "held_undo"]:
		if variant == "held_undo": _hold_hand_layout()
		var before_walk: Dictionary = _column(key)
		if not await _make_reversible_walk():
			errors.append(key + ": no reversible walk opened Undo move")
			return
		var after_walk: Dictionary = _column(key)
		after_walk.erase("_movement_undo_button")
		_expect(after_walk == before_walk, key + ": left stack moved during the reversible step")

	var hud: Control = scene.get("_battlefield_rule_hud")
	var sentence: Label = hud.find_child("RuleSentence", true, false)
	var expected_label: String = PatternText.strip(PatternText.display_rules(expected["sentence"]))
	if not sentence.is_visible_in_tree() or sentence.text != expected_label:
		errors.append("%s: live HUD visible=%s sentence=%s" % [key, sentence.is_visible_in_tree(), sentence.text])
		return

	var displayed: String = expected_label
	var translation: Translation
	var old_locale: String = TranslationServer.get_locale()
	if variant == "locale":
		displayed += " " + expected_label.left(roundi(expected_label.length() * (PSEUDO_EXPANSION - 1.0)) - 1)
		translation = Translation.new()
		translation.locale = PSEUDO_LOCALE
		translation.add_message(expected_label, displayed)
		var before: int = hud.get("wrap_measurements")
		_hold_hand_layout()
		TranslationServer.add_translation(translation)
		TranslationServer.set_locale(PSEUDO_LOCALE)
		await _frames(SETTLE_FRAMES)
		var measurements: int = int(hud.get("wrap_measurements")) - before
		_expect(measurements == 1 and sentence.get_total_character_count() == displayed.length() and sentence.get_line_count() > 4,
			key + ": translated text was not remeasured once")
		print("UI33 LOCALE: characters=%d→%d visible=%d total=%d measurements=%d" %
			[expected_label.length(), displayed.length(), sentence.get_visible_line_count(), sentence.get_line_count(), measurements])

	if variant == "objective":
		await _check_objective_minimum(key)
	if variant == "paragraph":
		await _check_paragraph_spacing(hud, sentence)
	if variant in ["switch", "tier_switch"]:
		await _check_rule_switch(key, id, hud)
		displayed = sentence.text

	var metrics: Dictionary = Check.text_data(sentence)
	var wrap_key: Array = hud.get("_wrap_key")
	_expect(not wrap_key.is_empty() and is_equal_approx(float(wrap_key[0]), sentence.size.x), key + ": measured width differs from allocated width")
	var column: Dictionary = _column(key)
	var row: Dictionary = {"case": key, "text": expected["sentence"], "label": displayed, "visible_lines": metrics["visible_lines"],
		"lines": metrics["lines"], "sentence_rect": Check.rect_data(Check.bounds(sentence, root)), "column": column}
	var relics: Control = scene.get("relic_bar")
	if relics.is_visible_in_tree():
		row["relic_gap"] = float(column["_battlefield_rule_hud"][1]) - float(scene.call("_relic_bar_visible_bottom_y"))
	if stock > 0:
		var badges: int = 0
		for badge: Node in scene.get("_relic_icon_grid").get_children():
			if badge.has_meta("relic_id"): badges += 1
		_expect(badges == stock, key + ": incorrect relic badge count")
		row["relic_badges"] = badges
		var home: Rect2 = scene.get("_combat_objective_dock_home")
		_expect(float(column["_combat_objective_hud"][1]) <= home.position.y + RECT_TOLERANCE, key + ": dock moved below the release home")
	states += 1
	if metrics["visible_lines"] != metrics["lines"] or float(metrics["available"][1]) + RECT_TOLERANCE < float(metrics["content_height"]):
		clipped += 1
		if not baseline:
			errors.append(key + ": clipped rule " + sentence.text)
	if variant in ["undo", "held_undo"]:
		_add_undo_witness(row)
	elif not native:
		await _check_undo_toggle(row)
	record("rule", row)
	print("UI33 RULE " + JSON.stringify(row))
	if native:
		await snapshot(key, "", {}, Array([], TYPE_OBJECT, &"Node", null))
	if translation != null:
		TranslationServer.remove_translation(translation)
		TranslationServer.set_locale(old_locale)

func _expect(condition: bool, problem: String) -> void:
	if not condition: errors.append(problem)

func _hold_hand_layout() -> void:
	# Loaded fixtures start after the opening deal. Mark the current hand home
	# as placed without running unrelated board-entry framing.
	var layout: RefCounted = scene.get("_combat_hud_layout")
	layout.set("_placed", true)
	layout.set("_environment", layout.call("_environment_for", scene))
	_expect(layout.holds_layout(scene), "Expected the hand-layout hold to be active")

func _check_entry(key: String, resize: bool) -> void:
	var hud: Control = scene.get("_battlefield_rule_hud")
	var objective: Control = scene.get("_combat_objective_hud")
	var entry_counts: Vector2i = _dock_counts()
	var count_at_load: int = hud.get("wrap_measurements")
	if resize:
		scene.call("_animate_combat_objective_intro")
	else:
		scene.call("_present_opening_hand_after_combat_entry")
	var deadline: int = Time.get_ticks_msec() + int(TRAVEL_WAIT_SECONDS * 1000.0)
	while objective.get("intro_phase") != "traveling" and Time.get_ticks_msec() < deadline:
		await process_frame
	if objective.get("intro_phase") != "traveling":
		errors.append(key + ": objective never reached its travel phase")
		return
	var original_target: Rect2 = scene.get("_combat_objective_intro_dock")
	var travel_counts: Vector2i = _dock_counts()
	var count_at_travel: int = hud.get("wrap_measurements")
	var travel_frames: int = 0
	if resize: root.size.y = RESIZE_HEIGHT
	while objective.get("intro_phase") == "traveling" and Time.get_ticks_msec() < deadline:
		travel_frames += 1
		await process_frame
	var travel_work: Vector2i = _dock_counts() - travel_counts
	await settle()
	var entry_work: Vector2i = _dock_counts() - entry_counts
	print("UI33 DOCK WORK: entry chips=%d undo=%d travel chips=%d undo=%d" % [entry_work.x, entry_work.y, travel_work.x, travel_work.y])
	var settled: Rect2 = objective.get_rect()
	var expected: Rect2 = scene.call("_combat_objective_hud_target_rect")
	var measurements: int = int(hud.get("wrap_measurements")) - count_at_load
	var traveling: int = int(hud.get("wrap_measurements")) - count_at_travel
	_expect(count_at_load == 1 and measurements == 0 and traveling == 0 and travel_frames > 0, key + ": repeated wrap measurement")
	_expect(settled.is_equal_approx(expected), key + ": settled dock differs from current viewport target")
	_expect(travel_work.y == 0 and travel_work.x <= (1 if resize else 0),
		key + ": repeated chip placement or Undo refresh during travel")
	if resize:
		_expect(root.size.y == RESIZE_HEIGHT and not original_target.is_equal_approx(settled), key + ": resize did not move dock")
	print("UI33 ENTRY: load=%d intro=%d travel=%d travel_frames=%d resize=%s original=%s settled=%s expected=%s" %
		[count_at_load, measurements, traveling, travel_frames, resize, original_target, settled, expected])

func _dock_counts() -> Vector2i:
	return Vector2i(scene.get("_ui33_chip_layouts"), scene.get("_movement_undo_button").get("_ui33_refreshes"))

func _check_objective_minimum(key: String) -> void:
	_hold_hand_layout()
	var objective: Control = scene.get("_combat_objective_hud")
	var starting_rect: Rect2 = objective.get_rect()
	objective.custom_minimum_size.y = starting_rect.size.y + PROOF_HEIGHT_INCREASE
	await _frames(SETTLE_FRAMES)
	var fitted: Rect2 = objective.get_rect()
	_expect(is_equal_approx(fitted.end.y, starting_rect.end.y) and fitted.size.y > starting_rect.size.y,
		key + ": objective growth was not refitted against the bottom reserve")
	print("UI33 OBJECTIVE MINIMUM: before=%s after=%s" % [starting_rect, fitted])

func _check_paragraph_spacing(hud: Control, sentence: Label) -> void:
	_hold_hand_layout()
	var source: String = sentence.text
	sentence.text += "\n" + source
	await _frames(SETTLE_FRAMES)
	var height: float = hud.size.y
	var measurements: int = hud.get("wrap_measurements")
	var spacing: int = sentence.get_theme_constant("paragraph_spacing")
	sentence.add_theme_constant_override("paragraph_spacing", spacing + PROOF_PARAGRAPH_SPACING)
	await _frames(SETTLE_FRAMES)
	var delta: int = int(hud.get("wrap_measurements")) - measurements
	_expect(delta == 1 and is_equal_approx(hud.size.y - height, float(PROOF_PARAGRAPH_SPACING)),
		"Paragraph spacing did not update rule height once")
	print("UI33 PARAGRAPH: height=%.1f→%.1f measurements=%d" % [height, hud.size.y, delta])

func _switch_half_health(combat: Dictionary) -> bool:
	var rule: Dictionary = combat["battlefield_rule"]
	for foe: Dictionary in combat["enemies"]:
		if int(foe["id"]) == int(rule["source"]["id"]):
			foe["hp"] = floori(float(foe["max_hp"]) * 0.5)
	return HalfHealth.check(combat)

func _check_rule_switch(key: String, id: String, hud: Control) -> void:
	_hold_hand_layout()
	var switched: Dictionary = scene.get("_combat_state").duplicate(true)
	var layout: RefCounted = scene.get("_combat_hud_layout")
	var before: int = hud.get("wrap_measurements")
	var panel: Dictionary
	if id == "ember_hoarder":
		switched["objective"]["escape_after_player_turns"] = Hoarder.escape_turn(3)
		panel = Hoarder.panel(switched)
	else:
		_expect(_switch_half_health(switched), key + ": half-health transition failed")
		panel = Rules.panel(switched)
	scene.call("_refresh_battlefield_rule_hud", switched)
	await _frames(SETTLE_FRAMES)
	var sentence: Label = hud.find_child("RuleSentence", true, false)
	var delta: int = int(hud.get("wrap_measurements")) - before
	_expect(layout.holds_layout(scene) and delta == 1 and sentence.text == panel["sentence"], key + ": held rule change did not reflow once")
	print("UI33 SWITCH: case=%s held=%s measurements=%d visible=%d total=%d" %
		[key, layout.holds_layout(scene), delta, sentence.get_visible_line_count(), sentence.get_line_count()])

func _check_undo_toggle(row: Dictionary) -> void:
	var key: String = row["case"]
	_hold_hand_layout()
	var undo: Control = scene.get("_movement_undo_button")
	var history: RefCounted = undo.get("rules")
	# Exercise the real visibility and placement paths independently of movement
	# animation or whether this encounter starts with a reversible destination.
	history.get("_history").append({"state": scene.get("_combat_state"), "tiles": 1})
	undo.refresh()
	await _frames(SETTLE_FRAMES)
	var shown: Dictionary = _column(key)
	_expect(undo.is_visible_in_tree(), key + ": staged Undo did not become visible")
	if undo.is_visible_in_tree(): _add_undo_witness(row)
	shown.erase("_movement_undo_button")
	_expect(shown == row["column"], key + ": stack moved when Undo appeared")
	history.clear()
	undo.refresh()
	await _frames(SETTLE_FRAMES)
	_expect(not undo.is_visible_in_tree() and _column(key) == row["column"], key + ": stack moved when Undo disappeared")

func _add_undo_witness(row: Dictionary) -> void:
	var undo: Control = scene.get("_movement_undo_button")
	var rect: Rect2 = Check.bounds(undo, root)
	var margin: float = root.get_visible_rect().end.y - rect.end.y
	row["undo_rect"] = Check.rect_data(rect)
	row["undo_bottom_margin"] = margin
	undo_passes += 1
	_expect(margin + RECT_TOLERANCE >= REQUIRED_BOTTOM_MARGIN, str(row["case"]) + ": Undo bottom margin %.3f" % margin)

func _make_reversible_walk() -> bool:
	var before: Dictionary = scene.get("_combat_state")
	var engine: RefCounted = scene.get("_combat_engine")
	for tile: Vector2i in engine.player_movement_targets(before):
		var after: Dictionary = engine.apply_player_movement(before, tile)
		if not bool(after.get("last_player_movement", {}).get("undo_report", {}).get("reversible", false)):
			continue
		await scene.call("_on_board_tile_clicked", before["player"]["pos"])
		await scene.call("_on_board_tile_clicked", tile)
		await settle()
		await _frames(SETTLE_FRAMES)
		return scene.get("_movement_undo_button").is_visible_in_tree()
	return false

func _column(key: String) -> Dictionary:
	var fields: Array[String] = preload("res://scripts/typed_arrays.gd").strings(["_battlefield_rule_hud", "_combat_objective_hud", "_play_meter", "_movement_meter", "_movement_undo_button"])
	var viewport: Rect2 = root.get_visible_rect().grow(RECT_TOLERANCE)
	var column: Dictionary = {}
	var previous := Rect2()
	for field: String in fields:
		var control: Control = scene.get(field)
		if not control.is_visible_in_tree():
			if field != "_movement_undo_button": errors.append(key + ": hidden " + field)
			continue
		var rect: Rect2 = Check.bounds(control, root)
		column[field] = Check.rect_data(rect)
		if not viewport.encloses(rect):
			offscreen += 1
			if not baseline: errors.append(key + ": offscreen " + field)
		if previous.end.y > rect.position.y + RECT_TOLERANCE:
			overlaps += 1
			if not baseline: errors.append(key + ": overlap above " + field)
		previous = rect
	var relics: Control = scene.get("relic_bar")
	if relics.is_visible_in_tree() and column.has("_battlefield_rule_hud") and not key.contains("/relics"):
		var gap: float = float(column["_battlefield_rule_hud"][1]) - float(scene.call("_relic_bar_visible_bottom_y"))
		_expect(gap + RECT_TOLERANCE >= REQUIRED_RELIC_GAP, key + ": relic clearance %.3f" % gap)
	return column
