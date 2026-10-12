extends RefCounted

const Tracker = preload("res://scripts/health_ghost_tracker.gd")
const Bar = preload("res://scripts/segmented_health_bar.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Run = preload("res://scripts/run_engine.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")

# Debug-only fixture values; production presentation values live in Tracker.
const FIXTURE_HP: float = 24.0
const FIXTURE_DAMAGE: float = 6.0
const FIXTURE_HERO_DAMAGE: float = 5.0
const FIXTURE_HEAL: float = 3.0
const CLOCK_TEST_SECONDS: float = 0.08
const CLOCK_TOLERANCE_SECONDS: float = 0.06
const SETTLE_FRAMES: int = 8
const HUD_TEST_SIZE: Vector2 = Vector2(140.0, 160.0)
const CLOCK_SPEED_MULTIPLIER: float = 2.0
const FIXTURE_ENEMY_ID: int = 901
const FIXTURE_ENEMY_TILE: Vector2i = Vector2i(4, 3)
const FIXTURE_HERO_TILE: Vector2i = Vector2i(3, 3)
const FIXTURE_SEED: int = 92841
const FIXTURE_ENEMY_TYPE: String = "crawler"
const FIXTURE_HERO_HP: int = 16
const FIXTURE_HERO_MAX_HP: int = 24

static func run(expect: Callable) -> void:
	var tracker := Tracker.new()
	tracker.observe("enemy_1", FIXTURE_HP, FIXTURE_HP)
	expect.call(not tracker.is_active(), "First display has no damage ghost or heal flash")
	tracker.observe("enemy_1", FIXTURE_HP - FIXTURE_DAMAGE, FIXTURE_HP)
	tracker.advance(0.1)
	expect.call(is_equal_approx(tracker.ghost_value("enemy_1"), FIXTURE_HP), "Damage ghost holds the pre-hit HP at 0.1 s")
	tracker.advance(0.45)
	expect.call(is_equal_approx(tracker.ghost_value("enemy_1"), FIXTURE_HP), "Damage ghost holds for exactly 0.55 s")
	tracker.advance(0.175)
	expect.call(is_equal_approx(tracker.ghost_value("enemy_1"), 22.5), "Halfway through drain uses ease-in quad, not linear interpolation")
	tracker.advance(0.175)
	expect.call(is_equal_approx(tracker.ghost_value("enemy_1"), 18.0) and not tracker.is_active(), "Damage ghost completes at 0.9 s")

	tracker.clear()
	tracker.observe("player", FIXTURE_HP, FIXTURE_HP)
	tracker.observe("player", 19.0, FIXTURE_HP)
	tracker.advance(0.5)
	tracker.observe("player", 17.0, FIXTURE_HP)
	tracker.advance(0.5)
	expect.call(is_equal_approx(tracker.ghost_value("player"), FIXTURE_HP), "Re-hit during hold restarts hold and retains the highest top")
	tracker.advance(0.225)
	var draining_top: float = tracker.ghost_value("player")
	tracker.observe("player", 14.0, FIXTURE_HP)
	expect.call(is_equal_approx(tracker.ghost_value("player"), draining_top), "Re-hit during drain continues from the current ghost position without jumping")
	tracker.advance(Tracker.HOLD_SECONDS + Tracker.DRAIN_SECONDS)
	expect.call(is_equal_approx(tracker.ghost_value("player"), 14.0), "Re-hit drains to its new HP endpoint")

	tracker.observe("player", 10.0, FIXTURE_HP)
	tracker.observe("player", 13.0, FIXTURE_HP)
	var healed: Dictionary = tracker.sample("player")
	expect.call(healed["hp"] == 13.0 and tracker.ghost_value("player") == 13.0, "Healing snaps the fill and cancels the damage ghost")
	expect.call(healed["heal_range"] == Vector2(10.0, 13.0) and healed["heal_flash"] == 1.0, "Only the healed portion starts a bright flash")
	tracker.advance(0.1)
	expect.call(is_equal_approx(float(tracker.sample("player")["heal_flash"]), 0.5), "Healing flash fades over 0.2 s")
	tracker.advance(0.1)
	expect.call(tracker.sample("player")["heal_flash"] == 0.0 and not tracker.is_active(), "Healing flash ends at 0.2 s")
	tracker.observe("player", 0.0, FIXTURE_HP)
	tracker.advance(0.55)
	expect.call(tracker.ghost_value("player") == 13.0, "Death still holds its last living HP")
	tracker.advance(0.35)
	expect.call(is_zero_approx(tracker.ghost_value("player")), "Death ghost drains fully to zero")

	tracker.clear()
	tracker.reduced_motion = true
	tracker.observe("enemy_1", FIXTURE_HP, FIXTURE_HP)
	tracker.observe("enemy_1", 18.0, FIXTURE_HP)
	tracker.advance(0.399)
	expect.call(tracker.ghost_value("enemy_1") == FIXTURE_HP, "Reduced motion keeps a static ghost before 0.4 s")
	tracker.advance(0.001)
	expect.call(tracker.ghost_value("enemy_1") == 18.0 and not tracker.is_active(), "Reduced motion removes the ghost in one step at 0.4 s")
	tracker.observe("enemy_1", 12.0, FIXTURE_HP)
	tracker.advance(0.2)
	tracker.observe("enemy_1", 9.0, FIXTURE_HP)
	tracker.advance(0.399)
	expect.call(tracker.ghost_value("enemy_1") == 18.0, "Reduced-motion re-hit restarts the static hold")
	tracker.advance(0.001)
	expect.call(tracker.ghost_value("enemy_1") == 9.0, "Reduced-motion re-hit disappears at its restarted deadline")
	tracker.observe("enemy_1", 12.0, FIXTURE_HP)
	expect.call(tracker.ghost_value("enemy_1") == 12.0, "Reduced-motion healing also cancels a ghost")
	expect.call(Tracker.ENEMY_GHOST_COLOR == Color(Color("f2c3a6"), 0.85), "Enemy ghost uses the exact authored warm pale colour and alpha")
	expect.call(Tracker.ALLY_GHOST_COLOR == Color(Color("d9f2e6"), 0.8), "Hero/ally ghost uses the exact authored colour and alpha")
	expect.call(Tracker.HEAL_LIGHTEN_AMOUNT == 0.35, "Healing flash lightens the fill by the authored 35 percent")
	var bounds := Rect2(10.0, 20.0, 240.0, 12.0)
	expect.call(Bar.range_rect(bounds, Vector2(18.0, 24.0), FIXTURE_HP) == Rect2(190.0, 20.0, 60.0, 12.0), "Ghost geometry covers only the lost HP range inside existing bar bounds")
	expect.call(Bar.range_rect(bounds, Vector2(-3.0, 30.0), FIXTURE_HP) == bounds, "Ghost geometry clamps to the bar bounds")
	_test_board_plumbing(expect)

static func _test_board_plumbing(expect: Callable) -> void:
	var board := Board.new()
	var state: Dictionary = fixture_run()["combat_state"]
	var original: Dictionary = state.duplicate(true)
	board.set_combat_state(state)
	var enemy: Dictionary = (state["enemies"] as Array)[0]
	var key: String = "enemy_%d" % int(enemy["id"])
	var damaged: Dictionary = state.duplicate(true)
	damaged["enemies"][0]["hp"] = float(enemy["hp"]) - FIXTURE_DAMAGE
	damaged["player"]["hp"] = float(state["player"]["hp"]) - FIXTURE_HERO_DAMAGE
	board.set_combat_state(damaged)
	var tracker: RefCounted = board.health_ghost_tracker
	expect.call(tracker.sample(key)["ghost_range"] == Vector2(float(enemy["hp"]) - FIXTURE_DAMAGE, float(enemy["hp"])), "Board enemy HP changes enter the tracker")
	expect.call(tracker.sample("player")["ghost_range"] == Vector2(float(state["player"]["hp"]) - FIXTURE_HERO_DAMAGE, float(state["player"]["hp"])), "Board hero HP changes enter the tracker")
	var preview: Dictionary = damaged.duplicate(true)
	preview["player"]["hp"] = 1
	board.set_health_ghost_source_state(damaged)
	board.set_combat_state(preview, [], [], Vector2i(-1, -1), "", "", {}, {}, {"damage_preview": {key: {"hp": 1}}})
	expect.call(tracker.sample("player")["hp"] == damaged["player"]["hp"], "Projected hero HP never starts a real damage ghost")
	var removed: Dictionary = damaged.duplicate(true)
	removed["enemies"] = []
	board.set_combat_state(removed)
	expect.call(tracker.sample(key)["hp"] == 0.0 and tracker.ghost_value(key) > 0.0, "Removing a defeated enemy still starts a ghost from its previous HP")
	expect.call(state == original, "Ghost plumbing never mutates combat state")
	var sample_before: Dictionary = tracker.sample(key)
	tracker.advance(0.0)
	expect.call(tracker.sample(key) == sample_before, "Zero presentation delta pauses the ghost during hit-stop")
	board.set_combat_state({}, [], [], Vector2i(-1, -1), "", "", {}, {}, {})
	expect.call(tracker.sample(key).is_empty(), "Leaving a board clears obsolete unit identities")
	board.free()

static func run_integration(tree: SceneTree, expect: Callable) -> void:
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	tree.root.add_child(scene)
	await settle(tree)
	scene.call("_load_run_state", fixture_run())
	scene.call("_close_dialogue")
	scene.call("_close_large_map")
	await settle(tree)
	var board: Control = scene.get("board_view")
	var tracker: RefCounted = board.health_ghost_tracker
	var combat: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	var boss: Dictionary = (combat["enemies"] as Array)[0]
	var boss_key: String = "enemy_%d" % int(boss["id"])
	var before_hp: float = float(boss["hp"])
	var hero_hp: float = float(combat["player"]["hp"])
	combat["enemies"][0]["hp"] = before_hp - FIXTURE_DAMAGE
	combat["player"]["hp"] = hero_hp - FIXTURE_HERO_DAMAGE
	scene.call("_render_board_state", combat, {})
	var boss_bar: Control = scene.get("_boss_health_bar")
	expect.call(boss_bar.ghost_key == boss_key and boss_bar.ghost_tracker == tracker, "Boss overlay binds to its board unit's shared tracker")
	expect.call(boss_bar.ghost_sample()["ghost_range"] == Vector2(before_hp - FIXTURE_DAMAGE, before_hp), "Boss overlay receives actual contact HP")
	var hud: Control = scene.call("_turn_order_health_bar", {"kind": "player", "actor_key": "player", "team": "player", "hp": hero_hp, "max_hp": combat["player"]["max_hp"]}, HUD_TEST_SIZE)
	expect.call(hud.ghost_tracker == tracker and hud.ghost_sample()["hp"] == hero_hp - FIXTURE_HERO_DAMAGE, "Rebuilt hero HUD meter shares contact HP with the board")
	expect.call((board.get("_hud_render_layer") as Control).health_ghost_tracker == tracker, "Retained HUD renderer shares the owner tracker")
	var frozen: Dictionary = tracker.sample("player")
	var previous_scale: float = Engine.time_scale
	Engine.time_scale = 0.0
	await tree.create_timer(CLOCK_TEST_SECONDS, true, false, true).timeout
	expect.call(tracker.sample("player") == frozen, "Engine hit-stop freezes the production presentation clock")
	Engine.time_scale = CLOCK_SPEED_MULTIPLIER
	var started: int = Time.get_ticks_usec()
	await tree.create_timer(CLOCK_TEST_SECONDS, true, false, true).timeout
	var real_seconds: float = float(Time.get_ticks_usec() - started) / 1000000.0
	var elapsed: float = float((tracker.get("_bars") as Dictionary)["player"]["elapsed"])
	expect.call(absf(elapsed - real_seconds * Engine.time_scale) < CLOCK_TOLERANCE_SECONDS, "Combat speed scales the production ghost clock through Engine.time_scale")
	Engine.time_scale = previous_scale
	var dead: Dictionary = combat.duplicate(true)
	dead["enemies"] = []
	var death_unit: Dictionary = boss.duplicate(true)
	death_unit["key"] = boss_key
	death_unit["death_progress"] = 0.0
	scene.call("_render_board_state", dead, {"death_animation_units": [death_unit]})
	expect.call((scene.get("_boss_health_overlay") as Control).visible and boss_bar.ghost_sample()["hp"] == 0.0, "A removed boss retains its zero-HP overlay through the existing death presentation")
	dead["enemies"] = [boss.duplicate(true)]
	dead["enemies"][0]["hp"] = 0
	death_unit["death_progress"] = 0.9
	scene.call("_render_board_state", dead, {"death_animation_units": [death_unit]})
	var overlay: Control = scene.get("_boss_health_overlay")
	var expected_tint: Color = board.call("_death_animation_tint", death_unit)
	expect.call(is_equal_approx(overlay.modulate.a, expected_tint.a), "A boss retained in the combat snapshot still follows its existing unit death fade")
	hud.free()
	scene.queue_free()
	await tree.process_frame

static func fixture_run(boss: bool = true) -> Dictionary:
	var state: Dictionary = Run.new().create_debug_boss_run(Progression.default_data())
	if boss:
		return state
	var layout: Dictionary = (state["current_room_layout"] as Dictionary).duplicate(true)
	var definition: Dictionary = Data.enemy_def(FIXTURE_ENEMY_TYPE)
	layout["player_start"] = FIXTURE_HERO_TILE
	layout["enemies"] = [{
		"id": FIXTURE_ENEMY_ID, "type": FIXTURE_ENEMY_TYPE, "pos": FIXTURE_ENEMY_TILE,
		"hp": definition["max_hp"], "max_hp": definition["max_hp"],
		"block": 0, "stoneskin": 0, "base_initiative": definition["base_initiative"],
	}]
	state["current_room_layout"] = layout
	state["combat_state"] = Combat.new().create_combat(FIXTURE_SEED, layout, {
		"hp": FIXTURE_HERO_HP, "max_hp": FIXTURE_HERO_MAX_HP,
		"deck_cards": ["quick_stab", "brace"], "relics": [], "hand_size": 2,
	})
	return state

static func settle(tree: SceneTree) -> void:
	for frame: int in range(SETTLE_FRAMES):
		await tree.process_frame
