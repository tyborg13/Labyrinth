# Unit 1 review status

Implementation and headless motion checks pass. Native review is **blocked**: macOS LaunchServices / `com.apple.hiservices-xpcservice` returned `Connection invalid` before Godot initialized. All three toolkit renders failed at the 8-second startup watchdog with no `godot.log`. No timed reel, PNG, editable scene, contact sheet, save/reload comparison or board-scale visual judgment has been produced. `verify-render` correctly fails because `capture_input_sha256.json` is absent.

The case was seeded from current production with `seed-protagonist`. Gear crops and offsets come from the retained `source/gear_registration.json`; `source/seed_motion.gd`, `source/seed_cutout.json`, seed layouts and `source/seed.sha256.json` retain the original inputs. `baseline.sha256.json` then registers the deliberate case art changes. The protected-art validation passes.

The new sampler dispatch and helpers are at the end of `motion.gd`. Existing sampler branches are untouched and compare exactly against the retained seed across 8 actions × 2 facings × 201 phases. Existing seed selector timing is retained; the other copied actions are exposed using their existing sampler durations.

## Measured keys (global source pixels)

| Facing | Phase | Right wrist | Left wrist | Hips Δy | Additional torso Δx |
| --- | --- | --- | --- | --- | --- |
| front | 0.00 | (86.000, 132.000) | (168.000, 143.000) | 0.000 | 0.000 |
| front | 0.30 | (100.000, 126.000) | (167.728, 145.575) | 1.000 | 0.000 |
| front | 0.42 | (66.000, 121.000) | (168.774, 141.513) | 1.187 | 0.000 |
| front | 0.54 | (67.000, 121.000) | (168.489, 141.949) | 1.187 | 0.000 |
| front | 0.90 | (86.000, 132.000) | (168.000, 143.000) | 0.000 | 0.000 |
| rear | 0.00 | (170.000, 143.000) | (87.000, 132.000) | 0.000 | 0.000 |
| rear | 0.30 | (160.000, 135.000) | (86.953, 134.661) | 1.000 | 0.000 |
| rear | 0.42 | (182.000, 112.000) | (87.118, 130.165) | 1.000 | 0.000 |
| rear | 0.54 | (181.000, 112.000) | (87.322, 130.613) | 1.000 | 0.000 |
| rear | 0.90 | (170.000, 143.000) | (87.000, 132.000) | 0.000 | 0.000 |

## Deviations

All specified wrist, direction, torso and root keys are exact. The planted-foot reach correction changes front hips Δy at contact/hold from `+1` to `+1.187`; the arm solve runs after this correction, so the wrist remains exactly `(66,121)` at 0.42 and `(67,121)` at 0.54. Rear contact is exactly `(182,112)`; the unspecified rear hold drifts one pixel to `(181,112)`. Both facings use the requested 2:1 stab line. The thrust takes 48 ms from phase 0.30 to 0.42. The left forearm counter-rotates 0.10 rad at contact and returns by 0.80. The complete pose settles to bind at 0.90.

## Board-scale readability

- attack_stab 0.00, front/rear: unassessed; native capture blocked.
- attack_stab 0.30, front/rear: unassessed; native capture blocked.
- attack_stab 0.42, front/rear: unassessed; native capture blocked.
- attack_stab 0.54, front/rear: unassessed; native capture blocked.
- attack_stab 0.90, front/rear: unassessed; native capture blocked.

Motion numbers do not establish board readability, painted anatomy or correct occlusion. Native proof and design-owner visual inspection remain required.
