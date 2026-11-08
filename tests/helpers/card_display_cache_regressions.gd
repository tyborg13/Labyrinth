extends RefCounted

const Display = preload("res://scripts/card_display_overrides.gd")
const Bindings = preload("res://scripts/card_display_bindings.gd")
const Dependencies = preload("res://scripts/card_display_dependencies.gd")
const State = preload("res://scripts/card_display_state.gd")
const Data = preload("res://scripts/game_data.gd")
const Fixture = preload("res://tests/helpers/card_display_fixture.gd")
const Audit = preload("res://tests/helpers/card_legibility_audit.gd")
const CardScene = preload("res://scenes/card_widget.tscn")
const BASE: Dictionary = {"player_hp": 24, "player_max_hp": 24, "player_pos": Vector2i(2, 2), "relics": []}
# Reviewer's actual colliding source hashes. Keep both sets as production IDs.
const COLLIDING_RELICS: Array = [
	["tailwind_fletching", "fivefold_knot", "fencers_gloves", "briar_throne", "whirling_sash", "iron_lung", "ember_lens", "mirror_shard"],
	["bloodglass_knife", "fivefold_knot", "hourglass_awl", "cragbound_gauntlet", "fencers_gloves", "bonded_set", "crown_of_surplus", "briar_throne", "iron_lung", "ember_lens", "pilgrim_boots", "mirror_shard", "coffin_nails"]
]
const OVERFLOW_VARIANTS: int = 520
const DEFINITION_LIMIT: int = 512
const IDENTITY_VARIANTS: Array = [27006, 122826]

static func run(tree: SceneTree, expect: Callable) -> void:
	_collision(tree, expect)
	_player_transitions(tree, expect)
	_overflow(tree, expect)
	# Mutations exercise the retained-face guards, including all cache limits.
	# The independent catalog matrix runs once in the normal focused program.
	if not OS.get_cmdline_user_args().has("--binding-guards"): _matrix(expect)

static func _collision(tree: SceneTree, expect: Callable) -> void:
	Bindings.reset_cache()
	var engine := preload("res://scripts/run_engine.gd").new()
	var first: Dictionary = Fixture.bloodglass_shop(engine, 12)
	first["relics"] = COLLIDING_RELICS[0].duplicate()
	var second: Dictionary = first.duplicate(true)
	second["relics"] = COLLIDING_RELICS[1].duplicate()
	var source_a: Dictionary = Dependencies.context_values(State.inputs(first))
	var source_b: Dictionary = Dependencies.context_values(State.inputs(second))
	expect.call(hash(source_a["source"]) == hash(source_b["source"]), "Collision fixture retains the reviewer's matching source hashes")
	expect.call(source_a["source"] != source_b["source"], "Colliding source snapshots compare their exact values")
	var shop := preload("res://scripts/scavenger_shop_view.gd").new()
	tree.root.add_child(shop)
	shop.configure(first, engine, true)
	shop.call("_select_item", "training_sword", false, shop.find_child("GearOffer_training_sword", true, false))
	var face: Control = Audit.find_card(shop.get("_detail_card_host"))
	expect.call(face != null, "Collision fixture binds the real shop's Training Sword detail")
	if face != null:
		expect.call(_damage(face.display_summary_rows()) == 6, "First colliding relic set shows Quick Stab 6")
		Display.refresh(shop, second)
		expect.call(_damage(face.display_summary_rows()) == 13 and face.display_summary_rows() == Display.for_card("quick_stab", second)["summary_rows"], "Bound colliding source changes Quick Stab from 6 to 13 without clearing the cache")
		# Mutating the caller's nested array cannot mutate a retained snapshot.
		(second["relics"] as Array).clear()
		Display.refresh(shop, second)
		expect.call(_damage(face.display_summary_rows()) == 6, "In-place nested source edits invalidate the frozen dependency snapshot")
	shop.free()
	_identity_buckets(tree, expect)
	print("CARD02 BOUND COLLISION: Quick Stab 6 -> 13 -> 6; exact snapshots")

