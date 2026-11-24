extends "res://tests/helpers/counted_program.gd"

const Merchant = preload("res://tests/suites/scavenger_shop_suite.gd")
const Depth = preload("res://tests/suites/depth_rules_suite.gd")
const Maps = preload("res://tests/suites/section_map_v7_suite.gd")
const Graph = preload("res://scripts/section_map_graph.gd")

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--merchant-prices"):
		Merchant.run(_expect)
		Depth._test_shop_prices(_expect)
		_finish("ECO03 MERCHANT AND DEPTH PRICES")
		return
	Merchant.run(_expect)
	Maps.test_saved_revisions_regenerate(_expect)
	Maps.test_fallback_sections(_expect)
	for seed_value: int in range(1, Maps.SEEDS + 1):
		var state: Dictionary = {"seed": seed_value, "current_room": Vector2i.ZERO, "mode": "room"}
		Graph.initialize(state)
		for index: int in range(6):
			Maps.test_section_rules(state, index, _expect)
			Maps.test_doors(state, index, _expect)
			Maps.test_layout(state, index, _expect)
	_finish("ECO03 SCAVENGER AND MAP POLICIES")
