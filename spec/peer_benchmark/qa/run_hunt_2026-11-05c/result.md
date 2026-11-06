# qa-60 result

Base `5a9a3da25` (Merge perf-56), branch `codex/qa-60`. Three local presentation defects were fixed. All changes remain **uncommitted**; no push, review agent, GUI run or cleanup was performed.

1. **Whole-run requirement met:** 26 hunts ended across the unchanged default/no-embrace launch windows and fresh default-policy top-ups: 4 victories, 19 Embraces, 3 exploration-limit stops. The conservative qualification subset contains **15 frozen-oracle hunts**, 14,766 decisions: 1 victory, 11 Embraces and 3 limit stops. No-embrace seed 6 won the final dragon, **Noctyrax**, in section 5 at decision **2993**. All 26 runners exited 0; no GDScript `SCRIPT ERROR` marker occurred. Eleven earlier discovery runs remain separately reported; they are not used to inflate the 15-run minimum.
2. **Presentation checks added and exercised:** the qualified runs made 3,822,805 model comparisons, including **4,374** controller/pointer target-set comparisons and **12,377** actionable-fight rail checks, with zero parity or rail mismatches. They sampled **71,929** actor bars, **8,961** dying actor bars and **230** dying boss overlays. Fresh scratch rebuilds ran at every decision and terminal checkpoint (14,781 qualified checkpoints), covering 324 room changes, 23 purchase changes, 25 purge changes and 46 scene instances. These change counters are observed transitions, not distinct successful transactions. Separate real menu Continue and purchase/purge probes passed. Natural campaign target samples were card-selection states; focused checks also cover hidden movement/confirmation/privacy. Surface and orientation branches are instrumented but were not sampled as distinct targeting states.
3. **Findings recorded with reproductions and attribution:**

| Finding | Seed / decision | Cause and source on base | Fix proof |
|---|---|---|---|
| F1: retained state/bars stale after room/fight layout changes | default 4 / 42, room (1,2) | `combat_board_view.gd:3320`; terrain-only binding suppresses full sync; hud-03 `7022cd5823`, merge `57af3dda7` | stale layers 158→0; bars 1→5 (5 expected) |
| F2: sliced HUD bypasses forecast values/pulse | no-embrace 4 / 23, room (1,1) | `board_layer_slices.gd:142`; direct entry/detail calls bypass fx-04 decoration; hud-03 hand merge | 5→0 failures; forecast HP 21→24; Block/Freeze/pulse restored; body state unchanged |
| F3: boss overlay uses a different fade clock | no-embrace 6 / 351 | `run_scene.gd:12679`; legacy tint call from `8e4de65582` (Oct 12); no evening merge attributed | real owner 1.0 vs overlay 0.347; controlled midpoint 0.5 vs 1.0 becomes equal; 22 checks pass |

The changes are 3/5/9 changed lines per finding including F3's existing expectation update. The old health-ghost suite passed all 42 checks before the change; its fade expectation now uses the approved shared owner clock. No pre-existing failing assertion was rewritten. Mechanics, input methods, rules text, saves, analytics, assets, tuning and animation timing declarations are unchanged.

## Verification

```text
QA60 RETAINED REGRESSION: stale=0 expected_bars=5 drawn_bars=5
QA60 HUD FORECAST REGRESSION: failures=0 player_hp=24 expected_hp=24
QA60 BOSS OBSERVER: checks=22 failures=0
QA60 HEALTH LIFECYCLE: checks=170 failures=0
QA60 TARGET OBSERVER: checks=104 failures=0
QA60 HEALTH GHOST SUITE: checks=42 failures=0
QA60 POSTFIX VERIFICATION: PASS cases=4 unknown_differences=0 logged_action_prefix_differences=0
Ran 183 tests in 29.927s — OK (Python default: 19 modules)
Ran 25 tests in 6.083s — OK (UI identity lint)
QA60 LIFETIME OWNERSHIP: PASS runs=26 room_samples=753 positive_samples=23 unknown_or_capacity_failures=0 pending=0
```

The post-fix seed-4 no-embrace replay reached 600 decisions and matched the recorded action kind/method/args/card-ID prefix. Inherited anonymous UI records do not identify their control. Four post-fix verification traces contain zero unexpected model differences; each retains only the exact five inherited opening Health-override differences (9999 vs 24, start decisions 0–4). The nine-case opening classifier passed positive/negative controls. Cache poisoning, duplicate/stale bar, missing-candidate, hidden-rail and corrupted boss-forecast controls passed. Native entry parser check and `git diff --check` exited 0. No full Python or Godot suite was run. The Python isolation audit passed (55 modules); no new Python test module was added. The expected read-only Git timing-cache update warning is preserved in `focused-results.txt`.

## Retained failures and open issues

- **Strict census remains FAIL** for no-embrace seed 5, decision 2272: orphan count 0→4. All five section-0/5 pairs pass the adjusted tree bound and other capacity/tile checks. The four nodes are one intentionally detached CardWidget summary layout, below its capacity of 4 layouts; all are released at scene deletion. The original assertion was not weakened. See `node-census-triage.json` and `lifetime-ownership.json`.
- **Three inherited 400-decision fight limits:** no-embrace 7 / 1884, default-extra 13 / 2232, default-extra-v3 18 / 464. These bound exploration; a gameplay softlock was not established. Reproductions and histories are retained.
- **10 pre-existing glossary overflow warnings** (`card_focus_tooltip_stack.gd:325`, Oct-15 `db82e2cfb5`) and **4 unattributed ObjectDB shutdown warnings** remain. Native glossary appearance and resource-lifetime causes are unverified. Every seed/decision/log location and reproduction is in `additional-findings.json`; complete histories remain in the raw runtime ledger.
- Platform CA-certificate diagnostics occur in each Godot process; the cold import also reports the known duplicate placeholder UID. They predate this hunt and do not change the observed runner exits.

## Proof for the design owner

**Actual windowed captures: none.** The sandbox has no macOS window-server access. [README.md](README.md#proof-for-the-design-owner) lists the five exact `visual_probe_runner.py` commands and contracts at **1920×1080, 100% UI scale**. Expected outputs are `native-captures/` (9 images including the real second-fight reproduction), `transition-native-captures/` (2), `health-native-captures/` (8), `forecast-native-captures/` (1), and `boss-native-captures/` (7), each paired with state JSON. Headless fixture labels match their contracts. The director owns pixel/judge review, commits and inspection fixtures; no fixture command was requested in this brief.

## TODO_DESIGN and chosen defaults

TODO_DESIGN: **none**. No player-facing value was chosen. New diagnostic defaults: 15 frozen-oracle runs after 11 discovery runs; target-host seed 60; Block 6; 3-HP test box at (1,1); exit (4,8)→(1,0); forecast loss 3; Freeze 1; sentinel -12345; dissolve samples 0/0.25/0.5/0.75/1; 50-second monitoring and the boss fixture's 180-second native allowance. The seeded transition proof targets section 0, room (1,2). Inherited policy, seed sequence, Health 9999, 8× time, 120 FPS, settle frames and exploration/watchdog bounds were retained. Full commands, hashes and source snapshots are in this directory; raw evidence is `/private/tmp/labyrinth_codex/qa-60/`.
