extends RefCounted
## Source paths refer to the live shader or a factory for a shared inline shader.
## Each geometry entry is an RD canvas command variant, not a texture variant.
## Cel is baked texture data. Tile/actor palette lanes are uniforms/UVs on the
## same live art shader, while the floor bake has its own render target.

enum Phase { TITLE_IDLE, LOADING_COVER, ROOM_ENTRY, COVER_INTRO }

const COVER_MESSAGE := "Entering the Labyrinth"
const COVER_OUTLINE_SIZE := 6
const COVER_INTRO := [
	{"name": "loading stone text", "path": "res://scripts/ui_typography.gd", "factory": "stone_text_shader", "draw": "banner"},
	{"name": "loading shade", "draw": "rect"},
]
const TITLE_IDLE := [
	{"name": "section map fog", "draw": "rect", "path": "res://shaders/section_map_fog.gdshader"},
	{"name": "section map routes", "draw": "route"},
	{"name": "opening dialogue portrait clip", "path": "res://scripts/dialogue_portrait_clip.gdshader"},
]
const LOADING_COVER := [
	{"name": "board cel colour rectangles", "draw": "rect", "path": "res://scripts/combat_pacing.gd", "factory": "impact_flash_shader", "source": "res://assets/shaders/combat_art_treatment.gdshader"},
	{"name": "board cel textured polygons", "path": "res://scripts/combat_pacing.gd", "factory": "impact_flash_shader", "source": "res://assets/shaders/combat_art_treatment.gdshader", "draw": "polygon_uv"},
	{"name": "board cel colour polygons", "path": "res://scripts/combat_pacing.gd", "factory": "impact_flash_shader", "source": "res://assets/shaders/combat_art_treatment.gdshader", "draw": "polygon_color"},
	{"name": "board cel shadow mesh", "path": "res://scripts/combat_pacing.gd", "factory": "impact_flash_shader", "source": "res://assets/shaders/combat_art_treatment.gdshader", "draw": "mesh_color"},
	{"name": "board cel ambient mesh", "path": "res://scripts/combat_pacing.gd", "factory": "impact_flash_shader", "source": "res://assets/shaders/combat_art_treatment.gdshader", "draw": "mesh_uv"},
	{"name": "board cel primitive", "path": "res://scripts/combat_pacing.gd", "factory": "impact_flash_shader", "source": "res://assets/shaders/combat_art_treatment.gdshader", "draw": "primitive"},
	{"name": "board floor bake backdrop", "path": "res://assets/shaders/combat_art_treatment.gdshader", "target": "transparent", "draw": "rect"},
	{"name": "board floor bake tile art", "path": "res://assets/shaders/combat_art_treatment.gdshader", "target": "transparent", "draw": "polygon_uv_solid"},
	{"name": "board floor bake shade and grid", "path": "res://assets/shaders/combat_art_treatment.gdshader", "target": "transparent", "draw": "floor_shade"},
	{"name": "board floor composite", "path": "res://assets/shaders/combat_floor_light.gdshader"},
	{"name": "board atmosphere", "draw": "rect", "path": "res://scripts/combat_atmosphere.gd", "factory": "atmosphere_shader"},
]
const ROOM_ENTRY := [
	{"name": "card frame reflection", "path": "res://scripts/card_widget.gd", "factory": "frame_reflection_shader", "draw": "stylebox"},
	{"name": "card rarity gem", "draw": "rect", "path": "res://scripts/card_widget.gd", "factory": "rarity_glow_shader"},
	{"name": "card action context glow", "path": "res://shaders/card_action_context_soft_glow.gdshader"},
	{"name": "card hand cache composite", "blend": CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA},
	{"name": "card drawing in hand cache", "draw": "stylebox", "target": "transparent"},
	{"name": "board targeting ink", "draw": "rect", "path": "res://scripts/targeted_tile_highlight.gdshader"},
	{"name": "board unit occlusion and team ink", "path": "res://scripts/board_occlusion_silhouettes.gdshader"},
	{"name": "turn-order polygon clip", "draw": "clip"},
	{"name": "turn-order portrait ink", "path": "res://scripts/turn_order_portrait_clip.gd", "factory": "portrait_shader", "smoothing_off": true},
	{"name": "turn-order portrait coverage", "path": "res://scripts/turn_order_portrait_coverage.gd", "factory": "coverage_shader", "smoothing_off": true, "draw": "polygon_solid", "target": "transparent"},
	{"name": "board surface particles", "path": "res://scripts/board_surface_particle.gd", "draw": "surface"},
	{"name": "board electric surface", "path": "res://scripts/board_surface_electric_layer.gd", "draw": "electric"},
	{"name": "pixel trail geometry", "path": "res://shaders/pixel_fx_lines.gdshader", "draw": "stroke", "target": "no_msaa_alpha"},
	{"name": "pixel trail composite", "path": "res://shaders/pixel_fx_quantize.gdshader"},
	{"name": "strike trail additive triangles", "blend": CanvasItemMaterial.BLEND_MODE_ADD, "draw": "triangles"},
	{"name": "atmosphere additive particles", "blend": CanvasItemMaterial.BLEND_MODE_ADD, "draw": "motes"},
	{"name": "enemy shadow dissolve", "path": "res://assets/shaders/enemy_shadow_dissolve.gdshader"},
	{"name": "wisp straight alpha conversion", "path": "res://scripts/lightning_wisp_cutout/straight_alpha.gdshader", "target": "no_msaa_alpha"},
]

static func for_phase(phase: Phase, continuing: bool) -> Array[Dictionary]:
	var recipes: Array[Dictionary] = preload("res://scripts/typed_arrays.gd").dictionaries([])
	match phase:
		Phase.COVER_INTRO:
			recipes.assign(COVER_INTRO)
		Phase.TITLE_IDLE:
			recipes.assign(COVER_INTRO)
			recipes.append_array(TITLE_IDLE)
		Phase.LOADING_COVER:
			recipes.assign(COVER_INTRO)
			recipes.append_array(TITLE_IDLE)
			recipes.append_array(LOADING_COVER)
			if continuing: recipes.append_array(ROOM_ENTRY)
		Phase.ROOM_ENTRY:
			recipes.assign(ROOM_ENTRY)
	return recipes
