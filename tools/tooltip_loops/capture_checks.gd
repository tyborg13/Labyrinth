extends RefCounted
## Focused ownership/timing proof; headless results never stand in for GPU budgets.
const Registry = preload("res://scripts/tooltip_loop_registry.gd")
const Cache = preload("res://scripts/tooltip_loop_cache.gd")
const TooltipPanel = preload("res://scripts/ui_tooltip_panel.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const OpenProof = preload("res://tools/tooltip_loops/capture_open.gd")
const Fixture = preload("res://tools/tooltip_loops/fixture.gd")
const Playback = preload("res://tools/tooltip_loops/playback.gd")

class PopupOwner extends Control:
	var _card_focus_tooltip_stack: Control

static func verify(proof: SceneTree) -> void:
	var row: Dictionary = Registry.find("freeze", {})
	Registry.proof_media_disabled = true
	var text_only: Control = TooltipPanel.make_text(Icons.tooltip("freeze"))
	var text: String = proof._popup_text(text_only)
	proof._expect(text_only.find_child("TooltipLoopWindow", true, false) == null, "No-media control omits only the loop")
	text_only.free()
	Registry.proof_media_disabled = false
	var enabled: Control = TooltipPanel.make_text(Icons.tooltip("freeze"))
	proof._expect(proof._popup_text(enabled) == text and enabled.find_child("TooltipLoopWindow", true, false) != null, "Same Freeze factory/text/icons used for matched opens")
	enabled.free()
	proof._expect(row["id"] == "freeze_status", "Counterfactual never changes registry source identity")

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
		if not Fixture.Tip03.IDS.has(row["id"]): continue
		if row["id"] == "freeze_status":
			Registry.proof_media_disabled = true
			var scene: Node = await Playback.instance(proof, proof.viewport, Fixture.build("freeze_status"), false)
			var prepared: Dictionary = await OpenProof.prepare(proof, scene, row)
			var baseline: Dictionary = await OpenProof.measure(proof, scene, prepared["route"], false)
			await OpenProof.close(proof, scene, baseline["panel"])
			proof._expect(not Cache.diagnostics_if_present().has(row["asset_path"]), "Freeze is cold after the no-loop open")
			var enabled: Dictionary = await OpenProof.measure(proof, scene, prepared["route"], true)
			proof._expect(enabled["text"] == baseline["text"] and enabled["icons"] == baseline["icons"] and enabled["owner_path"] == baseline["owner_path"], "Matched real status-plate opens preserve owner, text and icons")
			var report: Dictionary = {"id": row["id"], "context_preparation_loop_disabled": prepared["timings"], "no_loop_max_frame_usec": baseline["max_frame_usec"], "loop_max_frame_usec": enabled["max_frame_usec"], "no_loop_route_usec": baseline["route_usec"], "loop_route_usec": enabled["route_usec"], "headless_only": true}
			report["close"] = await OpenProof.close(proof, scene, enabled["panel"])
			reports.append(report)
			print("TIP03 FREEZE CPU DIAGNOSTIC ", order_name, " ", JSON.stringify(report))
			scene.queue_free()
			await proof.process_frame
		else:
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
