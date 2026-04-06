extends RefCounted
class_name ElementData

const NONE: String = "none"
const FIRE: String = "fire"
const ICE: String = "ice"
const LIGHTNING: String = "lightning"
const AIR: String = "air"
const EARTH: String = "earth"

const ORDER: PackedStringArray = [FIRE, ICE, LIGHTNING, AIR, EARTH]

const ELEMENTS := {
	NONE: {
		"name": "Neutral",
		"label": "Neutral",
		"short_label": "",
		"accent": "#8a6d49",
		"card_background": "#efe4cf",
		"card_selected_background": "#ddd0bb",
		"card_art_background": "#51463f",
		"room_tint": "#8c7462",
		"door_tint": "#d3b78e",
		"icon_path": ""
	},
	FIRE: {
		"name": "Fire",
		"label": "Fire",
		"short_label": "FIRE",
		"accent": "#d9623f",
		"card_background": "#f5dfd2",
		"card_selected_background": "#e9c5b0",
		"card_art_background": "#5a3a30",
		"room_tint": "#ba5d41",
		"door_tint": "#f2a36f",
		"icon_path": "res://assets/placeholders/cards/element_fire.svg"
	},
	ICE: {
		"name": "Ice",
		"label": "Ice",
		"short_label": "ICE",
		"accent": "#5fa7d8",
		"card_background": "#dcecf6",
		"card_selected_background": "#c2ddf0",
		"card_art_background": "#314758",
		"room_tint": "#6aa7cf",
		"door_tint": "#b2e1ff",
		"icon_path": "res://assets/placeholders/cards/element_ice.svg"
	},
	LIGHTNING: {
		"name": "Lightning",
		"label": "Lightning",
		"short_label": "LGT",
		"accent": "#cfb347",
		"card_background": "#f4ebc8",
		"card_selected_background": "#eadb9b",
		"card_art_background": "#584c2f",
		"room_tint": "#c7a944",
		"door_tint": "#f5d96c",
		"icon_path": "res://assets/placeholders/cards/element_lightning.svg"
	},
	AIR: {
		"name": "Air",
		"label": "Air",
		"short_label": "AIR",
		"accent": "#72bea5",
		"card_background": "#dff4ee",
		"card_selected_background": "#c6e7dd",
		"card_art_background": "#315248",
		"room_tint": "#72b9a3",
		"door_tint": "#bfe9da",
		"icon_path": "res://assets/placeholders/cards/element_air.svg"
	},
	EARTH: {
		"name": "Earth",
		"label": "Earth",
		"short_label": "EARTH",
		"accent": "#89a15b",
		"card_background": "#e5edd7",
		"card_selected_background": "#d2dfbc",
		"card_art_background": "#445438",
		"room_tint": "#8ea55e",
		"door_tint": "#c6dfa0",
		"icon_path": "res://assets/placeholders/cards/element_earth.svg"
	}
}

static func all_elements() -> PackedStringArray:
	return ORDER

static func is_elemental(element_id: String) -> bool:
	return ORDER.has(str(element_id))

static func def(element_id: String) -> Dictionary:
	var key: String = str(element_id)
	if not ELEMENTS.has(key):
		key = NONE
	return (ELEMENTS[key] as Dictionary).duplicate(true)

static func name(element_id: String) -> String:
	return str(def(element_id).get("name", "Neutral"))

static func short_label(element_id: String) -> String:
	return str(def(element_id).get("short_label", ""))

static func accent(element_id: String) -> Color:
	return Color(str(def(element_id).get("accent", "#8a6d49")))

static func card_background(element_id: String, selected: bool = false) -> Color:
	var data: Dictionary = def(element_id)
	var key: String = "card_selected_background" if selected else "card_background"
	return Color(str(data.get(key, "#efe4cf")))

static func card_art_background(element_id: String) -> Color:
	return Color(str(def(element_id).get("card_art_background", "#51463f")))

static func room_tint(element_id: String) -> Color:
	return Color(str(def(element_id).get("room_tint", "#8c7462")))

static func door_tint(element_id: String) -> Color:
	return Color(str(def(element_id).get("door_tint", "#d3b78e")))

static func icon_path(element_id: String) -> String:
	return str(def(element_id).get("icon_path", ""))
