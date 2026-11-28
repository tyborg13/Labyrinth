# fel-34 action-caption placement

Implementation is uncommitted in `codex/fel-34`. The comparison release is
`1e56b4fbf`.

## Acceptance criteria

1. The board snapshots its visible units, retained HUD layouts and the
   captioned action's tile diamonds. `_texture_used_draw_rect` trims the draw
   rectangle to opaque art. The cutout path uses the board's existing
   `_unit_draw_rect_for_center` registration and
   `board_occlusion_sources.gd::_unit_mask` for its facing-specific authored
   alpha bounds. Burrowed units use the existing mound draw rect. Health,
   defense and statuses use `_health_bar_collision_rects`, intent labels
   borrow the retained layout's individual line rectangles, and rest chips
   use `IntentBadges.layouts`. Leader crests are included in the health
   category. Tile rectangles bound the vertices returned by `_tile_polygon`.
   The conversion from board-local to caption-parent coordinates is
   `stage.get_global_transform_with_canvas().affine_inverse() * board.get_global_transform_with_canvas()`.
   The same conversion projects each screen HUD item's local rectangle into
   the caption's space. The complete action tile set is available for supported
   enemy steps and single-step player actions. Multistep player cards, echoes,
   and some secondary card impacts still need the resolved step passed to the
   caption call. The current calls only pass the display string, and the
   existing step tracker's resolution index is inactive.
2. The solver grows the complete label and scrim rectangle by 8 px. An
   intersection of at least one square pixel counts as covering.
3. A covering default searches outward at 8 px intervals, right before left at
   each distance. It rejects moves outside the stage's safe margins or into
   painted HUD, including the boss overlay, header controls and turn-order
   rail. The top bar is measured through its visible controls since its spacer
   stretches across the empty middle. The center remains the fallback.
4. Noctyrax keeps the 560 px horizontal limit. The board retains the same
   centered brazier reservation when the caption becomes visible and also
   receives the visible caption's actual rectangle.
5. Placement runs at caption set and on viewport resize. Duplicate updates of
   the same text within an enemy step and ordinary HUD layout calls retain
   the horizontal offset. The clear-default path uses the legacy offsets.
6. Enemy, boss, Meteorfall, hidden presence and player card captions use the
   same placement path. Concealed enemy action tiles are filtered through
   board visibility. The player-step tile limitation in criterion 1 applies.

## Changed files

- `scripts/action_caption_placement.gd` and UID hold the placement solver and
  input projection.
- `scripts/run_scene.gd` integrates placement and the Noctyrax reservation in
  the three owned functions.
- `scripts/combat_board_view.gd` exposes the board-local rectangle snapshot.
- `tools/fel34/` holds the census observer, temporary pack builder, replay
  wrappers, scoped geometry probe, renderer proof contract and crop assembly.

## Chosen defaults

The headless replay reuses fel-30's fixed 60 fps and 4× diagnostic clock, with
a 30-minute timeout per seed per tree. It runs two independent three-seed
batches per tree. Native uses normal speed and a 60-minute limit per tree.
Ranking sums padded intersection areas, with caption key as the tie-breaker.
Crops use 18 px padding on the union of the two recorded caption bounds and
nearest-neighbor 2× enlargement. The contact sheet uses two 880×190 cells per
row and fel-30's existing caption style. Counts by kind are rectangle
intersections. The median includes zero-shift captions.

## Proof for the design owner

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-34 && bash tools/fel34/headless.sh ../release /private/tmp/labyrinth_codex/fel-34/fresh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-34 && bash tools/fel34/native.sh ../release /private/tmp/labyrinth_codex/fel-34/proof
```

The native command takes the census output directory with its
`selection.json`. It requires a window server and captures both trees at
1920×1080 and 100% UI scale with `LABYRINTH_CEL_LOOK=all`. Each native attempt
writes full frames, visual manifests, 2× pairs under `crops/` and `sheet.png`
under the reported `native.*` directory. It checks the identity and
visibility of each selected caption at the capture boundary. Fresh native
frames remain for the design owner to capture.

The existing pressure probe checks the retained renderer's brazier labels
during Noctyrax's attack frames.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-34 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --task-id fel-34 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --timeout 300 tests/dragon_pressure_presentation_probe.gd
```

## Six-seed headless census

Both trees replayed all 1,275 input witnesses across seeds 30001–30006 and
reached all six recaps. The replay kept both fel-30 reference boundaries and
sampled 1,327 caption placements, including player, enemy, hidden presence and
boss Meteorfall captions. The scoped geometry probe covers the separate
player-card Meteorfall landing adapter.

