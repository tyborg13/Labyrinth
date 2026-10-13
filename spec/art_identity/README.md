# Art identity command reference

Run from the repository root with Python 3.9 or later, numpy and Pillow. These commands read the director-owned
canon, bands, preamble and view clauses. They do not generate art or change game data.

## Deterministic crawler recolour (rr-01)

The director's 2026-10-13 legacy palette correction uses `L* × 0.76`, `a*, b* × 0.85` and `np.rint`, with
the conversion in `prototype/match_palette.py`. Every nonzero-alpha pixel is transformed, including translucent
paint; alpha and fully transparent pixels stay byte-identical. The tool refuses any mode other than RGBA.
Without `--in-place` it prints before/after Rec.601 value and RGB max-minus-min chroma, without writing.
An image with no alpha > 128 reports null audit metrics. Reapplying the transform darkens again; use the fixed
baseline, never already recoloured paint, when rebuilding.

```sh
python3 tools/recolour_lab.py --l-scale 0.76 --ab-scale 0.85 FILES...
python3 tests/test_recolour_lab.py
```

Only crawler sources and the named portrait/fallback are recoloured. Density grids, rig layouts, joints, motion
and adoption metrics are preserved. The rr-01 checkout's actual unchanged baseline is
`2cf00ab4ece2f27a590f0bde5d5fb2fecacbd283`; use this fixed commit, including after the design owner commits rr-01.

```sh
python3 tools/recolour_lab.py --l-scale 0.76 --ab-scale 0.85 --in-place \
  spec/assets/board_pixel_density/sources/assets/units/crawler_cutout/front/*.png \
  spec/assets/board_pixel_density/sources/assets/units/crawler_cutout/rear/*.png
python3 tools/process_board_density.py --only crawler
python3 tools/recolour_lab.py --l-scale 0.76 --ab-scale 0.85 --in-place \
  assets/art/portraits/tunnel_crawler.png assets/placeholders/units/crawler_anime_trial.png \
  assets/placeholders/units/crawler_anime_trial_idle.png
```

Those transform commands have already been applied in rr-01. Do not run them a second time. While windowed
rebake is pending, `--record-crawler --paint-only` records only the static fallback's finished legacy entry, and
`--check-crawler --paint-only` verifies all 32 recoloured density sources, 30 derived parts and three direct PNGs.
Both rest entries and their previous native rebake records remain uncertified until the following continuation.

The director resolved crawler calibration on 2026-10-13: this is a palette change, so both density grids stay
1.73 and remain calibrated on the pre-recolour source from 2026-10-07. The crawler density entry records
`calibration_source`, `calibration_note` and `calibration_baseline`. The baseline binds the two original source
rests to the fixed Git commit above and decoded pixel digests. Density checks, tests and report calibration rows
measure those bound historical pixels and still enforce the original orphan-share, strength and grid rule.
The current recoloured source orphan shares (0.039500180720 front / 0.046415678185 rear) do not recalibrate the grid.
Paint is still derived from current recoloured sources; every other entry still calibrates on its ordinary
untouched density source. A note with missing or incorrect baseline evidence fails validation. The calibration
TODO is resolved; the full density check continues to require the pending native rest rebake.

The sound alternative to changing the shared identity gate is a separate mandatory replay check, then the
unchanged gate's production-digest check. `recolour_baseline` binds the prior decoded digest to an immutable Git
commit containing that PNG and its original legacy registry entry. `post_steps` records the director's parameters
and reason. The checker independently replays the source transform and density derivation, rejects changed
density settings and adoption fields (allowing only the verified calibration annotation), and requires up-to-date
native rest/parts records with unchanged alpha and hidden pixels. The real-renderer contact probe independently
checks native rest assembly pixel equality. A bare
updated digest or unverified rest record alone does not complete this workflow.

