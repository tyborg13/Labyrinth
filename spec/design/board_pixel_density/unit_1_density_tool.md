# Unit 1: Density tool, registry and treated board art

## Header

- **Read first:** `README.md` in this folder (the rule, decisions and scope), and the sheets in `review/`.
- **Seed data:** `grid_table.json`.
- **Reference prototype** (not production code; write your own clean implementation): `/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/1192fff8-0018-41b6-b489-30bcf96f6a52/scratchpad/density/treat.py`. Its functions are `regrid`, `regrid_keep_edge`, `edge_ring` and `clean_orphans`; `calib.py` there has `clean_only`.
- **Existing pipeline to share code with:** `tools/process_gear_visual_assets.py` and `tests/test_gear_visual_assets.py`.

## Change

### 1. `tools/pixel_density.py` (new shared helper)

- **Move code out of the gear tool.** Move `clean_orphans`, `consolidate` and `outline` out of `tools/process_gear_visual_assets.py` and import them from here.
  - The gear outputs must stay byte-identical: `python3 tools/process_gear_visual_assets.py --check` must still print `CHECK-OK`.
- **`regrid(im, grid)`**, as in the README rule:
  1. Premultiplied BOX reduction.
  2. Un-premultiply.
  3. `clean_orphans` on opaque pixels.
  4. NEAREST enlargement to the exact source size.
  - Write RGB only where the source alpha is above 0 and the enlarged block is non-empty; keep the source RGB elsewhere.
- **`clean(im)`**: `clean_orphans` at native size on opaque pixels.
- **Edge ring:** both modes then restore the edge-ring pixels from the source.
- **Invariants:** size, the alpha channel and alpha-0 pixels must be byte-identical. Output is 8-bit RGBA.
- **`process(im, mode, grid, frames)`.** `frames` is `None`, `{"grid": [cols, rows]}` or `{"rects": [[x, y, w, h], ...]}`.
  - Each frame region is processed on its own, with the grid anchored at the frame origin.
  - Pixels outside every frame stay untouched.
  - The door-opening rects are `DOOR_OPENING_FRAME_REGIONS` in `scripts/combat_board_view.gd`. Copy them into the registry, and have a test assert that they still match the code.
- **`metrics(im)`**: the orphan share (definition in the README) and the mean horizontal run length (consecutive opaque pixels each less than 24 from the previous one).

### 2. Registry `spec/assets/board_pixel_density/registry.json`

Seed it from `grid_table.json`.

**Fields per entry:**
- `id` and `kind`;
- `paths`. For rigs, this is every PNG under `<dir>/front` and `<dir>/rear` except `rest*.png`;
- `r` with its derivation:
  - rigs: `art_scale` in `data/enemies.json`, defaulting to 1.0;
  - props: the named draw constant in `scripts/combat_board_view.gd` ÷ `1.03/255`;
- `orphan_share`, `t`, `grid`, `mode`, `frames`, and an optional `override` note.

**Hero rear entry:**
- paths: `assets/units/protagonist_cutout/rear/*.png`;
- mode `clean`;
- exclude `weapon_r.png`, `weapon_r_grip.png`, `crossbow.png`, `hand_l.png`, `hand_r.png`, `hand_r_fingers.png` and the rest images. These match their front counterparts, and the gear tool derives the grip and fingers layers.

**Verify the props.** My prop values come from a code survey, not from running code.
- Check every prop's `r` against the code it cites.
- If the code disagrees, fix `r`, recompute `grid` by the rule, and list each correction in your final message.
- Confirm every listed path is actually drawn on the board, and drop any that are not.
- If you find a board-drawn raster I missed, add it by the rule and report it. Exclusions are listed in the README.

### 3. `tools/process_board_density.py` (new)

- **Sources.** The untouched originals are committed under `spec/assets/board_pixel_density/sources/<repo-relative path>`.
  - `--adopt-all` copies the current production files into sources.
  - It refuses to overwrite an existing source unless `--force-adopt` is given.
  - Run it once, before any processing.
- **Default run.**
  - Process every registered file from its source and write the production path.
  - Then write `spec/assets/board_pixel_density/outputs.json`, mapping each path to its sha256, id, mode and grid.
