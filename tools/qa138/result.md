# qa-138 results

Release baseline `c6d0e65fca428d19d2ac2b36f4b9704b0137a374` also matched the worktree HEAD before the two tooltip guards.

## Acceptance

1. `LoopMovePlate` and `LoopTraitRow` return `null` for empty or whitespace-only text. The headless witness hovers every known-move plate and trait row in the pinned inspections for Crawler, Ember Tick, Cinder Ooze and Burrow Grub. Crawler, Ember Tick and Cinder Ooze each had one empty-text plate. Their native pop-up counts went from one each to zero. The Burrow Grub move, Ember Tick Burst trait and Cinder Ooze Split trait each opened a pop-up. A diff of the three source and rendered text records was empty. The witness also calls both overrides with whitespace-only input.
2. The ui_32 probe and its proof contracts are under `tests/`. Both failing expectations were stale. Whispering Well and Sealed Sarcophagus showed two columns at both test sizes, with a shared top edge above the reward plate. The old check required one. Owner-approved ui-36 (`4490e3aae`, merged in `c835a33c3`) wraps when the stack exceeds the painting height. The probe now checks the expected column count from the height of the unwrapped stack. Its existing layout checks cover bounds, gaps, reading order and the shared top edge.

## Headless proof

| Check | Exact result |
| --- | --- |
| `tools/qa138/witness.gd` on release UI | `QA-138 witness: FAIL \| 4 enemy kinds, 4 move plates, 2 trait rows, 3 populated popups, 3 empty-text spots, 3 empty-text popups` |
| `tools/qa138/witness.gd` with the guards | `QA-138 witness: PASS \| 4 enemy kinds, 4 move plates, 2 trait rows, 3 populated popups, 3 empty-text spots, 0 empty-text popups` |
| ui_32 `--semantics-only` before expectation fix | `UI-36 semantics 1920x1080 at 1.00: 4 event choices, 2 failures` |
| ui_32 `--semantics-only --compact` before expectation fix | `UI-36 semantics 1280x800 at 1.15: 4 event choices, 2 failures` |
| ui_32 `--semantics-only` | `UI-36 semantics 1920x1080 at 1.00: 4 event choices, 0 failures` |
| ui_32 `--semantics-only --compact` | `UI-36 semantics 1280x800 at 1.15: 4 event choices, 0 failures` |
| `tests/pre_battle_semantics_test.gd` | `PRE-BATTLE SEMANTICS TEST: PASS` and `TEST RESULT: PASS` |
| `tests/pre_battle_view_test.gd` | `PRE-BATTLE VIEW TEST: PASS` and `TEST RESULT: PASS` |
| `tests/test_ui_identity_lint.py` | `Ran 25 tests in 4.222s` and `OK` |
| Python default group | `INPUT GROUP default: always run`, `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 28.150s` and `OK` |
| Rules text lint, in the default group | `PASS: Rules text lint (16 existing hits)` |
| `tools/qa138/proof_1920x1080.json` | `QA-138 proof contract: 3 captures at 1920x1080` |

The headless Godot runs logged `get_system_ca_certificates` with `ret != noErr`. The pre-battle view test also logged `ObjectDB instances leaked at exit` on both release and the fixed worktree. Both focused tests returned exit code 0.

The Python default group ran with `python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir .godot/qa138-python-default`. It returned exit code 0 and wrote `summary.json` there. The runner logged `[Errno 1] Operation not permitted` when writing its shared Git timing cache.

## Proof for the design owner

Windowed proof is pending because the sandbox has no macOS window server. Run both at 1920×1080 and 100% UI scale.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-138 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --task-id qa-138 --expect-size 1920x1080 --proof-contract tools/qa138/proof_1920x1080.json --result-manifest .godot/qa138-pre-battle-proof.json tools/qa138/witness.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-138 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --task-id qa-138 --expect-size 1920x1080 --proof-contract tests/ui_32_event_reward_tooltip_proof_1920x1080.json --result-manifest .godot/qa138-ui32-proof.json tests/ui_32_event_reward_tooltip_probe.gd
```

The witness writes `empty_plate.png`, `move_tooltip.png` and `trait_tooltip.png` under `user://probes/qa138/`. The event probe writes its six captures under `user://ui-36-event-reward-plates/`. Each runner manifest records the resolved paths.

## Chosen defaults

- Enemy fixtures `crawler`, `ember_tick`, `cinder_ooze` and `burrow_grub` in the first eligible pre-battle room from the existing fixture helper.
- A 1.2-second hover wait, a 3-pixel inset from the row's left edge, pointer parking at `(8, 8)`, and a whitespace-only test input containing spaces, a tab and a newline.
- A central proof region covering the inspection and pop-up area for the three pre-battle captures.

No `TODO_DESIGN` placeholders or `BLOCKER_ui32` findings.
