# FX-32 baked force and Earth travel

## Baseline inventory

Audited the card actions in `data/cards.json` (including equipment and skill cards and upgrade variants), the enemy actions in `data/enemies.json`, the shot override tables, and the player/enemy presentation dispatch at `0d3ccfd26`. The table gives catalog ranges in Manhattan tiles. Upgrades and relics can modify those values while retaining the action type. A force action with range above 1 can still resolve at distance 1. The hero presents targeted push/pull as `kind=ranged`; Chain Reel uses `kind=pull` and supplies no hero `force_tiles` wash. The force wash visits the forced-movement tiles when the displacement path is nonempty.

| Authored action | Action | Element | Range and affected distance | Baseline travel and wash |
| --- | --- | --- | --- | --- |
| `lodestone_reversal` | Pull | Lightning | 2, distance 1–2 | Bezier, line trail and legacy projectile sprite throughout the fallback. Wash on the displacement path. |
| `cold_shoulder` | Push | Ice | 1 | Bezier, line trail and legacy projectile sprite. Wash on the displacement path. |
| `rooted_kick` | Push | Earth | 1 after the move | Same fallback and wash. |
| `hurricane_palm`, `kestrel_dive` | Push | Air | 1, after the move for Kestrel Dive | Same fallback and wash. |
| `kite_bash`, `spur_vault`, `hobnail_drive`, `haft_shove`, `shield_charge`, `unhorse`, `joust` | Push | None | 1 | Same fallback and wash. |
| `gust_step` | Pull | Air | 2 after the move | At 1, fallback arc/trail/sprite. At 2, Hook. Wash on the displacement path. |
| `vacuum_line`, `lash` | Pull | Air | 3 | At 1, fallback arc/trail/sprite. At 2–3, Hook. Wash on the displacement path. |
| `updraft`, `skybreak_current` | Push | Air | 4 | At 1, fallback arc/trail/sprite. At 2–4, Blade. Wash on the displacement path. |
| `buffet`, `crosswind`, `fan_the_flames` | Push | Air | 2 for Buffet, 3 otherwise | At 1, fallback arc/trail/sprite. At 2 through maximum range, Blade. Wash on the displacement path. |
| `sleet_squall` | Push | Ice | 3 | At 1, fallback arc/trail/sprite. At 2–3, Lance. Wash on the displacement path. |
| `chain_catch`, `hookspine_reap`, `royal_bramble` | Pull | None | 2 | At 1, fallback arc/trail/sprite. At 2, Hook. Wash on the displacement path. |
| `anchor_slam`, `undertow_guard`, `snare_coil` | Pull | None | 3 | At 1, fallback arc/trail/sprite. At 2–3, Hook. Wash on the displacement path. |
| `yank` | Pull | None | 4 | At 1, fallback arc/trail/sprite. At 2–4, Hook. Wash on the displacement path. |
| `chainbound_gaoler:chain_reel` | Pull | Air | 3 | At 2–3, Hook, including clipped shots. At 1, the enemy force dispatch skips travel. No wash. |
| `razor_gale` | Ranged with a Push rider | Air | 3 | Blade at any legal distance. Wash on the displacement path. |
| `root_snare` | Ranged | Earth | 3 | Earth spike fragments, rims and spark dots via the legacy Earth painter. |
| `briar_weaver:lash_of_thorns` | Ranged | Earth | 3 | Same Earth painter from a visible source. Clipped polygon fragments from a hidden source. |

Area forces and swaps take the surface presentation route. Vaeloryx's wind takes the dedicated dragon route. Fire has no authored targeted force action. Ranged terrain detonation and special boss/cutout actions were checked separately from ordinary shots. The empty override for `ashen_reaver:executioners_fall` is a guardian committed line, with its own presentation route. Force movement, surfaces, collisions, strike and ground contacts have separate presentation routes.

## Implementation and acceptance

