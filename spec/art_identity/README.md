# Art identity command reference

Run from the repository root with Python 3.9 or later, numpy and Pillow. These commands read the director-owned
canon, bands, preamble and view clauses. They do not generate art or change game data.

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