The design owner runs this continuation in order. Native rebake is windowed and uses the visual runner;
`--record-rests` and full legacy registration follow only a successful native rebake. It emits two 255×255 rest
proof PNGs, which are native assets rather than player-facing screenshots. The crawler layouts have no rest
fingerprint field, so this rebake changes no layout JSON.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-01 && python3 tools/visual_probe_runner.py \
  --task-id rr-01 --no-headless --display-driver macos --audio-driver Dummy \
  --expect-size 255x255 tools/rebake_cutout_rests.gd -- --only crawler
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-01 && python3 tools/process_board_density.py --only crawler --record-rests
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-01 && python3 tools/godot_task_runner.py \
  --task-id rr-01 --stream -- godot --headless --path . --script tools/rr01_refresh_shadow_cache.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-01 && python3 tools/godot_task_runner.py \
  --task-id rr-01 --stream -- godot --headless --path . --script tools/rr01_refresh_shadow_cache.gd -- --check
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-01 && python3 tools/recolour_lab.py \
  --record-crawler --baseline-ref 2cf00ab4ece2f27a590f0bde5d5fb2fecacbd283
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-01 && python3 tools/recolour_lab.py \
  --check-crawler --baseline-ref 2cf00ab4ece2f27a590f0bde5d5fb2fecacbd283
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-01 && python3 tools/process_board_density.py --only crawler --check
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-01 && python3 tools/art_identity_gate.py check
```

Renderer proof uses 1920×1080 and 100% UI scale. The contact probe loads exact previous PNGs exported by
`--prepare-proof`, displays before above after at 2× NEAREST, and compares the native front/rear assemblies to
shipped rests before saving. `--validate-only` runs metadata/alpha/palette checks headlessly, with no capture claim.
The original baseline files are proof inputs under `output/rr-01/before/`, not additional production paint.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-01 && python3 tools/recolour_lab.py \
  --prepare-proof --baseline-ref 2cf00ab4ece2f27a590f0bde5d5fb2fecacbd283
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-01 && python3 tools/visual_probe_runner.py \
  --task-id rr-01 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 \
  --proof-contract tests/crawler_recolour_probe_contract.json \
  --result-manifest /private/tmp/labyrinth-inspection-manifests/rr-01-crawler-recolour.json tests/crawler_recolour_probe.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-01 && python3 tools/visual_probe_runner.py \
  --task-id rr-01 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 \
  --proof-contract tests/bestiary_lineup_probe_contract.json \
  --result-manifest /private/tmp/labyrinth-inspection-manifests/rr-01-lineup.json tests/bestiary_lineup_probe.gd
```

The contact probe emits `crawler_before_after.png` and `semantic-proof.json` in its printed isolated
`user://probes/crawler_recolour/` directory. The lineup output is described below. These galleries construct their
own presentation states; a playable saved-run inspection fixture is not applicable. No `inspection_fixture.py`
command is required by rr-01.

## Existing gate commands

```sh
python3 tools/art_identity_gate.py measure assets/units/protagonist_cutout/front/front_assembled_rest.png
python3 tools/art_identity_gate.py measure tests/fixtures/art_identity/storm_capacitor.png --kind object --anatomy plinth
python3 tools/art_identity_gate.py measure assets/units/crawler_cutout/front/rest.png --art-scale 0.64 --anatomy crawler
```

`measure` prints canvas alpha-bbox dimensions, drawn height, morphology, luminance-region and palette metrics, and
the board-density orphan/run metrics. Object measurement also prints both fitted base slopes. Empty subjects and
subjects without any four-pixel luminance region fail with an explicit error.

```sh
python3 tools/art_identity_gate.py kit --id candidate --subject subject.md \
  --view creature_front --size-class medium --anatomy biped \
  --peers harrier_front grave_surgeon_front --out-dir jobs/candidate/front
python3 tools/art_identity_gate.py kit --id candidate --subject subject.md \
  --view creature_rear --size-class medium --anatomy biped \
  --peers harrier_front grave_surgeon_front --front-ref approved_front_raw.png \
  --out-dir jobs/candidate/rear
```

`kit` requires a fresh `refs` directory. Peers must be canon of the candidate's kind and anatomy; front/rear IDs are
resolved to the matching view. Views are `creature_front`, `creature_rear`, `beast_front`, `beast_rear`, and
`object_plinth`. Size classes default to heights 150, 205 and 238; `--target-h` and `--target-w` override the target
dimensions. Rear views require an unchanged raw front reference. Plinth jobs include the footprint guide.
References are centred, with at least 32 green pixels below their enlarged bbox. Output is `prompt.md`, `kit.json`
and `refs/*.png`; stdout is the exact orchestrator command, using `$CU` or the brief's default command.

```sh
python3 tools/art_identity_gate.py process raw.png --kit jobs/candidate/front/kit.json --out assets/candidate.png
python3 tools/art_identity_gate.py sheet --front assets/candidate.png --rear assets/candidate_rear.png \
  --kit jobs/candidate/front/kit.json --art-scale 1.0 --landmarks landmarks.json --out jobs/candidate/sheet.png
```

