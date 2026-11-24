# gfix-48 collision implementation and proof

## QA-133 root cause

Seed 133001, decision 3667, offers `(1, 2) → (2, 2) → (3, 2)`. The checkpoint replay found Veilbound Acolyte 6 visible at `(2, 2)` and Veilbound Acolyte 5 hidden at `(3, 2)`. The equipped Vaulting Sigil contributes `move_through_enemies_stagger` with Stagger 2. In the counterfactual that removes only that relic, `(3, 2)` is no longer offered. The real rule allows the intermediate enemy and requires an open landing. The resolver trims both occupied tiles, so the hero stays at `(1, 2)` and spends 0 Movement.

The real click plays the contact beat against Acolyte 5. This case leaves the hero two tiles away from the blocker, so playback uses the existing temporary actor visibility field to show that Acolyte during the beat. Ordinary sight governs the next offer. QA-133 can offer the same landing again, and resolving it still produces feedback. In the Eclipse walk fixture, the reached tile `(2, 2)` puts the blocker inside ordinary sight and the next offers exclude its tile.

The same state repro ran against `codex/release` at `652f6261f` and the worktree. Both emitted byte-identical `GFIX-48 OUTCOME` lines, including the SHA-256 of the full enemy state.

| Fixture | Destination | Movement spent | Movement remaining | Hero Health | Umbra interruption delta |
| --- | --- | ---: | ---: | ---: | ---: |
| QA-133 first step | `(1, 2)` | 0 | 2 | 7359 | 0 |
| Eclipse three-step offer `(1, 2) → (2, 2) → (3, 2) → (4, 2)` | `(2, 2)` | 1 | 2 | 30 | 1 |

## Requirements

