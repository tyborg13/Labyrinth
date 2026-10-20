# sfx-05 implementation handoff

Changes are uncommitted on `codex/sfx-05`. No branch change, commit, push,
peer review, signoff, task-queue update, inspection fixture or windowed run
was performed. The design owner owns those later workflow steps.

## Feedback 1 / numbered requirements

1. Rebuilt the director's updated A recipes through design → index → slice →
   features → build. The recipe is protected and was not edited by the worker;
   its SHA-256 remains
   `4f258da6558ffe80b4d57a32b173a3890c0543cc393afd4b2fb82e51a884a6f7`.
   Both `onset_note` fields remain verbatim in the recipe and retained design
   sidecars. The uncharge design matches the director's `dd180dd9…` hash:
   `dd180dd9a2bf31b70475a18bd71d674b12fbf162559e5732c61e0e5c39709d71`.
   Charge's designed hash is
   `807989c208acbe078dccf4e67c424ff320dec459172c63b25079bf7ff0929279`.
   Refreshed approval take IDs, OGGs, supplementary build manifest, transitive
   licence/source provenance, registry gains and hash-bound sample fixtures.
   Category remains `card`; licences remain Sonniss GDC Bundle licence for
   charge and CC0-1.0 for uncharge. Mix targets remain -24.000/-30.000 LUFS
   using the existing 400 ms maximum policy, exactly 6.000 LU apart.
   Playback offsets are measured -0.6943642465005659/-5.514149796205942 dB.
   The short uncharge follows the pipeline's existing peak normalization and
   the mix policy's zero-padding to 400 ms. Both `TODO_DESIGN_sync_policy`
   fields are removed. No head alignment, policy exception or cap change was
   introduced. Original sfx-04 manifests/provenance and all 81 prior cue
   entries/levels remain unchanged.
2. Authorized routing edits are three guard replacements in `run_scene.gd`
   and the blocked-signal filter in `card_widget.gd`. `can_attempt()` retains
   every existing guard except health, while `available()` still rejects
   blocked health for the existing prompts and visuals. The shared toggle
   sends a blocked attempt to `card.invalid` and returns before changing any
   charge state, preview or toggle analytics. The routed seal/E/RS tests each
   observe exactly `["card.invalid"]` for one blocked attempt and no Empower
   cue. They assert input-frame playback, unchanged blocked/tooltip state,
   immediate-repeat suppression, suppression at 199 ms and playback at the
   existing 200 ms boundary, using a fixed bank clock. Healthy charge/uncharge
   routing, reduced motion and silent automatic clears still pass. Added a
   fixed-clock blocked case for the new cue call site.
3. Reran all focused checks from the original handoff, plus the existing card
   keyword/Empower/tooltip suite for the changed input guards. The complete
   sync trace now runs with `--assert-onsets`, followed by the sync audit with
   `--check`. Every timing, playback and coverage check passes.

| Cue | Input → play | First sample | Perceived RMS onset | First RMS peak after input |
|---|---:|---:|---:|---:|
| empower.charge | 0 ms | 1.521 ms | 20.104 ms | 24.917 ms |
| empower.uncharge | 0 ms | 1.813 ms | 12.229 ms | 17.479 ms |

The approved recipe trim resolves both previous timing violations. Existing
first-sample, perceived-onset and peak limits are unchanged.

## Observed verification

Current logs/reports are under `output/sfx/sfx-05/feedback-1/` (gitignored).
All commands below completed with exit 0.

- `asset-tests.log`: `Ran 3 tests in 0.007s` / `OK`.
- `sound-lab-tests.log`: `Ran 39 tests in 22.825s` / `OK`.
- `sync-tests.log`: `Ran 18 tests in 2.370s` / `OK`;
  `SFX04 BUILD RESULT: PASS (0 rebuilt; 82 verified hashes)`.
- `routed-test-final.log`: `EMPOWER SFX TEST RESULT: PASS (0 failures)`.
  Healthy mouse/keyboard/controller each report charge then uncharge with
  reduced motion false/true. Blocked paths report:
  `EMPOWER BLOCKED SFX mouse: ["card.invalid"]`,
  `EMPOWER BLOCKED SFX keyboard: ["card.invalid"]`,
  `EMPOWER BLOCKED SFX controller: ["card.invalid"]`.
  Play/discard/burn/turn_end each report `0 toggle cues`.
- `bank-test.log`: `SFX BANK TEST RESULT: PASS (0 failures)`.
- `sync-bank-test.log`: `SFX AUDIO LENGTHS: 85 Godot streams compared with decoded PCM`;
  `SFX SYNC BANK TEST RESULT: PASS (0 failures)`.
