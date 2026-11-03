extends RefCounted

const CombatEngine = preload("res://scripts/combat_engine.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")

# Test/proof-only state, never written to production encounter data.
const SEED: int = 13004
const SIZE := Vector2i(1920, 1080)
const BOSS_TILE := Vector2i(4, 3)
const REGULAR_TILE := Vector2i(4, 2)
const BOSS_HP: int = 48
const BOSS_MAX_HP: int = 60
const LETHAL_HP: int = 3
const REGULAR_HP: int = 18
const DETONATION_SURFACE: String = "fire"
const GRID_SIZE := Vector2i(9, 7)
const PLAYER_TILE := Vector2i(3, 3)
const ROOM_COORD := Vector2i(4, 3)
const PLAYER_HP: int = 24
const HAND_SIZE: int = 2

static func prepare_storage() -> Dictionary:
	SettingsStore.set_storage_path("user://boss_health_preview_settings.json")
	ProgressionStore.set_storage_path("user://boss_health_preview_profile.json")
	ProgressionStore.set_run_storage_path("user://boss_health_preview_run.save")
	var profile: Dictionary = ProgressionStore.default_data()
	profile[Tutorial.PROGRESSION_KEY] = {"version": Tutorial.VERSION, "status": "dismissed", "completed_steps": []}
	ProgressionStore.save_data(profile)
	ProgressionStore.clear_saved_run()
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	SettingsStore.save_settings(settings)
	return settings

static func install(scene: Node, card_id: String = "quick_stab", lethal: bool = false) -> void:
	scene.call("_cancel_drag_play")
	scene.call("_reset_card_resolution")
	var grid: Array = []
	for y: int in range(GRID_SIZE.y):
		var row: Array = []
		for x: int in range(GRID_SIZE.x):
			row.append("wall" if x == 0 or x == GRID_SIZE.x - 1 or y == 0 or y == GRID_SIZE.y - 1 else "stone")
		grid.append(row)
	var layout: Dictionary = {
		"name": preload("res://scripts/dragon_boss_library.gd").room_name_for_boss("vyraketh"), "coord": ROOM_COORD, "type": "combat",
		"element": "fire", "grid": grid, "player_start": PLAYER_TILE,
		"enemies": [
			{"id": 1, "type": "vyraketh", "pos": BOSS_TILE, "hp": LETHAL_HP if lethal else BOSS_HP, "max_hp": BOSS_MAX_HP, "footprint": Vector2i(2, 2)},
			{"id": 2, "type": "crawler", "pos": REGULAR_TILE, "hp": REGULAR_HP, "max_hp": REGULAR_HP},
		],
		"traps": [], "terrain": [], "loot": [],
	}
	var combat: Dictionary = CombatEngine.new().create_combat(SEED, layout, {
		"hp": PLAYER_HP, "max_hp": PLAYER_HP, "deck_cards": [card_id, "brace"],
		"relics": [], "hand_size": HAND_SIZE, "heal_bonus": 0,
	})
	combat["deck"]["hand"] = [card_id, "brace"]
	combat["deck"]["draw"] = []
	combat["deck"]["discard"] = []
	combat["deck"]["burned"] = []
	combat["current_actor"] = {"kind": "player", "key": "player"}
	if card_id == "phoenix_cleave":
		# Detonate requires pre-existing fuel; this makes both authored hits land.
		preload("res://scripts/board_surface_rules.gd").place(combat, BOSS_TILE, DETONATION_SURFACE)
	var run: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	run["mode"] = "combat"
	run["current_room"] = layout["coord"]
	run["current_room_layout"] = layout
	run["combat_state"] = combat
	scene.set("_run_state", run)
	scene.set("_combat_state", combat)
	scene.set("_animation_lock", false)
	scene.set("_hovered_board_tile", Vector2i(-1, -1))
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_refresh_ui")
