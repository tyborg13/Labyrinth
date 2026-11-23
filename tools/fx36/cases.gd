extends RefCounted

const Witness = preload("res://tools/fx33/cases.gd")
const NATIVE: Array[String] = ["chain_bolt", "storm_relay", "capacitor"]
const EXTRA: Array[String] = ["storm_salvo", "spark_conduction", "chain_conduction"]
const FOURTH_CAPACITOR_TARGET := Vector2i(5, 5)

static func options(id: String, seed: int) -> Dictionary:
	var result: Dictionary = Witness.options(id, seed)
	var card: String = card_id(id)
	result["hand"] = card
	if id == "capacitor":
		result["enemy_types"] += ",crawler"
		result["enemy_positions"] += "," + Witness.coord(FOURTH_CAPACITOR_TARGET)
	return result

static func card_id(id: String) -> String:
	return {"capacitor": "quick_stab", "spark_conduction": "spark_dart", "chain_conduction": "chain_bolt"}.get(id, id)

static func configure(id: String, state: Dictionary) -> void:
	Witness.configure(id, state)
