# purge-04 implementation handoff

Only `scripts/magic_purge_overlay.gd` changes production behavior. The other files in this directory are one-off proof tooling, not permanent tests. No Git writes, peer review, task-queue changes, new assets, dependency changes, or design decisions were made.

## Acceptance and root cause

1. **Reproduction:** reproduced through the actual Scavenger confirm/save/commit path headlessly before editing production code. Native reproduction remains for the owner: this worker has no window server. The table below measures canvas geometry, not rendered pixels.
2. **In-place burn:** every measured card-support rect in the headless matrix (1920×1080 / 1280×800, 100% / maximum supported 125%, normal / reduced motion, scrolled overflow list) differs by at most 0.000061 px after the fix. Native pixel inspection remains required.
3. **Preserve effect:** shader, card SubViewport placement, durations, ease, noise, char, ember colors, spark origin/birth/drift, reduced-motion fade, sound, and gameplay continuation are untouched. The only runtime change sets the full-viewport proxy's global position to zero. Its existing parent and relative z order remain intact. Thus the composite and sparks share the same viewport coordinates used to configure them, including when the spark tail reparents after 0.70 s.
4. **Other effects:** measured real heirloom ceremony, combat proxy mount/consumption, event item-loss snapshot, and Graftwright sacrifice reparenting. None jumps. Measurements below; native audit captures remain required.

The purge proxy was a child of the translated confirmation, but its SubViewport card, shader origin and spark origins were already expressed in viewport/global canvas coordinates. Rendering that full-viewport texture and those sparks at the proxy's inherited panel origin applied the translation twice. In the 1920×1080, 100% scrolled overflow fixture, the confirmation rect `(835,324,250,352)` became `(1029,454,250,352)`: an extra `(194,130)` px, unchanged through the first ten burn frames. At 1280×800 it gained `(24,24)` px; at maximum scale, both fixtures gained `(30,30)` physical px. The shader was internally consistent with its source texture; no shader correction is needed once the composite is drawn at viewport origin. Canceling the inherited translation removes the jump without touching the confirmation layout.

### Headless rects (x, y, width, height)

Normal and reduced motion have the same geometry. Burn frames 1–10 and all later frames with card paint have the same support rect. Dissolved alpha naturally vanishes; the support rect is not an alpha bounding box.

| Resolution | Scale | Last confirmation | Before composite | After composite | Max after error px |
| --- | --- | --- | --- | --- | ---: |
| 1920×1080 | 100% | 835,324,250,352 | 1029,454,250,352 | 835,324,250,352 | 0 |
| 1920×1080 | 125% | 803.75,270,312.5,440 | 833.75,300,312.5,440 | 803.75,270,312.5,440 | 0 |
| 1280×800 | 100% | 515,251,250,352 | 539,275,250,352 | 515,251,250,352 | 0 |
| 1280×800 | 125% | 485.525574,217.5,308.948914,435 | 515.525574,247.5,308.948853,435 | 485.525574,217.5,308.948853,435 | 0.000061 |

Headless uses the existing real-scene SubViewport fixture with a 125% stretch override for the scale case. Native capture instead mounts the real scene in its Window and applies `SettingsStore` to that Window; it retains the game's project stretch behavior. Headless values are not substitutes for the native measurements.

### Other-effect measurement table (headless, 1920×1080, 100%)

| Effect / source | Before rect | After rect | Displacement / size delta px |
| --- | --- | --- | --- |
| Heirloom glacial_bulwark / `heirloom_burn.gd` | 629,168,316,540 | 629,168,316,540 | 0,0 / 0,0 |
| Heirloom ironshod_sabatons | 975,168,316,540 | 975,168,316,540 | 0,0 / 0,0 |
| Heirloom stormglass_orb | 1321,168,316,540 | 1321,168,316,540 | 0,0 / 0,0 |
| Combat Exhaust proxy mount / `run_scene.gd::_mount_card_proxy` | 600,260,250,352 | 600,260,250,352 | 0,0 / 0,0 |
| Combat Purge/consume at t=0 / `card_consumption_effect.gd` | 600,260,250,352 | 600,260,250,352 | 0,0 / 0,0 |
| Event item loss / `event_gain_effect.gd` | 480,270,223,315 | 480,270,223,315 | 0,0 / 0,0 |
| Graftwright sacrifice / `graftwright_view.gd` | 585,474,219,308.352 | 585,474,219,308.352 | 0,0 / 0,0 |

