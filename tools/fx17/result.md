# FX-17 implementation handoff

Worktree `codex/fx-17`, base `e0b29e0b6` (`codex/fx-13`). Risk tier medium. The implementation and proof files are uncommitted.

## Acceptance

| Requirement | Implementation |
| --- | --- |
| Single-target contact | Melee and unmapped ranged contacts use the attack element or Steel. Health, Block, Stoneskin, Mantle, Defiance or defeat selects the hit row. A miss or a contact without pool loss selects the floor row. The resolved target descriptor supplies the tile, including the named tile of a large unit and the original target of an Umbra-clipped effect. |
| Force collision | Push and Pull use Impact hit at the stopped unit. Damage-bearing unit blockers also receive Impact hit. Walls, props and terrain supply the obstruction only. |
| Surface break | Ice, Rubble, Fire and Electrified use Ice, Earth, Fire and Lightning floor rows respectively. The surface event still drives the original outgoing floor fade. |
| Triggered traps | FX-12's existing cross takes priority. An unstamped trigger uses the trap element, or Impact with no element, and selects hit or floor from the occupant's resolved pool loss. |
| Burrow Grub | Dive uses Earth floor on the tile left. Erupt uses the actual eruption tile and the marked strike tile when distinct. The Health loss at the marked tile selects hit. A displaced recipient's hit stamp lands with the existing number on the throw landing frame. |
| Bramble | The bramble grow and expiry playback descriptors use Earth floor. The native case stages the legacy bramble descriptor through RunScene. Current Thornwall uses the shared Upheaval outcrop rules. |
| Bile Bloomer | The release fragments remain for Shale Burst. FX-12's `bile_burst` mapping is empty. The release draw skips an effect already marked as using an FX-12 area burst. |
| Deduplication and presentation | A step reserves the visible tiles in existing area/trap plans, honors the mapped FX-14 shot when its resolver is installed, and claims each new tile once. The normal FX-12 player owns depth, size, palette, 13 frames at 30 fps on the board clock, sight culling, and the reduced-motion still. All hooks fire within existing submissions. |
| Legacy drawing | Replaced contacts suppress the aftermath decal, the ranged elemental landing, the Cinder Ooze/Droplet tile contact and the Grave Surgeon jab strokes as applicable. Force spokes and surface-break fragments skip replaced event records. The Burrow dust-circle and bramble fleck painters are removed, as is the unused impact-crack helper. Ellipse helpers still serve legacy contact decals and the Burrow mound. |

`tile_burst_fx.gd` accepts one optional `contact_hits` map on a spec submitted through its existing API. An Ice break must use floor even if something loses a pool on that tile in the same step, and a force collision must explicitly use hit. The existing state comparison cannot express those outcomes. The atlas manifest, PNGs and shader are untouched.

### Shadow sites

The Shadow branch keeps the existing contact decal and authored shadow effects for Veilbound Acolyte's Veil Needle and Closing Shade, Gloam Stalker's Ambush and Slash, and Hollow Mimic's Echo and Shade Bolt when the resolved action is Shadow. The Shadow trap fallback keeps the existing draw path. Noctyrax's Night Coil, Void Claw and Starless Breath stay on the dragon paths. The dry-run Shadow fixture uses Closing Shade.

FX-14 is a sibling branch. This checkout exercises the shot/area tile reservation contract and uses the neutral fallback for Hurl Spear. The integrated FX-14 renderer has to be checked after branch integration. FX-15's authored weapon arcs have no tile-hit stamp on the specified base.

## Files changed

- `scripts/resolved_contact_bursts.gd` and its UID own the contact specifications and per-step reservations.
- `scripts/run_scene.gd` connects current attack, adapter, surface and displacement submissions.
- `scripts/combat_board_view.gd` and `scripts/board_surface_presentation.gd` gate legacy drawing at replaced contacts.
- `scripts/enemy_mechanics/burrow_view.gd` and `scripts/enemy_mechanics/bramble_view.gd` remove the dust and fleck painters.
- `scripts/tile_burst_fx.gd` accepts the resolved row override.
- `tests/en01_enemies_probe.gd` drops the obsolete dust diameter from its existing proof metadata.
- `tools/fx17/` contains this handoff, the headless verifier and UID, the native probe and UID, the capture contract, and the two shell launchers. The director entry point is also at `/private/tmp/labyrinth_codex/fx-17/native.sh`.

