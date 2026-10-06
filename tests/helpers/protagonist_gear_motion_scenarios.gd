extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const Gear = preload("res://scripts/protagonist_cutout/gear_visuals.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Playback = preload("res://tests/fixtures/protagonist_gear_motion_run_scene.gd")
const Fx = preload("res://scripts/attack_fx_library.gd")
const L1: Dictionary = {"weapon": "war_maul", "offhand": "ward_kite", "armor": "undertaker_plate", "boots": "ironshod_sabatons", "trinket": "crown_of_thorns"}
const L2: Dictionary = {"weapon": "sawtooth_knife", "offhand": "parrying_dagger", "armor": "cinderweave_mail", "boots": "emberstriders", "trinket": "war_dancer_sash"}

static func run(scene: Node, expect: Callable, capture: Callable = Callable()) -> Array:
	scene.proof_expect = expect
	scene.proof_capture = capture
	var checks: Array = []
	var loadouts: Array = [Gear.DEFAULTS, L1, L2]
	var cards: Array = ["quick_stab", "crushing_blow", "sawtooth_flurry"]
	for index: int in range(3):
		for direction: Vector2i in [Vector2i(0, 1), Vector2i(0, -1)]:
			var label: String = "L%d_%s_%s" % [index, cards[index], "rear_northeast" if direction.y < 0 else "front_southwest"]
			await _fixture(scene, loadouts[index], cards[index], direction)
			scene.proof_mode = "attack"
			scene.proof_label = label
			checks.append(await _play_card(scene, cards[index], direction, expect))
			var archetype: String = Gear.weapon_motion(loadouts[index])
			var expected_clip: String = "attack_heavy" if archetype == "heavy" else "attack_stab" if archetype == "stab" else "attack"
			expect.call(scene.proof_captures.size() == scene.proof_hits.size() * 6, "Every attack captures all six requested checkpoints: " + label)
			for hit: Dictionary in scene.proof_hits:
				expect.call(hit["frames"] == Fx.animation_frame_count({"kind": "melee", "protagonist_melee": true, "protagonist_weapon_motion": archetype}, 6, false), "Gameplay clock uses the equipped archetype: " + expected_clip)
	for index: int in [0, 1]:
		await _fixture(scene, loadouts[index], "quick_stab", Vector2i(0, 1))
		var state: Dictionary = scene.get("_combat_state").duplicate(true)
		state["player"]["block"] = 20
		state["enemies"][0]["intent"] = {"id": "skitter_strike", "name": "Skitter Strike", "time": 5, "actions": [{"type": "melee", "damage": 4, "range": 1, "element": "none"}]}
		var result: Dictionary = Combat.new().resolve_enemy_turn_with_steps(state, 0)
		expect.call(int(result["state"]["player"]["hp"]) == 24 and int(result["state"]["player"]["block"]) < 20, "Real enemy resolver absorbs the hit with block")
		scene.proof_mode = "block"
		scene.proof_label = "L%d_absorbed_enemy_hit_%s" % [index, "sword_block" if index == 1 else "shield_block"]
		await scene.call("_animate_enemy_phase_steps", state, result["steps"])
		expect.call(scene.proof_captures.has(scene.proof_label), "Absorbed enemy hit renders its actual guard reaction")
		checks.append({"label": scene.proof_label, "player_hp": result["state"]["player"]["hp"], "remaining_block": result["state"]["player"]["block"]})
	for card: String in ["guiding_flare", "bone_dart"]:
		await _fixture(scene, Gear.DEFAULTS, card, Vector2i(0, -1))
		scene.proof_mode = "ranged"
		scene.proof_label = "L0_rear_%s" % ("cast" if card == "guiding_flare" else "shoot")
		scene.proof_ranged_release = Fx.anticipation_end_progress(Fx.STYLE_FIREBALL) if card == "guiding_flare" else 0.18
		checks.append(await _play_card(scene, card, Vector2i(0, -1), expect))
		expect.call(scene.proof_captures.has(scene.proof_label + "_phase_042"), "Rear ranged action captures its .42 release")
	await _fixture(scene, L1, "crushing_blow", Vector2i(0, 1), true)
	scene.proof_mode = "attack"
	scene.proof_label = "L1_crushing_blow"
	checks.append(await _play_card(scene, "crushing_blow", Vector2i(0, 1), expect))
	expect.call(scene.proof_captures.has("L1_crushing_blow_reduced_motion"), "Reduced-motion heavy action is captured")
	scene.proof_mode = ""
	return checks

static func _play_card(scene: Node, card: String, direction: Vector2i, expect: Callable) -> Dictionary:
	var engine := Combat.new()
	var initial: Dictionary = scene.get("_combat_state").duplicate(true)
	var prepared: Dictionary = engine.prepare_player_card(initial, 0)
	var actions: Array = engine.card_play_actions(card, prepared)
	var expected: Dictionary = prepared
	var damage: Array = []
	var tile: Vector2i = initial["player"]["pos"] + direction
	for action: Dictionary in actions:
		var before_hp: int = int(expected["enemies"][0]["hp"])
		expected = engine.apply_player_action(expected, action, tile)
		damage.append(before_hp - int(expected["enemies"][0]["hp"]))
	await scene.call("_on_card_pressed", 0)
	scene.call("_on_board_tile_hovered", tile)
	await scene.call("_on_board_tile_clicked", tile)
	expect.call(not bool(scene.get("_animation_lock")), "Real card input returns after " + card)
	var final: Dictionary = scene.get("_combat_state")
	expect.call(int(final["enemies"][0]["hp"]) == int(expected["enemies"][0]["hp"]), "Card applies every authored hit exactly once: " + card)
	if scene.proof_mode == "attack":
		expect.call(scene.proof_hits.size() == actions.size(), "One attack animation per authored hit, including Flurry repeats")
		for index: int in range(mini(scene.proof_hits.size(), damage.size())):
			var hit: Dictionary = scene.proof_hits[index]
			if float(hit["frame_seconds"]) > 0.0:
				expect.call(int(hit["initial_hp"]) - int(hit["final_hp"]) == int(damage[index]) and hit["hp_changes"] == 1, "Each animated hit presents its exact damage once")
	var snapshot: Dictionary = scene.board_view.protagonist_animation_snapshot()
	var rest_clip: String = "rest" if bool(scene.get("_settings").get("reduced_motion", false)) else "idle"
	expect.call(snapshot["clip"] == rest_clip and snapshot["facing"] == "front" and not snapshot["mirrored"], "Real action returns to front idle (neutral still in reduced motion)")
	return {"label": scene.proof_label, "card": card, "expected_damage_per_hit": damage, "enemy_hp": final["enemies"][0]["hp"], "hits": scene.proof_hits.duplicate(true)}

static func _fixture(scene: Node, equipped: Dictionary, card: String, direction: Vector2i, reduced: bool = false) -> void:
	scene.proof_mode = ""
	scene.proof_hits.clear()
	scene.proof_captures.clear()
	scene.call("_cancel_drag_play")
	scene.call("_reset_card_resolution")
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	var hand: Array = [card, "brace", "sidestep_slash", "bone_dart", "patch_up"]
	var layout: Dictionary = {"name": "Visible Gear Motion Trial", "coord": Vector2i(4, 3), "type": "combat", "grid": grid,
		"player_start": Vector2i(3, 3), "enemies": [{"id": 1, "type": "crawler", "pos": Vector2i(3, 3) + direction, "hp": 80, "max_hp": 80, "block": 0}],
		"traps": [], "terrain": [], "element": "none"}
	var state: Dictionary = Combat.new().create_combat(261005, layout, {"hp": 24, "max_hp": 24, "deck_cards": hand.duplicate(), "relics": [], "hand_size": 5, "heal_bonus": 0})
	state["deck"] = {"hand": hand, "draw": [], "discard": [], "burned": []}
	state["current_actor"] = {"kind": "player", "key": "player"}
	var progression: Dictionary = scene.get("_progression").duplicate(true)
	for prompt: String in Tutorial.prompt_ids():
		progression = Tutorial.resolve_progression(progression, prompt)
	var run: Dictionary = scene.get("_run_state").duplicate(true)
	run.merge({"mode": "combat", "current_room": layout["coord"], "current_room_layout": layout, "combat_state": state, "progression": progression, "equipped_equipment": equipped.duplicate()}, true)
	scene.set("_progression", progression)
	scene.set("_run_state", run)
	var settings: Dictionary = scene.get("_settings").duplicate()
	settings["reduced_motion"] = reduced
	settings["ui_scale"] = 1.0
	scene.set("_settings", settings)
	scene.call("_sync_combat_state_from_run")
	scene.set("_animation_lock", false)
	scene.call("_refresh_ui")
	if DisplayServer.get_name() != "headless":
		Input.warp_mouse(Vector2(960, 80))
	for frame: int in range(5):
		await scene.get_tree().process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
	(scene.board_view.get("_protagonist_renderer") as Node).set_process(false)
