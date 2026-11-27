# fel-10 combat effects census

202 inventory rows. The hunt observed 125 IDs and packaged 123 witnesses.

## Draw paths

The audit covers live combat board effects, persistent effects and targeting telegraphs. Action rows describe a production route. The atlas rows enumerate authored variants of shared routes, so a single frame can satisfy more than one ID.

The procedural composite uses the screen-anchored 2 px grid at 1080p, Bayer alpha thresholds and the configured element ramp. Baked atlases have separate palettes and physical cell fits. Animation clocks can hold or repeat an authored cell across consecutive rendered frames.

| ID | Family | Spawn or draw site | Draw path | Grid | Blend | Alpha | Colour source | Visible geometry | Cost | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| player_melee_trail | player | `scripts/combat_board_view.gd:12559`, `scripts/hero_strike_trail.gd:15` | CanvasItem draw_mesh + additive child | No shared grid | Additive halo + normal core | Continuous alpha | Weapon or enemy style literals | Sweep ribbons, thrust streaks, spark diamonds | Live triangle batches from pose history. Separate normal and glow passes. | PASS |
| player_melee_impact | player | `scripts/run_scene.gd:23723`, `scripts/tile_burst_fx.gd:549` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/tile_bursts.json indexed palette | None | Up to two retained quads per eligible tile. Update frame uniform on cell-frame changes. | PASS |
| player_ranged_projectile | player | `scripts/shot_fx.gd:845` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Retained head(s), optional shadow and clipped span. Update position and frame parameters. | PASS |
| player_ranged_impact | player | `scripts/shot_fx.gd:1033` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Two reusable contact slots. Update one-shot frame and visibility. | PASS |
| player_area | player | `scripts/run_scene.gd:23723`, `scripts/combat_board_view.gd:13237` | Baked atlas stamp, pixel_fx_layer or CanvasItem footprint | Route-dependent | Normal | Authored cells or Bayer for routed effects. Smooth floor washes. | Indexed palettes, vfx_pixel_style.json ramp or lit accent literals | Footprint polygons and optional spell lines | Tiles plan/stagger separate contacts. Retained stamps or repeated footprint submissions. | PASS |
| player_block | player | `scripts/tile_burst_fx.gd:673` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/self_bursts.json indexed palette | None | Two depth-ordered quads. Per-stamp lifetime and frame index sampled. | PASS |
| player_heal | player | `scripts/tile_burst_fx.gd:673` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/self_bursts.json indexed palette | None | Two depth-ordered quads. Per-stamp lifetime and frame index sampled. | replay unresolved |
| player_move | player | `scripts/run_scene.gd:25320`, `scripts/run_scene.gd:25541` | Rig or sprite pose + CanvasItem draw_* | Per-rig body fit. Ground translation is continuous. | Normal | Body alpha or occlusion tint | Authored texture + code tint | None | Update moving actor, depth layer, shadow and HUD when needed. | PASS |
| player_blink | player | `scripts/run_scene.gd:25493` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/self_bursts.json indexed palette | None | Origin/arrival tear reuses the summon atlas. Delayed destination quad pair. | PASS |
| player_push | player | `scripts/displacement_throw.gd:117`, `scripts/combat_board_view.gd:12577` | Pose/position + optional shot stamp and collision painter | Shot cells only | Normal | Continuous body translation. Discrete optional shot cells. | Authored texture + code tint and data/shots.json indexed palette | Optional chain links and collision medallion | Sample displacement paths. Optional per-marker circle and arc, plus hit feedback. | never observed |
| player_pull | player | `scripts/displacement_throw.gd:117`, `scripts/combat_board_view.gd:12577` | Pose/position + optional shot stamp and collision painter | Shot cells only | Normal | Continuous body translation. Discrete optional shot cells. | Authored texture + code tint and data/shots.json indexed palette | Optional chain links and collision medallion | Sample displacement paths. Optional per-marker circle and arc, plus hit feedback. | never observed |
| player_summon | player | `scripts/run_scene.gd:23648` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/self_bursts.json indexed palette | None | Rear/front stamp precedes body reveal. | never observed |
| enemy_ranged_projectile | enemy | `scripts/shot_fx.gd:845` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Retained head(s), optional shadow and clipped span. Update position and frame parameters. | PASS |
| enemy_ranged_impact | enemy | `scripts/shot_fx.gd:1033` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Two reusable contact slots. Update one-shot frame and visibility. | PASS |
| enemy_area | enemy | `scripts/run_scene.gd:24458`, `scripts/combat_board_view.gd:13237` | Baked atlas stamp, pixel_fx_layer or CanvasItem footprint | Route-dependent | Normal | Authored cells or Bayer for routed effects. Smooth floor washes. | Indexed palettes, vfx_pixel_style.json ramp or lit accent literals | Footprint polygons and optional spell lines | Tiles plan/stagger separate contacts. Retained stamps or repeated footprint submissions. | PASS |
| enemy_block | enemy | `scripts/tile_burst_fx.gd:673` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/self_bursts.json indexed palette | None | Two depth-ordered quads. Per-stamp lifetime and frame index sampled. | PASS |
| enemy_heal | enemy | `scripts/tile_burst_fx.gd:673` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/self_bursts.json indexed palette | None | Two depth-ordered quads. Per-stamp lifetime and frame index sampled. | PASS |
| enemy_move | enemy | `scripts/run_scene.gd:25248`, `scripts/run_scene.gd:25541` | Rig or sprite pose + CanvasItem draw_* | Per-rig body fit. Ground translation is continuous. | Normal | Body alpha or occlusion tint | Authored texture + code tint | None | Update moving actor, depth layer, shadow and HUD when needed. | PASS |
| enemy_blink | enemy | `scripts/run_scene.gd:25493` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/self_bursts.json indexed palette | None | Origin/arrival tear reuses the summon atlas. Delayed destination quad pair. | never observed |
| enemy_push | enemy | `scripts/displacement_throw.gd:117`, `scripts/combat_board_view.gd:12577` | Pose/position + optional shot stamp and collision painter | Shot cells only | Normal | Continuous body translation. Discrete optional shot cells. | Authored texture + code tint and data/shots.json indexed palette | Optional chain links and collision medallion | Sample displacement paths. Optional per-marker circle and arc, plus hit feedback. | never observed |
| enemy_pull | enemy | `scripts/displacement_throw.gd:117`, `scripts/combat_board_view.gd:12577` | Pose/position + optional shot stamp and collision painter | Shot cells only | Normal | Continuous body translation. Discrete optional shot cells. | Authored texture + code tint and data/shots.json indexed palette | Optional chain links and collision medallion | Sample displacement paths. Optional per-marker circle and arc, plus hit feedback. | PASS |
| enemy_summon | enemy | `scripts/run_scene.gd:23658` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/self_bursts.json indexed palette | None | Rear/front stamp precedes body reveal. | PASS |
| player_burst | player | `scripts/run_scene.gd:23723` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/tile_bursts.json indexed palette | None | Resolved cross contact plan. Eligible foreground and background rows are staggered by tile. | never observed |
| item_use | player | `scripts/run_scene.gd:21985` | Card proxy Tween + resolved card action draw path | Varies by resolved effect | Normal | Proxy interpolates. Resolved gain/contact uses its normal effect. | Authored texture + code tint | None | Ordinary item cards dispatch through the same production card-resolution loop. | never observed |
| light_placement | player | `scripts/combat_board_view.gd:6624`, `scripts/combat_board_view.gd:6584` | CanvasItem draw_* | No shared grid | Normal | Pulsed layered alpha | Code colour literals | Orb circles, ellipses, motes and reach polygons | Batched shapes and per-source footprint. Tethered and brazier paths branch separately. | PASS |
| chain_bolt | player | `scripts/chain_bolt_fx.gd:40` | Nearest Sprite2D with rasterized bolt | Yes, fx-14 cell size | Normal | Ordered coverage per raster stage | data/chain_bolt.json | Jagged segmented strokes | Reraster and update texture when fade stage, span or cell basis changes. | PASS |
| lightning_conduction | player | `scripts/chain_attack_feedback.gd:15`, `scripts/tile_burst_fx.gd:281` | Baked tile contacts or pixel_fx_layer grid | Yes for both paths | Normal | Atlas cell sequence or Bayer quantization | Indexed palette or vfx_pixel_style.json ramp | Segmented bolt strokes on the procedural path | One hop or group of relay/contact tiles per beat. | PASS |
| enemy_melee_trail | enemy | `scripts/combat_board_view.gd:12559`, `scripts/enemy_strike_trail.gd:57` | CanvasItem draw_mesh + additive child | No shared grid | Additive halo + normal core | Continuous alpha | Weapon or enemy style literals | Ribbons, thrust streaks or claw cuts | Live triangle batches from pose history. Separate normal and glow passes. | PASS |
| enemy_claw_marks | enemy | `scripts/strike_trail_fx.gd:113`, `scripts/combat_board_view.gd:12559` | CanvasItem draw_mesh + additive child | No shared grid | Additive halo + normal core | Continuous alpha | Weapon or enemy style literals | Curved tapered cuts and short streaks | Live triangle batches from pose history. Separate normal and glow passes. | PASS |
| enemy_area_rake | enemy | `scripts/combat_board_view.gd:12420` | CanvasItem draw_mesh + additive child | No shared grid | Additive halo + normal core | Continuous alpha | Weapon or enemy style literals | Per-tile swept strikes | Eligible foreground cells get their own geometry. | audit-only |
| enemy_melee_impact | enemy | `scripts/run_scene.gd:23561` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/tile_bursts.json indexed palette | None | Up to two retained quads per eligible tile. Update frame uniform on cell-frame changes. | PASS |
| surgeon_jab | enemy | `scripts/grave_surgeon_cutout/attack_fx.gd:7` | CanvasItem draw_* | No shared grid | Normal | Continuous alpha | Code literals | Tapered jab and ribbons | Only legacy jab submissions surviving contact suppression. | PASS |
| enemy_lob_projectile | enemy | `scripts/enemy_mechanics/lob_view.gd:263` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Reused ember head follows an arc. No separate projectile node allocation per frame. | PASS |
| enemy_lob_landing | enemy | `scripts/enemy_mechanics/lob_view.gd:272` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/tile_bursts.json indexed palette | None | Up to two retained quads per eligible tile. Update frame uniform on cell-frame changes. | PASS |
| enemy_icefall_landing | enemy | `scripts/enemy_mechanics/icefall_view.gd:117` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/strikes.json and data/tile_bursts.json | None | One sky quad per visible tile. Contact can also submit pairs of grounded burst quads. | PASS |
| enemy_meteorfall | enemy | `scripts/tile_burst_fx.gd:542` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/strikes.json and data/tile_bursts.json | None | The cue holds pre-contact until the resolver lands. The grounded burst is separate. | PASS |
| enemy_erupt | enemy | `scripts/enemy_mechanics/burrow_view.gd:131` | Rig or sprite pose + CanvasItem draw_* + optional pixel_fx_layer contact | Body no shared grid. Routed contact uses 2 px. | Normal | Mound/lift alpha or Bayer at contact | Authored texture + code tint and vfx_pixel_style.json ramp | Optional earthy debris and dust | Move/rise frames plus displacement and surface playback for affected actors. | PASS |
| enemy_burrow | enemy | `scripts/enemy_mechanics/burrow_view.gd:26` | CanvasItem draw_texture* | No shared grid | Normal | Tint and continuous mound breath scale | Authored texture + code tint | None | Substitute mound art for the actor on the board. | PASS |
| enemy_outcrop_raise | enemy | `scripts/run_scene.gd:34944`, `scripts/combat_board_view.gd:9579` | CanvasItem draw_* | No shared grid | Normal | Smoothstep height and opacity | Earth literals | Faceted polygons and grain | Procedural terrain commands retained and refreshed as rise changes. | PASS |
| enemy_charge | enemy | `scripts/enemy_mechanics/capacitor_view.gd:34` | Rig or sprite pose + CanvasItem draw_* + CanvasItem pips | No shared grid | Normal | Pose, tint and discrete pip count | Palette tokens or code literals | Circle pips | Capacitor charge clip, status float and count. Dynamo Tether reuses a charge field. | never observed |
| enemy_retreat | enemy | `scripts/run_scene.gd:25248` | Rig or sprite pose + CanvasItem draw_* | No shared grid | Normal | Continuous path sampling | Authored texture + code tint | None | Retreat uses movement playback with a retreat or backward clip. | PASS |
| enemy_split | enemy | `scripts/combat_engine.gd:8655` | Death playback + new body submissions | No shared grid | Normal | Dissolve/pose depends on parent | Authored texture + code tint | None | The resolver adds newborn enemy IDs. No dedicated split stamp is selected. | PASS |
| enemy_grow_bramble | enemy | `scripts/enemy_mechanics/bramble_view.gd:103` | CanvasItem draw_texture* | No shared grid | Normal | Timed draw rect growth and fade | Authored texture + code tint | None | Per-prop transition on affected cells. | never observed |
| enemy_wind | enemy | `scripts/enemy_mechanics/wind_view.gd:164` | CanvasItem draw_* | No shared grid | Normal | Continuous alpha | Palette tokens or code literals | Animated field strokes and tile arrows | Rows and strokes derived from field geometry. | never observed |
| enemy_refraction | enemy | `scripts/enemy_mechanics/reflect_view.gd:274` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Retained head along the visible segment and ordinary contact slots. | never observed |
| enemy_banner_break | enemy | `scripts/warband_view.gd:89` | CanvasItem draw_* | No shared grid | Normal | Continuous alpha | Palette tokens or code literals | Banner decal and spreading line/lozenge cues | Sample eligible banner tiles during the break beat. | never observed |
| death_burst | enemy | `scripts/enemy_mechanics/death_burst_view.gd:101`, `scripts/enemy_mechanics/death_burst_view.gd:171` | Atlas contacts + CanvasItem draw_* | Atlas cells only | Normal | Authored cells and smooth glow/ribbon envelope | data/tile_bursts.json indexed palette and literals | Tile glow, tapered ribbons and smoke quads | Per-burst timing with chained contact and death holds. | PASS |
| surface_fire | surface | `scripts/board_pixel_surface_layer.gd:75`, `scripts/board_ground_fx_sheet.gd:146`, `scripts/board_surface_presentation.gd:55` | Shader floor field + baked rear/front ground atlas | Floor grain uses a projected cell lattice. Animated stamps use physical sheet cells. | Normal | Indexed cells. Atlas frames and optional contact reflection opacity. | vfx_pixel_style.json ramp and ground animation indexed palettes | Field masks, cracks or sprite shapes | Field data/region rebuild on surfaces changing. Shared tick plus retained depth stamps. | PASS |
| surface_break_fire | surface | `scripts/board_surface_presentation.gd:632` | Baked contact or pixel_fx_layer grid + leaving layer | Yes for contact. The leaving layer uses its own field/stamp path. | Normal | Discrete frames/Bayer with smooth legacy leaving alpha | vfx_pixel_style.json ramp or data/tile_bursts.json indexed palette | Per-element debris and floor marks | Check affected tiles for leaving and replacement feedback. | PASS |
| surface_ice | surface | `scripts/board_pixel_surface_layer.gd:75`, `scripts/board_surface_presentation.gd:55` | Shader floor field | Floor grain uses a projected cell lattice. Animated stamps use physical sheet cells. | Normal | Indexed cells. Atlas frames and optional contact reflection opacity. | vfx_pixel_style.json ramp and ground animation indexed palettes | Field masks, cracks or sprite shapes | Field data/region rebuild on surfaces changing. Shared tick plus retained depth stamps. | PASS |
| surface_break_ice | surface | `scripts/board_surface_presentation.gd:632` | Baked contact or pixel_fx_layer grid + leaving layer | Yes for contact. The leaving layer uses its own field/stamp path. | Normal | Discrete frames/Bayer with smooth legacy leaving alpha | vfx_pixel_style.json ramp or data/tile_bursts.json indexed palette | Per-element debris and floor marks | Check affected tiles for leaving and replacement feedback. | PASS |
| surface_electrified | surface | `scripts/board_pixel_surface_layer.gd:75`, `scripts/board_ground_fx_sheet.gd:146`, `scripts/board_surface_presentation.gd:55` | Shader floor field + baked rear/front ground atlas | Floor grain uses a projected cell lattice. Animated stamps use physical sheet cells. | Normal | Indexed cells. Atlas frames and optional contact reflection opacity. | vfx_pixel_style.json ramp and ground animation indexed palettes | Field masks, cracks or sprite shapes | Field data/region rebuild on surfaces changing. Shared tick plus retained depth stamps. | PASS |
| surface_break_electrified | surface | `scripts/board_surface_presentation.gd:632` | Baked contact or pixel_fx_layer grid + leaving layer | Yes for contact. The leaving layer uses its own field/stamp path. | Normal | Discrete frames/Bayer with smooth legacy leaving alpha | vfx_pixel_style.json ramp or data/tile_bursts.json indexed palette | Per-element debris and floor marks | Check affected tiles for leaving and replacement feedback. | PASS |
| surface_rubble | surface | `scripts/board_pixel_surface_layer.gd:75`, `scripts/board_surface_presentation.gd:55` | Shader floor field | Floor grain uses a projected cell lattice. Animated stamps use physical sheet cells. | Normal | Indexed cells. Atlas frames and optional contact reflection opacity. | vfx_pixel_style.json ramp and ground animation indexed palettes | Field masks, cracks or sprite shapes | Field data/region rebuild on surfaces changing. Shared tick plus retained depth stamps. | PASS |
| surface_break_rubble | surface | `scripts/board_surface_presentation.gd:632` | Baked contact or pixel_fx_layer grid + leaving layer | Yes for contact. The leaving layer uses its own field/stamp path. | Normal | Discrete frames/Bayer with smooth legacy leaving alpha | vfx_pixel_style.json ramp or data/tile_bursts.json indexed palette | Per-element debris and floor marks | Check affected tiles for leaving and replacement feedback. | never observed |
| pixel_release | procedural | `scripts/elemental_spell_fx.gd:689`, `scripts/combat_board_view.gd:5428` | pixel_fx_layer grid + shader | Yes, 2 px at 1080 | Normal | Bayer discard of smooth source envelope | vfx_pixel_style.json ramp | Directional tapered streaks, glow quads, sparks | Conservative bounds feed cropped low-resolution SubViewports. Contiguous same-element commands share a pass. | PASS |
| pixel_travel | procedural | `scripts/elemental_spell_fx.gd:716`, `scripts/combat_board_view.gd:5428` | pixel_fx_layer grid + shader | Yes, 2 px at 1080 | Normal | Bayer discard of smooth source envelope | vfx_pixel_style.json ramp | Ribbons, curls or segmented lines by element | Conservative bounds feed cropped low-resolution SubViewports. Contiguous same-element commands share a pass. | never observed |
| pixel_impact | procedural | `scripts/elemental_spell_fx.gd:300`, `scripts/combat_board_view.gd:5428` | pixel_fx_layer grid + shader | Yes, 2 px at 1080 | Normal | Bayer discard of smooth source envelope | vfx_pixel_style.json ramp | Fragments, puffs, ribbons and lightning strokes | Conservative bounds feed cropped low-resolution SubViewports. Contiguous same-element commands share a pass. | never observed |
| pixel_ground | procedural | `scripts/elemental_spell_fx.gd:206`, `scripts/combat_board_view.gd:5428` | pixel_fx_layer grid + shader | Yes, 2 px at 1080 | Normal | Bayer discard of smooth source envelope | vfx_pixel_style.json ramp | Floor chips, frost lines or pressure polygons | Conservative bounds feed cropped low-resolution SubViewports. Contiguous same-element commands share a pass. | never observed |
| pixel_floor_light | procedural | `scripts/elemental_spell_fx.gd:192`, `scripts/combat_board_view.gd:5428` | pixel_fx_layer grid + shader | Yes, 2 px at 1080 | Normal | Bayer discard of smooth source envelope | vfx_pixel_style.json ramp | Projected soft textured glow quad | Conservative bounds feed cropped low-resolution SubViewports. Contiguous same-element commands share a pass. | PASS |
| neutral_impact_decal | procedural | `scripts/combat_board_view.gd:12237` | CanvasItem draw_* | No shared grid | Normal | Continuous alpha | Code literals | Filled ellipse, outlined ellipse, seven short radial marks | Build two sampled ellipse polygons and radial lines per active decal. | never observed |
| legacy_projectile | procedural | `scripts/combat_board_view.gd:13063` | CanvasItem draw_texture* | No shared grid | Normal | Continuous alpha | Authored texture + code tint | Sprite with directional stretch and afterimage | Travel redraw where the shot atlas has no replacement. | audit-only |
| status_expose_gain | status | `scripts/combat_board_view.gd:17783`, `scripts/board_status_plates.gd:111` | CanvasItem draw_* | No shared grid | Normal | Pill pop or count change. Forecast pulse is separate. | Palette tokens or code literals | Rounded style box and icon. Defense plate has a short line. | Retained plate layout with pop/forecast updates. | PASS |
| status_expose_tick | status | `scripts/combat_board_view.gd:17783`, `scripts/board_status_plates.gd:111` | CanvasItem draw_* | No shared grid | Normal | Pill pop or count change. Forecast pulse is separate. | Palette tokens or code literals | Rounded style box and icon. Defense plate has a short line. | Retained plate layout with pop/forecast updates. | PASS |
| status_shock_gain | status | `scripts/combat_board_view.gd:17783`, `scripts/board_status_plates.gd:111` | CanvasItem draw_* | No shared grid | Normal | Pill pop or count change. Forecast pulse is separate. | Palette tokens or code literals | Rounded style box and icon. Defense plate has a short line. | Retained plate layout with pop/forecast updates. | PASS |
| status_shock_tick | status | `scripts/combat_board_view.gd:17783`, `scripts/board_status_plates.gd:111` | CanvasItem draw_* | No shared grid | Normal | Pill pop or count change. Forecast pulse is separate. | Palette tokens or code literals | Rounded style box and icon. Defense plate has a short line. | Retained plate layout with pop/forecast updates. | PASS |
| status_immobilize_gain | status | `scripts/combat_board_view.gd:17783`, `scripts/board_status_plates.gd:111` | CanvasItem draw_* | No shared grid | Normal | Pill pop or count change. Forecast pulse is separate. | Palette tokens or code literals | Rounded style box and icon. Defense plate has a short line. | Retained plate layout with pop/forecast updates. | PASS |
| status_immobilize_tick | status | `scripts/combat_board_view.gd:17783`, `scripts/board_status_plates.gd:111` | CanvasItem draw_* | No shared grid | Normal | Pill pop or count change. Forecast pulse is separate. | Palette tokens or code literals | Rounded style box and icon. Defense plate has a short line. | Retained plate layout with pop/forecast updates. | PASS |
| status_stoneskin_gain | status | `scripts/combat_board_view.gd:17783`, `scripts/board_status_plates.gd:111` | CanvasItem draw_* | No shared grid | Normal | Pill pop or count change. Forecast pulse is separate. | Palette tokens or code literals | Rounded style box and icon. Defense plate has a short line. | Retained plate layout with pop/forecast updates. | PASS |
| status_stoneskin_tick | status | `scripts/combat_board_view.gd:17783`, `scripts/board_status_plates.gd:111` | CanvasItem draw_* | No shared grid | Normal | Pill pop or count change. Forecast pulse is separate. | Palette tokens or code literals | Rounded style box and icon. Defense plate has a short line. | Retained plate layout with pop/forecast updates. | PASS |
| status_frost_armor_gain | status | `scripts/combat_board_view.gd:17783`, `scripts/board_status_plates.gd:111` | CanvasItem draw_* | No shared grid | Normal | Pill pop or count change. Forecast pulse is separate. | Palette tokens or code literals | Rounded style box and icon. Defense plate has a short line. | Retained plate layout with pop/forecast updates. | PASS |
| status_frost_armor_tick | status | `scripts/combat_board_view.gd:17783`, `scripts/board_status_plates.gd:111` | CanvasItem draw_* | No shared grid | Normal | Pill pop or count change. Forecast pulse is separate. | Palette tokens or code literals | Rounded style box and icon. Defense plate has a short line. | Retained plate layout with pop/forecast updates. | PASS |
| status_charge_gain | status | `scripts/combat_board_view.gd:17783`, `scripts/board_status_plates.gd:111` | CanvasItem draw_* | No shared grid | Normal | Pill pop or count change. Forecast pulse is separate. | Palette tokens or code literals | Rounded style box and icon. Defense plate has a short line. | Retained plate layout with pop/forecast updates. | PASS |
| status_charge_tick | status | `scripts/combat_board_view.gd:17783`, `scripts/board_status_plates.gd:111` | CanvasItem draw_* | No shared grid | Normal | Pill pop or count change. Forecast pulse is separate. | Palette tokens or code literals | Rounded style box and icon. Defense plate has a short line. | Retained plate layout with pop/forecast updates. | PASS |
| status_kindled_bonus_gain | status | `scripts/combat_board_view.gd:17783`, `scripts/board_status_plates.gd:111` | CanvasItem draw_* | No shared grid | Normal | Pill pop or count change. Forecast pulse is separate. | Palette tokens or code literals | Rounded style box and icon. Defense plate has a short line. | Retained plate layout with pop/forecast updates. | PASS |
| status_kindled_bonus_tick | status | `scripts/combat_board_view.gd:17783`, `scripts/board_status_plates.gd:111` | CanvasItem draw_* | No shared grid | Normal | Pill pop or count change. Forecast pulse is separate. | Palette tokens or code literals | Rounded style box and icon. Defense plate has a short line. | Retained plate layout with pop/forecast updates. | PASS |
| status_stagger | status | `scripts/run_scene.gd:34527` | CanvasItem draw_* | No shared grid | Normal | Continuous alpha | Code literals | Stagger glyph and text | Per-entry position/alpha/typography plus screen popup placement and retained icons. | PASS |
| crystal_mantle_broken | status | `scripts/run_scene.gd:27331`, `scripts/tile_burst_fx.gd:281` | Baked contact or pixel_fx_layer grid + float | Effect cells only | Normal | Atlas/Bayer plus smooth text | vfx_pixel_style.json ramp, data/tile_bursts.json indexed palette and literal text tint | Ice fragments and label | Per-entry position/alpha/typography plus screen popup placement and retained icons. | PASS |
| status_chilled_frozen_legacy | status | `scripts/combat_board_view.gd:17870` | Legacy status fields in presentation | No active draw | Normal | No active draw | None | None | Rules no longer apply Chilled or Freeze. Current Ice applies Expose. | dormant |
| status_petrify_legacy | status | `scripts/combat_board_view.gd:9772`, `scripts/combat_board_view.gd:17783` | Legacy field in rendered unit data | No dedicated draw | Normal | No active draw | None | None | Visible-unit payload retains the field. The active plate switch has no Petrify entry. | dormant |
| status_other_popup | status | `scripts/run_scene.gd:26595` | CanvasItem draw_* | No shared grid | Normal | Continuous alpha | Code literals | Text and optional cause icon | Per-entry position/alpha/typography plus screen popup placement and retained icons. | audit-only |
| status_pending_traits | status | `scripts/combat_board_view.gd:17783`, `scripts/board_status_plates.gd:111` | CanvasItem draw_* | No shared grid | Normal | Badge pop/forecast alpha | Palette tokens or code literals | Icon, rounded plate and count | Vision, retaliate, pending Quicken/next attack, Flying, Burrow, Split and other trait badges share status plates. | audit-only |
| trap_fire | hazard | `scripts/run_scene.gd:23589`, `scripts/combat_board_view.gd:12540` | Baked contact + activation texture, or pixel_fx_layer grid | Yes for contacts. Texture marker has native sampling. | Normal | Indexed contact cells or Bayer. Sprite overlay has smooth alpha. | data/tile_bursts.json indexed palette and vfx_pixel_style.json ramp or native marker art | Element-specific burst or pressure field | Per trap, retained depth stamp or cropped pixel passes and animated marker. | PASS |
| trap_ice | hazard | `scripts/run_scene.gd:23589`, `scripts/combat_board_view.gd:12540` | Baked contact + activation texture, or pixel_fx_layer grid | Yes for contacts. Texture marker has native sampling. | Normal | Indexed contact cells or Bayer. Sprite overlay has smooth alpha. | data/tile_bursts.json indexed palette and vfx_pixel_style.json ramp or native marker art | Element-specific burst or pressure field | Per trap, retained depth stamp or cropped pixel passes and animated marker. | PASS |
| trap_earth | hazard | `scripts/run_scene.gd:23589`, `scripts/combat_board_view.gd:12540` | Baked contact + activation texture, or pixel_fx_layer grid | Yes for contacts. Texture marker has native sampling. | Normal | Indexed contact cells or Bayer. Sprite overlay has smooth alpha. | data/tile_bursts.json indexed palette and vfx_pixel_style.json ramp or native marker art | Element-specific burst or pressure field | Per trap, retained depth stamp or cropped pixel passes and animated marker. | PASS |
| trap_air | hazard | `scripts/run_scene.gd:23589`, `scripts/combat_board_view.gd:12540` | Baked contact + activation texture, or pixel_fx_layer grid | Yes for contacts. Texture marker has native sampling. | Normal | Indexed contact cells or Bayer. Sprite overlay has smooth alpha. | data/tile_bursts.json indexed palette and vfx_pixel_style.json ramp or native marker art | Element-specific burst or pressure field | Per trap, retained depth stamp or cropped pixel passes and animated marker. | PASS |
| trap_lightning | hazard | `scripts/run_scene.gd:23589`, `scripts/combat_board_view.gd:12540` | Baked contact + activation texture, or pixel_fx_layer grid | Yes for contacts. Texture marker has native sampling. | Normal | Indexed contact cells or Bayer. Sprite overlay has smooth alpha. | data/tile_bursts.json indexed palette and vfx_pixel_style.json ramp or native marker art | Element-specific burst or pressure field | Per trap, retained depth stamp or cropped pixel passes and animated marker. | PASS |
| tick_fire | hazard | `scripts/run_scene.gd:23276`, `scripts/status_tick_feedback.gd:28` | CanvasItem float + body flash, with contact FX on entry | Float and body no shared grid | Normal | Continuous alpha | Code literal tint and Fire glyph | Outlined digits and icon | Per-entry position/alpha/typography plus screen popup placement and retained icons. | PASS |
| umbra_advance | hazard | `scripts/combat_board_view.gd:6157` | CanvasItem draw_* | No shared grid | Normal | Stage alpha and animated billows | Code literals | Tile polygons, line edges and soft circle lobes | Batch circles/triangles. Per-hidden-tile and boundary work. Light can reveal or return tiles. | replay unresolved |
| umbra_tethered_light | hazard | `scripts/combat_board_view.gd:6787` | CanvasItem draw_texture* | No shared grid | Normal | Texture alpha or continuous pulse | Authored texture + code tint | Authored icon and layered light | Per authored board object or occupied tile. | audit-only |
| umbra_brazier | hazard | `scripts/combat_board_view.gd:6749` | CanvasItem draw_* | No shared grid | Normal | Texture alpha or continuous pulse | Authored texture + code tint | Marker/icon and prop flame | Per authored board object or occupied tile. | audit-only |
| trap_idle | hazard | `scripts/combat_board_view.gd:17921` | CanvasItem draw_texture* | No shared grid | Normal | Texture alpha or continuous pulse | Authored texture + code tint | Animated rune texture | Per authored board object or occupied tile. | audit-only |
| powder_keg_fuse | hazard | `scripts/combat_board_view.gd:9657` | CanvasItem draw_* | No shared grid | Normal | Texture alpha or continuous pulse | Authored texture + code tint | Soft textured glow | Per authored board object or occupied tile. | audit-only |
| death_site_embers | hazard | `scripts/combat_board_view.gd:8565` | CanvasItem draw_* | No shared grid | Normal | Texture alpha or continuous pulse | Authored texture + code tint | Ember sprites | Per authored board object or occupied tile. | audit-only |
| powder_keg_burst | hazard | `scripts/tile_burst_fx.gd:281`, `scripts/run_scene.gd:34944` | baked atlas stamp + shader or pixel_fx_layer grid + shader | Atlas or procedural cells | Normal | Authored cells and discrete frame changes or Bayer | data/tile_bursts.json indexed palette and vfx_pixel_style.json ramp | Fire burst and displacement | Up to two retained quads per eligible tile. Update frame uniform on cell-frame changes. | never observed |
| worldspine_pulse | hazard | `scripts/tile_burst_fx.gd:281`, `scripts/run_scene.gd:34944` | baked atlas stamp + shader or pixel_fx_layer grid + shader | Atlas or procedural cells | Normal | Authored cells and discrete frame changes or Bayer | data/tile_bursts.json indexed palette and vfx_pixel_style.json ramp | Earth contact and radius footprint | Up to two retained quads per eligible tile. Update frame uniform on cell-frame changes. | never observed |
| unit_death | outcome | `scripts/run_scene.gd:23022`, `scripts/combat_board_view.gd:2362` | Rig or sprite pose + CanvasItem draw_* or dissolve shader | Body fits are renderer-specific | Normal | Frame sequence, fallback fade or procedural dissolve | Authored texture + code tint | Dissolve haze/embers | Per-unit frame clocks, cutout sampling and depth order updates. | PASS |
| death_dissolve | outcome | `scripts/combat_board_view.gd:2362`, `scripts/enemy_shadow_dissolve_effect.gd:28` | Shader on retained texture Control | No shared grid | Normal | Noise threshold and edge halo | Authored texture + code tint | Expanding eroded silhouette | Reuses a prewarmed Control. Updates rect and shader uniforms. | PASS |
| destroy_crate | outcome | `scripts/run_scene.gd:23022`, `scripts/combat_board_view.gd:9629` | CanvasItem draw_* + texture frames | No shared grid | Normal | Discrete frames or smooth tint/height | Authored texture + code tint | Authored crate destruction frames | Per-destroyed-prop playback frames. Board depth and occlusion are retained. | PASS |
| destroy_box | outcome | `scripts/run_scene.gd:23022`, `scripts/combat_board_view.gd:9629` | CanvasItem draw_* + texture frames | No shared grid | Normal | Discrete frames or smooth tint/height | Authored texture + code tint | Authored box destruction frames | Per-destroyed-prop playback frames. Board depth and occlusion are retained. | PASS |
| destroy_powder_keg | outcome | `scripts/run_scene.gd:23022`, `scripts/combat_board_view.gd:9629` | CanvasItem draw_* + texture frames | No shared grid | Normal | Discrete frames or smooth tint/height | Authored texture + code tint | Keg frames plus its independent Fire Burst | Per-destroyed-prop playback frames. Board depth and occlusion are retained. | never observed |
| destroy_outcrop | outcome | `scripts/run_scene.gd:23022`, `scripts/combat_board_view.gd:9629` | CanvasItem draw_* + texture frames | No shared grid | Normal | Discrete frames or smooth tint/height | Authored texture + code tint | Procedural facets shrink and fade | Per-destroyed-prop playback frames. Board depth and occlusion are retained. | PASS |
| destroy_ice_pillar | outcome | `scripts/run_scene.gd:23022`, `scripts/combat_board_view.gd:9629` | CanvasItem draw_* + texture frames | No shared grid | Normal | Discrete frames or smooth tint/height | Authored texture + code tint | Pillar destruction texture sequence or texture fade | Per-destroyed-prop playback frames. Board depth and occlusion are retained. | never observed |
| destroy_bramble | outcome | `scripts/run_scene.gd:23022`, `scripts/combat_board_view.gd:9629` | CanvasItem draw_* + texture frames | No shared grid | Normal | Discrete frames or smooth tint/height | Authored texture + code tint | Bramble prop and expiry geometry | Per-destroyed-prop playback frames. Board depth and occlusion are retained. | never observed |
| destroy_worldspine | outcome | `scripts/run_scene.gd:23022`, `scripts/combat_board_view.gd:9629` | CanvasItem draw_* + texture frames | No shared grid | Normal | Discrete frames or smooth tint/height | Authored texture + code tint | Worldspine procedural facets shrink and fade | Per-destroyed-prop playback frames. Board depth and occlusion are retained. | never observed |
| destroy_raised_cover | outcome | `scripts/run_scene.gd:23022`, `scripts/combat_board_view.gd:9629` | CanvasItem draw_* + texture frames | No shared grid | Normal | Discrete frames or smooth tint/height | Authored texture + code tint | Destruction texture when available | Per-destroyed-prop playback frames. Board depth and occlusion are retained. | never observed |
| loot_pickup | outcome | `scripts/run_scene.gd:28451` | Tween + CanvasItem + baked acquisition stamp | Atlas uses fitted physical cells. Icon, labels and ray use screen geometry. | Normal | Discrete stamp frames and smooth icon/label alpha and scale | Loot accent, authored icon and data/acquisition_bursts.json | Ray and stroke geometry arc toward the destination | Transient icon/banner, atlas quad and destination animation. | PASS |
| block_break | outcome | `scripts/board_status_plates.gd:68`, `scripts/run_scene.gd:26716` | CanvasItem draw_* | No shared grid | Normal | Plate drops when spent. Float fades separately. | Palette tokens or code literals | Defense plate line and loss number | Block loss has a defense float and reaction. No dedicated break stamp. | PASS |
| number_damage | outcome | `scripts/combat_board_view.gd:13267`, `scripts/floating_combat_text.gd:410` | CanvasItem draw_* with retained icon textures | No shared grid | Normal | Continuous alpha | Code tint or Earth token | Outlined type, shadow and optional glyph | Per-entry position/alpha/typography plus screen popup placement and retained icons. | PASS |
| number_heal | outcome | `scripts/combat_board_view.gd:13267`, `scripts/floating_combat_text.gd:410` | CanvasItem draw_* with retained icon textures | No shared grid | Normal | Continuous alpha | Code tint or Earth token | Outlined type, shadow and optional glyph | Per-entry position/alpha/typography plus screen popup placement and retained icons. | PASS |
| number_block | outcome | `scripts/combat_board_view.gd:13267`, `scripts/floating_combat_text.gd:410` | CanvasItem draw_* with retained icon textures | No shared grid | Normal | Continuous alpha | Code tint or Earth token | Outlined type, shadow and optional glyph | Per-entry position/alpha/typography plus screen popup placement and retained icons. | PASS |
| number_stoneskin | outcome | `scripts/combat_board_view.gd:13267`, `scripts/floating_combat_text.gd:410` | CanvasItem draw_* with retained icon textures | No shared grid | Normal | Continuous alpha | Code tint or Earth token | Outlined type, shadow and optional glyph | Per-entry position/alpha/typography plus screen popup placement and retained icons. | PASS |
| number_draw | outcome | `scripts/combat_board_view.gd:13267`, `scripts/floating_combat_text.gd:410` | CanvasItem draw_* with retained icon textures | No shared grid | Normal | Continuous alpha | Code tint or Earth token | Outlined type, shadow and optional glyph | Per-entry position/alpha/typography plus screen popup placement and retained icons. | PASS |
| number_card_play | outcome | `scripts/combat_board_view.gd:13267`, `scripts/floating_combat_text.gd:410` | CanvasItem draw_* with retained icon textures | No shared grid | Normal | Continuous alpha | Code tint or Earth token | Outlined type, shadow and optional glyph | Per-entry position/alpha/typography plus screen popup placement and retained icons. | PASS |
| hit_flash | outcome | `scripts/combat_board_view.gd:10022` | Shader or second tinted texture draw | No shared grid | Normal | Contact alpha envelope | White flash profile or code tint | Body silhouette | Second texture or effect uniform for the affected unit. | PASS |
| camera_kick | outcome | `scripts/combat_board_view.gd:11009` | Tween on board offset | No shared grid | Normal | Decay and oscillation, no opacity | None | None | Shared board offset follows one merged hit tween. Roar rumble has its own trigger. | PASS |
| fatigue_float | outcome | `scripts/run_scene.gd:23244` | CanvasItem draw_* | No shared grid | Normal | Continuous alpha | Code tints | Damage text and Fatigue label | Per-entry position/alpha/typography plus screen popup placement and retained icons. | never observed |
| retaliate_reaction | outcome | `scripts/run_scene.gd:26595` | CanvasItem draw_* | No shared grid | Normal | Continuous alpha | Palette tokens or code literals | Loss float and usual hit reaction | Retaliate uses the status-damage transport and excludes the status-tick glyph. | audit-only |
| aim_tile_washes | telegraph | `scripts/combat_board_view.gd:8221` | CanvasItem draw_* or UI texture tint | No shared grid | Normal | Continuous alpha or fixed input-dependent geometry | Palette tokens or code literals | Tile washes, target outlines and action highlights | Retained tile/HUD caches update for preview, hover or relevant state. | audit-only |
| movement_path | telegraph | `scripts/combat_board_view.gd:5804` | CanvasItem draw_* or UI texture tint | No shared grid | Normal | Continuous alpha or fixed input-dependent geometry | Palette tokens or code literals | Authored path shapes, gradient contours and projected arcs | Retained tile/HUD caches update for preview, hover or relevant state. | audit-only |
| collision_forecast | telegraph | `scripts/combat_board_view.gd:10900` | CanvasItem draw_* or UI texture tint | No shared grid | Normal | Continuous alpha or fixed input-dependent geometry | Palette tokens or code literals | Filled circles, ring arc and danger icon | Retained tile/HUD caches update for preview, hover or relevant state. | audit-only |
| trajectory_forecast | telegraph | `scripts/combat_board_view.gd:12953` | CanvasItem draw_* or UI texture tint | No shared grid | Normal | Continuous alpha or fixed input-dependent geometry | Palette tokens or code literals | Sampled curve and projected arrow | Retained tile/HUD caches update for preview, hover or relevant state. | audit-only |
| blink_aim_rift | telegraph | `scripts/combat_board_view.gd:13116` | CanvasItem draw_* or UI texture tint | No shared grid | Normal | Continuous alpha or fixed input-dependent geometry | Palette tokens or code literals | Textured rift, endpoint smudge and ribbon/lines | Retained tile/HUD caches update for preview, hover or relevant state. | audit-only |
| intent_callout | telegraph | `scripts/combat_board_view.gd:5723` | CanvasItem draw_* or UI texture tint | No shared grid | Normal | Continuous alpha or fixed input-dependent geometry | Palette tokens or code literals | Intent callout text and graphic | Retained tile/HUD caches update for preview, hover or relevant state. | audit-only |
| skyfall_marks | telegraph | `scripts/combat_board_view.gd:8341` | CanvasItem draw_* or UI texture tint | No shared grid | Normal | Continuous alpha or fixed input-dependent geometry | Palette tokens or code literals | Mark badges and floor footprint | Retained tile/HUD caches update for preview, hover or relevant state. | audit-only |
| unit_focus | telegraph | `scripts/combat_board_view.gd:14678` | CanvasItem draw_* or UI texture tint | No shared grid | Normal | Continuous alpha or fixed input-dependent geometry | Palette tokens or code literals | Screen-space focus polygons and highlights | Retained tile/HUD caches update for preview, hover or relevant state. | audit-only |
| battlefield_rule_callout | telegraph | `scripts/combat_board_view.gd:6027` | CanvasItem draw_* or UI texture tint | No shared grid | Normal | Continuous alpha or fixed input-dependent geometry | Palette tokens or code literals | Tile markers and battlefield action caption | Retained tile/HUD caches update for preview, hover or relevant state. | audit-only |
| intent_halo | telegraph | `scripts/combat_board_view.gd:5706` | CanvasItem draw_* or UI texture tint | No shared grid | Normal | Continuous alpha or fixed input-dependent geometry | Palette tokens or code literals | Cached halo texture with animated alpha | Retained tile/HUD caches update for preview, hover or relevant state. | audit-only |
| health_forecast | telegraph | `scripts/combat_board_view.gd:10843` | CanvasItem draw_* or UI texture tint | No shared grid | Normal | Continuous alpha or fixed input-dependent geometry | Palette tokens or code literals | Health preview segments and damage chips | Retained tile/HUD caches update for preview, hover or relevant state. | audit-only |
| lethal_forecast | telegraph | `scripts/combat_board_view.gd:10938` | CanvasItem draw_* or UI texture tint | No shared grid | Normal | Continuous alpha or fixed input-dependent geometry | Palette tokens or code literals | Pulsed lethal icon | Retained tile/HUD caches update for preview, hover or relevant state. | audit-only |
| occlusion_fade | telegraph | `scripts/combat_board_view.gd:9134` | CanvasItem draw_* or UI texture tint | No shared grid | Normal | Continuous alpha or fixed input-dependent geometry | Palette tokens or code literals | Obstructor draw tint | Retained tile/HUD caches update for preview, hover or relevant state. | audit-only |
| lob_marks | telegraph | `scripts/enemy_mechanics/lob_view.gd:147`, `scripts/enemy_mechanics/lob_view.gd:191` | CanvasItem draw_* | No shared grid | Normal | Pulsed floor alpha and static badge | Palette tokens or code literals | Marked-tile wash and damage badge | Retained footprint lookup keyed by active lobbers. | audit-only |
| loot_idle | ambient | `scripts/combat_board_view.gd:9435` | CanvasItem draw_texture* | No shared grid | Normal | Bobbing texture and pulsing outline | Authored texture + code tint | Outlined pickup silhouette | Per-pickup texture, shadow and pulse. | audit-only |
| combat_turn_banner | telegraph | `scripts/run_scene.gd:3996` | Tween + CanvasItem | No shared grid | Normal | Fade and motion on a visible UI band | Palette tokens or code literals | Text and band | A single phase banner yields to boss or enemy action overlays. | audit-only |
| ambient_motes | ambient | `scripts/combat_atmosphere.gd:102` | CPUParticles2D | No shared grid | Normal | Particle curves and emitter envelope | Biome preset data | Textured particles across viewport | One emitter per biome. Disabled under reduced motion. | audit-only |
| ambient_film | ambient | `scripts/combat_atmosphere.gd:89` | Atmosphere shader | No shared grid | Premultiplied alpha | Continuous shader strength | Biome preset data | Screen-space haze, vignette and hurt tint | Full viewport shader plus time/board-light uniforms. | audit-only |
| unit_contact_shadow | ambient | `scripts/combat_board_view.gd:16812` | CanvasItem mesh with optional multiply contact layer | Contact layer uses pixel field alignment | Normal or multiply | Texture/silhouette opacity | Shadow tint literals | Fallback ellipse | Cached silhouette geometry, refreshed for moving actors or art changes. | audit-only |
| torch_light_motes | ambient | `scripts/combat_board_view.gd:8971` | CanvasItem draw_* | No shared grid | Normal | Smooth pulse and sprite alpha | Authored texture + code tint | Light glow and moving motes | Per torch cached mote templates and projected light. | audit-only |
| burst_steel_hit | atlas-contact | `scripts/tile_burst_fx.gd:549` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/tile_bursts.json indexed palette | None | Up to two retained quads per eligible tile. Update frame uniform on cell-frame changes. | PASS |
| burst_steel_floor | atlas-contact | `scripts/tile_burst_fx.gd:549` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/tile_bursts.json indexed palette | None | Up to two retained quads per eligible tile. Update frame uniform on cell-frame changes. | PASS |
| burst_volley_hit | atlas-contact | `scripts/tile_burst_fx.gd:549` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/tile_bursts.json indexed palette | None | Up to two retained quads per eligible tile. Update frame uniform on cell-frame changes. | never observed |
| burst_volley_floor | atlas-contact | `scripts/tile_burst_fx.gd:549` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/tile_bursts.json indexed palette | None | Up to two retained quads per eligible tile. Update frame uniform on cell-frame changes. | never observed |
| burst_shrapnel_hit | atlas-contact | `scripts/tile_burst_fx.gd:549` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/tile_bursts.json indexed palette | None | Up to two retained quads per eligible tile. Update frame uniform on cell-frame changes. | PASS |
| burst_shrapnel_floor | atlas-contact | `scripts/tile_burst_fx.gd:549` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/tile_bursts.json indexed palette | None | Up to two retained quads per eligible tile. Update frame uniform on cell-frame changes. | never observed |
| burst_impact_hit | atlas-contact | `scripts/tile_burst_fx.gd:549` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/tile_bursts.json indexed palette | None | Up to two retained quads per eligible tile. Update frame uniform on cell-frame changes. | PASS |
| burst_impact_floor | atlas-contact | `scripts/tile_burst_fx.gd:549` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/tile_bursts.json indexed palette | None | Up to two retained quads per eligible tile. Update frame uniform on cell-frame changes. | PASS |
| burst_fire_hit | atlas-contact | `scripts/tile_burst_fx.gd:549` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/tile_bursts.json indexed palette | None | Up to two retained quads per eligible tile. Update frame uniform on cell-frame changes. | PASS |
| burst_fire_floor | atlas-contact | `scripts/tile_burst_fx.gd:549` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/tile_bursts.json indexed palette | None | Up to two retained quads per eligible tile. Update frame uniform on cell-frame changes. | PASS |
| burst_ice_hit | atlas-contact | `scripts/tile_burst_fx.gd:549` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/tile_bursts.json indexed palette | None | Up to two retained quads per eligible tile. Update frame uniform on cell-frame changes. | PASS |
| burst_ice_floor | atlas-contact | `scripts/tile_burst_fx.gd:549` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/tile_bursts.json indexed palette | None | Up to two retained quads per eligible tile. Update frame uniform on cell-frame changes. | PASS |
| burst_earth_hit | atlas-contact | `scripts/tile_burst_fx.gd:549` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/tile_bursts.json indexed palette | None | Up to two retained quads per eligible tile. Update frame uniform on cell-frame changes. | PASS |
| burst_earth_floor | atlas-contact | `scripts/tile_burst_fx.gd:549` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/tile_bursts.json indexed palette | None | Up to two retained quads per eligible tile. Update frame uniform on cell-frame changes. | PASS |
| burst_air_hit | atlas-contact | `scripts/tile_burst_fx.gd:549` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/tile_bursts.json indexed palette | None | Up to two retained quads per eligible tile. Update frame uniform on cell-frame changes. | PASS |
| burst_air_floor | atlas-contact | `scripts/tile_burst_fx.gd:549` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/tile_bursts.json indexed palette | None | Up to two retained quads per eligible tile. Update frame uniform on cell-frame changes. | PASS |
| burst_lightning_hit | atlas-contact | `scripts/tile_burst_fx.gd:549` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/tile_bursts.json indexed palette | None | Up to two retained quads per eligible tile. Update frame uniform on cell-frame changes. | PASS |
| burst_lightning_floor | atlas-contact | `scripts/tile_burst_fx.gd:549` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/tile_bursts.json indexed palette | None | Up to two retained quads per eligible tile. Update frame uniform on cell-frame changes. | PASS |
| burst_light_hit | atlas-contact | `scripts/tile_burst_fx.gd:549` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/tile_bursts.json indexed palette | None | Up to two retained quads per eligible tile. Update frame uniform on cell-frame changes. | PASS |
| burst_light_floor | atlas-contact | `scripts/tile_burst_fx.gd:549` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/tile_bursts.json indexed palette | None | Up to two retained quads per eligible tile. Update frame uniform on cell-frame changes. | PASS |
| burst_shadow_hit | atlas-contact | `scripts/tile_burst_fx.gd:549` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/tile_bursts.json indexed palette | None | Up to two retained quads per eligible tile. Update frame uniform on cell-frame changes. | never observed |
| burst_shadow_floor | atlas-contact | `scripts/tile_burst_fx.gd:549` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/tile_bursts.json indexed palette | None | Up to two retained quads per eligible tile. Update frame uniform on cell-frame changes. | never observed |
| self_block | atlas-self | `scripts/tile_burst_fx.gd:528` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/self_bursts.json indexed palette | None | Two depth-ordered quads. Per-stamp lifetime and frame index sampled. | PASS |
| self_stoneskin | atlas-self | `scripts/tile_burst_fx.gd:528` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/self_bursts.json indexed palette | None | Two depth-ordered quads. Per-stamp lifetime and frame index sampled. | PASS |
| self_heal | atlas-self | `scripts/tile_burst_fx.gd:528` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/self_bursts.json indexed palette | None | Two depth-ordered quads. Per-stamp lifetime and frame index sampled. | PASS |
| self_empower | atlas-self | `scripts/tile_burst_fx.gd:528` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/self_bursts.json indexed palette | None | Two depth-ordered quads. Per-stamp lifetime and frame index sampled. | never observed |
| self_mantle | atlas-self | `scripts/tile_burst_fx.gd:528` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/self_bursts.json indexed palette | None | Two depth-ordered quads. Per-stamp lifetime and frame index sampled. | never observed |
| self_illusion | atlas-self | `scripts/tile_burst_fx.gd:528` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/self_bursts.json indexed palette | None | Two depth-ordered quads. Per-stamp lifetime and frame index sampled. | never observed |
| self_summon | atlas-self | `scripts/tile_burst_fx.gd:528` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/self_bursts.json indexed palette | None | Two depth-ordered quads. Per-stamp lifetime and frame index sampled. | PASS |
| self_expose | atlas-self | `scripts/tile_burst_fx.gd:528` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/self_bursts.json indexed palette | None | Two depth-ordered quads. Per-stamp lifetime and frame index sampled. | PASS |
| sky_lightning | atlas-sky | `scripts/tile_burst_fx.gd:542` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/strikes.json indexed palette | None | One retained sky quad per eligible tile. Clock tracks strike contact. | PASS |
| sky_meteor | atlas-sky | `scripts/tile_burst_fx.gd:542` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/strikes.json indexed palette | None | One retained sky quad per eligible tile. Clock tracks strike contact. | PASS |
| sky_ice_spear | atlas-sky | `scripts/tile_burst_fx.gd:542` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/strikes.json indexed palette | None | One retained sky quad per eligible tile. Clock tracks strike contact. | PASS |
| shot_arrow | atlas-shot | `scripts/shot_fx.gd:909` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Reusable head and depth slot. Nearest indexed texels sampled by flight/flicker frame. | never observed |
| shot_spear | atlas-shot | `scripts/shot_fx.gd:909` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Reusable head and depth slot. Nearest indexed texels sampled by flight/flicker frame. | never observed |
| shot_knife | atlas-shot | `scripts/shot_fx.gd:909` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Reusable head and depth slot. Nearest indexed texels sampled by flight/flicker frame. | never observed |
| shot_hook | atlas-shot | `scripts/shot_fx.gd:909` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Reusable head and depth slot. Nearest indexed texels sampled by flight/flicker frame. | PASS |
| shot_coin | atlas-shot | `scripts/shot_fx.gd:909` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Reusable head and depth slot. Nearest indexed texels sampled by flight/flicker frame. | never observed |
| shot_die | atlas-shot | `scripts/shot_fx.gd:909` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Reusable head and depth slot. Nearest indexed texels sampled by flight/flicker frame. | never observed |
| shot_net | atlas-shot | `scripts/shot_fx.gd:909` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Reusable head and depth slot. Nearest indexed texels sampled by flight/flicker frame. | never observed |
| shot_trap | atlas-shot | `scripts/shot_fx.gd:909` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Reusable head and depth slot. Nearest indexed texels sampled by flight/flicker frame. | never observed |
| shot_stone | atlas-shot | `scripts/shot_fx.gd:909` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Reusable head and depth slot. Nearest indexed texels sampled by flight/flicker frame. | PASS |
| shot_rock | atlas-shot | `scripts/shot_fx.gd:909` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Reusable head and depth slot. Nearest indexed texels sampled by flight/flicker frame. | PASS |
| shot_pale | atlas-shot | `scripts/shot_fx.gd:909` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Reusable head and depth slot. Nearest indexed texels sampled by flight/flicker frame. | PASS |
| shot_light | atlas-shot | `scripts/shot_fx.gd:909` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Reusable head and depth slot. Nearest indexed texels sampled by flight/flicker frame. | never observed |
| shot_sunlance | atlas-shot | `scripts/shot_fx.gd:909` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Reusable head and depth slot. Nearest indexed texels sampled by flight/flicker frame. | never observed |
| shot_lance | atlas-shot | `scripts/shot_fx.gd:909` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Reusable head and depth slot. Nearest indexed texels sampled by flight/flicker frame. | never observed |
| shot_needle | atlas-shot | `scripts/shot_fx.gd:909` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Reusable head and depth slot. Nearest indexed texels sampled by flight/flicker frame. | PASS |
| shot_blade | atlas-shot | `scripts/shot_fx.gd:909` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Reusable head and depth slot. Nearest indexed texels sampled by flight/flicker frame. | PASS |
| shot_shade | atlas-shot | `scripts/shot_fx.gd:909` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Reusable head and depth slot. Nearest indexed texels sampled by flight/flicker frame. | PASS |
| shot_dust | atlas-shot | `scripts/shot_fx.gd:909` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Reusable head and depth slot. Nearest indexed texels sampled by flight/flicker frame. | PASS |
| shot_ember | atlas-shot | `scripts/shot_fx.gd:909` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Reusable head and depth slot. Nearest indexed texels sampled by flight/flicker frame. | PASS |
| shot_spark | atlas-shot | `scripts/shot_fx.gd:909` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Reusable head and depth slot. Nearest indexed texels sampled by flight/flicker frame. | PASS |
| shot_hit_spark | atlas-shot | `scripts/shot_fx.gd:1033` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Update one of two reusable contact slots until its authored lifetime ends. | PASS |
| shot_hit_pale | atlas-shot | `scripts/shot_fx.gd:1033` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Update one of two reusable contact slots until its authored lifetime ends. | PASS |
| shot_hit_puff | atlas-shot | `scripts/shot_fx.gd:1033` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Update one of two reusable contact slots until its authored lifetime ends. | PASS |
| shot_hit_chips | atlas-shot | `scripts/shot_fx.gd:1033` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Update one of two reusable contact slots until its authored lifetime ends. | PASS |
| shot_hit_flash | atlas-shot | `scripts/shot_fx.gd:1033` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Update one of two reusable contact slots until its authored lifetime ends. | never observed |
| shot_hit_glass | atlas-shot | `scripts/shot_fx.gd:1033` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Update one of two reusable contact slots until its authored lifetime ends. | PASS |
| shot_hit_gust | atlas-shot | `scripts/shot_fx.gd:1033` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Update one of two reusable contact slots until its authored lifetime ends. | PASS |
| shot_hit_gloom | atlas-shot | `scripts/shot_fx.gd:1033` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Update one of two reusable contact slots until its authored lifetime ends. | PASS |
| hook_links | atlas-shot | `scripts/shot_fx.gd:914` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | One retained span quad. Shader indexes repeated links. | PASS |
| reflected_projectile | atlas-shot | `scripts/shot_fx.gd:865` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | Dedicated reusable return head. | never observed |
| shot_shadow | atlas-shot | `scripts/shot_fx.gd:845` | baked atlas stamp + shader | Yes, using physical cells. Sheet fit may adjust the 2 px baseline. | Normal | Authored cells and discrete frame changes | data/shots.json indexed palette | None | One reusable shadow slot with its own tint and nearest atlas sampling. | PASS |

