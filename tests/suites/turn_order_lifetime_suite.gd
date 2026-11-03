extends RefCounted

const PortraitPaths = preload("res://scripts/turn_order_portraits.gd")
const Slots = preload("res://scripts/turn_order_slots.gd")
const Strip = preload("res://scripts/turn_order_landing_strip.gd")
const STILL_FRAME_COUNT := 30
const REGRESSION_ENEMIES: Array = ["ember_tick", "ashen_reaver", "last_lamplighter", "storm_cantor", "arc_thrall", "frostglass_lancer"]
## Rebuilds can retire nodes while a rail animation is suspended on a frame.
const COMPLETION_TIMEOUT_MSEC: int = 2000
const PORTRAIT_FIXTURE_SIZE := Vector2(64, 64)
const QUEUE_FIXTURE_TIME_STEP: int = 1

static func run(tree: SceneTree, scene: Node, expect: Callable) -> void:
	await check_still_portraits(tree, scene, expect)
	# Borrow a production portrait already installed by the combat fixture.
	var portrait: Texture2D
	for child: Node in (scene.get("_turn_order_bar") as Control).get_children():
		portrait = child.get_meta("turn_order_portrait_texture", null) as Texture2D
		if portrait != null: break
	expect.call(portrait != null, "The lifetime fixture has a production portrait")
	if portrait == null: return
	for retired_part: String in ["slot", "effect", "visual"]:
		var slot := Control.new()
		slot.size = PORTRAIT_FIXTURE_SIZE
		slot.set_meta("turn_order_portrait_texture", portrait)
		scene.add_child(slot)
		var visual := Control.new()
		slot.add_child(visual)
		var dissolve: Dictionary = scene.call("_turn_order_shadow_dissolve_slot", slot)
		var slots: Array[Dictionary]
		slots.append(dissolve)
		var survivor := Control.new()
		survivor.size = slot.size
		survivor.set_meta("turn_order_portrait_texture", portrait)
		scene.add_child(survivor)
		var survivor_visual := Control.new()
		survivor.add_child(survivor_visual)
		slots.append(scene.call("_turn_order_shadow_dissolve_slot", survivor))
		var completed: Dictionary = {"done": false}
		_dissolve(scene, slots, completed)
		# The first sample ran synchronously. Retire one borrowed node before the
		# next sample, as a rail reconciliation does during overlapping updates.
		if retired_part == "slot": slot.free()
		elif retired_part == "effect": (dissolve["effect"] as Node).free()
		else: visual.free()
		await _wait(tree, completed)
		expect.call(bool(completed["done"]), "A dissolve completes after its %s is freed" % retired_part)
		expect.call(is_zero_approx(survivor_visual.modulate.a), "Retiring the %s does not abort the surviving portrait's dissolve" % retired_part)
		survivor.free()
		if is_instance_valid(slot): slot.free()

	var before: Array[Dictionary] = scene.call("_turn_order_entries_from_state", scene.get("_combat_state"))
	var after: Array[Dictionary]
	var defeated: Dictionary = {}
	for entry: Dictionary in before:
		if str(entry.get("kind", "")) == "enemy" and defeated.is_empty():
			defeated[str(scene.call("_turn_order_actor_key", entry))] = true
		else:
			after.append(entry.duplicate(true))
	expect.call(not defeated.is_empty() and not after.is_empty(), "The overlap fixture removes an enemy portrait and retains the hero")
	var first: Dictionary = {"done": false}
	var second: Dictionary = {"done": false}
	_transition(scene, before, after, defeated, first)
	# Start another producer while the first transition owns its dissolve.
	var deadline: int = Time.get_ticks_msec() + COMPLETION_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline and scene.find_child("TurnOrderShadowDissolve", true, false) == null:
		await tree.process_frame
	expect.call(scene.find_child("TurnOrderShadowDissolve", true, false) != null, "The overlap starts during a real portrait dissolve")
	var active_dissolve: Node = scene.find_child("TurnOrderShadowDissolve", true, false)
	_transition(scene, before, after, defeated, second)
	expect.call(is_instance_valid(active_dissolve) and active_dissolve.is_inside_tree(), "A second producer cannot retire the active dissolve's slots")
	var rewound: bool = false
	deadline = Time.get_ticks_msec() + COMPLETION_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline and (not bool(first["done"]) or not bool(second["done"])):
		if bool(first["done"]):
			for child: Node in (scene.get("_turn_order_bar") as Control).get_children():
				if defeated.has(str(child.get_meta("turn_order_actor_key", ""))): rewound = true
		await tree.process_frame
	expect.call(not rewound, "A queued stale before-order cannot restore an already removed portrait")
	expect.call(bool(first["done"]) and bool(second["done"]), "Both overlapping rail producers finish")
	expect.call(not bool(scene.get("_turn_order_animating")), "Overlapping transitions release the rail lock")
	expect.call(float(scene.get("_turn_order_panel_locked_width")) < 0.0, "Overlapping transitions release the held panel width")
	var bar: Control = scene.get("_turn_order_bar")
	expect.call(bar.get_child_count() == after.size(), "The final rail contains exactly the surviving entries")
	for index: int in range(mini(bar.get_child_count(), after.size())):
		expect.call(str(bar.get_child(index).get_meta("turn_order_actor_key", "")) == str(scene.call("_turn_order_actor_key", after[index])), "The final rail keeps survivor order at %d" % index)
	await _test_queued_continuation(tree, scene, after, expect)
	await _test_detached_waiter(tree, scene, after, expect)

