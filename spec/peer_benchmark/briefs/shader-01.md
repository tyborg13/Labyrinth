# shader-01 — No shader compiles mid-action: warm combat pipelines before the fight

## Header
- **Why.** The owner's 150 ms hitch (2026-10-22) coincided with first-use shader work. perf-03's native trap scenario
  compiled 4 render pipelines on the first trap kill (31 ms frame, about 10 ms uncovered); later passes compiled none
  (19 ms). The owner's Steam build also logged 37 `shader_rd.cpp _save_to_cache` failures in one session (cache folder
  untouched since 2026-09-25), so every session pays those compiles again.
  - The director exported the macOS build (`Steam macOS` preset) and ran it with a fresh home and with a copy of the
    owner's cache. Both wrote their caches cleanly at the main menu, so the save failure isn't reproduced. Making
    first use cheap fixes the hitch either way.
- **Base:** `codex/peer-benchmark`. **Risk tier:** standard.
- **Owned:** a new `scripts/pipeline_warmup.gd` (and a scene if needed); the hook where the pre-battle / combat loading
  screen starts (small, not inside `run_scene.gd`'s hot paths); a new focused test + runner; a native proof probe.

## Rule that matters most
The player sees nothing new: no flashes, no visible offscreen content, no extra loading time they can notice. The
pre-battle screen must not get longer than today by more than 100 ms (report it), and it must stay responsive.

## Change
1. **Inventory every combat render path that can compile on first use:**
   - every CanvasItem `ShaderMaterial`/`.gdshader` used on the board, by units, FX and UI in combat (e.g.
     `combat_floor_light`, `combat_art_treatment`, `enemy_shadow_dissolve`, element/trap/surface FX);
   - particles (CPU/GPU, and which);
   - blend modes, light/occlusion use, MSAA and texture-filter variants the board actually uses.
   Derive it from the code and data, and print the inventory; don't hand-guess.
2. **Warm them while the pre-battle screen shows:** draw one frame of each into a hidden offscreen `SubViewport` (same
   rendering method, MSAA and filter settings as the real board), spread over frames so no single frame exceeds 8 ms.
   Do it once per session; later fights skip it.
3. **Measure with Godot's pipeline counters** (`Performance.PIPELINE_COMPILATIONS_*`): in the perf-03 harness scenarios
   (`tests/perf/combat_frame_scenarios.gd`: hover sweep, the Hobnail Drive lightning-trap kill, fire trap, survivor)
   run after the warmup, the per-frame pipeline compilations during combat must be 0. Add a native proof command that
   reports them.
4. **Investigate the cache-save failure a little more** (time-box 30 min): read Godot 4.6.1's `ShaderRD` cache path
   logic as far as you can from the binary's behaviour and our project settings, and list any setting or path in this
   project that could make `_save_to_cache` fail in an exported build launched from Steam (working directory, user
   dir, custom user dir name, permissions). Report findings only; change nothing there unless it's a clear project
   misconfiguration, and if so stop and report first.

## Proof
- A focused test that the warmup covers the inventory (every inventoried material is drawn at least once offscreen) and
  that it runs once per session.
- The headless harness still passes (`--equivalence-only`).
- Under "Proof for the design owner": the windowed command that runs scenario B on the real renderer and prints the
  pipeline counts per frame; the director checks it.
- No full suites.

## Out of scope
Changing any shader's look, export presets, the Steam build pipeline.

## Current export command

Release and playtest exports refresh cel variants and verify their packaged paths and runtime pixels:

```bash
python3 tools/export_game.py --task-id <task-id> --preset 'Steam macOS' --output /private/tmp/labyrinth_codex/<task-id>/Escape-the-Umbra.zip
python3 tools/export_game.py --task-id <task-id> --preset 'Steam Windows' --output /private/tmp/labyrinth_codex/<task-id>/Escape-the-Umbra.exe
```