`process` requires a square raw canvas and uses `k_eff = K × raw_width / 1024`. BOX resizing of floating
premultiplied channels supports non-integer effective factors; a 1280² K=4 raw uses `k_eff: 5.0`. Padding remains
anchored at the bbox's bottom-left; non-integer raw-pixel padding rounds outward. After downscale and alpha
binarization, sprites taller than 240 px or wider than 251 px uniformly BOX-fit inside those limits using the same
premultiplied/binary-alpha path. Paint is never clipped to the canvas. Placement remains centre x=128, bottom y=246.
The sibling `.json` contains raw SHA-256, decoded pixel digest, K, `k_eff`, `fit_scale` (1.0 when no fit is needed),
drawn dimensions, placement, shift and metrics.
`sheet` accepts an optional rear and optional landmarks. Landmarks are `{"far": [x,y], "near": [x,y]}` for a shared
annotation, or `{"front": {"far": [x,y], "near": [x,y]}, "rear": {...}}` for distinct facings. Coordinates are canvas
pixels, y down. Missing required landmarks appear as FAIL in the table. Sheets use the committed
`backdrop/empty_board.png` and `backdrop/slots.json` together, or the specified synthetic board until both exist.
The metric table includes `fit_scale` as INFO, bound to the processed PNG's digest through its sidecar. Legacy or
kit-less candidates without processing metadata show N/A.

```sh
python3 tools/art_identity_gate.py canon-sheet --out jobs/canon-front.png
python3 tools/art_identity_gate.py canon-sheet --view rear --out jobs/canon-rear.png
```

`canon-sheet` labels every canon creature in the selected facing (default `front`) and every canon object. All
subjects use their enemy-data art scale where applicable and the same backdrop slots, LANCZOS screen-size draw,
canvas registration and exact 2× NEAREST duplication as the candidate sheet. Rows repeat to include the complete
canon in one image. Give this image to the independent judge beside the candidate sheet.

```sh
python3 tools/art_identity_gate.py adopt-legacy
python3 tools/art_identity_gate.py check
python3 tools/art_identity_gate.py check --id arc_thrall --strict
python3 tests/test_art_identity_gate.py
```

`adopt-legacy` is a one-time baseline command and refuses to overwrite an existing registry. Paths are sorted;
all twelve rejected 2026-10-12 jobs are `pending_reart`, even if some files have not yet been integrated. `check`
reports each path and exits 1 on a failure. Pending entries warn normally and fail under `--strict`. `--id` selects
an enemy/canon ID or exact path; coverage and duplicate-path failures are still checked globally.

Registry entries use `entry_kind` (`legacy`, `pending_reart`, `kit`) separately from subject `kind` (`creature`,
`object`). Kit entries require repository-relative `path`, `kit_path`, `prompt_path`, `sheet_path`; `job_id`,
`kit_version`, `raw_sha256`, `pixel_sha256`; `kind`, `anatomy`, `size_class`; `judge` with `verdict: PASS` and `date`;
and an `owner_approval` note. Add `landmarks` for creatures/legged objects. Optional `raw_path` is verified against
the raw hash. Exceptions are `{"metric": "thin_rel", "value": 0.15, "reason": "owner-approved reason"}` and must
match the current measurement; hard exception limits still apply. Runtime art scale and boss classification come
from enemy data when the path is covered there. Legacy entries retain their adoption metrics and decoded digest.

Headless roster validation and real-renderer capture are separate commands:

```sh
python3 tools/godot_task_runner.py --task-id art-01 --stream -- godot --headless --path . \
  --script tests/bestiary_lineup_probe.gd -- --validate-only
python3 tools/visual_probe_runner.py --task-id art-01 --no-headless --display-driver macos --audio-driver Dummy \
  --expect-size 1920x1080 --proof-contract tests/bestiary_lineup_probe_contract.json \
  --result-manifest /private/tmp/labyrinth-inspection-manifests/art-01-lineup.json tests/bestiary_lineup_probe.gd
```

The windowed probe prints its isolated output directory: `00_empty_board.png`, `slots.json`,
`01_lineup_normals.png`, `02_lineup_bosses.png`, and `semantic-proof.json`. After inspecting the captures, the design
owner copies `00_empty_board.png` to `spec/art_identity/backdrop/empty_board.png` and `slots.json` beside it. Headless
validation writes only slot/semantic JSON and makes no visual-proof claim. No inspection save fixture is needed:
this gallery constructs its own presentation-only state and does not expose a playable change.
