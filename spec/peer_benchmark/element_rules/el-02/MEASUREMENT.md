# el-02 encounter measurement

Report only. The unmodified spx-01 `Bot.Policy` ran on the existing Warband/Snare room-spec generators, all six variants at tiers 1–3. Room seed 83, one run per row, the harness tier decks and 24 HP. No balance value, deck, policy coefficient, turn cap or objective was changed. These are medians of one observation per row; win rates are therefore 0% or 100%, not statistical estimates. Turn-cap losses remain losses.

Design bands: 3–6 turns and 4–8 HP lost. HP lost is the harness `hp_lost` (damage received), not net HP. Both conditions are required for “in band”.

| Fight | Tier | Variant | Base turns / HP / win | After turns / HP / win | After bands |
|---|---:|---|---|---|---|
| Snare | 1 | air | 3 / 3 / 100% | 3 / 3 / 100% | HP outside |
| Snare | 1 | earth | 2 / 0 / 100% | 2 / 0 / 100% | turns outside, HP outside |
| Snare | 1 | fire | 2 / 0 / 100% | 2 / 0 / 100% | turns outside, HP outside |
| Snare | 1 | ice | 1 / 0 / 100% | 1 / 0 / 100% | turns outside, HP outside |
| Snare | 1 | lightning | 2 / 0 / 100% | 2 / 0 / 100% | turns outside, HP outside |
| Snare | 1 | shadow | 2 / 0 / 100% | 2 / 0 / 100% | turns outside, HP outside |
| Snare | 2 | air | 3 / 5 / 100% | 3 / 6 / 100% | in band |
| Snare | 2 | earth | 4 / 0 / 100% | 4 / 0 / 100% | HP outside |
| Snare | 2 | fire | 3 / 0 / 100% | 2 / 0 / 100% | turns outside, HP outside |
| Snare | 2 | ice | 2 / 0 / 100% | 2 / 0 / 100% | turns outside, HP outside |
| Snare | 2 | lightning | 4 / 0 / 100% | 4 / 0 / 100% | HP outside |
| Snare | 2 | shadow | 3 / 0 / 100% | 3 / 0 / 100% | HP outside |
| Snare | 3 | air | 2 / 4 / 100% | 2 / 4 / 100% | turns outside |
| Snare | 3 | earth | 6 / 11 / 100% | 2 / 0 / 100% | turns outside, HP outside |
| Snare | 3 | fire | 2 / 3 / 100% | 2 / 3 / 100% | turns outside, HP outside |
| Snare | 3 | ice | 1 / 0 / 100% | 1 / 0 / 100% | turns outside, HP outside |
| Snare | 3 | lightning | 3 / 0 / 100% | 3 / 0 / 100% | HP outside |
| Snare | 3 | shadow | 7 / 15 / 100% | 7 / 15 / 100% | turns outside, HP outside |
| Warband | 1 | air | 30 / 6 / 0% | 30 / 6 / 0% | turns outside |
| Warband | 1 | earth | 6 / 3 / 100% | 7 / 8 / 100% | turns outside |
| Warband | 1 | fire | 4 / 7 / 100% | 4 / 7 / 100% | in band |
| Warband | 1 | ice | 6 / 3 / 100% | 6 / 3 / 100% | HP outside |
| Warband | 1 | lightning | 7 / 6 / 100% | 7 / 6 / 100% | turns outside |
| Warband | 1 | shadow | 2 / 0 / 100% | 2 / 0 / 100% | turns outside, HP outside |
| Warband | 2 | air | 8 / 0 / 100% | 23 / 4 / 100% | turns outside |
| Warband | 2 | earth | 12 / 12 / 100% | 30 / 7 / 0% | turns outside |
| Warband | 2 | fire | 10 / 2 / 100% | 10 / 2 / 100% | turns outside, HP outside |
| Warband | 2 | ice | 10 / 2 / 100% | 13 / 2 / 100% | turns outside, HP outside |
| Warband | 2 | lightning | 7 / 6 / 100% | 7 / 6 / 100% | turns outside |
| Warband | 2 | shadow | 7 / 0 / 100% | 7 / 0 / 100% | turns outside, HP outside |
| Warband | 3 | air | 5 / 4 / 100% | 8 / 4 / 100% | turns outside |
| Warband | 3 | earth | 15 / 5 / 100% | 12 / 4 / 100% | turns outside |
| Warband | 3 | fire | 9 / 15 / 100% | 9 / 18 / 100% | turns outside, HP outside |
| Warband | 3 | ice | 6 / 11 / 100% | 6 / 6 / 100% | in band |
| Warband | 3 | lightning | 9 / 8 / 100% | 9 / 8 / 100% | turns outside |
| Warband | 3 | shadow | 10 / 4 / 100% | 30 / 2 / 0% | turns outside, HP outside |

33/36 sampled rows are outside at least one design band. The director decides any tuning.

Raw evidence: `measurement-before.json`, `measurement-after.json`, and their runner logs. The harness wrapper and named measurement settings are in `tests/el02_evidence.gd`.

Reproduction (current code gives the after result):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/el-02 && python3 tools/godot_task_runner.py --task-id el-02 --timeout 3600 --stream -- godot --headless --path . --script tests/el02_evidence.gd -- --phase after
```
