# GRD-11 native proof

The capture uses a 1920×1080 SubViewport, 100% UI scale, the normal RunScene
combat HUD and the existing full cel look. Install the project's existing
generated cel variants before capturing.

## Tile-size stills

This probe uses separate 1920×1080 RunScene fixtures at 100, 126, 147 and 184
framebuffer pixels per tile. The 1280×800 fixture uses a 100-pixel tile. Each
room saves a Fire and Electrified still with both occupied and empty tiles,
then a Stormcoal still at the same width. The native probe also compares the
shader's pixels to the authored palette and index bytes in a transparent
viewport.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/grd-11 &&
  export GRD11_WORKTREE="$PWD" LABYRINTH_CEL_LOOK=all LABYRINTH_GRD03_FIXTURE_ATLASES=0 &&
  GRD11_STILLS=/private/tmp/labyrinth_codex/grd-11-round1/native &&
  python3 tools/visual_probe_runner.py --task-id grd-11 --no-headless \
    --display-driver macos --audio-driver Dummy --rendering-method mobile \
    --rendering-driver metal --godot tools/grd11/study_native.sh --timeout 120 \
    --expect-size 1920x1080 --min-images 8 tools/grd11/size_stills.gd -- "$GRD11_STILLS/desktop" &&
  python3 tools/visual_probe_runner.py --task-id grd-11 --no-headless \
    --display-driver macos --audio-driver Dummy --rendering-method mobile \
    --rendering-driver metal --godot tools/grd11/study_native.sh --timeout 120 \
    --expect-size 1280x800 --min-images 2 tools/grd11/size_stills.gd -- --deck "$GRD11_STILLS/800p"
```

## Generated room width table

The census follows the generated map connections for run seeds 1–3 through
depth 12. Each reachable room uses its first breadth-first entry direction,
initial loadout and settled RunScene framing at default zoom. The CSV records
the physical width, integer cell size, selected sheet, drawn width and ratio
for each room at each output resolution.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/grd-11 &&
  LABYRINTH_CEL_LOOK=all python3 tools/godot_task_runner.py --task-id grd-11 --timeout 600 --stream -- \
    godot --headless --path . --script tools/grd11/room_widths.gd -- \
    /private/tmp/labyrinth_codex/grd-11-round1/room-widths.csv
```

## Fight and walk

Run from this worktree with a fresh absolute destination.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/grd-11 &&
  GRD11_OUT=/private/tmp/labyrinth_codex/grd-11/fight-native &&
  LABYRINTH_CEL_LOOK=all LABYRINTH_GRD03_FIXTURE_ATLASES=0 \
  python3 tools/visual_probe_runner.py --task-id grd-11 --no-headless \
    --display-driver macos --audio-driver Dummy --rendering-method mobile \
    --rendering-driver metal --godot tools/grd11/fight_native.sh --timeout 600 \
    --proof-contract tools/grd11/fight_proof_contract.json \
    --result-manifest "$GRD11_OUT/visual-proof.json" tools/grd11/fight_capture.gd -- "$GRD11_OUT"
```

The output contains 96 PNGs under `fight/`, six PNGs under `stills/`, 72 PNGs
under `walk/` and `fight-proof.json`. The still names use sample numbers
0012, 0036 and 0060 for 0.5, 1.5 and 2.5 seconds at 24 fps.

The existing Stormcoal rule applies to every Fire tile in the fight. Both
flag settings use the same room and enable that rule on sample 48. The
room shows ordinary Fire in the first half and Stormcoal in the second.
In the walk fixture the two production Move actions start on samples 12 and 42.
The temporary movie activates the engine's deterministic movie clock for the
native capture. The wrapper removes it on exit.

Headless validation uses the same scenario. The dummy renderer cannot
run MovieWriter, so the dry run waits for each walking sample on the live combat
clock. The manifest records the observed number of movement poses.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/grd-11 &&
  LABYRINTH_CEL_LOOK=all LABYRINTH_GRD03_FIXTURE_ATLASES=0 \
  python3 tools/godot_task_runner.py --task-id grd-11 --stream -- \
    godot --headless --path . --fixed-fps 24 --script tools/grd11/fight_capture.gd -- \
    --dry-run /private/tmp/labyrinth_codex/grd-11/fight-dry-new
```

