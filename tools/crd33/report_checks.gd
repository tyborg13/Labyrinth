extends SceneTree
## Report-only witnesses through committed plays and the live combat HUD.

const Fight = preload("res://tools/crd33/fight.gd")
const LiveFight = preload("res://tools/crd33/live_fight.gd")
const BookData = preload("res://scripts/grimoire_library.gd")
const Data = preload("res://scripts/game_data.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const Keywords = preload("res://scripts/card_keyword_rules.gd")
const Tempo = preload("res://scripts/tempo_rules.gd")

const EXPENSIVE_CARD := "skybolt"
const MINIMUM_CARD := "brace"
const STAGGER_SETUP := "petrify"
const SECOND_STAGGER := "crushing_blow"
const TARGET_ID := 1
const NO_TILE := Vector2i(-1, -1)
const IMMUNE_UNIT := "zekarion"
const IMMUNE_COPY := "This enemy is immune to Shock."

var _fight := Fight.new()
var _live := LiveFight.new()
var _failures: Array[String]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if await _live.start(self):
		await _quicken()
		await _stagger()
		await _skybolt()
	else:
		_failures.append("RunScene did not finish loading")
	await _live.close()
	for failure: String in _failures:
		push_error(failure)
	print("CRD33 REPORT CHECKS: %s (%d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _failures.size()])
	quit(int(not _failures.is_empty()))


func _quicken() -> void:
	var baseline: Dictionary = _fight.play(_fight.fresh(), EXPENSIVE_CARD, [Fight.NEAR], true)
	if not _expect(not baseline.has("blocked"), "Quicken baseline commits " + EXPENSIVE_CARD): return
	var normal: int = _spent_time(baseline)
	if not _expect(normal >= 5, "Control card costs at least 5 Time"): return
	for id: String in Data.cards():
		var actions: Array = Data.card_def(id).get("actions", [])
		if not actions.any(func(action: Dictionary) -> bool: return action["type"] == "quicken"): continue
		var state: Dictionary = _fight.fresh()
		state["deck"]["hand"] = [EXPENSIVE_CARD]
		var first: Dictionary = _fight.play(state, id)
		if not _expect(not first.has("blocked"), "%s commits during Quicken setup" % id): continue
		var quickened: Dictionary = first["after"]
		var pending: int = Tempo.quicken_pending(quickened)
		await _live.install(quickened)
		var hand: Array = quickened["deck"]["hand"]
		var index: int = hand.find(EXPENSIVE_CARD)
		var widget: CardWidget = _live.scene.call("_hand_card_control", index)
		var badge: Control = widget.get_node("TimeCostBadge") if widget != null else null
		var shown: int = int(badge.get("value")) if badge != null and badge.is_visible_in_tree() else -1
		var unselected: bool = int(_live.scene.get("_selected_card_index")) < 0
		var next: Dictionary = _fight.play(quickened, EXPENSIVE_CARD, [Fight.NEAR], true)
		var minimum: Dictionary = _fight.play(quickened, MINIMUM_CARD)
		if not _expect(not next.has("blocked") and not minimum.has("blocked"), "%s next-card witnesses commit" % id): continue
		var paid: int = _spent_time(next)
		var floor_time: int = _spent_time(minimum)
		_expect(pending > 0 and paid == normal - pending, "%s has the full Quicken reduction" % id)
		_expect(unselected and shown == paid, "%s shows the reduced badge before targeting" % id)
		_expect(floor_time == 1, "%s leaves Brace at the 1 Time floor" % id)
		_witness("quicken/" + id, {
			"next_card": EXPENSIVE_CARD, "normal_time": normal, "quicken": pending, "paid_time": paid,
			"hand_time_before_click": shown, "card_unselected": unselected, "brace_time_with_quicken": floor_time,
		})


func _stagger() -> void:
	var control: Dictionary = await _stagger_hover(_fight.fresh())
	var petrify: Dictionary = _fight.play(_fight.fresh(), STAGGER_SETUP, [Fight.NEAR], true)
	if not _expect(not petrify.has("blocked"), "Petrify commits to the test enemy"): return
	var capped: Dictionary = await _stagger_hover(petrify["after"])
	var book: Dictionary = BookData.entry_def("keyword:stagger")
	var body: String = " ".join(book.get("body", []))
	var cap_text: String = "Each unit takes up to 6 Stagger per turn."
	_expect(control["legal"] and control["preview_delay"] == 3 and control["time_delta"] == 3,
		"Crushing Blow previews Stagger 3 on the uncapped enemy")
	_expect(capped["legal"] and capped["stagger_already_applied"] == 6 and capped["preview_delay"] == 0
		and capped["time_delta"] == 0 and capped["preview_slot"] == capped["baseline_slot"],
		"Crushing Blow leaves the capped enemy in its existing turn-order slot")
	_expect(body.contains(cap_text), "Grimoire contains the Stagger cap line")
	_witness("stagger/uncapped", control)
	_witness("stagger/after_petrify", capped)
	_witness("stagger/grimoire", {"line": cap_text, "present": body.contains(cap_text)})


func _stagger_hover(state: Dictionary) -> Dictionary:
	state["deck"]["hand"] = [SECOND_STAGGER]
	await _live.install(state)
	var scene: Node = _live.scene
	await scene.call("_on_card_pressed", 0)
	scene.call("_on_board_tile_hovered", Fight.NEAR)
	scene.call("_refresh_board_hover_presentation")
	await _live.settle()
	var preview: Dictionary = scene.call("_active_card_preview")
	var legal: bool = (preview.get("target_tiles", []) as Array).has(Fight.NEAR)
	var baseline: Dictionary = _enemy_slot(scene.call("_project_turn_order_entries", scene.call("_turn_order_display_state", {})))
	var hovered: Dictionary = _enemy_slot(scene.get("_turn_order_all_entries"))
	_expect(not baseline.is_empty() and not hovered.is_empty(), "The enemy is present on the turn order rail")
	var delays: Dictionary = scene.call("_turn_order_stagger_preview_delays")
	var receipt: Dictionary = {
		"card": SECOND_STAGGER, "hover_tile": Fight.NEAR, "legal": legal,
		"stagger_already_applied": Keywords.stagger_applied_this_turn(state, TARGET_ID),
		"preview_delay": int(delays.get(TARGET_ID, 0)),
		"baseline_slot": baseline.get("slot", -1), "preview_slot": hovered.get("slot", -1),
		"baseline_time": baseline.get("time", -1), "preview_time": hovered.get("time", -1),
		"time_delta": int(hovered.get("time", -1)) - int(baseline.get("time", -1)),
		"slot_stagger_badge": int(hovered.get("stagger_preview", 0)),
	}
	scene.call("_on_board_tile_hovered", NO_TILE)
	scene.call("_on_cancel_requested")
	return receipt


func _skybolt() -> void:
	var state: Dictionary = _fight.fresh([Fight.NEAR, Fight.THIRD])
	for tile: Vector2i in [Fight.NEAR, Fight.SECOND, Fight.THIRD]:
		Ground.place(state, tile, "electrified")
	var control: Dictionary = _fight.play(state, "skybolt", [Fight.NEAR], true)
	state["enemies"][1]["type"] = IMMUNE_UNIT
	var immune: Dictionary = _fight.play(state, "skybolt", [Fight.NEAR], true)
	if not _expect(not immune.has("blocked") and not control.has("blocked"), "Both Skybolt plays commit"): return
	var controlled: Dictionary = control["after"]["enemies"][1]
	var conducted: Dictionary = immune["after"]["enemies"][1]
	await _live.install(immune["after"])
	var scene: Node = _live.scene
	var board: Control = scene.get("board_view")
	var badges: Array[Dictionary] = board.call("_unit_status_badges", conducted)
	var trait_hover: String = "Immune\n" + IMMUNE_COPY
	var badge_shown: bool = badges.any(func(badge: Dictionary) -> bool: return badge.get("tooltip") == trait_hover)
	_expect(int(controlled["shock"]) == 1 and int(conducted["shock"]) == 0
		and controlled["hp"] == conducted["hp"] and int(conducted["hp"]) < Fight.HEALTH,
		"The same conducted hit adds Shock to the control and omits it for Zekarion")
	_expect(badge_shown, "Zekarion has the Shock immunity trait chip")
	var page_id: String = "enemy:" + IMMUNE_UNIT
	var run: Dictionary = scene.get("_run_state")
	scene.set("_run_state", BookData.unlock_entries(run, [page_id])["state"])
	scene.call("_on_grimoire_button_pressed")
	await _live.settle()
	var book: Control = scene.get("_grimoire_scrim")
	book.call("_on_grimoire_entry_pressed", page_id)
	await _live.settle()
	var traits: Node = book.find_child("GrimoireTraits", true, false)
	var grimoire_shown: bool = traits != null and LiveFight.visible_text(traits).has(IMMUNE_COPY)
	_expect(grimoire_shown, "Zekarion's Grimoire page renders the immunity in Traits")
	_witness("skybolt/immunity", {
		"conducted_to": Fight.THIRD, "damage_each": Fight.HEALTH - int(conducted["hp"]),
		"control_shock": int(controlled["shock"]), "zekarion_shock": int(conducted["shock"]),
		"status_plate_trait": trait_hover if badge_shown else "",
		"grimoire_traits": IMMUNE_COPY if grimoire_shown else "",
	})
	book.call("close")
	await _live.settle()


static func _enemy_slot(entries: Array) -> Dictionary:
	for index: int in range(entries.size()):
		var entry: Dictionary = entries[index]
		if entry.get("kind") == "enemy" and int(entry.get("enemy_id", -1)) == TARGET_ID:
			var result: Dictionary = entry.duplicate()
			result["slot"] = index
			return result
	return {}


static func _spent_time(play: Dictionary) -> int:
	return int(play["after"]["player_turn_time_spent"]) - int(play["before"]["player_turn_time_spent"])


static func _witness(id: String, payload: Dictionary) -> void:
	print("CRD33 WITNESS %s %s" % [id, JSON.stringify(payload)])


func _expect(condition: bool, message: String) -> bool:
	if not condition: _failures.append(message)
	return condition
