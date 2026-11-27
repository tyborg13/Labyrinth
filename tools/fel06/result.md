# fel-06 tile-hover census result

The headless run resumed all 12 checkpoints and recorded 46 tile-centre hovers. The [census](census.md) contains the square picks, live hover evidence, coverage and discrepancies. Native renderer proof is pending.

## Requirements

1. **Square selection.** Picks use visible, rendered tiles ranked by descending screen y and then ascending screen x. Categories A through E have 11, 11, 12, 4 and 8 picks. Category E measures the union of qualifying foreground rest masks using the same alpha coverage calculation as fel-01. The [dry log](captures/dry.lDnM8P/runner.log) prints all 46 picks and their contents.
2. **Hover.** Each fixture stages a copy of the fel-01 save and resumes through production Continue. The witness matched before and after each headless hover. The windowed probe uses the fel-01 native entry wait, samples the physical pointer and relays only GUI motion into the 1920×1080 viewport at 100% UI scale. It checks the resolved hover tile, inactive card and movement selection, and completed occluder fades before saving each frame.
3. **Contents and feedback.** The [observation JSON](captures/dry.lDnM8P/observations.json) holds tile state, live tooltip and rail text, board painter inputs, and rest-to-hover changes. Fixture 12 category B at (3, 7) produced “Siphon”, the Dust Acolyte’s “12/16” Health plate, its rail highlight and a door fade. The sampled square contained Fire. The hover provided no Fire tooltip. Five samples opened tooltips sourced from other squares. The census quotes those tooltips and the sampled contents.
4. **Report.** [Census](census.md) lists each sample and its coverage by category, omitted content counts and off-square claims. A passing windowed run rebuilds it with one validated frame link per sample. Its output stays under the tool directory.

## Files changed

- `board_census.gd` and `marks.gd` collect tile state and select the front-most category candidates.
- `hover_probe.gd` and `hover_evidence.gd` stage checkpoints and record the production hover.
- `native.sh`, `proof_contract.json` and `report.py` run, validate and report captures.
- `.gitignore`, the four Godot `.gd.uid` sidecars, `census.md` and this handoff.

## Verification

```text
FEL06 DRY RUN PASS fixtures=12 samples=46
FEL06 REPORT PASS /Users/borgerding/workspace/Labyrinth.worktrees/fel-06/tools/fel06/census.md
FEL06 CENSUS CHECK PASS A=11 B=11 C=12 D=4 E=8 off_square=5
Shell and report syntax PASS
PASS: Rules text lint (16 existing hits)
```

The dry run exited 0. Godot logged `ERROR: Condition "ret != noErr" is true. Returning: ""` in `get_system_ca_certificates`, also present in the fel-01 witness log. This unit has no full-suite proof requirement.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-06 && tools/fel06/native.sh --dry-run
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-06 && tools/fel06/native.sh
```

The native command creates a fresh `tools/fel06/captures/native.*/` with hover PNGs, `observations.json`, `runner.log` and `visual-proof.json`. The renderer runs on the owner’s machine. This sandbox produced zero native frames.

## TODO_DESIGN placeholders

None.

## Chosen defaults

- Probe window gutter of 24 logical pixels, an off-viewport park point of (−16, −16), 6 capture pixels of pointer tolerance for window and display scaling, and 12 divisions for the empty-canvas rest search.
- The native process timeout is 180 seconds, inherited from fel-01. The existing 0.35-second and two-frame hover settle rule also allows Godot’s configured tooltip delay to elapse.

## Open issues

Native pointer delivery, renderer visibility and frame links await the owner’s capture run. Changes are uncommitted under `tools/fel06/`.
