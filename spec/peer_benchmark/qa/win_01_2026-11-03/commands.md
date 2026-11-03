# Proof for the design owner

Every command below starts in the existing task worktree. Exports were deleted after reporting; regenerate them before reusing pack commands. No inspection fixture or renderer capture is required by this unit.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/win-01 && python3 tools/godot_task_runner.py --task-id win-01 --timeout 900 --stream -- godot --headless --path . --import
cd /Users/borgerding/workspace/Labyrinth.worktrees/win-01 && python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/win-01/python-default
cd /Users/borgerding/workspace/Labyrinth.worktrees/win-01 && python3 /private/tmp/labyrinth_codex/win-01/proof/host_native_shim.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/win-01 && python3 tools/export_game.py --preset 'Steam macOS' --output '/private/tmp/labyrinth_codex/win-01/export/macos/Escape the Umbra.zip' --task-id win-01
cd /Users/borgerding/workspace/Labyrinth.worktrees/win-01 && python3 tools/export_game.py --preset 'Steam Windows' --output '/private/tmp/labyrinth_codex/win-01/export/windows/Escape the Umbra.exe' --task-id win-01
cd /Users/borgerding/workspace/Labyrinth.worktrees/win-01 && python3 tools/export_game.py --preset 'Steam Linux' --output '/private/tmp/labyrinth_codex/win-01/export/linux/Escape the Umbra.x86_64' --task-id win-01
```

The export driver `proof/export_and_smoke.py` additionally extracts the macOS PCK from the ZIP. `proof/native_boot.py` expects the macOS executable and dylibs extracted with executable permissions preserved. Exact observed final commands follow. Steam is disabled by the runner; the shim only links host-native libraries and does not provide game scripts/assets.

`pack-macos-start-final.log`

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/win-01 && /Library/Developer/CommandLineTools/usr/bin/python3 tools/godot_task_runner.py --task-id win-01 --run-id win-01-macos-pack --godot-home-root /private/tmp/labyrinth_codex/win-01/homes --timeout 180 --stream -- godot --headless --path /private/tmp/labyrinth_codex/win-01/proof/bootstrap --main-pack '/private/tmp/labyrinth_codex/win-01/export/macos/Escape the Umbra.app/Contents/Resources/Escape the Umbra.pck' --script /private/tmp/labyrinth_codex/win-01/proof/pack_smoke.gd -- start /private/tmp/labyrinth_codex/win-01/proof/macos
```

`pack-macos-resume-final.log`

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/win-01 && /Library/Developer/CommandLineTools/usr/bin/python3 tools/godot_task_runner.py --task-id win-01 --run-id win-01-macos-pack --godot-home-root /private/tmp/labyrinth_codex/win-01/homes --timeout 180 --stream -- godot --headless --path /private/tmp/labyrinth_codex/win-01/proof/bootstrap --main-pack '/private/tmp/labyrinth_codex/win-01/export/macos/Escape the Umbra.app/Contents/Resources/Escape the Umbra.pck' --script /private/tmp/labyrinth_codex/win-01/proof/pack_smoke.gd -- resume /private/tmp/labyrinth_codex/win-01/proof/macos
```

`pack-windows-start-final.log`

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/win-01 && /Library/Developer/CommandLineTools/usr/bin/python3 tools/godot_task_runner.py --task-id win-01 --run-id win-01-windows-pack --godot-home-root /private/tmp/labyrinth_codex/win-01/homes --timeout 180 --stream -- godot --headless --path /private/tmp/labyrinth_codex/win-01/proof/bootstrap --main-pack '/private/tmp/labyrinth_codex/win-01/export/windows/Escape the Umbra.pck' --script /private/tmp/labyrinth_codex/win-01/proof/pack_smoke.gd -- start /private/tmp/labyrinth_codex/win-01/proof/windows
```

`pack-windows-resume-final.log`

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/win-01 && /Library/Developer/CommandLineTools/usr/bin/python3 tools/godot_task_runner.py --task-id win-01 --run-id win-01-windows-pack --godot-home-root /private/tmp/labyrinth_codex/win-01/homes --timeout 180 --stream -- godot --headless --path /private/tmp/labyrinth_codex/win-01/proof/bootstrap --main-pack '/private/tmp/labyrinth_codex/win-01/export/windows/Escape the Umbra.pck' --script /private/tmp/labyrinth_codex/win-01/proof/pack_smoke.gd -- resume /private/tmp/labyrinth_codex/win-01/proof/windows
```

`pack-linux-start.log`

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/win-01 && /Library/Developer/CommandLineTools/usr/bin/python3 tools/godot_task_runner.py --task-id win-01 --run-id win-01-linux-pack --godot-home-root /private/tmp/labyrinth_codex/win-01/homes --timeout 180 --stream -- godot --headless --path /private/tmp/labyrinth_codex/win-01/proof/bootstrap --main-pack '/private/tmp/labyrinth_codex/win-01/export/linux/Escape the Umbra.pck' --script /private/tmp/labyrinth_codex/win-01/proof/pack_smoke.gd -- start /private/tmp/labyrinth_codex/win-01/proof/linux
```