## Hunt coverage

Volume is 738 checkpointed turn starts over 58 seeded fights and 4194 production hunt decisions. Sections reached in combat are 1, 2, 3, 4. Counts include finished ledger entries. In-game Section I corresponds to ledger section 0.

| Campaign | Seed | Fights | Turns | Decisions | Sections (1-based) | Outcome | Wall seconds | Exit |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| campaign | 8 | 6 | 174 | 758 | 1, 2 | fight_limit | 408.826 | 0 |
| campaign | 9 | 18 | 217 | 1361 | 1, 2, 3, 4 | watchdog timeout | 1200.264 | 124 |
| campaign | 10 | 17 | 206 | 1170 | 1, 2, 3 | watchdog timeout | 1200.219 | 124 |
| depth | 12 | 17 | 141 | 905 | 1, 2, 3, 4 | watchdog timeout | 720.433 | 124 |

**Observed with packaged checkpoints (123)**

| ID | Seed | Section | Room | Turn | Inputs | Runtime source |
| --- | --- | --- | --- | --- | --- | --- |
| player_melee_trail | 10 | 1 | (1, -1) | 2 | 2 | live strike mesh |
| player_melee_impact | 10 | 1 | (1, -1) | 2 | 2 | steel_hit_front |
| player_ranged_projectile | 10 | 1 | (1, -1) | 1 | 5 | fx-14 head pale |
| player_ranged_impact | 10 | 1 | (1, -1) | 1 | 5 | fx-14 hit_pale |
| player_area | 10 | 1 | (1, -1) | 3 | 4 | board area action |
| player_block | 10 | 1 | (1, -1) | 1 | 3 | block_front |
| player_move | 10 | 1 | (1, -1) | 1 | 6 | moving hero body |
| player_blink | 12 | 3 | (9, -5) | 2 | 4 | summon_front |
| enemy_ranged_projectile | 10 | 1 | (0, 1) | 6 | 5 | fx-14 head hook |
| enemy_ranged_impact | 10 | 1 | (0, 1) | 6 | 5 | fx-14 hit_spark |
| enemy_area | 10 | 1 | (2, -1) | 6 | 2 | board area action |
| enemy_block | 10 | 1 | (0, 1) | 2 | 4 | block_front |
| enemy_heal | 9 | 2 | (5, -3) | 3 | 5 | heal_front |
| enemy_move | 8 | 1 | (1, 1) | 1 | 6 | moving enemy body |
| enemy_pull | 10 | 1 | (3, -2) | 7 | 5 | board action pull |
| enemy_summon | 8 | 1 | (4, 0) | 4 | 1 | summon_front |
| light_placement | 10 | 2 | (7, -5) | 1 | 3 | rendered Light source |
| chain_bolt | 9 | 2 | (8, 0) | 3 | 4 | ChainBolt texture |
| lightning_conduction | 8 | 1 | (4, 0) | 2 | 8 | surface_conducted |
| enemy_melee_trail | 8 | 1 | (1, 1) | 1 | 6 | live strike mesh |
| enemy_claw_marks | 8 | 1 | (1, 1) | 1 | 6 | live claw marks mesh |
| enemy_melee_impact | 8 | 1 | (1, 1) | 1 | 6 | steel_hit_front |
| surgeon_jab | 10 | 3 | (11, -1) | 16 | 5 | grave surgeon jab painter |
| enemy_lob_projectile | 12 | 2 | (5, 2) | 3 | 7 | Lob ember head |
| enemy_lob_landing | 12 | 2 | (5, 2) | 3 | 7 | Lob contact presentation |
| enemy_icefall_landing | 9 | 1 | (-2, 3) | 14 | 5 | ice_spear_front |
| enemy_meteorfall | 12 | 2 | (8, 0) | 1 | 5 | meteor_front |
| enemy_erupt | 12 | 3 | (10, -5) | 2 | 7 | Burrow Grub cutout pose |
| enemy_burrow | 12 | 3 | (10, -5) | 1 | 5 | Burrow Grub cutout pose |
| enemy_outcrop_raise | 10 | 1 | (2, -1) | 3 | 7 | terrain_created |
| enemy_retreat | 9 | 1 | (0, 1) | 3 | 5 | retreat travel variant |
| enemy_split | 12 | 1 | (1, 3) | 2 | 4 | new body matching active split death |
| death_burst | 12 | 2 | (5, 2) | 2 | 5 | death Burst submission |
| surface_fire | 9 | 1 | (0, 1) | 2 | 4 | rendered surface fire |
| surface_break_fire | 12 | 2 | (8, 0) | 3 | 6 | surface_removed |
| surface_ice | 9 | 1 | (-2, 3) | 14 | 5 | rendered surface ice |
| surface_break_ice | 9 | 1 | (4, 0) | 8 | 6 | surface_removed |
| surface_electrified | 8 | 1 | (-1, 0) | 2 | 8 | rendered surface electrified |
| surface_break_electrified | 9 | 1 | (-2, 3) | 5 | 2 | surface_removed |
| surface_rubble | 10 | 1 | (2, -1) | 3 | 1 | rendered surface rubble |
| pixel_release | 8 | 1 | (4, 0) | 1 | 5 | release lightning |
| pixel_floor_light | 10 | 1 | (-2, -2) | 8 | 3 | floor_light earth |
| status_expose_gain | 10 | 1 | (-2, -2) | 3 | 5 | rendered unit status changed |
| status_expose_tick | 10 | 1 | (-2, -2) | 5 | 1 | rendered unit status changed |
| status_shock_gain | 9 | 1 | (-2, 3) | 5 | 1 | rendered unit status changed |
| status_shock_tick | 9 | 1 | (-2, 3) | 5 | 2 | rendered unit status changed |
| status_immobilize_gain | 10 | 1 | (0, 1) | 6 | 5 | rendered unit status changed |
| status_immobilize_tick | 12 | 3 | (9, -5) | 7 | 5 | rendered unit status changed |
| status_stoneskin_gain | 10 | 2 | (5, -4) | 1 | 6 | rendered unit status changed |
| status_stoneskin_tick | 10 | 1 | (3, -2) | 2 | 2 | rendered unit status changed |
| status_frost_armor_gain | 9 | 1 | (4, 0) | 1 | 5 | rendered unit status changed |
| status_frost_armor_tick | 9 | 1 | (4, 0) | 2 | 4 | rendered unit status changed |
| status_charge_gain | 9 | 2 | (5, 1) | 2 | 8 | rendered unit status changed |
| status_charge_tick | 9 | 2 | (5, 1) | 5 | 2 | rendered unit status changed |
| status_kindled_bonus_gain | 9 | 3 | (9, 0) | 2 | 6 | rendered unit status changed |
| status_kindled_bonus_tick | 9 | 3 | (9, 0) | 5 | 5 | rendered unit status changed |
| status_stagger | 10 | 1 | (-2, -2) | 5 | 4 | Stagger popup |
| crystal_mantle_broken | 9 | 1 | (4, 0) | 2 | 4 | crystal_mantle_broken |
| trap_fire | 8 | 1 | (2, 1) | 15 | 2 | live trap feedback |
| trap_ice | 9 | 1 | (4, 0) | 3 | 4 | live trap feedback |
| trap_earth | 10 | 1 | (-2, -2) | 8 | 4 | live trap feedback |
| trap_air | 9 | 1 | (0, 1) | 2 | 4 | live trap feedback |
| trap_lightning | 9 | 1 | (-2, 3) | 3 | 2 | live trap feedback |
| tick_fire | 9 | 1 | (0, 1) | 2 | 5 | surface_damage |
| unit_death | 10 | 1 | (1, -1) | 2 | 2 | death animation submission |
| death_dissolve | 12 | 1 | (1, 1) | 2 | 2 | live dissolve Control |
| destroy_crate | 10 | 1 | (0, 1) | 4 | 4 | terrain destruction submission |
| destroy_box | 10 | 1 | (0, 1) | 2 | 4 | terrain destruction submission |
| destroy_outcrop | 10 | 1 | (2, -1) | 4 | 4 | terrain destruction submission |
| loot_pickup | 10 | 1 | (1, -1) | 1 | 6 | EquipmentAcquisitionIcon |
| block_break | 10 | 1 | (2, -1) | 5 | 6 | Block depleted on hit |
| number_damage | 10 | 1 | (1, -1) | 1 | 5 | visible float damage |
| number_heal | 9 | 2 | (5, -3) | 3 | 5 | visible float heal |
| number_block | 10 | 1 | (1, -1) | 1 | 3 | visible float block |
| number_stoneskin | 10 | 1 | (3, -2) | 2 | 2 | visible float stoneskin |
| number_draw | 10 | 1 | (4, 0) | 1 | 5 | visible float draw |
| number_card_play | 8 | 1 | (4, 0) | 4 | 1 | visible float card_play |
| hit_flash | 12 | 1 | (1, 1) | 1 | 3 | combat-feel flash profile |
| camera_kick | 12 | 1 | (1, 1) | 1 | 3 | live camera tween |
| burst_steel_hit | 10 | 1 | (1, -1) | 2 | 2 | fx-12 steel_hit_front |
| burst_steel_floor | 8 | 1 | (1, 1) | 5 | 2 | fx-12 steel_floor_front |
| burst_shrapnel_hit | 9 | 4 | (13, -12) | 5 | 2 | fx-12 shrapnel_hit_front |
| burst_impact_hit | 10 | 1 | (1, -1) | 3 | 2 | fx-12 impact_hit_front |
| burst_impact_floor | 9 | 3 | (11, -9) | 2 | 5 | fx-12 impact_floor_front |
| burst_fire_hit | 9 | 1 | (0, 1) | 2 | 5 | fx-12 fire_hit_front |
| burst_fire_floor | 8 | 1 | (2, 1) | 12 | 3 | fx-12 fire_floor_front |
| burst_ice_hit | 9 | 1 | (4, 0) | 1 | 5 | fx-12 ice_hit_front |
| burst_ice_floor | 9 | 1 | (-2, 3) | 14 | 5 | fx-12 ice_floor_front |
| burst_earth_hit | 10 | 1 | (3, -2) | 1 | 5 | fx-12 earth_hit_front |
| burst_earth_floor | 10 | 1 | (2, -1) | 3 | 7 | fx-12 earth_floor_front |
| burst_air_hit | 8 | 1 | (1, 1) | 3 | 4 | fx-12 air_hit_front |
| burst_air_floor | 9 | 1 | (0, 1) | 2 | 4 | fx-12 air_floor_front |
| burst_lightning_hit | 9 | 1 | (-2, 3) | 3 | 2 | fx-12 lightning_hit_front |
| burst_lightning_floor | 8 | 1 | (-1, 0) | 2 | 8 | fx-12 lightning_floor_front |
| burst_light_hit | 10 | 1 | (1, -1) | 3 | 4 | fx-12 light_hit_front |
| burst_light_floor | 10 | 1 | (1, -1) | 3 | 4 | fx-12 light_floor_front |
| self_block | 10 | 1 | (1, -1) | 1 | 3 | fx-13 block_front |
| self_stoneskin | 10 | 2 | (5, -4) | 1 | 6 | fx-13 stoneskin_front |
| self_heal | 9 | 2 | (5, -3) | 3 | 5 | fx-13 heal_front |
| self_summon | 8 | 1 | (4, 0) | 4 | 1 | fx-13 summon_front |
| self_expose | 10 | 1 | (-2, -2) | 3 | 5 | fx-13 expose_front |
| sky_lightning | 8 | 1 | (4, 0) | 1 | 5 | fx-15 lightning_front |
| sky_meteor | 12 | 2 | (8, 0) | 1 | 5 | fx-15 meteor_front |
| sky_ice_spear | 9 | 1 | (-2, 3) | 14 | 5 | fx-15 ice_spear_front |
| shot_hook | 10 | 1 | (0, 1) | 6 | 5 | fx-14 head hook |
| shot_stone | 8 | 1 | (2, 1) | 14 | 5 | fx-14 head stone |
| shot_rock | 9 | 2 | (5, 5) | 5 | 5 | fx-14 head rock |
| shot_pale | 10 | 1 | (1, -1) | 1 | 5 | fx-14 head pale |
| shot_needle | 9 | 1 | (4, 0) | 2 | 6 | fx-14 head needle |
| shot_blade | 9 | 1 | (0, 1) | 2 | 2 | fx-14 head blade |
| shot_shade | 9 | 3 | (11, -3) | 9 | 6 | fx-14 head shade |
| shot_dust | 8 | 1 | (2, 1) | 2 | 7 | fx-14 head dust |
| shot_ember | 12 | 1 | (1, 3) | 9 | 2 | fx-14 head ember |
| shot_spark | 8 | 1 | (4, 0) | 3 | 6 | fx-14 head spark |
| shot_hit_spark | 10 | 1 | (0, 1) | 6 | 5 | fx-14 hit_spark |
| shot_hit_pale | 10 | 1 | (1, -1) | 1 | 5 | fx-14 hit_pale |
| shot_hit_puff | 8 | 1 | (2, 1) | 2 | 7 | fx-14 hit_puff |
| shot_hit_chips | 8 | 1 | (2, 1) | 14 | 5 | fx-14 hit_chips |
| shot_hit_glass | 9 | 1 | (0, 1) | 7 | 5 | fx-14 hit_glass |
| shot_hit_gust | 9 | 1 | (0, 1) | 2 | 2 | fx-14 hit_gust |
| shot_hit_gloom | 9 | 2 | (5, -3) | 3 | 5 | fx-14 hit_gloom |
| hook_links | 10 | 1 | (0, 1) | 6 | 5 | fx-14 links |
| shot_shadow | 12 | 1 | (1, 1) | 3 | 2 | fx-14 shadow |

