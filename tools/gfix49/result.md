# gfix-49 · Live Gust at the Hanging Roost

The Gallows Roc's Gust reads the hero and Roc positions when it resolves. The same direction feeds the current board and battlefield HUD previews. The horizontal axis still wins a diagonal tie.

## Acceptance

1. **Resolution.** The proof walk takes the hero from `(4, 5)` to `(6, 5)` around the Roc at `(5, 4)`. The next beat Pushes the hero and both fledglings one tile west. The Anchored Roc stays in place. The same witness on `codex/release` Pushes east after the walk.
2. **Previews.** The witness checks the shared forecast, board wind and landing paths, Gust threat tiles, and the post-beat position used to start the Pass danger simulation. The walk, Blink, Swap, and ordinary Push each refresh those queries. The full RunScene dry run uses the normal movement clicks and observes the live battlefield HUD arrow and board telegraph before and after. The turn-order beat token exposes the existing rule sentence in its tooltip and has no direction value. No new hover prediction was added.
3. **Saves.** The witness writes a checkpoint through the normal save API with the hero on the east tile and the old eastbound `locked_direction` and `wind.direction`. The checkpoint loads through Continue, previews west even before the legacy-wind preparation, and resolves west after the Continue preparation. The existing save format and beat counters are reused.
4. **Controls.** All 17 unchanged case records match release byte for byte. The cases cover the stationary Roost, the opposite diagonal tie, aimed and toward-entry Gust, all four fixed directions, clockwise Gust, a Gale Herald Call, a Stormcaller Call, and six Umbral Snare variants. The comparison hashes the hex encoding of the serialized outcomes, including the committed state and beat receipts. The battlefield and Guardian suites verify the existing analytics path. The event shape, timing, and append-only writer are unchanged.

## Files

| File and lines | Change |
| --- | --- |
| `scripts/battlefield_rules/gust.gd:206–286` | Derives the live axis in the shared wind value used by projection and resolution. Keeps `locked_direction` current on prepared snapshots for the audit and retains the existing farthest-first mover. |
| `scripts/battlefield_rules/dispatcher.gd:165–175, 311–336` | Passes the engine to the shared Gust value. Keeps the pending Call forecast override on the existing modes and projects `toward_source` directly from the trial board. |
| `tests/suites/bos01_rules_suite.gd:61–99, 177–183` | Updates the previous `toward_source` witness for live aim, including Continue and a debug-only half-Health switch. The affected assertions passed on the original release contract before the change. |
| `tools/gfix49/roost_fixture.gd:1–25` | Loads the authored Hanging Roost at its real beat boundary and stages the proof opening tile. |
| `tools/gfix49/witness.gd:1–156` | Checks resolution, previews, Continue and release parity. Also invokes the focused battlefield-rules suite. |
| `tools/gfix49/native_probe.gd:1–102` | Checks the real scene and captures the two telegraphs. |
| `tools/gfix49/native.sh:1–13` and `tools/gfix49/proof_contract.json:1–8` | Launch the headless dry run or validate the two native 1920×1080 captures at 100% UI scale with `LABYRINTH_CEL_LOOK=all`. |
| `tools/gfix49/*.gd.uid:1` | Godot-generated sidecars for the three proof scripts. |
| `tools/gfix49/result.md` | Records the acceptance and proof. |

The existing board paths are `scripts/enemy_mechanics/wind_view.gd:110–160` for wind layers and paths and `scripts/battlefield_rule_view.gd:66–79` for rule threat tiles. The existing HUD arrow consumes the shared forecast at `scripts/battlefield_rule_hud.gd:79–96`. Pass calls the same activation-end dispatcher through `scripts/pass_forecast_red_tiles.gd:57–66`.

### `locked_direction` readers

