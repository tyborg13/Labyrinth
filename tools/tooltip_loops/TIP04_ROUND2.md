# tip-04 round 2 handoff

Changes are uncommitted. No windowed run, Git write, peer review or full suite.
Director-native media/sidecars were hash-checked unchanged during this round.
Runtime playback and the Collision/Retaliate open-hitch work remain unchanged.

## 1. Full sprite margin

Inspected `/private/tmp/labyrinth_codex/tip-04/record/raw/rule_gust.tlp` f25.
The new bound check reproduces the hero's top-edge failure. It measures actual
submitted paint: alpha-used Sprite2D bounds, live bone transforms and skinned
Polygon2D vertices, rather than just tile footprints or padded texture canvases.
Each paint item is clipped to its private production canvas before union;
parts parked off-canvas for Burrow/death do not count as visible sprites.
Every visible unit is checked on every rehearsal frame and, natively, after
frame_post_draw immediately before readback. Distances are converted into the
282x168 loop's pixels. The 4 px gate includes a conservative extra 1 px allowance
for filtering/outline. Per-unit minimum, sample and rect are in timing/provenance.

Position-only fixes:

- Gust: hero `(2,2) -> (2,1)`, Crawler `(0,2) -> (0,1)`. Same upward wind,
  two-tile separation across it, no collision. Worst unit margin now 25.80 px.
- Additional existing failure: `charge_storm_capacitor`, about -4.57 px at the
  Capacitor. Moved only its fixture position `(1,0) -> (1,1)`; now 14.08 px.
  Production loss numbers remain hero `-6`, Crawler `-5`, Charge resets to zero.
- Additional existing failure: `marked_icefall_seer`, about -2.17 px at the hero.
  Shifted its fixture hero `(0,1) -> (1,1)` and one-tile escape `(1,1) -> (2,1)`;
  now 16.27 px. Still marks three tiles, walks one tile, lands on empty Ice and
  hits nobody. Enemy, rules and cast timing are unchanged.

All fifteen final rehearsals passed. No other existing loop needs re-recording.
Margins (minimum over all sampled units/poses, including the 1 px allowance):

| Loop | Minimum px |
| --- | ---: |
| burst_ember_tick | 20.86 |
| marked_burrow_grub | 9.83 |
| chain_card | 26.55 |
| collision_push | 23.89 |
| retaliate_hollow_mimic | 19.73 |
| charge_storm_capacitor | 14.08 |
| lightning_strikes | 10.22 |
| marked_icefall_seer | 16.27 |
| marked_lob_slag | 16.27 |
| freeze_status | 20.27 |
| splits_cinder_ooze | 7.02 |
| rule_gust | 25.80 |
| rule_wildfire | 30.03 |
| rule_frostbite | 34.46 |
| rule_shadowstep | 16.27 |

Evidence: `/private/tmp/labyrinth_codex/tip-04/round2/final-margin/` contains
all fifteen timing JSON files and `margin-summary.json`. The extracted historical
Gust diagnosis is `/private/tmp/labyrinth_codex/tip-04/round2/gust_native_f25.png`;
it is not fresh proof of the fix.

## 2. Action-only FPS measurement

`capture.gd` delegates to the new authoring-only `playback_rate.gd`. It resets the
existing proof playback cursor, waits for presented frame zero, counts distinct
presented action-frame changes through the first presentation of the last action
frame, and stops there. A clipped action-clock deadline also excludes hold time
if decoding never presents the last action frame. Skipped frame indices are not
credited as rendered frames. Hold and cross-fade are excluded from the denominator.
Each native measurement now records `action_playback_sample` (changes, interval,
first/last indices, action count, end reason and explicit hold/cross-fade flags).
The runtime `tooltip_loop_view.gd` is byte-identical to HEAD.

Temporary focused proof checked short 21/24/27-frame and long 90-frame actions,
with both full 30 fps delivery and simulated dropped-frame 15 fps delivery. The
measurement distinguished them and never included the hold/cross-fade interval.
Four actual checked-in streams also passed in headless playback:

| Actual stream | Action-only fps |
| --- | ---: |
| rule_shadowstep | 29.475 |
| rule_wildfire | 29.559 |
| rule_gust | 29.666 |
| chain_card | 29.911 |