**Observed without a packaged replay (2)**

`player_heal`, `umbra_advance`

**Never observed (45)**

`player_push`, `player_pull`, `player_summon`, `enemy_blink`, `enemy_push`, `player_burst`, `item_use`, `enemy_charge`, `enemy_grow_bramble`, `enemy_wind`, `enemy_refraction`, `enemy_banner_break`, `surface_break_rubble`, `pixel_travel`, `pixel_impact`, `pixel_ground`, `neutral_impact_decal`, `powder_keg_burst`, `worldspine_pulse`, `destroy_powder_keg`, `destroy_ice_pillar`, `destroy_bramble`, `destroy_worldspine`, `destroy_raised_cover`, `fatigue_float`, `burst_volley_hit`, `burst_volley_floor`, `burst_shrapnel_floor`, `burst_shadow_hit`, `burst_shadow_floor`, `self_empower`, `self_mantle`, `self_illusion`, `shot_arrow`, `shot_spear`, `shot_knife`, `shot_coin`, `shot_die`, `shot_net`, `shot_trap`, `shot_light`, `shot_sunlance`, `shot_lance`, `shot_hit_flash`, `reflected_projectile`.

**Audit-only (30)**

The audit-only rows have inline painters without an individually attributable activation in the sampled inputs, or cover steady state and hover outside the recorded action prefix. An independent painter hook or interaction probe would be needed to witness those paths separately.

