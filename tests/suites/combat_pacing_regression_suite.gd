extends RefCounted

const Pacing = preload("res://scripts/combat_pacing.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Motion = preload("res://tests/suites/combat_motion_timing_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const VICTORY_ENEMY_HP: int = 1
const VICTORY_ENEMY_TILE: Vector2i = Vector2i(3, 4)
const ENEMY_PHASE_DAMAGE: int = 1
const ENEMY_PHASE_FIRST_TIME: int = 1
const LAST_ACTION_INTENT_TIME: int = 20
const RESOLUTION_TIMEOUT_MS: int = 10000
const CLEANUP_FRAMES: int = 20
const WAIT_TOLERANCE_SECONDS: float = 0.08
const MOVE_ONLY_MAX_SECONDS: float = 0.05
const FEEDBACK_INITIAL_ELAPSED: float = 0.20

class FeedbackScene:
	extends "res://scripts/run_scene.gd"
	var final_feedback_frame: int = -1
	func _render_board_state(state: Dictionary, presentation: Dictionary, stable: bool = false) -> void:
		super._render_board_state(state, presentation, stable)
		if _combat_pacing.enemies_active:
			for unit: Dictionary in board_view.presentation.get("death_animation_units", []):
				final_feedback_frame = maxi(final_feedback_frame, int(unit.get("death_frame", -1)))

class RemovalOwner:
	extends Node
	var _settings: Dictionary = Settings.default_settings()
	var _run_state: Dictionary = {"mode": "combat"}
	var _animation_lock: bool = true
	var _drag_card_index: int = -1
	var detached_refreshes: int = 0
	var caption: String = ""
	func _controller_modal_visible() -> bool: return false
	func _set_action_banner(text: String) -> void: caption = text
	func _refresh_stage_view() -> void:
		if not is_inside_tree(): detached_refreshes += 1

static func run(tree: SceneTree, expect: Callable) -> void:
	_test_feedback_duration(expect)
	await _action_waits(tree, expect)
	await _victory_board(tree, expect, false)
	await _victory_board(tree, expect, true)
	for death: bool in [true, false]: await _last_action_overlays(tree, expect, death)
	await _removed_owner(tree, expect)
	print("COMBAT PACING REGRESSION SUITE: complete")

static func _test_feedback_duration(expect: Callable, pacing_script: Script = Pacing) -> void:
	var pacing: Node = pacing_script.new()
	var texts: Array = [{"tile":Vector2i.ZERO,"text":"-1"},{"tile":Vector2i.ZERO,"text":"-2"}]
	var authored: float = preload("res://scripts/floating_combat_text.gd").total_duration(texts)
	for enemy_phase: bool in [false,true]:
		pacing.enemies_active = enemy_phase
		for elapsed: float in [0.0,FEEDBACK_INITIAL_ELAPSED,authored]:
			expect.call(is_equal_approx(pacing.feedback_duration(texts,authored,elapsed),authored),"Full authored feedback includes popup stagger (enemies=%s elapsed=%s)" % [enemy_phase,elapsed])
	expect.call(is_equal_approx(Pacing.ENEMY_TILE_SECONDS,0.20),"Enemy movement retains 0.20 s per tile")
	for kind: String in ["melee","ranged","aoe","push","pull","lightning_strikes"]:
		expect.call(Pacing.activation_has_action("actor",[{"actor_key":"actor","kind":kind}]),"Action pacing covers %s" % kind)
	expect.call(not Pacing.activation_has_action("actor",[{"actor_key":"actor","kind":"move"},{"actor_key":"other","kind":"melee"}]),"Move-only classification uses this actor's resolved actions")
	pacing.free()

static func _action_waits(tree: SceneTree, expect: Callable, pacing_script: Script = Pacing) -> void:
	for speed: String in ["normal","fast","fastest"]:
		for reduced: bool in [false,true]:
			var owner := RemovalOwner.new()
			owner._settings["combat_speed"] = speed
			owner._settings["reduced_motion"] = reduced
			tree.root.add_child(owner)
			await tree.process_frame
			var pacing: Node = pacing_script.new()
			pacing.install(owner)
			pacing.begin_enemies()
			var scale: float = Settings.combat_speed_scale(owner._settings)
			var intent: Dictionary = {"kind":"intent","actor_key":"first","actor_name":"Fixture","intent_name":"Fixture intent"}
			var action: Dictionary = {"kind":"melee","actor_key":"first"}
			var began: int = Time.get_ticks_usec()
			var done: Dictionary = {"done":false}
			_observe_lead(pacing,intent,[intent,action],done)
			expect.call(owner.caption == "Fixture: Fixture intent" and not done["done"],"Caption is already showing during the first lead")
			while not done["done"]: await tree.process_frame
			_expect_real_wait(began,0.35/scale,expect,"First enemy shares the 0.35 s banner lead at %s reduced=%s" % [speed,reduced])
			await pacing.before_step(action)
			# Retained feedback can outlive the action view. It must finish before
			# settle, even when hit-stop/reduced motion changes real elapsed time.
			var popup_start: int = pacing.presentation_usec()
			pacing.get("_popups")["fixture"] = {"start":popup_start}
			began = Time.get_ticks_usec()
			await pacing.after_step(action)
			_expect_real_wait(began,(preload("res://scripts/floating_combat_text.gd").ANIMATION_DURATION_SECONDS+0.15)/scale,expect,"Retained feedback then settle scale at %s reduced=%s" % [speed,reduced])
			pacing.get("_popups").clear()
			intent["actor_key"] = "next"
			action["actor_key"] = "next"
			began = Time.get_ticks_usec()
			await pacing.before_step(intent,[intent,action])
			_expect_real_wait(began,0.25/scale,expect,"Subsequent actor has a 0.25 s lead at %s reduced=%s" % [speed,reduced])
			intent["actor_key"] = "walker"
			began = Time.get_ticks_usec()
			await pacing.before_step(intent,[intent,{"kind":"move","actor_key":"walker"}])
			await pacing.after_step({"kind":"move","actor_key":"walker"})
			expect.call(float(Time.get_ticks_usec()-began)/1000000.0 < MOVE_ONLY_MAX_SECONDS,"Move-only turn adds no lead or settle at %s reduced=%s" % [speed,reduced])
			pacing.end_scope()
			pacing.begin_enemies()
			began = Time.get_ticks_usec()
			await pacing.before_step(intent,[intent,{"kind":"move","actor_key":"walker"}])
			await pacing.after_step({"kind":"move","actor_key":"walker"})
			expect.call(float(Time.get_ticks_usec()-began)/1000000.0 < MOVE_ONLY_MAX_SECONDS,"Even the first move-only turn adds no lead or settle")
			intent["actor_key"] = "next"
			began = Time.get_ticks_usec()
			await pacing.before_step(intent,[intent,action])
			_expect_real_wait(began,0.25/scale,expect,"Actor after an opening move-only turn uses the ordinary 0.25 s lead")
			pacing.end_scope()
			expect.call(is_equal_approx(Engine.time_scale,1.0),"Action waits restore the original clock")
			owner.queue_free()
			await tree.process_frame
	print("COMBAT PACING ACTION WAITS: full feedback/stagger/lead/settle/move-only/three speeds/reduced motion checked")

static func _observe_lead(pacing: Node, intent: Dictionary, steps: Array, done: Dictionary) -> void:
	await pacing.before_step(intent,steps)
	done["done"] = true

static func _expect_real_wait(start: int, seconds: float, expect: Callable, message: String) -> void:
	var elapsed: float = float(Time.get_ticks_usec()-start)/1000000.0
	expect.call(elapsed >= seconds and elapsed <= seconds+WAIT_TOLERANCE_SECONDS,message+" (%.3f s)" % elapsed)

static func _victory_board(tree: SceneTree, expect: Callable, enemy_phase: bool) -> void:
	# Use the actual scene and actual victory coroutine, including the overlay.
	var scene: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	Motion._install_fixture(scene, false)
	var state: Dictionary = scene.get("_combat_state")
	state["deck"]["hand"] = ["quick_stab"]
	state["enemies"][0]["pos"] = VICTORY_ENEMY_TILE
	state["enemies"][0]["hp"] = VICTORY_ENEMY_HP
	scene.get("_settings")["combat_speed"] = "fastest"
	var expected_player_hp: int = int(state["player"]["hp"])
	if enemy_phase:
		state["enemies"][0]["intent"] = {"id": "fixture_self_damage", "name": "Fixture", "time": ENEMY_PHASE_FIRST_TIME, "actions": [{"type": "melee", "range": 1, "damage": ENEMY_PHASE_DAMAGE, "self_damage": VICTORY_ENEMY_HP}]}
		state["turn_queue"] = [Combat.new()._enemy_actor_entry(state, state["enemies"][0], ENEMY_PHASE_FIRST_TIME, 1)]
		expected_player_hp -= ENEMY_PHASE_DAMAGE
	scene.get("_run_state")["combat_state"] = state
	scene.call("_refresh_ui")
	var boundary: Callable = func() -> void: RenderingServer.frame_post_draw.emit()
	if DisplayServer.get_name() == "headless": tree.process_frame.connect(boundary)
	if enemy_phase: scene.call("_on_pass_turn_pressed")
	else:
		scene.call("_on_card_pressed", 0)
		scene.call("_on_board_tile_clicked", VICTORY_ENEMY_TILE)
	var pacing: Node = scene.get("_combat_pacing")
	var overlay: Control = scene.get("_post_combat_victory_overlay")
	var board: Control = scene.get("board_view")
	var samples: int = 0
	var stale_samples: int = 0
	var speed_samples: int = 0
	var lost_scope_samples: int = 0
	var deadline: int = Time.get_ticks_msec() + RESOLUTION_TIMEOUT_MS
	while bool(scene.get("_animation_lock")) and Time.get_ticks_msec() < deadline:
		await tree.process_frame
		if overlay.visible:
			samples += 1
			if not enemy_phase and str(pacing.get("_scope")) != "card": lost_scope_samples += 1
			var shown: Dictionary = board.get("combat_state")
			var post_kill: bool = int(shown.get("player", {}).get("hp", -1)) == expected_player_hp
			for enemy: Dictionary in shown.get("enemies", []): post_kill = post_kill and int(enemy.get("hp", 0)) <= 0
			if not post_kill: stale_samples += 1
			if not is_equal_approx(Engine.time_scale, 1.0): speed_samples += 1
	if tree.process_frame.is_connected(boundary): tree.process_frame.disconnect(boundary)
	var kind: String = "enemy phase" if enemy_phase else "card kill"
	expect.call(not bool(scene.get("_animation_lock")) and samples > 0, "Real %s reaches and completes the victory beat" % kind)
	expect.call(samples > 0 and stale_samples == 0, "Every real %s victory frame retains the post-kill board" % kind)
	expect.call(samples > 0 and speed_samples == 0, "Every real %s victory frame runs at scale 1.0" % kind)
	if not enemy_phase: expect.call(lost_scope_samples == 0, "Scale-only victory restore preserves card scope bookkeeping")
	print("COMBAT PACING VICTORY %s: samples=%d stale=%d sped_up=%d lost_scope=%d" % [kind, samples, stale_samples, speed_samples, lost_scope_samples])
	scene.queue_free()
	for frame: int in range(CLEANUP_FRAMES): await tree.process_frame

static func _last_action_overlays(tree: SceneTree, expect: Callable, death: bool) -> void:
	var scene: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	# Replace only the observer script before installation; release its old node.
	scene.get("_combat_pacing").free()
	scene.set_script(FeedbackScene)
	tree.root.add_child(scene)
	await tree.process_frame
	Motion._install_fixture(scene, false)
	var state: Dictionary = scene.get("_combat_state")
	var actor: Dictionary = state["enemies"][0]
	actor["pos"] = VICTORY_ENEMY_TILE
	if death: actor["hp"] = VICTORY_ENEMY_HP
	actor["bleed"] = VICTORY_ENEMY_HP if death else 0
	actor["intent"] = {"id": "fixture_bleed_on_action", "name": "Fixture", "time": LAST_ACTION_INTENT_TIME, "actions": [{"type": "melee", "range": 1, "damage": ENEMY_PHASE_DAMAGE}]}
	state["turn_queue"] = [Combat.new()._enemy_actor_entry(state, actor, ENEMY_PHASE_FIRST_TIME, 1)]
	scene.get("_settings")["combat_speed"] = "fastest"
	scene.get("_run_state")["combat_state"] = state
	scene.call("_refresh_ui")
	# Fixture-only: an independent rail tween must not mask feedback cleanup.
	scene.set("_turn_order_bar", null)
	var boundary: Callable = func() -> void: RenderingServer.frame_post_draw.emit()
	if DisplayServer.get_name() == "headless": tree.process_frame.connect(boundary)
	scene.call("_on_pass_turn_pressed")
	var pacing: Node = scene.get("_combat_pacing")
	var board: Control = scene.get("board_view")
	var death_end: int = 0
	var popup_end: int = 0
	var final_frame: int = -1
	var observed_frame: int = -1
	var scope_end: int = -1
	var seen_scope: bool = false
	var deadline: int = Time.get_ticks_msec() + RESOLUTION_TIMEOUT_MS
	while bool(scene.get("_animation_lock")) and Time.get_ticks_msec() < deadline:
		await tree.process_frame
		if str(pacing.get("_scope")) == "enemies":
			seen_scope = true
			for entry: Dictionary in pacing.get("_deaths"):
				death_end = maxi(death_end, int(entry["start"]) + int(entry["duration"]))
				for unit: Dictionary in entry["units"]: final_frame = maxi(final_frame, int(scene.call("_enemy_death_frame_count_for_unit", unit)) - 1)
			for popup: Dictionary in pacing.get("_popups").values():
				popup_end = maxi(popup_end, int(popup["start"]) + int(preload("res://scripts/floating_combat_text.gd").ANIMATION_DURATION_SECONDS * 1000000.0))
			for unit: Dictionary in board.get("presentation").get("death_animation_units", []): observed_frame = maxi(observed_frame, int(unit.get("death_frame", -1)))
		elif seen_scope and scope_end < 0: scope_end = int(pacing.presentation_usec())
	observed_frame = maxi(observed_frame, int(scene.get("final_feedback_frame")))
	if tree.process_frame.is_connected(boundary): tree.process_frame.disconnect(boundary)
	expect.call(not bool(scene.get("_animation_lock")) and scene.get("_run_state").get("mode") == ("reward" if death else "combat"), "Last real enemy action completes its ordinary flow")
	if death:
		expect.call(death_end > 0 and scope_end >= death_end, "Last enemy action's retained dissolve completes before enemy scope ends")
		expect.call(final_frame >= 0 and observed_frame >= final_frame, "Last enemy dissolve reaches its authored final frame")
	else:
		expect.call(popup_end > 0 and scope_end >= popup_end, "Last damage numbers keep their complete bounded lifetime")
	print("COMBAT PACING LAST ACTION %s: death_end=%d popup_end=%d scope_end=%d final_frame=%d/%d" % ["dissolve" if death else "damage numbers", death_end, popup_end, scope_end, observed_frame, final_frame])
	scene.queue_free()
	for frame: int in range(CLEANUP_FRAMES): await tree.process_frame

static func _removed_owner(tree: SceneTree, expect: Callable) -> void:
	for end_before_removal: bool in [false, true]:
		var owner := RemovalOwner.new()
		tree.root.add_child(owner)
		var pacing: Node = Pacing.new()
		pacing.install(owner)
		pacing.begin_card()
		owner._animation_lock = false
		if end_before_removal: pacing.end_scope()
		tree.root.remove_child(owner)
		await tree.process_frame
		expect.call(owner.detached_refreshes == 0, "Pacing cannot defer a stage refresh onto a removed owner (already ended=%s)" % end_before_removal)
		expect.call(is_equal_approx(Engine.time_scale, 1.0), "Removal still restores the owned time scale")
		owner.free()
