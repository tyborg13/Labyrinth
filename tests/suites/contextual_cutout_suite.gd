extends RefCounted

const Context = preload("res://scripts/cutout_context.gd")
const FloatingText = preload("res://scripts/floating_combat_text.gd")
const Guardian = preload("res://scripts/guardian_cutout/renderer.gd")
const FAMILIES: Array[String] = ["protagonist", "stone_warden", "crawler", "acolyte", "bile_bloomer", "chainbound_gaoler", "cinder_droplet", "cinder_ooze", "frostglass_lancer", "grave_surgeon", "harrier", "iskaldra", "lightning_wisp", "noctyrax", "tharokh", "vaeloryx", "veilbound_acolyte", "vyraketh", "zekarion"]

static func run(tree: SceneTree, expect: Callable) -> void:
	_check_routing(expect)
	_check_feedback_tags(expect)
	for family: String in FAMILIES:
		var script: Script = load("res://scripts/%s_cutout/renderer.gd" % family)
		await _check_renderer(tree, script.new(), family, expect)
	for actor: String in Guardian.ACTOR_IDS:
		var renderer := Guardian.new()
		renderer.character_id = actor
		await _check_renderer(tree, renderer, actor, expect)

static func _check_routing(expect: Callable) -> void:
	var state: Dictionary = {"player": {"hp": 10}, "enemies": [{"id": 7, "type": "zekarion", "hp": 20}], "illusions": [{"id": 3, "hp": 2}]}
	var damage: Dictionary = FloatingText.damage_entry(Vector2i(2,2), "-3", Color.WHITE, {"reaction_actor_key":"enemy_7", "reaction":"hit"})
	var presentation: Dictionary = {"floating_texts": [damage]}
	Context.apply_to_presentation(state, presentation)
	expect.call(not presentation.has("zekarion_motion"), "Unresolved/base popup cannot pre-trigger a recoil")
	presentation = {"floating_texts": FloatingText.animate_entries([damage], 0.054, false)}
	Context.apply_to_presentation(state, presentation)
	expect.call(presentation["zekarion_motion"]["enemy_7"]["clip"] == "hit" and is_equal_approx(float(presentation["zekarion_motion"]["enemy_7"]["phase"]), .15), "Resolved damage owns the .36-second reaction clock")
	expect.call(not presentation.has("protagonist_motion"), "Enemy damage does not animate the player")
	presentation = {"floating_texts": FloatingText.animate_entries([damage], .4, false)}
	Context.apply_to_presentation(state, presentation)
	expect.call(not presentation.has("zekarion_motion"), "The actor recovers before the popup finishes")
	presentation = {"floating_texts": FloatingText.animate_entries([damage], .05, false), "zekarion_motion": {"enemy_7": {"clip":"attack", "phase":.2}}}
	Context.apply_to_presentation(state, presentation)
	expect.call(presentation["zekarion_motion"]["enemy_7"]["clip"] == "attack", "A lingering prior hit cannot cancel a fresh outgoing action")
	var guard: Dictionary = {"reaction_actor_key":"player", "reaction":"block", "animation_progress":.1}
	presentation = {"floating_texts":[guard]}
	Context.apply_to_presentation(state, presentation)
	expect.call(presentation["protagonist_motion"]["clip"] == "block", "An absorbed player hit uses its guard pose")
	presentation = {"floating_texts":[guard, {"reaction_actor_key":"player", "reaction":"hit", "animation_progress":.12}]}
	Context.apply_to_presentation(state, presentation)
	expect.call(presentation["protagonist_motion"]["clip"] == "hit", "HP damage takes precedence over partial absorption")
	presentation = {"floating_texts":[{"kind":"damage", "tile":Vector2i(2,2), "animation_progress":.1}]}
	Context.apply_to_presentation(state, presentation)
	expect.call(not presentation.has("protagonist_motion") and not presentation.has("zekarion_motion"), "Terrain damage and decorative popups never infer an actor from their tile")
	presentation = {"death_animation_units":[{"key":"enemy_7", "type":"zekarion", "death_animation":true, "death_progress":.62}], "zekarion_motion":{"enemy_7":{"clip":"attack", "phase":.4}}}
	Context.apply_to_presentation(state, presentation)
	expect.call(presentation["zekarion_motion"]["enemy_7"] == {"clip":"death", "phase":1.0}, "Death overrides actions and settles while the original dissolve is still running")
	presentation = {"death_animation_units":[{"key":"enemy_7", "type":"zekarion", "hp":20, "death_progress":.62}]}
	Context.apply_to_presentation(state,presentation)
	expect.call(not presentation.has("zekarion_motion"), "Living reinforcement arrival reuses dissolve without a death pose")
	for actor_type: String in preload("res://scripts/game_data.gd").enemies():
		var roster_state: Dictionary = {"enemies":[{"id":7,"type":actor_type,"hp":20}]}
		var roster_presentation: Dictionary = {"floating_texts":FloatingText.animate_entries([damage],.054,false)}
		Context.apply_to_presentation(roster_state,roster_presentation)
		var family: String = Context.family_key(actor_type)
		expect.call(not family.is_empty() and roster_presentation.get(family,{}).get("enemy_7",{}).get("clip","") == "hit", actor_type + " content identity routes its incoming damage")
	presentation = {"floating_texts":[{"reaction_actor_key":"illusion_3", "reaction":"hit", "animation_progress":.1}]}
	Context.apply_to_presentation(state,presentation)
	expect.call(presentation.get("illusion_motion",{}).has("illusion_3") and not presentation.has("protagonist_motion"), "An illusion owns its incoming hit independently of the player")
	var untouched: Dictionary = state.duplicate(true)
	Context.apply_to_presentation(state, {})
	expect.call(state == untouched, "Reaction routing cannot mutate resolver state")

