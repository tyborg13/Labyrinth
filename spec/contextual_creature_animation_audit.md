# Creature hit and collapse animation audit

The creature cohort covers Crawler, Bone Harrier, Stone Warden, Shale Bloomer (`bile_bloomer`), Lightning Wisp, Cinder Ooze and Cinder Droplet. The current production paint and source registrations remain their visual identity. No PNG was replaced. Shared playback, outcome timing and shadow dissolve are owned by the contextual cutout runtime; these samplers only supply poses.

Each `hit` peaks at authored phase 0.15, makes a small recovery overshoot and returns exactly to rest at 1.0. Every previously grounded terminal remains planted throughout the reaction. Each `death` eases into a stable pose by 0.84 and holds it through 1.0. Cases declare the shared 0.36-second recoil and 0.64232-second collapse (62% of the existing 1.036-second dissolve). There is no idle ripple or new idle motion.

| Creature | Contextual articulation and inspected constraints |
| --- | --- |
| Crawler | Four-contact recoil; the hunch lowers 27 source pixels and pitches forward 0.10 radians as the claws/toes spread slightly. The head remains attached to its owning hunch. Rear proximal thigh paint blends to the body across a shared source-space weight field, preventing the deeper collapse from opening the hip. |
| Bone Harrier | Braced recoil and a 34-pixel knee drop. The defeat solver folds the skeletal legs at their original lengths while retaining planted rigid feet; hands keep the spear grip. Existing walk/retreat/attack/cast solvers remain unchanged. |
| Stone Warden | Small heavy recoil and a 29-pixel armored slump; shield and mace lower with the body. Its accepted projected leg solver preserves the painted armor overlap. The rigid-length knee trial was rejected because it made the plate silhouettes loop unnaturally. |
| Shale Bloomer | Coordinated trunk recoil and a 22-pixel downward bow. Three root tips remain planted. The existing painted hidden root crown supplies exposed sockets during the collapse. |
| Lightning Wisp | Coherent recoil, then a 24-pixel sink and six-pixel inward branch contraction. The rigid aperture stays intact. Stronger contraction was rejected because it exposed straight segmentation edges. |
| Cinder Ooze | Crusted mass recoils, then settles 22 pixels into its six flexible lobes, which splay seven pixels; crust plates never squash or shear. |
| Cinder Droplet | Rigid cap recoils and settles 15 pixels while the five continuous tendril meshes lose their arch and spread. |

## Source ownership and reproducibility

`tools/prepare_contextual_creature_cases.py` copies current production layouts, PNGs and motion into fresh ignored output. It preserves the pre-pass sampler from commit `0d104bcdc907bdc17f581f9e25c68bf872eec4bf` for exact legacy-pose comparisons. Historical builders are never replayed. Historical case metadata supplies the existing clip phase curves; production renderer constants refresh current walk/idle cadence.

The Crawler repair changes only the `rear_leg_near` weight family in its production rear layout. Both the leg and its existing hidden fill use the same body weight: `1 - smoothstep(-4, 14, projection)`, where projection is measured from source hip `(106, 131)` along the hip-to-knee direction `(22, 27)`. All prior weights are multiplied by the complementary factor, preserving normalization and shared-vertex agreement. The registered paint is unchanged and the bind pose remains identical. This source-space ownership fix applies consistently to walking, attack and collapse; it is not a layer added over a gap.

```sh
python3 tools/prepare_contextual_creature_cases.py
python3 tools/godot_task_runner.py --task-id <task-id> --stream -- godot --headless --path . --script tests/contextual_creature_motion_test.gd
python3 tools/visual_probe_runner.py tests/contextual_creature_keypose_probe.gd --project . --task-id <task-id> --no-headless --expect-size 1920x1080 --result-manifest /private/tmp/creature-keyposes.json
```

The sampler test checks all retained clips at 101 phases in both painted views against the saved pre-pass baseline, finite nonsingular transforms, rigid terminal bases, planted hit contacts, exact hit recovery, held death endpoints and promotion identity between each case and production. The compact key-pose probe renders all seven at 1920×1080 in front/rear and reflected views at a shared source scale.

Full raw native cycle audits retain every configured action and editable-scene roundtrips under `output/contextual-animation-polish/creatures/audit-v01`. Key-pose iterations remain under `keyposes-v01` through `keyposes-v04`, including rejected trials; only final `render`/`verify-render` output is final case-bound proof. Full-cycle contact sheets use invariant framing and are inspected for preparation, reach/contact, passing, deepest bend and recovery.

After the broad raw audit, `--contextual-only` prepares final focused cases containing idle/hit/death for unchanged prior actions. Crawler retains every action because the hip skin changed. Final proof is produced by the maintained cutout workflow with the shared GUI lease and real renderer; saved scenes and all sampled native poses remain in the ignored proof output. Root integration separately proves actual combat triggers, reduced motion and shadow dissolution.