1. The inventory covers the live fallback, clipped travel and displacement-wash routes. Razor Gale retains its normal ranged shot and loses its force wash. Its attached Push leaves its action type ranged.
2. Lodestone Reversal uses Spark at distance 2 through the card override. Other distant force actions retain the existing override order. The verifier exercises the ordinary Fire fallback with synthetic distant Push and Pull descriptors.
3. Adjacent Push and Pull skip flight. The board submission uses the FX-17 reservation and the FX-12 player. It applies the action element and the shared step-loss row rule. Cold Shoulder against a wall kept the existing `impact_hit` pair on the aimed tile. Zero-damage Sleet Squall advanced its Ice floor stamp to contact. Haft Shove kept the existing Steel burst at the displaced tile.
4. The force wash now requires a preview effect. Lodestone's Spark uses the existing Lightning contact burst at its aim because the approved Spark has no separate hit row. Hook, Blade and Lance retain their existing hit handling.
5. The Earth routes use `PathUtils._supercover_line`, the walk used by `CombatEngine.combat_line_of_sight` for ranged targeting. The caster is excluded. Original, unclipped endpoints determine the denominator. Each intermediate tile starts at the first submitted sample at or after its fraction of release to contact. The existing FX-17 target burst owns contact when already reserved. The shared tile player culls hidden tiles and samples its normal depth layers.
6. The ranged painter only dispatches the existing preview curve. The production force, Earth and ranged-area witnesses have zero legacy travel or force-wash submissions by source audit.
7. Ranged Shadow areas keep their Shade flight and their own tendril bursts. Both motion modes submit zero `hit_gloom` stamps at the aim. The FX-25 and FX-27 verifier edits change only the ranged-area arrival assertion.
8. Paired resolver playback matched release, contact, every sampled phase, authored and rendered frame counts, duration, action completion and every floating-text sample at the exact base revision.
9. Reduced motion skips flight and presents the FX-12 still on each burst's start sample. The one-sample reduced Earth beat submits all visible path tiles on that sample. The used still cells are 3 for force and Earth and 4 for Shadow.

## Base and implementation playback

Times are 60 Hz capture samples. In the burst columns, `tile name/row @ frame` is the first visible frame. Parentheses give the earlier submission frame when the area's existing stagger delays visibility. Release, contact, and the final effect sample matched on both sides. The reduced-motion release entry records the sampled authored threshold. The flight column confirms that reduced motion displays no shot in the implementation.