Combat Exhaust uses an intentional arc/shrink/fade to its pile, not a burn shader; consumption intentionally lifts/shrinks/rotates/fades after t=0. These are existing approved effects, not reparenting displacement. Event transforms/reforges crossfade their original proxy children, without snapshot reparenting. Heirloom adds its CanvasGroup in the card's existing parent at the original local position. Graftwright inserts an identity CanvasGroup under the original parent. Event loss uses a local-size snapshot and local-zero source rect under its already-positioned proxy. Searches of all runtime `reparent`, `SubViewport.new`, burn shader and dissolve call sites found no additional card/item burn path. Enemy cutout viewports and board/turn-order shadow dissolves are actor effects, not card/item removal; event-hover preparation and locked-hand caches are not loss effects.

## Observed checks

All listed commands used `godot_task_runner.py --task-id purge-04 --stream -- godot --headless --path . --script …` unless noted.

| Entry point | Exact result lines | Exit |
| --- | --- | ---: |
| `tests/magic_deck_test.gd` | `MAGIC DECK TEST: PASS`; `TEST RESULT: PASS` | 0 |
| `tests/magic_deck_input_test.gd` | `PURGE WHOLE-ROW SCROLL CHECKS: PASS`; `MAGIC DECK INPUT TEST: PASS`; `TEST RESULT: PASS` | 0 |
| `tests/heirloom_notification_test.gd` | `HEIRLOOM NOTIFICATION TEST RESULT: PASS`; `TEST RESULT: PASS`; `HEIRLOOM NOTIFICATION LIFECYCLE: surviving_queues_or_presenters=0 orphan_nodes=0` | 0 |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 4.021s`; `OK` | 0 |
| `capture.gd`, baseline/after, both resolutions | `PURGE-04 PROOF: PASS … native=false`; `TEST RESULT: PASS` | 0 |
| `audit.gd` | `PURGE-04 EFFECT AUDIT: PASS`; `TEST RESULT: PASS` | 0 |
| Both proof GDScripts, `--check-only` | no parser errors | 0 |
| `run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/purge-04-python-audit` | `ISOLATION AUDIT: 56 modules; /private/tmp/purge-04-python-audit/isolation-audit.md` | 0 |

`tests/suites/magic_purge_presentation.gd` is a static helper suite, exercised by the existing deck test (halo checks) and input test (grid, confirmation, text-fit expectations); it is not a standalone SceneTree entry point. No existing expectations needed changes. Full suites were not run. No new Python test modules require resource-registry entries.

Headless JSON: `/private/tmp/purge-04-{before,after}-{1920,1280}/rects.json` (118 measurements each). Full tables: `/private/tmp/purge-04-summary-{1920,1280}/measurements.md`. Audit: `/private/tmp/purge-04-audit/audit.json`. Test logs: `/private/tmp/purge-04-*.log`.

Observed diagnostics: the runtime logged macOS `get_system_ca_certificates` (`ret != noErr`) during headless startup. The input test also logged `ObjectDB instances leaked at exit` and `1 resources still in use at exit`; its assertions and runner exit passed. No assertion was changed to suppress these diagnostics; their preexistence on master was not established.

## Proof for the design owner

No windowed runs were attempted. The exact all-in-one owner command is:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/purge-04 && python3 tools/proofs/purge_04/run_native.py
```

It executes the explicit commands below and checks for new DiagnosticReports even if a capture fails. `--print-commands` only prints commands and was verified here without starting a renderer. Use a fresh `--output` directory for a repeat. Alternatively, run the following commands in order; each capture emits every rendered frame, frame 0 (last confirmation), and first ten/all burn support rects. The real confirmation tween is paused and stepped at 1/60 s so native readback cannot skip early frames. Gameplay still takes the real save/confirm/continuation path, and frame 3 repeats Confirm and Cancel to check exactly one charge/commit. The normal frame series continues through the spark tail; reduced motion uses the real 0.25 s fade. Four cases per run cover both scales and motion settings with the list scrolled.

`--baseline` reconstructs the old inherited proxy translation in proof code after real Confirm. It changes only that proxy position and is explicitly labeled in `rects.json`; it is not a pristine historical-build recording. The initial headless reproduction was run before the production edit. For pristine native reproduction first, the design owner can run this probe in the original revision; this worker did not change branches.

The 180 s process / 45 s startup budgets allow scene initialization, four complete frame sequences and synchronous native PNG readback. Keep `LABYRINTH_CEL_LOOK=all`: runners otherwise default to source art. No art is generated by these probes; the build command refreshes the game's existing approved cel-look cache.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/purge-04 && python3 tools/cel_look.py build --if-stale

