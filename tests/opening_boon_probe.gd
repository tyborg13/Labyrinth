extends "res://tests/pre_battle_fixture.gd"

const Boons = preload("res://scripts/opening_boon_rules.gd")
const Fixture = preload("res://tests/helpers/opening_boon_fixture.gd")
const Proof = preload("res://tests/helpers/opening_boon_proof.gd")
const ProofStrip = preload("res://tests/helpers/proof_strip.gd")
const HeirloomFixture = preload("res://tests/helpers/heirloom_fixture.gd")
const HeirloomChecks = preload("res://tests/helpers/heirloom_checks.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const OUTPUT_ROOT: String = "user://opening_boon_probe/1920x1080"
var _verify_only: bool = false
var _captures: Array[String]
var _purge_pair_captured: bool = false
var _secondary_geometry: Dictionary = {}
var _maximum_relic_rule_height: int = 0
var _relic_rules_proof: Dictionary = {}
var _heirloom_proof: Dictionary = {}

func _initialize() -> void:
	_setup()
	_verify_only = OS.get_cmdline_user_args().has("--verify-only")
	Settings.set_storage_path("user://opening_boon_probe_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	Analytics.set_storage_dir("user://opening_boon_probe_analytics")
	call_deferred("_run")

func _open(scene: Node, state: Dictionary) -> Control:
	ProgressionStore.save_data(state["progression"])
	scene.call("_load_run_state", state)
	scene.call("_speak_to_emaciated_man")
	scene.call("_complete_current_dialogue_line")
	await _settle()
	var modal: Control = scene.get("_opening_boon_flow").overlay
	_expect(modal != null, "Proof opens the actual offer modal")
	_expect(not bool(scene.get("_large_map_scrim").visible), "Proof keeps the start room behind the modal")
	if modal != null: Proof.offer(scene, modal, _expect)
	return modal

func _run() -> void:
	ProgressionStore.save_data(Fixture.profile())
	var scene: Node = await _instance(Fixture.state())
	_relic_rules_proof = await preload("res://tests/helpers/opening_boon_relic_proof.gd").run(_viewport, scene, _expect)
	_maximum_relic_rule_height = int(_relic_rules_proof["maximum_height"])
	for with_heirloom: bool in [false, true]:
		var modal: Control = await _open(scene, Fixture.state(with_heirloom))
		if modal == null: continue
		await _save("offer_with_heirloom.png" if with_heirloom else "offer_without_heirloom.png")
		if not with_heirloom:
			var spell: Control = modal.find_child("BoonSpell_*", true, false)
			await _pointer(spell.get_global_rect().get_center())
			await _settle()
			_expect(modal.get("_tooltip") != null, "Strip hover exposes the real full-card preview beside its boon")
			await _save("offer_spell_preview.png")
			await _key(KEY_ESCAPE)
			_expect(scene.get("_opening_boon_flow").active(), "Esc cannot silently dismiss the initial offer")
			modal.find_child("Boon_elemental_gift", true, false).grab_focus()
			await _key(KEY_ENTER)
			await _settle()
			Proof.secondary(scene, modal, 3, _expect)
			_expect(not modal.get("_secondary_tooltips").visible, "Elemental Gift opens without a tooltip stack")
			_record_geometry(modal, "elemental_gift")
			await _save("elemental_gift_choice.png")
			await _joy(JOY_BUTTON_A)
			await _settle()
			_expect(not Boons.pending(scene.get("_run_state")), "Proof accepts a real spell into the deck")
			scene.call("_complete_current_dialogue_line")
			Proof.rect_near(scene.get("_dialogue_dialog").get_global_rect(), Proof.contract()["geometry"]["OfferDialogue"], _expect, "Taking keeps the same NPC dialogue box")
			await _save("elemental_gift_taken.png")
			scene.call("_advance_dialogue")
			await _settle()
	await _additional_offers(scene)
	await _heirloom(scene)
	var report: Dictionary = {"resolution": "1920x1080", "ui_scale": 1.0, "geometry_tolerance_px": 1, "captures": _captures, "headless_semantics_only": _verify_only, "passed": not _failed, "secondary_geometry": _secondary_geometry, "maximum_relic_rule_height": _maximum_relic_rule_height, "relic_rules": _relic_rules_proof, "heirloom": _heirloom_proof}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_ROOT))
	var file := FileAccess.open(OUTPUT_ROOT + "/semantics.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("BOON PROBE REPORT: " + ProjectSettings.globalize_path(OUTPUT_ROOT + "/semantics.json"))
	# Drain the existing two-frame modal-layout refresh before scene disposal.
	await process_frame
	await process_frame
	scene.queue_free()
	_viewport.queue_free()
	await process_frame
	await process_frame
	print("OPENING BOON PROBE RESULT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _additional_offers(scene: Node) -> void:
	var modal: Control = await _open(scene, Fixture.state(false, Fixture.ALL_PREVIEWS_SEED))
	var offers: Array = scene.get("_run_state")[Boons.STATE_KEY]["offers"]
	_expect(offers[0].has("spells") and offers[1].has("relic") and offers[2]["boon"] == "debt", "All-previews capture uses a genuine seeded strip/object/glyph offer")
	await _save("offer_all_previews.png")
	modal = await _open(scene, Fixture.state())
	modal.find_child("Boon_purge", true, false).grab_focus()
	await _key(KEY_ENTER)
	await _settle()
	Proof.secondary(scene, modal, 6, _expect)
	_record_geometry(modal, "purge")
	_expect(not modal.get("_secondary_tooltips").visible, "Purge opens without a tooltip stack")
	var first: Control = modal.get("_controls")[0]
	await _click(first)
	_expect(first.get_node("RewardOwnershipBadge").get_child(0).text == "REMOVE", "Selecting Purge changes OWNED to REMOVE")
	await _click(first)
	_expect(first.get_node("RewardOwnershipBadge").get_child(0).text == "OWNED", "Deselecting restores OWNED")
	modal.purge_selection_ready.connect(_capture_purge_pair.bind(modal), CONNECT_ONE_SHOT)
	var controls: Array = modal.get("_controls")
	await _click(controls[0])
	await _click(controls[1])
	await _settle()
	_expect(_purge_pair_captured, "The submitted selected pair is captured before confirmation opens")
	_expect(is_instance_valid(modal.get("_confirmation")), "Purge then presents the production confirmation")
	var confirmation: Control = modal.get("_confirmation")
	if confirmation != null:
		await _pointer(confirmation.cancel_button.get_global_rect().get_center())
		await process_frame
		_expect(not modal.get("_secondary_tooltips").visible, "The Purge confirmation blocks inspection of cards underneath it")
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	modal = await _open(scene, Fixture.state(false, Fixture.BLOOD_PRICE_SEED))
	modal.find_child("Boon_blood_price", true, false).grab_focus()
	await _key(KEY_ENTER)
	await _settle()
	Proof.secondary(scene, modal, 5, _expect)
	_expect(not modal.get("_secondary_tooltips").visible, "Blood Price has no tooltip after automatic focus and no inspection input")
	await _save("secondary_open_no_tooltip.png")
	_record_geometry(modal, "blood_price")
	await _secondary_inspection(modal)
	await _save("blood_price_five_cards.png")

func _capture_purge_pair(modal: Control) -> void:
	_expect(not is_instance_valid(modal.get("_confirmation")), "Selected pair proof precedes confirmation creation")
	_expect(modal.get("_purge_indices") == [0, 1], "Two distinct copies of the same starter are selected")
	for index: int in [0, 1]:
		var widget: Control = modal.get("_controls")[index]
		var actual_lift: float = -widget.position.y * widget.get_parent().scale.y
		var tag: PanelContainer = widget.get_node("RewardOwnershipBadge")
		_expect(tag.get_child(0).text == "REMOVE" and tag.get_child(0).get_theme_color("font_color") == Palette.DANGER, "Both selected copies show REMOVE in the warning colour token")
		Proof.medallion(modal, widget, _expect)
		_expect(absf(actual_lift - 20.0) <= 1.0 and widget.get("_external_highlighted"), "Both selected cards lift exactly 20px with the focus finish")
	await _save("purge_two_selected.png")
	_purge_pair_captured = true

func _heirloom(scene: Node) -> void:
	await _pointer(Vector2(24.0, 800.0))
	for count: int in [4, 5, 1]:
		var view: Control = await HeirloomChecks.open(self, scene, count)
		HeirloomChecks.geometry(view, count, _expect)
		_heirloom_proof[str(count)] = {"row": [view.row.position.x, view.row.position.y, view.row.size.x, view.row.size.y], "card_count": view.cards.size(), "first_focused": _viewport.gui_get_focus_owner() == view.cards[0], "medallion": view.cards[0].medallion.size.x, "art": view.cards[0].art.size.x}
		_expect(_viewport.gui_get_focus_owner() == view.cards[0], "Heirloom proof starts with the first card focused")
		_expect(not scene.get("_dialogue_footer").visible and scene.get("_dialogue_choice_bar").get_child_count() == 0, "Heirloom dialogue keeps portrait and exact line, without options or footer")
		await _save("heirloom_choice_%d.png" % count)
		if count == 4: await _save("heirloom_prompt.png")
	var view: Control = await HeirloomChecks.open(self, scene, 4)
	view.call("_choose", 0)
	view.ceremony.fixed_clock = true
	view.ceremony.seek(HeirloomFixture.BURN_CLOCK_SECONDS)
	_expect(view.ceremony.burns.size() == 3, "Every non-chosen card uses the burn material")
	for burn: Control in view.ceremony.burns:
		_expect(is_equal_approx(float(burn.burn_material.get_shader_parameter("progress")), 0.36), "Burn proof holds the ease-in quad dissolve at exactly 0.30s")
	_heirloom_proof["burn"] = {"seconds": view.ceremony.elapsed, "cards": view.ceremony.burns.size(), "progress": view.ceremony.burns[0].burn_material.get_shader_parameter("progress"), "embers_per_card": view.ceremony.burns[0].sparks.size()}
	await _save("heirloom_ceremony_burn.png")
	view.ceremony.seek(HeirloomFixture.MID_CLOCK_SECONDS)
	_expect(view.ceremony.elapsed == 0.70 and view.ceremony.get_node("HeirloomFlyingArt").visible, "Ceremony proof is held at exactly 0.70 seconds")
	_heirloom_proof["ceremony"] = {"seconds": view.ceremony.elapsed, "flight_visible": view.ceremony.get_node("HeirloomFlyingArt").visible, "flight_scale": view.ceremony.get_node("HeirloomFlyingArt").scale.x}
	await _save("heirloom_ceremony_mid.png")
	var settings: Dictionary = Settings.default_settings()
	settings["reduced_motion"] = true
	Settings.apply_settings(settings, null, false)
	scene.set("_settings", settings)
	view = await HeirloomChecks.open(self, scene, 4)
	await _save("heirloom_prompt_reduced_motion.png")
	view.call("_choose", 0)
	view.ceremony.fixed_clock = true
	view.ceremony.seek(HeirloomFixture.CROSSFADE_PROOF_SECONDS)
	_expect(view.ceremony.reduced_motion and view.ceremony.get_node_or_null("HeirloomFlyingArt") == null, "Reduced-motion proof uses only the crossfade")
	_heirloom_proof["reduced_motion"] = {"seconds": view.ceremony.elapsed, "reduced": view.ceremony.reduced_motion, "row_alpha": view.row.modulate.a, "duration": view.ceremony.duration()}
	await _save("heirloom_reduced_motion.png")
	settings["reduced_motion"] = false
	Settings.apply_settings(settings, null, false)
	scene.set("_settings", settings)
	view = await HeirloomChecks.open(self, scene, 0)
	_expect(view == null and scene.get("_run_end_recap").visible and not scene.get("_dialogue_active"), "Starter-only proof shows the real recap without dialogue")
	_expect(scene.get("_run_state")[Boons.HEIRLOOM_END_KEY] == {"item": "", "done": true}, "Starter-only proof records exactly Leave nothing")
	_heirloom_proof["starter_only"] = {"recap_visible": scene.get("_run_end_recap").visible, "dialogue_active": scene.get("_dialogue_active"), "heirloom_end": scene.get("_run_state")[Boons.HEIRLOOM_END_KEY]}
	await _save("heirloom_starter_only_skipped.png")
	_heirloom_contact_sheet()

func _heirloom_contact_sheet() -> void:
	if _verify_only: return
	# Proof-only 3x3 contact sheet; all source captures remain native.
	var names := PackedStringArray(["heirloom_choice_4", "heirloom_choice_5", "heirloom_choice_1", "heirloom_ceremony_burn", "heirloom_ceremony_mid", "heirloom_reduced_motion", "heirloom_starter_only_skipped"])
	var frames: Array[String]
	for index: int in range(names.size()):
		frames.append(OUTPUT_ROOT + "/" + names[index] + ".png")
	var path: String = OUTPUT_ROOT + "/heirloom_contact_sheet.png"
	_expect(ProofStrip.save_png(frames, 3, path, Vector2i(640, 360), Palette.INK_0) == OK, "Heirloom contact sheet saves")
	print("HEIRLOOM CONTACT SHEET: " + ProjectSettings.globalize_path(path))

func _save(name: String) -> void:
	if _verify_only: return
	var path: String = OUTPUT_ROOT + "/" + name
	await _capture(path)
	_captures.append(ProjectSettings.globalize_path(path))
	print("BOON CAPTURE: " + ProjectSettings.globalize_path(path))

func _secondary_inspection(modal: Control) -> void:
	var cards: Array = modal.get("_controls")
	await _key(KEY_RIGHT)
	await _settle()
	_expect(_viewport.gui_get_focus_owner() == cards[1], "Keyboard navigation moves focus before enabling inspection")
	Proof.tooltip(modal, _expect)
	Proof.medallion(modal, cards[1], _expect)
	await _joy(JOY_BUTTON_DPAD_RIGHT)
	await _settle()
	_expect(_viewport.gui_get_focus_owner() == cards[2], "Controller navigation enables the focused card's inspection")
	Proof.tooltip(modal, _expect)
	Proof.medallion(modal, cards[2], _expect)
	await _pointer(cards[3].get_global_rect().get_center())
	await _settle()
	Proof.tooltip(modal, _expect)
	Proof.medallion(modal, cards[3], _expect)

func _record_geometry(modal: Control, key: String) -> void:
	var row: Control = modal.find_child("BoonSpellChoices", true, false)
	_secondary_geometry[key] = {"row_top": row.global_position.y, "card_width": row.get_child(0).size.x, "card_height": row.get_child(0).size.y}