```text
FEL34 OVERLAP captions=1327 covering_before=395 covering_after=31 fallback=31 max_shift_px=624 median_shift_px=0
FEL34 COVERS kind=body before=300 after=25
FEL34 COVERS kind=health before=618 after=51
FEL34 COVERS kind=intent before=26 after=0
FEL34 COVERS kind=tiles before=15 after=0
FEL34 UNCHANGED clear_at_default=932 moved=1 FAIL
FEL34 LIVE_DEFAULT clear_at_default=931 moved=0 PASS
FEL34 HUD_CLEAR placed=365 overlaps=0 PASS
FEL34 NATIVE READY pairs=10 trees=2 output=/private/tmp/labyrinth_codex/fel-34/proof
```

The strict comparison failed at `30003-05-caption-0017`, the Lightning Wisp's
move step in the Zekarion fight. The preceding placement already moved the
caption 624 px left. The board's retained intent layout then placed one intent
line in the vacated center. Release's caption continued to reserve the center,
so release had no overlap at this step. The branch caption held its prior
offset. The branch kept all 931 captions whose current default geometry was
clear at their exact release rectangles. The report exits nonzero for the
strict comparison and retains the native selection.

The paired inputs, per-seed logs and caption rows are under
`/private/tmp/labyrinth_codex/fel-34/proof/{release,branch}/`. The summary and
the one mismatch are in `/private/tmp/labyrinth_codex/fel-34/summary.log`.

## Scoped evidence

- The final Python default group ran serially and printed
  `Ran 196 tests in 115.397s` and `OK`. The earlier four-shard runs reported
  `FAILED (failures=6, errors=1)` during the census and `FAILED (failures=1)`
  after it. The remaining failure on that repeat was the runner process
  startup assertion `Child did not start`.
- `BOSS HEALTH PREVIEW TEST: PASS (0 failures)`
- `ENEMY NO ACTION TEST RESULT: PASS (747 assertions; 0 failures)`
- `ENC03 SLAG TEST: PASS (732 checks; 0 failures)`
- `ENC03 LOB PROBE: PASS (5 states; 0 failures)` in check-only mode.
- `TURN CLOCK HUD PROBE RESULT: PASS`. Headless Godot also logged a null
  texture from the board aim focus path.
- `FEL34 GEOMETRY PASS cases=18 failures=0`, including a resolver-generated
  player Meteorfall impact through production playback. Godot reported one
  resource still in use on exit.
- Media assembly produced 10 synthetic pairs at
  `/private/tmp/labyrinth_codex/fel-34/media-check/crops` and one sheet at
  `/private/tmp/labyrinth_codex/fel-34/media-check/sheet.png`. It used fel-30
  frames as input to the assembly-only check.
- No `TODO_DESIGN` placeholders. The unresolved player tile handoff is an
  implementation-scope issue.

The first Combat Feel run reported
`Resume's existing row-preparation coroutines finish before clock-fixture teardown`.
A baseline comparison and the final branch repeat both printed
`FLOATING COMBAT TEXT TEST RESULT: PASS` and
`COMBAT FEEL TEST RESULT: PASS`. The earlier assertion did not reproduce.

UI identity lint printed `Ran 25 tests in 8.390s` and `OK`. Rules text lint
printed `PASS: Rules text lint (16 existing hits)`. Python's default group
could not write its optional duration cache under the shared Git metadata
because those files are read-only in the implementation sandbox.

## Round 1

Enemy captions now use the decorated playback action as their identity, and
player captions use the resolved card action sequence. The placement snapshot
includes every move destination and attack tile in the sequence. It includes
the moving actor's translated body and visible plates. A private copy of the
board's plate-layout solver also projects standing actors' visible badges at
the destination. This mattered in seed 30003, where the crawler's arrival
moved the hero's Block badge into the caption band. The live board layout
continues to use its original solver and inputs.

A viewport resize re-samples the caption. Board navigation uses the existing
navigation signal to restart a 150 ms wall-clock timer and re-samples once
when the timer expires. On the default line, HUD rectangles already under
the padded caption are treated as its seat. Other painted HUD remains an
obstacle. Noctyrax keeps the 560 px limit. Lightning Storm uses the tile list
from its resolver receipt. A hidden health frame contributes
nothing at zero opacity, and the separately painted badges remain eligible.

### Round 0 and Round 1 census

