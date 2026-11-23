# fx-23 round 1 result

Round 1 is uncommitted on `codex/fx-23` on top of the approved round 0 commit `2fbbd06c0`. The playback comparison uses the original base `8f38fb277`.

## Acceptance

1. `FIRE` and `BOLT` copy the fx-12 ramps. The original 56 palette entries retain their indices. The retained renderer shares one shader sized for the 65-entry palette with its warm draw.
2. `ember` is pixel-identical to round 0 in all seven atlases, including its palette colours.
3. `spark` uses the new wake, three authored centre paths, and pointed halo, body, and core polygons with capped miter joins. The two-segment fork uses the same polygon fill and a straight core on its first segment. The tip is the specified four-cell orb. The shot has zero lift, ease 0.6, and an empty shot-atlas hit row.
4. Single-target attacks use the retained flight window and reduced-motion rule. Scorch hit and fully blocked fixtures select `fire_hit_front` because both spend a damage pool. The empty target selects `fire_floor_front`. Arc Flash selects `lightning_hit_front`. Arc Bolt's cutout adapter uses the existing Lightning flight duration leading into its authored contact. Active Chain Bolt keeps its original contact and hops. Slag Mortar's Scatter Shot resolves Ember through Fire and retains its fx-17 contact.
5. Ranged Fire and Lightning areas use the same indexed shots and finish at the aimed tile centre. Cinder Bloom and Volt Surge retain their fx-12 arrival rows. Ice and Air areas still use `ElementalSpellFx.travel`. Earth areas use the separate procedural ground spike path through `ElementalSpellFx.ground` and `ElementalSpellFx.impact`. The Slag Mortar's marked lob uses its own procedural Fire flight in `lob_view.gd`.
6. The atlas comparison checks the original coordinates, raw indices and palette for 28 base regions and the approved Ember region in each sheet. The timing comparison uses base scripts and assets from `8f38fb277`. The new shots use the fx-14 visible spans for Umbra and the existing tile visibility gate for contact.

## RunScene cases

Frames in the following table count 60 Hz presentation samples from the start of the action. The authored column gives the contact frame and action length on the underlying action clock. The before and after action clocks and observed contact samples matched in each row. The complete per-action draw lists, burst rows and before/after legacy flags are in the [dry-run log](/private/tmp/labyrinth_codex/fx-23/round-1/dry-run.log) and [take manifests](/private/tmp/labyrinth_codex/fx-23/round-1/headless).

| Resolved case | Shot after | Flight samples after | Authored contact / length, both | Contact sample, both | Legacy flight / release before → after |
| --- | --- | --- | ---: | ---: | --- |
| Hero · Scorch hit | `ember` | 3–9 | 12 / 48 | 10 | yes / yes → no / no |
| Hero · Scorch fully blocked | `ember` | 3–9 | 12 / 48 | 10 | yes / yes → no / no |
| Hero · Scorch empty tile | `ember` | 3–9 | 12 / 48 | 10 | yes / yes → no / no |
| Hero · Arc Flash | `spark` | 3–4 | 8 / 30 | 5 | yes / yes → no / no |
| Hero · Cinder Bloom | `ember` | 3–9 | 12 / 48 | 10 | yes / yes → no / no |
| Hero · Volt Surge | `spark` | 3–4 | 8 / 30 | 5 | yes / yes → no / no |
| Hero · Chain Bolt | `spark` | 3–4 | 8 / 30 | 5 | yes / yes → no / no |
| Vyraketh · `kindle_ground` ranged follow-up | — | — | 35 / 66 | 43 | no / no → no / no |
| Vyraketh · `cinderfall` | — | — | 35 / 66 | 43 | no / no → no / no |
| Zekarion · `storm_claw` | — | — | 35 / 66 | 43 | no / no → no / no |
| Zekarion · `tempest_breath` | — | — | 35 / 66 | 43 | no / no → no / no |
| Zekarion · `call_wisps` | — | — | 35 / 66 | 43 | no / no → no / no |
| Lightning Wisp · `static_lash` | `spark` | 8–15 | 13 / 48 | 16 | yes / yes → no / no |
| Lightning Wisp · `blinding_arc` | `spark` | 8–15 | 13 / 48 | 16 | yes / yes → no / no |
| Bell Tender · `staff_bolt` | `spark` | 8–15 | 13 / 48 | 16 | yes / yes → no / no |
| Arc Thrall · `arc_bolt` | `spark` | 43–45 | 37 / 72 | 46 | yes / no → no / no |
| Slag Mortar · `scatter_shot` | `ember` | 4–13 | 12 / 48 | 14 | yes / yes → no / no |

