# rd-08 integration handoff

Current owner feedback: [Sealbinder countdown tooltips](FEEDBACK2.md), following
[enemy tooltip removal](FEEDBACK1.md). These supersede the original full
enemy/dragon tooltip requirement below.

Worker changes are uncommitted on `codex/rd-08`. rd-04 was integrated with a
read-only three-way source merge from `7ec60afc5`; no Git metadata was changed.
The owner owns commit, peer review, rendered inspection and publication.

## Reconciliation / acceptance

1. `board_rail_highlight.gd` owns one target and one tween per rail entry.
   Inspection (all rd-07 triggers) OR threat isolation selects GOLD_BRIGHT;
   losing both sources returns over the existing 0.12-second quadratic ease-out.
   rd-04's diagnostic tween/rest metadata aliases that same animator.
2. Compact disc hit testing resolves the enemy before floor hit testing. The
   same board pointer event opens its plate, unfurls the disc, isolates its
   telegraphs and lights its rail entries. Reverse lookup adds the isolated
   enemies to the existing unfurl predicate. Always keeps its existing layouts.
3. Aim focus updates rd-02's per-unit multiplier using one tween per actor,
   shared by body and HUD records: 50%, 0.12 seconds, quadratic ease-out.
   The existing hook applies to normal team and covered x-ray outlines.
4. rd-04's complete dragon tooltip and footprint lookup remain intact; the
   plate inspector uses that footprint and disc routing under contextual mode.
5. Isolation retains rd-04's command ownership under both settings. Scene-tile
   slices paint behind their original parent; team body canvases keep their
   original indices and depth order. The rd-02 body pass prevents duplicate
   bodies in the isolation scene painter.
6. No new art, fonts, icons, tuning, gameplay rules, saves or analytics changes.
   Production work is confined to the integrated board/HUD helpers.

`integration_proof.gd` boots all three stock-certified saves, tests both
settings, actual disc input, overlapping threat reverse lookup, the rail union,
production ranged aim and outline restoration, and both dragons' footprints.
`headless_checks.py` runs the upstream unit proofs plus the requested focused
checks. Its generated proof copies change output paths only, preserving every
upstream assertion and input fixture. The original unit scripts are unchanged.

## Headless reproduction

Every command starts in this worktree. No full Python or Godot suite is needed.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-08 && python3 tools/rd08/prepare_fixtures.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-08 && python3 tools/godot_task_runner.py --task-id rd-08 --stream -- godot --headless --path . --script tools/rd08/integration_proof.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-08 && python3 tools/rd08/headless_checks.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-08 && python3 tools/godot_task_runner.py --task-id rd-08 --stream -- godot --headless --path . --script tools/rd08/capture.gd -- --check-only --case overlap
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-08 && python3 tools/godot_task_runner.py --task-id rd-08 --stream -- godot --headless --path . --script tools/rd08/capture.gd -- --check-only --case zekarion
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-08 && python3 tools/godot_task_runner.py --task-id rd-08 --stream -- godot --headless --path . --script tools/rd08/capture.gd -- --check-only --case vyraketh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-08 && python3 tools/godot_task_runner.py --task-id rd-08 --stream -- godot --headless --path . --script tools/rd08/movie_capture.gd -- --check-only --fixed-fps 30
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-08 && python3 tools/godot_task_runner.py --task-id rd-08 --stream -- godot --headless --path . --script tools/rd08/performance.gd -- --check-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-08 && python3 tests/test_ui_identity_lint.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-08 && python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/rd-08/python-audit-final
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-08 && python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/rd-08/python-default
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-08 && python3 tools/rd02/export_check.py --task-id rd-08 --use-provided-cel --output-dir /private/tmp/labyrinth_codex/rd-08/release
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-08 && python3 tools/rd08/check_tools.py
```

The upstream unit proofs use their already-certified manifests in rd-02 through
rd-07. The rd-08 generator inherits rd-04's natural Section I route selection,
retains its existing living Health crate at `(4,4)`, changes only the proof
hand through the shared inspection fixture override, and uses the stock verifier for all three saves. The seed is
7262034, Section I room `(3,-1)` at depth 3/fight 4; natural Zekarion depth 16,
Vyraketh depth 12. `prepare_fixtures.py` records exact generate/verify commands
in `/private/tmp/labyrinth_codex/rd-08/{overlap,zekarion,vyraketh}.json`.
There is no need to relabel a synthetic boss fight or change a certified source.

## Proof for the design owner

No native/windowed commands were run by the worker. Use the existing approved
`cel_look_variants/`. All wrappers require Metal/mobile, 1920x1080, 100% UI scale,
`LABYRINTH_CEL_LOOK=all`, a 300-second probe timeout and Metal-only fallback.
They reject logs containing `Cel look variant unavailable`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-08 && LABYRINTH_CEL_LOOK=all sh tools/rd08/proof_for_owner.sh fixture
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-08 && LABYRINTH_CEL_LOOK=all sh tools/rd08/proof_for_owner.sh stills
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-08 && LABYRINTH_CEL_LOOK=all sh tools/rd08/proof_for_owner.sh movie
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-08 && python3 tools/rd08/prepare_baseline.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-08 && LABYRINTH_CEL_LOOK=all sh tools/rd08/proof_for_owner.sh performance
```

