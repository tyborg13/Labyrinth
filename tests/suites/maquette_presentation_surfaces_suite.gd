extends RefCounted

## Independent Script identities, then actual production consumers (including
## portraits built outside the tree and their retained defeat texture).
const EXPECTED: Dictionary = {
	"burrow_grub": preload("res://assets/units/burrow_grub_cutout/renderer.gd"),
	"ember_tick": preload("res://assets/units/ember_tick_cutout/renderer.gd"),
	"bile_bloomer": preload("res://scripts/maquette_cutout_runtime/shale_bloomer_renderer.gd"),
	"lightning_wisp": preload("res://scripts/maquette_cutout_runtime/lightning_wisp_renderer.gd")
}
const Actor = preload("res://scripts/actor_presentation.gd")
const Live = preload("res://scripts/live_actor_presentation.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Run = preload("res://scripts/run_scene.gd")
const LandingStrip = preload("res://scripts/turn_order_landing_strip.gd")
const Portrait = preload("res://scripts/maquette_cutout_runtime/portrait.gd")
const Fixture = preload("res://tests/maquette_cutout/runtime_suite.gd")
const PROCESS_FRAMES: int = 3

static func run(expect: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var stage := Control.new()
	tree.root.add_child(stage)
	for frame: int in range(PROCESS_FRAMES): await tree.process_frame
	var host := Run.new()
	for identity: String in EXPECTED:
		var expected: Script = EXPECTED[identity]
		expect.call(Actor.travel_renderer(identity) == expected, "Travel resolves the maquette Script: " + identity)
		expect.call(Live.renderer_script(identity) == expected, "LiveActor resolves the maquette Script: " + identity)
		var board := Board.new()
		stage.add_child(board)
		var state: Dictionary = Fixture.fixture(identity)
		board.set_combat_state(state)
		var renderer: Node = board.unit_cutout_renderer(state["enemies"][0])
		expect.call(renderer != null and renderer.get_script() == expected, "Board instantiates the registered maquette Script: " + identity)
		var entry: Dictionary = {"kind": "enemy", "type": identity, "id": 1, "actor_key": "enemy_1", "team": "enemy", "hp": 1, "max_hp": 1, "time": 0}
		var slot: Control = host.call("_build_turn_order_slot", entry, 0)
		stage.add_child(slot)
		_check_portrait(slot, expected, identity + " turn order", expect)
		var portrait_renderer: Node = slot.find_child("MaquettePortraitRenderer", true, false)
		if portrait_renderer != null:
			expect.call(slot.get_meta("turn_order_portrait_texture") == (portrait_renderer.get_parent() as TextureRect).texture, "Turn order defeat retains its live maquette atlas: " + identity)
		var strip := LandingStrip.new()
		stage.add_child(strip)
		strip.call("_add_slot", entry, "TestMaquetteSlot", "before", 0.0, func(_entry: Dictionary) -> String: return Portrait.rest_path(identity))
		_check_portrait(strip, expected, identity + " landing strip", expect)
		for crop: bool in [false, true]:
			var portrait := TextureRect.new()
			Portrait.bind(portrait, identity, true, crop)
			stage.add_child(portrait)
			_check_portrait(portrait, expected, identity + " portrait", expect)
			var node: Node = portrait.get_node("MaquettePortraitRenderer")
			var snapshot: Dictionary = node.call("snapshot")
			expect.call(snapshot.get("shown_clip", snapshot["clip"]) == "rest" and is_zero_approx(float(snapshot["phase"])), "Reduced portrait reports its applied rest pose: " + identity)
			portrait.free()
		strip.free()
		slot.free()
		board.free()
	host.free()
	stage.free()

static func _check_portrait(surface: Node, expected: Script, context: String, expect: Callable) -> void:
	var renderer: Node = surface.find_child("MaquettePortraitRenderer", true, false)
	expect.call(renderer != null and renderer.get_script() == expected, context + " instantiates the registered maquette Script")
	if renderer == null: return
	var portrait := renderer.get_parent() as TextureRect
	expect.call(portrait.texture is AtlasTexture and (portrait.texture as AtlasTexture).atlas == renderer.call("texture"), context + " submits the registered renderer texture")
