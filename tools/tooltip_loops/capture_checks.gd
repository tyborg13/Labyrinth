extends RefCounted
## Focused ownership/timing proof; headless results never stand in for GPU budgets.
const Registry = preload("res://scripts/tooltip_loop_registry.gd")
const Cache = preload("res://scripts/tooltip_loop_cache.gd")
const TooltipPanel = preload("res://scripts/ui_tooltip_panel.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const OpenProof = preload("res://tools/tooltip_loops/capture_open.gd")
const Fixture = preload("res://tools/tooltip_loops/fixture.gd")
const Playback = preload("res://tools/tooltip_loops/playback.gd")
const LoopView = preload("res://scripts/tooltip_loop_view.gd")
const Recorder = preload("res://tools/tooltip_loops/record.gd")
const MAX_LEAD_SECONDS: float = 0.4
const MAX_TAIL_SECONDS: float = 0.2

class PopupOwner extends Control:
	var _card_focus_tooltip_stack: Control

static func verify_registry(proof: SceneTree) -> void:
	var rows: Dictionary = {}
	for row: Dictionary in Registry.entries(): rows[row["id"]] = row
	proof._expect(rows.size() == Registry.entries().size() and rows.size() == 30, "Exactly 30 unique active tooltip loops")
	var required: Array = ["marked_burrow_grub", "chain_card"] + Fixture.Tip03.IDS + ["rule_gust", "rule_wildfire", "rule_shadowstep"] + Fixture.Tip05.IDS + Fixture.Tip06.IDS + Fixture.Tip07.IDS + Fixture.Traps.IDS + Fixture.Txt13.IDS + Fixture.Tip13.IDS + Fixture.Tip09.IDS + Fixture.Tip10.IDS
	for id: String in required:
		proof._expect(rows.has(id), "Expected fixture has a registered loop: " + id)
	var speeds: Dictionary = {"burst_ember_tick": "normal", "marked_burrow_grub": "fast", "chain_card": "normal", "discharge_network": "fast"}
	for id: String in speeds:
		proof._expect(rows.has(id) and rows[id].get("speed", "normal") == speeds[id], "Recording speed is preserved for " + id)

static func recording_timing_matches(id: String, timing: Dictionary) -> bool:
	if float(timing.get("first_motion_seconds", INF)) > MAX_LEAD_SECONDS: return false
	var tail: float = float(timing.get("tail_seconds", INF))
	if tail <= MAX_TAIL_SECONDS: return true
	if not Fixture.Tip13.IDS.has(id): return false
	# A short Burst can retain settled frames only up to the two-second loop minimum.
	var min_frames: int = ceili((Fixture.Tip13.MIN_LOOP_SECONDS - LoopView.HOLD_SECONDS - LoopView.CROSSFADE_SECONDS) * Recorder.FPS)
	var motion_frames: int = int(timing.get("last_visible_frame", -1)) - int(timing.get("trim_start_frames", 0)) + 1
	return int(timing.get("recording_frames", 0)) == min_frames and motion_frames > 0 and motion_frames < min_frames and is_equal_approx(tail, float(min_frames - motion_frames) / Recorder.FPS)

static func verify_burst_recording(proof: SceneTree, row: Dictionary, frame_count: int) -> void:
	var path: String = row["asset_path"]
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path + ".json"))
	var id: String = row["id"]
	proof._expect(parsed is Dictionary, "Registered Burst has a recording receipt: " + id)
	if not parsed is Dictionary: return
	var renderer: Dictionary = parsed.get("renderer", {})
	var timing: Dictionary = parsed.get("motion_timing", {})
	proof._expect(parsed.get("id") == id and parsed.get("speed") == row["speed"] and int(timing.get("recording_frames", 0)) == frame_count and parsed.get("asset_sha256") == FileAccess.get_sha256(path), "Registered Burst matches its recording receipt: " + id)
	var viewport_size: Array = renderer.get("viewport", [])
	var exact_size: bool = viewport_size.size() == 2 and viewport_size[0] == Playback.SIZE.x and viewport_size[1] == Playback.SIZE.y
	proof._expect(not bool(parsed.get("requires_native_rerecord", true)) and renderer.get("cel_look") == "all" and exact_size and renderer.get("ui_scale") == 1.0, "Registered Burst has native cel-look proof: " + id)
	var seconds: float = float(frame_count) / Recorder.FPS + LoopView.HOLD_SECONDS + LoopView.CROSSFADE_SECONDS
	proof._expect(recording_timing_matches(id, timing) and seconds >= Fixture.Tip13.MIN_LOOP_SECONDS and seconds <= Fixture.Tip13.MAX_LOOP_SECONDS, "Registered Burst meets its lead, tail and loop duration limits: " + id)

