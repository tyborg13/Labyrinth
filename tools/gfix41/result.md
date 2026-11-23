# gfix-41 verification

Candidate 7 at `647b49092`, Godot 4.6.1, low-risk teardown and fixture changes.

## 1. Title quick-quit

On candidate 7, the title starts a root-owned threaded run-scene request at `scripts/menu_run_preload.gd:90–109`. The managed drain passed the 250 ms cutoff from `53df4e89e` at `scripts/application_shutdown.gd:176,193`. `scripts/menu_run_preload.gd:152–165` skipped the idle request after that cutoff, and the managed-exit branch skipped the fallback collection at `scripts/application_shutdown.gd:205–208`. Those are pre-change line numbers. The probe found the request still in the root's pending dictionary at tree exit, immediately before Godot reported a failed compile or scene parse. The same resource loaded successfully when the probe waited for completion.

Managed quit now waits for the root-owned request to finish and collects its token before allowing tree exit. Collection still follows the existing idle-load terminal-status check on a later frame. The application dismisses the native window at the existing point and uses the existing 2.5 s cleanup watchdog while waiting in the background. Changed ranges are `scripts/application_shutdown.gd:20–22,170–194,199–206` and `scripts/menu_run_preload.gd:2–4,152–162`. The direct engine-stop path still uses its bounded collector.

### Headless matrix

Three fresh processes per row. Offsets are measured from the first observation of an accepted preload and are given as observed before / after. Pending counts are the number of processes with a request still registered at tree exit. Error counts include every teardown `ERROR:` or `SCRIPT ERROR:` line.

| Quit phase | Offset before / after | Pending before → after | Teardown errors before → after | Root exit after quit, before / after |
| --- | --- | ---: | ---: | --- |
| Title ready, Quit button | Before the request | 0 → 0 | 0 → 0 | 51–123 ms / 53–120 ms |
| Pending, Quit button | 0 / 0–1 ms | 3 → 0 | 12 → 0 | 269–273 ms / 1,783–1,916 ms |
| Pending, window close signal | 26–28 / 27–29 ms | 3 → 0 | 12 → 0 | 261–267 ms / 1,733–1,914 ms |
| Pending, Quit button | 76–78 / 77–78 ms | 3 → 0 | 12 → 0 | 262–277 ms / 1,702–1,855 ms |
| Pending near completion, Quit button | 1,502 / 1,501–1,508 ms | 3 → 0 | 6 → 0 | 261–266 ms / 222–627 ms |
| Load complete, Quit button | 1,802–1,928 / 1,703–2,686 ms | 0 → 0 | 0 → 0 | 33–125 ms / 97–122 ms |

The four pending phases produced 42 teardown error lines before the fix. All 12 of those processes logged an ObjectDB leak warning and failed the runner check. All 18 patched processes armed, completed the drain, exited 0 and printed `pending=[]`. Every process also logged the macOS certificate lookup diagnostic at startup `ERROR: Condition "ret != noErr" is true. Returning: ""` from `get_system_ca_certificates`. The matrix records it separately from teardown errors.

The early baseline phases produced these exact error lines. The near-completion phase produced the last two lines, with one reference to scene line 288 instead of 18.

```text
SCRIPT ERROR: Parse Error: Could not preload resource file "res://scenes/card_widget.tscn".
          at: GDScript::reload (res://scripts/run_scene.gd:134)
ERROR: Failed to load script "res://scripts/run_scene.gd" with error "Parse error".
ERROR: Parse Error: Failed. [Resource file res://scenes/run_scene.tscn:18]
ERROR: Failed loading resource: res://scenes/run_scene.tscn.
```

- `GFIX41 STRESS: FAIL (15 processes)` [Baseline](/private/tmp/labyrinth_codex/gfix-41/quit-before/results.json)
- `GFIX41 STRESS: FAIL (3 processes)` [Baseline near completion](/private/tmp/labyrinth_codex/gfix-41/quit-near-end-before/results.json)
- `GFIX41 STRESS: PASS (18 processes)` [Patched matrix](/private/tmp/labyrinth_codex/gfix-41/quit-after/results.json)

## 2. Combat feel fixtures

`54b05c508` added the instrumentation flag read at `scripts/combat_pacing.gd:318`. The production default is `false` at `scripts/run_scene.gd:1380`. Adding the same Boolean to both stubs removes the invalid `bool(null)` calls.

The surface failure was a stale fixture. `f5bfbb1aa` added the Fire feedback helper call at `scripts/combat_pacing.gd:702`. `scripts/status_tick_feedback.gd:28` types the owner as `Control`, so the prior fixture's `Node` failed at the call boundary even for the Ice event used by the test. `FixtureOwner` now extends `Control` like RunScene. The same surface and popup assertions now exercise the overlap and retirement paths. Changed ranges are `tests/suites/combat_feel_suite.gd:38–42` and `tests/suites/combat_pacing_regression_suite.gd:29–33`.