static func _identity_buckets(tree: SceneTree, expect: Callable) -> void:
	# Separate fixed identity collision: exercise both context-local and retained
	# definition lookups with two unequal variants in one hash bucket.
	Bindings.reset_cache()
	var elements: Array = Data.upgradeable_elements_for_card("quick_stab", {})
	var options: Array = []
	for element: Dictionary in elements.slice(0, 2): options.append(Data.upgrade_options_for_element("quick_stab", element, {})[0])
	expect.call(options.size() == 2 and options[0] != options[1], "Collision identity fixture uses two distinct authored upgrade options")
	if options.size() != 2: return
	expect.call(hash(["quick_stab", Data.cards()["quick_stab"], IDENTITY_VARIANTS[0]]) == hash(["quick_stab", Data.cards()["quick_stab"], IDENTITY_VARIANTS[1]]), "Distinct upgrade identities deliberately share a hash bucket")
	var host := Control.new()
	tree.root.add_child(host)
	var face: Control = CardScene.instantiate()
	host.add_child(face)
	var sequence: Array = [0, 1, 0, 1]
	for step: int in range(sequence.size()):
		var index: int = sequence[step]
		var option: Dictionary = options[index]
		var state: Dictionary = BASE.duplicate(true)
		if step >= 2: state["player_bleed"] = step
		face.configure("quick_stab")
		Display.bind(face, state, func(source: Dictionary) -> Dictionary: return Data.preview_card_with_mod("quick_stab", option, source), IDENTITY_VARIANTS[index])
		var expected: Dictionary = Data.preview_card_with_mod("quick_stab", option, state)
		expect.call(face.call("_display_card_def") == expected and face.display_summary_rows() == Display.for_card("quick_stab", state, expected)["summary_rows"], "Bound upgrade identity is exact inside a colliding hash bucket: " + str(step))
	expect.call(Bindings.calculations == 2 and Bindings.definition_count() == 2, "Both colliding definitions coexist and reuse independently")
	host.free()

static func _player_transitions(tree: SceneTree, expect: Callable) -> void:
	Bindings.reset_cache()
	var host := Control.new()
	tree.root.add_child(host)
	var face: Control = CardScene.instantiate()
	face.configure("stonefist")
	host.add_child(face)
	Display.bind(face, BASE)
	for stoneskin: int in [0, 3, 6, 7, 0]:
		var state: Dictionary = BASE.duplicate(true)
		state["player_stoneskin"] = stoneskin
		var before: int = Bindings.calculations
		Display.refresh(host, state)
		expect.call(_damage(face.display_summary_rows()) == 6 + mini(stoneskin, 6), "Bound Stonefist scales across the Stoneskin threshold: " + str(stoneskin))
		expect.call(face.display_summary_rows() == Display.for_card("stonefist", state)["summary_rows"], "Bound Stonefist rows match fresh resolution")
		if stoneskin == 7: expect.call(Bindings.calculations == before, "Stonefist past its cap has the same effective Stoneskin dependency")
	face.configure("frostbolt")
	var frost: Dictionary = BASE.duplicate(true)
	frost["relics"] = ["hobnail_cleats"]
	Display.bind(face, frost)
	for patch: Dictionary in [
		{"surfaces": {"2,2": {"elemental": "ice"}}},
		{"player_pos": Vector2i(3, 2)},
		{"surfaces": {"2,2": {"elemental": "ice"}, "3,2": {"elemental": "ice"}}},
		{"surfaces": {"2,2": {"elemental": "ice"}, "3,2": {"elemental": "fire"}}}
	]:
		frost.merge(patch, true)
		Display.refresh(host, frost)
		var on_ice: bool = preload("res://scripts/board_surface_rules.gd").has_surface(frost, frost["player_pos"], "ice")
		expect.call(_damage(face.display_summary_rows()) == (6 if on_ice else 4), "Bound Frostbolt/Hobnail follows the hero's surface and position")
		expect.call(face.display_summary_rows() == Display.for_card("frostbolt", frost)["summary_rows"], "Bound Frostbolt/Hobnail rows match fresh resolution")
	host.free()
	print("CARD02 BOUND PLAYER INPUTS: Stonefist cap and Frostbolt/Hobnail surface transitions")