cd /Users/borgerding/workspace/Labyrinth.worktrees/purge-04 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --task-id purge-04 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 45 --expect-size 1920x1080 --proof-contract tools/proofs/purge_04/capture_1920.json --result-manifest /private/tmp/purge-04-native/before_1920_manifest.json tools/proofs/purge_04/capture.gd -- --baseline --output=/private/tmp/purge-04-native/before_1920

cd /Users/borgerding/workspace/Labyrinth.worktrees/purge-04 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --task-id purge-04 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 45 --expect-size 1920x1080 --proof-contract tools/proofs/purge_04/capture_1920.json --result-manifest /private/tmp/purge-04-native/after_1920_manifest.json tools/proofs/purge_04/capture.gd -- --output=/private/tmp/purge-04-native/after_1920

cd /Users/borgerding/workspace/Labyrinth.worktrees/purge-04 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --task-id purge-04 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 45 --expect-size 1280x800 --proof-contract tools/proofs/purge_04/capture_1280.json --result-manifest /private/tmp/purge-04-native/before_1280_manifest.json tools/proofs/purge_04/capture.gd -- --baseline --deck --output=/private/tmp/purge-04-native/before_1280

cd /Users/borgerding/workspace/Labyrinth.worktrees/purge-04 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --task-id purge-04 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 45 --expect-size 1280x800 --proof-contract tools/proofs/purge_04/capture_1280.json --result-manifest /private/tmp/purge-04-native/after_1280_manifest.json tools/proofs/purge_04/capture.gd -- --deck --output=/private/tmp/purge-04-native/after_1280

cd /Users/borgerding/workspace/Labyrinth.worktrees/purge-04 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --task-id purge-04 --no-headless --display-driver macos --audio-driver Dummy --timeout 90 --startup-timeout 45 --expect-size 1920x1080 --proof-contract tools/proofs/purge_04/audit.json --result-manifest /private/tmp/purge-04-native/audit_manifest.json tools/proofs/purge_04/audit.gd -- --output=/private/tmp/purge-04-native/audit

cd /Users/borgerding/workspace/Labyrinth.worktrees/purge-04 && python3 tools/proofs/purge_04/summarize.py --before /private/tmp/purge-04-native/before_1920 --after /private/tmp/purge-04-native/after_1920 --output /private/tmp/purge-04-native/summary_1920

cd /Users/borgerding/workspace/Labyrinth.worktrees/purge-04 && python3 tools/proofs/purge_04/summarize.py --before /private/tmp/purge-04-native/before_1280 --after /private/tmp/purge-04-native/after_1280 --output /private/tmp/purge-04-native/summary_1280
```

Inspect `/private/tmp/purge-04-native/summary_{1920,1280}/before_after_native.png`. Each uses unscaled native tiles: first two rows before, next two after; within each half: confirmation / 1 / 3, then 6 / 12 / final. Per-case sheets and every individual frame are under each capture directory. `measurements.md` includes all recorded frames, including the first ten, at both scales/motion settings. The rects are transformed geometry measurements; inspect the native pixels for clipping, actual support placement, sparks/front alignment and the unchanged cel look. Do not label them pixel-segmented measurements.

After the native runs, inspect diagnostic reports (a read-only command):

```bash
python3 - <<'PY'
from datetime import datetime, timedelta
from pathlib import Path
cutoff = (datetime.now() - timedelta(hours=1)).timestamp()
folder = Path.home() / 'Library/Logs/DiagnosticReports'
for path in sorted(folder.glob('*')):
    if path.is_file() and path.stat().st_mtime >= cutoff:
        print(path)
PY
```

No `inspection_fixture.py` command was requested by this unit brief. Fixture preparation, native inspection and publication remain with the design owner.

## TODO_DESIGN, chosen defaults and open issues

- TODO_DESIGN: none. There are no new perceivable values or assets.
- Chosen defaults (proof only): 60 Hz deterministic tween stepping, scroll request 296 px, 32 spark-tail capture frames, 0.5 px measurement tolerance from the brief, 0.30 s other-effect audit clock, 10 s Graftwright wait deadline, synthetic combat source rect `(600,260,250,352)`, synthetic event origin `(480,270)`, temporary output paths, and native runner budgets above. All are named fields/constants or command arguments. The existing fixture seeds, content IDs and 125% maximum come from current fixtures/settings.
- Open: native reproduction/frame strips/visual inspection and post-run DiagnosticReports inspection cannot be performed in this sandbox. Native before mode reconstructs the old transform; it is clearly identified rather than presented as an untouched historical build. Headless proof does not certify native pixels. The observed startup/leak diagnostics are recorded above.