| Witness | Shot before → after | Release / contact / last | Tile bursts and shot hits before | Tile bursts and shot hits after | After flight |
| --- | --- | --- | --- | --- | --- |
| `lodestone_reversal` | none → spark | 16 / 21 / 30 | 4:2 lightning/hit @21, 4:3 lightning/hit @31 | 4:2 lightning/hit @21, 4:3 lightning/hit @31 | 16–20 |
| `lodestone_reversal` reduced | none → spark | 5 / 0 / 16 | 4:2 lightning/hit @0, 4:3 lightning/hit @17 | 4:2 lightning/hit @0, 4:3 lightning/hit @17 | — |
| `cold_shoulder` | none → none | 16 / 21 / 31 | 4:1 ice/hit @32 | 4:3 ice/hit @21, 4:1 ice/hit @32 | — |
| `cold_shoulder` reduced | none → none | 5 / 0 / 16 | 4:1 ice/hit @17 | 4:3 ice/hit @0, 4:1 ice/hit @17 | — |
| `cold_shoulder_ice` | none → none | 16 / 21 / 31 | 4:2 ice/floor @21, 4:1 ice/hit @32 | 4:2 ice/floor @21, 4:3 ice/hit @21, 4:1 ice/hit @32 | — |
| `cold_shoulder_ice` reduced | none → none | 5 / 0 / 16 | 4:2 ice/floor @0, 4:1 ice/hit @17 | 4:2 ice/floor @0, 4:3 ice/hit @0, 4:1 ice/hit @17 | — |
| `cold_shoulder_collision` | none → none | 16 / 21 / 33 | 4:3 impact/hit @21 | 4:3 impact/hit @21 | — |
| `cold_shoulder_collision` reduced | none → none | 6 / 0 / 17 | 4:3 impact/hit @0 | 4:3 impact/hit @0 | — |
| `sleet_squall_floor` | none → none | 16 / 21 / 27 | 4:3 ice/floor @28 | 4:3 ice/floor @21 | — |
| `sleet_squall_floor` reduced | none → none | 3 / 0 / 14 | 4:3 ice/floor @15 | 4:3 ice/floor @0 | — |
| `rooted_kick` | none → none | 16 / 21 / 33 | 4:2 earth/hit @21 | 4:2 earth/hit @21, 4:3 earth/hit @21 | — |
| `rooted_kick` reduced | none → none | 6 / 0 / 17 | 4:2 earth/hit @0 | 4:2 earth/hit @0, 4:3 earth/hit @0 | — |
| `hurricane_palm` | none → none | 16 / 21 / 31 | 4:1 impact/hit @21 | 4:1 impact/hit @21, 4:3 air/hit @21 | — |
| `hurricane_palm` reduced | none → none | 5 / 0 / 16 | 4:1 impact/hit @0 | 4:1 impact/hit @0, 4:3 air/hit @0 | — |
| `haft_shove` | none → none | 16 / 21 / 31 | 4:1 steel/hit @32 | 4:1 steel/hit @32 | — |
| `haft_shove` reduced | none → none | 5 / 0 / 16 | 4:1 steel/hit @17 | 4:1 steel/hit @17 | — |
| `yank` | hook → hook | 16 / 21 / 30 | 4:3 steel/hit @31, 4:2 hit_spark @21 | 4:3 steel/hit @31, 4:2 hit_spark @21 | 16–20 |
| `yank` reduced | hook → hook | 5 / 0 / 16 | 4:3 steel/hit @17, 4:2 hit_spark @10 | 4:3 steel/hit @17, 4:2 hit_spark @10 | — |
| `gust_step` | hook → hook | 16 / 21 / 30 | 4:3 air/hit @31, 4:2 hit_spark @21 | 4:3 air/hit @31, 4:2 hit_spark @21 | 16–20 |
| `gust_step` reduced | hook → hook | 5 / 0 / 16 | 4:3 air/hit @17, 4:2 hit_spark @10 | 4:3 air/hit @17, 4:2 hit_spark @10 | — |
| `root_snare` | none → none | 16 / 28 / 58 | 4:1 earth/hit @28 | 4:3 earth/floor @20, 4:2 earth/floor @24, 4:1 earth/hit @28 | — |
| `root_snare` reduced | none → none | 0 / 0 / 0 | 4:1 earth/hit @0 | 4:1 earth/hit @0, 4:2 earth/floor @0, 4:3 earth/floor @0 | — |
| `root_snare_diagonal` | none → none | 16 / 28 / 58 | 5:2 earth/hit @28 | 4:3 earth/floor @22, 5:2 earth/hit @28 | — |
| `root_snare_diagonal` reduced | none → none | 0 / 0 / 0 | 5:2 earth/hit @0 | 4:3 earth/floor @0, 5:2 earth/hit @0 | — |
| `lash_visible` | none → none | 27 / 42 / 83 | 4:4 earth/hit @42 | 4:2 earth/floor @32, 4:3 earth/floor @37, 4:4 earth/hit @42 | — |
| `lash_visible` reduced | none → none | 21 / 21 / 21 | 4:4 earth/hit @21 | 4:2 earth/floor @21, 4:3 earth/floor @21, 4:4 earth/hit @21 | — |
| `lash_hidden` | none → none | 27 / 42 / 83 | 4:4 earth/hit @42 | 4:3 earth/floor @37, 4:4 earth/hit @42 | — |
| `lash_hidden` reduced | none → none | 21 / 21 / 21 | 4:4 earth/hit @21 | 4:3 earth/floor @21, 4:4 earth/hit @21 | — |
| `area_ranged` | shade → shade | 3 / 6 / 23 | 4:4 shadow/hit @6, 3:4 shadow/floor @15 (6), 5:4 shadow/floor @15 (6), 4:4 hit_gloom @6 | 4:4 shadow/hit @6, 3:4 shadow/floor @15 (6), 5:4 shadow/floor @15 (6) | 3–5 |
| `area_ranged` reduced | shade → shade | 6 / 0 / 20 | 3:4 shadow/floor @0, 4:4 shadow/hit @0, 5:4 shadow/floor @0, 4:4 hit_gloom @0 | 3:4 shadow/floor @0, 4:4 shadow/hit @0, 5:4 shadow/floor @0 | — |

The one-fight recording plan measured contacts at samples 21, 76, 139 and 214. All four fit the 360-frame reel, and the final caster was hidden. The engine verifier compares every reported sample and checks for exactly one rear/front pair per stamped tile.

