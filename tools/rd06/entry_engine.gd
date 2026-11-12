extends "res://scripts/run_engine.gd"

## Deterministic proof placement only. The room, encounter and combat creation
## are production-generated; use the same covered hero tile as the combat save.
const HERO_TILE := Vector2i(2, 4)
const ENEMY_TILES: Array[Vector2i] = [Vector2i(3, 5), Vector2i(5, 6), Vector2i(6, 2), Vector2i(7, 3), Vector2i(1, 1)]

func begin_pre_battle_combat(run_state: Dictionary, prepared: Dictionary = {}) -> Dictionary:
	var state: Dictionary = super.begin_pre_battle_combat(run_state, prepared)
	if state.get("mode") == "combat":
		state.combat_state.player.pos = HERO_TILE
		var enemies: Array = state.combat_state.enemies
		assert(enemies.size() <= ENEMY_TILES.size(), "Proof placement covers the generated encounter")
		for index: int in enemies.size(): enemies[index].pos = ENEMY_TILES[index]
	return state