static func _check_feedback_tags(expect: Callable) -> void:
	var scene: Node = load("res://scripts/run_scene.gd").new()
	var losses: Array = [{"key":"enemy_7", "kind":"enemy", "tile":Vector2i(3,3), "hp_loss":2}, {"key":"player", "kind":"player", "tile":Vector2i(2,2), "block_loss":3}]
	var entries: Array = scene.call("_floating_texts_for_target_losses", losses)
	expect.call(entries.size() == 2 and entries[0].get("reaction_actor_key") == "enemy_7" and entries[1].get("reaction") == "block", "Actual outcome feedback tags actor identities and absorbed hits")
	var terrain: Array = scene.call("_floating_texts_for_terrain_losses", [{"tile":Vector2i(2,2), "hp_loss":3}])
	expect.call(terrain.size() == 1 and not terrain[0].has("reaction_actor_key"), "Terrain HP losses stay outside character reactions")
	var status: Array = scene.call("_status_damage_floating_texts", {"actor_key":"enemy_7", "tile":Vector2i(3,3), "amount":2, "label":"Bleed"})
	expect.call(status[0].get("reaction_actor_key") == "enemy_7", "Status damage retains its actual victim")
	scene.free()

static func _check_renderer(tree: SceneTree, renderer: Node, actor: String, expect: Callable) -> void:
	tree.root.add_child(renderer)
	await tree.process_frame
	renderer.set_process(false)
	var texture: Texture2D = renderer.call("texture")
	for direction: Vector2i in [Vector2i(0,1), Vector2i(0,-1)]:
		renderer.call("present", {"clip":"walk", "phase":.0, "direction":direction}, false)
		var view: String = str(renderer.get("facing"))
		var rig: Node2D = renderer.get("rigs")[view]
		rig.call("apply_pose", "rest", 0.0)
		var neutral: Dictionary = _transforms(rig)
		for clip: String in ["hit", "death"]:
			renderer.call("present", {"clip":clip, "phase":.15 if clip == "hit" else 1.0}, false, clip != "death")
			var sample: Dictionary = renderer.call("snapshot")
			expect.call(sample["clip"] == clip and sample["facing"] == view, "%s %s %s routes without turning or substituting art" % [actor,view,clip])
			expect.call(renderer.call("texture") == texture, actor + " preserves its canvas through reactions and dissolve")
			expect.call(_different(neutral, _transforms(rig)), "%s %s %s has an authored articulated pose" % [actor,view,clip])
			renderer.call("present", {"clip":clip, "phase":.5}, true, clip != "death")
			var reduced: Dictionary = renderer.call("snapshot")
			expect.call(reduced["clip"] == ("death" if clip == "death" else "rest"), actor + " reduced motion shows a stable meaningful state")
			if clip == "death":
				expect.call(is_equal_approx(float(reduced["phase"]),1.0), actor + " reduced death shows its stable endpoint")
		renderer.call("present", {}, false)
		expect.call(renderer.call("snapshot")["clip"] == "idle", actor + " returns to idle on the next living presentation")
	renderer.queue_free()
	await tree.process_frame

static func _transforms(rig: Node2D) -> Dictionary:
	var result: Dictionary = {}
	for bone: String in rig.get("bones"):
		result[bone] = (rig.get("bones")[bone] as Bone2D).transform
	return result

static func _different(a: Dictionary, b: Dictionary) -> bool:
	for key: String in a:
		if not (a[key] as Transform2D).is_equal_approx(b[key]):
			return true
	return false