| Measure | Round 0 | Round 1 |
| --- | ---: | ---: |
| Caption placements | 1,327 | 919 |
| Covering at center | 395 | 228 |
| Covering after placement | 31 | 0 |
| Fallbacks | 31 | 0 |
| Maximum absolute slide | 624 px | 368 px |
| Median absolute slide | 0 px | 0 px |
| Body rectangle intersections before / after | 300 / 25 | 252 / 0 |
| Health rectangle intersections before / after | 618 / 51 | 182 / 0 |
| Intent rectangle intersections before / after | 26 / 0 | 24 / 0 |
| Tile rectangle intersections before / after | 15 / 0 | 14 / 0 |
| Clear-at-default captions moved | 1 | 0 |
| Slides with HUD or band violations | 0 | 0 |

Round 0 sampled per step. Round 1 measures placements at the first setter
call for each displayed caption, and checks all observed continuation steps
for stability. For coverage it tests the projected subjects from the same
placement snapshot against the proven release rectangle and the actual branch
rectangle. The release and branch both reached all six recaps on the original
input transcript. The final branch pass used the same unchanged release
replay from this round.

```text
FEL34 OVERLAP captions=919 covering_before=228 covering_after=0 fallback=0 max_shift_px=368 median_shift_px=0
FEL34 COVERS kind=body before=252 after=0
FEL34 COVERS kind=health before=182 after=0
FEL34 COVERS kind=intent before=24 after=0
FEL34 COVERS kind=tiles before=14 after=0
FEL34 UNCHANGED clear_at_default=691 moved=0 PASS
FEL34 HUD_CLEAR placed=228 overlaps=0 PASS
FEL34R1 STABLE_ALL actions=338 max_jump_px=0
FEL34R1 STABLE caption="Tunnel Crawler: Skitter Strike" positions=1 max_jump_px=0 covers_after=0
FEL34 PASS cases=919
```

The replay logs and selection are in `/private/tmp/labyrinth_codex/fel-34-round1/final`.
The two crawler samples are `30003-02-caption-0036` (walk) and
`30003-02-caption-0037` (melee). They held the same offset of −176 px.

### Proof for the design owner

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-34 && bash tools/fel34/native.sh ../release /private/tmp/labyrinth_codex/fel-34-round1/final
```

The native dry run verified a 13-pair selection. The wrapper uses the real
renderer at 1920×1080 and 100% UI scale with `LABYRINTH_CEL_LOOK=all`.
It keeps both original reference frames and the eight ranked captions, then
captures both crawler steps and a shared staged Night Coil fixture. The native
run writes separate renderer manifests, the unscaled frames, the paired 2×
crops and `sheet.png` under its reported `native.*` directory.

### Chosen defaults

The six-seed wrapper uses three two-seed batches per tree. The staged
Night Coil witness uses 1.4× board zoom and a 16 px initial overlap. The
blocked fixture widens the board just for its headless assertion using a
32 px extra width. The Sidestep Slash probe reuses the Move Attack fixture
with seed 9292026, move tile (2, 3) and strike tile (3, 3). The capture
wrapper gives the staged renderer probe a five-minute timeout.

### Focused proofs

```text
FEL34R1 NOCTYRAX caption="Night Coil" default_covers=1 placed_in_band=1 fallback=0
FEL34R1 NOCTYRAX caption="Night Coil" default_covers=1 placed_in_band=1 fallback=1
FEL34R1 NAVIGATION settle_ms=150
FEL34R1 SIDESTEP strike_tiles=1 covers_after=0
FEL34R1 STORM strike_tiles=1 covers_after=0
FEL34R1 HIDDEN_HEALTH shifted=0
FEL34 GEOMETRY PASS cases=31 failures=0
BOSS HEALTH PREVIEW TEST: PASS (0 failures)
ENEMY NO ACTION TEST RESULT: PASS (710 assertions; 0 failures)
ENC03 SLAG TEST: PASS (732 checks; 0 failures)
ENC03 LOB PROBE: PASS (5 states; 0 failures)
TURN CLOCK HUD PROBE RESULT: PASS
FLOATING COMBAT TEXT TEST RESULT: PASS
COMBAT FEEL TEST RESULT: PASS
Ran 196 tests in 105.283s
OK
```

UI identity lint printed `Ran 25 tests in 4.239s` and `OK`. Rules text
lint printed `PASS: Rules text lint (16 existing hits)`. The media assembly
check produced 13 synthetic pairs and
`/private/tmp/labyrinth_codex/fel-34-round1/media-check/sheet.png` using
existing fel-30 frames. The native dry run and fixture generation passed.
The staged probe also passed a Godot parser check in the release pack.
The Python default group ran serially and reported that the sandbox denied
its optional shared timing-cache update. Godot logged resource teardown
warnings in several focused runs after their assertions passed.
Fresh native images remain for the design owner. There are no
`TODO_DESIGN` placeholders.
