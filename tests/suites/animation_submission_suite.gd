extends RefCounted
## A contact snapshot can mutate the same Dictionary used by earlier samples.
const Fixture = preload("res://tests/suites/en04_enemies_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Droplet = preload("res://scripts/cinder_droplet_cutout/renderer.gd")
const SUMMON_ENEMY_ID: int = 7
const SUMMON_TILE := Vector2i(6, 5)

static func run(scene: Node, expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = Fixture.fixture(engine, "slag_mortar")
	scene.set("_combat_state", state)
	var board: Node = scene.get("board_view")
	# Reproduce a type not present before the contact, even if the initial run's
	# asynchronous preparation happened to warm that type in this process.
	(board.get("_unit_assets_loaded") as Dictionary).erase("cinder_droplet")
	(board.get("_unit_textures") as Dictionary).erase("cinder_droplet")
	scene.call("_render_board_state", state, {}, false)
	var after: Dictionary = state.duplicate(true)
	var summoned: Dictionary = engine._spawned_enemy_entry(after, "cinder_droplet", SUMMON_ENEMY_ID, SUMMON_TILE, true)
	(after["enemies"] as Array).append(summoned)
	var action: Dictionary = Fixture.intent("slag_mortar", "slag_lands")["actions"][0]
	var step: Dictionary = Fixture.Lob.animation_step(engine, state, after, 0, action)
	expect.call(step.has("en04_state_after"), "The submission regression uses the production Slag landing snapshot")
	scene.call("_apply_animation_step", state, step)
	# The adapter's later samples keep its reference and request the fast path.
	# Applying the contact snapshot must invalidate that hint exactly once.
	scene.call("_render_board_state", state, {}, true)
	expect.call(bool(board.get("_unit_assets_loaded").get("cinder_droplet", false)), "A contact-born Droplet loads its static assets on its first submission")
	var anchor: Texture2D = board.call("_unit_hud_anchor_texture", summoned)
	var rest: Texture2D = Assets.load_texture_source_first(Droplet.REST_PATH)
	expect.call(anchor == rest, "The new Droplet's HUD and shadow use its approved rest source immediately")
	if anchor == rest:
		var image: Image = Assets.texture_source_image(anchor)
		expect.call(image != null and not image.is_empty(), "The first Droplet silhouette has CPU pixels without viewport readback")
		expect.call(not Assets.build_alpha_polygons(anchor).is_empty(), "The first Droplet shadow has an opaque silhouette")
