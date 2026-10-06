# Unit 1 review status

Implementation and headless motion checks pass. Native review is **blocked**: macOS LaunchServices / `com.apple.hiservices-xpcservice` returned `Connection invalid` before Godot initialized. All three toolkit renders failed at the 8-second startup watchdog with no `godot.log`. No timed reel, PNG, editable scene, contact sheet, save/reload comparison or board-scale visual judgment has been produced. `verify-render` correctly fails because `capture_input_sha256.json` is absent.

The case was seeded from current production with `seed-protagonist`. Gear crops and offsets come from the retained `source/gear_registration.json`; `source/seed_motion.gd`, `source/seed_cutout.json`, seed layouts and `source/seed.sha256.json` retain the original inputs. `baseline.sha256.json` then registers the deliberate case art changes. The protected-art validation passes.

The new sampler dispatch and helpers are at the end of `motion.gd`. Existing sampler branches are untouched and compare exactly against the retained seed across 8 actions × 2 facings × 201 phases. Existing seed selector timing is retained; the other copied actions are exposed using their existing sampler durations.

## Measured keys (global source pixels)

| Facing | Phase | Right wrist | Left wrist | Hips Δy | Additional torso Δx |
| --- | --- | --- | --- | --- | --- |
| front | 0.00 | (86.000, 132.000) | (168.000, 143.000) | 0.000 | 0.000 |
| front | 0.12 | (118.000, 122.000) | (124.319, 128.409) | 2.027 | 0.000 |
| front | 0.30 | (132.000, 84.000) | (131.006, 92.945) | 0.037 | 0.000 |
| front | 0.36 | (132.000, 83.000) | (130.828, 91.923) | 0.037 | 0.000 |
| front | 0.42 | (122.000, 132.000) | (127.400, 124.800) | 5.000 | 0.000 |
| front | 0.48 | (122.000, 133.000) | (127.400, 125.800) | 6.000 | 0.000 |
| front | 0.58 | (122.000, 132.000) | (127.400, 124.800) | 5.000 | 0.126 |
| front | 0.72 | (110.000, 128.000) | (129.987, 127.367) | 2.000 | 0.000 |
| front | 0.90 | (92.997, 130.834) | (167.953, 142.879) | 0.583 | 0.000 |
| front | 1.00 | (86.000, 132.000) | (168.000, 143.000) | 0.000 | 0.000 |
| rear | 0.00 | (170.000, 143.000) | (87.000, 132.000) | 0.000 | 0.000 |
| rear | 0.12 | (127.000, 118.000) | (120.681, 124.409) | 1.000 | 2.526 |
| rear | 0.30 | (128.000, 84.000) | (128.994, 92.945) | 0.046 | 3.375 |
| rear | 0.36 | (128.000, 83.000) | (129.172, 91.923) | 0.046 | 4.109 |
| rear | 0.42 | (136.000, 126.000) | (130.600, 118.800) | 5.000 | 3.801 |
| rear | 0.48 | (136.000, 127.000) | (130.600, 119.800) | 6.000 | 3.895 |
| rear | 0.58 | (136.000, 126.000) | (130.600, 118.800) | 5.000 | 3.710 |
| rear | 0.72 | (132.000, 125.000) | (115.509, 122.265) | 2.000 | 0.000 |
| rear | 0.90 | (158.921, 137.752) | (87.187, 131.845) | 0.583 | 0.000 |
| rear | 1.00 | (170.000, 143.000) | (87.000, 132.000) | 0.000 | 0.000 |

## Deviations and rear authoring

- Front gather wrist `(112,122)` → `(118,122)` (+6 px x); root Δx `0` → `−5`. Both hands reach the haft at 0.08 and retain the gather at 0.12. These adjustments bring the left sleeve within painted reach.
- Front lift wrist `(104,128)` → `(110,128)` (+6 px x), to retain grip until the prescribed 0.68–0.80 release.
- The torso translates by the minimum horizontal amount needed to reach both wrists: front at most 5.466 px (phase 0.685), rear at most 4.109 px (phase 0.36). The table reports each requested key; no sleeve stretches.
- The minimum planted-foot pelvis drop changes front gather hips Δy `+1` → `+2.027`, front apex/hold `−1` → `+0.037`, and rear apex/hold `−1` → `+0.046`. The table also reports subpixel recovery adjustments. These replace impossible leg reaches with small body-position changes.
- The brief leaves rear gather/apex/lift wrists unspecified. Rear gather is `(127,118)` at 0.08/0.12, with an intermediate `(132,122)` at 0.04 to avoid overreaching during hand closure; apex is `(128,84)` / `(128,83)`, with the head straight up and slightly camera-ward. Rear lift stays `(132,125)` until the left hand releases. These keep the shorter hidden arm within its painted reach.
- Rear contact wrist near `(138,128)` → `(136,126)` (−2 px each); registered hammer-head centre is `(181.430,190.817)`, near the requested `(184,188)`.
- Front swing angles unwrap through the screen-left side; rear through screen-right. Contact remains exactly authored 0.42 with identity playback; 0.36→0.42 is 43.2 ms at the requested 0.72 s duration.
- Cape motion reuses the sword attack's exact restrained amplitudes and envelopes. No idle or added cloth motion.

## Board-scale readability

- attack_heavy 0.00, front/rear: unassessed; native capture blocked.
- attack_heavy 0.12, front/rear: unassessed; native capture blocked.
- attack_heavy 0.30, front/rear: unassessed; native capture blocked.
- attack_heavy 0.36, front/rear: unassessed; native capture blocked.
- attack_heavy 0.42, front/rear: unassessed; native capture blocked.
- attack_heavy 0.48, front/rear: unassessed; native capture blocked.
- attack_heavy 0.58, front/rear: unassessed; native capture blocked.
- attack_heavy 0.72, front/rear: unassessed; native capture blocked.
- attack_heavy 0.90, front/rear: unassessed; native capture blocked.
- attack_heavy 1.00, front/rear: unassessed; native capture blocked.

Motion numbers do not establish board readability, painted anatomy or correct occlusion. Native proof and design-owner visual inspection remain required.