`enemy_area_rake`, `legacy_projectile`, `status_other_popup`, `status_pending_traits`, `umbra_tethered_light`, `umbra_brazier`, `trap_idle`, `powder_keg_fuse`, `death_site_embers`, `retaliate_reaction`, `aim_tile_washes`, `movement_path`, `collision_forecast`, `trajectory_forecast`, `blink_aim_rift`, `intent_callout`, `skyfall_marks`, `unit_focus`, `battlefield_rule_callout`, `intent_halo`, `health_forecast`, `lethal_forecast`, `occlusion_fade`, `lob_marks`, `loot_idle`, `combat_turn_banner`, `ambient_motes`, `ambient_film`, `unit_contact_shadow`, `torch_light_motes`.

**Dormant (2)**

`status_chilled_frozen_legacy`, `status_petrify_legacy`.

## Replay witness

```text
FEL10 WITNESS PASS player_melee_trail campaign-seed-000010-turn-000002 inputs=2 via=live strike mesh
FEL10 WITNESS PASS player_melee_impact campaign-seed-000010-turn-000002 inputs=2 via=steel_hit_front
FEL10 WITNESS PASS player_ranged_projectile campaign-seed-000010-turn-000001 inputs=5 via=fx-14 head pale
FEL10 WITNESS PASS player_ranged_impact campaign-seed-000010-turn-000001 inputs=5 via=fx-14 hit_pale
FEL10 WITNESS PASS player_area campaign-seed-000010-turn-000003 inputs=4 via=area stamp light_hit_front
FEL10 WITNESS PASS player_block campaign-seed-000010-turn-000001 inputs=3 via=block_front
FEL10 WITNESS PASS player_move campaign-seed-000010-turn-000001 inputs=6 via=moving hero body
FEL10 WITNESS PASS player_blink depth-seed-000012-turn-000099 inputs=4 via=summon_front
FEL10 WITNESS PASS enemy_ranged_projectile campaign-seed-000010-turn-000010 inputs=5 via=fx-14 head hook
FEL10 WITNESS PASS enemy_ranged_impact campaign-seed-000010-turn-000010 inputs=5 via=fx-14 hit_spark
FEL10 WITNESS PASS enemy_area campaign-seed-000010-turn-000017 inputs=2 via=area stamp steel_floor_front
FEL10 WITNESS PASS enemy_block campaign-seed-000010-turn-000006 inputs=4 via=block_front
FEL10 WITNESS PASS enemy_heal campaign-seed-000009-turn-000051 inputs=5 via=heal_front
FEL10 WITNESS PASS enemy_move campaign-seed-000008-turn-000001 inputs=6 via=moving enemy body
FEL10 WITNESS PASS enemy_pull campaign-seed-000010-turn-000042 inputs=5 via=live Chain Reel cutout pose
FEL10 WITNESS PASS enemy_summon campaign-seed-000008-turn-000035 inputs=1 via=summon_front
FEL10 WITNESS PASS light_placement campaign-seed-000010-turn-000081 inputs=3 via=rendered Light source
FEL10 WITNESS PASS chain_bolt campaign-seed-000009-turn-000093 inputs=4 via=ChainBolt texture
FEL10 WITNESS PASS lightning_conduction campaign-seed-000008-turn-000033 inputs=8 via=surface_conducted
FEL10 WITNESS PASS enemy_melee_trail campaign-seed-000008-turn-000001 inputs=6 via=live strike mesh
FEL10 WITNESS PASS enemy_claw_marks campaign-seed-000008-turn-000001 inputs=6 via=live claw marks mesh
FEL10 WITNESS PASS enemy_melee_impact campaign-seed-000008-turn-000001 inputs=6 via=steel_hit_front
FEL10 WITNESS PASS surgeon_jab campaign-seed-000010-turn-000170 inputs=5 via=grave surgeon jab painter
FEL10 WITNESS PASS enemy_lob_projectile depth-seed-000012-turn-000047 inputs=7 via=Lob ember head
FEL10 WITNESS PASS enemy_lob_landing depth-seed-000012-turn-000047 inputs=7 via=Lob contact presentation
FEL10 WITNESS PASS enemy_icefall_landing campaign-seed-000009-turn-000026 inputs=5 via=ice_spear_front
FEL10 WITNESS PASS enemy_meteorfall depth-seed-000012-turn-000082 inputs=5 via=meteor_front
FEL10 WITNESS PASS enemy_erupt depth-seed-000012-turn-000108 inputs=7 via=Burrow Grub cutout pose
FEL10 WITNESS PASS enemy_burrow depth-seed-000012-turn-000107 inputs=5 via=Burrow Grub cutout pose
FEL10 WITNESS PASS enemy_outcrop_raise campaign-seed-000010-turn-000014 inputs=7 via=terrain_created
FEL10 WITNESS PASS enemy_retreat campaign-seed-000009-turn-000007 inputs=5 via=retreat travel variant
FEL10 WITNESS PASS enemy_split depth-seed-000012-turn-000012 inputs=4 via=new body matching active split death
FEL10 WITNESS PASS death_burst depth-seed-000012-turn-000046 inputs=5 via=death Burst submission
FEL10 WITNESS PASS surface_fire campaign-seed-000009-turn-000006 inputs=4 via=rendered surface fire
FEL10 WITNESS PASS surface_break_fire depth-seed-000012-turn-000084 inputs=6 via=surface_removed
FEL10 WITNESS PASS surface_ice campaign-seed-000009-turn-000026 inputs=5 via=rendered surface ice
FEL10 WITNESS PASS surface_break_ice campaign-seed-000009-turn-000035 inputs=6 via=surface_removed
FEL10 WITNESS PASS surface_electrified campaign-seed-000008-turn-000007 inputs=8 via=rendered surface electrified
FEL10 WITNESS PASS surface_break_electrified campaign-seed-000009-turn-000017 inputs=2 via=surface_removed
FEL10 WITNESS PASS surface_rubble campaign-seed-000010-turn-000014 inputs=1 via=rendered surface rubble
FEL10 WITNESS PASS pixel_release campaign-seed-000008-turn-000032 inputs=5 via=release lightning
FEL10 WITNESS PASS pixel_floor_light campaign-seed-000010-turn-000035 inputs=3 via=floor_light earth
FEL10 WITNESS PASS status_expose_gain campaign-seed-000010-turn-000030 inputs=5 via=rendered unit status changed
FEL10 WITNESS PASS status_expose_tick campaign-seed-000010-turn-000032 inputs=1 via=rendered unit status changed
FEL10 WITNESS PASS status_shock_gain campaign-seed-000009-turn-000017 inputs=1 via=rendered unit status changed
FEL10 WITNESS PASS status_shock_tick campaign-seed-000009-turn-000017 inputs=2 via=rendered unit status changed
FEL10 WITNESS PASS status_immobilize_gain campaign-seed-000010-turn-000010 inputs=5 via=rendered unit status changed
FEL10 WITNESS PASS status_immobilize_tick depth-seed-000012-turn-000104 inputs=5 via=rendered unit status changed
FEL10 WITNESS PASS status_stoneskin_gain campaign-seed-000010-turn-000072 inputs=6 via=rendered unit status changed
FEL10 WITNESS PASS status_stoneskin_tick campaign-seed-000010-turn-000037 inputs=2 via=rendered unit status changed
FEL10 WITNESS PASS status_frost_armor_gain campaign-seed-000009-turn-000028 inputs=5 via=rendered unit status changed
FEL10 WITNESS PASS status_frost_armor_tick campaign-seed-000009-turn-000029 inputs=4 via=rendered unit status changed
FEL10 WITNESS PASS status_charge_gain campaign-seed-000009-turn-000057 inputs=8 via=rendered unit status changed
FEL10 WITNESS PASS status_charge_tick campaign-seed-000009-turn-000060 inputs=2 via=rendered unit status changed
FEL10 WITNESS PASS status_kindled_bonus_gain campaign-seed-000009-turn-000127 inputs=6 via=rendered unit status changed
FEL10 WITNESS PASS status_kindled_bonus_tick campaign-seed-000009-turn-000130 inputs=5 via=rendered unit status changed
FEL10 WITNESS PASS status_stagger campaign-seed-000010-turn-000032 inputs=4 via=Stagger popup
FEL10 WITNESS PASS crystal_mantle_broken campaign-seed-000009-turn-000029 inputs=4 via=crystal_mantle_broken
FEL10 WITNESS PASS trap_fire campaign-seed-000008-turn-000030 inputs=2 via=live trap feedback
FEL10 WITNESS PASS trap_ice campaign-seed-000009-turn-000030 inputs=4 via=live trap feedback
FEL10 WITNESS PASS trap_earth campaign-seed-000010-turn-000035 inputs=4 via=live trap feedback
FEL10 WITNESS PASS trap_air campaign-seed-000009-turn-000006 inputs=4 via=live trap feedback
FEL10 WITNESS PASS trap_lightning campaign-seed-000009-turn-000015 inputs=2 via=live trap feedback
FEL10 WITNESS PASS tick_fire campaign-seed-000009-turn-000006 inputs=5 via=surface_damage
FEL10 WITNESS PASS unit_death campaign-seed-000010-turn-000002 inputs=2 via=death animation submission
FEL10 WITNESS PASS death_dissolve depth-seed-000012-turn-000002 inputs=2 via=live dissolve Control
FEL10 WITNESS PASS destroy_crate campaign-seed-000010-turn-000008 inputs=4 via=terrain destruction submission
FEL10 WITNESS PASS destroy_box campaign-seed-000010-turn-000006 inputs=4 via=terrain destruction submission
FEL10 WITNESS PASS destroy_outcrop campaign-seed-000010-turn-000015 inputs=4 via=terrain destruction submission
FEL10 WITNESS PASS loot_pickup campaign-seed-000010-turn-000001 inputs=6 via=EquipmentAcquisitionIcon
FEL10 WITNESS PASS block_break campaign-seed-000010-turn-000016 inputs=6 via=Block depleted on hit
FEL10 WITNESS PASS number_damage campaign-seed-000010-turn-000001 inputs=5 via=visible float damage
FEL10 WITNESS PASS number_heal campaign-seed-000009-turn-000051 inputs=5 via=visible float heal
FEL10 WITNESS PASS number_block campaign-seed-000010-turn-000001 inputs=3 via=visible float block
FEL10 WITNESS PASS number_stoneskin campaign-seed-000010-turn-000037 inputs=2 via=visible float stoneskin
FEL10 WITNESS PASS number_draw campaign-seed-000010-turn-000046 inputs=5 via=visible float draw
FEL10 WITNESS PASS number_card_play campaign-seed-000008-turn-000035 inputs=1 via=visible float card_play
FEL10 WITNESS PASS hit_flash depth-seed-000012-turn-000001 inputs=3 via=combat-feel flash profile
FEL10 WITNESS PASS camera_kick depth-seed-000012-turn-000001 inputs=3 via=live camera tween
FEL10 WITNESS PASS burst_steel_hit campaign-seed-000010-turn-000002 inputs=2 via=fx-12 steel_hit_front
FEL10 WITNESS PASS burst_steel_floor campaign-seed-000008-turn-000005 inputs=2 via=fx-12 steel_floor_front
FEL10 WITNESS PASS burst_shrapnel_hit campaign-seed-000009-turn-000197 inputs=2 via=fx-12 shrapnel_hit_front
FEL10 WITNESS PASS burst_impact_hit campaign-seed-000010-turn-000003 inputs=2 via=fx-12 impact_hit_front
FEL10 WITNESS PASS burst_impact_floor campaign-seed-000009-turn-000134 inputs=5 via=fx-12 impact_floor_front
FEL10 WITNESS PASS burst_fire_hit campaign-seed-000009-turn-000006 inputs=5 via=fx-12 fire_hit_front
FEL10 WITNESS PASS burst_fire_floor campaign-seed-000008-turn-000027 inputs=3 via=fx-12 fire_floor_front
FEL10 WITNESS PASS burst_ice_hit campaign-seed-000009-turn-000028 inputs=5 via=fx-12 ice_hit_front
FEL10 WITNESS PASS burst_ice_floor campaign-seed-000009-turn-000026 inputs=5 via=fx-12 ice_floor_front
FEL10 WITNESS PASS burst_earth_hit campaign-seed-000010-turn-000036 inputs=5 via=fx-12 earth_hit_front
FEL10 WITNESS PASS burst_earth_floor campaign-seed-000010-turn-000014 inputs=7 via=fx-12 earth_floor_front
FEL10 WITNESS PASS burst_air_hit campaign-seed-000008-turn-000003 inputs=4 via=fx-12 air_hit_front
FEL10 WITNESS PASS burst_air_floor campaign-seed-000009-turn-000006 inputs=4 via=fx-12 air_floor_front
FEL10 WITNESS PASS burst_lightning_hit campaign-seed-000009-turn-000015 inputs=2 via=fx-12 lightning_hit_front
FEL10 WITNESS PASS burst_lightning_floor campaign-seed-000008-turn-000007 inputs=8 via=fx-12 lightning_floor_front
FEL10 WITNESS PASS burst_light_hit campaign-seed-000010-turn-000003 inputs=4 via=fx-12 light_hit_front
FEL10 WITNESS PASS burst_light_floor campaign-seed-000010-turn-000003 inputs=4 via=fx-12 light_floor_front
FEL10 WITNESS PASS self_block campaign-seed-000010-turn-000001 inputs=3 via=fx-13 block_front
FEL10 WITNESS PASS self_stoneskin campaign-seed-000010-turn-000072 inputs=6 via=fx-13 stoneskin_front
FEL10 WITNESS PASS self_heal campaign-seed-000009-turn-000051 inputs=5 via=fx-13 heal_front
FEL10 WITNESS PASS self_summon campaign-seed-000008-turn-000035 inputs=1 via=fx-13 summon_front
FEL10 WITNESS PASS self_expose campaign-seed-000010-turn-000030 inputs=5 via=fx-13 expose_front
FEL10 WITNESS PASS sky_lightning campaign-seed-000008-turn-000032 inputs=5 via=fx-15 lightning_front
FEL10 WITNESS PASS sky_meteor depth-seed-000012-turn-000082 inputs=5 via=fx-15 meteor_front
FEL10 WITNESS PASS sky_ice_spear campaign-seed-000009-turn-000026 inputs=5 via=fx-15 ice_spear_front
FEL10 WITNESS PASS shot_hook campaign-seed-000010-turn-000010 inputs=5 via=fx-14 head hook
FEL10 WITNESS PASS shot_stone campaign-seed-000008-turn-000029 inputs=5 via=fx-14 head stone
FEL10 WITNESS PASS shot_rock campaign-seed-000009-turn-000070 inputs=5 via=fx-14 head rock
FEL10 WITNESS PASS shot_pale campaign-seed-000010-turn-000001 inputs=5 via=fx-14 head pale
FEL10 WITNESS PASS shot_needle campaign-seed-000009-turn-000029 inputs=6 via=fx-14 head needle
FEL10 WITNESS PASS shot_blade campaign-seed-000009-turn-000006 inputs=2 via=fx-14 head blade
FEL10 WITNESS PASS shot_shade campaign-seed-000009-turn-000161 inputs=6 via=fx-14 head shade
FEL10 WITNESS PASS shot_dust campaign-seed-000008-turn-000017 inputs=7 via=fx-14 head dust
FEL10 WITNESS PASS shot_ember depth-seed-000012-turn-000019 inputs=2 via=fx-14 head ember
FEL10 WITNESS PASS shot_spark campaign-seed-000008-turn-000034 inputs=6 via=fx-14 head spark
FEL10 WITNESS PASS shot_hit_spark campaign-seed-000010-turn-000010 inputs=5 via=fx-14 hit_spark
FEL10 WITNESS PASS shot_hit_pale campaign-seed-000010-turn-000001 inputs=5 via=fx-14 hit_pale
FEL10 WITNESS PASS shot_hit_puff campaign-seed-000008-turn-000017 inputs=7 via=fx-14 hit_puff
FEL10 WITNESS PASS shot_hit_chips campaign-seed-000008-turn-000029 inputs=5 via=fx-14 hit_chips
FEL10 WITNESS PASS shot_hit_glass campaign-seed-000009-turn-000011 inputs=5 via=fx-14 hit_glass
FEL10 WITNESS PASS shot_hit_gust campaign-seed-000009-turn-000006 inputs=2 via=fx-14 hit_gust
FEL10 WITNESS PASS shot_hit_gloom campaign-seed-000009-turn-000051 inputs=5 via=fx-14 hit_gloom
FEL10 WITNESS PASS hook_links campaign-seed-000010-turn-000010 inputs=5 via=fx-14 links
FEL10 WITNESS PASS shot_shadow depth-seed-000012-turn-000003 inputs=2 via=fx-14 shadow
```