`pack-linux-resume.log`

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/win-01 && /Library/Developer/CommandLineTools/usr/bin/python3 tools/godot_task_runner.py --task-id win-01 --run-id win-01-linux-pack --godot-home-root /private/tmp/labyrinth_codex/win-01/homes --timeout 180 --stream -- godot --headless --path /private/tmp/labyrinth_codex/win-01/proof/bootstrap --main-pack '/private/tmp/labyrinth_codex/win-01/export/linux/Escape the Umbra.pck' --script /private/tmp/labyrinth_codex/win-01/proof/pack_smoke.gd -- resume /private/tmp/labyrinth_codex/win-01/proof/linux
```

`pack-macos-boot-fixed.log`

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/win-01 && /Library/Developer/CommandLineTools/usr/bin/python3 tools/godot_task_runner.py --task-id win-01 --run-id win-01-macos-boot-fixed --godot-home-root /private/tmp/labyrinth_codex/win-01/homes --timeout 60 --stream -- godot --headless --path /private/tmp/labyrinth_codex/win-01/proof/bootstrap --main-pack '/private/tmp/labyrinth_codex/win-01/export/macos/Escape the Umbra.app/Contents/Resources/Escape the Umbra.pck' --script /private/tmp/labyrinth_codex/win-01/proof/pack_boot.gd
```

`pack-windows-boot-fixed.log`

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/win-01 && /Library/Developer/CommandLineTools/usr/bin/python3 tools/godot_task_runner.py --task-id win-01 --run-id win-01-windows-boot-fixed --godot-home-root /private/tmp/labyrinth_codex/win-01/homes --timeout 60 --stream -- godot --headless --path /private/tmp/labyrinth_codex/win-01/proof/bootstrap --main-pack '/private/tmp/labyrinth_codex/win-01/export/windows/Escape the Umbra.pck' --script /private/tmp/labyrinth_codex/win-01/proof/pack_boot.gd
```

`pack-linux-boot-fixed.log`

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/win-01 && /Library/Developer/CommandLineTools/usr/bin/python3 tools/godot_task_runner.py --task-id win-01 --run-id win-01-linux-boot-fixed --godot-home-root /private/tmp/labyrinth_codex/win-01/homes --timeout 60 --stream -- godot --headless --path /private/tmp/labyrinth_codex/win-01/proof/bootstrap --main-pack '/private/tmp/labyrinth_codex/win-01/export/linux/Escape the Umbra.pck' --script /private/tmp/labyrinth_codex/win-01/proof/pack_boot.gd
```

`pack-macos-script-audit-canonical.log`

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/win-01 && /Library/Developer/CommandLineTools/usr/bin/python3 tools/godot_task_runner.py --task-id win-01 --timeout 180 --stream -- godot --headless --path /private/tmp/labyrinth_codex/win-01/proof/bootstrap --main-pack '/private/tmp/labyrinth_codex/win-01/export/macos/Escape the Umbra.app/Contents/Resources/Escape the Umbra.pck' --script /private/tmp/labyrinth_codex/win-01/proof/pack_script_audit.gd
```

`pack-windows-script-audit-canonical.log`

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/win-01 && /Library/Developer/CommandLineTools/usr/bin/python3 tools/godot_task_runner.py --task-id win-01 --timeout 180 --stream -- godot --headless --path /private/tmp/labyrinth_codex/win-01/proof/bootstrap --main-pack '/private/tmp/labyrinth_codex/win-01/export/windows/Escape the Umbra.pck' --script /private/tmp/labyrinth_codex/win-01/proof/pack_script_audit.gd
```

`pack-linux-script-audit-canonical.log`

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/win-01 && /Library/Developer/CommandLineTools/usr/bin/python3 tools/godot_task_runner.py --task-id win-01 --timeout 180 --stream -- godot --headless --path /private/tmp/labyrinth_codex/win-01/proof/bootstrap --main-pack '/private/tmp/labyrinth_codex/win-01/export/linux/Escape the Umbra.pck' --script /private/tmp/labyrinth_codex/win-01/proof/pack_script_audit.gd
```

`native-macos-default-boot.log`

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/win-01 && /Library/Developer/CommandLineTools/usr/bin/python3 tools/godot_task_runner.py --task-id win-01 --run-id win-01-native-macos-default --godot-home-root /private/tmp/labyrinth_codex/win-01/homes --timeout 45 --stream -- '/private/tmp/labyrinth_codex/win-01/export/macos/Escape the Umbra.app/Contents/MacOS/Escape the Umbra' --headless --log-file /private/tmp/labyrinth_codex/win-01/logs/native-macos-default-engine.log --quit-after 600 --max-fps 60
```

Additional audits:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/win-01 && python3 /private/tmp/labyrinth_codex/win-01/proof/audit.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/win-01 && python3 /private/tmp/labyrinth_codex/win-01/proof/runtime_paths.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/win-01 && python3 /private/tmp/labyrinth_codex/win-01/proof/observed_paths.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/win-01 && python3 /private/tmp/labyrinth_codex/win-01/proof/pck_audit.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/win-01 && python3 tools/typed_array_audit.py --json /private/tmp/labyrinth_codex/win-01/proof/typed-current.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/win-01 && python3 tools/godot_task_runner.py --task-id win-01 --stream -- godot --headless --path . --script /private/tmp/labyrinth_codex/win-01/proof/typed_and_namespace.gd
```

Native windowed launch command for the owner, after rebuilding/extracting the macOS bundle (not run here; no window-server access):

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/win-01 && python3 tools/godot_task_runner.py --task-id win-01 --allow-steam --stream -- '/private/tmp/labyrinth_codex/win-01/export/macos/Escape the Umbra.app/Contents/MacOS/Escape the Umbra'
```

Windows/Linux require transferring their complete export directory to the target machine and invoking that platform executable through the task runner (or the Steam build) there. No target OS installation or destination was available in this sandbox, so no executed target-native command or capture is claimed. Test startup, first fight/card, Save & Quit, relaunch/Continue, input, audio and renderer/cache behavior with Steam enabled.
