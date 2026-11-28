extends RefCounted

const Pass = preload("res://scripts/pass_forecast_tooltip_button.gd")
const Forecast = preload("res://scripts/pass_forecast_focus_tooltip.gd")
const Controls = preload("res://scripts/pre_battle_controls.gd")
const View = preload("res://scripts/pre_battle_view.gd")
const Inspection = preload("res://scripts/pre_battle_inspection_view.gd")
const Heading = preload("res://scripts/pre_battle_objective_heading.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const RuleHud = preload("res://scripts/battlefield_rule_hud.gd")
const Omens = preload("res://scripts/omen_badges.gd")
const Map = preload("res://scripts/section_map_panel.gd")
const Chronicle = preload("res://scripts/chronicle_panel.gd")
const Tile = preload("res://scripts/chronicle_card_tile.gd")
const Choice = preload("res://scripts/graftwright_choice.gd")
const Card = preload("res://scenes/card_widget.tscn")
const Seal = preload("res://scripts/card_empower_seal.gd")
const Data = preload("res://scripts/game_data.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Catalog = preload("res://scripts/combat_objective_rules.gd")
const EmpowerSuite = preload("res://tests/suites/empower_seal_tooltip_suite.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const FOE_ID: String = "burrow_grub"
const CARD_ID: String = "overhead_smash"
const OMEN_ID: String = "dread"
const LEGACY_CARD_ID: String = "legacy_card"
const LEGACY_MAP_REVISION: int = 5
const LEGACY_ROOM := Vector2i(1, 0)
const FOE_HP: int = 12
const OMEN_FIGHTS_LEFT: int = 1
const FORECAST_WAIT: int = 2
const FIXTURE_FOE_SIZE := Vector2(152, 184)
const FIXTURE_CARD_SIZE := Vector2(250, 352)
const BLANK: String = " \t\n"

var host := RunScene.new()
var summary := ColorRect.new()
var pinned := ColorRect.new()

func _init() -> void:
	host._pre_battle_scrim = summary
	host._pinned_tooltip_scrim = pinned
	pinned.hide()

func dispose() -> void:
	host.free()
	summary.free()
	pinned.free()

func foe() -> Control:
	return View.build_foe(host, {"type": FOE_ID, "hp": FOE_HP, "max_hp": FOE_HP}, FIXTURE_FOE_SIZE)

func strip() -> Control:
	return View._card_strip(host, {"card_id": CARD_ID, "count": 1}, "deck")

func gear() -> Control:
	var socket := Controls.Gear.new()
	socket.host = host
	socket.equipment_id = str(Data.starting_equipped_equipment()["weapon"])
	var definition: Dictionary = Data.equipment_def(socket.equipment_id)
	socket.setup(AssetLoader.load_texture(str(definition["icon_path"])), "equipment:" + socket.equipment_id)
	return socket

func suppress(target: Control) -> void:
	# RunScene clears the original source's tooltip when it opens a pinned inspection.
	host._suppress_pinned_tooltip_source(target)
	pinned.show()

func unsuppress() -> void:
	host._restore_pinned_tooltip_source()
	pinned.hide()

static func pass_button() -> Button:
	var button := Pass.new()
	button.text = "PASS"
	return button

static func show_forecast(button: Button) -> void:
	var summary_data: Dictionary = {"wait_time": FORECAST_WAIT}
	var portraits: Array[Dictionary]
	Forecast.configure(button, Forecast.rows(summary_data, portraits, {}))
	Forecast.refresh(button, true)

static func omen() -> Control:
	var grid := GridContainer.new()
	var badges := Omens.new()
	badges.sync(grid, {"omens": [{"id": OMEN_ID, "fights_left": OMEN_FIGHTS_LEFT}]}, true)
	var badge: Control = badges.badges[OMEN_ID]
	grid.remove_child(badge)
	grid.free()
	return badge

static func battlefield() -> Control:
	var hud := RuleHud.new()
	hud.set_combat_state({"battlefield_rule": {"rule": "gust", "source": {"kind": "room"}}}, null)
	return hud

static func heading() -> Control:
	var control := Heading.new()
	var objective: Dictionary = {"type": "kill_all"}
	control.text = "OBJECTIVE"
	control.tooltip_text = Catalog.description_for_objective(objective)
	return control

static func graft_choice() -> Control:
	var button := Choice.new()
	button.reduced_motion = true
	button.size = FIXTURE_CARD_SIZE
	var card: Control = Card.instantiate()
	card.size = FIXTURE_CARD_SIZE
	card.configure(CARD_ID, false, false, true, false, false)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(card)
	button.card_face = card
	return button

static func legend(revealed: bool) -> Control:
	var map := Map.new()
	map.run_state = {"section_map_layout_revision": LEGACY_MAP_REVISION, "rooms": {
		"1,0": {"type": "combat", "coord": LEGACY_ROOM, "section_index": 0, "revealed": revealed}
	}}
	map._legend = map._build_legend()
	map.add_child(map._legend)
	map._add_legend_item("combat")
	var item: Control = map._legend.get_child(0)
	map._legend.remove_child(item)
	map.free()
	return item

static func chronicle_icon() -> Control:
	var chronicle := Chronicle.new()
	var path := VBoxContainer.new()
	chronicle._build_path({"path": [["combat"]], "section_names": [], "dragon_ids": [], "outcome": "defeat"}, path)
	var icon: Control = path.find_child("PathSection0Room0", true, false)
	icon.get_parent().remove_child(icon)
	path.free()
	chronicle.free()
	return icon

static func chronicle_tile(id: String) -> Control:
	var tile := Tile.new()
	tile.configure(id, 1, {})
	return tile

static func empower(detail: String) -> Control:
	var seal := Seal.new()
	seal.configure(false, false, false, true, "", detail)
	return seal

func move(with_tooltip: bool) -> Control:
	if with_tooltip:
		var intent: Dictionary = Data.enemy_def(FOE_ID)["intents"][0]
		return Inspection.build_move(host, intent, {"kind": "enemy", "id": FOE_ID})
	return Inspection.build_move(host, {"name": "Move", "actions": []})

static func trait_row(detail: String) -> Control:
	return Inspection.build_trait({"value": "Burst", "tooltip": detail})
