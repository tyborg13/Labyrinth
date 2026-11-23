# Pre-push smoke recording

Run from the worktree under inspection, with Godot, FFmpeg and FFprobe on PATH
and the approved cel-look variants installed in that worktree.

```sh
python3 tools/smoke_recording/record.py --out /private/tmp/labyrinth_codex/smoke-current
python3 tools/smoke_recording/record.py --out /private/tmp/labyrinth_codex/smoke-next --compare /private/tmp/labyrinth_codex/smoke-current
```

Use a fresh output directory. The native run uses the visual-probe runner and
Godot Movie Maker at 1920×1080 and 30 fps. Allow at least 5 GB for the MJPEG AVI
with mixed game audio and the encoded MP4. The recorder removes the AVI after
verifying the MP4. The native probe prints the current chapter and elapsed time
every minute and has a 5,400-second cap. Leave the game window and pointer alone
during the take.

The five chapters are main menu and map, normal fight, rewards and event,
Craghide and Tharokh, and return to menu. The fixed seed gives a real connected
route through Section I. The isolated profile uses the production tutorial
completion flag to reach ordinary combat with the starter kit. All recorded
actions enter the game as mouse or controller events. The fight policy reads
a snapshot to choose free movement and card inputs during the connecting
fights. The live engine commits each action, rolls encounters and rewards,
and determines Health within a fight. The route refills Health before each room,
so a weak starter deck can't stop it from reaching the later screens.

The output contains `recording.mp4` with embedded chapter markers,
`chapters.md`, `contact-sheet.png`, the five chapter stills, `timing.md`,
`visual-proof.json`, and `route.json`. The route log includes interaction
witnesses. The five stills are viewport captures taken during the route.
Production `performance_window` records are under `telemetry/`.
`frame-cohorts.json` supplements the production 33.33 ms bin with exact counts
strictly over 33 ms. Movie Maker fixes the simulation delta. Frame intervals in
the timing report use a monotonic clock and include the cost of recording.
Compare captures at 30 fps on the same host and renderer when assessing timing
changes.

Rehearse the same input route without capture by passing `--dry-run`.

```sh
python3 tools/smoke_recording/record.py --dry-run --out /private/tmp/labyrinth_codex/smoke-dry
```