## Removed and retained painters

| Removed | Former route |
| --- | --- |
| `_draw_fireball_attack_effect`, `_draw_fireball_travel_composite`, `_draw_fireball_impact_frame` | Fireball style dispatch from the ranged painter |
| `_draw_earth_spike_attack_effect`, `_draw_earth_spike_path`, `_draw_earth_impact` | Earth style dispatch from the ranged painter |
| `_draw_air_gust_attack_effect`, `_draw_air_gust_travel`, `_draw_air_gust_impact` | Air style dispatch from the ranged painter |
| `_draw_lightning_attack_effect`, `_draw_lightning_travel`, `_draw_lightning_impact` | Lightning style dispatch from the ranged painter |
| `_draw_ice_shard_attack_effect`, `_draw_ice_shard_travel`, `_draw_ice_icicle_impact` | Ice style dispatch from the ranged painter |
| `_draw_elemental_release` | Release helper used by the five style painters |
| `_draw_bezier_glow`, `_draw_partial_bezier_glow`, `_draw_elemental_projectile_trail`, `_projectile_trail_segment_count`, `_projectile_trail_width` | Default live arc and trail |
| `_draw_projectile_sprite`, `_draw_projectile_diamond`, `_projectile_sprite_rect`, `_projectile_sprite_anchor`, `_projectile_texture`, `_projectile_atlas_row` | Default live sprite, missing-texture fallback and texture lookup. The board's now-unused atlas bindings are gone. |
| `_draw_umbra_clipped_ranged_effect`, `_draw_umbra_projectile_fragment`, `_umbra_projectile_fragment_texture`, `_draw_umbra_clipped_oriented_texture`, `_draw_umbra_clipped_colored_polygon`, `_umbra_clip_polygon_vertices`, `_umbra_clip_planes_for_segment`, `_umbra_dictionary_array`, `_umbra_ranged_spatial_progress` | Clipped live flight. The two overlay callers no longer dispatch it. |

- `_draw_ranged_projectile_effect` remains as a preview-only adapter. `_draw_effect_overlay` and the shared elemental scene-depth pass call it. `_draw_ranged_target_preview_curve` also remains reachable from aim, threat, echo and area-preview paths, along with `_arc_control_point`, `_sample_quadratic_points`, `_quadratic_bezier`, `_projectile_element_id`, `_projectile_accent` and `_projectile_secondary`.
- `_umbra_tile_boundary_plane` remains in use by `_draw_texture_rect_with_umbra_clip` for actors. The retained shot shader still clips its own visibility spans.
- `TileGlow.draw_wash` remains available for force previews, trap marks, dragon area footprints and the separate death driver. `AttackFxLibrary.STYLE_*` still controls the timing and other supported presentation routes. The scene-depth and foreground contact painters and the shared spell library remain in place for their other callers.
- These takes can still show procedural focus tint, surface material and lighting, collision and status feedback, impact flashes and floating text. The live force and Earth travel and the Shadow area arrival use the baked effects.

## Verification