- `card-keywords-test.log`: `CARD KEYWORDS TEST RESULT: PASS`;
  `EMPOWER TOOLTIP EXCLUSIVITY charged=true body_active=true body_modified=true`;
  `EMPOWER TOOLTIP ISOLATED offered=true charged=true desktop_input_isolated=true`.
- `sync-harness.log`: `SFX SYNC HARNESS RESULT: PASS (9417 observations, 0 failures)`.
  Includes onset assertions, five frame profiles and six effective speeds.
- `sync-audit.log`:
  `SFX SYNC AUDIT: PASS {"cue_call_site_rows": 140, "cues": 83, "loudness_exceptions": 2, "observations": 9417, "overlong_variants": 0, "registry_cues": 83, "uncovered_call_sites": 0, "uncovered_cue_call_site_pairs": 0, "unmeasured": 0, "violations": 0}`.
  Full report: `output/sfx/sfx-05/feedback-1/sync_audit.{json,md}`.
  The two old sfx-04 loudness exceptions remain unchanged; this unit adds none.
- `probe-validation.log`:
  `EMPOWER SFX PROBE RESULT: PASS (0 failures; validate_only=true)`.
  Cue trace, with no renderer captures claimed:
  `/private/tmp/labyrinth-godot-home/sfx-05-1792512823035157000-94918/Library/Application Support/Escape the Umbra Parallel sfx-05-1792512823035157000-94918/empower_sfx_probe/1920x1080_ui100/cue-events.json`.
- `registration.log`: `TEST REGISTRATION AUDIT: PASS (761 scripts; full suite=415, quarantined=29, windowed probe=317)`.
- Preservation check:
  `SFX05 FEEDBACK-1 PRESERVATION: PASS (81 prior cues, sync rules, prior manifests/provenance and targets unchanged; director recipe unchanged; no alignment or exception)`.
- `git diff --check`: exit 0.

Focused tests only, as requested. Full Python/Godot suites were not run.
Non-failing macOS certificate lookup and ObjectDB leak diagnostics remain in
some headless engine logs. All feedback-1 assertions passed without changing
any existing master assertion.

## Reproduction commands

Run from this worktree. No source root or owner recipe is modified.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-05
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-05 && /Users/borgerding/.cache/umbra-sfx/venv/bin/python tools/sfx_lab/design.py --recipes spec/peer_benchmark/staged/sfx/recipes_empower.json --features /Users/borgerding/workspace/Labyrinth/output/sfx-lab-index-2026-10-20/features.jsonl --out-root output/sfx/sfx-05/feedback-1/design --only empower.charge empower.uncharge
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-05 && /Users/borgerding/.cache/umbra-sfx/venv/bin/python tools/sfx_lab/index.py --sources output/sfx/sfx-05/feedback-1/design --out output/sfx/sfx-05/feedback-1/analysis/index.json --workers 2
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-05 && /Users/borgerding/.cache/umbra-sfx/venv/bin/python tools/sfx_lab/slice.py --index output/sfx/sfx-05/feedback-1/analysis/index.json --out output/sfx/sfx-05/feedback-1/analysis/takes.jsonl --workers 2
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-05 && /Users/borgerding/.cache/umbra-sfx/venv/bin/python tools/sfx_lab/features.py --index output/sfx/sfx-05/feedback-1/analysis/index.json --takes output/sfx/sfx-05/feedback-1/analysis/takes.jsonl --out output/sfx/sfx-05/feedback-1/analysis/features.jsonl --workers 2
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-05 && /Users/borgerding/.cache/umbra-sfx/venv/bin/python tools/sfx_lab/build.py --approved spec/peer_benchmark/staged/sfx/approved_empower.json --features output/sfx/sfx-05/feedback-1/analysis/features.jsonl --out-dir assets/audio/sfx/cues --manifest spec/assets/sfx/manifest_empower.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-05 && /Users/borgerding/.cache/umbra-sfx/venv/bin/python tests/test_empower_sfx.py -v
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-05 && /Users/borgerding/.cache/umbra-sfx/venv/bin/python tests/test_sfx_lab.py -v
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-05 && /Users/borgerding/.cache/umbra-sfx/venv/bin/python tests/sfx_sync_test.py -v
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-05 && python3 tools/godot_task_runner.py --task-id sfx-05 --stream -- godot --headless --path . --script tests/empower_sfx_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-05 && python3 tools/godot_task_runner.py --task-id sfx-05 --stream -- godot --headless --path . --script tests/sfx_bank_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-05 && python3 tools/godot_task_runner.py --task-id sfx-05 --stream -- godot --headless --path . --script tests/sfx_sync_bank_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-05 && python3 tools/godot_task_runner.py --task-id sfx-05 --stream -- godot --headless --path . --script tests/sfx_sync_harness.gd -- --assert-onsets --output=res://output/sfx/sfx-05/feedback-1/full-trace.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-05 && /Users/borgerding/.cache/umbra-sfx/venv/bin/python tools/sfx_sync_audit.py --trace output/sfx/sfx-05/feedback-1/full-trace.json --report output/sfx/sfx-05/feedback-1/sync_audit.json --check
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-05 && python3 tools/godot_task_runner.py --task-id sfx-05 --stream -- godot --headless --path . --script tests/card_keywords_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-05 && python3 tools/godot_task_runner.py --task-id sfx-05 --stream -- godot --headless --path . --script tests/empower_sfx_probe.gd -- --validate-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-05 && python3 tools/test_registration_audit.py
```

The audit's `--trace` mode is intentional: its default launch hardcodes task ID
sfx-04. This unit launches the trace through the required sfx-05 runner instead.

## Proof for the design owner

Not run: this sandbox has no macOS window-server access. The script records
charge → uncharge → charge through real seal input in the existing isolated
capture viewport. The root is 1920×1080 at 100% UI scale. MovieWriter records
its mixed sound track even with the Dummy playback driver.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-05 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --godot ./tests/sfx05_movie_godot.sh --timeout 120 --expect-size 1920x1080 --proof-contract tests/proof_contracts/empower_sfx.json --result-manifest output/sfx/sfx-05/feedback-1/movie-manifest.json tests/empower_sfx_probe.gd --task-id sfx-05
```

