# enc-03 — director feedback 3

The approved caption scrim is implemented. Changes remain uncommitted. The
two-cross copy and accepted measurements are unchanged. The remaining proof is
the director's windowed after-phase; no windowed command was run this round.

## Implementation and requirements

1. **Shared scrim and coverage:** `scripts/action_caption_scrim.gd` extends
   `scripts/hud_seat_scrim.gd` and uses its existing `_ease` falloff. Its extent
   is the caption Label's laid-out text rectangle plus 48 px on each side and
   10 px above/below. `Palette.INK_0` is 0.85 alpha across the complete text
   rectangle. The outer 48 horizontal pixels and outer 6 vertical pixels fade
   to zero. The inner 4 vertical pixels remain dense. It draws gradient
   polygons with no border, plate, new colour literal or material.
2. **Layer, lifetime and scope:** `scripts/run_scene.gd` installs the scrim
   beneath the existing shared `ActionBanner` Label using
   `show_behind_parent`. It shares the caption's canvas and inherits visibility
   and opacity. It has no process function, tween or independent clock, so
   normal and Reduced Motion timing follow the caption exactly. Every enemy
   action uses this path, including Brace. No board overlay is moved or hidden;
   existing node paths and caption layout remain intact.
3. **Regression:** `tests/enc03_lob_probe.gd` reproduces an intersecting leader
   medallion and caption in the real fire Warband fixture, then inspects the
   actual polygon colours submitted by the scrim's `_draw`. The complete
   intersection is covered at 0.85 alpha. Before the implementation this check
   failed because both observed captions lacked the scrim. The existing
   canvas-order assertion remains green. The probe also checks non-lob
   visibility/opacity inheritance under both Reduced Motion settings.
4. **Identity:** the focused suite checks the authored extent, full-density
   text area, zero outer edges, shared 2.2 falloff and palette colour. UI
   identity passes without baseline or exception changes.

Files changed this round: `scripts/action_caption_scrim.gd` (new),
`scripts/run_scene.gd` (one preload and the shared installation),
`tests/enc03_lob_probe.gd`, `tests/suites/enc03_slag_suite.gd`, this report,
`feedback-3-proof.json`, and the canonical `handoff.md` / `proof.json` updates.
Execution logs are under `output/enc-03/feedback-3/`.

## Focused checks

The exact commands, observed result lines and exit codes are in
[feedback-3-proof.json](feedback-3-proof.json).

- Red regression: `ENC03 LOB PROBE: FAIL (3 states; 2 failures)`, exit 1.
  Both failures: `Every action caption rests on the shared soft HUD scrim`.
- Focused geometry, AI and intent checks:
  `ENC03 SLAG TEST: PASS (730 checks; 0 failures)`, exit 0.
- Live fixture: `ENC03 CAPTION SCRIM: overlap area=596.051 min_alpha=0.85`;
  `ENC03 CAPTION LIFECYCLE: PASS (shared non-lob caption; normal and Reduced Motion)`;
  `ENC03 LOB PROBE: PASS (3 states; 0 failures)`, exit 0.
- UI identity: `Ran 25 tests in 4.082s`, `OK`, exit 0.
- Existing timing suite: `COMBAT PACING REGRESSION TEST RESULT: PASS`, exit 0.
  Its log includes headless dummy-renderer `texture_2d_get` diagnostics in the
  existing Veil fixture; the timing assertions and process exit pass.

No full suites, peer review, commit or publication were performed. The qa-08
quarantined HUD test and `tests/quarantine.json` were neither edited nor run.
Headless logs' `CAPTURES` paths are output hints, not renderer image evidence.

## TODO_DESIGN placeholders and chosen defaults

`TODO_DESIGN_callout_occlusion_treatment` is resolved by director feedback 3.
There are no unresolved design placeholders. Historical feedback-2 reports
retain their original pending state for provenance.

Chosen defaults are implementation/test-only: `FALLOFF_STEPS=8` reuses the
existing scrim's gradient subdivision count; `SCRIM_TEST_TEXT_SIZE=(661,30)` is
the geometry-test fixture; `CAPTION_TEST_FADE_ALPHA=0.5` exercises opacity
inheritance. Logs and the fresh manifest use `output/enc-03/feedback-3/`.
All player-facing scrim values above were supplied by the director.

## Proof for the design owner

Run the after-phase at native 1920×1080 and 100% UI scale:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/enc-03 && python3 tools/enc03_proof.py --phase after --result-manifest output/enc-03/feedback-3/director-after-visual-result.json
```

The manifest records absolute capture paths after a successful run. Expected
images are `after_pre_battle_1920x1080.png`, `after_aiming_1920x1080.png` and
`after_landing_1920x1080.png` under the runner's isolated
`user://probes/enc03_lob/`. Earlier director before/after evidence is preserved.
The existing before/inspection-fixture commands remain in the earlier handoff;
this round requests only a new after capture. Native visual inspection is the
only remaining open proof item.