The exact expanded per-case still command (replace `overlap` with `zekarion`
or `vyraketh` for the other certified arenas):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-08 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py tools/rd08/capture.gd --task-id rd-08 --godot "$PWD/tools/rd08/native_capture.sh" --no-headless --display-driver macos --audio-driver Dummy --rendering-driver metal --rendering-method mobile --fallback-rendering-driver metal --timeout 300 --expect-size 1920x1080 --proof-contract tools/rd08/overlap_contract.json --result-manifest /private/tmp/labyrinth_codex/rd-08/native-overlap.json -- --case overlap
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-08 && LABYRINTH_CEL_LOOK=all RD08_MOVIE=1 python3 tools/visual_probe_runner.py tools/rd08/movie_capture.gd --task-id rd-08 --godot "$PWD/tools/rd08/native_capture.sh" --no-headless --display-driver macos --audio-driver Dummy --rendering-driver metal --rendering-method mobile --fallback-rendering-driver metal --timeout 300 --expect-size 1920x1080 --proof-contract tools/rd08/movie_contract.json --result-manifest /private/tmp/labyrinth_codex/rd-08/native-movie.json -- --fixed-fps 30
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-08 && python3 tools/rd08/finalize_movie.py
```

Expected output root: `/private/tmp/labyrinth_codex/rd-08/`.

- `stills/overlap/01_rest_always.png`, `02_rest_on_hover_and_aim.png`,
  `03_enemy_hover.png`, `04_overlap_hover.png`, `05_crate_hover.png`,
  `06_hero_block_rest.png`, `07_hero_block_hover.png`, `08_ranged_aim.png`,
  `09_details.png`.
- `stills/zekarion/10_zekarion_rest.png`, `11_zekarion_hover.png`.
- `stills/vyraketh/12_hero_behind_vyraketh.png`.
- Each still case includes `semantics.json` with isolation, intent and x-ray
  states. Headless setup creates metadata only; it does not certify pixels.
- `clip/frames/sweep_000.png` through `sweep_119.png`: four seconds, 30 fps,
  native consecutive MovieWriter frames. The finalizer verifies draw-frame and
  presentation-clock continuity without resampling; its manifest records removed
  startup frames. The sequence holds empty floor, enemy, overlap tile, then away.
- `performance/1-A.json` through `6-B.json`, native sample stills and manifests,
  and `performance/report.json`. Each pair reports base/foundation median and
  p99 and their deltas for whole-frame, engine, render CPU and GPU times.
  A is the exact archived `14a369b61`; B is this working tree. Both use the same
  certified overlap save and approved cel assets. There is no invented cost gate.
  `prepare_baseline.py` already produced the baseline locally; it preserves an
  existing directory and need not be rerun for this handoff.

The owner's play command seeds a profile only when it does not exist, copying
all three files from the specified Steam directory. The source is read only.
A staged copy avoids leaving a partially seeded profile on failure.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-08 && RD08_PROFILE_HOME="$HOME" LABYRINTH_CEL_LOOK=all python3 tools/godot_task_runner.py --task-id rd-08 --timeout 0 --allow-steam --stream -- tools/rd08/play_profile.sh --path . --windowed --resolution 1920x1080 --rendering-driver metal --rendering-method mobile
```

## TODO_DESIGN placeholders and chosen defaults

No new TODO_DESIGN placeholders or player-visible values were chosen.
All palette, geometry, wording, timing and intent behavior come from the brief
and integrated units. Inherited unrelated TODO_DESIGN values remain unchanged.

Chosen proof-only defaults are named in their owning tools: inherited seed
search bounds, real fixture seed/route, the rd-07 proof hand (`dull_bolt,ember_rain,sidestep_slash,brace`), hero
Block 7, Vyraketh hero offset `(-1,0)`, 20 settling frames, 0.25-second fade wait,
3-second visibility-hold expiry, 0.8-second tooltip wait, 8 startup movie frames,
30-frame phases with 6-frame pointer travel, 30 performance warmup frames and
180 sample frames per process, temp profile contents and output paths. Movie
length/fps, viewport size, UI scale and timeout are brief requirements.

Native capture inspection, movie viewing, UI judge, native A/B costs, owner
play, commit and review remain owner work as explicitly assigned in this round.
See `RESULTS.md` for exact observed headless outcomes and remaining failures.
