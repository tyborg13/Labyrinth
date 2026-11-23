# fx-24 contact fallbacks

Base `28d367a90`, branch `codex/fx-24`. Shared presentation risk tier medium. Resolver outcomes, authored action and contact frames, and the leaving-surface fade are fixed. Proof uses real resolver steps, one pair per visible tile, reduced-motion stills, and a native 1920×1080 before/after capture for the design owner.

## Caller inventory

| Trigger | Live base path | Director rule |
| --- | --- | --- |
| Late attack feedback for melee, ranged, area, and force | RunScene impact decals call neutral ellipse/outline/spokes or elemental ground paint. Mapped attacks and strikes already claim their tiles. | Use the existing tile pair per uncovered contact. Keep the original feedback tail. |
| Unmapped area footprint, including targeted Fire and effect-specific area overrides | Action-ground wash calls `_draw_aoe_resolution_footprint`. The depth and floor passes also draw the target core for ranged-style area actions. | Use the elemental or Steel pair on affected tiles. Preserve travel. |
| Unmapped ground burst | Player Detonate, Shatter Illusion and Burst Terrain (and enemy terrain bursts) reach the depth/floor painter if no baked plan owns the contact. | Preserve mapped special cases and dragon presentation. Use the element's pair for an uncovered ground burst. |
| Surface entry, paint, replacement, damage, grounding a status, conduction, Mantle shatter, terrain creation and Worldspine feedback | Retained and synchronous surface rendering call `BoardSurfacePresentation.draw_feedback` with an elemental feedback event. | Submit on the event's existing feedback frame. Use the elemental pair and the resolved loss row. Preserve chain and dragon attack exceptions. |
| Ice melt, Rubble clear, Fire burnout and Electrified discharge | Retained and synchronous calls to `_draw_surface_break` when the beat is uncovered. | Ice, Earth, Fire and Lightning pairs with the full-step row. The exact old fade curve remains. |
| Uncovered trap activation | Trap depth impact and trap floor/core fallback. Trigger preview and rendered plate activation are separate callers. | Use the elemental pair, or Impact for an elementless trap. |
| Push or Pull ends against a blocker, wall, Rubble or boundary | Retained and synchronous `_draw_collision_feedback` when the old beat was uncovered. | Impact on the stopped actor's tile. Determine hit from pool loss. |
| Cinder Droplet `spark_bite`, Cinder Ooze melee | Rig-specific Fire spatter or splash when contact coverage did not suppress it. | Fire pair at the existing resolved contact. |
| Veil Needle | Legacy `VeilboundAcolyteFx.ranged` branch. Shade already resolves by intent and uses the same release socket. The late neutral decal can overlap Shade's hit. | Keep Shade flight and hit. Remove the legacy branch and suppress the extra decal. |
| Burrow mound | `burrow_view.gd` calls `_draw_impact_ellipse` while presenting the mound. | Retain the marker and its helper. |
| Earth spike travel, Fire and Lightning travel, dragon attacks and chain hops | Reuse some of the elemental painters in their separate depth and travel passes. | Preserve these paths. |

`_draw_impact_crack_marks` was already absent at the base revision.

## Implementation

1. The table traces the reachable painter paths at `28d367a90`. Shale Burst already had the protected Earth mapping. The remaining Shale contact path was the separate procedural Rubble feedback, sometimes over an Earth pair.
2. Uncovered non-dragon area, ground and decal contacts now use FX-12 through the same per-step reservations as planned attacks and shots. Surface feedback follows the published event, including retained overlap and displacement frames. A mapped attack, strike, trap or shot keeps its tile. Trap fallbacks use the same mapping as planned traps. Visible and reduced-motion samples use the board tile player. Worldbreak and Shattered Reflection keep their existing mappings and lose their duplicate tail decals.
3. Ice, Rubble, Fire and Electrified end with their existing element's pair, using the floor row on tiles without a loss in the step. The old surface still follows the original `leaving_alpha` code and sampled values.
4. Force collision uses Impact at the stopped actor's anchor. A push that costs Health selects the hit row even if its collision costs zero. Losses on blocker tiles count separately.
5. Veil Needle already resolved as Shade in the base. The normal overlay guard kept the bespoke needle branch from double-drawing the flight. The headless trace exposed a different double draw: `hit_gloom` at frame 44 and a legacy ground decal at frame 72. Both revisions launch Shade from the same release socket at sample 12. The new enemy-intent key explicitly selects Shade, and only `hit_gloom` submits at contact.
6. Authored frame counts, authored duration, rendered submission counts, contact progress and exact 60 Hz contact samples matched. Take completion also matched in all 20 standard and four reduced-motion comparisons. The probe records intermediate progress samples too. Sampling a 60 Hz framebuffer can skip different intermediate authored samples when the two clocks have different fractional offsets.

