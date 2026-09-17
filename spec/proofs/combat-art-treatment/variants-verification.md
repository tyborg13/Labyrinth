# Lighting variants verification — 2026-09-17

## Requirement and result

The user approved a stronger follow-up to Mikus's “could be saucier” feedback: five distinct looks, deeper light/dark regions, stronger contact shading, grounded potion/intent symbols, subtle dynamic fill and position-responsive rims, with background integration deferred. The user then rejected unrealistic examples with overlapping actors and a scavenger cart in combat.

The replacement showcase is an unmodified generated encounter: seed 62001, room (1,1), Hollow Grotto. Player (1,4); grave surgeon (6,6), acolyte (3,2), harrier (7,3); two real torch columns; original crates, traps, equipment and crimson draught. Room metadata and layout both identify ordinary combat; no NPCs or scene props are present. The initial hand and HP are generated normally. Actor footprints, terrain and pickups are disjoint and on passable cells. Movement resolves a real adjacent step to (1,3) through CombatEngine, then samples the production movement presentation.

Earlier showcase captures from the forced scavenger room and arbitrary movement offset are **superseded** and are not acceptance evidence. The new probe rejects both mistakes before recording accepted captures. Internal synthetic renderer stress tests remain technical checks, separate from the realistic user-facing comparison.

## Fresh proof

Source hashes in `variants-source-hashes.json` identify the runtime and final probe. The runtime was unchanged between the full-suite/performance runs and the final scenario correction; only the new probe and documentation changed afterward.

- Full `tests/run_tests.gd`: **PASS**, exit 0. Known legacy-save migration and ObjectDB shutdown warnings; no failed assertion or script/shader error.
- `tests/combat_lighting_variants_probe.gd`: **PASS**, native Metal, eleven 1920×1080 captures at 100% UI scale. Valid generated scenario, no actor/terrain/pickup overlap, genuine room type/props, unchanged generated enemy composition and loot; negative checks reject the two earlier mistakes. All five looks are distinct. Sampled backdrop/cards/HUD stay pixel-identical. Each deliberate preset switch rebuilds the floor once; flicker does not rebuild it. Reduced-motion light is exactly stable. Live movement selection, legal hover, controller focus and cancel pass. A production-resolved movement step has valid occupancy. A separate native shader swatch proves opposite rim directions on either side of a source and the 24-source upload limit.
- `tests/combat_art_treatment_probe.gd`: **PASS**, eight native captures; cached/direct floor equivalence, source-alpha preservation, untagged UI, partial Umbra, targeting and normal motion.
- `tests/enemy_intent_compass_probe.gd`: **PASS**, eleven native captures; existing family identities, support/attack refresh, focus, hidden enemies, reduced motion and moving boss.
- `tests/enemy_shadow_dissolve_probe.gd`: **PASS**, thirteen native captures; early/mid/end appearance, motion-reduced endpoint, impact continuity and node lifecycle.
- `git diff --check`: **PASS**.

The five replacement looks, untreated baseline, legal targeting and movement were inspected at native resolution. Light pools now distinguish lit stone from dark periphery; the potion and symbols have tighter floor contact. Warm and balanced preserve more ambient visibility; moody and dramatic intentionally deepen unlit corners. Actor details and attack/defense meanings remain readable. Intent-family/dense/boss checks and the death contact sheet were separately inspected for renderer regressions.

## Evidence locations

Durable root:

`/Users/borgerding/.codex/visualizations/2026/09/17/01a0acec-2bc4-7051-8564-94947a7a7951/combat-art-treatment/`

The accepted showcase is `lighting-variants-v2/`: `00_untreated.png`, `01_gentle.png` through `05_dramatic.png`, flicker/reduced-motion/targeting/movement frames, `capture.log`, `capture-manifest.json`, `fixture-manifest.json`, the five-choice comparison and replacement silent wipe video. “Untreated” means the art-treatment inspection switch is off, not the previously sent revision.

The unchanged-runtime regression/performance evidence is in `lighting-variants-v1/`: `full-suite.log`, `art-probe.log`, `intent-probe.log`, `death.log`, matching manifests, `four_torch_benchmark.gd`, `verification-runs.json` and `performance.json`. Its main showcase images are superseded, as explained above. Committed copies of timing data and the workload modification accompany this report. Peer review corrected two typed-array declarations in the committed benchmark copy to a typed default and explicit appends for Windows compatibility; the measured external script remains intact as provenance. The equivalent declaration-only correction was checked by loading the committed script in a fresh headless Godot process; runtime and timing behavior are unchanged.

## UI rubric

