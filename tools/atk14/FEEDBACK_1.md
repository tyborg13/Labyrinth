# atk-14 feedback 1 — implementation and proof

Both feedback items are implemented. All changes remain uncommitted in `codex/atk-14`. Native capture remains the design owner's step; no windowed run or peer review was attempted.

## 1. Supplied design values

- Compact rule rider: `RULE_RIDER_SIZE = SECONDARY_ICON_SIZE` (16 px), radius factor 0.72, lower-left shoulder. Its top-left relative to the disc centre is (−19.52, 3.52), exactly the supplied formula. The original approved icon is drawn over its cached alpha-contour outline, with a 3 px `Palette.TEXT_OUTLINE` halo. No art asset is generated or edited.
- Caption icon: 28 px. Its rectangle is computed from the actual label font, text width, horizontal alignment and line height/vertical alignment. Its right edge is 8 px before the first glyph. It is a child of the caption, so it inherits the caption's visibility/modulate/fade and remains through the numbers and arcs. The next `_set_action_banner` removes it. Resize/theme changes update its position.
- Caption-only rule hold: 0.6 presentation seconds. Lightning Storm adds no preliminary caption-only wait; its caption remains through bolts, Chain and the existing number tail. Gust retains its existing animation.

All five active `TODO_DESIGN_RULE_*` constants are removed. No new design placeholders were added.

## 2. Every struck unit gets its number at contact

`hit_playback.gd` uses the resolver's existing per-hit snapshots to create presentation receipts. All primary hits share the simultaneous bolt stage; actual victim-to-victim hops retain resolver order and 0.12 seconds per jump. The display copy applies recorded actor deltas at contact, rather than refreshing all Health after the arcs. This also handles interleaved resolver order: a later primary can show its bolt loss without prematurely draining a Chain victim.

Loss numbers use `_floating_texts_for_target_losses`, the standard hit-number formatter, for hero, foes and illusions, including Health, Block and Stoneskin losses. Numbers run concurrently through the existing floating-text timeline; no per-victim pause delays the Chain. The final number tail uses the existing timeline's duration. Caption-only rules also reconcile all actor losses at their step; Gust keeps its existing loss receipts.

The shared board resolver retains rule hit snapshots even for Chain 0, so Dynamo/snare primary victims also have contact receipts. This changes presentation trace capture only. No rule dials, damage/status resolution, AI, save fields or analytics schema/events were changed. Zekarion data and `dragon_combat_rules.gd` remain untouched.

The Zekarion fixture is built by the existing production dragon inspection factory, then stages only a controlled witness: Zekarion and hero on Electrified, a nearby authored Wisp on plain floor. It fires the actual installed Lightning Storm via `Rules.fire`; it does not claim to replay the whole Overload activation. The Wisp is constructed from its current catalog definition, independently of either branch's starting-helper count. Boss Health and rule damage/Chain are never overridden.

## Observed proof

Headless results, all exit 0:

```text
ATK14 RULE PLAYBACK zekarion: PASS
ATK13 CAPTURE zekarion: PASS
ATK14 RULE PLAYBACK zekarion: PASS
ATK13 CAPTURE zekarion: PASS
ATK14 RULE PLAYBACK caption_only: PASS
ATK13 CAPTURE caption_only: PASS
ATK13 CAPTURE playback: PASS
ATK14 RULES RESULT: PASS (0 failures)
THREATS AT REST TEST RESULT: PASS (16952 assertions; includes compass suite)
Ran 25 tests
OK
ATK14 F1 UID SIDECAR: PASS
ATK14 F1 SIDECAR INVENTORY: PASS
ATK14 F1 NATIVE COMMAND SYNTAX: PASS
```

The two Zekarion entries are normal and reduced motion. Both observe primary and Chain contact frames, not merely an eventual final state:

| Stage | Displayed Zekarion Health / boss bar | Number receipts |
| --- | --- | --- |
| Primary bolts | 45 / 45 | hero −5; Zekarion −5 |
| Chain contact | 45 / 45 | Wisp −5; earlier popups continue |

Each of the three units has exactly one popup identity with text `-5`. During primary bolts the Wisp retains its original Health; its number appears on the same contact frame as its Chain loss. Zekarion's number is visible under the `Lightning Storm` caption. The controlled caption-only Frostbite case took 0.619542 presentation seconds in the observed headless run and had no losses. Icon geometry is checked against the laid-out label on every sampled icon frame.

Sidecars/logs (explicitly `headless_semantics_only: true`):

- `/private/tmp/labyrinth_codex/atk-14/feedback1/zek.{json,log}`
- `/private/tmp/labyrinth_codex/atk-14/feedback1/zek-reduced.{json,log}`
- `/private/tmp/labyrinth_codex/atk-14/feedback1/caption.{json,log}`
- `/private/tmp/labyrinth_codex/atk-14/feedback1/peal.{json,log}`
- `/private/tmp/labyrinth_codex/atk-14/feedback1/{rules,threats,lint,uids}.log`

