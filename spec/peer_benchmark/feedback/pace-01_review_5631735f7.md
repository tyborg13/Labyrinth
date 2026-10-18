1. **Medium — Ally support skips the caster’s lead.** [combat_pacing.gd:260](/private/tmp/labyrinth_codex/review/pace-01-5631735f7/scripts/combat_pacing.gd:260) matches only `actor_key`, but ally heal/guard steps identify the caster through `source_actor_key`. An engine-generated heal reproduced `classified=false` and a **0.000006 s** lead. Use the source actor for activation classification and caption ownership; add ally-support coverage.

2. **Medium — `status_damage` bypasses settle.** It is absent from [combat_pacing.gd:12](/private/tmp/labyrinth_codex/review/pace-01-5631735f7/scripts/combat_pacing.gd:12), although the engine emits it for action-triggered bleed. A real bleed-death sequence produced zero settles; the next move-only activation began **0.000135 s** later. Include this feedback in settle handling and cover the early `continue` at [run_scene.gd:24660](/private/tmp/labyrinth_codex/review/pace-01-5631735f7/scripts/run_scene.gd:24660).

3. **Medium — Hidden attacks can settle twice.** [run_scene.gd:24941](/private/tmp/labyrinth_codex/review/pace-01-5631735f7/scripts/run_scene.gd:24941) recursively presents visible portions of hidden attacks, including `after_step`; the outer branch calls it again at [run_scene.gd:24546](/private/tmp/labyrinth_codex/review/pace-01-5631735f7/scripts/run_scene.gd:24546). One attack reproduced **two settles totaling 0.304 s**. Give one layer ownership of the pacing hook and add a clipped-Umbra regression.

4. **Low — Remove unused constants.** `ROUND_CAPTURE_FPS` at [combat_feel_probe.gd:27](/private/tmp/labyrinth_codex/review/pace-01-5631735f7/tests/combat_feel_probe.gd:27) and `Pacing` at [combat_pacing_mutation_test.gd:4](/private/tmp/labyrinth_codex/review/pace-01-5631735f7/tests/combat_pacing_mutation_test.gd:4) are unused.

Verification completed:

- Combat feel, pristine pacing regression, mutation tests, and all **66** requested Python tests passed.
- The repaired fixture retains four activations, one move-only turn, melee/ranged/AoE actions, and exact resolver state/RNG.
- Hit-stop, pause/resume, leaving combat, and detachment completed waits without hanging or leaking speed.
- Both program-suite registration paths successfully ran the mutation test.
- No changed-line Windows typed-array violations, inappropriate tunables, or unrelated scope changes found.

| Headless pass-to-hero time | Before | After |
|---|---:|---:|
| Normal | 4.268 s | 5.348 s |
| Fast | 3.698 s | 4.612 s |
| Fastest | 3.129 s | 3.796 s |

Mutations **caught**: restored 0.20 s cap, dropped lead, move-only wait, unawaited `after_step`, an 11.529 s budget overrun, and an overlapping timeline entry. Removing `heal` from the registry **survived** the regression suite, confirming the utility-action coverage gap.

Every mutation was restored; the checkout is clean. Windowed capture remains director-owned.

CHANGES REQUESTED