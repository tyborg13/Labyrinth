extends "res://tests/scavenger_shop_probe.gd"
## Drives the production purchase, event choice and milestone actions at 60 fps.

const Burst = preload("res://scripts/acquisition_burst.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const EventFixtures = preload("res://tests/suites/event_view_suite.gd")
const EventRules = preload("res://scripts/event_rules.gd")
const Preview = preload("res://scripts/event_reward_preview.gd")
const DragonFixture = preload("res://tools/dragon_boss_inspection.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Elements = preload("res://scripts/element_data.gd")
const FPS := 60
const READY_FRAMES := 240
const SHOP_ENTRY_FRAMES := 24
const AUDIO_DRAIN_MSEC := 100
const SHOP_FLIGHT_END := 0.73
const SHOP_FLIGHT_START := 0.23
const BURST_LAYER_PATH := "GainBursts"
const GAIN_CASES := {
	"shop_card": ["shop", "grave_mortar", "card"],
	"shop_gear": ["shop", "duelist_rapier", "equipment"],
	"shop_item": ["shop", "jaw_trap", "item"],
	"shop_sale": ["shop", "smoke_bomb", "sale"],
	"event_card": ["event", "whispering_well", "ember", "card"],
	"event_relic": ["event", "bloodletters_basin", "bleed", "relic"],
	"event_gear": ["event", "hanged_knight", "boots", "equipment"],
	"event_item": ["event", "fallen_lantern_bearer", "satchel", "item"],
	"event_blessing": ["event", "shrine_last_door", "candle", "omen"],
	"event_defiance": ["event", "shrine_last_door", "kneel", "defiance"],
	"event_transform": ["event", "mirror_of_skins", "hand", "transform_magic"],
	"event_reforge": ["event", "abandoned_forge", "weapon", "reforge"],
	"event_bane": ["event", "whispering_well", "drink", "omen"],
	"event_embers": ["event", "lost_cartographer", "embers", "embers"],
	"event_health": ["event", "moth_library", "burn", "heal"],
	"event_map": ["event", "lost_cartographer", "survey", "reveal"],
	"event_loss": ["event", "starving_pilgrim", "item", "lose_item"],
	"dragon": ["dragon", "noctyrax", 24],
	"dragon_section": ["dragon", "vyraketh", 4],
}

var take_scene: Control
var take_viewport: SubViewport
var take_screen: Control
var take_action: Button
var take_shop_source: Control
var take_spec: Array
var take_case: String
var take_reduced: bool
var take_expected: Array[Dictionary]
var take_prepared: Dictionary
var take_trace: Dictionary
var take_origin_frame: int
var take_art := Rect2()
var take_destination := Vector2.ZERO
var _seen_effects: Dictionary
var _effect_ids: Array[int]
var _seen_stamps: Dictionary
var _stamps: Array[WeakRef]
var _shop_currency: Control

func _option(key: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find(key)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else ""

func _open_gain(directory: String, case_id: String, reduced: bool) -> bool:
	if DirAccess.make_dir_recursive_absolute(directory) != OK or not GAIN_CASES.has(case_id): return false
	ProgressionStore.set_storage_path(directory.path_join("progression.json"))
	ProgressionStore.set_run_storage_path(directory.path_join("run.save"))
	ProbeSettings.set_storage_path(directory.path_join("settings.json"))
	Analytics.set_storage_dir(directory.path_join("analytics"))
	var settings: Dictionary = ProbeSettings.default_settings()
	settings["display_mode"] = ProbeSettings.DISPLAY_WINDOWED
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = reduced
	settings["mute_in_background"] = false
	if not ProbeSettings.save_settings(settings): return false
	ProbeSettings.apply_settings(settings, root, false)
	root.get_node("InputRouter").call("set_forced_state_for_test", "pointer", "xbox")
	take_case = case_id
	take_spec = GAIN_CASES[case_id]
	take_reduced = reduced
	take_expected.clear()
	take_art = Rect2()
	take_destination = Vector2.ZERO
	_seen_effects.clear()
	_effect_ids.clear()
	_seen_stamps.clear()
	_stamps.clear()
	var state: Dictionary = _gain_state()
	if state.is_empty(): return false
	if not ProgressionStore.save_data(state["progression"]) or not ProgressionStore.save_run_state(state): return false
	take_viewport = SubViewport.new()
	take_viewport.size = VIEWPORT_SIZE
	take_viewport.msaa_2d = root.msaa_2d
	take_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if DisplayServer.get_name() == "headless" else SubViewport.UPDATE_ALWAYS
	root.add_child(take_viewport)
	root.set_meta("labyrinth_resume_saved_run", true)
	take_scene = load("res://scenes/run_scene.tscn").instantiate()
	take_viewport.add_child(take_scene)
	for tick: int in READY_FRAMES:
		if take_scene.initial_presentation_is_ready(): break
		await process_frame
	if not take_scene.initial_presentation_is_ready(): return false
	if take_scene._dialogue_active: take_scene._close_dialogue()
	match take_spec[0]:
		"shop":
			take_screen = take_scene._scavenger_shop_view
			if not take_screen.visible: return false
			var selling: bool = take_spec[2] == "sale"
			if selling: take_screen._set_pack_mode(true)
			take_shop_source = _offer_source(take_screen, take_spec[1], selling)
			if not is_instance_valid(take_shop_source): return false
			take_shop_source.pressed.emit()
			take_action = take_screen._detail_action
			_shop_currency = take_screen._currency_panel
			for tick: int in SHOP_ENTRY_FRAMES: await process_frame
			var id: String = take_spec[1]
			take_expected.append({"kind": take_spec[2], "id": id})
		"event":
			take_screen = take_scene._event_view
			if not is_instance_valid(take_screen) or not take_screen.visible: return false
			for tick: int in READY_FRAMES:
				if not take_screen.hover_preview.preparation_snapshot().active: break
				await process_frame
			take_screen.finish_animation_for_test()
			var live_state: Dictionary = take_scene._run_state
			take_expected.assign(EventRules.preview_choice(live_state, take_spec[2]))
			if not take_expected.any(func(outcome: Dictionary) -> bool: return outcome["type"] == take_spec[3]): return false
		"dragon":
			take_screen = take_scene._relic_choice_host
			take_action = take_scene.find_child("DragonRewardContinue", true, false) as Button
			take_expected.append({"kind": "relic", "id": take_scene._run_state.get("pending_reward", {}).get("relic_id", "")})
			if take_action == null or not take_action.is_visible_in_tree(): return false
	await process_frame
	await process_frame
	var layer: Node2D = _gain_layer()
	take_prepared = layer._textures.duplicate() if layer != null else {}
	return take_viewport.size == VIEWPORT_SIZE and is_equal_approx(root.content_scale_factor, 1.0)

func _gain_state() -> Dictionary:
	var engine := RunEngine.new()
	var state: Dictionary
	var profile: Dictionary = Tutorial.complete_tutorial(ProgressionStore.default_data())
	match take_spec[0]:
		"shop":
			state = _scavenger_state(engine)
			state["progression"] = Tutorial.complete_tutorial(state["progression"])
		"event":
			var template: Dictionary = engine.create_new_run(EventFixtures.FIXTURE_SEED, profile)
			state = EventFixtures.fixture(take_spec[1], true, template)
		"dragon":
			var options := {"dragon_id": take_spec[1], "dragon_depth": take_spec[2], "dragon_case": "reward"}
			state = DragonFixture.build(engine, Combat.new(), engine.create_new_run(DragonFixture.seed_for_options(options), profile), options)
			if not engine.is_dragon_reward(state): return {}
			state["pending_reward"]["intro_pending"] = false
	return state

func _close_gain() -> void:
	if is_instance_valid(take_viewport): take_viewport.queue_free()
	await process_frame
	take_scene = null
	take_screen = null
	take_action = null
	take_shop_source = null
	_shop_currency = null

func _activate_gain() -> void:
	take_origin_frame = Engine.get_process_frames()
	take_trace = {"effects": [], "bursts": [], "timing": {}}
	match take_spec[0]:
		"shop":
			var local: Rect2 = take_screen.purchase_origin(take_spec[1], take_shop_source)
			take_art = take_screen._canvas.get_global_transform() * local
			take_action.pressed.emit()
		"event":
			take_scene._on_section_map_event(take_spec[2])
		"dragon":
			var artwork: TextureRect = take_scene.find_child("DragonRewardArtwork", true, false)
			take_art = artwork.get_global_rect()
			var texture_size: Vector2 = artwork.texture.get_size()
			texture_size *= minf(take_art.size.x / texture_size.x, take_art.size.y / texture_size.y)
			take_art = Rect2(take_art.get_center() - texture_size * 0.5, texture_size)
			take_action.pressed.emit()

func _sample_gain() -> void:
	var frame: int = Engine.get_process_frames() - take_origin_frame
	var timing: Dictionary = take_trace.timing
	match take_spec[0]:
		"shop":
			for effect: Control in take_screen._purchase_effects.get_children():
				var receipt: Dictionary = _observe_effect(effect, frame)
				take_destination = effect.get_global_transform() * effect.destination
				_mark(receipt, "flight_end", frame, not take_reduced and effect._elapsed >= SHOP_FLIGHT_END)
			_mark(timing, "currency_flash", frame, _shop_currency.modulate != Color.WHITE)
			_mark(timing, "currency_restored", frame, timing.has("currency_flash") and _shop_currency.modulate == Color.WHITE)
		"event":
			var beats: Control = take_screen.result_beats
			if is_instance_valid(beats):
				_mark(timing, "beats", frame, true)
				for effect: Node in beats.get_children():
					if not effect.has_signal("arrived"): continue
					var receipt: Dictionary = _observe_effect(effect, frame)
					take_destination = effect.get_global_transform() * effect.destination
				_mark(timing, "ember_pulse", frame, beats._ember_pulse != null)
				_mark(timing, "ember_roll_done", frame, timing.has("ember_pulse") and beats._ember_started < 0)
				_mark(timing, "map_pulse", frame, take_case == "event_map" and not beats._pulses.is_empty())
			_mark(timing, "beats_end", frame, timing.has("beats") and not is_instance_valid(beats))
		"dragon":
			var beam: Control = take_scene._card_fx_layer.get_node_or_null("RelicAcquisitionBeam")
			if is_instance_valid(beam):
				take_destination = beam.get_global_transform() * beam.target
			_mark(timing, "beam", frame, is_instance_valid(beam))
			_mark(timing, "beam_end", frame, timing.has("beam") and not is_instance_valid(beam))
			_mark(timing, "transition", frame, is_instance_valid(take_scene._section_transition))
			_mark(timing, "settlement", frame, take_scene._relic_delivery_phase == "settlement")
			_mark(timing, "hud_pulse", frame, take_scene._relic_delivery_phase == "settle")
			_mark(timing, "complete", frame, not take_scene._relic_claim_in_progress and not is_instance_valid(take_scene._section_transition))
	for effect_id: int in _effect_ids:
		var entry: Dictionary = _seen_effects[effect_id]
		_mark(entry, "end", frame, not is_instance_id_valid(effect_id))
	_sample_stamps(frame)

func _observe_effect(effect: Control, frame: int) -> Dictionary:
	var instance: int = effect.get_instance_id()
	if _seen_effects.has(instance): return _seen_effects[instance]
	var art: Rect2 = take_art
	var entry: Dictionary = {"start": frame}
	if effect.has_signal("arrived"):
		var display: Control = effect.replacement if effect.replacement != null else effect.content
		art = display.get_meta("reward_art_rect", Rect2(Vector2.ZERO, display.size))
		art.position += effect.origin.position + display.position
		art = effect.get_global_transform() * art
		take_art = art
		entry["kind"] = effect.kind
		entry["tone"] = effect.tone
		effect.arrived.connect(_event_arrived.bind(entry, effect.get_parent(), effect), CONNECT_ONE_SHOT)
	else:
		entry["kind"] = take_spec[2]
	entry["centre"] = _point(art.get_center())
	entry["art_size"] = _point(art.size)
	_seen_effects[instance] = entry
	_effect_ids.append(instance)
	take_trace.effects.append(entry)
	return entry

func _event_arrived(receipt: Dictionary, beats: Control, effect: Control) -> void:
	var frame: int = Engine.get_process_frames() - take_origin_frame
	receipt["arrived"] = frame
	take_destination = effect.get_global_transform() * effect.destination
	var kind: String = effect.kind
	var destination: String = kind
	if kind in ["card", "transform_magic"]: destination = "deck"
	elif kind in ["item", "equipment", "reforge"]: destination = "loadout"
	elif kind == "omen": destination = "omen:" + str(effect.content.get_meta("preview_line")["ids"][0])
	var target: Control = beats.destinations.get(destination, {}).get("control")
	if is_instance_valid(target) and beats._pulses.has(target): receipt["pulse"] = frame

func _gain_layer() -> Node2D:
	return take_scene._acquisition_bursts.get_node_or_null(BURST_LAYER_PATH) as Node2D

func _active_stamps() -> Array[Node]:
	var result: Array[Node]
	var layer: Node2D = _gain_layer()
	if layer == null: return result
	for stamp: Node in layer.get_children():
		if stamp is Burst.Stamp and stamp._frame_count > 0 and not stamp.is_queued_for_deletion():
			result.append(stamp)
	return result

func _sample_stamps(frame: int) -> void:
	for stamp: Node in _active_stamps():
		var index: int = stamp.get_instance_id()
		if not _seen_stamps.has(index):
			var fit: Vector2i = stamp.fit
			var info: Dictionary = Burst.metadata().sizes[fit.y]
			var palette: PackedColorArray = stamp.material.get_shader_parameter("palette")
			var proxy: Control = _gain_proxy()
			var base_z: int = _effective_z(proxy)
			var entry := {
				"start": frame, "frame": stamp.frame, "centre": _point(stamp.global_position),
				"accent": "#" + palette[3].to_html(false), "sheet": info.atlas.get_file(),
				"cell_px": fit.x, "proxy_z": base_z, "z": stamp.z_index,
				"relative_z": stamp.z_index - base_z, "radius": stamp.card_radius,
				"prepared": take_prepared.get(fit.y) == stamp.material.get_shader_parameter("atlas"),
			}
			_seen_stamps[index] = entry
			_stamps.append(weakref(stamp))
			take_trace.bursts.append(entry)
		var trace: Dictionary = _seen_stamps[index]
		if stamp.visible:
			trace["last_visible"] = frame
			trace["last_visible_frame"] = stamp.frame
			trace["last_visible_centre"] = _point(stamp.global_position)
		if take_spec[0] == "shop" and not take_reduced:
			var proxy: Control = _gain_proxy()
			var trade: Control = proxy.get_parent()
			var pivot: Vector2 = trade.get_global_transform() * (proxy.position + proxy.pivot_offset)
			if trade._elapsed < SHOP_FLIGHT_START and frame > int(trace.start):
				trace["follows_lift"] = bool(trace.get("follows_lift", true)) and stamp.global_position.is_equal_approx(pivot)
				trace["last_lift_centre"] = _point(stamp.global_position)
	for index: int in _stamps.size():
		_mark(take_trace.bursts[index], "end", frame, _stamps[index].get_ref() == null)

func _gain_proxy() -> Control:
	if take_spec[0] == "dragon": return take_scene.find_child("DragonRewardArtwork", true, false) as Control
	if _effect_ids.is_empty(): return null
	var effect: Control = instance_from_id(_effect_ids.back()) as Control
	return effect.proxy if is_instance_valid(effect) else null

func _effective_z(proxy: CanvasItem) -> int:
	var z: int
	while is_instance_valid(proxy):
		z += proxy.z_index
		if not proxy.z_as_relative: break
		proxy = proxy.get_parent() as CanvasItem
	return z

func _mark(trace: Dictionary, key: String, frame: int, condition: bool) -> void:
	if condition and not trace.has(key): trace[key] = frame

func _point(value: Vector2) -> Array:
	return [snappedf(value.x, 0.001), snappedf(value.y, 0.001)]

func _draw_counts() -> Dictionary:
	var calls := RegEx.create_from_string("\\bdraw_\\w+\\s*\\(")
	var counts: Dictionary
	for name: String in ["merchant_acquisition_effect", "event_gain_effect", "scavenger_trade_effect"]:
		var source: String = FileAccess.get_file_as_string("res://scripts/" + name + ".gd")
		counts[name] = calls.search_all(source).size()
	var beats: String = FileAccess.get_file_as_string("res://scripts/event_result_beats.gd")
	var sparks: int = beats.find("class EmberSparks")
	counts["EmberSparks"] = calls.search_all(beats.substr(sparks)).size() if sparks >= 0 else 0
	return counts