Earlier candidates below remain in their raw hunt directories. Their recorded input prefix did not reproduce the effect on Continue, so the bundle uses the next eligible observation when available.

```text
FEL10 WITNESS FAIL player_heal campaign-seed-000009-turn-000074 effect or strip missing after 5 inputs
FEL10 WITNESS FAIL status_immobilize_tick campaign-seed-000010-turn-000011 effect or strip missing after 2 inputs
FEL10 WITNESS FAIL umbra_advance campaign-seed-000010-turn-000004 effect or strip missing after 2 inputs
FEL10 WITNESS FAIL player_heal campaign-seed-000010-turn-000080 effect or strip missing after 5 inputs
FEL10 WITNESS FAIL umbra_advance campaign-seed-000008-turn-000005 effect or strip missing after 2 inputs
FEL10 WITNESS FAIL umbra_advance campaign-seed-000009-turn-000004 effect or strip missing after 2 inputs
FEL10 WITNESS FAIL player_heal depth-seed-000012-turn-000038 effect or strip missing after 5 inputs
FEL10 WITNESS FAIL umbra_advance depth-seed-000012-turn-000005 effect or strip missing after 2 inputs
```

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-10 && tools/fel10/native.sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-10 && tools/fel10/native.sh --only player_melee_trail,player_block
```

Native output is written under `tools/fel10/captures/native.*/`. Open `index.md` for family sheets, full-size strips, the 25-frame sequences and the full-frame peaks. Windowed proof is pending.
## Checks and artifacts

- The headless inventory probe exited 0 with `FEL10 INVENTORY PASS rows=202 runtime=170 audit_only=30 dormant=2`. [Inventory log](.local/inventory-final-v2.log)
- The primary three-seed hunt lasted 1,200.268 wall seconds. The seed 12 follow-up ran alongside the primary hunt and used a 720-second watchdog. The runner returned 124 for the three runs capped by their watchdogs and 0 for seed 8 at its fight limit. The coverage table counts completed turn records through each cutoff. [Primary campaign](.local/campaign/report.md) · [Follow-up](.local/depth/report.md)
- The bounded hunt smoke run returned `FEL10 HUNT seed=12 turns=10 effects=31` and `RUN HUNT: seed=12 outcome=replay_point decisions=65`. [Hunt smoke log](.local/hunt-final-smoke.log)
- The headless capture command exited 0 with `FEL10 DRY RUN PASS strips=122`. The additional Chain Reel check exited 0 with `FEL10 DRY RUN PASS strips=1`. Every packaged effect has a PASS line and a 25-frame strip plan. Both runs emitted Godot shutdown leak diagnostics. The reports remain available in the logs. [Bulk dry run](.local/replay-final.log) · [Chain Reel dry run](.local/replay-reel.log)
- The packaged inputs and save bytes match the replayed fixtures. `FEL10 BUNDLE PASS effects=123 checkpoints=65`. [Replay manifest](fixtures/manifest.json)
- The rules-text lint returned `Ran 3 tests in 0.071s`, `OK` and `PASS: Rules text lint (16 existing hits)`. The resource audit returned `ISOLATION AUDIT: 59 modules`. Bash syntax, the proof-contract JSON and whitespace checks passed. [Rules-text log](.local/rules-text.log) · [Resource audit](.local/python-audit/isolation-audit.md)

Godot emitted the macOS certificate diagnostic `ERROR: Condition "ret != noErr" is true. Returning: ""` at startup. Native captures and the renderer proof manifest are pending macOS window-server access.

## Chosen defaults

- Primary seeds 8–10 ran concurrently at 120 fixed FPS, fastest combat pacing and the inherited ×8 hunt time scale, with the stock 9,999 Health override. Seed 12 used legal hunt offers with a 0.65 revisit cost and a 0.5 distance term when no enemy was visible. The follow-up entered fights directly and skipped incoming-loss forecasting at diagnostic Health.
- Replay uses fel-03's presentation clock, an eight-frame input settle, a 10-second readiness limit, a 60-second action limit, 90 native warm-up frames and a 1,800-second runner watchdog. SubViewport input places the virtual pointer outside the board.
- The first native run used fixed crops and sampled the peak on a 60 × 45 grid. The director feedback revision below supersedes those settings.
- Individual strips use fel-03's five-column arrangement with a 28 px header and 20 px label. Verified family sheets place 192 × 144 previews in each effect row. The index links to the 960 × 720 crops and full-frame peak.

## Open issues

- `player_heal` and `umbra_advance` were observed during the hunt. The kept early observations and tested alternatives failed to reproduce those IDs from their recorded prefixes through Continue. Their original checkpoint files remain in the raw hunt directories.
- The initial detector assigned the shared summon stamp to some hero Blink events. The current hero summon detector requires the dedicated Illusion row. Those initial Blink observations were excluded from the summon count.
- Sections V and VI were outside the coverage reached before the hunt cutoffs. The report lists every never-observed, audit-only and dormant ID.
- No `TODO_DESIGN` placeholders were needed.

## Director feedback 1 capture revision

The old `native.qHgQya` Light strip captured movement. The capture observer now tracks a newly placed Light source by its committed ID and requires the foreground painter to carry that source at the same position. When the first archived checkpoint has no matching Light draw or the draw is still active at its replay limit, the next eligible checkpoint uses Flash Powder and follows the recorded fight inputs through the reward boundary. The focused dry run recorded 540 active frames, sampled 25 at a mean stride of 22.46 frames, and fitted a 724 × 543 crop at 1.326× nearest-neighbour scale. The crate replay recorded all 13 destruction frames and used the actual destruction texture’s destination rectangle. Both rects were fully covered in the focused dry run. [Named cases](.local/feedback-named-v2.log)

The capture uses one physical draw instance per effect. Its union of frame bounds determines the smallest in-viewport 4:3 crop at or above 480 × 360. Each sampled frame exports at 960 × 720. The native proof scores every active frame using exact changed pixels inside that frame’s effect bounds, measured against the same crop before onset. The peak keeps the complete 1920 × 1080 frame. Verification also counts every pixel in the peak crop against that baseline to apply the 0.5% threshold. The minimum coverage is checked over the complete observed lifetime. When the draw is still active at the end of the available replay, the lifetime check fails.

The native index gives the selected attempt’s verification result and other recorded draw IDs with overlapping rectangles. Aliases pointing to the same draw are excluded. Verified strips populate the normal family sheets. The Unverified sheet lists failed effects and shows their retained diagnostic frames where available. `capture-evidence.json` records the selected checkpoint, first rectangle, crop, coverage, frame counts, pixel fraction and retry verdict. The next known retained turn is available for 106 effects. The absence of a later archived candidate is explicit in the failure result.

Headless capture proof checks renderer submissions, geometry and lifetime. It leaves the RGB threshold pending for the native renderer. The framebuffer spool, crop sizing, even sampling, overlap, threshold checks and exact peak choice passed a headless test with controlled input frames. `FEL10 CAPTURE CHECKS PASS crop lifetime stride spool peak cooccurrence thresholds`. The historical witness mode also returned `FEL10 WITNESS PASS strips=2` for the two named primary cases. [Capture checks](.local/feedback-final-checks.log) · [Witness check](.local/feedback-witness.log)

The capture waits 120 additional frames after archived inputs have settled. Even sampling rounds to the nearest frame and always keeps both endpoints. Framebuffers are spooled losslessly per checkpoint and removed after scoring. No design placeholders were needed.

Run the native revision with window-server access.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-10 && tools/fel10/native.sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-10 && tools/fel10/native.sh --only light_placement,destroy_crate
```

