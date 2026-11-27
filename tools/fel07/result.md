# fel-07 board tooltip result

The board popup now uses the picked square for tile regions and live pickups. The headless census found five off-square popups on base `6203cf9aa` and zero in the fel-07 worktree.

## Requirements

1. **Square ownership.** The pointer resolver uses the same board pick as hover and targeting. A live pickup must match the picked tile and its existing live draw rect. A retained tile region must match the picked tile and its existing rect. Eligible regions retain their lookup order and use the shared tile stack. The base and branch census captured all 46 hovers from 12 saved fights.
2. **Off-board exception.** A registered tile region whose anchor is absent from the rendered layout still matches its rectangle. Across the 12 saved fights, zero registrations qualified. The separate Light witness placed a regular Light orb on outer wall tile `(0, 0)` and confirmed the orb's actual rect opened its popup when the pointer picked `(-1, -1)`. The orb registers at [combat_board_view.gd:6659](../../scripts/combat_board_view.gd#L6659).
3. **Existing paths.** Untiled regions still match their rectangles. The living-unit check and shared tile-detail stack, index and cache remain in use. Production changes are confined to which tile region or live pickup can answer a pointer query. The census checks the displayed strings, hover and rail feedback, occluder fades, and saved combat witness.
4. **Focus.** Controller inspection already builds the detail stack from the focused tile through [controller_tooltip_for_tile](../../scripts/combat_board_view.gd#L5377). Keyboard move and blink navigation uses that same tile-keyed focus candidate and displays its targeting arrow. The crate and pickup witnesses compare pointer and focus stacks on both the object square and the square behind it. The focused keyboard probe exercises its existing targeting and confirmation path.

### Popup first lines

| Fixture | Square | Base | Branch |
| --- | --- | --- | --- |
| 02 A | (4, 5) | FIRE TRAP | FIRE |
| 04 A | (4, 5) | WOODEN CRATE | FIRE |
| 07 D | (2, 6) | AIR TRAP | LOB SLAG |
| 10 A | (3, 6) | WOODEN CRATE | FIRE |
| 12 A | (6, 4) | Thunderstone | FIRE |

### Off-board registration audit

The Light witness at `(0, 0)` was the only exercised case. Coordinates for the registration sites below come from the live board state.

| Region | Tile source | Registration line in combat_board_view.gd |
| --- | --- | --- |
| Tethered Light | `source.pos`, the player or illusion tile | 6649 |
| Light orb | `source.pos`, the Light placement tile. The witness uses `(0, 0)`. | 6659 |
| Noctyrax brazier marker | `guardian_braziers[].pos` | 6779 |
| Meteorfall badge and number | `meteor_marks[].tiles` | 8393, 8400 |
| Ground loot, Watch Brazier body, floating loot, terrain and trap | Drawn tile or the trap's `pos` | 8570, 8643, 8888, 9613, 17939 |

## Verification

- Base [observations](captures/base.3bRHTd/observations.json), [census](captures/base.3bRHTd/census.md) and [runner log](captures/base.3bRHTd/runner.log).
- Branch [observations](captures/branch.u9nOfo/observations.json), [census](captures/branch.u9nOfo/census.md) and [runner log](captures/branch.u9nOfo/runner.log).
- The fel-06 reporter infers origin by replaying the old rectangle matches. The fel-07 adapter also checks the displayed panel metadata against the picked square's focus stack before assigning its origin. The comparison normalizes Godot-generated node serials and compares the remaining observations, including tile centers.

```text
FEL06 DRY RUN PASS fixtures=12 samples=46
FEL07 CENSUS base off_square=5 branch off_square=0
FEL07 DIFF PASS unchanged=41 popup_only=5
FEL07 WITNESS PASS own=(5, 6) Wooden crate behind=(4, 5) Fire off_board=empty focus=equal
FEL07 WITNESS PASS own=(7, 5) item:thunderstone behind=(6, 4) Fire off_board=empty focus=equal
FEL07 WALL LIGHT PASS tile=(0, 0) pointer_tile=(-1, -1) rect_match=true
```

The [comparison log](captures/comparison.log) lists the five changes. An earlier branch run sampled fixture 01 before the board layout settled. The isolated rerun reached the baseline tile centers.

| Focused check | Exact result |
| --- | --- |
| [board_tile_tooltip_test.gd](captures/board_tile_tooltip_test.log) | `BOARD TILE TOOLTIPS: PASS checks=233 failures=0` |
| [board_tile_tooltip_route_test.gd](captures/board_tile_tooltip_route_test.log) | `BOARD TILE TOOLTIP ROUTES: PASS (12 capture states; real X input; native popup layout; headless, no pixels)` |
| [board_tile_tooltip_live_test.gd](captures/board_tile_tooltip_live_test.log) | `BOARD TILE TOOLTIP LIVE: PASS (held mouse, idle controller, occupied tile, all mutation domains)` |
| [cbt_01_probe.gd -- --logic-only](captures/cbt_01_probe.log) | `CBT-01 PROBE: PASS (0 failures)` |
| [Light region witness](captures/light_region_witness.log) | `FEL07 WALL LIGHT PASS tile=(0, 0) pointer_tile=(-1, -1) rect_match=true` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 19.941s` and `OK` |
| `python3 tests/test_rules_text_lint.py` | `Ran 3 tests in 0.468s`, `OK` and `PASS: Rules text lint (16 existing hits)` |

Godot logged `ERROR: Condition "ret != noErr" is true. Returning: ""` from `get_system_ca_certificates` on both base and branch. The 233-check tooltip program logged missing glossary definitions for `bramble` and `ice_pillar` and exited successfully.

## Files changed

- [combat_board_view.gd](../../scripts/combat_board_view.gd#L5269) for pointer tooltip eligibility.
- [census_probe.gd](census_probe.gd), [census.sh](census.sh) and [compare_census.py](compare_census.py) for census verification and the crate and pickup witnesses.
- [light_region_witness.gd](light_region_witness.gd) for the wall Light exception.
- [census_probe.gd.uid](census_probe.gd.uid), [light_region_witness.gd.uid](light_region_witness.gd.uid), [.gitignore](.gitignore) and this report.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-07 && tools/fel06/native.sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-07 && tools/fel07/census.sh
```

The first command runs the fel-06 probe from this worktree. The second captures base and branch, verifies displayed-stack origin on the branch, and writes `pairs.png` under `tools/fel07/captures/native.*/`. Base frames go in the batch's `base/` subdirectory. Both commands capture at 1920×1080 and 100% UI scale.

## TODO_DESIGN placeholders

None.

## Chosen defaults

- The headless witnesses use the existing crate and Thunderstone overlap fixtures. The empty-point search inherits the census's 12 divisions.
- The wall Light witness uses the outer corner `(0, 0)`, radius 2 and three settle frames. The native replay inherits the fel-06 180-second timeout.

## Open issues

Native renderer capture and inspection are pending on the design owner's machine. The worktree contains the uncommitted implementation and proof tools.

## Feedback 1 · SubViewport input and comparison sheet

The owner’s earlier native run stopped at the first fixture while trying to park the physical pointer. Both probes now send the same motion events and enter and exit notifications directly to the SubViewport. The preview displays that texture. Each 1920×1080 capture path is printed on a line of its own, and the census still checks the picked tile, viewport position, input state, completed fades and saved combat witness.

The executable-code search across `tools/fel06/` and `tools/fel07/` found zero matches for the removed `root.warp_mouse`, `DisplayServer.mouse_get_position`, `get_screen_transform`, `_native_pointer`, `_pointer_matches` and `NATIVE_POINTER_TOLERANCE`. The native-only park and movement failure branches were removed with them.

The fel-07 runner stages the two original tooltip methods from `6203cf9aa` in an ignored probe-only subclass. The staged loot helper has a distinct name so its one-argument signature can coexist with the current method. Both runs use the same scenes, assets and input driver. The observations retain the original schema. A separate `pair_bounds.jsonl` records the projected highlight and embedded popup bounds. [Baseline staging](stage_base_tooltip.py) · [Sheet builder](pair_sheet.py)

The five rows each use the same unscaled crop on both sides. The crop encloses the highlight and popup from both captures and adds up to 24 pixels of padding where the viewport allows. The sheet uses a 20-pixel built-in label font, 34-pixel label rows and 12-pixel gutters. These values apply to proof output only.

- `tools/fel06/native.sh --dry-run` emitted `FEL06 DRY RUN PASS fixtures=12 samples=46`. [Dry-run log](../fel06/captures/dry.yImtoC/runner.log)
- `tools/fel07/census.sh --dry-run` emitted `FEL06 DRY RUN PASS fixtures=12 samples=46` for both base and branch. [Base log](captures/branch.j6JgSr/base/runner.log) · [Branch log](captures/branch.j6JgSr/runner.log)
- The staged base matched the archived base across all normalized observations. `FEL07 BASE REPLAY PASS matches_archived_observations=46`
- The fresh comparison emitted `FEL07 CENSUS base off_square=5 branch off_square=0` and `FEL07 DIFF PASS unchanged=41 popup_only=5`. [Comparison log](captures/branch.j6JgSr/comparison.log)
- The sheet check used synthetic PNGs with the recorded headless geometry and verified all five crop pairs pixel for pixel. It emitted `FEL07 PAIRS SMOKE PASS rows=5 sheet=1476x2237 source=synthetic_pngs live_bounds=92`. [Sheet check log](captures/branch.j6JgSr/pairs_smoke.log)

The production board script’s Git blob hash matched before and after this feedback. Native screenshots and the corresponding native `pairs.png` await the owner's run.