static func _overflow(tree: SceneTree, expect: Callable) -> void:
	Bindings.reset_cache()
	var host := Control.new()
	tree.root.add_child(host)
	var face: Control = CardScene.instantiate()
	host.add_child(face)
	var calls: Dictionary = {"count": 0}
	for index: int in range(OVERFLOW_VARIANTS):
		_bind_variant(face, BASE, index, calls)
		expect.call(Bindings.definition_count() == mini(index + 1, DEFINITION_LIMIT), "Definition cache remains bounded during overflow: " + str(index))
	var retained: int = calls["count"]
	# New raw contexts prevent the context-local projection cache from hiding
	# definition eviction. Bleed changes no dependency for these variants.
	for index: int in range(8, OVERFLOW_VARIANTS):
		var state: Dictionary = BASE.duplicate(true)
		state["player_bleed"] = index + 1
		_bind_variant(face, state, index, calls)
	expect.call(calls["count"] == retained, "Overflow retains exactly the newest 512 definitions across context eviction")
	var state: Dictionary = BASE.duplicate(true)
	state["player_bleed"] = OVERFLOW_VARIANTS + 1
	_bind_variant(face, state, 8, calls)
	expect.call(calls["count"] == retained, "Touching the oldest surviving definition reuses its projection")
	state["player_bleed"] += 1
	_bind_variant(face, state, 0, calls)
	expect.call(calls["count"] == retained + 1, "FIFO overflow evicts the oldest definition")
	state["player_bleed"] += 1
	_bind_variant(face, state, 8, calls)
	expect.call(calls["count"] == retained + 2, "Reusing a definition does not promote it: insertion order controls eviction")
	expect.call(Bindings.definition_count() == DEFINITION_LIMIT, "Definition cache stays at 512 after eviction/reinsertion")
	host.free()
	print("CARD02 CACHE OVERFLOW: 520 variants; 512 retained; FIFO and context eviction verified")

static func _bind_variant(face: Control, state: Dictionary, index: int, calls: Dictionary) -> void:
	face.configure("quick_stab")
	Display.bind(face, state, func(source: Dictionary) -> Dictionary:
		calls["count"] += 1
		return Data.card_def_for_progression("quick_stab", source)
	, {"cache_test_variant": index})

static func _matrix(expect: Callable) -> void:
	Bindings.reset_cache()
	var states: Array = [BASE]
	# A fixed gear/relic source, followed by only player/spatial changes, checks
	# that dependency selection cannot conceal a fresh resolver result.
	for relics: Array in [[], ["bloodglass_knife"], ["hobnail_cleats"], ["anchor_chain"], ["widow_thread", "true_north", "sunlit_edge"]]:
		for patch: Dictionary in [{}, {"player_stoneskin": 3}, {"player_block": 3}, {"player_hp": 12}, {"player_bleed": 3}, {"surfaces": {"2,2": {"elemental": "ice"}}}, {"player_pos": Vector2i(3, 2)}, {"illusions": [{"id": 1, "hp": 2, "pos": Vector2i(2, 2)}]}, {"player_truesight": true}, {"umbra": {"light_sources": [{"pos": Vector2i(2, 2), "radius": 2}]}}]:
			var state: Dictionary = BASE.duplicate(true)
			state["relics"] = relics.duplicate()
			state.merge(patch, true)
			states.append(state)
	var comparisons: int = 0
	for state: Dictionary in states:
		var ctx: Dictionary = Bindings.context(state)
		for id: String in Data.cards():
			var actual: Dictionary = Bindings.projection(ctx, id, Callable(), null, Display.for_card)
			var definition: Dictionary = Data.card_def_for_progression(id, state)
			expect.call(actual["card"] == definition and actual["display"] == Display.for_card(id, state, definition), "Cached/fresh equality for %s in player-input case %d" % [id, comparisons / Data.cards().size()])
			comparisons += 1
	print("CARD02 PLAYER INPUT MATRIX: %d cached/fresh comparisons; %d catalog cards" % [comparisons, Data.cards().size()])

static func _damage(rows: Array) -> int:
	for row: Array in rows:
		for token: Dictionary in row:
			if str(token.get("field", "")) == "damage": return int(token.get("value", 0))
	return 0
