extends RefCounted
## Fixture IDs sit outside the ordinary joypad slots.
const Router = preload("res://scripts/input_router.gd")
const XBOX_DEVICE: int = 100
const PLAYSTATION_DEVICE: int = 101
const DECK_DEVICE: int = 102

const FAMILIES = [Router.FAMILY_XBOX, Router.FAMILY_STEAM_DECK, Router.FAMILY_PLAYSTATION]
const FAMILY_NAMES = ["Xbox", "Steam Deck", "PlayStation"]
const LABELS = {
	Router.ACTION_ACCEPT: ["A", "A", "✕"],
	Router.ACTION_CANCEL: ["B", "B", "○"],
	Router.ACTION_HAND_TOGGLE: ["X", "X", "□"],
	Router.ACTION_PASS: ["Y", "Y", "△"],
	Router.ACTION_HAND_PREVIOUS: ["LB", "L1", "L1"],
	Router.ACTION_HAND_NEXT: ["RB", "R1", "R1"],
	Router.ACTION_HAND_BUMPERS: ["LB·RB", "L1·R1", "L1·R1"],
	Router.ACTION_MENU: ["≡", "≡", "≡"],
	Router.ACTION_MAP: ["▣", "▣", "▣"],
	Router.ACTION_MAP_ZOOM: ["LT·RT", "L2·R2", "L2·R2"],
	Router.ACTION_EMPOWER: ["RS", "R3", "R3"],
	Router.ACTION_UNDO_MOVE: ["LT", "L2", "L2"],
	&"controller_move": ["LS", "LS", "LS"],
	&"controller_dpad": ["+", "+", "+"],
}

class FixtureRouter extends "res://scripts/input_router.gd":
	const STEAM_TYPES = {XBOX_DEVICE: 2, PLAYSTATION_DEVICE: 13, DECK_DEVICE: 14}
	var steam_input_enabled: bool = true

	func _family_from_steam_input(device_id: int) -> String:
		return family_for_steam_input_type(int(STEAM_TYPES.get(device_id, 0))) if steam_input_enabled else ""

	func _family_from_device_name(device_id: int) -> String:
		var device_name: String = "Steam Virtual Gamepad" if device_id == PLAYSTATION_DEVICE else "Xbox Controller"
		return family_for_device_name(device_name)

func check_tables(expect: Callable, router: Node) -> void:
	var steam_families: Dictionary = {
		2: "xbox", 3: "xbox", 4: "xbox", 5: "playstation",
		12: "playstation", 13: "playstation", 14: "steam_deck",
	}
	for input_type: int in range(19):
		expect.call(Router.family_for_steam_input_type(input_type) == steam_families.get(input_type, ""), "Steam Input type %d" % input_type)
	for input_type: int in [-1, 255]:
		expect.call(Router.family_for_steam_input_type(input_type).is_empty(), "Unrecognized Steam Input type %d" % input_type)
	var name_cases: Array = [
		["Xbox Wireless Controller", false, "", "xbox"],
		["XINPUT DualSense", false, "", "xbox"],
		["Sony Controller", false, "Microsoft Gamepad", "xbox"],
		["DualSense Edge", false, "", "playstation"],
		["DUALSHOCK 4", false, "", "playstation"],
		["PlayStation Controller", false, "", "playstation"],
		["PS3 Controller", false, "", "playstation"],
		["PS4 Controller", false, "", "playstation"],
		["PS5 Controller", false, "", "playstation"],
		["Sony Interactive Entertainment", false, "", "playstation"],
		[" Wireless Controller ", false, "Generic Gamepad", "playstation"],
		["Generic Gamepad", true, "Wireless Controller", "playstation"],
		["Generic Wireless Controller", false, "", "xbox"],
		["Steam Virtual Gamepad", false, "", "steam_deck"],
		["Steam Virtual Gamepad", true, "DualSense", "playstation"],
		["Steam Deck", false, "", "steam_deck"],
		["Steam Controller", false, "", "steam_deck"],
		["Generic Gamepad", true, "", "steam_deck"],
		["", true, "", "steam_deck"],
		["Nintendo Switch Pro Controller", false, "", "xbox"],
		["Unknown", false, "", "xbox"],
	]
	for entry: Array in name_cases:
		expect.call(Router.family_for_device_name(entry[0], entry[1], entry[2]) == entry[3], "Device name case %s" % str(entry))
	router.steam_input_enabled = false
	expect.call(router.family_for_device(PLAYSTATION_DEVICE) == Router.FAMILY_STEAM_DECK, "Steam Virtual Gamepad without Steam type")
	router.steam_input_enabled = true
	expect.call(router.family_for_device(PLAYSTATION_DEVICE) == Router.FAMILY_PLAYSTATION, "Steam Virtual Gamepad with PS5 Steam type")
	expect.call(router.family_for_device(DECK_DEVICE) == Router.FAMILY_STEAM_DECK, "Steam Deck type precedes Xbox name")
	for action: StringName in LABELS:
		for index: int in range(FAMILIES.size()):
			expect.call(router.glyph_label(action, FAMILIES[index]) == LABELS[action][index], "%s label for %s" % [action, FAMILIES[index]])
	print("UX-15 TABLES: %d Steam types, %d device names, 3 type/name precedence cases, %d labels checked" % [21, name_cases.size(), LABELS.size() * FAMILIES.size()])