Each command creates a fresh `tools/fel10/captures/native.*/` directory containing `index.md`, `capture-evidence.json` and `visual-proof.json`. This round leaves the windowed capture to the director.

### Director feedback 1 dry-run proof

`tools/fel10/native.sh --dry-run` exited 0. Both lines are from the complete 123-effect run. [Dry-run log](.local/feedback-proof.log)

```text
FEL10 DRY STRUCTURE ready_for_pixel_check=100
FEL10 DRY RUN PASS strips=123 verified=0 unverified=123
```

Light’s first replay ran out of recorded inputs while the draw remained active. The retry at `depth-seed-000012-turn-000052` followed 540 frames and fit a 728 × 546 crop with full coverage. The crate produced 13 frames with full coverage at `campaign-seed-000010-turn-000008`. The runner emitted its macOS certificate diagnostic and Godot reported dummy-renderer resource leaks at exit.

#### Unverified

- Effect signal had no matching drawn rectangle (no later checkpoint retained) (4). `surgeon_jab`, `surface_break_fire`, `status_immobilize_tick`, `status_charge_tick`.
- Effect signal had no matching drawn rectangle (14). `enemy_outcrop_raise`, `surface_break_ice`, `surface_break_electrified`, `status_expose_tick`, `status_shock_tick`, `status_stoneskin_gain`, `status_frost_armor_gain`, `status_frost_armor_tick`, `status_charge_gain`, `status_kindled_bonus_gain`, `status_kindled_bonus_tick`, `crystal_mantle_broken`, `destroy_outcrop`, `block_break`.
- Draw path present in 1 captured frame(s), minimum 3 (no later checkpoint retained) (1). `enemy_split`.
- Draw lifetime still active at the replay limit (3). `surface_fire`, `surface_ice`, `surface_electrified`.
- Draw path present in 1 captured frame(s), minimum 3 (1). `status_stoneskin_tick`.
- Pixel check pending native rendering (100). `player_melee_trail`, `player_melee_impact`, `player_ranged_projectile`, `player_ranged_impact`, `player_area`, `player_block`, `player_move`, `player_blink`, `enemy_ranged_projectile`, `enemy_ranged_impact`, `enemy_area`, `enemy_block`, `enemy_heal`, `enemy_move`, `enemy_pull`, `enemy_summon`, `light_placement`, `chain_bolt`, `lightning_conduction`, `enemy_melee_trail`, `enemy_claw_marks`, `enemy_melee_impact`, `enemy_lob_projectile`, `enemy_lob_landing`, `enemy_icefall_landing`, `enemy_meteorfall`, `enemy_erupt`, `enemy_burrow`, `enemy_retreat`, `death_burst`, `surface_rubble`, `pixel_release`, `pixel_floor_light`, `status_expose_gain`, `status_shock_gain`, `status_immobilize_gain`, `status_stagger`, `trap_fire`, `trap_ice`, `trap_earth`, `trap_air`, `trap_lightning`, `tick_fire`, `unit_death`, `death_dissolve`, `destroy_crate`, `destroy_box`, `loot_pickup`, `number_damage`, `number_heal`, `number_block`, `number_stoneskin`, `number_draw`, `number_card_play`, `hit_flash`, `camera_kick`, `burst_steel_hit`, `burst_steel_floor`, `burst_shrapnel_hit`, `burst_impact_hit`, `burst_impact_floor`, `burst_fire_hit`, `burst_fire_floor`, `burst_ice_hit`, `burst_ice_floor`, `burst_earth_hit`, `burst_earth_floor`, `burst_air_hit`, `burst_air_floor`, `burst_lightning_hit`, `burst_lightning_floor`, `burst_light_hit`, `burst_light_floor`, `self_block`, `self_stoneskin`, `self_heal`, `self_summon`, `self_expose`, `sky_lightning`, `sky_meteor`, `sky_ice_spear`, `shot_hook`, `shot_stone`, `shot_rock`, `shot_pale`, `shot_needle`, `shot_blade`, `shot_shade`, `shot_dust`, `shot_ember`, `shot_spark`, `shot_hit_spark`, `shot_hit_pale`, `shot_hit_puff`, `shot_hit_chips`, `shot_hit_glass`, `shot_hit_gust`, `shot_hit_gloom`, `hook_links`, `shot_shadow`.

