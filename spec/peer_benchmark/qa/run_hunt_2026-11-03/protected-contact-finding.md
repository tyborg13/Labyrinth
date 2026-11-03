# Protected finding: Gloam Stalker Ambush contact payload

Status: **confirmed** in the default campaign and a fresh single-process seed
replay, both at decision 2475 in the same room. No protected file is edited.

- Seed **5**, decision **2475**, section **5**, ordinary `combat`, encounter
  `t2_biome_warden`, room `(22, -8)`; driver chooses a legal preferred movement
  tile `(4, 6)` before the animation error.
- `SCRIPT ERROR: Invalid access to property or key 'actor_key' on a base object of type 'Dictionary'.`
- Source: `scripts/maquette_cutout_runtime/contact_actions.gd:18`.
- Stack: `assets/units/gloam_stalker_cutout/actions.gd:18`, `_blink` at line 64,
  `scripts/run_scene.gd:23626` (`_play_timed_animation_frames`).
- Raw log: `/private/tmp/labyrinth_codex/qa-23/campaign-default/seed-000005/godot.log:2563`.
- The campaign continues making decisions after the error. It is a script error,
  not evidence of a native crash or a softlock. The runner may later convert its
  native zero exit to a failing status because it scans script errors.

The compound Stalker step can carry an effectless nested strike. In
`scripts/enemy_mechanics/stalker.gd:90–92`, `_enemy_action_step_base` can return
`{}` (no damage, movement, status or terrain/trap change), after which
`enemy_after` is inserted. The Gloam adapter unconditionally forwards the nested
strike to `Contact.animate`, setting only `intent_id`; the contact adapter
requires `actor_key`. The old generic playback path handled the nested step
through scene dispatch instead. The private payload diagnostic reproduced the malformed nested payload:
`QA23 NO-EFFECT AMBUSH PAYLOAD: DEFECT OBSERVED; outer actor_key=enemy_1; nested keys=["enemy_after"]`.
The fresh seed replay then reproduced the same runtime error at the exact
original decision and room. Confirmation metadata is retained in
`/private/tmp/labyrinth_codex/qa-23/protected-contact-confirmation.json`.

The affected contact runtime is explicitly hands off for qa-23 (walk-01).
No workaround is applied in the caller or resolver, and no protected regression
test is edited. The owning unit must repair the payload/dispatch contract and
add its own no-effect Ambush playback regression.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-23 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-23/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 2476 --output-dir /private/tmp/labyrinth_codex/qa-23/replay-default-seed-5
```

The confirmation replay uses the archived read-only census driver. Its exact
command record is `/private/tmp/labyrinth_codex/qa-23/replay-default-seed-5/seed-000005/command.json`.
The additional driver only reads node/pool counts and terminal combat state;
policy, inputs, limits and production files remain unchanged.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-23 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-23/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 2710 --script /private/tmp/labyrinth_codex/qa-23/run_hunt_census.gd --output-dir /private/tmp/labyrinth_codex/qa-23/owner-contact-confirm-01
```

Use a fresh output directory on every invocation. No corrected replay or
fail-before/pass-after regression is claimed: the owning unit must implement
the protected fix first.

The final fixed-art-renderer seed-4 follow-up also reproduced this protected
error at decision 2756, section 5, room `(23, -11)` (`t3_biome_support`). It still
completed with victory; native exit 0 was converted to runner status 1. The
world-art guard does not alter this contact-runtime payload defect.
