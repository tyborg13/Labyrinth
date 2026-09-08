extends SceneTree

const Card = preload("res://scripts/card_widget.gd")
const Elements = preload("res://scripts/element_data.gd")
const RARITIES: Array = ["", "starter", "common", "rare", "epic", "legendary"]
const ELEMENTS: Array = ["fire", "ice", "lightning", "air", "earth"]
const ROLES: Array = ["role_mobility", "role_attack_melee", "role_block", "role_attack_ranged", "role_illusion"]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var card := Card.new()
	var emblem := Card.DebossedRoleEmblem.new()
	var results: Dictionary = {"schema_version": 1, "workload_id": "cold_card_frame_and_emblem_images_v1", "frames": {}, "emblems": {}}
	for rarity: String in RARITIES:
		for element: String in ELEMENTS:
			assert(Elements.is_elemental(element), "Benchmark element must be authored")
			var started: int = Time.get_ticks_usec()
			var texture: Texture2D = card.call("_card_frame_texture", rarity, element)
			var ms: float = float(Time.get_ticks_usec() - started) / 1000.0
			var img: Image = texture.get_image()
			results["frames"][rarity + "/" + element] = {"ms": ms, "size": img.get_size(), "bytes_digest": hash(img.get_data())}
	for role: String in ROLES:
		var started: int = Time.get_ticks_usec()
		var texture: Texture2D = emblem.call("_masked_emblem_texture", "res://assets/art/ui/card_role_emblems/" + role + ".png")
		var ms: float = float(Time.get_ticks_usec() - started) / 1000.0
		var img: Image = texture.get_image()
		results["emblems"][role] = {"ms": ms, "size": img.get_size(), "bytes_digest": hash(img.get_data())}
	card.free()
	emblem.free()
	results["semantic_errors"] = []
	print("CARD PRESENTATION PERF RESULT: %s" % JSON.stringify(results))
	quit()