## Round 2

### Pickup flight

`RunScene._animate_loadout_acquisition_ray` replaces the combat pickup's stretched beam with opaque 2 × 2 screen cells on even coordinates. The trail starts at the icon centre and is capped at the lesser of 56 screen pixels and the distance already travelled. The first third is 4 px wide and uses `accent.lightened(0.55)`. The remaining two thirds form a 2 px body in `accent`. A 4 × 4 Bayer threshold samples coverage from 1 to 0. The icon follows the original 0.42 s cubic ease-out and separate scale tween to 0.42. The motes and button pulse retain their original scheduling.

The trail retracts for 0.10 s as the icon arrives. A hand destination has no button pulse, so the icon stays at its original destination for the rest of the retraction. This adds up to 0.06 s to the arrived hand icon's hold. Reduced motion takes the existing stationary receipt path. The learned-magic reward call without a flying icon still uses its existing beam. The treasure relic flourish is byte-identical.

### Neutral impact decal

`CombatBoardView._draw_impact_decal` now draws nothing in its fallback branch. Removed `_draw_neutral_impact_decal`, `_draw_impact_ellipse`, `_draw_impact_ellipse_outline`, `_impact_ellipse_points`, and `_draw_impact_radial_marks`. No other production caller uses any of the five. Fire, Ice, Lightning, Air, and Earth keep their calls to `ElementalSpellFx.ground`. The atlas routing, impact records, and feedback tail retain their original code.

