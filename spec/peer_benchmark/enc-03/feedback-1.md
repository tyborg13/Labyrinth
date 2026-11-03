# enc-03 — director feedback 1

All changes remain uncommitted on `codex/enc-03`. The accepted measurement
reports are unchanged; their 12 archived SHA-256 hashes still match round 0.
No encounter measurements or full suites were rerun.

## 1. Resolved scaled damage everywhere

The badge and expanded action row show the resolved centre damage. Callouts,
full intent tooltips and tile tooltips interpolate the resolved centre and arm
values into the director's exact sentences. There is no base-damage fallback.
Aiming uses the scaled landing forecast from `Lob.presentation_action`; landing
uses the revealed action that the damage preview and resolver use. Tile damage
medallions use that same action. `TODO_DESIGN_scaled_lob_copy` is resolved and
removed; no design placeholders remain.

The regression exercises aiming and landing at depth 6 (6 centre / 4 arm) and
18 (7 centre / 5 arm), checking the compact badge, expanded row, compass,
callout, full tooltip, tile tooltip, danger preview and actual centre/arm HP
loss. The real tier-2 fire Warband headless fixture now reads `Lob Slag 7` on
both turns, with nine danger tiles present from aiming.

Implementation files changed this round: `scripts/action_icon_library.gd`,
`scripts/intent_badges.gd`, `scripts/enemy_intent_compass.gd`,
`scripts/enemy_mechanics/lob.gd`, `scripts/enemy_mechanics/lob_view.gd`,
`scripts/combat_board_view.gd`; their focused tests and live probe; and
`tools/enc03_proof.py` so baseline proof also restores the lob helper. No new
player-facing tuning values, assets, input paths or analytics changes.

## 2. Pre-existing HUD badge failures

All three failures are in `tests/combat_hud_badges_test.gd` and reproduce at
baseline commit **`e3034e24fd8193daf717c691ba8939094927ac51`**, before enc-03.
The assertions were not edited. These are the exact failed assertion labels:

| Test location | Assertion |
| --- | --- |
| `tests/combat_hud_badges_test.gd:60` | Intents starts off with its semantic label intact |
| `tests/combat_hud_badges_test.gd:65` | ON retains semantic text and brightens the plate |
| `tests/combat_hud_badges_test.gd:191` | Controller focus must expose the complete inspection tooltip |

Line 60 requires `intents.visible and not intents.button_pressed and intents.text == "INTENTS [I]"`.
Line 65 requires `intents.text == "INTENTS ON [I]"` and the normal border colour
`Palette.GOLD_BRIGHT`. Line 191 requires `frame.has_focus()` and the controller
cursor's `detail_text` to equal `frame.tooltip_text.strip_edges()`.

Baseline evidence: `output/enc-03/baseline-hud-badges.log` reports those three
errors and `COMBAT HUD BADGES TEST: FAIL`; its wrapper ends with
`ENC03 BEFORE SOURCE RESTORATION: PASS`. Round-0 current evidence is
`output/enc-03/hud-badges.log`, with the same three errors. These historical
failure checks were not rerun for this focused presentation-only feedback.

## Focused verification

Exact commands, exit codes and observed result lines are in
[feedback-1-proof.json](feedback-1-proof.json); logs are in
`output/enc-03/feedback-1/`.

- `ENC03 SLAG TEST: PASS (697 checks; 0 failures)`
- `EN04 ENEMIES TEST RESULT: PASS (420 checks, 0 failures)`
- `ENEMY INTENT PREVIEW TEST RESULT: PASS`
- `THREATS AT REST TEST RESULT: PASS (16251 assertions; includes compass suite)`
- Before and after: `ENC03 LOB PROBE: PASS (3 states; 0 failures)`
- UI identity: 25 tests, `OK`.
- Python measurement/proof-tool checks: 18 tests, `OK`.

Chosen defaults: the only added fixture inputs are depths 6 and 18. Existing
proof defaults remain unchanged. No new player-facing defaults were selected.

## Windowed proof for the director

No native captures were attempted. Both proof contracts require 1920×1080,
100% UI scale. Run these sequentially, without concurrent edits or measurement
processes in this worktree; the before wrapper restores baseline source and
then restores the current files even if capture fails.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/enc-03 && python3 tools/enc03_proof.py --phase before
cd /Users/borgerding/workspace/Labyrinth.worktrees/enc-03 && python3 tools/enc03_proof.py --phase after
cd /Users/borgerding/workspace/Labyrinth.worktrees/enc-03 && python3 tools/inspection_fixture.py --task-id enc-03 --run-id enc-03-fire-warband --manifest output/enc-03/fire-warband-inspection.json --scenario warband --warband-biome fire --warband-tier 2 --warband-case pre_battle --launch
```

The wrappers use `tools/visual_probe_runner.py`. Expected images are
`{before,after}_{pre_battle,aiming,landing}_1920x1080.png` in each runner's
isolated `user://probes/enc03_lob/`. The before/after result manifests in
`output/enc-03/` will record their absolute PNG paths. Renderer inspection,
visual judgment and the verified inspection fixture remain with the director.
