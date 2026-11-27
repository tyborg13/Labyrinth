"""Source-backed inventory. Function anchors resolve to file:line at report time."""
from __future__ import annotations

from functools import cache
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
RUN = "run_scene"
BOARD = "combat_board_view"
BURST = "tile_burst_fx"
SHOT = "shot_fx"
GROUND = "board_pixel_surface_layer"
SPELL = "elemental_spell_fx"
DEATH = "enemy_mechanics/death_burst_view"
LOB = "enemy_mechanics/lob_view"
ICE = "enemy_mechanics/icefall_view"
WIND = "enemy_mechanics/wind_view"
STATUS = "board_status_plates"

ATLAS = "baked atlas stamp + shader"
DRAW = "CanvasItem draw_*"
IMAGE = "CanvasItem draw_texture*"
TWEEN = "Tween + CanvasItem"
GRID = "pixel_fx_layer grid + shader"
PIXELS = "Yes, using physical cells. Sheet fit may adjust the 2 px baseline."
SOLID = "Authored cells and discrete frame changes"
RAMP = "vfx_pixel_style.json ramp"
SMOOTH = "Continuous alpha"
TOKENS = "Palette tokens or code literals"
ART = "Authored texture + code tint"
NONE = "None"
MIX = "Normal"
NO_GRID = "No shared grid"
POSE = "Rig or sprite pose + CanvasItem draw_*"


@cache
def lines(script: str) -> list[str]:
    return (ROOT / f"scripts/{script}.gd").read_text().splitlines()


def site(script: str, function: str) -> str:
    pattern = re.compile(rf"^\s*(?:static )?func {re.escape(function)}\(")
    matches = [n for n, line in enumerate(lines(script), 1) if pattern.match(line)]
    if len(matches) != 1:
        raise ValueError(f"{script}.{function} matched {matches}")
    return f"scripts/{script}.gd:{matches[0]}"


def data(name: str) -> dict:
    return json.loads((ROOT / "data" / f"{name}.json").read_text())


