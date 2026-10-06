# Unit 2: Board density proof probe and before/after sheets

## Header

Read `README.md` in this folder first. Existing probes to build on:
- `tests/actor_presentation_probe.gd` and `tests/enemy_cutout_roster_gameplay_probe.gd`: the live RunScene path, combat fixtures and `_still` captures;
- `tests/encounter_entry_probe.gd`;
- `tools/inspection_fixture.gd`: room scenarios.

## Change

### 1. Probe: `tests/board_density_probe.gd` (new)

**Rendering.**
- Use the real `scenes/run_scene.tscn` in a 1920×1080 SubViewport, the same way `actor_presentation_probe.gd` sets it up. Never capture the root window.
- Take a `--label <name>` argument, read from `OS.get_cmdline_user_args()` or an environment variable; match how other probes take arguments.
- Write stills to `user://probes/board_density/<label>/<scene>.png`, plus a `manifest.json`. For each still the manifest records:
  - the board tile width;
  - the hero's facing;
  - the screen rect of every actor and prop drawn (key, type, rect).

**Determinism.** A "before" run and an "after" run must differ only in art.
- Fix the animation phase of idle clips and sheets at capture time: torches, campfire, traps and unit idles. The simplest way is to capture each scene once its animated layers reach a fixed, documented phase.
- No random placement.
- Document in the probe header how determinism is achieved.

**Scenes.** Use production fixture paths where they exist. If a scene cannot be produced, use the closest existing fixture builder and say so.
1. `combat_small`:
   - the hero mid-board, facing AWAY from the camera (rear view);
   - Crawler, Cinder Droplet, Lightning Wisp, Bile Bloomer, Harrier and Cinder Ooze;
   - one fire trap and one ice trap, idle;
   - a wooden box, a wooden crate and a powder keg;
   - at least two pillars with their column torches;
   - a door;
   - dropped embers on a tile.
2. `combat_mixed`: the hero facing the camera, with Warden, Grave Surgeon, Frostglass Lancer, Chainbound Gaoler, Acolyte and Veilbound Acolyte.
3. `guardians`: one large guardian (Storm Cantor or Rimejaw) and two small ones (Rime Spitter and Wick Shade), with the watch brazier.
4. `dragon`: the Zekarion boss board with the hero.
5. Rooms:
   - `campfire` (the campfire idle);
   - `scavenger` (stall and scavenger NPC);
   - `start` (the emaciated man);
   - `relic_chest`.

**Finish.** Print `BOARD DENSITY PROBE: PASS` and the output directory.

### 2. Sheet builder: `tools/board_density_ab.py` (new)

`python3 tools/board_density_ab.py <before_dir> <after_dir> <out_dir>`
- **Per scene:** a before | after full-frame sheet.
- **Per manifest rect:** a before | after crop, padded by 12 px, at 3× nearest, with the hero's crop from the same scene at the start of each row as the reference.
- **Index:** an `index.md` listing the sheets.
- If before and after differ in anything except pixels inside the manifest rects and the floor, report that as a determinism failure.

## Keep

Production code is unchanged. This unit adds only the probe and the tool.

## Proof

- Your sandbox cannot start the GUI renderer.
- Make the probe parse cleanly with `--check-only` through `tools/godot_task_runner.py`, and give the exact `tools/visual_probe_runner.py` command, including `--timeout`.
- Unit-test the sheet builder on two synthetic directories (a small Python test or a `--self-test` flag).
- The design owner runs the captures natively.