- `tools/atk13/rule_audit.gd:139–152` reads the Gust lock from the prepared beat's `before` snapshot, including `toward_source`. That diagnostic and the BOS01 rules witness are why the compatibility field remains. The prepared `wind.direction` mirror also supplies the existing playback receipt in `scripts/battlefield_rules/gust.gd:178–188`.
- `scripts/battlefield_rules/gust.gd:219–257` validates and reads the aimed announcement and reads and rotates the clockwise heading. The Stormcaller and BOS01 save and forecast tests inspect those locks. Install/adoption and the pending Call projection continue to write them in the dispatcher. The half-Health dial switch clears stale locks when a held mode changes.
- The live `toward_source` branch reads the two unit tiles. Saved lock values can still be decoded by the existing save API and are refreshed at the next preparation boundary.

## Test receipts

The release witness used `codex/release` at `38a6abf322edb7d934d9ecff386a9f23612f7f73`. Its temporary project read the release versions of the changed tracked files and the same proof scripts used by the live run. The branch and index stayed in place.

```text
Release: GFIX-49 WITNESS: FAIL (39 checks, 27 failures)
Live: GFIX-49 WITNESS: PASS (39 checks, 0 failures)
GFIX-49 RELEASE COMPARISON: 17 byte-identical outcome records
GUARDIAN RULES TEST RESULT: PASS (693 checks, 0 failures)
GFIX-49 BATTLEFIELD RULES SUITE: PASS (629 checks, 0 failures)
BATTLEFIELD FUEL TEST RESULT: PASS (78 checks, 0 failures)
BOS01 RULES TEST RESULT: PASS (421 checks, 0 failures)
BOS01 AIMED SWITCH TEST: PASS (switched=true, error=)
BOS01 ROUTE CASE REPORT: PASS (3 existing Thornmother fixtures and relocated-source held line)
BOS01 RULE SCENE RESULT: PASS (170 checks, 0 failures)
EL04 RULE VIEWS RESULT: PASS (0 failures)
SPX07 WIND LOCK RESULT: PASS (114 checks, 0 failures)
Snare suite: 0 failures
SELECTED MODULES: 23 of 59
Ran 196 tests in 32.955s
OK
PASS: Rules text lint (16 existing hits)
Ran 25 tests in 5.809s
OK
GFIX-49 NATIVE STATE hero=(4, 5) wind=(1, 0) arrow=(0.894427, 0.447214)
GFIX-49 NATIVE STATE hero=(6, 5) wind=(-1, 0) arrow=(-0.894427, -0.447214)
GFIX-49 NATIVE DRY RUN: PASS (0 failures)
```

The standalone program logs use `/private/tmp/gfix-49-<program-stem>.log`. The comparison and scene logs are `/private/tmp/gfix-49-release-witness-final.log`, `/private/tmp/gfix-49-live-witness.log`, `/private/tmp/gfix-49-battlefield-rules-suite.log`, and `/private/tmp/gfix-49-native-dry-run.log`. The Python group and UI identity lint logs are `/private/tmp/gfix-49-python-default.log` and `/private/tmp/gfix-49-ui-identity.log`. The Python runner passed and reported that it could not update its optional timing cache in the read-only Git metadata. Godot printed a macOS system CA lookup message on both release and live runs.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-49 && tools/gfix49/native.sh
```

The native run prints each absolute PNG path. Inside its isolated Godot profile the capture paths are `user://probes/gfix49/01_gust_before_step.png` and `user://probes/gfix49/02_gust_after_step.png`. The sandbox ran the scene dry run with `tools/gfix49/native.sh --dry-run`. Native rendering and inspection are pending on a window-server session.

## Chosen defaults

- The proof uses the existing Guardian inspection seed `7262026`. The opening walk crosses two tiles south of the Roc. The separate tie control uses the other diagonal. The Swap study stages one fledgling on the east tile so the real Swap action can target it.
- The scene probe reuses the Guardian probe's `0.28`-second settle. The capture viewport and UI scale come from the brief. Proof save and image paths are isolated under `user://`.

## Design placeholders and open issues

No new `TODO_DESIGN_*` placeholders. The authored rule and tooltip text are unchanged. The native captures are the remaining proof. All changes are uncommitted.
