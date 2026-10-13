# Visual identity gate

New or repainted board art (enemies, guardians, NPC bodies, standing props) must keep one coherent hand: the hero's
three-quarter view on the 2:1 board, chunky stylized proportions, low detail at the size it is drawn, a dark muted
palette. This gate makes drift fail loudly instead of relying on someone noticing. It sits on top of the
[board pixel-density rule](board_pixel_density.md), which still owns pixel treatment.

## Why it exists (owner verdicts, 2026-10-12)

The twelve peer-benchmark enemies passed pixel density, but the owner rejected them:

- **Wrong view.** Ten of twelve stand head-on to the camera. Board units face lower-left (front) or upper-right (rear)
  in three-quarter view like the hero; head-on art also cannot be animated believably with the cutout rigs, which
  mirror front and rear to make four facings.
- **Wrong perspective on objects.** The Storm Capacitor's square base is drawn front-on. Board objects stand on
  footprints seen corner-on, as 2:1 diamonds.
- **Miniaturized.** Realistic thin limbs and many small features painted for a larger canvas, then shrunk to board
  size, read as miniatures beside the hero's chunky masses.

Root causes: references were legacy front-on static sprites, not canon; prompts asked for "2-pixel colour runs" on a
1024 canvas that was later shrunk about 4x (half-pixel detail in game); "rotated slightly toward the viewer's left"
produced near head-on views; art was approved from the generated image at generation size; no check looked at view,
proportion or footprint.

## 1. Canon

[`art_identity/canon.json`](art_identity/canon.json) lists the only files allowed as references for new board art,
with kind, anatomy, size class and view. Legacy static sprites under `assets/art/enemies/` and the rejected
2026-10-12 enemies are explicitly not canon. Adding or removing canon needs owner approval.

## 2. Generation kit (the only route to new board art)

`tools/art_identity_gate.py kit` writes an image job: the prompt is
[`art_identity/preamble.md`](art_identity/preamble.md) + one view clause from
[`art_identity/views.md`](art_identity/views.md) + the subject file + a size clause; the references are the hero plus
two canon peers of the same anatomy, enlarged by an integer factor K with NEAREST on flat `#00FF00` canvases, so every
reference pixel is a visible K×K block. K = 4 when the target canvas height is at most 225 px, otherwise 3. Plinth
objects also get the footprint guide. The job's `kit.json` records `kit_version`: SHA-256 of the preamble, view clause
and reference pixel digests.

Creature art is painted as a front and rear pair (rear is generated from the approved front as an edit reference).
Limbs stay separated from the torso so the art can be cut into a rig.

## 3. Processing

`process` keys the green, trims, downscales the premultiplied image by exactly K with BOX, and places it on the
255×255 canvas: alpha-bbox centre x = 128, bottom = y 246. New normal enemies use `art_scale` 0.75–1.2: paint at the
size it is drawn instead of painting large and shrinking. Then adopt it through the density pipeline as today.

## 4. Metric gate

Metrics are measured on the production PNG; `size` uses canvas px × `art_scale`. Bands live in
[`art_identity/bands.json`](art_identity/bands.json) and were calibrated on canon (min/max shown there).

| Metric | Definition | Default band |
| --- | --- | --- |
| `symmetry` | Best IoU of the alpha mask with its mirror over horizontal shifts of ±25% width | creature ≤ 0.86 |
| `thin_rel` | Share of silhouette removed by a morphological opening with a disk of radius round(0.03 × height) | ≤ 0.12; ≤ 0.20 with an owner-approved exception |
| `thin_abs` | Same with radius 2 px | ≤ 0.06 |
| `feature_px` | √(silhouette area ÷ number of regions ≥ 4 px) after a 3×3 median and 6-quantile luminance banding | ≥ 4.4; small class ≥ 5.6 |
| `chroma` | Mean (max − min) RGB over the silhouette, 0–1 | normal ≤ 0.20; boss ≤ 0.40 |
| `value` | Mean Rec.601 luminance over the silhouette | normal 0.12–0.40; boss ≤ 0.55 |
| `art_scale` | From `data/enemies.json` | new normal enemies 0.75–1.2 |
| `base_v` | Line fits to the lowest silhouette row profile over 8–40% and 60–92% of width | plinth objects: left +0.30…+0.75, right −0.75…−0.30 |
| `lateral_axis` | Angle of the director-annotated far→near landmark pair (feet contacts, or shoulders), y down | creature front/rear and legged objects: +8°…+40° |