Expected clip: `output/sfx/sfx-05/empower-toggles.avi` (60 fps, audio included).
Expected stills in the task-isolated `user://empower_sfx_probe/1920x1080_ui100/`:
`charge.png`, `uncharge.png`, `charge_again.png`, plus `cue-events.json`.
The validated manifest records the actual absolute capture paths.
Listen to the clip and inspect its audio stream:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-05 && ffprobe -v error -select_streams a:0 -show_entries stream=codec_name,sample_rate,channels -of json output/sfx/sfx-05/empower-toggles.avi
```

No `inspection_fixture.py` command is requested by the brief; fixture preparation
belongs to the design owner.

## Chosen defaults

Feedback 1 adds only the named test clock `BLOCKED_CLOCK_MS = 10000.0`,
following the existing sync fixture convention. Blocked HP 2 reuses the
existing keyword fixture's health cost; cooldown comes from the unchanged
registry value. No player-facing value was chosen.

Only test/proof/internal values were chosen: fixture seeds 60501/60502;
settling 5 frames in live tests and 12 frames in the probe; 72-frame proof holds;
60 fps capture; proof-only music volume 0; 120 s movie-writing timeout;
0.05 LU asset-test mix tolerance; 2 pipeline workers. The proof contract reuses
the existing ui-03 hand region `[450,650,1050,420]`, luma range 65 and standard
deviation 10. Existing SfxBank defaults supply zero pitch jitter, zero cooldown
and one oldest-stealing voice per new cue. No new production tuning was chosen.

## Files changed

- `scripts/card_empower_controller.gd`, `scripts/run_scene.gd` (three input guards),
  `scripts/card_widget.gd` (one signal guard), `data/sfx_cues.json`.
- `spec/peer_benchmark/staged/sfx/recipes_empower.json` is a director-owned
  uncommitted edit; the implementation preserved its bytes and notes.
- `assets/audio/sfx/cues/empower.{charge,uncharge}/empower.{charge,uncharge}_01.ogg`,
  `assets/audio/sfx/empower-design-provenance.json`.
- `spec/peer_benchmark/staged/sfx/approved_empower.json`,
  `spec/peer_benchmark/staged/sfx/mix_targets.json`,
  `spec/assets/sfx/manifest_empower.json`.
- `tests/empower_sfx_test.gd`, `tests/suites/empower_sfx_suite.gd`,
  `tests/suites/empower_seal_suite.gd`, `tests/suites/empower_sfx_sync_cases.gd`,
  `tests/sfx_sync_{harness,sources,coverage}.gd`,
  `tests/fixtures/empower_sfx_samples.json`, `tests/test_empower_sfx.py`.
- `tests/empower_sfx_probe.gd`, `tests/sfx05_movie_godot.sh`,
  `tests/proof_contracts/empower_sfx.json`, `tests/windowed_test_allowlist.json`,
  this handoff.

## TODO_DESIGN placeholders / open issues

None remain. Windowed listening/capture, commit, peer review, inspection fixture
and publication remain assigned to the design owner. No windowed run was tried.
