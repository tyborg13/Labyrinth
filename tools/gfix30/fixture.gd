extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Deck = preload("res://scripts/run_deck.gd")
const Events = preload("res://scripts/event_rules.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const ASH: String = "ash_confessional"
const SEED: int = 1
const START_SECTION: int = 0
const SMOKE_EVENT_ROOM := Vector2i(-1, -1)
const MID_SECTION: int = 2
const MID_EMBERS: int = 100
const MID_SPELLS: Array = ["hoarfrost_ward", "petrify", "root_snare"]
const MID_ITEM_COUNT: int = 2
const RESOLUTION := Vector2i(1920, 1080)
const FRAME_LIMIT: int = 120

static func starter() -> Dictionary:
	return Run.new().create_new_run(SEED, Store.default_data())

static func mid_run(base: Dictionary) -> Dictionary:
	var state: Dictionary = base.duplicate(true)
	for id: String in MID_SPELLS: Deck.add_magic(state, id)
	var equipped: Dictionary = state["equipped_equipment"]
	for id: String in Data.equipment():
		var slot: String = Data.equipment_slot(id)
		if str(equipped.get(slot, "")).is_empty(): equipped[slot] = id
	state["collected_equipment"] = equipped.values()
	state["item_inventory"] = Data.item_card_ids().slice(0, MID_ITEM_COUNT)
	state["relics"] = [Data.relics().keys().front()]
	state["held_embers"] = MID_EMBERS
	state["unbanked_embers"] = MID_EMBERS
	Deck.rebuild(state)
	return state

static func event(base: Dictionary, id: String, section: int = START_SECTION) -> Dictionary:
	var state: Dictionary = base.duplicate(true)
	if id == ASH and section == START_SECTION:
		state["current_room"] = SMOKE_EVENT_ROOM
		var ash_room: Dictionary = preload("res://scripts/section_map_graph.gd").room(state, SMOKE_EVENT_ROOM)
		if ash_room.is_empty() or ash_room.get("section_index") != START_SECTION: return {}
		ash_room["type"] = "event"
		ash_room["event_id"] = id
		return Events.enter_event(state)
	for room: Dictionary in (state["rooms"] as Dictionary).values():
		if room.get("section_index") != section or room.get("cleared", false): continue
		if room.get("type") != "event": continue
		state["current_room"] = room["coord"]
		room["event_id"] = id
		return Events.enter_event(state)
	return {}

static func choice_point(button: Control) -> Vector2:
	return button.get_global_transform_with_canvas() * (button.size * 0.5)

static func ash_starter() -> Dictionary:
	return event(starter(), ASH)