`RunScene._impact_decals_for_effect` accepts `melee`, `ranged`, `aoe`, `push`, `pull`, and `lightning_strikes`. It takes `effect.element`, then `effect._card_element`, then `none`. Any value outside the five matched elements reaches the fallback if the decal reaches the painter. That includes `none`, `shadow`, and empty or unrecognised values. Production constructors give `lightning_strikes` the Lightning element, so that kind uses the elemental branch. Covered contacts, baked strikes, and hidden tiles may bypass the fallback before it is called.

### Native proof

Run the comparison with window-server access:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-10 && tools/fel10/fix_native.sh
```

The probe copies the clean sibling release checkout into the output directory, then replays the six recorded inputs from `campaign-seed-000010-turn-000001` after Continue on each version. It records the release SHA and removes the temporary copy. The dry run used release `10d7a857468e7b43335220dd91c63df82af58fad`.

The windowed run writes a fresh `tools/fel10/captures/fix-native.*/` directory. Open `release/loot_pickup-strip-2x.png` and `branch/loot_pickup-strip-2x.png` for the 12-frame strips. `halfway-before-after.png` places release on the left and branch on the right, using the same path crop and each take's closest frame to halfway. `branch/loot_pickup-trail-4x.png` shows the last recorded full-length trail. `movie/loot_pickup.mp4` records the branch at 1920 × 1080 and a fixed 30 FPS from burst through both arrival pulses. The strips and detail crop use nearest-neighbour scaling. All native outputs use 100% UI scale and the full cel look.

### Headless proof

`tools/fel10/fix_native.sh --dry-run` returned the following. The movie line describes the observed 30 Hz event window in the headless replay. The separate exporter check used synthetic framebuffer data. [Dry-run log](.local/round2-proof.log) · [Export check](.local/round2-export.log)

```text
FEL10 FIX DRY PASS side=release inputs=6 flight_frames=25 strip_frames=12 midpoint=0.485
FEL10 FIX DRY PASS side=branch inputs=6 flight_frames=25 strip_frames=12 midpoint=0.485
FEL10 FIX REDUCED PASS inputs=6 receipt=yes flight=no trail=no
FEL10 FIX MOVIE DRY PASS inputs=6 frames=41 fps=30 size=1920x1080 burst=yes arrival=yes
FEL10 FIX DRY RUN PASS sides=2 strip_frames_each=12 midpoint_pair=planned trail_crop=4x movie=1920x1080@30
FEL10 FIX EXPORT PASS strips=2 frames_each=12 midpoint_pair=yes trail_crop=4x rgb_frames=2
FEL10 FIX HAND PASS scale=0.42 retract_frames=7 fps=60 beam=no
```

The branch still and movie checks returned the same lines after the final tween lifecycle change. The legacy pickup replay returned `FEL10 WITNESS PASS strips=1`. UI identity lint returned `Ran 25 tests in 4.706s` and `OK`. Rules text lint returned `Ran 3 tests in 0.085s`, `OK`, and `PASS: Rules text lint (16 existing hits)`. The Godot processes emitted the macOS certificate startup diagnostic. [Final branch stills](.local/round2-final-branch.log) · [Final branch movie](.local/round2-final-movie.log) · [Hand retraction](.local/round2-hand-final.log) · [Census witness](.local/round2-witness.log) · [UI lint](.local/round2-ui-lint.log) · [Rules text lint](.local/round2-rules-lint.log)

### Scope and open proof

Production changes are limited to `scripts/run_scene.gd` and `scripts/combat_board_view.gd`. The new proof is `tools/fel10/fix_native.sh` and `tools/fel10/pickup_fix/`. Existing census files and tests retain their prior source. The historical inventory generator still resolves the removed neutral painter by symbol, so regenerating that inventory on this revision would require updating its anchor. Older pickup probes still assert the former beam node in combat. The round-specific probe checks the actual icon flight and trail lifecycle.

Proof-only defaults are 60 Hz for still capture, evenly spaced source frames and the closest frame to half distance, a 4 px detail margin, 90 native warm-up frames, and 10 s readiness / 20 s action windows. No `TODO_DESIGN` was needed. Native pixel inspection and movie export remain pending window-server access.

## Round 3

`LoadoutAcquisitionTrail` publishes `acquisition_destination`, `acquisition_target_global`, and `acquisition_source_global`. The float metadata `acquisition_progress` starts at 0 and tracks the icon's already-eased position projected onto the flight path, clamped to 0–1. The pickup probe uses the source and target to check the icon's position in flight, waits for the icon to reach the recorded destination, and keeps the controller onscreen and hand-slot assertions. The reduced-motion probe checks for both the beam and the trail. The loadout probe expects the trail for the equipment flight and the beam for learned magic.

The pickup and loadout probes retain their PNG assertions for windowed runs. The headless runs exercise the presentation and layout assertions, with the pickup probe supplying the same dummy-renderer boundary used by the dragon reward probe. The event suite ran through its existing focused entry point, `tests/event_view_test.gd`. The treasure and dragon reward check sources retain their existing relic assertions.

The census retains the historical `neutral_impact_decal` ID with evidence `removed` and anchors it to `_draw_impact_decal`, where the neutral fallback draws nothing. It generated all 202 rows, including 169 runtime rows. [Generated inventory](.local/round3/inventory.md) · [Inventory validator](.local/round3-inventory.log)

### Headless checks

```text
TEST RESULT: PASS
Event view fit: 332 pages, 45 events × fresh/rich states
Event view suite: 0 failures
TREASURE PRESENTATION PROBE: PASS
DRAGON REWARD FEEDBACK PROOF: PASS
FEL10 INVENTORY PASS rows=202 runtime=169 audit_only=30 dormant=2
```

The first line is the loadout acquisition probe. Godot emitted the macOS certificate startup diagnostic. The event and treasure probes also emitted their source-image import warnings. [Loadout](.local/round3-loadout_acquisition_probe.log) · [Event suite](.local/round3-event_view_test.log) · [Treasure](.local/round3-treasure_presentation_probe.log) · [Dragon reward](.local/round3-dragon_reward_feedback_probe.log)

The desktop and Steam Deck pickup probes both printed `ITEM PICKUP PROBE: FAIL` and exited 1. Each printed `ERROR: Controller inspection keeps the selected pickup identity` five times. Those were their only assertion failures. All trail, destination, arrival, hand-slot, and reduced-motion checks completed without an assertion failure. [Desktop pickup](.local/round3-final-item_pickup_probe.log) · [Steam Deck pickup](.local/round3-final-item_pickup_deck_probe.log)

The same desktop probe on isolated `master` at `4c1547f19` produced the same five controller identity failures and `ITEM PICKUP PROBE: FAIL`. That copy added only the headless frame signal and skipped PNG readback. Master and the branch both give the cursor a `tile-effects:` key for the rich pickup tooltip, while the existing assertion compares it directly with the raw pickup key. The assertion remains in the gate. [Master baseline](.local/round3-item-master-final.log)
