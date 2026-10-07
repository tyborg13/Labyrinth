# Unit 1 review status

Implementation and headless motion checks pass. Native review is **blocked**: macOS LaunchServices / `com.apple.hiservices-xpcservice` returned `Connection invalid` before Godot initialized. All three toolkit renders failed at the 8-second startup watchdog with no `godot.log`. No timed reel, PNG, editable scene, contact sheet, save/reload comparison or board-scale visual judgment has been produced. `verify-render` correctly fails because `capture_input_sha256.json` is absent.

The case was seeded from current production with `seed-protagonist`. Gear crops and offsets come from the retained `source/gear_registration.json`; `source/seed_motion.gd`, `source/seed_cutout.json`, seed layouts and `source/seed.sha256.json` retain the original inputs. `baseline.sha256.json` then registers the deliberate case art changes. The protected-art validation passes.

The new sampler dispatch and helpers are at the end of `motion.gd`. Existing sampler branches are untouched and compare exactly against the retained seed across 8 actions × 2 facings × 201 phases. Existing seed selector timing is retained; the other copied actions are exposed using their existing sampler durations.

## Measured keys (global source pixels)

| Facing | Phase | Right wrist | Left wrist | Hips Δy | Additional torso Δx |
| --- | --- | --- | --- | --- | --- |
| front | 0.00 | (86.000, 132.000) | (168.000, 143.000) | 0.000 | 0.000 |
| front | 0.14 | (86.000, 132.000) | (146.000, 116.000) | 1.777 | 0.000 |
| front | 0.25 | (86.000, 132.000) | (146.000, 116.000) | 1.731 | 0.000 |
| front | 0.32 | (86.000, 132.000) | (146.000, 116.000) | 1.613 | 0.000 |
| rear | 0.00 | (170.000, 143.000) | (87.000, 132.000) | 0.000 | 0.000 |
| rear | 0.14 | (170.000, 143.000) | (98.000, 120.000) | 1.777 | 0.000 |
| rear | 0.25 | (170.000, 143.000) | (98.000, 120.000) | 1.731 | 0.000 |
| rear | 0.32 | (170.000, 143.000) | (98.000, 120.000) | 1.613 | 0.000 |

## Rig exception and retained attachment issue

The layout part is named `gear_offhand`, uses the registry crop/offset and layers 50 front / 73 rear, and is mounted through a new `gear_offhand_mount` child of `forearm_l`. A directly parented sprite cannot satisfy the rear wrist `(98,120)`, fixed sleeve lengths, existing body recoil and an upright shield simultaneously. The child pivot follows the forearm exactly for existing clips; `block_shield` counter-rotates it about the painted shield centre and caps its global tilt at ±0.15 rad. This is the sole attachment-topology exception to the brief's literal `bone: forearm_l`. Unit 2 must preserve this centre-based compensation when porting the new block.

Both guard wrists are exact, the existing `_hold(t,0.0,0.14,0.32,1.0)` envelope and body recoil are retained, and the complete sword chain stays at its global bind. No wrist target adjustment was needed.

The unchanged rear cast/shoot solver expands the forearm using its existing perspective approximation. A shield riding on that forearm inherits an affine stretch (maximum basis error 0.613214); front cast/shoot and both facings of walk/hit/attack remain rigid to floating-point precision. This is a measured attachment concern, **not** a visually inspected defect. Face/cloak/HP-bar occlusion is unassessed because no real-renderer capture could run. Existing clips were preserved as requested.

## Board-scale readability

- block_shield 0.00, front/rear: unassessed; native capture blocked.
- block_shield 0.14, front/rear: unassessed; native capture blocked.
- block_shield 0.25, front/rear: unassessed; native capture blocked.
- block_shield 0.32, front/rear: unassessed; native capture blocked.
- cast 0.42, front/rear: unassessed; native capture blocked.
- shoot 0.42, front/rear: unassessed; native capture blocked.
- walk 0.15, front/rear: unassessed; native capture blocked.
- walk 0.65, front/rear: unassessed; native capture blocked.
- hit 0.15, front/rear: unassessed; native capture blocked.
- attack 0.42, front/rear: unassessed; native capture blocked.

Motion numbers do not establish board readability, painted anatomy or correct occlusion. Native proof and design-owner visual inspection remain required.
