# tip-05 implementation handoff

Latest: [feedback 1 terrain-paint fix](TIP05_FEEDBACK1.md). The initial handoff below is historical.

All changes are uncommitted in `codex/tip-05`. The design owner retains commit,
peer review, inspection and publication. No windowed command or full suite ran.
No art, audio, fonts, gameplay, AI, analytics, saves or authored rule dials changed.

## Acceptance criteria

1. **One Upheaval rule-panel loop.** Added `rule_upheaval`, existing glossary term
   `upheaval`, source `{"kind": "battlefield_rule", "id": "upheaval"}`.
   The existing HUD factory attaches it. The original panel sentence and tooltip
   copy are unchanged. Media is deliberately absent until the native recording.
2. **The approved script through real rules and presentation.** A 4x3 open stone
   patch uses the production earth biome (`tharokh`). Hero `(0,2)`, Crawler `(2,2)`.
   The unchanged `snare_earth` instance and exit-lane selector mark the Crawler;
   one dispatcher beat raises its 3-HP Outcrop and selects landing `(3,2)`.
   The hero's complete record is unchanged. Playback calls the existing
   `_animate_surface_change`, which delegates to uph-01's production throw.
   This plain-floor landing causes no damage, so no landing number is invented.
   The recorder retains the production Snare mark while masking other HUD.
3. **Limits and exclusions.** Existing 30 fps, trim, 4 px sprite-margin (plus
   existing 1 px filter allowance), 1.5 MB, 4 ms opening, 10 s release, reduced
   motion and provenance gates are preserved. New source hashes cover the fixture,
   checks, HUD, Snare selectors/views and throw. All catalog enemy sources are
   rejected both by lookup and actual tooltip factories, with available temporary
   proof media. Grub Erupt still resolves to `marked_burrow_grub`. The unchanged
   two-card equipment factory remains loop-free for all 46 applicable equipment.
4. **Proof and handoff.** All sixteen semantic/rehearsal scripts pass headlessly.
   Added a 31-image native capture contract, including Upheaval start/middle/end
   and reduced motion. Native frames, size and performance acceptance await the
   design owner's window server. No permanent tests or dependencies were added.

## Observed results

```text
TIP01 SEMANTICS RESULT: PASS (0 failures)
TIP01 REHEARSAL RESULT: PASS (0 failures)
TIP03 DESIGN PENDING: 0 loops (excluded from recording)
TIP05 ALL-LOOP AUDIT: PASS (16 loops; every sampled sprite >=4 px; lead <=0.4 s; tail <=0.2 s; all landings inside patch)
TIP02 PLAYBACK rule_upheaval: PASS (37 frames at 30 fps; 1.233 s; speed=normal)
TIP04 RULE OWNERSHIP: PASS (all enemy sources rejected; rule HUD; unchanged copy; five rule HUD routes)
TIP01 TOOLTIP SEMANTICS: PASS (0 failures)
TIP05 TWO-CARD GEAR: PASS (46 equipment, 0 failures)
SPL01 SEMANTICS: PASS (17 checks, 0 failures)
GLOSSARY TEST RESULT: PASS (6525 checks, 0 failures)
SHORT CARD TOOLTIPS TEST RESULT: PASS (767 checks, 0 failures)
FLOATING COMBAT TEXT TEST RESULT: PASS (0 failures)
COMBAT FEEL TEST RESULT: PASS
TIP05 STATIC: PASS (Python AST; 16 registry rows; 31 capture images; existing registry/media, gear, rules and throw unchanged)
```

Upheaval rehearsal evidence:
`/private/tmp/labyrinth_codex/tip-05/all-loops/rule_upheaval_timing.json`.
The mark, airborne pose, Outcrop and arrival were all observed. Landing is
`(3,2)` and inside the patch. Lead is 0.366667 s; settled tail is 0.033333 s.
Minimum sampled margins: hero 16.269 px, Crawler 31.000 px (including flight),
production landing ghost 31.000 px. These are geometry/timing observations,
not native pixel acceptance. All-loop index:
`/private/tmp/labyrinth_codex/tip-05/all-loops/summary.json`.

Focused Python results, all exit 0 / `OK`:

- UI identity: `Ran 25 tests in 5.711s`.
- Icon identity: `Ran 10 tests in 0.128s`.
- Approved content manifest: `Ran 1 test in 15.430s`.
- Resource audit: `ISOLATION AUDIT: 56 modules; /private/tmp/labyrinth_codex/tip-05/python-audit/isolation-audit.md`.

Godot sidecar validation, including untracked fixture/check scripts, emitted:
`TIP05 GODOT SIDECARS: PASS (working-tree inventory includes new fixture/check scripts)`.

Both Python wrappers' `--check-only` exited 0. Python AST/JSON checks and
`git diff --check` passed. Existing media/sidecars, the gear factory, production
throw, rule data and `run_scene.gd` were compared byte-for-byte against HEAD.

The initial rehearsal failed because the offline Snare objective lacked required
metadata; it was fixed using the production objective factory and rerun cleanly.
The first Splits command omitted `LABYRINTH_CEL_LOOK=all` and failed its existing
`Cel look enabled` assertion; the corrected command passed. No assertion was
weakened. Existing macOS CA-certificate messages and glossary missing-definition /
intentional overflow warnings appeared; the final focused checks exited 0.