1. Real movement playback walks the reached path, then uses the existing quarter-tile bump and `push.collision` cue. The contact submission shows the actual blocker with its regular sprite, Health bar and intent. `Interrupted` is a `FloatingCombatText` effect using the Card Play popup's size, colour, offset, rise and fade. Forced-movement collisions have hit feedback and a camera kick, with no dedicated unit shake to reuse. The supplied fallback translates both units horizontally by a decaying 6 px sine over three cycles and 180 ms through the normal board position overrides. The dry run checked both actors and found no hit flash, damage number or Health loss.
2. Reduced motion submits the same reveal and cue immediately at contact, with both actors still and a fully opaque, stationary `Interrupted` for 900 ms.
3. Removed the bump shade, combat memory, memory pruning, and the offer and undo-report hooks for it. The Umbra save migration strips the legacy key from live combat and pending combat checkpoints. Each scene case reloads its actual post-bump checkpoint.
4. QA-133 retains the Vaulting Sigil crossing rule and produces first-step feedback for the blocked landing. The real checkpoint and relic-removal counterfactual are in the state repro.
5. Independent moves keep `blocked_tile` in the existing tile format and `steps_reached`. The scene checks `player_movement_interrupted` for QA-133 and `player_moved` for the Eclipse walk. The memory-only entry in the undo change list is removed. [Analytics specification](../../spec/analytics.md#surface-rules-v5)
6. The only new player-facing text is the `Interrupted` popup.
7. The gfix-39 memory checks and shade probe are retired. The replacement is task-local proof under `tools/gfix48/`, outside the permanent suites.

## Changed files and line ranges

| File | Changes |
| --- | --- |
| `scripts/run_scene.gd` | Lines 23789–23790 pass the blocked tile into playback and carry the blocker disclosure into the Move’s remaining frames. |
| `scripts/combat_engine.gd` | Compared with the prepared task HEAD, removed lines 148, 1550–1553, 1817, 1881, 8438–8439, 12187 and 12205. In the worktree, lines 7672, 7675, 7680, 7683 and 7690 use the existing Vaulting choice and record the blocked tile directly. Line 8430 restores the ordinary occupancy signature. |
| `scripts/umbra_movement_view.gd` | Plays and times the collision, visibility, shake and popup. |
| `scripts/umbra_movement.gd` and its UID | Removed the remembered occupancy field and helper. |
| `scripts/umbra_combat_migration.gd` | Erases remembered occupancy on load. |
| `scripts/battlefield_rules/committed.gd`, `scripts/movement_undo_rules.gd`, `scripts/surface_variety_relic_rules.gd` | Remove the memory pruning, analytics change-list entry and Vaulting offer hook. |
| `scripts/battlefield_rule_view.gd`, `scripts/combat_board_view.gd` | Remove the old bump shade adapter. The board also supplies the reduced-motion caption scrim as a popup placement obstacle. |
| `scripts/intent_badges.gd` | Build the blocker’s regular intent badge on the contact frame. |
| `tools/gfix39/`, `tools/gfix48/` | Retire the old executable repro and probe. Move the GDScript UIDs and provide the updated fixtures, state repro, scene probe, capture contract, launcher and this result. |

## Headless receipts

```text
GFIX-48 RELEASE STATE: 8 checks, 0 failures
GFIX-48 WORKTREE STATE: 12 checks, 0 failures
GFIX-48 STRIP first_normal: contact=100 ms, popup=490 ms, 6 shake half-cycles, 1 collision cue, save/resume PASS
GFIX-48 STRIP first_reduced: contact=0 ms, popup=900 ms, 0 shake half-cycles, 1 collision cue, save/resume PASS
GFIX-48 STRIP one_step_normal: contact=430 ms, popup=480 ms, 6 shake half-cycles, 1 collision cue, save/resume PASS
GFIX-48 STRIP one_step_reduced: contact=340 ms, popup=900 ms, 0 shake half-cycles, 1 collision cue, save/resume PASS
GFIX-48 SCENE STRIPS: 4 cases, 0 failures (headless dry run)
GFIX-48 NATIVE DRY RUN PASS — /private/tmp/labyrinth_codex/gfix-48/headless.pV8N89
```

- Baseline and worktree receipts are under `output/gfix48/`. The macOS CA certificate diagnostic appeared in both baseline and worktree runs. [Release](../../output/gfix48/release.log) · [Worktree](../../output/gfix48/worktree.log) · [Scene dry run](../../output/gfix48/native-dry.log)
- UI identity lint printed `Ran 25 tests in 5.663s` and `OK`. [UI identity log](../../output/gfix48/ui-identity.log)
- Rules text lint printed `Ran 3 tests in 0.146s`, `OK` and `PASS: Rules text lint (16 existing hits)`. [Rules text log](../../output/gfix48/rules-text.log)
- The Python default group printed `INPUT GROUP default: always run`, `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 28.587s` and `OK`. The runner exited 0. The optional learned timing cache write was denied by read-only Git metadata after the tests passed. [Default group log](../../output/gfix48/python-default.log) · [Summary](../../output/gfix48/python-default/summary.json)
- `git diff --check`, shell syntax checks and JSON parsing of the capture contract exited 0.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-48 && tools/gfix48/native.sh
```

The launcher runs the visual probe with `LABYRINTH_CEL_LOOK=all`, using an exact 1920×1080 SubViewport at 100% UI scale. It captures all four cases, with a strip every 30 ms through popup removal, a contact PNG and both offer PNGs. It prints each absolute PNG path and writes `manifest.json` under `/private/tmp/labyrinth_codex/gfix-48/native.*`. The same launcher accepts `--dry-run`. The dry run recorded isolated saves and JSONL analytics in `/private/tmp/labyrinth_codex/gfix-48/headless.pV8N89`.

The state comparison can be repeated with the same fixture against both projects.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-48 && python3 tools/godot_task_runner.py --task-id gfix-48 --stream -- godot --headless --path ../release --script "$PWD/tools/gfix48/move_repro.gd" -- --baseline
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-48 && python3 tools/godot_task_runner.py --task-id gfix-48 --stream -- godot --headless --path . --script tools/gfix48/move_repro.gd
```

## Chosen defaults

- The synthetic fixture carries forward seed 39001, a 30-Health hero, Tremor in a one-card hand, a 1-Health crawler at `(3, 2)`, and a survivor at `(7, 7)`. It equips existing Pilgrim Boots to get a three-step offer ending at `(4, 2)`.
- The probe uses the existing 100 fps capture clock, a 12-second readiness timeout, an eight-frame settle, and a five-second strip limit. It allows one frame of measurement tolerance for popup duration. The launcher uses a 300-second native timeout for rendering and PNG encoding.

## Open issues

Windowed pixel and audio inspection are pending on a Mac with window-server access. There are no `TODO_DESIGN_*` placeholders. The worktree changes are uncommitted.

## Director feedback 1

- The board had a compass descriptor at contact, but the red medallion is drawn from the regular intent badge rows. The bump now submits the blocker's own badge row with its sprite and board Health. At the same boundary, the rail replaces only that actor's scheduled slots with their ordinary portrait and Health presentation. The playback carries the disclosure into the Move's remaining frames.
- The reduced popup already submitted text with alpha 1. Its stationary placement put it behind the Movement caption's dark scrim. The existing popup placer now treats that scrim's full bounds as an obstacle for the reduced interruption popup. The task-local probe checks the laid-out text stays outside the scrim for the full 900 ms.
- The first-step capture uses The Last Eclipse checkpoint. The one-step capture uses the game-generated Sealed Grotto layout and title, with the deterministic collision roster, hero position and Eclipse sight seeded into that room.
- The launcher preserves the 30 ms strips and before/after and contact images. It adds one full-view `*_contact_plus_0060ms.png` per case. The proof contract also checks each new image's rail region.

All four `GFIX-48 SCENE` outcome lines were byte-identical to round 0, including the path, Health, remaining Movement and enemy-state hashes. The state repro outcome lines also matched round 0.

```text
GFIX-48 WORKTREE STATE: 12 checks, 0 failures
GFIX-48 STRIP first_normal: contact=100 ms, popup=490 ms, 6 shake half-cycles, 1 collision cue, save/resume PASS
GFIX-48 STRIP first_reduced: contact=0 ms, popup=900 ms, 0 shake half-cycles, 1 collision cue, save/resume PASS
GFIX-48 STRIP one_step_normal: contact=410 ms, popup=480 ms, 6 shake half-cycles, 1 collision cue, save/resume PASS
GFIX-48 STRIP one_step_reduced: contact=320 ms, popup=900 ms, 0 shake half-cycles, 1 collision cue, save/resume PASS
GFIX-48 SCENE STRIPS: 4 cases, 0 failures (headless dry run)
GFIX-48 NATIVE DRY RUN PASS — /private/tmp/labyrinth_codex/gfix-48/headless.PNCXVn
```

- The scene probe checked the laid-out medallion and the rail's portrait and Health control at contact and throughout playback. The rail's other entries matched their pre-click presentation. [Scene dry run](../../output/gfix48/native-round1-dry.log) · [State repro](../../output/gfix48/worktree-round1.log)
- UI identity lint printed `Ran 25 tests in 4.071s` and `OK`. Rules text lint printed `Ran 3 tests in 0.049s`, `OK` and `PASS: Rules text lint (16 existing hits)`. [UI identity](../../output/gfix48/ui-identity-round1.log) · [Rules text](../../output/gfix48/rules-text-round1.log)

The native command above writes the updated strip set and manifest to a fresh `/private/tmp/labyrinth_codex/gfix-48/native.*` directory. Windowed verification of this revision remains pending.