- **Other options:**
  - `--check`: recompute in memory and compare with production and `outputs.json`. Print `CHECK-OK`, or list the stale paths and exit non-zero.
  - `--only <id>`.
  - `--adopt <path>...`: make the current production file the new source, for repainted or new art.
  - `--write-originals`: copy the sources back over production, for before/after captures. The next default run restores the outputs.
  - `--report`: write `spec/assets/board_pixel_density/report.md`. It lists, per entry:
    - `r`, `t`, `grid` and `mode`;
    - the orphan share and run length at native, before and after;
    - the on-screen block size (run × r), with the hero's front as the reference row.
    - The report also has a section "Scale mismatches for owner decision" listing the entries with `r` > 1.25. Their pixels draw larger than the hero's, and only a higher-resolution repaint would match them exactly.

### 4. Rest rebakes: `tools/rebake_cutout_rests.gd` (new)

**Why:** the asset probes require each shipped rest image to equal the live native assembly. See `tests/harrier_cutout_asset_probe.gd:61`, which checks `shipped.get_data() == rest.get_data()`.

**The script** writes rebaked rest PNGs for every rig in the registry whose parts changed: enemy cutouts, guardians, and the hero's rear.
- Render each rest pose through the same renderer path and native region that the asset probes use.
- Find every rest path each rig ships, including the hero's `rear_assembled_rest_v9.png` and anything else a rear consumer loads.
- Assert that every rebaked rest's alpha is byte-identical to before.

**Running it.** Your sandbox cannot start the GUI renderer.
- Make the script parse cleanly under `--check-only` through `tools/godot_task_runner.py`.
- Give the exact `tools/visual_probe_runner.py` command. The design owner runs it natively, then regenerates `assets/generated/unit_shadow_cache.res`.

**Do not regenerate** the turn-order portraits (`tools/build_turn_order_assets.gd`). Portraits are out of scope.

### 5. Tests: `tests/test_board_pixel_density.py` (new; unittest, in the style of `tests/test_gear_visual_assets.py`)

- `--check` passes.
- For every output: size, alpha and alpha-0 pixels are byte-identical to its source.
- **Coverage.** Every PNG under each board rig directory is either registered or explicitly excluded, with a reason. The board rig directories are:
  - the cutout types in `_unit_uses_cutout`;
  - every `assets/units/guardians/<id>`;
  - the hero's rear.

  A new rig directory or a new PNG fails, with a message naming `--adopt`.
- Registry grids follow the rule, except entries that carry an override note.
- The door-opening rects match the code.
- The gear tool `--check` still passes.

### 6. Spec: `spec/board_pixel_density.md` (new)

- **Content:**
  - purpose;
  - the owner and design-owner decisions in the README;
  - the rule;
  - scope and exclusions, with reasons;
  - commands;
  - how to add or repaint art.
- **Links** to add:
  - one line in `spec/visual_design_system.md`;
  - one in `spec/cutout_workflow.md`;
  - one in `spec/protagonist_cutout_runtime.md` (the rear view is cleaned; the front is the reference).

### 7. Workflow

- **Skill and workflow docs.** In `.codex/skills/create-labyrinth-cutout/SKILL.md` (and its promotion checklist, if one exists in `references/`), `.codex/skills/create-labyrinth-enemy/SKILL.md` and `spec/cutout_workflow.md`, state that new or repainted board art is:
  1. registered by the rule;
  2. adopted;
  3. processed;
  4. rest-rebaked before landing.
- **`tools/build_guardian_cutouts.py --promote`:** after promoting, print those follow-up commands. Do not run them.

## Keep

- Rules, analytics and saves.
- All non-board art.
- Texture sizes, imports and draw code.
- Byte-identical gear outputs.
- The hero's front parts and his rear weapon, crossbow and hands.

## Proof

- **Run:**
  - the tool, then `--check`;
  - `--report`;
  - `python3 tests/test_board_pixel_density.py` and `python3 tests/test_gear_visual_assets.py`;
  - the full Godot suite headless through `tools/godot_task_runner.py`;
  - `--check-only` on the rebake script.
- **Report:**
  - exact result lines;
  - files changed per entry;
  - every registry correction.

The design owner runs the GUI asset probes and captures after the rebake.