static func _test_queued_continuation(tree: SceneTree, scene: Node, before: Array[Dictionary], expect: Callable) -> void:
	var middle: Array[Dictionary] = scene.call("_turn_order_array", before)
	middle[0]["time"] = int(middle[0].get("time", 0)) + QUEUE_FIXTURE_TIME_STEP
	var after: Array[Dictionary] = scene.call("_turn_order_array", middle)
	after[0]["time"] = int(after[0].get("time", 0)) + QUEUE_FIXTURE_TIME_STEP
	var first: Dictionary = {"done": false}
	var second: Dictionary = {"done": false}
	_transition(scene, before, middle, {}, first)
	_transition(scene, middle, after, {}, second)
	await _wait(tree, first)
	await _wait(tree, second)
	expect.call(bool(first["done"]) and bool(second["done"]), "A queued matching continuation still completes")
	expect.call(str(scene.get("_turn_order_render_signature")).get_slice("|overflow:", 0) == str(scene.call("_turn_order_signature", after)), "A valid queued continuation reaches its newer order")

static func _test_detached_waiter(tree: SceneTree, scene: Node, order: Array[Dictionary], expect: Callable) -> void:
	var parent: Node = scene.get_parent()
	var was_current: bool = tree.current_scene == scene
	# Hold the same lock a suspended owner retains during Save and Quit. This
	# request must leave without acquiring ownership after tree exit.
	scene.set("_turn_order_animating", true)
	var completed: Dictionary = {"done": false}
	_transition(scene, order, order, {}, completed)
	parent.remove_child(scene)
	await tree.process_frame
	await tree.process_frame
	expect.call(bool(completed["done"]), "A waiting rail request cancels cleanly after the scene detaches")
	expect.call(bool(scene.get("_turn_order_animating")), "A cancelled waiter does not release another rail owner's lock")
	scene.set("_turn_order_animating", false)
	parent.add_child(scene)
	if was_current: tree.current_scene = scene
	await tree.process_frame

static func _dissolve(scene: Node, slots: Array[Dictionary], completed: Dictionary) -> void:
	await scene.call("_animate_turn_order_shadow_dissolves", slots)
	completed["done"] = true

static func _transition(scene: Node, before: Array[Dictionary], after: Array[Dictionary], defeated: Dictionary, completed: Dictionary) -> void:
	await scene.call("_animate_turn_order_transition", before, after, defeated)
	completed["done"] = true

static func _wait(tree: SceneTree, completed: Dictionary) -> void:
	var deadline: int = Time.get_ticks_msec() + COMPLETION_TIMEOUT_MSEC
	while not bool(completed["done"]) and Time.get_ticks_msec() < deadline:
		await tree.process_frame

