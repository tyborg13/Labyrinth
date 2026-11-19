# QA-113 reproduction

The candidate is `2f24e9c65` (`codex/release`). The worktree also contains the design owner's QA-101 and QA-103 drivers at `fbafb4c6b`. Commands use isolated settings, saves, and logs. Use a fresh output directory when repeating a campaign. Schedule at most two QA-113 Godot processes at a time. A campaign with `--processes 2` takes both slots.

## Headless

The first default lane used the QA-110 observer. The QA-113 observer extends it with a separate committed-phase calculation before each Pass and a live state receipt after the phase. The fixed-step option uses the same route policy and headless clock multiplier with an uncapped 120 Hz simulated frame step.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-113 && python3 -B tools/qa113/campaign.py --seed 101001 --runs 10 --processes 2 --script tools/qa110/whole_run.gd --output-dir tools/qa113/out/default
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-113 && QA113_FIXED_STEP=1 python3 -B tools/qa113/campaign.py --seed 101013 --runs 2 --no-embrace --processes 2 --output-dir tools/qa113/out/no-embrace
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-113 && python3 -B tools/qa113/headless.py sounds rules hands focus text loops
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-113 && python3 -B tools/qa113/text_findings.py tools/qa113/out/targeted/text/inventory.tsv tools/qa113/out/targeted/text/qa113-findings.tsv
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-113 && python3 tools/qa105/typed_array_scan.py --base codex/release
```

For a bounded witness, add `--stop-after <decision>` and choose one seed. Use this selected-card red-tile replay to capture the hover-correction attribution.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-113 && QA113_RED_WITNESS=1 QA113_FIXED_STEP=1 python3 -B tools/qa113/campaign.py --seed 101014 --runs 1 --no-embrace --processes 1 --stop-after 1089 --output-dir tools/qa113/out/red-recheck
```

`command.json`, `trace.jsonl`, and `godot.log` under each seed record the exact command, inputs, and errors. Run `checkpoints.py` while the default lane is active to retain representative combat states. The manifest records the observed decision and the restored state can belong to an earlier persisted boundary.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-113 && python3 -B tools/qa113/checkpoints.py tools/qa113/out/default --runs 10 --out tools/qa113/out/checkpoints
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-113 && python3 -B tools/qa101/audit_checkpoints.py --checkpoints tools/qa113/out/checkpoints --out tools/qa113/out/checkpoint-audit/manifest.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-113 && LABYRINTH_CEL_LOOK=off python3 tools/godot_task_runner.py --task-id qa-113 --timeout 600 --stream -- godot --headless --path . --script tools/qa103/checkpoint_replay.gd -- --manifest "$PWD/tools/qa113/out/checkpoint-audit/manifest.json" --out-dir "$PWD/tools/qa113/out/checkpoint-audit"
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-113 && python3 -B tools/qa101/audit_checkpoints.py --forecasts tools/qa113/out/checkpoint-audit/forecasts.json --out tools/qa113/out/checkpoint-audit/audit.json
```

These focused rechecks cover live undo clearance and the sound-bank alignment and teardown witnesses.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-113 && python3 -B tools/qa113/headless.py --out tools/qa113/out/recheck sounds
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-113 && QA107_PROFILE=deck UI33_CASE=reach_exit/held_undo QA107_OUTPUT="$PWD/tools/qa113/out/recheck/reach-exit-held_undo" python3 tools/godot_task_runner.py --task-id qa-113 --stream -- godot --headless --path . --script tools/qa113/rules.gd
```

The staged master comparison uses the exact master production script and data bytes with the release's local import cache and probe drivers. It is for comparisons whose input assets are unchanged. The dragon roar check compares the asset and its registry entry directly.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-113 && python3 -B tools/qa113/master.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-113 && LABYRINTH_CEL_LOOK=off python3 tools/godot_task_runner.py --task-id qa-113 --stream -- godot --headless --path tools/qa113/out/master-project --script tools/qa110/interruptions.gd -- --out="$PWD/tools/qa113/out/master-focus" --case=normal-mouse-focus_loss_drag --case=tharokh-mouse-pass_with_loop
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-113 && QA107_PROFILE=deck UI33_CASE=reach_exit/held_undo UI33_BASELINE=1 QA107_OUTPUT="$PWD/tools/qa113/out/recheck/master-held-undo" python3 tools/godot_task_runner.py --task-id qa-113 --stream -- godot --headless --path tools/qa113/out/master-project --script tools/qa113/rules.gd
```

## Proof for the design owner

These commands require an actual macOS window server. Desktop is 1920×1080 at 100% UI scale. Deck matches the existing QA-107/hand-budget profile at 1280×800 and 115% UI scale. The wrapper runs the visual probe runner and writes a proof contract and `result.json` in each supplied output directory. Each completed probe prints its capture paths.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-113 && python3 -B tools/qa113/native.py rules --profile desktop --out tools/qa113/out/native/rules-desktop
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-113 && python3 -B tools/qa113/native.py rules --profile deck --out tools/qa113/out/native/rules-deck
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-113 && python3 -B tools/qa113/native.py undo --profile deck --out tools/qa113/out/native/undo-deck
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-113 && python3 -B tools/qa113/native.py held-undo --profile deck --out tools/qa113/out/native/held-undo-deck
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-113 && python3 -B tools/qa113/native.py hands --profile desktop --out tools/qa113/out/native/hands-desktop
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-113 && python3 -B tools/qa113/native.py hands --profile deck --out tools/qa113/out/native/hands-deck
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-113 && python3 -B tools/qa113/native.py loops --out tools/qa113/out/native/loops
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-113 && python3 -B tools/qa113/native.py focus --out tools/qa113/out/native/focus
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-113 && python3 -B tools/qa113/native.py text --out tools/qa113/out/native/text
```

At the focus prompt, switch away with the card held, then return to the game. The QA-110 fixture records whether the native focus-out signal arrived. The report-only brief uses existing fixtures for reproduction.