The Eclipse fixture hid the Wisp and set the shot's first visible span to 0.234375 of the original line. The hero retained the Lightning hit row. Reduced-motion Scorch kept its contact row with zero flight samples. The reel scheduled 240 frames with Ember followed by Spark.

Scatter Shot retained `fire_floor_front` at the shove destination. The resolver reports the hero's damage on the original tile and aims the presentation at the destination.

## Proof for the design owner

The launcher stages the base sources and atlases by Git object ID. It uses the native visual probe runner for exact 1920×1080 RunScene captures at 100% UI scale with cel look and HUD. The six 640×480 crop columns are release, 33% and 66% of flight, contact, contact +100 ms and contact +233 ms. The after-only reel uses one fight, Fire then Lightning, with sound off.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-23 && FX23_OUTPUT_ROOT=/private/tmp/labyrinth_codex/fx-23/round-1 /private/tmp/labyrinth_codex/fx-23/native.sh
```

The script writes `native/{before,after}/<case>/strip.png`, the six crops, a full contact frame, `take.json` and `manifest.json` under `/private/tmp/labyrinth_codex/fx-23/round-1/`. Scatter Shot is included in the native case inventory. The reel path is `/private/tmp/labyrinth_codex/fx-23/round-1/native/fire-lightning.mp4`. Windowed captures are pending. The [heading sheet](/private/tmp/labyrinth_codex/fx-23/headings.png) shows eight headings and all three flicker frames at 3× nearest-neighbour.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-23 && FX23_OUTPUT_ROOT=/private/tmp/labyrinth_codex/fx-23/round-1 /private/tmp/labyrinth_codex/fx-23/native.sh --dry-run
```

## TODO_DESIGN

None.

## Chosen defaults

- The proof uses the fixture seed 7262026, the hero at (4, 4), and ordinary opponents at (4, 2). The empty aim is (3, 3), the second Chain Bolt target is (5, 2), and the blocked case gives its target 20 Block. Dragon fixtures use the fx-18 staging. The hidden Wisp fixture uses Eclipse.
- The capture crops centre on the hero–opponent midpoint and clamp to the framebuffer. The reel is 240 frames. Native probe timeout is 300 seconds, matching the fx-20 capture runner.

## Verification

| Check | Observed result |
| --- | --- |
| FX-23 RunScene dry-run | `FX-23 VERIFY: PASS (258 checks, 0 failures)` |
| Atlas identity | `FX-23 PIXEL IDENTITY: PASS (196 regions across 7 atlases, indices and colours)` |
| Approved Ember identity | `FX-23 EMBER IDENTITY: PASS (7 regions against 2fbbd06c0, indices and colours)` |
| Round-1 atlas change isolation | `FX-23 ROUND 1 CHANGE ISOLATION: PASS (only Spark pixels changed in 7 atlases)` |
| Re-pinned atlas files | `FX-23 ASSET PINS: PASS (7 atlas blob hashes)` |
| FX-17 | `FX-17 VERIFY: 128 checks, 0 failures` · `TEST RESULT: PASS` |
| FX-14 affected suites | `FX-14 AFFECTED SUITES: PASS (1112 checks, 0 failures)` |
| FX-14 inventory verifier | `FX-14 VERIFY: PASS (1991 checks, 0 failures)` |
| GDScript parse | Exit 0 for `tools/fx14/verify.gd`, `tools/fx23/cases.gd`, and `tools/fx23/verify.gd` |
| Shell syntax, Python syntax, and diff whitespace | Exit 0 |

The Python default group was skipped for round 1. [FX-14 log](/private/tmp/labyrinth_codex/fx-23/round-1/fx14.log), [FX-17 log](/private/tmp/labyrinth_codex/fx-23/round-1/fx17.log), [parse log](/private/tmp/labyrinth_codex/fx-23/round-1/parse.log), [final FX-23 parse log](/private/tmp/labyrinth_codex/fx-23/round-1/parse-fx23-final.log)