### Painters and retained effects

- Removed `_draw_surface_break`, `_draw_fire_burnout`, `_draw_collision_feedback`, the fragment highlights from the generic removal wash, `_draw_trap_elemental_depth_effect`, and the remaining triggered-trap floor/core fallback. Retained the trigger preview and activated plate texture.
- Removed `VeilboundAcolyteFx.ranged` and its script and UID, and removed the Cinder Ooze and Droplet splash submissions in the board's melee branch. The Ooze's now-unused helper lives outside this unit's owned files.
- `_draw_impact_ellipse` still serves the Burrow mound and the retained dragon feedback. `_draw_impact_ellipse_outline`, `_draw_impact_radial_marks` and `_draw_aoe_resolution_footprint` still serve protected dragon presentation. Earth spike travel and protected elemental/chain paths still call the shared elemental paint routines.
- Other hand-drawn effects seen in the caller search include the Noctyrax breath contact, the Earth spike path and the legacy Umbra travel fragment. These are retained by the director's dragon and flight exclusions. Threat marks, force markings and aim paths also remain.

## Frame counts

The columns give the same value for base and after. Contact is the zero-based sample in the proof take.

| Resolver case | Authored action frames | Contact sample |
| --- | ---: | ---: |
| Ice melt, Rubble clear, Fire out, Electrified end | 18 | 0 |
| Collision with Health loss or with zero pool loss | 18 | 0 |
| Veil Needle | 54 | 44 |
| Closing Shade | 36 | 19 |
| Cinder Ooze melee | 42 | 22 |
| Cinder Droplet melee | 36 | 19 |
| Shale Burst area | 60 | 28 |
| Targeted Fire area, clear and Umbra | 60 | 23 |
| Immolation consumed-ground burst | 48 | 10 |
| Worldbreak terrain burst | 6 | 5 |
| Shattered Reflection illusion burst | 6 | 5 |
| Quick Stab Steel contact | 30 | 13 |
| Fire entry, Ice placement, unmapped trap | 18 | 0 |
| Reduced Ice melt, zero-loss collision, Veil Needle and targeted Fire | 1 | 0 |

## Chosen defaults

The proof inherits FX-20's boot seed `7262026`, 60 Hz movie clock, standard starting Health 30, 900 capture-frame budget, 420-frame teardown allowance and 300-second native timeout per take. The fixtures use an open stone patch, a hero at (4,4), a ground witness at (4,3), a wall at (4,5), and neighbouring enemies and props named in `cases.gd`. Fuel Health is 3, fixture trap damage is 4 and the no-loss collision fixture uses a resolver-local relic effect with both damage and Block reward set to zero. The Shadow trap is a fixture for a missing tile-burst mapping. The live trap definitions and existing mappings were preserved. The two general native witnesses are a targeted Fire AoE and Fire entry, which exercise the two broad fallback paths. The crop centres on the visible source and affected board area. Sample offsets are 0, 6, 14 and 22 capture frames.

## Open issues

- Shadow contacts and Shadow traps follow the shared element lookup, whose Shadow entry is empty on this branch.
- Renderer output and inspection require the design owner's macOS window-server access. The dry run validates the take schedule, submitted rows and legacy eligibility. It emits JSON reports.

## Round 0 verification

| Check | Observed result |
| --- | --- |
| FX-24 dry run | `FX-24 VERIFY: PASS (384 checks, 0 failures)` |
| Focused Godot suites | `FX-24 VERIFY: PASS (802 checks, 0 failures)` |
| FX-20 original matrix | `FX-20 VERIFY: FAIL (171 checks, 1 failures)` · `Veilbound Shadow keeps the legacy contact` |
| FX-22 original matrix | `FX-22 VERIFY: PASS (266 checks, 0 failures)` |
| Godot parse checks | Exit 0 in all seven changed-script invocations |
| UI identity | `Ran 25 tests in 7.736s` · `OK` |
| Rules text | `PASS: Rules text lint (16 existing hits)` |
| Python default | `Ran 194 tests in 36.149s` · `FAILED (failures=2)` |

