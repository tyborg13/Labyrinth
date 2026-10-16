# pb-01 — round 1 implementation handoff

Round 1 applies the owner's 2026-10-16 copy decision and the three coverage findings in `/private/tmp/labyrinth_codex/review/pb-01-2d8c89100.md`, against base HEAD `2d8c89100191eaa866db3fad852ed724b17ef9ec`. All round-1 changes are uncommitted. No peer review, commit, push, branch change or queue edit was performed.

## Owner decision A

Every objective now shows only its 19 px `OBJECTIVE · <TITLE>` heading, with the existing objective icon and plate. There is no secondary line for any objective and the obsolete line-spacing field has been removed.

The four shared rule strings remain verbatim. The heading owns its hover tooltip; it uses the existing `UiTooltipPanel` style and preserves the gold word-only Time token. Keyboard and controller navigation focus show the same tooltip immediately, and leaving focus or hiding the heading removes it. The heading is passive and has no activation callback. Named dragon/Guardian titles remain unchanged.

The 13-state probe now covers native heading hover, keyboard Up and controller D-pad Up reaching the heading and showing its tooltip, all objective variants, the idle strip, cropped still inspection and reduced motion. Noctyrax is now in the mixed proof roster.

The single full-suite run exposed a test startup error: its first heading was asked to grab focus during `SceneTree._initialize`, before entering the tree. The focus test now waits for attachment/layout before requesting focus. The focused runner deliberately starts during `_initialize` too; it reproduced the original failure and passes after this test-only correction. The production heading implementation did not change for this fix.

## Review findings B

1. The independent identity oracle uses the production board's explicit Script constants. Every instantiated renderer is compared by Script identity; shared Guardian instances must also have the exact `character_id`. All 43 identities are covered.
2. The SceneTree drives all idle clocks. All 32 rigged identities must advance naturally, freeze while the stage is hidden, and enter a frozen rest pose after reduced motion changes. The tests never call `_process` directly.
3. Six real, ready-initialized Crawler renderers are sampled at the same SceneTree boundary before elapsed time. Their actual snapshot phases and applied rig-pose phases must match the six authored slot fractions, be distinct, and repeat exactly across two rebuilds.
4. A scripted `Texture2D` draw virtual records the texture submitted by the actual queued CanvasItem draw callback. This proves the renderer texture is submitted with board padding and the source still is not submitted, even under the headless dummy renderer. It catches the fifth surviving mutation without relying on presentation metadata or GPU pixels.

A reusable mutation checker builds disposable resource overlays, runs the focused suite through the required Godot runner, and preserves logs. It does not modify production files.

## Files changed in round 1

- `scripts/pre_battle_view.gd`: heading-only objective; rule tooltip owned by the heading; obsolete secondary-line construction and spacing removed.
- `scripts/pre_battle_objective_heading.gd` (new): shared-style native hover and focus tooltip behavior.
- `tests/fixtures/pre_battle_view_reference.gd`: same intentional objective topology/copy change in the independent synchronous reference.
- `tests/suites/combat_objective_suite.gd`: heading/tooltip persistence expectation instead of secondary copy.
- `tests/suites/pre_battle_living_foes_suite.gd`: exact heading/tooltip expectations, focus lifecycle, Script and Guardian identity, natural clocks and actual applied phases.
- `tests/pre_battle_living_foes_test.gd`: exercise the same immediate `_initialize` startup boundary as the full suite.
- `tests/suites/live_actor_submission_suite.gd` (new): headless native draw-submission oracle.
- `tests/pb_01_mutation_check.py` (new): the five review mutations and exact expected failure checks in isolated overlays.
- `tests/pre_battle_living_foes_fixture.gd`: heading-only layout assertions and Noctyrax in the mixed debug roster.
- `tests/pre_battle_living_foes_probe.gd`: native hover and keyboard/controller heading-tooltip proof within the existing 13 captures.
- `tests/proof_contracts/pb_01_living_foes.json`: current copy/inspection criteria; preserves `expected_sizes: ["1920x1080"]`.
- `tests/pb_01_implementation_report.md`: this current handoff.

The live-actor production implementation, assets, tuning, shared descriptions, board renderers and existing performance benchmark are unchanged in this round. The owner/reviewer previously accepted the director's performance evidence; this round does not claim a new timing measurement.

## Observed verification