Head-on creature art measures 0–5° on `lateral_axis` (Arc Thrall 1.8°, Hollow Mimic 4.3°); the hero measures +13.5° on its feet. The Storm Capacitor's
square base measures +0.02/−0.01 on `base_v`; the crag outcrop measures +0.54/−0.73.

## 5. Review sheet: the only approval surface

`sheet` builds one image per candidate: the candidate at its in-game draw size on a board tile row between the hero
and two canon peers, at 1× and 2× NEAREST; front, rear and mirrored front (all four facings); the landmark line and
the ideal 2:1 diagonal through the near landmark (or the diamond for plinths); the metric table with pass/fail. Never
approve art from the generated image at generation size.

## 6. Independent judge

Before the owner sees a sheet, a fresh Claude subagent that did not write the prompts judges it against
[`art_identity/judge_rubric.md`](art_identity/judge_rubric.md) with the canon sheet beside it. Any failed criterion
sends the art back. The verdict is stored with the provenance.

## 7. Registry, provenance and CI

[`art_identity/registry.json`](art_identity/registry.json) has one entry per board art file adopted on or after
2026-10-13: kit job and `kit_version`, prompt and references, raw and production SHA-256, review sheet path, judge
verdict, landmarks, exceptions with reasons, owner approval note. Existing art is grandfathered as `legacy` with its
measured metrics, so it cannot change silently. `python3 tests/test_art_identity_gate.py` fails when a board art path
used by `data/enemies.json` (art path or cutout rests) or a standing prop has no entry, an entry's hash does not
match, or a metric leaves its band without a recorded exception.

## 8. In-engine lineup

`tests/bestiary_lineup_probe.gd` captures every enemy and the hero on a board at in-game scale (1920×1080
SubViewport). Every enemy art review includes it.

## Commands

Run `python3 tools/art_identity_gate.py --help` for the CLI and see the
[command reference](art_identity/README.md) for kit, processing, sheet and provenance schemas.

```sh
python3 tools/art_identity_gate.py measure PATH --art-scale 1.0 --kind creature --anatomy biped
python3 tools/art_identity_gate.py kit --id ID --subject SUBJECT.md --view creature_front \
  --size-class medium --anatomy biped --peers harrier_front grave_surgeon_front --out-dir JOB_DIR
python3 tools/art_identity_gate.py process RAW.png --kit JOB_DIR/kit.json --out OUT.png
python3 tools/art_identity_gate.py sheet --front OUT.png --kit JOB_DIR/kit.json --out SHEET.png
python3 tools/art_identity_gate.py canon-sheet --out CANON_SHEET.png --view front
python3 tools/art_identity_gate.py check
python3 tools/art_identity_gate.py check --strict
python3 tools/art_identity_gate.py adopt-legacy
python3 tests/test_art_identity_gate.py
```

`adopt-legacy` refuses to replace an existing baseline. Normal checks list the twelve pending reart jobs as warnings;
strict checks fail them. The lineup capture command and backdrop-copy instructions are in the command reference.
Processing normalizes square raw canvases with `k_eff = K × raw_width / 1024`, uniformly fits oversized sprites
within 251×240 without clipping paint, and records `k_eff` and `fit_scale`. The candidate table shows `fit_scale` as
INFO. Use `canon-sheet` (front or rear) beside each candidate sheet for the independent judge.
