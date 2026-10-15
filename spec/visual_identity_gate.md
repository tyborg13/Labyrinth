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
2026-10-13: kit job and `kit_version`, prompt and references, raw binding and production pixel SHA-256, review sheet path, judge
verdict, landmarks, exceptions with reasons, owner approval note. Existing art is grandfathered as `legacy` with its
measured metrics, so it cannot change silently. `python3 tests/test_art_identity_gate.py` fails when a board art path
used by `data/enemies.json` (art path or cutout rests) or a standing prop has no entry, an entry's hash does not
match, or a metric leaves its band without a recorded exception.

## 7b. Maquettes (baseline for anatomy image generation cannot infer)

Owner decision 2026-10-13. For wings, rear views of complex creatures and rigs that need part masks, the structure is
decided in 3D and image generation only paints over it: `spec/art_identity/maquettes/` (Blender, headless) renders a
posed proxy from the board camera — front (yaw 0) and rear (yaw 180) — as part-label colours plus a clay pass (and, for
rigs, per-part solo renders and projected joints). Prompts say the label colours are part labels and keep silhouette,
overlap and camera. Front and rear agree by construction. Birds stand perched (upright on two legs, tail down).

Maquette jobs set `kit_kind: "maquette"` in `kit.json`. Their non-empty `job_id` must equal the registry's job id;
it does not use the standard `id-<id>-<view>` pattern. `prompt_path: "prompt.md"` names the byte-identical job-local
prompt; `prompt_source` records its original location. `kit_version` is SHA-256 of the prompt bytes followed by the
reference pixel digests concatenated in list order (ASCII, no separator). Both perched shrike views reproduce it;
maquette certification rejects a mismatch rather than using the historical standard-kit fallback.

Every maquette reference has a job-relative `file` under `refs/`, a decoded `pixel_sha256`, and a `role` from
`maquette_parts`, `maquette_clay`, `identity`, `canon`, or `edit_source`. The PNG must exist inside that directory
and match its digest. `source_file` is informational provenance. `canon` references resolve to an active or retired
canon id in any view: they supply the hand, not a matching pose. Other roles may use their own labels in `canon_id`
but must not reuse a canon id. At least one `maquette_parts` reference is required; rear jobs also require an
`identity` reference. Standard peer ordering, matching-view canon, and first-front-reference rules do not apply.
Prompt hashes, registry reference bindings, processed sidecars, post-steps, source/production pixel hashes, metric
bands, landmarks, judge verdict and owner approval retain the same checks as standard kits.
Maquette reference PNGs are committed with the job records: maquette job folders are named `mq*` (the gate checks
this) and `.gitignore` re-includes `spec/art_identity/jobs/*/mq*/refs/`; `prompt_source` names the original prompt
under `spec/art_identity/maquettes/`.

Certification commands (read-only):

```sh
python3 tools/art_identity_gate.py check --id gust_shrike --strict
python3 tools/art_identity_gate.py check
python3 tests/test_art_identity_gate.py
```

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
# A kit with raw_steps supplies its own initial raw and match_reference:
python3 tools/art_identity_gate.py process --kit JOB_DIR/kit.json --out OUT.png --clean-outline
# Read-only recipe proof for a job which is not registered yet:
python3 tools/art_identity_gate.py check --kit JOB_DIR/kit.json
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

`adopt-legacy` refuses to replace an existing baseline. Art-04 adopts the final pending enemy, Gust Shrike, so normal
and strict checks now require zero `pending_reart` warnings. Standard-kit reference PNGs are intentionally
git-ignored and regenerable; certification reads their committed job records, not these files. Maquette reference
PNGs are required certification inputs under §7b and are committed: maquette job folders are named `mq*`, and
`.gitignore` re-includes `spec/art_identity/jobs/*/mq*/refs/`. The lineup capture command
and backdrop-copy instructions are in the command reference.
Processing normalizes square raw canvases with `k_eff = K × raw_width / 1024`, uniformly fits oversized sprites
within 251×240 without clipping paint, and records `k_eff` and `fit_scale`. The candidate table shows `fit_scale` as
INFO. Use `canon-sheet` (front or rear) beside each candidate sheet for the independent judge.