| Gate | Result / evidence |
| --- | --- |
| Hierarchy and consequence | Pass: targeting/controller highlight, movement budget, HP and card UI stay readable in the real encounter. |
| Visual cohesion | Pass: shared light, contact pools and ground-profile symbols; five choices expose the artistic tradeoff. |
| Gameplay visibility | Pass: actor and symbol ambient floors, ungraded tactical cues, partial Umbra and death coverage. |
| Interaction completeness | Pass: real movement selection/target/hover/controller/cancel, production-resolved step, plus existing full suite. No input routing changes. |
| Accessibility | Pass: exact reduced-motion stability; distinct preexisting icon silhouettes and family color meanings retained. |
| Copy and layout | Pass: unchanged gameplay copy and geometry; no new player-facing control or icon identity. |
| Proof realism | Pass: generated combat topology/composition/props, footprint checks and verified save; all accepted showcase captures inspected at 1920×1080 / 100%. |

## Matched performance

Godot 4.6.1, Mobile/Metal 4.0, Apple M5 Pro, 1920×1080. Sequential ABBA order: unchanged local master `a31807e8523e382b693ba1ec30ef11dafaff3459`, candidate, candidate, baseline. Both run the same workload, copied from the existing benchmark with four torch columns and a reduced-motion cached/direct equivalence sub-check. Six enemies, active Umbra and the existing four phases are retained. 45 warm-up frames and 150 measured frames per phase; GUI workloads were serialized.

| Phase | Baseline median frame interval, ms | Candidate median, ms | Baseline p95, ms | Candidate p95, ms |
| --- | --- | --- | --- | --- |
| Idle | 8.321 / 8.341 | 8.343 / 8.329 | 8.480 / 8.634 | 8.587 / 8.597 |
| Interaction | 8.313 / 8.330 | 8.332 / 8.315 | 8.449 / 8.563 | 8.571 / 8.701 |
| Movement | 8.339 / 8.314 | 8.304 / 8.298 | 8.511 / 8.583 | 8.594 / 8.620 |
| Action heavy | 8.311 / 8.318 | 8.370 / 8.348 | 8.639 / 8.661 | 8.668 / 8.693 |

Both retain approximately 120 Hz typical pacing on this machine; there is no systematic frame-interval regression in these samples. Candidate idle/interaction/movement draw calls rise by one, with a few more in effect-heavy phases. Both have 775 nodes and zero orphan nodes. Static memory rises from about 201.45 MB to 202.22 MB. Candidate cached/direct mean-channel difference is about 0.000363 and passes. The first baseline's CPU draw timing is unusually low relative to its repeat, so these samples do not establish a precise CPU-overhead figure.

All four benchmark invocations exit 1 on the same three existing Umbra MultiMesh-versus-ArrayMesh image-equivalence assertions, reproduced on unchanged master. Timings are comparative evidence, **not a passing benchmark**. Other lifecycle/cache assertions pass. Metal reports no usable GPU duration. No Windows, Steam Deck or worst-case 24-light performance claim is made. The shader adds work to the cached composite; its two bounded source loops require target-hardware profiling before universal performance claims.

## Reproduce and inspect

From the task worktree, run:

```sh
python3 tools/inspection_fixture.py --task-id unify-combat-art-with-efficient-grading-contact-shading-and-shared-light --run-id combat-art-realistic-20260916 --scenario combat --seed 62001 --room-coord 1,1 --summary 'Hollow Grotto: three naturally generated enemies and loot; shared lighting comparison'
python3 tools/visual_probe_runner.py tests/combat_lighting_variants_probe.gd --task-id unify-combat-art-with-efficient-grading-contact-shading-and-shared-light --no-headless --min-images 11 --expect-size 1920x1080 -- --inspection-save '/private/tmp/labyrinth-godot-home/combat-art-realistic-20260916/Library/Application Support/Escape the Umbra Parallel combat-art-realistic-20260916/current_run.save'
```

Self-healing interactive launch:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/unify-combat-art-with-efficient-grading-contact-shading-and-shared-light && python3 tools/inspection_fixture.py --task-id unify-combat-art-with-efficient-grading-contact-shading-and-shared-light --run-id combat-art-realistic-20260916 --launch --scenario combat --seed 62001 --room-coord 1,1 --summary 'Hollow Grotto: three naturally generated enemies and loot; shared lighting comparison'
```

Prefix the launch's Python command with `LABYRINTH_ART_LOOK=moody` (or any preset in the design specification) to inspect another look. Continue opens the pre-action encounter. Publication is pending user inspection/approval; this report does not authorize pushing or landing.
