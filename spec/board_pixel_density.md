# Board pixel density

Board raster paint should read with the protagonist's chunky colour blocking at its actual draw scale. This treatment preserves texture dimensions, imports, native alpha, fully transparent RGB and silhouette edges; it changes interior RGB only. Gameplay, node names, rules, analytics and saves are unchanged.

The [design brief and comparison sheets](design/board_pixel_density/README.md) record the owner decisions of 2026-10-06. Harrier-class art uses grid 1.5 at the hero's scale. The hero front stays untouched as the reference, and the rear body receives native orphan cleanup only. The design owner retained the source silhouette edge, compensated for relative draw scale, and capped Lightning Wisp at grid 1.5 because coarser grids smear its line art. No palette posterising is applied to board paint: blocks retain averaged painted colours. The existing visible-gear palette/outline treatment is shared through `tools/pixel_density.py` without changing its outputs.

## Rule and registry

`spec/assets/board_pixel_density/registry.json` owns explicit paths, frame layouts, draw-scale derivations, calibration references, exceptions and coverage exclusions. Untouched originals live under its `sources/<repo-relative path>` directory. `outputs.json` binds each production paint PNG to its decoded output/source pixel digest, entry id, mode and grid. A pixel digest is SHA-256 over `RGBA\0`, big-endian uint32 width and height, then decoded RGBA bytes; PNG compression and metadata do not affect checks. Rest records bind each shipped assembly's pixel digest to the digest of that rig's sorted `path\0pixel_digest\n` part records at rebake time. [The native metrics report](assets/board_pixel_density/report.md) includes per-entry paths and scale mismatches. [Seed corrections](assets/board_pixel_density/seed_corrections.json) retain the code-survey reconciliation.

1. `r` is horizontal screen pixels per source pixel divided by the hero's `1.03/255` pixels per tile-width unit. Enemy/guardian rigs use `data/enemies.json` `art_scale`, default 1.0. Props use their actual source/frame width and code draw width. Follow texture trimming and aspect fitting before calculating the width; a pillar uses its alpha-used 160×205 region, not its transparent 255×255 canvas. NPCs use the unit fitting path and their `data/npcs.json` scale.
2. Measure the untouched rig front `rest.png`, or the first sheet frame. An orphan is a nonzero-alpha pixel whose RGB sum-absolute difference is at least 24 from every nonzero-alpha 4-neighbour. Only pixels with at least one such neighbour enter the denominator. `orphan_share` is a fraction in [0,1]; `t` is 1.5 at share ≥ 0.15, otherwise 1.0.
3. `grid = round(t/r, 2)`. Use `regrid` at grid ≥ 1.25; otherwise `clean`. Lightning Wisp and hero rear carry explicit override notes. All currently registered assets at r > 1.25 receive native cleanup; only higher-resolution repainting could bring their screen pixels exactly to the hero's size.
4. Regrid reduces float premultiplied channels independently with BOX to `round(w/grid) × round(h/grid)`, un-premultiplies, cleans orphans on the reduced grid (threshold 24, two simultaneous passes), and enlarges with NEAREST. Round float colour with `np.rint` before conversion to uint8. Replace RGB only where the original alpha is nonzero and the enlarged block is nonempty. Empty blocks retain source RGB.
5. Clean performs the same two-pass orphan cleanup at native resolution. Both modes restore source pixels on the edge ring: visible pixels with a transparent or out-of-bounds 4-neighbour. Outputs are 8-bit RGBA and retain alpha and all alpha-zero pixels byte for byte.
6. Sheets are processed per frame with the grid anchored at each frame origin. Regular sheets declare `{"grid": [cols, rows]}`; the door uses explicit `rects` copied from `DOOR_OPENING_FRAME_REGIONS` and verified against code. Gaps stay untouched. Frame regions may not overlap.

Horizontal run length counts consecutive nonzero-alpha pixels differing by less than 24 from the previous pixel. The report multiplies it by r for relative screen block size. It distinguishes native calibration-rest metrics from the mean before/after painted-part metrics; derived RGB statistics are not native-renderer proof.

## Scope and protected paint