`--match-front` applies Reinhard mean/std transfer in CIE Lab over opaque non-accent pixels. The original accent
rule is Lab chroma > the image's opaque-pixel p90 + 15. Current matches additionally protect L* >= 80. Hue protection
uses the centres of the reference front's dominant 15-degree Lab a/b hue bins: each must contain at least 5% of
the front's accent pixels selected by the original rule. A rear pixel within 25 degrees of a dominant bin centre
is protected only if its Lab chroma is at least `max(rear opaque-pixel p90 chroma, 30)`. The same chroma floor uses
the front's own p90 when selecting its body statistics. Circular hue distances and all thresholds are inclusive.
Green-dominant RGB pixels (`G > R` and `G > B`) are never protected by either the lightness or hue rule; green
key residue therefore still reaches the original cleanup. Other protected pixels retain their exact RGBA.

The protected body share is the newly protected count divided by the original chroma-only body count, separately
for front and rear. Processing fails before writing outputs if either exceeds 25% or a body becomes empty.
`--allow-protected-share` explicitly overrides the share limit and is recorded with the parameters; current steps
also record `protected_body_share` for both images. If either body is empty with the flag enabled, the palette match
is skipped and the post-step additionally records `{"kind": "palette_match", "skipped": "empty body",
"protected_share": {"front": <share>, "rear": <share>}}`. It retains the existing `step`, parameters, reference
binding and pre-step digest. The skip leaves the input pixels unchanged; subsequent steps, including outline cleanup,
still run. Replay reproduces the skip and its shares, and `check` validates the skip record and replays available
inputs. Without the flag an empty body remains an error before any output is written.
Zero opaque samples are detected before body masks or percentiles are calculated. This includes a valid derived
mask that excludes the entire front. With the override, these cases record `skipped: "empty reference"` (front)
or `skipped: "empty rear"`; both share fields are `null` because no body statistics were measured. Verification
also checks the reason against the bound reference's opacity, including when raw replay inputs are unavailable.
The rear-consistency metric retains its original non-accent mask and bands. `--clean-outline`
then removes isolated pixels and replaces silhouette edges above Rec.601 luminance 0.2 with RGB (20,16,21).

Each deterministic step records parameters and the pre-step decoded digest in `post_steps`; palette matching also
binds its reference digest. Current parameters include the lightness, hue window, chroma floor, bin width/minimum
share, maximum body share, green exclusion and override flag. `process` defaults to the recorded `palette_match`
parameters in the kit folder's `processed.json`, even when `--out` names a different folder. A new match without a
recorded palette step uses current parameters. Use `--palette-parameters current` to explicitly upgrade a recorded
job, or `--palette-parameters legacy` for the original chroma-only algorithm. Missing/unsupported recorded parameters
fail with an explicit-selection error instead of silently adopting current settings. Replay retains the original
chroma-only and art-07 v1 algorithms exactly; their sidecars are not rewritten. Both steps run after canvas placement.
`--subject-rear` uses and records the supplied rear subject in the kit and prompt, while retaining the usual front
reference requirement.

### Replayable director steps (art-05; pixel bindings hardened in art-06)

`raw_steps` is an ordered, non-empty list in `kit.json`. `process` reads it automatically before the ordinary green
key, BOX reduction and canvas placement. Omit the positional RAW; if supplied, it must hash to the first step's raw
input. Each director input binding is `{ "path": "refs/FILE", "sha256": "<file-byte SHA-256>" }`, relative to the job folder.
Absolute paths, traversal and symlinks escaping that folder are rejected. Maquette inputs must be in `refs/` or
`raw_inputs/`; use `refs/` in `mq*` jobs to inherit the existing Git inclusion rule. Copy inputs byte-for-byte,
including the first raw, edits and JSON configs. Later steps consume the previous output in memory: their raw binding
is exactly `{ "previous_output_pixel_sha256": "<preceding output pixel digest>" }`. Intermediate raw PNGs are not inputs
and need not be committed. Every output uses `pixel_digest` (decoded RGBA bytes plus image size), independent of the
PNG encoder. The art-05 `output_raw_sha256` field is rejected; re-record it as `output_raw_pixel_sha256` once.