def catalog() -> list[dict]:
    rows = []

    def add(id, family, spawn, path, grid, alpha, colors, shape, cost, *,
            blend=MIX, evidence="runtime", also=()):
        anchors = [site(*anchor) for anchor in (spawn, *also)]
        rows.append(dict(id=id, family=family, sites=anchors, path=path, grid=grid,
                         blend=blend, alpha=alpha, colors=colors, shape=shape,
                         cost=cost, evidence=evidence))

    def atlas(id, family, spawn, palette, cost, *, also=(), evidence="runtime"):
        add(id, family, spawn, ATLAS, PIXELS, SOLID, palette, NONE, cost,
            also=also, evidence=evidence)

    def mesh(id, family, spawn, shape, cost, *, evidence="runtime", also=()):
        add(id, family, spawn, "CanvasItem draw_mesh + additive child", NO_GRID,
            SMOOTH, "Weapon or enemy style literals", shape, cost,
            blend="Additive halo + normal core", evidence=evidence, also=also)

    tile_palette = "data/tile_bursts.json indexed palette"
    self_palette = "data/self_bursts.json indexed palette"
    shot_palette = "data/shots.json indexed palette"
    paired = "Up to two retained quads per eligible tile. Update frame uniform on cell-frame changes."
    self_pair = "Two depth-ordered quads. Per-stamp lifetime and frame index sampled."
    trail = "Live triangle batches from pose history. Separate normal and glow passes."
    float_cost = "Per-entry position/alpha/typography plus screen popup placement and retained icons."
    status_cost = "Retained plate layout with pop/forecast updates."
    terrain_cost = "Per-destroyed-prop playback frames. Board depth and occlusion are retained."

    mesh("player_melee_trail", "player", (BOARD, "_sync_strike_trail"),
         "Sweep ribbons, thrust streaks, spark diamonds", trail, also=(("hero_strike_trail", "prepare"),))
    atlas("player_melee_impact", "player", (RUN, "_animate_player_action_step"),
          tile_palette, paired, also=((BURST, "_spawn_stamp"),))
    for side in ("player", "enemy"):
        atlas(f"{side}_ranged_projectile", side, (SHOT, "_sample_flight"), shot_palette,
              "Retained head(s), optional shadow and clipped span. Update position and frame parameters.")
        atlas(f"{side}_ranged_impact", side, (SHOT, "_start_hit"), shot_palette,
              "Two reusable contact slots. Update one-shot frame and visibility.")
        add(f"{side}_area", side, (RUN, "_animate_player_action_step" if side == "player" else "_animate_enemy_phase_steps"),
            "Baked atlas stamp, pixel_fx_layer or CanvasItem footprint", "Route-dependent",
            "Authored cells or Bayer for routed effects. Smooth floor washes.",
            f"Indexed palettes, {RAMP} or lit accent literals", "Footprint polygons and optional spell lines",
            "Tiles plan/stagger separate contacts. Retained stamps or repeated footprint submissions.",
            also=((BOARD, "_draw_aoe_resolution_footprint"),))
        for name in ("block", "heal"):
            atlas(f"{side}_{name}", side, (BURST, "present_feedback"), self_palette, self_pair)
        add(f"{side}_move", side, (RUN, "_animate_player_move_path" if side == "player" else "_animate_move_step"),
            POSE, "Per-rig body fit. Ground translation is continuous.", "Body alpha or occlusion tint",
            ART, NONE, "Update moving actor, depth layer, shadow and HUD when needed.",
            also=((RUN, "_animate_actor_along_path"),))
        atlas(f"{side}_blink", side, (RUN, "_present_blink_transits"), self_palette,
              "Origin/arrival tear reuses the summon atlas. Delayed destination quad pair.")
        for name in ("push", "pull"):
            add(f"{side}_{name}", side, ("displacement_throw", "animate"),
                "Pose/position + optional shot stamp and collision painter", "Shot cells only",
                "Continuous body translation. Discrete optional shot cells.", f"{ART} and {shot_palette}",
                "Optional chain links and collision medallion",
                "Sample displacement paths. Optional per-marker circle and arc, plus hit feedback.",
                also=((BOARD, "_draw_effect_overlay"),))
        atlas(f"{side}_summon", side, (RUN, "_illusion_windup" if side == "player" else "_summon_prelude"),
              self_palette, "Rear/front stamp precedes body reveal.")

    atlas("player_burst", "player", (RUN, "_animate_player_action_step"), tile_palette,
          "Resolved cross contact plan. Eligible foreground and background rows are staggered by tile.")
    add("item_use", "player", (RUN, "_play_player_card"),
        "Card proxy Tween + resolved card action draw path", "Varies by resolved effect",
        "Proxy interpolates. Resolved gain/contact uses its normal effect.", ART,
        NONE, "Ordinary item cards dispatch through the same production card-resolution loop.")
    add("light_placement", "player", (BOARD, "_draw_umbra_light_source_markers"), DRAW,
        NO_GRID, "Pulsed layered alpha", "Code colour literals", "Orb circles, ellipses, motes and reach polygons",
        "Batched shapes and per-source footprint. Tethered and brazier paths branch separately.",
        also=((BOARD, "_draw_umbra_light_source_reach"),))
    add("chain_bolt", "player", ("chain_bolt_fx", "present"), "Nearest Sprite2D with rasterized bolt",
        "Yes, fx-14 cell size", "Ordered coverage per raster stage", "data/chain_bolt.json", "Jagged segmented strokes",
        "Reraster and update texture when fade stage, span or cell basis changes.")
    add("lightning_conduction", "player", ("chain_attack_feedback", "play"),
        "Baked tile contacts or pixel_fx_layer grid", "Yes for both paths",
        "Atlas cell sequence or Bayer quantization", f"Indexed palette or {RAMP}",
        "Segmented bolt strokes on the procedural path", "One hop or group of relay/contact tiles per beat.",
        also=((BURST, "event_specs"),))

    mesh("enemy_melee_trail", "enemy", (BOARD, "_sync_strike_trail"),
         "Ribbons, thrust streaks or claw cuts", trail, also=(("enemy_strike_trail", "prepare"),))
    mesh("enemy_claw_marks", "enemy", ("strike_trail_fx", "geometry"),
         "Curved tapered cuts and short streaks", trail, also=((BOARD, "_sync_strike_trail"),))
    mesh("enemy_area_rake", "enemy", (BOARD, "_draw_dragon_area_depth"),
         "Per-tile swept strikes", "Eligible foreground cells get their own geometry.",
         evidence="audit-only")
    atlas("enemy_melee_impact", "enemy", (RUN, "_append_contact_burst"), tile_palette, paired)
    add("surgeon_jab", "enemy", ("grave_surgeon_cutout/attack_fx", "draw_jab"),
        DRAW, NO_GRID, SMOOTH, "Code literals", "Tapered jab and ribbons",
        "Only legacy jab submissions surviving contact suppression.")
    atlas("enemy_lob_projectile", "enemy", (LOB, "_sample_flight"), shot_palette,
          "Reused ember head follows an arc. No separate projectile node allocation per frame.")
    atlas("enemy_lob_landing", "enemy", (LOB, "_present_contact"), tile_palette, paired)
    atlas("enemy_icefall_landing", "enemy", (ICE, "animate"), "data/strikes.json and data/tile_bursts.json",
          "One sky quad per visible tile. Contact can also submit pairs of grounded burst quads.")
    atlas("enemy_meteorfall", "enemy", (BURST, "spawn_strikes"), "data/strikes.json and data/tile_bursts.json",
          "The cue holds pre-contact until the resolver lands. The grounded burst is separate.")
    add("enemy_erupt", "enemy", ("enemy_mechanics/burrow_view", "animate"),
        POSE + " + optional pixel_fx_layer contact", "Body no shared grid. Routed contact uses 2 px.",
        "Mound/lift alpha or Bayer at contact", f"{ART} and {RAMP}", "Optional earthy debris and dust",
        "Move/rise frames plus displacement and surface playback for affected actors.")
    add("enemy_burrow", "enemy", ("enemy_mechanics/burrow_view", "draw_body"),
        IMAGE, NO_GRID, "Tint and continuous mound breath scale", ART, NONE,
        "Substitute mound art for the actor on the board.")
    add("enemy_outcrop_raise", "enemy", (RUN, "_animate_surface_change"), DRAW,
        NO_GRID, "Smoothstep height and opacity", "Earth literals", "Faceted polygons and grain",
        "Procedural terrain commands retained and refreshed as rise changes.",
        also=((BOARD, "_draw_terrain_object"),))
    add("enemy_charge", "enemy", ("enemy_mechanics/capacitor_view", "draw_pips"),
        POSE + " + CanvasItem pips", NO_GRID, "Pose, tint and discrete pip count", TOKENS, "Circle pips",
        "Capacitor charge clip, status float and count. Dynamo Tether reuses a charge field.")
    add("enemy_retreat", "enemy", (RUN, "_animate_move_step"), POSE, NO_GRID,
        "Continuous path sampling", ART, NONE, "Retreat uses movement playback with a retreat or backward clip.")
    add("enemy_split", "enemy", ("combat_engine", "_trigger_enemy_death_spawn"),
        "Death playback + new body submissions", NO_GRID, "Dissolve/pose depends on parent", ART,
        NONE, "The resolver adds newborn enemy IDs. No dedicated split stamp is selected.")
    add("enemy_grow_bramble", "enemy", ("enemy_mechanics/bramble_view", "animate"),
        IMAGE, NO_GRID, "Timed draw rect growth and fade", ART, NONE, "Per-prop transition on affected cells.")
    add("enemy_wind", "enemy", (WIND, "draw_field"), DRAW, NO_GRID, SMOOTH,
        TOKENS, "Animated field strokes and tile arrows", "Rows and strokes derived from field geometry.")
    atlas("enemy_refraction", "enemy", ("enemy_mechanics/reflect_view", "animate_beam"),
          shot_palette, "Retained head along the visible segment and ordinary contact slots.")
    add("enemy_banner_break", "enemy", ("warband_view", "animate_break"), DRAW,
        NO_GRID, SMOOTH, TOKENS, "Banner decal and spreading line/lozenge cues",
        "Sample eligible banner tiles during the break beat.")
    add("death_burst", "enemy", (DEATH, "decorate"), "Atlas contacts + CanvasItem draw_*",
        "Atlas cells only", "Authored cells and smooth glow/ribbon envelope", f"{tile_palette} and literals",
        "Tile glow, tapered ribbons and smoke quads", "Per-burst timing with chained contact and death holds.",
        also=((DEATH, "present_contacts"),))

    for name in ("fire", "ice", "electrified", "rubble"):
        path = "Shader floor field"
        extra = ()
        if name in ("fire", "electrified"):
            path += " + baked rear/front ground atlas"
            extra = (("board_ground_fx_sheet", "sync"),)
        add(f"surface_{name}", "surface", (GROUND, "present_field"), path,
            "Floor grain uses a projected cell lattice. Animated stamps use physical sheet cells.",
            "Indexed cells. Atlas frames and optional contact reflection opacity.",
            f"{RAMP} and ground animation indexed palettes", "Field masks, cracks or sprite shapes",
            "Field data/region rebuild on surfaces changing. Shared tick plus retained depth stamps.",
            also=extra + (("board_surface_presentation", "draw_tile"),))
        add(f"surface_break_{name}", "surface", ("board_surface_presentation", "draw_feedback"),
            "Baked contact or pixel_fx_layer grid + leaving layer",
            "Yes for contact. The leaving layer uses its own field/stamp path.",
            "Discrete frames/Bayer with smooth legacy leaving alpha",
            f"{RAMP} or {tile_palette}", "Per-element debris and floor marks",
            "Check affected tiles for leaving and replacement feedback.")
    for method, shape in {
        "release": "Directional tapered streaks, glow quads, sparks",
        "travel": "Ribbons, curls or segmented lines by element",
        "impact": "Fragments, puffs, ribbons and lightning strokes",
        "ground": "Floor chips, frost lines or pressure polygons",
        "floor_light": "Projected soft textured glow quad",
    }.items():
        add(f"pixel_{method}", "procedural", (SPELL, method), GRID, "Yes, 2 px at 1080",
            "Bayer discard of smooth source envelope", RAMP, shape,
            "Conservative bounds feed cropped low-resolution SubViewports. Contiguous same-element commands share a pass.",
            also=((BOARD, "_submit_pixel_fx"),))
    add("neutral_impact_decal", "procedural", (BOARD, "_draw_impact_decal"),
        "Removed. Neutral fallback draws nothing.", NONE, NONE, NONE, NONE, NONE,
        blend=NONE, evidence="removed")
    add("legacy_projectile", "procedural", (BOARD, "_draw_projectile_sprite"), IMAGE,
        NO_GRID, SMOOTH, ART, "Sprite with directional stretch and afterimage",
        "Travel redraw where the shot atlas has no replacement.", evidence="audit-only")

    for name in ("expose", "shock", "immobilize", "stoneskin", "frost_armor", "charge", "kindled_bonus"):
        for phase in ("gain", "tick"):
            add(f"status_{name}_{phase}", "status", (BOARD, "_unit_status_badges"), DRAW, NO_GRID,
                "Pill pop or count change. Forecast pulse is separate.", TOKENS,
                "Rounded style box and icon. Defense plate has a short line.", status_cost,
                also=((STATUS, "draw_entry"),))
    add("status_stagger", "status", (RUN, "_stagger_floating_texts"), DRAW,
        NO_GRID, SMOOTH, "Code literals", "Stagger glyph and text", float_cost)
    add("crystal_mantle_broken", "status", (RUN, "_player_action_floating_texts"),
        "Baked contact or pixel_fx_layer grid + float", "Effect cells only",
        "Atlas/Bayer plus smooth text", f"{RAMP}, {tile_palette} and literal text tint",
        "Ice fragments and label", float_cost, also=((BURST, "event_specs"),))
    add("status_chilled_frozen_legacy", "status", (BOARD, "_player_display_statuses"),
        "Legacy status fields in presentation", "No active draw", "No active draw",
        NONE, NONE, "Rules no longer apply Chilled or Freeze. Current Ice applies Expose.",
        evidence="dormant")
    add("status_petrify_legacy", "status", (BOARD, "_visible_units"),
        "Legacy field in rendered unit data", "No dedicated draw", "No active draw",
        NONE, NONE, "Visible-unit payload retains the field. The active plate switch has no Petrify entry.",
        evidence="dormant", also=((BOARD, "_unit_status_badges"),))
    add("status_other_popup", "status", (RUN, "_floating_texts_for_step"), DRAW, NO_GRID,
        SMOOTH, "Code literals", "Text and optional cause icon", float_cost,
        evidence="audit-only")
    add("status_pending_traits", "status", (BOARD, "_unit_status_badges"), DRAW, NO_GRID,
        "Badge pop/forecast alpha", TOKENS, "Icon, rounded plate and count",
        "Vision, retaliate, pending Quicken/next attack, Flying, Burrow, Split and other trait badges share status plates.",
        evidence="audit-only", also=((STATUS, "draw_entry"),))

    for element in ("fire", "ice", "earth", "air", "lightning"):
        add(f"trap_{element}", "hazard", (RUN, "_animate_player_ground_result"),
            "Baked contact + activation texture, or pixel_fx_layer grid", "Yes for contacts. Texture marker has native sampling.",
            "Indexed contact cells or Bayer. Sprite overlay has smooth alpha.",
            f"{tile_palette} and {RAMP} or native marker art", "Element-specific burst or pressure field",
            "Per trap, retained depth stamp or cropped pixel passes and animated marker.",
            also=((BOARD, "_draw_trap_elemental_footprint"),))
    add("tick_fire", "hazard", (RUN, "_animate_turn_start_fire"),
        "CanvasItem float + body flash, with contact FX on entry", "Float and body no shared grid",
        SMOOTH, "Code literal tint and Fire glyph", "Outlined digits and icon", float_cost,
        also=(("status_tick_feedback", "enemy_fire_start_losses"),))
    add("umbra_advance", "hazard", (BOARD, "_draw_umbra_overlay"), DRAW,
        NO_GRID, "Stage alpha and animated billows", "Code literals", "Tile polygons, line edges and soft circle lobes",
        "Batch circles/triangles. Per-hidden-tile and boundary work. Light can reveal or return tiles.")
    for id, topic, path, shape in (
        ("umbra_tethered_light", "_draw_umbra_tethered_light_marker", IMAGE, "Authored icon and layered light"),
        ("umbra_brazier", "_draw_noctyrax_brazier_markers", DRAW, "Marker/icon and prop flame"),
        ("trap_idle", "_draw_trap_marker", IMAGE, "Animated rune texture"),
        ("powder_keg_fuse", "_draw_powder_keg_fuse_glow", DRAW, "Soft textured glow"),
        ("death_site_embers", "_draw_death_site_embers", DRAW, "Ember sprites"),
    ):
        add(id, "hazard", (BOARD, topic), path, NO_GRID, "Texture alpha or continuous pulse",
            ART, shape, "Per authored board object or occupied tile.", evidence="audit-only")
    for id, label in (("powder_keg_burst", "Fire burst and displacement"),
                      ("worldspine_pulse", "Earth contact and radius footprint")):
        add(id, "hazard", (BURST, "event_specs"), ATLAS + " or " + GRID,
            "Atlas or procedural cells", SOLID + " or Bayer", f"{tile_palette} and {RAMP}",
            label, paired, also=((RUN, "_animate_surface_change"),))

    add("unit_death", "outcome", (RUN, "_animate_defeats_and_terrain_destruction"),
        POSE + " or dissolve shader", "Body fits are renderer-specific", "Frame sequence, fallback fade or procedural dissolve",
        ART, "Dissolve haze/embers", "Per-unit frame clocks, cutout sampling and depth order updates.",
        also=((BOARD, "_sync_enemy_shadow_dissolve_effects"),))
    add("death_dissolve", "outcome", (BOARD, "_sync_enemy_shadow_dissolve_effects"),
        "Shader on retained texture Control", NO_GRID, "Noise threshold and edge halo", ART,
        "Expanding eroded silhouette", "Reuses a prewarmed Control. Updates rect and shader uniforms.",
        also=(("enemy_shadow_dissolve_effect", "configure"),))
    for name, detail in {
        "crate": "Authored crate destruction frames",
        "box": "Authored box destruction frames",
        "powder_keg": "Keg frames plus its independent Fire Burst",
        "outcrop": "Procedural facets shrink and fade",
        "ice_pillar": "Pillar destruction texture sequence or texture fade",
        "bramble": "Bramble prop and expiry geometry",
        "worldspine": "Worldspine procedural facets shrink and fade",
        "raised_cover": "Destruction texture when available",
    }.items():
        add(f"destroy_{name}", "outcome", (RUN, "_animate_defeats_and_terrain_destruction"),
            DRAW + " + texture frames", NO_GRID, "Discrete frames or smooth tint/height",
            ART, detail, terrain_cost, also=((BOARD, "_draw_terrain_destruction"),))
    add("loot_pickup", "outcome", (RUN, "_animate_pickup_acquisition_flair"),
        TWEEN + " + baked acquisition stamp",
        "Atlas uses fitted physical cells. Icon, labels and ray use screen geometry.",
        "Discrete stamp frames and smooth icon/label alpha and scale",
        "Loot accent, authored icon and data/acquisition_bursts.json",
        "Ray and stroke geometry arc toward the destination", "Transient icon/banner, atlas quad and destination animation.")
    add("block_break", "outcome", (STATUS, "defense_entries"), DRAW, NO_GRID,
        "Plate drops when spent. Float fades separately.", TOKENS,
        "Defense plate line and loss number", "Block loss has a defense float and reaction. No dedicated break stamp.",
        also=((RUN, "_floating_texts_for_target_losses"),))
    for name in ("damage", "heal", "block", "stoneskin", "draw", "card_play"):
        add(f"number_{name}", "outcome", (BOARD, "_draw_floating_texts"),
            DRAW + " with retained icon textures", NO_GRID, SMOOTH,
            "Code tint or Earth token", "Outlined type, shadow and optional glyph", float_cost,
            also=(("floating_combat_text", "animate_entry"),))
    add("hit_flash", "outcome", (BOARD, "_draw_unit_sprite"), "Shader or second tinted texture draw",
        NO_GRID, "Contact alpha envelope", "White flash profile or code tint",
        "Body silhouette", "Second texture or effect uniform for the affected unit.")
    add("camera_kick", "outcome", (BOARD, "_update_impact_camera_shake"),
        "Tween on board offset", NO_GRID, "Decay and oscillation, no opacity", NONE, NONE,
        "Shared board offset follows one merged hit tween. Roar rumble has its own trigger.")
    add("fatigue_float", "outcome", (RUN, "_animate_fatigue_damage"),
        DRAW, NO_GRID, SMOOTH, "Code tints", "Damage text and Fatigue label", float_cost)
    add("retaliate_reaction", "outcome", (RUN, "_floating_texts_for_step"),
        DRAW, NO_GRID, SMOOTH, TOKENS, "Loss float and usual hit reaction",
        "Retaliate uses the status-damage transport and excludes the status-tick glyph.", evidence="audit-only")

    for id, title, kind in (
        ("aim_tile_washes", "_draw_tile_overlays", "Tile washes, target outlines and action highlights"),
        ("movement_path", "_draw_path_render_layer", "Authored path shapes, gradient contours and projected arcs"),
        ("collision_forecast", "_draw_collision_markers", "Filled circles, ring arc and danger icon"),
        ("trajectory_forecast", "_draw_ranged_target_preview_curve", "Sampled curve and projected arrow"),
        ("blink_aim_rift", "_draw_blink_rift_effect", "Textured rift, endpoint smudge and ribbon/lines"),
        ("intent_callout", "_draw_slice_callouts", "Intent callout text and graphic"),
        ("skyfall_marks", "_draw_meteor_mark_badges", "Mark badges and floor footprint"),
        ("unit_focus", "_draw_unit_focus", "Screen-space focus polygons and highlights"),
        ("battlefield_rule_callout", "_draw_effect_telegraphs", "Tile markers and battlefield action caption"),
        ("intent_halo", "_draw_slice_intent_halo", "Cached halo texture with animated alpha"),
        ("health_forecast", "_draw_health_damage_preview", "Health preview segments and damage chips"),
        ("lethal_forecast", "_draw_lethal_preview_icons", "Pulsed lethal icon"),
        ("occlusion_fade", "_foreground_blocker_tint", "Obstructor draw tint"),
    ):
        add(id, "telegraph", (BOARD, title), DRAW + " or UI texture tint", NO_GRID,
            "Continuous alpha or fixed input-dependent geometry", TOKENS, kind,
            "Retained tile/HUD caches update for preview, hover or relevant state.", evidence="audit-only")
    add("lob_marks", "telegraph", (LOB, "draw_tile"), DRAW,
        NO_GRID, "Pulsed floor alpha and static badge", TOKENS, "Marked-tile wash and damage badge",
        "Retained footprint lookup keyed by active lobbers.", evidence="audit-only",
        also=((LOB, "draw_badges"),))
    add("loot_idle", "ambient", (BOARD, "_draw_equipment_pickup"), IMAGE,
        NO_GRID, "Bobbing texture and pulsing outline", ART, "Outlined pickup silhouette",
        "Per-pickup texture, shadow and pulse.", evidence="audit-only")
    add("combat_turn_banner", "telegraph", (RUN, "_show_turn_banner"), TWEEN,
        NO_GRID, "Fade and motion on a visible UI band", TOKENS, "Text and band",
        "A single phase banner yields to boss or enemy action overlays.", evidence="audit-only")
    add("ambient_motes", "ambient", ("combat_atmosphere", "build_preset_motes"), "CPUParticles2D",
        NO_GRID, "Particle curves and emitter envelope", "Biome preset data",
        "Textured particles across viewport", "One emitter per biome. Disabled under reduced motion.", evidence="audit-only")
    add("ambient_film", "ambient", ("combat_atmosphere", "_apply_biome"), "Atmosphere shader", NO_GRID,
        "Continuous shader strength", "Biome preset data", "Screen-space haze, vignette and hurt tint",
        "Full viewport shader plus time/board-light uniforms.", blend="Premultiplied alpha", evidence="audit-only")
    add("unit_contact_shadow", "ambient", (BOARD, "_draw_unit_shadow"),
        "CanvasItem mesh with optional multiply contact layer", "Contact layer uses pixel field alignment",
        "Texture/silhouette opacity", "Shadow tint literals", "Fallback ellipse",
        "Cached silhouette geometry, refreshed for moving actors or art changes.", blend="Normal or multiply",
        evidence="audit-only")
    add("torch_light_motes", "ambient", (BOARD, "_draw_pillar_torch_flame_light"),
        DRAW, NO_GRID, "Smooth pulse and sprite alpha", ART, "Light glow and moving motes",
        "Per torch cached mote templates and projected light.", evidence="audit-only")

    for row in data("tile_bursts")["rows"]:
        if row.endswith("_front"):
            atlas("burst_" + row.removesuffix("_front"), "atlas-contact", (BURST, "_spawn_stamp"),
                  tile_palette, paired)
    for row in data("self_bursts")["rows"]:
        if row.endswith("_front"):
            atlas("self_" + row.removesuffix("_front"), "atlas-self", (BURST, "spawn_self"),
                  self_palette, self_pair)
    for row in data("strikes")["rows"]:
        atlas("sky_" + row.removesuffix("_front"), "atlas-sky", (BURST, "spawn_strikes"),
              "data/strikes.json indexed palette", "One retained sky quad per eligible tile. Clock tracks strike contact.")
    shots = data("shots")["shots"]
    for name in shots:
        atlas("shot_" + name, "atlas-shot", (SHOT, "_submit_head"), shot_palette,
              "Reusable head and depth slot. Nearest indexed texels sampled by flight/flicker frame.")
    for name in dict.fromkeys(row["hit"] for row in shots.values() if row["hit"]):
        atlas("shot_" + name, "atlas-shot", (SHOT, "_start_hit"), shot_palette,
              "Update one of two reusable contact slots until its authored lifetime ends.")
    atlas("hook_links", "atlas-shot", (SHOT, "_show_links"), shot_palette,
          "One retained span quad. Shader indexes repeated links.")
    atlas("reflected_projectile", "atlas-shot", (SHOT, "_sample_reflection"), shot_palette,
          "Dedicated reusable return head.")
    atlas("shot_shadow", "atlas-shot", (SHOT, "_sample_flight"), shot_palette,
          "One reusable shadow slot with its own tint and nearest atlas sampling.")
    if len({row["id"] for row in rows}) != len(rows):
        raise ValueError("duplicate effect ID")
    return rows
