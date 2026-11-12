# rd-05 observed verification

Implementation is uncommitted. Native rendering and visual judgment remain with
the design owner. Exact owner commands and the numbered acceptance mapping are
in [README.md](README.md).

Observed checks:

- Real-save plate proof: `RD05 PLATE VISIBILITY: PASS (103 checks, 0 failures)`.
  Includes exact single/area/reachable-strike/self sets, all hover paths,
  pointer-exit/focus continuity, Steam Deck controller navigation, Details,
  change timing, switching, stable intent geometry and rail health numerals.
- Settings: `TEST RESULT: PASS` from the existing settings test, including the
  new permanent legacy/default/round-trip check.
- Focused existing checks: `RD05 FOCUSED: FAIL (75377 checks, 2 failures)`.
  A matched read-only HEAD baseline reports
  `RD05 BASELINE: FAIL (75372 checks, 2 failures)`. Both failures are the same
  existing assertion, once each for rail and landing-strip portraits:
  `Umbra keeps the still Unknown Presence texture`. No assertion was changed.
  The narrower baseline cache+rail invocation passes (2656 checks); the failure
  depends on the broader suite's asset-cache ordering.
- UI identity: `Ran 25 tests in 8.750s` / `OK`. No baseline increase or new
  colour literal was introduced.
- Python resource audit: passed for 56 discovered modules. No new Python test
  module was added; the task-local Python tools are outside test discovery.
- Python default group: 20 selected modules, `Ran 189 tests in 64.576s` /
  `FAILED (failures=2)`. Failures were the approved-content Godot smoke startup
  (30s timeout) and runner cancellation child startup (`Child did not start`).
  Isolated reruns of those unchanged modules subsequently passed:
  `Ran 1 tests in 12.485s` / `OK`, and `Ran 15 tests in 7.761s` / `OK`.
  Assertions and timeouts were unchanged. The runner also reported its expected
  inability to write the untracked timing cache under the shared read-only Git
  metadata directory; implementation work continued.
- Both inspection manifests reported `Inspection fixture verified.` They are
  `/private/tmp/labyrinth_codex/rd-05/inspection.json` (five foes) and
  `/private/tmp/labyrinth_codex/rd-05/zekarion.json`.
- Native capture script parsed via Godot `--check-only`. Shell/Python/JSON tool
  syntax and `git diff --check` passed. No windowed command was run.

The plate proof writes `/private/tmp/labyrinth_codex/rd-05/proof.json` with exact
redraw request counts for each setting and all failure/evidence records. Idle
frames add zero visibility invalidations. Full logs, audit reports, and targeted
Python rerun reports are under that same task output directory.

Final checks after the last implementation change:

- `RD05 PLATE VISIBILITY: PASS (103 checks, 0 failures)` (`proof-release.log`).
- `RD05 HIT PATH: PASS (120 frames at 30fps, 0 failures)` (`hit-release.log`).
  This is a headless real-time 30fps-cap input/commit check, not native movie
  evidence. It selects Dull Bolt, chooses the foe, uses the production Confirm
  action, and observes actual HP loss, health ghost, visibility and fade.
- Native capture parser: runner exit 0 (`capture-final.log`).

Earlier fixed-FPS headless hit attempts were rejected because live presentation
uses wall time without MovieWriter. The final headless hit probe uses a real-time
30fps cap. Native capture keeps the existing MovieWriter frame clock at 30fps.
No failed native launch was attempted or retried.

Final idle redraw-request counts (Always / On hover and aim):

```json
[
  {
    "ambient": 60,
    "foreground": 60,
    "ground": 17,
    "hud": 60,
    "overlays": 60,
    "scene_tile": 132
  },
  {
    "ambient": 60,
    "foreground": 60,
    "ground": 17,
    "hud": 60,
    "overlays": 60,
    "scene_tile": 132
  }
]
```
