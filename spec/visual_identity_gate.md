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
| `lateral_axis` | Angle of the director-annotated far→near landmark pair (feet contacts, or shoulders), y down | creature fronts and legged objects: +8°…+40° (rears are judged visually: their feet mix the lateral axis with the stride) |

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
python3 tools/art_identity_gate.py process REAR_RAW.png --kit REAR_JOB/kit.json --out REAR_OUT.png \
  --match-front FRONT_PROCESSED.png --clean-outline
python3 tools/art_identity_gate.py kit --id ID --subject SUBJECT.md --subject-rear REAR_SUBJECT.md \
  --view creature_rear --size-class medium --anatomy biped --peers harrier_rear grave_surgeon_rear \
  --front-ref FRONT_RAW.png --out-dir REAR_JOB
python3 tools/art_identity_gate.py sheet --front OUT.png --kit JOB_DIR/kit.json --out SHEET.png
python3 tools/art_identity_gate.py canon-sheet --out CANON_SHEET.png --view front
python3 tools/art_identity_gate.py check
python3 tools/art_identity_gate.py check --strict
python3 tools/art_identity_gate.py adopt-legacy
python3 tests/test_art_identity_gate.py
```

`adopt-legacy` refuses to replace an existing baseline. Normal checks warn for Gust Shrike, the remaining `pending_reart` enemy; strict checks fail it.
Reference PNGs are intentionally git-ignored and regenerable; certification reads the committed job records,
not these files. The lineup capture command and backdrop-copy instructions are in the command reference.
Processing normalizes square raw canvases with `k_eff = K × raw_width / 1024`, uniformly fits oversized sprites
within 251×240 without clipping paint, and records `k_eff` and `fit_scale`. The candidate table shows `fit_scale` as
INFO. Use `canon-sheet` (front or rear) beside each candidate sheet for the independent judge.


`--match-front` applies the approved prototype's Reinhard mean/std transfer in CIE Lab over opaque non-accent
pixels (accent chroma > p90 + 15), retaining accents and alpha and stripping green key residue. `--clean-outline`
then removes isolated pixels and replaces silhouette edges above Rec.601 luminance 0.2 with RGB (20,16,21).
Each deterministic step records parameters and the pre-step decoded digest in `post_steps`; palette matching also
binds its reference digest. Both run after canvas placement. `--subject-rear` uses and records the supplied rear
subject in the kit and prompt, while retaining the usual front reference requirement.

Creature sheets and kit checks enforce `edge_light_share` ≤ `creature.edge_light_share_max`. Pair sheets show
absolute front/rear chroma and value differences over non-accent pixels only. Both views use the exact palette-match
mask: opaque pixels with Lab chroma ≤ their view's p90 + 15. Kit checks enforce the unchanged `rear_consistency` bands
on those approved processed sources. Registry `source_path` / `source_pixel_sha256` bind those sources, their processing sidecars and
copied `post_steps`; `pixel_sha256` independently binds the density-treated production files.


Kit certification verifies `prompt.md` against `prompt_sha256` in both its job and registry, and the job's recorded
reference pixel digests against registry `ref_pixel_sha256`. It checks digest validity and reference identities,
without opening or regenerating reference PNGs. `kit_version` is generation-time provenance: recover the captured
preamble and view clause from the stored prompt, undo the generation-time `{K}` substitution in its numeric contexts,
and hash those bytes with the job's sorted reference digests. Today's preamble/view clauses and canon paint are not
hash inputs. Every current art-03 kit reproduces its version this way; `check` labels these `kit_version
prompt_reconstructed`. If a historical custom prompt cannot reproduce the recorded value exactly, the director's
fallback verifies the prompt hash, reference digest bindings, and equality/validity of the job and registry version
fields; `check` explicitly labels that mode `kit_version recorded`. Protected job files remain unchanged.

Art-03's static enemies use the existing four-direction cutout policy with front/rear stills. Idle observers wait
for the hero's movement to finish, movement follows the sampled segment and attacks follow their target. Death
retains the preceding facing. Cached shadows use the selected front/rear silhouette; mirrored textures and cached
polygons flip about the logical rectangle centre. Logical HUD, tooltip and obstruction rectangles stay fixed.
Storm Capacitor has no rear and does not turn; its explicit approved `art_scale` supersedes the old canvas fitting
compensation. Gale Herald's front measures grid 1.42 and uses `regrid` under the existing density rule; the other
20 art-03 views use `clean`. Static art has no rig rests to rebake or record.

Headless registration and semantic validation (no renderer-proof claim):

```sh
python3 tools/godot_task_runner.py --task-id art-03 --stream -- godot --headless --path . \
  --script tests/static_facing_shadow_cache.gd
python3 tools/godot_task_runner.py --task-id art-03 --stream -- godot --headless --path . \
  --script tests/static_facing_test.gd
python3 tools/godot_task_runner.py --task-id art-03 --stream -- godot --headless --path . \
  --script tests/bestiary_lineup_probe.gd -- --validate-only
python3 tools/godot_task_runner.py --task-id art-03 --stream -- godot --headless --path . \
  --script tests/static_facing_probe.gd -- --validate-only
```

The design owner runs the following windowed proof at 1920×1080, 100% UI scale and inspects the fresh captures:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/art-03 && python3 tools/visual_probe_runner.py \
  --task-id art-03 --no-headless --display-driver macos --audio-driver Dummy \
  --expect-size 1920x1080 --proof-contract tests/bestiary_lineup_probe_contract.json \
  --result-manifest /private/tmp/labyrinth-inspection-manifests/art-03-lineup.json tests/bestiary_lineup_probe.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/art-03 && python3 tools/visual_probe_runner.py \
  --task-id art-03 --no-headless --display-driver macos --audio-driver Dummy \
  --expect-size 1920x1080 --proof-contract tests/static_facing_probe_contract.json \
  --result-manifest /private/tmp/labyrinth-inspection-manifests/art-03-static-facing.json tests/static_facing_probe.gd
```

The first probe writes the empty board and normal/boss lineups; the second writes eight idle facing captures
(`arc_thrall` and `slag_mortar`: front, front mirrored, rear, rear mirrored), `arc_thrall_mid_move.png`,
`slag_mortar_reduced_motion.png`, `turn_clock_three_portraits.png`, and `semantic-proof.json`. Both print their
isolated `user://probes/` directory. Capture uses only the fixed SubViewport texture. These probes construct their
own presentation fixtures; no saved-run inspection fixture is needed. The 11 old/new portrait pairs are available
at exact 2× NEAREST in `tests/static_facing_portrait_contact.png` (old left, approved crop right).
