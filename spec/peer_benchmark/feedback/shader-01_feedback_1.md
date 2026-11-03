# shader-01 feedback 1: fix the root cause, drop the warmup

## What the director found
- **Root cause, confirmed.**
  - `scripts/steam_service.gd` `_apply_steam_user_directory()` switches `user://` at runtime
    (`application/config/use_custom_user_dir` + `custom_user_dir_name`, giving "Escape the Umbra/steam/<id>") after
    the renderer has set up its shader cache.
  - Every shader compiled after that point fails `_save_to_cache` (`shader_rd.cpp:516`), because the cache folders
    only exist in the pre-switch user dir. Godot's pipeline cache very likely suffers the same way: it reads from the
    old dir at startup and writes to the new one.
  - Repro, with no Steam needed: `spec/peer_benchmark/director_tools/user_dir_switch_shader_probe.gd`. A fresh shader
    drawn before the switch caches cleanly; one drawn after the switch logs the owner's exact error.
  - The owner's Steam folder has no `shader_cache`. The old cache was last written 2026-09-25, probably in a session
    without Steam.
- **The warmup doesn't meet its acceptance natively.**
  - Trap scenarios still compile 3 pipelines per pass in combat.
  - Warmup frames exceed 8 ms.
  - The join and the loading extension exceed 100 ms.

## Decisions
1. **Remove the warmup entirely**: `pipeline_warmup*.gd`, the `menu_run_transition.gd` hook, the inventory tool and
   its tests. Keep only what the cache fix needs.
2. **Fix the cache across the user-dir switch.** Right after `_apply_steam_user_directory()` switches the dir (and
   before anything else renders), make every engine cache folder in the new user dir resolve to the original
   pre-switch folder:
   - Capture the pre-switch absolute user dir before switching.
   - For `shader_cache` and the pipeline cache folder (find its real name/location for Godot 4.6.1 on Metal and Vulkan,
     e.g. `vulkan/`; inspect what the engine writes under a fresh user dir), create a link in the new user dir pointing
     to the original (`DirAccess.create_link`).
   - If a link can't be created (e.g. Windows without symlink permission) or the path already exists as a real
     folder: mirror the original `shader_cache` folder tree (every `<shader>/<group>` directory) into the new
     location, so writes succeed there. Report what that means for persistence on that path.
   - Never delete or overwrite anything in either location. Do the same in `scripts/parallel_runtime.gd`'s switch only
     if it costs nothing; that path is tests only.
3. **Proof (director-checkable):**
   - Headless/unit: link creation, the mirror fallback, idempotence on the second launch, no deletion.
   - Native probe: the director's probe pattern with a deterministic shader, run twice in the same HOME with the switch.
     Run 1: no `_save_to_cache` errors after the switch. Run 2: that shader is a cache hit (verbose log) and the
     pipeline compile counters stay 0 for it.
   - Then perf-03 scenario B (`--native`), twice in the same HOME with the Steam-style switch emulated: the second
     session compiles 0 pipelines in combat. Give the exact commands.
4. Steam itself stays untouched apart from this hook. No export-preset or engine changes.

Re-run: the Steam service tests (find them; e.g. a `steam_service` suite), the settings/save pipeline tests, and the
new tests. No full suites.
