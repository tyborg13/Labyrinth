# rd-03 feedback 1 handoff

Changes remain uncommitted. No windowed run, full suite, peer review or Git write
was performed. The director's existing four stills, Zekarion still, and movie
frames 000/030 were inspected. Previous owner outputs are preserved.

## Changes

- Accepted quadratic ease-out: `EASE_OUT_CURVE = Tween.TRANS_QUAD`, with
  `Tween.EASE_OUT` and the approved 0.12-second duration. No TODO_DESIGN remains.
- Six still cases now produce twelve `<case>_on.png` / `<case>_off.png` images.
  A tool-only toggle replaces **only rd-03 actor-canvas modulation** with white
  for the off exposure, then restores it. No player setting was added.
  The off exposure keeps the same selected card, target, HUD order, preview,
  terrain, tooltips, animation poses and simulation frame. It is an ablation of
  the dimming, not cancellation of the card. The tool asserts no process tick
  occurs between the two exposures; native `RenderingServer.force_draw(false)`
  exposes the changed modulation without advancing game logic or animation.
- The certified five-foe fight asserts melee/ranged/area reach counts of 1/2/2.
  The hero and four foes have no pillar on either screen-forward neighbour;
  one foe stands immediately behind a pillar. The real Zekarion arena remains.
- The idle trap case now explicitly opens an embedded popup using the production
  board-hover text resolver and custom-tooltip builder. This avoids reliance on
  native OS tooltip timers for an injected pointer, which omitted the old fifth
  still. The trap-choosing case asserts that the same resolver returns nothing.
- Task-local still and movie launchers default to Metal/mobile, cel look,
  1920x1080 and 100% UI. Shared project/runners are unchanged.

## Causes of the two observed artifacts

**Pillar fade:** existing occlusion-cache invalidation, reproduced without rd-03.
`feedback1-baseline.log` uses exact `HEAD` board/run-scene sources with only their
`class_name` declarations removed so they can coexist in a diagnostic process.
The initial obstruction snapshot contains startup-scale rectangles near y=19,
with actor widths about 0.66–1.22 pixels. The final display is already board-sized,
but that retained snapshot is stale. Card selection refreshes the obstruction
rectangles at the final board size (hero width 161.45 px). The existing
`_foreground_blocker_tint_uncached` overlap rule then returns alpha 0.32 for
pillar (2,5), and 0.54 for prop overlap at (3,2). `_draw_pillar_body` preserves the
cap/foot while fading the shaft. It is not rd-03 modulation and is not an
explicit hovered/targeted-tile opacity rule. No prop-opacity code was changed.
The startup cache issue remains an existing issue outside this unit.

**Empty pale bar:** the existing terrain-health bar for `terrain_3_5`, a wooden
box at (3,5), not an extra Warden health bar. Its original terrain draw rectangle
is `(753.10,364.95,100.32,100.32)` at 1920x1080, placing the small painted frame
under the overlapping Warden's upper body. `_should_show_terrain_health_bar`
reveals undamaged breakables when their tile enters `attack_tiles`; Dull Bolt
selection does that. Its pale prop-HP fill/frame can read as empty segments.
The box is at 3/3 HP; the notches are not a new five-point Warden resource.
The unchanged HEAD scripts reproduce both box-bar entries at selection. The new
proof fixture moves its single box away from all actors; no terrain-HUD behavior
was altered.

To reproduce the baseline diagnostic against the **original** owner fixture
`/private/tmp/labyrinth_codex/rd-03/combat.json`:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-03 && sh tools/rd03/diagnose_baseline.sh
```

It creates temporary tool-local source copies, runs only through the task Godot
runner, and removes the copies in `finally`. `diagnostics.gd` also runs directly
against the current implementation for comparison.

## Proof-only defaults

Natural generated 9x9 Sooted Hall: seed 7262026, room 1,0. Hero (3,6), foes
(3,5), (5,6), (6,2), (7,3), (1,1). Existing Warden occupies (5,6); the others
are existing Crawlers. The foe at (6,2) is behind pillar (6,3). Fire trap (4,6);
one wooden box (1,7). Hand retains the original proof's six existing cards.
The three captured cards are Quick Stab, Dull Bolt, Lantern Rain. Zekarion uses
the same real arena and hero (3,4). Setup waits are 16 frames; stills additionally wait 0.16 seconds so the fade
has settled even on high-refresh displays. Movie select frame
6, cancel frame 72, 90 frames at 30 fps. These choices affect proof fixtures only.

## Headless checks

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-03 && sh tools/rd03/prepare_fixtures.sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-03 && python3 tools/godot_task_runner.py --task-id rd-03 --stream -- godot --headless --path . --script tools/rd03/aim_focus_proof.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-03 && python3 tools/godot_task_runner.py --task-id rd-03 --stream -- godot --headless --path . --script tools/rd03/capture.gd -- --check-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-03 && RD03_CLIP=1 python3 tools/godot_task_runner.py --task-id rd-03 --stream -- godot --headless --path . --script tools/rd03/capture.gd -- --check-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-03 && python3 tests/test_ui_identity_lint.py
```