| Focused combat check | Candidate 7 | Patched |
| --- | --- | --- |
| `SCRIPT ERROR: Invalid call. Nonexistent 'bool' constructor.` | 29 | 0 |
| `SCRIPT ERROR: Invalid type in function 'enemy_fire_start_losses'` | 1 | 0 |
| `ERROR: Surface lifetime fixture starts actual overlapping feedback` | 1 | 0 |
| Floating combat text | `FLOATING COMBAT TEXT TEST RESULT: FAIL` | `FLOATING COMBAT TEXT TEST RESULT: PASS` |
| Combat feel | `COMBAT FEEL TEST RESULT: FAIL` | `COMBAT FEEL TEST RESULT: PASS` |
| Runner exit | 1 | 0 |

Both combat feel runs emitted the pre-existing `WARNING: ObjectDB instances leaked at exit (run with --verbose for details).` The title matrix after the fix had zero such warnings. [Combat baseline](/private/tmp/labyrinth_codex/gfix-41/combat-feel-before-verified.log) · [Combat after](/private/tmp/labyrinth_codex/gfix-41/combat-feel-after.log)

## 3. Test inventory

The adapted QA-124 probe, its driver and a native capture contract live in `tools/gfix41/` for on-demand proof. Existing suite registrations and assertions are unchanged. Git changes remain uncommitted.

### Other verification

- `python3 tests/test_ui_identity_lint.py` printed `Ran 25 tests in 4.182s` and `OK`. [Log](/private/tmp/labyrinth_codex/gfix-41/ui-identity.log)
- `python3 tests/test_rules_text_lint.py` printed `Ran 3 tests in 0.055s`, `OK` and `PASS: Rules text lint (16 existing hits)`. [Log](/private/tmp/labyrinth_codex/gfix-41/rules-text.log)
- The Python default-group runner printed `INPUT GROUP default: always run`, `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 31.725s` and `OK`. The sandbox denied the optional learned timing-cache write to Git metadata after the checks passed. [Log](/private/tmp/labyrinth_codex/gfix-41/python-default.log) · [Summary](/private/tmp/labyrinth_codex/gfix-41/python-default/summary.json)
- The additional startup-fade case printed `GFIX41 QUIT TEST RESULT: PASS (startup, managed drain complete)` and exited 0. The loading-cover case reached the watchdog and returned 247 on the patched run, its isolated retry and the candidate-7 replay. All three cover runs recorded zero teardown errors. [Startup](/private/tmp/labyrinth_codex/gfix-41/quit-adjacent/startup-01.log) · [Cover after](/private/tmp/labyrinth_codex/gfix-41/quit-cover-recheck/cover-01.log) · [Cover baseline](/private/tmp/labyrinth_codex/gfix-41/quit-cover-baseline/cover-01.log)
- The existing gfix-14 fault-injection probe printed `GFIX14 DEADLINE: requested quit with load delayed 30000 ms`. The deliberately stalled worker triggered the watchdog, with runner exit 247. [Log](/private/tmp/labyrinth_codex/gfix-41/watchdog.log)

The original cache lacked 48 generated texture artifacts. The verified baseline and patched checks used artifacts from the matching candidate cache after verifying the source and import-sidecar bytes for each texture.

## Proof for the design owner

The native run records the first rendered title frame, then samples the same quit phases. The contract checks the 1920×1080 PNG and the probe sets UI scale to 100%. Capture paths are `$gfix41_native/gfix41-title-<case>.png`, with a validation manifest per case. This command requires a macOS window-server session.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-41
gfix41_native=$(mktemp -d /private/tmp/labyrinth_codex/gfix-41-native.XXXXXX)
for quit_case in title idle-load idle-load-close idle-load-late idle-load-near-end idle-loaded
do
  python3 tools/visual_probe_runner.py --task-id gfix-41 --no-headless \
    --display-driver macos --audio-driver Dummy --expect-size 1920x1080 \
    --proof-contract tools/gfix41/title_proof.json \
    --result-manifest "$gfix41_native/$quit_case.json" tools/gfix41/quit_entry.gd -- \
    "--case=$quit_case" "--capture=$gfix41_native/gfix41-title-$quit_case.png"
done
```

## Chosen defaults

The test harness samples 0, 25, 75 and 1,500 ms after observing the accepted preload. It runs three repetitions per case, one process at a time, with a 40 s process timeout and the inherited 20 s phase deadline. The copied fixture seed is 83 and the frame cap is 120 fps. The native image contract uses full-frame luma range ≥20 and standard deviation ≥3 to reject blank captures.

## Open issues

Native capture and inspection are pending a macOS window-server session. The candidate-7 loading-cover watchdog exit and combat feel leak warning are reproducible outside the title fix. No `TODO_DESIGN_` placeholders were needed.