# Exercise both production factories, including slots built outside the tree.
# Keep all six identities in the fixture even though the strip displays only
# four "before" actors during ordinary card aiming.
static func check_still_portraits(tree: SceneTree, scene: Node, expect: Callable) -> void:
	var result: Dictionary = {"failures": 0}
	var check: Callable = func(condition: bool, message: String) -> void:
		expect.call(condition, message)
		if not condition: result["failures"] = int(result["failures"]) + 1
	var stage := Control.new()
	var strip := Strip.new()
	var samples: Array[Dictionary]
	var entries: Array[Dictionary]
	for index: int in range(REGRESSION_ENEMIES.size()):
		var type: String = str(REGRESSION_ENEMIES[index])
		var entry: Dictionary = {"kind": "enemy", "type": type, "actor_key": "enemy_%d" % index, "team": "enemy", "hp": 1, "max_hp": 1, "time": index, "active": index == 0}
		entries.append(entry)
		var slot: Control = Slots.update(scene, entry, index)
		stage.add_child(slot)
		strip.call("_add_slot", entry, "StillPortrait_%d" % index, "before", 0.0, Callable(scene, "_turn_order_portrait_path"))
	stage.add_child(strip)
	tree.root.add_child(stage)
	for index: int in range(entries.size()):
		var type: String = str(entries[index]["type"])
		var slot: Control = stage.get_child(index) as Control
		var parts: Dictionary = slot.get_meta("perf03_retained_parts")
		var rail_portrait: TextureRect = parts["portrait"]
		var strip_slot: Node = strip.get_node("StillPortrait_%d" % index)
		var strip_portrait: TextureRect = strip_slot.get_node("LandingStripPortraitCrop/LandingStripPortrait")
		for portrait: TextureRect in [rail_portrait, strip_portrait]:
			var context: String = "%s %s" % [type, "rail" if portrait == rail_portrait else "landing strip"]
			check.call(portrait.texture != null and str(portrait.texture.get_meta("asset_source_path", portrait.texture.resource_path)) == PortraitPaths.PATHS[type], context + " uses PATHS painted portrait")
			check.call(not portrait.has_node("MaquettePortraitRenderer"), context + " has no live portrait renderer")
			var pixels: PackedByteArray = portrait.texture.get_image().get_data() if portrait.texture != null and str(portrait.texture.get_meta("asset_source_path", portrait.texture.resource_path)) == PortraitPaths.PATHS[type] else PackedByteArray()
			samples.append({"portrait": portrait, "texture": portrait.texture, "pixels": pixels, "context": context})
		check.call(slot.get_meta("turn_order_portrait_texture") == rail_portrait.texture, type + " defeat treatment retains painted texture")
		check.call(rail_portrait.modulate == scene.call("_turn_order_portrait_modulate", entries[index], index == 0), type + " retains active-slot modulate")
	for _frame: int in range(STILL_FRAME_COUNT):
		await tree.process_frame
		for sample: Dictionary in samples:
			var portrait: TextureRect = sample["portrait"]
			check.call(portrait.texture == sample["texture"], str(sample["context"]) + " keeps identical texture across 30 processed frames")
			if not (sample["pixels"] as PackedByteArray).is_empty():
				check.call(portrait.texture.get_image().get_data() == sample["pixels"], str(sample["context"]) + " keeps identical pixels across 30 processed frames")
	# Reapply changed content and reduced motion through the retained factories.
	var settings: Dictionary = scene.get("_settings")
	var previous_reduced: bool = bool(settings.get("reduced_motion", false))
	settings["reduced_motion"] = true
	scene.set("_settings", settings)
	strip.get("_slot_reuse").begin(strip)
	for index: int in range(entries.size()):
		var entry: Dictionary = entries[index].duplicate(true)
		entry["hp"] = 0
		var slot: Control = stage.get_child(index) as Control
		check.call(Slots.update(scene, entry, index, slot) == slot, "Rail reuses its painted slot in place")
		var previous: Node = strip.get_node("RetainedLandingStripSlot_%d" % index)
		strip.call("_add_slot", entry, "StillPortrait_%d" % index, "before", 0.0, Callable(scene, "_turn_order_portrait_path"))
		check.call(strip.get_node("StillPortrait_%d" % index) == previous, "Landing strip reuses its painted slot in place")
	strip.get("_slot_reuse").finish(strip)
	for sample: Dictionary in samples:
		var portrait: TextureRect = sample["portrait"]
		check.call(portrait.texture == sample["texture"], str(sample["context"]) + " retains texture when reduced motion changes")
	var hidden: Dictionary = entries[0].duplicate(true)
	hidden["hidden_by_umbra"] = true
	var hidden_slot: Control = Slots.update(scene, hidden, 0)
	stage.add_child(hidden_slot)
	strip.call("_add_slot", hidden, "StillHiddenPortrait", "after", 0.0, Callable(scene, "_turn_order_portrait_path"))
	var hidden_parts: Dictionary = hidden_slot.get_meta("perf03_retained_parts")
	var hidden_rail: TextureRect = hidden_parts["portrait"]
	var hidden_strip: TextureRect = strip.get_node("StillHiddenPortrait/LandingStripPortraitCrop/LandingStripPortrait")
	for portrait: TextureRect in [hidden_rail, hidden_strip]:
		check.call(portrait.texture.resource_path == "res://assets/art/icons/umbra_presence.png", "Umbra keeps the still Unknown Presence texture")
		check.call(not portrait.has_node("MaquettePortraitRenderer"), "Umbra has no live portrait renderer")
	settings["reduced_motion"] = previous_reduced
	scene.set("_settings", settings)
	stage.free()
	print("TURN ORDER STILL PORTRAITS: %s (6 identities; rail + landing strip; 30 processed frames)" % ("PASS" if int(result["failures"]) == 0 else "FAIL"))