| Check | Observed result |
| --- | --- |
| FX-32 paired headless and reel plan | `FX-32 BASELINE: PASS (32 checks, 0 failures)` and `FX-32 VERIFY: PASS (870 checks, 0 failures)`. [Log](/private/tmp/labyrinth_codex/fx-32/final-dry-run.log) |
| Legacy draw audit | `FX-32 LIVE LEGACY SUBMISSIONS: 0 (painters removed, preview-only guards)`. [Log](/private/tmp/labyrinth_codex/fx-32/final-dry-run.log) |
| FX-12 | `FX-12 VERIFY: 120 checks, 0 failures` and `TEST RESULT: PASS`. [Log](/private/tmp/labyrinth_codex/fx-32/fx12.log) |
| FX-14 affected suites | `FX-14 AFFECTED SUITES: PASS (1112 checks, 0 failures)`. The verifier reports `FX-14 VERIFY: FAIL (1998 checks, 1 failures)` on this work and `FX-14 VERIFY: FAIL (1991 checks, 1 failures)` at base. Both report `Noctyrax breath keeps its drawing`. [Current](/private/tmp/labyrinth_codex/fx-32/fx14-affected.log), [Base](/private/tmp/labyrinth_codex/fx-32/fx14-base-affected.log) |
| FX-17 | `FX-17 VERIFY: 132 checks, 0 failures` and `TEST RESULT: PASS`. [Log](/private/tmp/labyrinth_codex/fx-32/fx17.log) |
| FX-25 | Current playback printed `FX-25 BASELINE: PASS (17 checks, 0 failures)`. The historical overlay could not parse `present_arc_head()`. Comparison using the archived takes printed `FX-25 VERIFY: FAIL (569 checks, 6 failures)` on both the implementation and exact base with its original assertions. The same three protected dragon assertions and three historical Shade flight assertions fail in both. [Playback](/private/tmp/labyrinth_codex/fx-32/fx25-playback.log), [Archived comparison](/private/tmp/labyrinth_codex/fx-32/fx25.log), [Exact base](/private/tmp/labyrinth_codex/fx-32/fx25-exact-base.log), [Overlay](/private/tmp/labyrinth_codex/fx-32/fx25-base.log) |
| FX-27 | `FX-27 VERIFY: PASS (164 checks, 0 failures)`. [Log](/private/tmp/labyrinth_codex/fx-32/fx27.log) |
| Python default | `SELECTED MODULES: 22 of 58`, `Ran 194 tests in 36.159s`, `OK`. The optional learned timing-cache update hit read-only Git metadata. [Log](/private/tmp/labyrinth_codex/fx-32/python-default.log) |
| Rules text and UI identity | `PASS: Rules text lint (16 existing hits)`, UI identity `Ran 25 tests in 7.000s` and `OK`. [Rules text](/private/tmp/labyrinth_codex/fx-32/python-default.log), [UI identity](/private/tmp/labyrinth_codex/fx-32/ui-lint.log) |
| Parse checks | Exit 0 with `--check-only` for all seven changed or new GDScripts. Shell syntax, staging helper, both proof contracts, protected shot data, and `git diff --check` passed. [Initial](/private/tmp/labyrinth_codex/fx-32/parse.log), [Final changed scripts](/private/tmp/labyrinth_codex/fx-32/final-parse.log) |

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-32 && /private/tmp/labyrinth_codex/fx-32/native.sh --dry-run
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-32 && /private/tmp/labyrinth_codex/fx-32/native.sh
```

- Headless takes are under `/private/tmp/labyrinth_codex/fx-32/headless/{before,after}/<case>/take.json`.
- Windowed output goes under `/private/tmp/labyrinth_codex/fx-32/native/{before,after}/{lodestone_reversal,cold_shoulder,root_snare,lash_hidden}/`. Each directory gets six 1920×1080 frames, `strip.png`, `take.json` and the visual-probe manifest. The sample order is release, one-third and two-thirds of travel, contact, +100 ms and +233 ms. Cold Shoulder uses the same sampled attack milestones in both revisions.
- The 60 fps silent reel target is `/private/tmp/labyrinth_codex/fx-32/native/force-and-earth.mp4`. The four full-size contact frames, take and manifest go in `native/after/recording/`.
- Native proof uses the full 1920×1080 RunScene SubViewport, HUD on, 100% UI scale, and `LABYRINTH_CEL_LOOK=all`. Real renderer captures and encoding await the desktop run.

## Chosen defaults

- The proof inherits seed 7262026, the standard fight camera and normal combat speed. The private fixture uses 30 hero Health and 30 target Health, clears its local stone lane, and fixes the hero at (4,4). Targets use distances 1–3, including an offset at (5,2). The Ice witness places Ice under the target and on its first forced landing. The extra wall witness puts a wall directly beyond the target. The reel switches its fixture room to Eclipse before the right-side Briar Weaver attacks. Rooted Kick and Gust Step start from the post-move position for their selected resolver step.
- The strip arranges its six scaled copies in two rows of 640×360 cells. The native launcher inherits the existing MovieWriter clock and uses a 300-second capture timeout. The 360-frame reel records all four attacks in one fight and keeps the final result on screen for the remainder.

## Open issues

The native proof is pending desktop execution. The historical FX-14 assertion and FX-25 comparison failures reproduce at base.

## TODO_DESIGN placeholders

None.