The Python default group selected 22 of 58 audited modules. Its two failures match the checked-out base. The approved content test expects `assets/art/effects/defense_heal_casts.png`. The Git sidecar test expects `tools/flt01/fight_probe.gd.uid` and `tools/flt01/renderer_check.gd.uid`. The Python runner also reported that the read-only Git directory prevented its local timing-cache update. Headless Godot startup logged a macOS system-certificate warning. Matching baked atlas import artifacts were restored to the worktree's local Godot cache after comparing source-image and import-setting bytes with the FX-22 worktree.

- [Headless takes](/private/tmp/labyrinth_codex/fx-24/headless/)
- [FX-24 dry-run log](/private/tmp/labyrinth_codex/fx-24/dry-all.log)
- [Focused suites](/private/tmp/labyrinth_codex/fx-24/focused-complete.log)
- [FX-20 verifier](/private/tmp/labyrinth_codex/fx-24/fx20-complete.log)
- [FX-22 verifier](/private/tmp/labyrinth_codex/fx-24/fx22-complete.log)
- [Python default summary](/private/tmp/labyrinth_codex/fx-24/python-default/summary.json)

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-24 && /private/tmp/labyrinth_codex/fx-24/native.sh
```

The launcher runs the real RunScene in a 1920×1080 SubViewport with cel look and HUD at 100% UI scale. It uses the four 640×480 samples at contact and approximately +100, +233 and +366 ms. Default takes are `ice_melt`, `rubble_clear`, `fire_out`, `collision_hit`, `veil_needle`, `targeted_fire`, `fire_entry`, `push_wall`, `ice_trap` and `elementless_trap`. It prints each base and after strip, full-resolution witness, take report and manifest under `/private/tmp/labyrinth_codex/fx-24/native/{before,after}/<case>/`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-24 && /private/tmp/labyrinth_codex/fx-24/native.sh --dry-run
```

The dry run prints `/private/tmp/labyrinth_codex/fx-24/headless/{before,after}/<case>/take.json` and the planned native paths. Reduced-motion evidence is under `headless/{reduced-before,reduced-after}/`. All source changes are uncommitted.

## Round 1 verification

Round 1 uses the whole step's resolved losses for the row of each FX-24 contact. The per-step tile reservation and contact clocks are retained. Planned and uncovered traps share the element lookup. Elementless traps use Impact, and Shadow uses the catalog value.

| Case | Authored frames before / after | Contact | Result |
| --- | ---: | --- | --- |
| Damaging push into a wall, zero collision damage | 6 / 6 | Authored frame 3 / 3 | `impact_floor_front` at round 0, `impact_hit_front` after |
| Damaging Ice trap | 18 / 18 | Capture sample 0 / 0 | `ice_hit_front` at the center |
| Damaging elementless trap | 18 / 18 | Capture sample 0 / 0 | `impact_hit_front` at the center |
| Shadow trap | 18 / 18 | Capture sample 0 / 0 | No pair with the current catalog |

The push fixture uses damage 4, range 1, and push distance 1. Its resolver-local collision defense sets collision damage and Block reward to zero. The authored contact check uses the action frame because the pre-action pause can shift the take's capture index by one tick.

- `FX-24 VERIFY: PASS (429 checks, 0 failures)`. [Dry-run log](/private/tmp/labyrinth_codex/fx-24/round1/dry-run-verified.log) · [Takes](/private/tmp/labyrinth_codex/fx-24/round1/verified/headless/)
- `ROUND 0 PUSH: impact_floor_front -> impact_hit_front, frames=6/6, authored contact=3/3`. [Round 0 comparison](/private/tmp/labyrinth_codex/fx-24/round1/round0-push-verified.log)
- `FX-20 VERIFY: PASS (171 checks, 0 failures)` and `FX-22 VERIFY: PASS (266 checks, 0 failures)`. [FX-20](/private/tmp/labyrinth_codex/fx-24/round1/fx20-complete.log) · [FX-22](/private/tmp/labyrinth_codex/fx-24/round1/fx22-complete.log)
- `FX-17 VERIFY: 128 checks, 1 failures` on the live catalog. Its sole failure expects the original empty Shale Burst mapping, whereas FX-22 requires Earth. In an isolated Godot process loaded with FX-17's historical intent table, the unmodified assertions reported `FX-17 VERIFY: 128 checks, 0 failures`. The empty Shadow trap accounts for two fewer per-pair assertions than in the 130-check failure run. [Live catalog](/private/tmp/labyrinth_codex/fx-24/round1/fx17-live-complete.log) · [Historical catalog](/private/tmp/labyrinth_codex/fx-24/round1/fx17-compat-complete.log)
- All six changed GDScripts returned exit 0 in separate parse checks. Python verification was skipped for this round.
