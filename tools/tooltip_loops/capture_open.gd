extends RefCounted
## Same-context counterfactual. Never changes catalog/asset values or clears caches.
const Fixture = preload("res://tools/tooltip_loops/fixture.gd")
const Registry = preload("res://scripts/tooltip_loop_registry.gd")
const Cache = preload("res://scripts/tooltip_loop_cache.gd")
const Context = preload("res://scripts/tooltip_loop_context.gd")
const CLEANUP_FRAMES: int = 8 # Debug deferred native-popup teardown acknowledgement.
const EXPIRY_WATCHDOG_USEC: int = 12000000 # Debug worker/expiry failure bound, never a new cache lifetime.

static func prepare(proof: SceneTree, scene: Node, row: Dictionary) -> Dictionary:
	Registry.proof_media_disabled = true
	proof._start_frame_sample()
	var started: int = Time.get_ticks_usec()
	var timings: Dictionary = {}
	var route: Dictionary = row.duplicate(true)
	if row["id"] == "freeze_status":
		var stage: int = Time.get_ticks_usec()
		var fixture: Dictionary = Fixture.build("freeze_status")
		timings["fixture_build_usec"] = Time.get_ticks_usec() - stage
		stage = Time.get_ticks_usec()
		var result: Dictionary = Fixture.plan(fixture, preload("res://scripts/hero_facing_combat.gd").new())
		timings["fixture_plan_usec"] = Time.get_ticks_usec() - stage
		var run: Dictionary = fixture["run"].duplicate(true)
		run["combat_state"] = result["beats"][0]["after"]
		stage = Time.get_ticks_usec()
		scene.call("_load_run_state", run)
		scene.call("_close_dialogue")
		timings["load_run_state_usec"] = Time.get_ticks_usec() - stage
		route["source_match"] = Context.enemy("crawler")
	var id: String = row["id"]
	if Fixture.Tip10.IDS.has(id):
		route["source_match"] = Fixture.Tip10.source(id)
	if route["source_match"].get("kind") == "enemy": await proof._prepare_enemy_inspection(scene)
	await proof._frame_max(proof.OUTER_POPUP_SETTLE_FRAMES)
	timings["total_usec"] = Time.get_ticks_usec() - started
	timings["max_frame_usec"] = proof._stop_frame_sample()
	timings["loop_disabled"] = true
	return {"route": route, "timings": timings}

static func measure(proof: SceneTree, scene: Node, row: Dictionary, media: bool) -> Dictionary:
	Registry.proof_media_disabled = not media
	proof._start_frame_sample()
	var started: int = Time.get_ticks_usec()
	var panel: Control = await proof._open(scene, row)
	var route_usec: int = Time.get_ticks_usec() - started
	if panel != null: await proof._frame_max(proof.SAMPLE_FRAMES)
	var maximum: int = proof._stop_frame_sample()
	var window: Control = panel.find_child("TooltipLoopWindow", true, false) if panel != null else null
	proof._expect(panel != null, "Same context opens with media %s: %s" % [media, row["id"]])
	proof._expect((window != null) == media, "Counterfactual changes only media attachment: " + str(row["id"]))
	var owner_path: String = ""
	var icons: Array = []
	if panel != null:
		var host: Window = panel.get_window()
		owner_path = str(host.get_parent().get_path()) if host is PopupPanel else str(scene.call("_hand_card_control", 0).get_path())
		for icon: Node in panel.find_children("TooltipIcon", "TextureRect", true, false):
			icons.append(icon.texture.get_rid().get_id() if icon.texture != null else 0)
	return {"panel": panel, "window": window, "max_frame_usec": maximum, "route_usec": route_usec, "text": proof._popup_text(panel) if panel != null else "", "owner_path": owner_path, "icons": icons}

static func close(proof: SceneTree, scene: Node, panel: Control) -> Dictionary:
	var before: Dictionary = audit(proof)
	await proof._pointer(proof.CLEAR_POINTER)
	var stack: Control = scene.get("_card_focus_tooltip_stack")
	if stack != null: stack.hide_stack()
	# The capture owns opening the native popup; finish that interaction before
	# destroying/reloading its owner, including the final tooltip of the process.
	if is_instance_valid(panel):
		var popup: Window = panel.get_window()
		if popup is PopupPanel: popup.hide()
	for frame: int in range(CLEANUP_FRAMES): await proof.process_frame
	var after: Dictionary = audit(proof)
	for path: String in after["streams"]:
		proof._expect(int(after["streams"][path]["users"]) == 0, "Closed tooltip released its lease: " + path + " owners=" + JSON.stringify(after["owners"]))
	return {"before_close": before, "after_close": after}

static func audit(proof: SceneTree) -> Dictionary:
	var owners: Array[Dictionary]
	_collect(proof.root, owners)
	return {"now_usec": Time.get_ticks_usec(), "streams": Cache.diagnostics_if_present(), "owners": owners}

static func _collect(node: Node, owners: Array[Dictionary]) -> void:
	if node.has_method("window_rect") and node.name == "TooltipLoopWindow":
		var host: Window = node.get_window()
		owners.append({"path": str(node.get_path()), "asset_path": node.asset_path, "leased": node._leased, "visible": node.is_visible_in_tree(), "window_path": str(host.get_path()), "window_visible": host.visible})
	for child: Node in node.get_children(true): _collect(child, owners)

static func expire(proof: SceneTree) -> Dictionary:
	var before: Dictionary = audit(proof)
	var started: int = Time.get_ticks_usec()
	var deadline: int = started
	for stream: Dictionary in before["streams"].values():
		if int(stream["users"]) > 0:
			return {"before_expiry": before, "after_expiry": audit(proof), "elapsed_usec": 0}
		deadline = maxi(deadline, int(stream["release_at_usec"]))
	# Cache expiry uses Time.get_ticks_usec(), not SceneTreeTimer's delta clock.
	# Service exactly the latest release deadline, plus two process boundaries.
	while Time.get_ticks_usec() < deadline and Time.get_ticks_usec() - started < EXPIRY_WATCHDOG_USEC:
		await proof.process_frame
	await proof.process_frame
	await proof.process_frame
	return {"before_expiry": before, "after_expiry": audit(proof), "deadline_usec": deadline, "elapsed_usec": Time.get_ticks_usec() - started}
