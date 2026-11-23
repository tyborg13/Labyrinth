extends SceneTree
## The retired keyword clips leave the existing tooltip owners in place.
const Routes = preload("res://tools/tooltip_loops/tip12_routes.gd")
const Playback = Routes.Playback
const Context = Routes.Context
const Registry = Routes.Registry
const Icons = Routes.Icons
const CardScene = Routes.CardScene
const Stack = preload("res://scripts/card_focus_tooltip_stack.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const TooltipButton = preload("res://scripts/ui_tooltip_button.gd")
const KEYWORD_CARDS: Dictionary = {"empower": "blood_price", "follow_up": "main_gauche"}
const RETIRED_TERMS: Array = ["immobilize", "block", "empower", "follow_up"]

var _errors: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	var before: int = _errors.size()
	Routes.audit(_errors)
	print("TIP12 KEYWORD OWNERSHIP: %s" % ["PASS" if _errors.size() == before else "FAIL"])
	await Routes.audit_feedback(self, _errors)
	for term: String in RETIRED_TERMS:
		_check_retired_route(term)
	var viewport: SubViewport = Playback.canvas(self)
	for term: String in KEYWORD_CARDS:
		before = _errors.size()
		_check_grimoire(term)
		await _check_card(viewport, term, KEYWORD_CARDS[term])
		print("TIP12 TEXT-ONLY %s: %s" % [term, "PASS" if _errors.size() == before else "FAIL"])
	viewport.queue_free()
	await process_frame
	for failure: String in _errors: push_error(failure)
	print("TIP12 TOOLTIP SEMANTICS RESULT: %s (%d failures)" % ["PASS" if _errors.is_empty() else "FAIL", _errors.size()])
	quit(0 if _errors.is_empty() else 1)

func _check_retired_route(term: String) -> void:
	var entry_id: String = "keyword:" + term
	var path: String = "res://assets/tooltip_loops/" + term + ".tlw"
	_expect(Registry.find(term, {}).is_empty() and Context.term_in(Icons.tooltip(term), {}).is_empty(), term + ": canonical tooltip has no loop route")
	_expect(Registry.grimoire_term(entry_id).is_empty(), term + ": Grimoire has no loop binding")
	_expect(not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".json"), term + ": recording and receipt were removed")

func _check_grimoire(term: String) -> void:
	var entry_id: String = "keyword:" + term
	var button := TooltipButton.new()
	button.set_meta("grimoire_nav_id", entry_id)
	button.tooltip_text = Grimoire.entry_def(entry_id).get("title", "")
	_check_panel(button._make_custom_tooltip(button.tooltip_text), term + ": Grimoire keyword tab")
	button.free()

func _check_card(viewport: SubViewport, term: String, card_id: String) -> void:
	var card: Control = CardScene.instantiate()
	card.configure(card_id)
	viewport.add_child(card)
	for frame: int in range(Playback.SETTLE_FRAMES): await process_frame
	var token: Control = card.find_child("SummaryToken_" + term, true, false)
	_expect(token != null, term + ": authored card keyword token exists")
	if token != null:
		var local: Vector2 = card.get_global_transform().affine_inverse() * token.get_global_rect().get_center()
		var tooltip: String = card.call("_get_tooltip", local)
		_expect(not tooltip.is_empty() and tooltip == token.tooltip_text, term + ": native card hover retains the keyword text")
		_check_panel(card._make_custom_tooltip(tooltip), term + ": native card hover")
	var entries: Array[Dictionary] = Icons.tooltip_entries_for_rows(card.display_summary_rows())
	var index: int = entries.find_custom(func(entry: Dictionary) -> bool: return entry.get("glossary_key") == term)
	_expect(index >= 0, term + ": card focus tooltip retains the keyword entry")
	if index >= 0:
		var entry: Dictionary = entries[index]
		var body := PackedStringArray([entry.get("description", "")])
		_check_panel(Stack.make_entry_panel(entry, body, false, card_id), term + ": card focus tooltip")
	if term == "empower":
		card.set_empower_state(true, true, true, false, false, "", Icons.tooltip(term))
		var seal: Button = card.get_node("EmpowerSeal")
		_check_panel(seal._make_custom_tooltip(seal.tooltip_text), "Empower: charged seal tooltip")
	card.queue_free()
	await process_frame

func _check_panel(panel: Control, owner: String) -> void:
	_expect(panel != null, owner + " keeps its tooltip")
	if panel == null: return
	_expect(panel.find_child("TooltipLoopWindow", true, false) == null, owner + " has no loop")
	panel.free()

func _expect(ok: bool, failure: String) -> void:
	if not ok: _errors.append(failure)
