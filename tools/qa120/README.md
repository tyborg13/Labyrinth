# qa-120 forecast truth soak

The campaign starts one production-generated fight per seed. It selects rooms in
Sections I–III, resumes through the production save path and uses the run-hunt
policy for random legal play. It also sends real controller, mouse and keyboard
events through the game viewport. The separate input matrix covers both input
positions even when random play does not draw an aimed or rotatable card.

## Headless

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-120 && python3 tools/qa120/soak.py --out /private/tmp/labyrinth_codex/qa120-replay --control-fixture /private/tmp/labyrinth_codex/perf-140/native-r1-pairs/fixtures-v3.var
```

The optional fixture archive reproduces the perf-154b reviewer’s encounter.
Without that argument the controls build the same encounter recipe with the
production inspection fixture builder. Give each run a fresh output directory.
The launcher writes the exact child commands, coverage and exit codes to
`campaign.json`. Each child logs actions, expected and shown values, pending
owners and per-Pass outcome receipts to `trace.jsonl`.

Run one seed or one control with the same Godot entry point.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-120 && python3 tools/godot_task_runner.py --task-id qa-120 --timeout 180 --stream -- godot --headless --path . --script tools/qa120/campaign.gd -- --out=/private/tmp/labyrinth_codex/qa120-seed-12003 --seed=12003
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-120 && python3 tools/godot_task_runner.py --task-id qa-120 --timeout 180 --stream -- godot --headless --path . --script tools/qa120/campaign.gd -- --out=/private/tmp/labyrinth_codex/qa120-details-gap-2 --case=gfix23_details --gap=2
```

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-120 && python3 tools/qa120/report.py /private/tmp/labyrinth_codex/qa120-replay/campaign.json tools/qa120/qa120_report.md
```

## Proof for the design owner

The native replay writes an early and a settled image per gfix-23 control at
1920×1080 and 100% UI scale. Its trace remains the source of exact values and
publishing frame order.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-120 && python3 tools/visual_probe_runner.py --task-id qa-120 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 30 --expect-size 1920x1080 --proof-contract tools/qa120/native_contract.json --result-manifest /private/tmp/labyrinth_codex/qa120-native-manifest.json tools/qa120/campaign.gd -- --out=/private/tmp/labyrinth_codex/qa120-native --case=all --fixture=/private/tmp/labyrinth_codex/perf-140/native-r1-pairs/fixtures-v3.var
```

To inspect a seeded window, pass `--seed=… --capture-step=…` and use the
runner’s `--min-images 2 --expect-size 1920x1080`. Capture names contain the
seed and step. Repeated windows on the same step share the first pair of
captures. Headless emits no images.

## Chosen defaults

- Seeds 12001–12032, one generated encounter per seed, nine seeded decisions
  per fight plus explicit Pass checks, four shards, and a 900-second shard
  watchdog.
- Gaps 0–6 for rapid input and 24 frames for ordinary input. Observe 24 frames
  after the second event. Every fourth seed uses normal combat pacing. The
  other seeds use Fastest with 4× simulation time. The input-ready deadline
  is 60 seconds.
- The controls use fixture seed 102, the review fixture card substitutions, and
  the 1 HP lethal reproduction. The input matrix reuses the encounter and uses a
  0.75 left-stick pulse. Mouse card selection searches a small grid of exposed
  hit points on the existing card widget.
- Capture geometry is fixed for proof. The campaign never modifies production
  assets, layout, gameplay values, saves outside the isolated proof directory,
  or the task queue.