- `PB-01 LIVING FOES TEST: PASS (43 identities; exact objective copy; reduced-motion rest)` / `TEST RESULT: PASS` — exit 0. This also executes the complete existing combat-objective suite.
- `PB-01 MUTATION disable_renderer_processing: CAUGHT`
- `PB-01 MUTATION noctyrax_processing_disabled: CAUGHT`
- `PB-01 MUTATION wrong_noctyrax_renderer: CAUGHT`
- `PB-01 MUTATION remove_phase_seed: CAUGHT`
- `PB-01 MUTATION draw_still_for_every_cutout: CAUGHT`
- `PB-01 MUTATION CHECK: PASS (5/5 caught)` — exit 0; result JSON confirms `production_unchanged: true`.
- `PB-01 LIVING FOES PROBE LOGIC ONLY: PASS` — native hover and keyboard/controller navigation/focus checks passed headlessly; no screenshot claim.
- `PRE-BATTLE VIEW TEST: PASS` / `TEST RESULT: PASS` — original layout and input paths; exit 0.
- `PREPARED PRE-BATTLE VIEW EQUIVALENCE RESULT: {"cases":18,"errors":[],"presented":13}` — exit 0.
- UI identity lint: `Ran 25 tests in 3.537s` / `OK` — exit 0.
- `OUTPUT GDIGNORE: PASS (12 folders; 2 referenced roots)`.
- Single full Godot suite: `FULL SUITE RUNTIME: 760.394 seconds (budget 900 seconds)` / `TEST RESULT: FAIL (1 failure(s))` — exit 1. The sole assertion was `Navigation focus displays the heading's existing-style tooltip: kill_all`, caused by the test's premature focus request. Reproduced in isolation, fixed as described above, then the focused suite passed from the same immediate startup boundary. No second full run was launched, per the requested once limit; a post-fix full-suite PASS has not been observed.

Logs: `/private/tmp/pb-01-r1-focused.log`, `/private/tmp/pb-01-r1-mutation-check.log`, `/private/tmp/pb-01-r1-mutations.json` (links all five mutation logs), `/private/tmp/pb-01-r1-probe-logic.log`, `/private/tmp/pb-01-r1-view.log`, `/private/tmp/pb-01-r1-equivalence.log`, `/private/tmp/pb-01-r1-ui-lint.log`, `/private/tmp/pb-01-r1-full-godot.log`, `/private/tmp/pb-01-r1-startup-reproduction.log` (the intentionally reproduced failure before the test fix).

## Requested 13-capture rerun

Attempted once through `tools/visual_probe_runner.py`, with the 1920×1080 contract, 100% UI scale and normal startup watchdog. **The native renderer could not launch. No images were produced.** macOS returned `Connection Invalid error for service com.apple.hiservices-xpcservice`; the runner reported:

> Godot did not initialize within 8.0 seconds: .../godot.log was never created.

The failed attempt is recorded in `/private/tmp/pb-01-r1-renderer.log` and `/private/tmp/pb-01-r1-renderer.json` (`ok: false`, no images). No retry, alternate backend or watchdog extension was used.

Run this exact command in the owner's window-server-capable session; the fresh manifest path preserves the failed worker attempt:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pb-01 && python3 tools/visual_probe_runner.py --task-id pb-01 --no-headless --display-driver macos --audio-driver Dummy --min-images 13 --expect-size 1920x1080 --proof-contract tests/proof_contracts/pb_01_living_foes.json --result-manifest /private/tmp/pb-01-r1-owner-renderer.json tests/pre_battle_living_foes_probe.gd
```

Expected captures, under the runner's printed isolated `user://probes/pb_01_living_foes/` folder:

- `mixed_idle_00.png` through `mixed_idle_03.png` (includes Noctyrax).
- `objective_kill_leader.png` (native hover), `objective_survive.png` (keyboard focus), `objective_reach_exit.png` (controller focus), `objective_dragon.png`, `objective_guardian.png`.
- `controller_focus.png`, `inspection_still.png`, `reduced_motion_00.png`, `reduced_motion_01.png`.
- `witnesses.json` records per-slot production snapshots.

## Chosen defaults / design placeholders

No TODO_DESIGN placeholder remains: the owner removed the secondary line, so its spacing field is obsolete. The focus tooltip reuses the existing tooltip style, Omen focus-tooltip layer (2201), and Chronicle-style edge-aligned below/above placement; no new font, color, spacing or animation tuning was introduced.

Test-only defaults: three natural SceneTree process frames per observation and before focus requests, phase tolerance `0.000001`, a 1000×100 objective test container, six Crawler phase slots and two rebuilds. Existing 206×365 foe test geometry is retained. The mixed debug roster replaces Ash Hound with Noctyrax. Native hover uses the existing probe's 3000 ms deadline / 0.05-second polling pattern. Mutation subprocess timeout is 330 seconds around the mandatory runner's unchanged 300-second default. The existing four frames at 0.2-second intervals and proof image regions/luma thresholds remain unchanged.

## Open issues

- Fresh round-1 renderer captures and visual inspection require the owner's window-server-capable session. Headless checks and command preparation do not substitute for these images.
- The requested single full run failed on the new test's startup ordering. That ordering is corrected and the focused suite passes; the final tree has not had another full run.
- The retained old `tests/pre_battle_preview_probe.gd` named-boss `KILL THE LEADER` assertion was already present on the reviewed base and remains unchanged; the new probe verifies current named objectives.
- Commit/publication and further peer-review workflow remain with the owner, as instructed.