## Reproduce the headless checks

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/tip-05 && LABYRINTH_CEL_LOOK=all python3 tools/godot_task_runner.py --task-id tip-05 --stream -- godot --headless --path . --script tools/tooltip_loops/record.gd -- --semantics-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/tip-05 && LABYRINTH_CEL_LOOK=all TIP01_OUT=/private/tmp/labyrinth_codex/tip-05/all-loops python3 tools/godot_task_runner.py --task-id tip-05 --stream -- godot --headless --path . --script tools/tooltip_loops/record.gd -- --rehearsal
cd /Users/borgerding/workspace/Labyrinth.worktrees/tip-05 && LABYRINTH_CEL_LOOK=all python3 tools/godot_task_runner.py --task-id tip-05 --stream -- godot --headless --path . --script tools/tooltip_loops/capture.gd -- --semantics-only
```

Other focused Godot commands use that same runner and `--headless --path .
--script`, with `tools/spl01/capture.gd` (cel look all),
`tests/glossary_test.gd`, `tests/short_card_tooltips_test.gd`,
`tests/combat_feel_test.gd`, or the temporary harnesses
`/private/tmp/labyrinth_codex/tip-05/proof/{floating_text,gear}.gd`.
Python checks: `python3 tests/test_ui_identity_lint.py`,
`python3 tests/test_icon_identity_policy.py`,
`python3 tests/test_approved_content_manifest.py`, and
`python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/tip-05/python-audit`.

## Proof for the design owner

Record only the new loop, preserving the fifteen approved existing streams:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/tip-05 && python3 tools/tooltip_loops/record.py --loops rule_upheaval
cd /Users/borgerding/workspace/Labyrinth.worktrees/tip-05 && LABYRINTH_CEL_LOOK=all python3 tools/tooltip_loops/capture.py
```

Both wrappers run through `tools/visual_probe_runner.py`, 1920x1080, 100% UI
scale. Record emits three full-size source PNGs (`rule_upheaval_source_start`,
`rule_upheaval_source_first_motion`, `rule_upheaval_source_end`, each suffixed
`_1920x1080.png`), timing/visibility JSON, raw footage, provenance and the
compression report under `/private/tmp/labyrinth_codex/tip-05/record/`.
Compression installs `assets/tooltip_loops/rule_upheaval.tlw` and its JSON sidecar
only after the existing gates pass. Native post-draw auditing measures every
unit's submitted sprite through the throw's arc, including its upper poses.

Capture opens all sixteen streams in two fresh engines (Freeze first/last), with
31 required images, including Upheaval start/middle/end/reduced-motion. It checks
size, matched cold-open cost, action-frame-only FPS, resident bound and release.
Outputs: `/private/tmp/labyrinth_codex/tip-05/capture/{freeze-first,freeze-last}/`,
including `capture-manifest.json`, `measurements.json` and
`rule_upheaval_{start,middle,end,reduced_motion}_1920x1080.png`.
No `inspection_fixture.py` command was requested by this unit's brief.

## Files changed

- `data/tooltip_loops.json`: one registry entry; existing entries unchanged.
- `scripts/battlefield_rule_hud.gd`: existing term/source mapping for Upheaval.
- `tools/tooltip_loops/tip05_fixture.gd` / UID: isolated fixture, dispatch,
  semantic checks and production playback delegate.
- `tools/tooltip_loops/tip05_checks.gd` / UID: mark/flight/arrival/number proof.
- `tools/tooltip_loops/fixture.gd`, `playback.gd`, `patch_checks.gd`, `record.gd`,
  `record_board.gd`: fixture wiring, production mark mask, continuous audit and
  provenance; task-local output defaults.
- `tools/tooltip_loops/tip04_context.gd`, `capture.gd`, `capture.py`, `record.py`:
  fifth rule ownership, sixteen-loop capture and task-local runner/output paths.
- `tools/tooltip_loops/tip05_capture_contract.json`: 31-image native contract.
- This handoff.

## TODO_DESIGN placeholders, chosen defaults and open issues

No active design TODO. The required conditional `TODO_DESIGN_rule_upheaval`
stop is in the fixture's `todo_design` field if the production landing ever
leaves the patch; it is inactive in the verified script.

Chosen defaults are offline fixture fields only: `HERO=(0,2)`, `CRAWLER=(2,2)`,
`EXIT=(3,2)`, physical entry reuses `HERO`, objective type `KILL_ALL`, exit role
`jailer`/kept open, and the already-authored hunter cap is marked exhausted to
prevent unrelated preview arrivals. `turn` advances once after the real mark
is prepared to cross its existing fuel-eligibility boundary. No dials, durations,
HP, motion, camera, crop, palette, copy, speeds or asset budgets were invented.
Task-local output roots are `/private/tmp/labyrinth_codex/tip-05/record` and
`/private/tmp/labyrinth_codex/tip-05/capture`; all watchdogs retain tip-04 values.

Open issue: new native `.tlw`/sidecar and renderer acceptance are pending the
commands above. Until recording, the production tooltip safely stays text-only.