## Proof for the design owner

Generate certified saves (the script contains both complete
`tools/inspection_fixture.py` commands):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-03 && LABYRINTH_CEL_LOOK=all sh tools/rd03/prepare_fixtures.sh
```

Native paired stills and 3-second movie, using the new Metal/mobile defaults:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-03 && sh tools/rd03/capture_native.sh stills
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-03 && sh tools/rd03/capture_native.sh movie
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-03 && python3 tools/rd03/finalize_movie.py
```

The still command expands to:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-03 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --godot tools/rd03/native_capture.sh --no-headless --display-driver macos --audio-driver Dummy --rendering-driver metal --rendering-method mobile --fallback-rendering-driver metal --timeout 120 --expect-size 1920x1080 --proof-contract tools/rd03/capture_contract.json --result-manifest /private/tmp/labyrinth_codex/rd-03/feedback1/stills_probe_manifest.json tools/rd03/capture.gd --task-id rd-03 -- --fixed-fps 30
```

The movie command uses the same options, with `--godot tools/rd03/movie_capture.sh`,
`--proof-contract tools/rd03/movie_contract.json` and result manifest
`feedback1/movie_probe_manifest.json`. MovieWriter supplies fixed 30 fps and
1920x1080; the finalizer checks 90 consecutive native frames and clock spacing.

Output root: `/private/tmp/labyrinth_codex/rd-03/feedback1/`.
Stills are `stills/01_melee_one_foe_{on,off}.png`,
`02_ranged_two_foes_{on,off}.png`, `03_area_two_foes_{on,off}.png`,
`04_zekarion_melee_{on,off}.png`, `05_trap_choosing_{on,off}.png`,
`06_trap_idle_{on,off}.png`. Movie: `clip/frames/sweep_000.png` through
`sweep_089.png`. The idle pair should be identical: no target step means no aim
dimming. Comparing cases 05 and 06 shows suppression/restoration of the same
trap's production tooltip.

Native pairing and renderer timing remain for the owner to verify; headless
setup checks do not certify pixels. No new full-suite result is claimed.

## Observed results this round

All final headless runner commands exit 0. Logs are under
`/private/tmp/labyrinth_codex/rd-03/`:

- `feedback1-proof.log`: `RD03 AIM FOCUS: PASS (658 checks, 0 failures)`.
  All six cases report `idle_full_redraw_delta=0` across 120 frames.
- `feedback1-capture-final.log`: `RD03 COMPOSITION: 5 clear including hero; 1 behind pillar`;
  `RD03 REACH: 1/5 foes`, `2/5 foes`, `2/5 foes`;
  `RD03 REAL CAPTURE: PASS (6 states, 1920x1080, 100% UI, headless setup only)`.
- `feedback1-movie.log`: `RD03 MOVIE CONTRACT: 90 consecutive frames / 30 fps = 3 seconds; select, sweep two targets, cancel`;
  `RD03 REAL CAPTURE: PASS (90 states, 1920x1080, 100% UI, headless setup only)`.
- `feedback1-ui.log`: `Ran 25 tests in 5.917s` / `OK`; no ratchet changes.
- `feedback1-baseline-final.log`: `RD03 DIAGNOSTICS: PASS` with the same original
  pillar alpha transition and terrain-bar entries on unchanged HEAD sources.
- Shell syntax, Python helper compilation (task-local pycache), source sidecars
  and `git diff --check` pass. No new Python test module was added.

The macOS headless engine still prints its existing certificate-store diagnostic
`ERROR: Condition "ret != noErr" is true. Returning: ""` from
`get_system_ca_certificates`. It does not fail these commands. No script errors
are accepted as successful proof. The earlier existing Python runner cleanup
failure was not rerun in this focused feedback round.

Open items: owner native on/off exposure validation, embedded idle tooltip
appearance, and transition timing review. Existing initial occlusion-cache
invalidation is documented above; no rd-03 prop-opacity change needs removal.