## Chosen defaults

- Proof board uses the existing inspection seed; hero at `4:4`, adjacent target at `4:3`, distant target at `4:2`, trap at `5:4`, and staged bramble at `3:4`. Fixture Health is 80 for the hero and 35 for enemies. The Block fixture starts with 12 Block and the archived bramble has 3 Health. The Pull fixture uses a sight-transparent crate so the real targeting rules accept an enemy beyond it. These values live in `native.gd`.
- The capture uses a 64×64 MovieWriter sink, an exact 1920×1080 SubViewport at 100% UI scale, and the specified 640×480 crop. The capture clock is 60 fps, with sample frames 0, 2, 4, 8, 14 and 22. The probe allows 360 setup frames, 12 settle frames and 900 take frames. The recording stages three hero and enemy exchanges. The shell allows up to 480 seconds per native take.
- The scripted verifier uses a four-by-three floor, 40 Health, a 4-point loss, and a 1 ms margin for lifetime sampling. The verifier and native proof run on separately isolated task-local Godot processes.

## Proof for the design owner

Run the native strips and five-second recording under a macOS window session.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-17 && /private/tmp/labyrinth_codex/fx-17/native.sh
```

The script prints the new `/private/tmp/labyrinth_codex/fx-17/native.*` root. Each take writes `contact.png`, `strip.png`, `take.json`, and `manifest.json` under `base/<case>` or `after/<case>`. The recording is `after/recording/melee-exchanges.mp4`. The same script with `--dry-run` writes only `take.json` evidence using a fixed headless presentation clock. Windowed proof and visual inspection remain pending.

## TODO_DESIGN placeholders

None.

## Observed results

```text
FX-17 PACING strike: base=43, after=43
FX-17 PACING bite: base=46, after=46
FX-17 PACING push_wall: base=52, after=52
FX-17 PACING erupt: base=68, after=68
FX-17 PACING hurl_spear: base=52, after=52
FX-17 VERIFY: 133 checks, 0 failures
TEST RESULT: PASS
FX-17 NATIVE DRY RUN: 15 cases, 29 takes
FX-12 VERIFY: 120 checks, 0 failures
TEST RESULT: PASS
FX-13 VERIFY: 96 checks, 0 failures
TEST RESULT: PASS
TEST RESULT: PASS board surface presentation
SURFACE FEEDBACK UI TEST RESULT: PASS
EN01 ENEMIES TEST RESULT: PASS
EN01 PROBE HEADLESS CONTRACT RESULT: PASS
EN04 ENEMIES PROBE CONTRACT: PASS (9 states, 1920x1080, UI scale 100%)
PASS: Rules text lint (16 existing hits)
```

The UI identity lint reported `Ran 25 tests in 6.032s` and `OK`. The full Godot and Python product suites are left for integration. The requested Python default group reported `Ran 194 tests in 35.552s` and `FAILED (failures=1)`. The failure names the existing missing `tools/flt01/fight_probe.gd.uid` and `tools/flt01/renderer_check.gd.uid` sidecars. Running the sidecar module on exact base `e0b29e0b6` reproduced both missing paths and reported `FAILED (failures=1)`.

- [Dry-run matrix with every take path](/private/tmp/labyrinth_codex/fx-17/dry-run-summary.json)
- [FX-17 verifier log](/private/tmp/labyrinth-godot-home/fx-17-1795402494371958000-57431/godot.log)
- [Python default result](/private/tmp/labyrinth_codex/fx-17/python-default/summary.json)

## Open items

- Native strips and the five-second recording require the design owner's macOS window session.
- FX-14 overlap passed the resolver-boundary simulation. The real shot player can be exercised after integration.
- The legacy bramble fixture emitted the missing `bramble` glossary warning on both builds. The EN01 suite also logged the same dummy-renderer texture error on both builds and returned its documented PASS result. The Python default group's sidecar failure is reproducible on the base.