These establish measurement semantics, not native performance acceptance.

## Observed proof

```text
TIP01 REHEARSAL RESULT: PASS (0 failures)
TIP03 DESIGN PENDING: 0 loops (excluded from recording)
TIP04 SPRITE MARGIN: PASS (15 loops; every sampled sprite >=4 px; native post-draw audit enabled)
TIP04 ACTION FPS PROOF: PASS (short/long action; full-rate/dropped frames; no hold/crossfade)
TIP04 REAL ACTION FPS: PASS (four actual streams; headless timing only)
TIP04 RULE OWNERSHIP: PASS (all enemy sources rejected; rule HUD; unchanged copy; four rule HUD routes)
TIP01 TOOLTIP SEMANTICS: PASS (0 failures)
TIP04 ROUND2 SCOPE: PASS (runtime unchanged; director media unchanged)
```

UI identity: `Ran 25 tests in 3.358s` / `OK`. Both wrapper `--check-only`
commands and `git diff --check` exited 0. Existing macOS CA-certificate output
appeared. Temporary rig-diagnosis teardown emitted resource-at-exit warnings;
the final rehearsal and focused measurement checks exited 0.
No assertions on master were rewritten, and no permanent test module was added.

Headless commands (all Godot calls through the mandatory runner):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/tip-04 && LABYRINTH_CEL_LOOK=all TIP01_OUT=/private/tmp/labyrinth_codex/tip-04/round2/final-margin python3 tools/godot_task_runner.py --task-id tip-04 --stream -- godot --headless --path . --script tools/tooltip_loops/record.gd -- --rehearsal
cd /Users/borgerding/workspace/Labyrinth.worktrees/tip-04 && python3 tools/godot_task_runner.py --task-id tip-04 --stream -- godot --headless --path . --script /private/tmp/labyrinth_codex/tip-04/round2/rate_proof.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/tip-04 && python3 tools/godot_task_runner.py --task-id tip-04 --stream -- godot --headless --path . --script /private/tmp/labyrinth_codex/tip-04/round2/real_rate_proof.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/tip-04 && LABYRINTH_CEL_LOOK=all python3 tools/godot_task_runner.py --task-id tip-04 --stream -- godot --headless --path . --script tools/tooltip_loops/capture.gd -- --semantics-only
```

## Proof for the design owner

Re-record only Gust and the two additional margin failures:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/tip-04 && python3 tools/tooltip_loops/record.py --loops rule_gust,charge_storm_capacitor,marked_icefall_seer
cd /Users/borgerding/workspace/Labyrinth.worktrees/tip-04 && python3 tools/tooltip_loops/capture.py
```

Outputs remain `/private/tmp/labyrinth_codex/tip-04/record/` and
`/private/tmp/labyrinth_codex/tip-04/capture/{freeze-first,freeze-last}/`,
1920x1080 / 100% UI scale through visual_probe_runner. Capture uses the existing
27-image contract and all fifteen streams. The known Collision/Retaliate 4 ms
open hitch remains perf-130's work; this patch does not change that gate or path.
No inspection_fixture command was requested.

## Files, defaults and open issues

This round: `tip04_fixture.gd` and `tip03_fixture.gd` positions; `patch_checks.gd`
and `record.gd` margin enforcement/provenance; new `sprite_margin.gd` / UID;
`capture.gd` and new `playback_rate.gd` / UID; this handoff and its index link.
All are under `tools/tooltip_loops/`.

No active TODO_DESIGN added. Chosen values are offline fixture fields only:
`GUST_HERO=(2,2)`, `GUST_CRAWLER=(0,2)`, `CHARGE_CAPACITOR=(1,1)`,
`ICEFALL_HERO=(1,1)`, `ICEFALL_ESCAPE=(2,1)`. `REQUIRED_PIXELS=4` comes from
the director; the debug-only filter allowance is `FILTER_PAD_PIXELS=1`.
The FPS readiness watchdog reuses 300 frames, and its 30 fps action clock matches
the unchanged runtime. Native post-fix framing and FPS acceptance remain pending.