- All 18 enemy cutout rigs used by `_unit_uses_cutout`, all 13 guardian rigs, and the hero rear body.
- Board floor variants, the runtime ember floor and stone fallback, all five families of floor overlays, the pillar and its moss overlay, all static/idle/activation traps, the door/opening sheet, and column torch static/idle art.
- Wooden box, crate, powder keg and the box/crate destroy sheets (the keg uses box destruction); relic chest and its four opening parts, campfire static/idle, watch brazier dark art, scavenger stall/NPC, emaciated-man idle and dropped embers. The opening chest's 128×160 canvas maps to 96×96 logical units: source-pixel scale is `0.68/96` per tile width, r = 1.753641, grid = 0.86, clean mode.

Some treated PNGs are **shared board art** also used in UI: the Warden, Chainbound Gaoler and Zekarion front `rest.png` files are their `art_path` in pre-battle/grimoire views; `assets/art/npcs/scavenger.png` supplies dialogue portrait crops and the grimoire icon; `dropped_embers.png` supplies the map recovery marker. They stay treated in those consumers; the pre-battle Warden was inspected at 1920×1080 (`design/board_pixel_density/review/13_ui_prebattle_warden.png`). The scavenger NPC overrides its grid to cleanup only because grid 1.63 muddied its face in the dialogue portrait (`review/14` rejected, `review/15` accepted).

Protected exclusions and reasons:

- Hero front: reference density. Rear sword/grip, crossbow, both hands and fingers: identical front-matched paint or gear-derived layers.
- Dedicated UI, cards, portrait PNGs, icons and item/equipment loot icons: shared painterly UI policy. This exclusion does not apply to the shared board art named above. Turn-order portraits are never rebaked here.
- Protagonist gear: its own painted-source pipeline (`process_gear_visual_assets.py`). Scavenger/Graftwright cutout rigs: UI-only.
- Raster VFX and ambient particles: transient glow art. Backdrop: soft, dimmed painting without fine texture.
- Wall overlays, non-earth pillar overlays, unreferenced floor art, `watch_brazier_lit`, and raised cover: not drawn in the active board path. Crag-outcrop/dragon-spire PNGs are geometry/shadow references; the live shapes draw procedurally.
- Rig assembled rests: only exact rest/assembly outputs named by layouts or renderers are excluded from paint processing. Live rest-named paint remains registered: Acolyte front `rest_hand.png`, front `rest_sleeve.png` and rear `rest_sleeve.png` (there is no rear `rest_hand.png`). All other rig layouts were checked for the same mistake.
- The hero's unused `rear_assembled_rest.png` is a historical pre-v9 reference. Its alpha differs from v9 at 271 pixels. It is preserved because rebaking it to the current assembly would violate the alpha invariant; runtime/layout consumers use `rear_assembled_rest_v9.png`. It is named in `preserved_rest_paths` and receives a rest digest without becoming a rebake target.

Every scanned board PNG and every rig PNG must be registered or have an `excluded_paths` object with a category (`vfx`, `ui_icon`, `never_drawn`, `presence_gate`, or `other`) and a concrete reason. Coverage scans `combat_board_view.gd`, `relic_chest_prop.gd`, `stone_outcrop_art.gd`, `dragon_board_props.gd`, NPC `art_path` and existing `_idle` sheets, including dynamic trap templates and the chest parts directory. A new path fails with registry/`--adopt` instructions.

## Commands

Run Python commands from the task worktree. Pillow and NumPy are required. Initial adoption copies painted production files and calibration rests and refuses existing sources unless explicitly forced:

```sh
python3 tools/process_board_density.py --adopt-all
```

`--only <id>` restricts adoption/processing/checking/rest recording to one entry, preserving the other manifest records. `--report` always reports the whole registry. `--adopt <path>...` adopts registered repainted/new paths; replacing an existing baseline requires `--force-adopt`. Processing always starts from sources, so reruns never compound treatment. `--write-originals` restores original paint and original native rests for before captures; restore the treated view by processing, rebaking and recording rests again. It deliberately does not update `outputs.json`, so `--check` detects the temporary original state.

Processing preserves the last rest records and never certifies a rebake. Run `--record-rests` only after a successful native rebake; it first verifies current part derivations, then records all 63 runtime views and the preserved historical hero assembly. `--check` reports `rest rebake needed` and exits 1 when a rest record is missing, rest pixels differ, or the current parts digest differs from the one recorded at rebake time. Changing PNG encoding alone remains current.

Parser proof, without launching a GUI:

```sh
python3 tools/godot_task_runner.py --task-id <task-id> --stream -- godot --headless --path . --script tools/rebake_cutout_rests.gd --check-only
```

Native steps (GUI renderer) from the task worktree:

```sh
python3 tools/process_board_density.py
python3 tools/visual_probe_runner.py tools/rebake_cutout_rests.gd --task-id <task-id> --no-headless --display-driver macos --audio-driver Dummy --timeout 180
python3 tools/process_board_density.py --record-rests
python3 tools/godot_task_runner.py --task-id <task-id> --stream -- godot --headless --path . --script tools/generate_unit_shadow_cache.gd
python3 tools/process_board_density.py --check
python3 tools/process_board_density.py --report
python3 tests/test_board_pixel_density.py
python3 tests/test_gear_visual_assets.py
```

The 180-second native timeout covers the known batch of 63 views, rig loading and per-pixel alpha comparisons. The rebaker uses each production rig's rest pose and the probes' `Rect2i(128,128,255,255)` region inside a transparent 512×512 viewport. It stages every changed facing and validates all old and untouched-source alpha bytes before writing any production rest. Existing `rest_source_sha256` fields are refreshed without reformatting layouts. A `--only <id>` script argument limits a later repaint rebake. It emits native proof PNGs plus `BOARD DENSITY REST REBAKE: PASS` only after all checks succeed.

After rebaking and cache regeneration, run fresh renderer probes and inspect captures at 1920×1080/100% UI scale; `--check-only` results do not establish rendered/rest equivalence or visual acceptance.

`tests/board_density_probe.gd` captures 11 representative scenes: props, small_a, small_b, mixed_a, mixed_b, guardians, dragon (Zekarion), campfire, scavenger, start and relic_chest. Run it after `--write-originals`, then again after processing and rebaking; `tools/board_density_ab.py` pairs them into full-frame and per-sprite sheets. These stills do not capture Iskaldra, Noctyrax, Tharokh, Vaeloryx or Vyraketh, the ten guardians outside Storm Cantor/Rime Spitter/Wick Shade, all facings or action phases, all floor/overlay variants and static fallbacks, earth/lightning/air traps, trap activation, destruction sheets, door/chest opening parts, or shared-art UI consumers. Idle sheets are sampled at one phase, not proved across every frame.

Cutout asset probes compare production rigs with their editable cases under `experiments/cutouts/`. Production paint is now the case paint after this treatment, so the four probes that passed before this pass (Chainbound Gaoler, Stone Warden, dragon attachment, Vaeloryx feedback) compare the exact alpha silhouette through `tests/helpers/silhouette_match.gd` instead of full RGBA; pose and motion parity is unchanged. Their `native_silhouette_comparisons` key counts attempted comparisons; `ok` establishes whether all checks passed. Python tests read those probes' current CaseRig configuration paths and pin each live case paint part to the decoded density source; derivation checks complete the case → source → production chain. The other sixteen asset probes already failed their case comparisons on master (2026-10-06) because later motion passes moved production past the cases; they are left as they were.

## Adding or repainting art

Before landing new or repainted board art: **register by the rule → adopt untouched paint → process → native rest-rebake → `--record-rests` → shadow cache**. Measure a fresh native calibration rest or first frame, derive r from the current code, and record any owner override. Add every new board PNG to `paths` or `excluded_paths` with a category and concrete reason. Update `measurement_path` and rest paths if the native assembly changed. Coverage failures name the `--adopt` action.

Adopt repainted PNGs with `--adopt <paths> --force-adopt` only after the repaint is installed; also adopt a recalibrated rest when its silhouette changes. Process the entry, run the native rebake, record rests, regenerate shadows, check the entry, and inspect the actual board. Keep source paint, registry, manifests and derived production PNGs together. Guardian promotion prints these follow-up commands and never runs them automatically. Sources have no `.gdignore`: the rebaker reads their part and old-rest alpha baselines with `Image.load_from_file("res://spec/assets/board_pixel_density/sources/...")`.

## Proof contract

Acceptance is reproducible decoded RGBA treatment for every registered board path; unchanged size, alpha, hidden RGB and edges; frame-local processing; exhaustive rig and scanned board-path coverage; unchanged gear derivations; and recorded native rests equal to the live assemblies. Run the tool `--check` and report, both Python suites, parser checks for touched GDScript, and the full headless Godot suite when runtime GDScript changes. Native completion requires rest rebake → `--record-rests` → shadow cache, the affected cutout asset probes, and inspected before/after board captures. Until the design owner completes that native sequence, `--check` and the strict shipped-derivations test are expected to fail with `rest rebake needed`; this is pending proof, not a passing rest check.
