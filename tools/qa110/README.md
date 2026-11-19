# QA-110 reproduction

Run from the QA-110 worktree. Each command below uses one Godot slot. Keep at
most two slots active, including other local hunts and renderer proof. Use
fresh output paths for repeat runs. The report links the archived receipts
under the ignored `out/` directory.

## Headless campaign and interruption matrix

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-110 && LABYRINTH_GROUND_FX= LABYRINTH_DEMO= python3 -B tools/qa110/campaign.py --seed 101001 --runs 8 --processes 1 --output-dir tools/qa110/out/default-final
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-110 && LABYRINTH_GROUND_FX= LABYRINTH_DEMO= python3 -B tools/qa110/campaign.py --seed 101013 --runs 2 --no-embrace --processes 1 --output-dir tools/qa110/out/no-embrace-final
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-110 && mkdir -p tools/qa110/out/interruptions
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-110 && LABYRINTH_CEL_LOOK=off LABYRINTH_GROUND_FX= LABYRINTH_DEMO= python3 tools/godot_task_runner.py --task-id qa-110 --timeout 600 --stream -- godot --headless --path . --script tools/qa110/interruptions.gd -- --out="$PWD/tools/qa110/out/interruptions" > tools/qa110/out/interruptions/godot.log 2>&1
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-110 && python3 -B tools/qa110/collect.py --lane tools/qa110/out/default-final --lane tools/qa110/out/no-embrace-final --interruptions tools/qa110/out/interruptions/godot.log --interruptions tools/qa110/out/interruption-recheck/godot.log --interruptions tools/qa110/out/death-recheck/godot.log --interruptions tools/qa110/out/release-targeted/godot.log --out tools/qa110/out/analysis
```

Add `--case=normal-mouse-cancel_right` after `--out=` to isolate one path.
Repeat `--case=` to select several paths, or use `--route=own_move_death`
to run that route in every room and device. When combining initial and
repeat logs, list the repeat last so each path contributes one receipt.
The labels use `<room>-<device>-<route>` and the complete label matrix is
in the interruptions log. Right-click and Esc belong to the mouse lane.
B belongs to the controller lane. The controller focus-loss case holds an
aimed card, the controller equivalent of a pointer-held card.

The campaign keeps its exact decisions in `trace.jsonl` and its command in
`command.json`. A bounded replay runs through the same decision number before
stopping. Add `--no-embrace` when replaying the no-Embrace lane.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-110 && LABYRINTH_GROUND_FX= LABYRINTH_DEMO= python3 -B tools/qa110/campaign.py --seed 101003 --runs 1 --processes 1 --stop-after 102 --output-dir tools/qa110/out/release-red-repro
```

## Master comparison

The comparison project uses the production scripts at `047c5848f` and shared
runtime assets verified unchanged against the release tree. It uses the same
QA drivers and local import cache. The command creates a local source overlay
inside the ignored output folder and leaves the checkout and Git references
alone.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-110 && python3 -B tools/qa110/master_project.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-110 && LABYRINTH_CEL_LOOK=off LABYRINTH_GROUND_FX= LABYRINTH_DEMO= python3 tools/godot_task_runner.py --task-id qa-110 --timeout 180 --stream -- godot --headless --path tools/qa110/out/master-project --script tools/qa110/interruptions.gd -- --out="$PWD/tools/qa110/out/master-targeted-final" --case=normal-mouse-focus_loss_drag --case=normal-controller-focus_loss_drag --case=tharokh-mouse-pass_with_loop
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-110 && LABYRINTH_CEL_LOOK=off LABYRINTH_GROUND_FX= LABYRINTH_DEMO= python3 tools/godot_task_runner.py --task-id qa-110 --timeout 300 --stream -- godot --headless --path tools/qa110/out/master-project --script tools/qa110/whole_run.gd -- --seed 101003 --stop-after 102 --output-dir "$PWD/tools/qa110/out/master-red-repro"
```

## Proof for the design owner

Use one native proof per case. Each command validates a 1920×1080 PNG at
100% UI scale and writes `result.json` alongside the image and trace or
path receipt. Headless JSON and SVG stills record live node and paint inputs.
The headless display driver provides no viewport pixels.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-110 && sh tools/qa110/native.sh case tools/qa110/out/native/tharokh-red tharokh-mouse-pass_with_loop
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-110 && sh tools/qa110/native.sh run tools/qa110/out/native/red-101003-102 101003 102
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-110 && sh tools/qa110/native.sh case tools/qa110/out/native/normal-mouse-focus normal-mouse-focus_loss_drag --native-focus-loss
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-110 && sh tools/qa110/native.sh case tools/qa110/out/native/normal-controller-focus normal-controller-focus_loss_drag --native-focus-loss
```

For the physical focus-loss cases, switch away from the game window when the
held card appears, then return. The driver records whether its native focus
signal arrived. Additional `case` commands accept exact path labels from the report.