No PNGs were generated here. The logs retain the macOS certificate diagnostic and existing Peal HUD anchor warnings; no script errors remain. No full GDScript/Python suite, balance retune, or census rerun was requested for this round. Round-0 forecast evidence remains in the original handoff.

Exact headless probe commands:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-14 && python3 tools/godot_task_runner.py --task-id atk-14 --stream -- godot --headless --path . --script tools/atk14/capture.gd -- --case zekarion --out /private/tmp/labyrinth_codex/atk-14/feedback1/zek.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-14 && python3 tools/godot_task_runner.py --task-id atk-14 --stream -- godot --headless --path . --script tools/atk14/capture.gd -- --case zekarion --reduced-motion true --out /private/tmp/labyrinth_codex/atk-14/feedback1/zek-reduced.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-14 && python3 tools/godot_task_runner.py --task-id atk-14 --stream -- godot --headless --path . --script tools/atk14/capture.gd -- --case caption_only --out /private/tmp/labyrinth_codex/atk-14/feedback1/caption.json
```

The real Peal probe uses the original audited `1305-2` save with `--view playback`, unchanged from round 0. Rule suites, threats-at-rest and UI identity lint also passed. No new permanent test module was added.

## Proof for the design owner

The existing command now includes the new cases:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-14 && sh tools/atk14/native_proof.sh
```

It uses the visual probe runner, native cel/Metal mobile, 1920×1080, 100% UI scale and no retries. In addition to the round-0 panels/strips, the new exact invocations are:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-14 && LABYRINTH_TASK_ID=atk-14 ATK13_CAPTURE_OUT=/private/tmp/labyrinth_codex/atk-14/captures ATK13_CAPTURE_SCRIPT=res://tools/atk14/capture.gd ATK13_PROOF_CONTRACT=tools/atk13/capture_contract.json sh tools/atk13/native_capture.sh controlled caption_only caption_only --case caption_only
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-14 && LABYRINTH_TASK_ID=atk-14 ATK13_CAPTURE_OUT=/private/tmp/labyrinth_codex/atk-14/captures ATK13_CAPTURE_SCRIPT=res://tools/atk14/capture.gd ATK13_PROOF_CONTRACT=tools/atk14/playback_contract.json sh tools/atk13/native_capture.sh controlled zekarion zekarion_self_strike --case zekarion
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-14 && LABYRINTH_TASK_ID=atk-14 ATK13_CAPTURE_OUT=/private/tmp/labyrinth_codex/atk-14/captures ATK13_CAPTURE_SCRIPT=res://tools/atk14/capture.gd ATK13_PROOF_CONTRACT=tools/atk14/playback_contract.json sh tools/atk13/native_capture.sh controlled zekarion zekarion_self_strike_reduced --case zekarion --reduced-motion true
```

Expected native outputs under `/private/tmp/labyrinth_codex/atk-14/captures/`:

- `peal_disc.png`: the compact ring with its lower-left rider.
- `peal_playback_step*.png`: the Lightning Storm caption with its icon, bolts and arcs on the real save.
- `caption_only.png`, `caption_only_step*.png`: the caption-only beat with its icon.
- `zekarion_self_strike_source.png`, `zekarion_self_strike_step*.png`: source caption, primary self-strike/hero numbers and subsequent Wisp Chain number.
- `zekarion_self_strike_reduced_step*.png`: the reduced-motion equivalent.

Each view also writes `.json`, `.manifest.json` and `.log`. These are prepared paths, not claimed captures. The controlled cases build their own isolated fixture; `inspection_fixture.py` installation is unnecessary. Native pixel quality, outline appearance, icon fade and full-renderer timing remain for the owner to inspect.

## Chosen defaults

Only controlled proof values: boss anchor (4,4), hero tile (3,4), Wisp tile (2,4), hero protection Health 50, and fixture Wisp ID equal to boss ID + 1. Seed 7262026, depth 4 and the balanced production inspection loadout reuse the existing dragon proof setup. Controlled contact/hold probes use native time scale 1 and the inherited headless FPS cap 120; the ordinary Peal proof retains its inherited fast headless clock. No player-facing value was chosen beyond the director's supplied values or existing hit-number/strike timing rules.

## Files changed in this round

- `scripts/intent_badges.gd`: supplied rider geometry and outline.
- `scripts/battlefield_rules/playback.gd`: caption icon/hold, concurrent per-contact numbers and Health state.
- New `scripts/battlefield_rules/hit_playback.gd` and `.uid`: resolved receipt staging for every actor.
- `scripts/board_attack_rules.gd`: retain primary hit traces for rule Chain 0.
- `scripts/run_scene.gd`: remove a rule icon when its caption is replaced.
- `tools/atk14/capture.gd`: controlled native/headless self-strike and caption-only probes.
- `tools/atk14/native_proof.sh`, `tools/atk13/native_capture.sh`: append new native commands; allow the task-local capture subclass while preserving the old default.
- `tools/atk14/README.md`, this report: current status and proof handoff.

TODO_DESIGN placeholders: none remaining for these requests. Open implementation issues: none observed in this round. Native proof remains pending owner execution.
