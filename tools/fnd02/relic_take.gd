extends "res://tools/inspection_fixture.gd"
## Shared production reward fixture for the headless verifier and native capture.

const Settings = preload("res://scripts/settings_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Burst = preload("res://scripts/acquisition_burst.gd")
const SEED := 131011
const VENOM := "venom_signet"
const STORM := "storm_crown"
const CURATOR := "curators_patience"
const GUARDIAN := "ashen_reaver"
const SIZE := Vector2i(1920, 1080)
const FPS := 60
const FRAME_LIMIT := 240

var _viewport: SubViewport
var _scene: Control
var _relic_id: String
var _offer: Control
var _icon_rect: Rect2
var _icon_z: int
var _origin: int
var _trace: Dictionary

func _arg(key: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find(key)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else ""

func _open_take(directory: String, relic_id: String, size: Vector2i = SIZE, reduced: bool = false, curator: bool = false, guardian: bool = false) -> bool:
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return false
	ProgressionStore.set_storage_path(directory.path_join("progression.json"))
	ProgressionStore.set_run_storage_path(directory.path_join("run.save"))
	Settings.set_storage_path(directory.path_join("settings.json"))
	Analytics.set_storage_dir(directory.path_join("analytics"))
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = reduced
	settings["mute_in_background"] = false
	if not Settings.save_settings(settings): return false
	Settings.apply_settings(settings, root, false)
	root.get_node("InputRouter").call("set_forced_state_for_test", "pointer", "xbox")
	_options = {"scenario": "treasure", "seed": SEED, "relic_choices": relic_id}
	var profile: Dictionary = Tutorial.complete_tutorial(_build_progression())
	if curator:
		_options["relic_choices"] = "%s,%s" % [relic_id, STORM]
		profile["level"] = GameData.max_progression_level()
		var requested: Array[String] = [CURATOR]
		profile["skill_ids"] = SkillTreeLibrary.repaired_selection([], int(profile["level"]), requested)
	if guardian:
		_options.merge({"scenario": "guardian", "guardian_id": GUARDIAN, "guardian_case": "reward"}, true)
	var run: Dictionary = _build_run_state(str(_options["scenario"]), profile)
	_relic_id = str(run.get("guardian_reward", {}).get("relic_id", relic_id))
	if not (_relic_id in run.get("pending_relics", [])): return false
	if not ProgressionStore.save_data(profile) or not ProgressionStore.save_run_state(run): return false
	_viewport = SubViewport.new()
	_viewport.size = size
	_viewport.msaa_2d = root.msaa_2d
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if DisplayServer.get_name() == "headless" else SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	root.set_meta("labyrinth_resume_saved_run", true)
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(_scene)
	for tick: int in FRAME_LIMIT:
		await process_frame
		_offer = _scene.find_child("RelicChoice_" + _relic_id, true, false) as Control
		if not is_instance_valid(_offer) or not _offer.is_visible_in_tree(): continue
		var icon: Control = _offer.find_child("RelicChoiceIcon", true, false) as Control
		if icon == null or icon.get_global_rect().size.x <= 0.0: continue
		return _viewport.size == size and is_equal_approx(root.content_scale_factor, 1.0)
	return false

func _close_take() -> void:
	if is_instance_valid(_viewport):
		_viewport.queue_free()
		await process_frame

func _activate_offer() -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	_offer.gui_input.emit(press)

func _begin_claim(curator_choice: Button = null) -> void:
	var icon: Control = _offer.find_child("RelicChoiceIcon", true, false) as Control
	_icon_rect = icon.get_global_rect()
	_icon_z = icon.z_index
	var parent: CanvasItem = icon
	while parent.z_as_relative and parent.get_parent() is CanvasItem:
		parent = parent.get_parent() as CanvasItem
		_icon_z += parent.z_index
	_origin = Engine.get_process_frames()
	_trace = {"relic": _relic_id}
	if curator_choice == null:
		_activate_offer()
	else:
		curator_choice.pressed.emit()
	_sample_claim()

func _sample_claim() -> void:
	var frame: int = Engine.get_process_frames() - _origin
	var burst: Node = _burst()
	var beam: Control = _delivery_beam()
	var phase: String = _scene._relic_delivery_phase
	var hud: Control = _scene._relic_frame_for_id(_relic_id)
	_mark("offer_dismissed", frame, not is_instance_valid(_offer) or not _offer.is_visible_in_tree())
	_mark("beam", frame, beam != null)
	_mark("beam_visible", frame, beam != null and beam.is_visible_in_tree())
	_mark("beam_end", frame, _trace.has("beam") and beam == null)
	var motes: bool = _delivery_motes_active()
	_mark("motes", frame, motes)
	_mark("motes_end", frame, _trace.has("motes") and not motes)
	_mark("settlement", frame, phase == "settlement")
	_mark("hud_bounce", frame, hud != null and hud.modulate != Color.WHITE)
	_mark("settle", frame, phase == "settle")
	_mark("complete", frame, not _scene._relic_claim_in_progress)
	_mark("map", frame, _scene._large_map_scrim.visible)
	_mark("burst", frame, burst != null)
	_mark("burst_end", frame, _trace.has("burst") and burst == null)

func _mark(key: String, frame: int, condition: bool) -> void:
	if condition and not _trace.has(key): _trace[key] = frame

func _delivery_beam() -> Control:
	var beam: Control = _scene._card_fx_layer.get_node_or_null("RelicAcquisitionBeam") as Control
	return beam if is_instance_valid(beam) and not beam.is_queued_for_deletion() else null

func _delivery_motes_active() -> bool:
	# The card FX layer contains only the beam and motes during these takes.
	# Later motes receive automatic names, so track them by their node type.
	for child: Control in _scene._card_fx_layer.get_children():
		if child is TextureRect and child.name != "RelicAcquisitionBeam" and not child.is_queued_for_deletion() and child.is_visible_in_tree():
			return true
	return false

func _burst() -> Node:
	for child: Node in _scene._acquisition_bursts.get_children():
		if child is Burst.Stamp and child._frame_count > 0 and not child.is_queued_for_deletion():
			return child
	return null