```json
{
  "raw_steps": [
    {
      "kind": "composite_region",
      "inputs": {
        "raw": {"path": "refs/raw_approved.png", "sha256": "<SHA-256>"},
        "edit": {"path": "refs/raw_chain_edit.png", "sha256": "<SHA-256>"}
      },
      "parameters": {"box": [60, 255, 300, 720], "resample": "LANCZOS"},
      "output_raw_pixel_sha256": "<pixel digest of the resulting raw>"
    },
    {
      "kind": "tone_region",
      "inputs": {
        "raw": {"previous_output_pixel_sha256": "<preceding output pixel digest>"},
        "config": {"path": "refs/tone_front_r3.json", "sha256": "<SHA-256>"}
      },
      "parameters": {"space": "CIE Lab"},
      "output_raw_pixel_sha256": "<pixel digest of the resulting raw>"
    }
  ]
}
```

`composite_region` preserves the original script's RGB conversion, resizes a differently sized edit to the approved
raw's size with LANCZOS, then pastes the half-open box. `tone_region` preserves the original ordered region config:
`name`, `box`, optional eight-way `seed`, `min_lum`/`max_lum`, `min_chroma`, optional `max_chroma` and `max_value`,
optional `hue_deg` (lo > hi wraps across zero), `exclude_green` (default true), and `lab_scale`.
`max_chroma` caps `(max(R,G,B) - min(R,G,B)) / 255`, the same measure as `min_chroma`; `max_value` caps
`max(R,G,B) / 255` (HSV value, distinct from Rec.601 luminance). All five limits (`min_lum`, `max_lum`, `min_chroma`,
`max_chroma`, `max_value`) must be finite numbers in 0..1; booleans are rejected. Minimum luminance/chroma must not
exceed their corresponding maximum. Bounds are inclusive,
combine with the other selectors before seed filling, and are optional: omitting them leaves all existing configs
and recorded raw-step pixels unchanged. They also apply to reference masks through the shared region selector.
The prototype tone/mask scripts and gaoler composite script
remain thin CLI wrappers around these library functions, with the same arguments and output bytes.

`match_reference` in the kit can name a processed front job directly:

```json
{
  "match_reference": {
    "job_path": "spec/art_identity/jobs/frostglass_lancer/mq1_front_v3/kit.json",
    "pixel_sha256": "<pixel digest of that front job's processed.png>"
  }
}
```

A job-local processed-front binding
`{ "path": "refs/palette_front.png", "pixel_sha256": "<decoded digest>" }` remains supported, as does a derived reference:

```json
{
  "match_reference": {
    "derived_from": {
      "job_path": "spec/art_identity/jobs/chainbound_gaoler/mq3_front_v4/kit.json",
      "pixel_sha256": "<pixel digest of that front job's processed.png>"
    },
    "mask_config": {"path": "refs/match_exclude_front_r3.json", "sha256": "<SHA-256>"}
  }
}
```

Both job-link forms name a repository-relative front **job**, whose `processed.png` must match the recorded pixel
digest. Relative to `spec/art_identity/jobs/`, both its declared and resolved `job_path` must be exactly `<id>/<job>/kit.json`.
Both the path's `id` and the front kit's `id` must match the referencing kit's `id`; the referenced JSON must be an
object and its view must be a front view. A front kit may also reference an earlier front of the same identity,
but never itself (including through a symlink). A changed front fails the referencing kit's check, even when its raw
inputs are absent; recompressing the front does not. The mask config remains a job-local file-byte binding.
No palette copy or prebuilt masked PNG is required.
The mask uses the same region selectors, ignores `lab_scale`, and sets only selected opaque pixels' alpha to zero.
It never overwrites the approved front. `--match-front FRONT.png` remains supported;
`--match-front REFERENCE.json` accepts the binding/derived object above (without the outer `match_reference` key),
with input paths relative to `--kit`'s job folder and `job_path` relative to the repository. A legacy direct PNG
argument must be repository-relative and, for maquettes, resolve inside the job folder. These constraints also apply
when checking digest-bound direct references. An explicit reference must agree with the kit's recorded reference.
The sidecar's `palette_match` post-step binds the reference descriptor, the decoded `reference_pixel_sha256`,
and its existing parameters and pre-step digest. Derived references no longer record `reference_sha256`.
Direct PNGs also record only their decoded digest. The sidecar copies `raw_steps`; `raw_pixel_sha256` binds the final
replayed raw's pixels. A registry entry for such a job must use the same `raw_pixel_sha256` field (and, if it supplies
`raw_path`, that file is checked by pixels). Jobs without `raw_steps` retain `raw_sha256` for their director-supplied
raw file. Historical informal gaoler commands/rationale remain under `raw_steps_provenance` for
audit only; execution uses `raw_steps` and `match_reference`.