## Matched study draw calls

Set `GRD11_BASE` to a prepared checkout of the unit's starting revision
`56ba4310d`, with the same full cel look variants. The two invocations use the
same study driver and seven columns. Each report records the canvas draw calls
and raised quad commands per column. The second run compares the flag-off
RGBA bytes and the serialized retained surface inputs to the first run.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/grd-11 &&
  export GRD11_WORKTREE="$PWD" LABYRINTH_CEL_LOOK=all LABYRINTH_GRD03_FIXTURE_ATLASES=0 &&
  GRD11_STUDY_OUT=/private/tmp/labyrinth_codex/grd-11/study-native &&
  python3 tools/visual_probe_runner.py --task-id grd-11 --no-headless \
    --display-driver macos --audio-driver Dummy --rendering-method mobile \
    --rendering-driver metal --godot "$GRD11_WORKTREE/tools/grd11/study_native.sh" \
    --timeout 120 --expect-size 1920x1080 --min-images 14 --project "$GRD11_BASE" \
    "$GRD11_WORKTREE/tools/grd11/study_calls.gd" -- "$GRD11_STUDY_OUT/before/study.json" &&
  python3 tools/visual_probe_runner.py --task-id grd-11 --no-headless \
    --display-driver macos --audio-driver Dummy --rendering-method mobile \
    --rendering-driver metal --godot "$GRD11_WORKTREE/tools/grd11/study_native.sh" \
    --timeout 120 --expect-size 1920x1080 --min-images 14 \
    tools/grd11/study_calls.gd -- "$GRD11_STUDY_OUT/after/study.json" "$GRD11_STUDY_OUT/before/study.json"
```

## Round 3 sliced ground proof

The comparison uses occupied and empty tiles for each of the four grounds,
plus merged Ice. The headless check adds Stormcoal and submits live previews,
feedback and a conduction path. It checks the slice's draw list and legacy
nodes in pixel mode and with `LABYRINTH_GROUND_FX` unset.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/grd-11
export GRD11_WORKTREE="$PWD" LABYRINTH_CEL_LOOK=all LABYRINTH_GRD03_FIXTURE_ATLASES=0
export GRD11_OUT=/private/tmp/labyrinth_codex/grd-11/round3

python3 tools/godot_task_runner.py --task-id grd-11 --stream --timeout 90 -- \
  godot --headless --path . --script tools/grd11/ground_comparison.gd -- \
  --dry-run --sliced --check-draw-path "$GRD11_OUT/pixel-dry"
python3 tools/godot_task_runner.py --task-id grd-11 --stream --timeout 90 -- \
  godot --headless --path . --script tools/grd11/ground_comparison.gd -- \
  --dry-run --sliced --check-draw-path --off "$GRD11_OUT/default-dry"
```

In the same shell, run these native commands to write the fight and walk
sequences under `fight-native/` and the 1920×1080 frames and 2× footprint
crops under `four-grounds-native/`. Each directory also receives a manifest.

```sh
python3 tools/visual_probe_runner.py --task-id grd-11 --no-headless \
  --display-driver macos --audio-driver Dummy --rendering-method mobile \
  --rendering-driver metal --godot tools/grd11/fight_native.sh --timeout 600 \
  --proof-contract tools/grd11/fight_proof_contract.json \
  --result-manifest "$GRD11_OUT/fight-native/visual-proof.json" \
  tools/grd11/fight_capture.gd -- "$GRD11_OUT/fight-native"

python3 tools/visual_probe_runner.py --task-id grd-11 --no-headless \
  --display-driver macos --audio-driver Dummy --rendering-method mobile \
  --rendering-driver metal --godot tools/grd11/study_native.sh --timeout 120 \
  --expect-size 1920x1080 --min-images 18 \
  tools/grd11/ground_comparison.gd -- --sliced "$GRD11_OUT/four-grounds-native"
```
