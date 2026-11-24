# gfix-46 UID repair

## Census

`python3 tools/gfix46/uid_census.py` reads the working copies of tracked files. Add `--inventory` to list every declaration and reference, including the `path=` target of an external resource when available. The command exits 1 when a UID is declared by multiple files.

Before, on `23152865a`:

```text
uid://dhbcy5jpnld0c (duplicate)
  declares assets/placeholders/units/player_reaver_anime_idle.png.import:5
  declares assets/placeholders/units/player_reaver_idle.png.import:5
  references: none
UID census: 13973 declarations, 3 references, 1 duplicate UIDs.
```

After:

```text
UID census: 13973 declarations, 3 references, 0 duplicate UIDs.
```

## UID assignment and reference paths

- `player_reaver_idle.png.import` keeps `uid://dhbcy5jpnld0c`. The board fallback in `scripts/combat_board_view.gd` starts from `player_reaver.png` and derives the `_idle` stem in `_load_idle_frames_for_art_path`. `AssetLoader.load_texture_by_stem` tries PNG first, so that fallback loads `player_reaver_idle.png` by path. The tracked reference formats contain zero references to the shared UID and no caller of the anime idle texture. Git history agrees with the runtime evidence. `git log --diff-filter=A` dates the idle sidecar to `1929aa454` on 2026-04-12 and the anime idle sidecar to `c592238a3` on 2026-04-28. `1929aa454` is an ancestor of `c592238a3`.
- `player_reaver_anime_idle.png.import` receives `uid://ntbi2w113m2l`. The project’s Godot 4.6.1 ran `ResourceUID.id_to_text(ResourceUID.create_id())` headless through the task runner and printed `GFIX46_NEW_UID uid://ntbi2w113m2l`.
- Zero tracked `ext_resource` entries referenced the changed UID. The two `ext_resource` UID references in the inventory belong to Steamworks editor scripts. Their `path=` values match their declarations. The third reference is the Steamworks panel preload in `godotsteam_plugin.gd`. The two Reaver PNGs have the same SHA-256, `51eb82f5b24d2fba17eae4f29ee9645e4c4acb01402084d7c4c5d4a062025592`, so the release probe checks exact resource paths as well as loading both textures.

## Headless import

The focused runs used empty projects containing the unchanged PNGs and their original resource paths. Both exited 0. Godot 4.6.1 ran via `python3 tools/godot_task_runner.py --task-id gfix-46 --stream -- godot --headless --path <staged-project> --import`.

`output/gfix46/import-focused-before.log` used the two sidecars from `23152865a` and reproduced the baseline diagnostic:

```text
WARNING: UID duplicate detected between res://assets/placeholders/units/player_reaver_idle.png and res://assets/placeholders/units/player_reaver_anime_idle.png.
     at: _process_file_system (editor/file_system/editor_file_system.cpp:1377)
```

The focused fixed import at `output/gfix46/import-focused.log` re-imported both textures with zero UID warnings. The lines below omit terminal color codes.

```text
[   0% ] reimport | player_reaver_anime_idle.png
[  33% ] reimport | player_reaver_idle.png
[ DONE ] reimport
```

The headless source probe loaded both textures through `ResourceLoader` by path and by UID. Its output in `output/gfix46/source-load.log` matches the two `GFIX46_TEXTURE_LOADED` lines from the release binary below.

Additional full-worktree scans were stopped after the initial scan produced no further progress. The clean-cache baseline (`output/gfix46/import-before.log`) reproduced the warning. The clean-cache fixed run (`output/gfix46/import-after.log`) emitted zero UID warnings through cancellation. A run seeded with the original warm cache (`output/gfix46/import-warm.log`) still warned, and both Reaver entries in that `filesystem_cache10` held the same old numeric ID (`7652814217641924520`). The completed focused imports and release export used fresh filesystem and UID caches.

## Steam macOS export and release smoke

`python3 tools/gfix46/export_uid_smoke.py` uses `tools/export_smoke.py` to stage the working tree, run `tools/export_game.py` and launch the native release binary headless. The additional probe verifies that each UID maps to its expected path and that the packed texture loads both ways.

```text
CEL_PACK_TEST paths=3089 failures=0
EXPORT_SMOKE_LOADED scripts=799 scenes=9
GFIX46_TEXTURE_LOADED uid://dhbcy5jpnld0c -> res://assets/placeholders/units/player_reaver_idle.png (4080x2040)
GFIX46_TEXTURE_LOADED uid://ntbi2w113m2l -> res://assets/placeholders/units/player_reaver_anime_idle.png (4080x2040)
GFIX46_EXPORT_SMOKE RESULT: PASS (303.11 seconds)
```

`output/gfix46/export/export.log` and `output/gfix46/export/launch.log` have zero UID warnings. Godot printed `ERROR: Condition "ret != noErr" is true. Returning: ""` from `get_system_ca_certificates` during the headless commands. The export and texture loads completed successfully.

## Python default group

`python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir output/gfix46/python` selected the `default` group. The result is in `output/gfix46/python-default.log`.

```text
SELECTED MODULES: 23 of 59
Ran 196 tests in 45.907s
FAILED (failures=1)
```

`test_godot_task_runner.GodotTaskRunnerTests.test_killing_runner_mid_godot_test_leaves_no_godot_child` reported `AssertionError: False is not true : Child did not start`. The same test passed in isolation on both the baseline snapshot (`Ran 1 test in 3.983s`, `OK`) and the updated worktree (`Ran 1 test in 3.426s`, `OK`). No assertions were edited. The runner also reported that the sandbox denied its optional Git timing-cache write.

The census fixture printed `UID_CENSUS_FIXTURE PASS (4 declaration forms; 4 reference formats; ext_resource path; BOM and CRLF)`.