static func verify(proof: SceneTree) -> void:
	var row: Dictionary = Registry.find("stagger", {})
	Registry.proof_media_disabled = true
	var text_only: Control = TooltipPanel.make_text(Icons.tooltip("stagger"))
	var text: String = proof._popup_text(text_only)
	proof._expect(text_only.find_child("TooltipLoopWindow", true, false) == null, "No-media control omits only the loop")
	text_only.free()
	Registry.proof_media_disabled = false
	var enabled: Control = TooltipPanel.make_text(Icons.tooltip("stagger"))
	proof._expect(proof._popup_text(enabled) == text and enabled.find_child("TooltipLoopWindow", true, false) != null, "Same Stagger factory/text/icons used for matched opens")
	enabled.free()
	proof._expect(row["id"] == "stagger", "Counterfactual never changes registry source identity")

static func order(proof: SceneTree) -> void:
	proof.root.size = Playback.SIZE
	proof.root.content_scale_size = Playback.SIZE
	proof.viewport = Playback.canvas(proof)
	proof.viewport.gui_embed_subwindows = true
	proof.viewport.notify_mouse_entered()
	var order_name: String = OS.get_environment("TOOLTIP_LOOP_ORDER")
	proof._expect(Cache.resident_stream_count() == 0, "Fresh process has no streams: " + order_name)
	var reports: Array[Dictionary]
	for row: Dictionary in proof.ordered_entries():
		if not Fixture.Tip03.IDS.has(row["id"]) and row["id"] != Fixture.Tip10.STAGGER: continue
		# Exercise the other actual recording streams and native PopupPanel
		# ownership without inventing headless board draw registrations.
		Registry.proof_media_disabled = false
		var owner := PopupOwner.new()
		proof.viewport.add_child(owner)
		var popup := PopupPanel.new()
		owner.add_child(popup)
		var panel: Control = TooltipPanel.make_icon_lines(Icons.icon_texture(row["term"]), Icons.label(row["term"]), PackedStringArray([Icons.description(row["term"])]), row["term"], row["source_match"])
		popup.add_child(panel)
		popup.popup()
		var window: Control = panel.find_child("TooltipLoopWindow", true, false)
		proof._expect(window != null, "Actual stream opens in native popup: " + str(row["id"]))
		if window != null:
			window.proof_seconds = 0.0
			await proof._wait_frame(window, 0)
		reports.append({"id": row["id"], "close": await OpenProof.close(proof, owner, panel)})
		# Retain the hidden popup to prove closure, not destruction, releases
		# its textures and lease. It is removed after the release audit.
		if window != null: proof._expect(not window._leased and window._texture == null and window._first == null, "Hidden native window relinquishes stream and textures")
		owner.queue_free()
		await proof.process_frame
	var expiry: Dictionary = await OpenProof.expire(proof)
	proof._expect(Cache.shared().streams.is_empty(), "All real streams expire after last release: " + order_name + " " + JSON.stringify(expiry))
	Registry.proof_media_disabled = false
	DirAccess.make_dir_recursive_absolute(proof.output_dir())
	FileAccess.open(proof.output_dir().path_join("headless-lifecycle.json"), FileAccess.WRITE).store_string(JSON.stringify({"order": order_name, "opens": reports, "expiry": expiry}, "\t"))
	print("TIP03 LIFECYCLE ", order_name, ": ", "PASS" if proof.failures.is_empty() else "FAIL", " (%d real streams; native popup closure; monotonic expiry)" % reports.size())
