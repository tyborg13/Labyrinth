extends "res://tools/tooltip_loops/capture.gd"
## Exercise the shipped source hover and every registered Grimoire entry.

const Grimoire = preload("res://scripts/grimoire_library.gd")
const Tip06Capture = preload("res://tools/tooltip_loops/tip06_capture.gd")
const CYCLES: int = 5
const FRAME_WATCHDOG_MSEC: int = 2000

var attempts: int
var opened: int
var closed: int
var routes: int

func _run() -> void:
	var headless: bool = DisplayServer.get_name() == "headless"
	Engine.max_fps = 60
	root.size = Playback.SIZE
	root.content_scale_size = Playback.SIZE
	if headless:
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	viewport = Playback.canvas(self)
	viewport.gui_embed_subwindows = true
	viewport.notify_mouse_entered()
	DirAccess.make_dir_recursive_absolute(output_dir())
	for row: Dictionary in Registry.entries():
		if row.has("todo_design"): continue
		var fixture: Dictionary = Fixture.build(row["id"])
		var entries: Array = row.get("grimoire_entries", [])
		var card_id: String = fixture["card"]
		var card_entry: String = _grimoire_card_entry(row, card_id)
		var unlocks: Array = entries.duplicate()
		if not card_entry.is_empty(): unlocks.append(card_entry)
		fixture["run"] = Grimoire.unlock_entries(fixture["run"], unlocks)["state"]
		var scene: Node = await Playback.instance(self, viewport, fixture, false)
		var prepared: Dictionary = await OpenProof.prepare(self, scene, row)
		Registry.proof_media_disabled = false
		await _cycles(scene, prepared["route"], "", headless)
		if not card_entry.is_empty():
			await _grimoire_card(scene, row, card_entry, card_id, headless)
		for entry: String in entries:
			scene._open_grimoire_overlay()
			scene._on_grimoire_entry_pressed(entry)
			await _frame_max(OUTER_POPUP_SETTLE_FRAMES)
			await _cycles(scene, row, entry, headless)
			scene._close_grimoire_overlay()
		scene.queue_free()
		await process_frame
	await OpenProof.expire(self)
	var cache: Dictionary = OpenProof.audit(self)
	_expect(cache["streams"].is_empty() and cache["owners"].is_empty(), "all loop streams and player nodes retired")
	print("QA113 LOOPS: routes=%d attempts=%d opened=%d released=%d owners=%d streams=%d" %
		[routes, attempts, opened, closed, cache["owners"].size(), cache["streams"].size()])
	_finish("QA113 LOOP LIFETIME")

func _grimoire_card_entry(row: Dictionary, card_id: String) -> String:
	var id: String = row["id"]
	if id == Fixture.Tip07.COLLISION or row["source_match"]["kind"] != "hero_card": return ""
	if Fixture.Tip07.EQUIPMENT.has(id): return Grimoire.equipment_entry_id(Fixture.Tip07.EQUIPMENT[id])
	if id == Fixture.Tip06.SWAP: return Tip06Capture.EMPTY_HUSK_GRIMOIRE
	return Grimoire.magick_entry_id(card_id) if Grimoire.is_magick_card_id(card_id) else ""

func _grimoire_card(scene: Node, row: Dictionary, entry: String, card_id: String, headless: bool) -> void:
	scene._open_grimoire_overlay()
	scene.set("_grimoire_selected_entry", entry)
	scene._refresh_grimoire_detail()
	await _frame_max(Playback.SETTLE_FRAMES)
	var content: Control = scene.get("_grimoire_detail_content")
	var term: String = Tip06Capture.CARD_ICONS.get(row["id"], row["term"])
	for card: CardWidget in content.find_children("CardWidget", "Button", true, false):
		if card.card_id != card_id or not card.is_visible_in_tree(): continue
		var hit: Control = card.find_child("SummaryToken_" + term, true, false)
		if hit != null:
			await _cycles(scene, row, "grimoire-card", headless, card, hit)
			scene._close_grimoire_overlay()
			return
	_expect(false, str(row["id"]) + ": missing Grimoire card or keyword hit region")
	scene._close_grimoire_overlay()

func _cycles(scene: Node, row: Dictionary, entry: String, headless: bool, card: Control = null, hit: Control = null) -> void:
	var id: String = row["id"]
	var label: String = id if entry.is_empty() else id + "_" + entry.replace(":", "-")
	var asset: String = row["asset_path"]
	var keyword: Control
	if card != null:
		keyword = card
	elif not entry.is_empty():
		for button: Control in scene._grimoire_nav_buttons:
			if button.get_meta("grimoire_nav_id", "") == entry:
				keyword = button
				break
		if keyword == null:
			_expect(false, label + ": missing Grimoire navigation control")
			return
		scene._grimoire_entry_scroll.ensure_control_visible(keyword)
		await process_frame
	routes += 1
	var successes: int = 0
	for iteration: int in range(CYCLES):
		attempts += 1
		var panel: Control
		if keyword == null:
			panel = await _open(scene, row)
		else:
			var target: Control = hit if hit != null else keyword
			await _pointer(target.get_global_rect().get_center())
			await create_timer(HOVER_WAIT_SECONDS, true, false, true).timeout
			panel = _tooltip(keyword)
		var player: Control
		if is_instance_valid(panel):
			for candidate: Control in panel.find_children("TooltipLoopWindow", "Control", true, false):
				if candidate.asset_path == asset and candidate.is_visible_in_tree():
					player = candidate
					break
		var tag: String = "%s cycle %d" % [label, iteration + 1]
		_expect(player != null, tag + ": production tooltip has no matching loop")
		var witness: WeakRef
		if player != null:
			opened += 1
			witness = weakref(player)
			var deadline: int = Time.get_ticks_msec() + FRAME_WATCHDOG_MSEC
			while player.displayed_frame < 0 and Time.get_ticks_msec() < deadline:
				await process_frame
			var active: Dictionary = Cache.diagnostics_if_present().get(asset, {})
			var decoded: bool = player.displayed_frame >= 0 and int(active.get("users", 0)) == 1
			_expect(decoded and int(active.get("cached_frames", 0)) <= Cache.FRAME_LIMIT, tag + ": missing decoded frame or unbounded cache")
			if decoded and not headless and iteration == 0: await _capture("qa113_loop_" + label)
		await _pointer(CLEAR_POINTER)
		scene._card_focus_tooltip_stack.hide_stack(true)
		await _frame_max(OpenProof.CLEANUP_FRAMES)
		var released: bool = witness != null and witness.get_ref() == null and int(Cache.diagnostics_if_present().get(asset, {}).get("users", 0)) == 0
		if released:
			closed += 1
			successes += 1
		elif witness != null:
			_expect(false, tag + ": player or stream lease retained after close")
	print("QA113 LOOP ", JSON.stringify({"case": label, "seed": Fixture.SEED, "released": successes, "cycles": CYCLES}))