Registry `check` retains all standard/maquette certification checks and additionally verifies these recipes. It
validates every present input, every intermediate output, the final raw, sidecar bindings, post-step parameters and
digests, and the processed PNG's decoded pixels. Re-encoded PNG byte equality is an INFO diagnostic only.
Missing raw-step inputs fail for maquettes; historical standard kits can lack raw inputs, but any present input must
still match. Registry checks report `WARN <entry>: SKIP raw_steps replay: inputs absent` in this case; reference,
final-raw, kit/sidecar and source-pixel bindings still run. A recipe exception adds an entry failure without dropping
its other provenance or metric failures. The summary counts skipped replays, and `--strict` fails on any skip.
`check --kit` requires every director input and prints matching raw and
processed pixel digests, plus the byte diagnostic. It certifies replay only, without registry/metric/judge approval.
Neither check writes into the job. Art-05/art-06 add no gaoler registry entries.

Once a kit lists its recipe steps and input paths, `record-steps` computes every input file's `sha256`, each
`output_raw_pixel_sha256`, the intervening `previous_output_pixel_sha256` links, and any match-reference pixel
digest (including the front job and mask-config byte digest for a derived reference). It replaces legacy output
byte fields and local reference byte fields with pixel fields. Legacy intermediate raw file bindings become
previous-output links only after their decoded pixels match the preceding replayed step. It refuses missing
inputs for both standard and maquette kits and validates the complete recipe/reference before writing. The command
prints a diff, or `UNCHANGED` when already current. It writes only `kit.json`; prompts, generation reference records,
configs and processed artifacts stay untouched. It uses the listed paths and never chooses a front job for the director.
`record-steps` is director-only: it re-binds current file bytes, so review every `INPUT CHANGED <path> old->new` sha256
change; neither `check` nor CI may run it to refresh recorded digests. Maquette input paths are checked after resolving
symlinks against the job's resolved `refs/` and `raw_inputs/` folders, including plain-path match references.
CLI stdout uses `backslashreplace` for unencodable characters so these diagnostics survive non-UTF-8 Windows consoles.

Art-07's headless comparison proof uses only copies of the recorded lancer/wisp rear recipes. It writes
`front.png`, `before.png` (before palette/outline), `legacy.png`, `after.png` and `results.json`, including bright-core
pixel counts, body coverage and before/after RGB samples, without changing approved jobs. A separate coverage table
uses the processed gaoler/lancer/wisp rears and two bloomer front-as-rear stand-ins (there is no approved bloomer rear).
The tests require at least 90% of both original bodies to remain transfer samples, while lancer/wisp bright cores
remain byte-identical. The director's desired protection range is 2–10%; measurements below 2% are reported rather
than increasing protection beyond the specified rules. From the task worktree:

```bash
python3 - <<'PY'
import json, runpy
from pathlib import Path
proofs = runpy.run_path('tests/test_art_identity_gate.py')
out = Path('output/art-07/review-r1-proof')
print(json.dumps(proofs['rear_palette_proof'](out), indent=2))
print(json.dumps(proofs['protected_share_proof'](out), indent=2))
PY
```

No renderer probe or playable inspection fixture applies to this offline processing-tool change.

After recording, use `process` with the job's existing post-step flags to regenerate its processing sidecar.
The existing kit-side `processed.json` must remain present so the default retains its recorded palette parameters.
For a known chroma-only legacy job, explicitly selecting `legacy` also makes the metadata-only intent clear. Never
select `current` for a metadata-only migration. Process into a temporary folder, check its pixel digest against
the approved `processed.json`, and copy back only the regenerated JSON after an exact match. For example:

```sh
python3 tools/art_identity_gate.py record-steps --kit spec/art_identity/jobs/frostglass_lancer/mq1_rear_v3/kit.json
python3 tools/art_identity_gate.py process --kit spec/art_identity/jobs/frostglass_lancer/mq1_rear_v3/kit.json --palette-parameters legacy --clean-outline --out "<temporary-output-directory>/processed.png"
```

Art-06 re-records all five recipes: gaoler `mq3_front_v4` and `mq3_rear_v3`, and lancer `mq1_front_v2`,
`mq1_front_v3` and `mq1_rear_v3`. Their processed PNGs, prompts, reference records and director configs are unchanged.
The gaoler rear links to the current `mq3_front_v4` job; its redundant palette copy, the front's unused
`match_reference_no_tabard.png`, and the three intermediate raws are removed. The gaoler `mq3_front_v4` front links
to its earlier `mq_front_v3` palette source, removing its redundant `refs/palette_front.png`. The lancer v3 rear links directly to
`mq1_front_v3`; its redundant `refs/palette_front.png` is removed. The gate tests also re-encode a processed PNG with
zlib compression level 0 and require both standalone replay and registry `check` to pass.

Proof for the design owner (headless Python; no capture or saved-run fixture is applicable):

```sh
python3 tests/test_art_identity_gate.py
python3 tools/art_identity_gate.py check
python3 tools/art_identity_gate.py check --kit spec/art_identity/jobs/chainbound_gaoler/mq3_front_v4/kit.json
python3 tools/art_identity_gate.py check --kit spec/art_identity/jobs/chainbound_gaoler/mq3_rear_v3/kit.json
python3 tools/art_identity_gate.py check --kit spec/art_identity/jobs/frostglass_lancer/mq1_front_v2/kit.json
python3 tools/art_identity_gate.py check --kit spec/art_identity/jobs/frostglass_lancer/mq1_front_v3/kit.json
python3 tools/art_identity_gate.py check --kit spec/art_identity/jobs/frostglass_lancer/mq1_rear_v3/kit.json
```

Creature sheets and kit checks enforce `edge_light_share` ≤ `creature.edge_light_share_max`. Pair sheets show
absolute front/rear chroma and value differences over non-accent pixels only. Both views use the exact palette-match
mask: opaque pixels with Lab chroma ≤ their view's p90 + 15. Kit checks enforce the unchanged `rear_consistency` bands
on those approved processed sources. Registry `source_path` / `source_pixel_sha256` bind those sources, their processing sidecars and
copied `post_steps`; `pixel_sha256` independently binds the density-treated production files.


Kit certification verifies `prompt.md` against `prompt_sha256` in both its job and registry, and the job's recorded
reference pixel digests against registry `ref_pixel_sha256`. Standard kits check digest validity and reference
identities without opening or regenerating reference PNGs; maquette kits also verify their shipped PNGs as in §7b.
Standard-kit `kit_version` is generation-time provenance: recover the captured
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
python3 tools/visual_probe_runner.py \
  --task-id art-03 --no-headless --display-driver macos --audio-driver Dummy \
  --expect-size 1920x1080 --proof-contract tests/bestiary_lineup_probe_contract.json \
  --result-manifest output/art-03-lineup.json tests/bestiary_lineup_probe.gd
python3 tools/visual_probe_runner.py \
  --task-id art-03 --no-headless --display-driver macos --audio-driver Dummy \
  --expect-size 1920x1080 --proof-contract tests/static_facing_probe_contract.json \
  --result-manifest output/art-03-static-facing.json tests/static_facing_probe.gd
```

The first probe writes the empty board and normal/boss lineups; the second writes eight idle facing captures
(`arc_thrall` and `slag_mortar`: front, front mirrored, rear, rear mirrored), `arc_thrall_mid_move.png`,
`slag_mortar_reduced_motion.png`, `turn_clock_three_portraits.png`, and `semantic-proof.json`. Both print their
isolated `user://probes/` directory. Capture uses only the fixed SubViewport texture. These probes construct their
own presentation fixtures; no saved-run inspection fixture is needed. The 11 old/new portrait pairs are available
at exact 2× NEAREST in `tests/static_facing_portrait_contact.png` (old left, approved crop right).
