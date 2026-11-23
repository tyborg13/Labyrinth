extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Inline = preload("res://scripts/inline_icon_text.gd")

const SEED: int = 24
const SIZE: int = 9
const PLAYER: Vector2i = Vector2i(3, 4)
const ENEMY: Vector2i = Vector2i(5, 4)
const TEST_HEALTH: int = 100

static func text(value: Variant) -> String:
	# Icon-only terms are transcribed by their names. The production rewrite
	# removes diagram tokens, so the transcription retains the words only.
	return Inline.plain_text(Inline.Patterns.display_rules(str(value))).strip_edges()

static func grid() -> Array:
	var rows: Array = []
	for y: int in range(SIZE):
		var row: Array = []
		for x: int in range(SIZE):
			row.append("wall" if x in [0, SIZE - 1] or y in [0, SIZE - 1] else "floor")
		rows.append(row)
	return rows

static func fight(engine: RefCounted, enemy_type: String = "crawler", skills: Array = []) -> Dictionary:
	var actor: Dictionary = unit(enemy_type, 0, ENEMY)
	var layout: Dictionary = {"player_start": PLAYER, "grid": grid(), "enemies": [actor]}
	return engine.create_combat(SEED, layout, {"hp": TEST_HEALTH, "max_hp": TEST_HEALTH,
		"deck_cards": Data.starting_deck(), "skill_ids": skills})

static func unit(enemy_type: String, id: int, pos: Vector2i) -> Dictionary:
	var definition: Dictionary = Data.enemy_def(enemy_type)
	return {"id": id, "type": enemy_type, "pos": pos, "hp": definition["max_hp"], "max_hp": definition["max_hp"]}

static func intent(enemy_type: String, id: String) -> Dictionary:
	for intent_row: Dictionary in Data.enemy_def(enemy_type)["intents"]:
		if str(intent_row["id"]) == id: return intent_row
	return {}

