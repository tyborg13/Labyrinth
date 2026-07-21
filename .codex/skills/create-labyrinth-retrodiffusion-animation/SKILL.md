---
name: create-labyrinth-retrodiffusion-animation
description: Generate, import, clean, validate, and wire Retro Diffusion animation sheets for Escape the Umbra. Use when Codex needs to use Retro Diffusion or retrodiffusion.ai via Chrome/Computer Use to create idle, death, combat, NPC, enemy, prop, or other animated raster sheets, then integrate them into Labyrinth assets, Godot metadata, tests, visual proof, and inspection fixtures.
---

# Create Labyrinth Retrodiffusion Animation

## Core Workflow

1. Use this with `$parallel-labyrinth-task` for substantive game/source/asset changes. Start or adopt an isolated task worktree before writing generated assets.
2. Read `AGENTS.md`, then pull focused memory before edits:
   ```bash
   memento brief assets/art data/enemies.json data/npcs.json scripts/combat_board_view.gd scripts/run_scene.gd tests/run_tests.gd
   ```
3. If the animation is for an enemy or NPC, also use `$create-labyrinth-enemy` or the relevant content skill for Labyrinth data, balance, tests, and visual proof expectations.
4. Audit the target's current art path and animation discovery path before opening Retro Diffusion. In Labyrinth, unit idle sheets are usually same-stem files such as `assets/art/enemies/cinder_ooze_idle.png` and are configured with JSON `idle_sheet_*` fields.
5. Use Chrome for Retro Diffusion when the task depends on the user's logged-in session. Use Computer Use only when Chrome tooling cannot reach the needed UI.

## Retro Diffusion Browser Flow

- Open or claim `https://retrodiffusion.ai/app` in the user's Chrome profile.
- Select **Advanced Animations** and the requested animation type, for example **Idle**. For death animations, choose the site's death-style option if available; otherwise use the closest animation mode and make the prompt explicit.
- Set the requested frame count before generating. The previous successful Labyrinth idle workflow used **16 frames**.
- Fill a short motion prompt that says what should move and what must not happen. Good pattern:
  `Seamless <animation type> loop: <subject> <specific motion>, while staying in place, no walking, no camera movement.`
- Upload the source transparent PNG through the visible upload dropzone. The label may be `Input Image * upload dropzone` before a file is attached and `Input Image upload dropzone` after replacement.
- Confirm with the user before any paid **Generate** click unless their current message already explicitly authorizes spending Retro Diffusion credits for the named batch.
- After generation, identify the sheet PNG, not only the animated GIF preview. For the 16-frame idle flow, the useful asset was a `1020x1020` PNG sheet plus a `255x255` GIF preview.
- Prefer Chrome `pageAssets` inventory to discover the generated sheet URL. Bundling through `pageAssets.bundle()` works but can be slow; once the browser reveals the exact generated CloudFront PNG URL, a direct `curl -L` download is acceptable with network permission.
- If Chrome file upload fails with `Not allowed`, tell the user to enable file URL access for the Codex Chrome Extension in `chrome://extensions` -> Details -> **Allow access to file URLs**, then retry.

## Import And Cleanup

Use `scripts/process_retrodiffusion_sheet.py` for every downloaded sheet:

```bash
python3 .codex/skills/create-labyrinth-retrodiffusion-animation/scripts/process_retrodiffusion_sheet.py \
  --input /private/tmp/generated_sheet.png \
  --output assets/art/enemies/example_idle.png \
  --columns 4 --rows 4 \
  --contact-sheet /private/tmp/example_idle_contact.png
```

The script validates dimensions, preserves the native sheet size, removes only exterior magenta/purple matte residue, writes the destination PNG, and creates a checkerboard contact sheet. Inspect the contact sheet before continuing.

When Retro Diffusion preserves a non-square source sprite's native dimensions, pass `--expected-cell-width` and `--expected-cell-height` instead of relying on the square `--expected-cell` default.

For the prior Retro Diffusion 16-frame idle sheets:

- output size: `1020x1020`
- grid: `4` columns by `4` rows
- frame size: `255x255`
- order: `row_major`
- ping-pong: `false`

Wire unit idle metadata in `data/enemies.json` or `data/npcs.json`:

```json
"idle_sheet_columns": 4,
"idle_sheet_rows": 4,
"idle_sheet_order": "row_major",
"idle_sheet_ping_pong": false
```

For non-idle animations such as death, inspect the current renderer first and add narrowly named metadata or presentation hooks that match the existing animation system. Do not overload `idle_sheet_*` fields for death behavior.

## Validation

- Check JSON after metadata edits:
  ```bash
  python3 -m json.tool data/enemies.json
  python3 -m json.tool data/npcs.json
  ```
- Add focused tests for the asset contract: file exists, sheet size/grid are correct, frame count matches metadata, and the renderer loads the frames.
- For generated unit sheets, verify silhouette shadows for every frame. The previous Retro Diffusion 255px frames exposed a shadow fallback bug when broad polygon simplification produced bounds but no drawable polygons.
- Run the full suite through the task wrapper:
  ```bash
  python3 tools/godot_task_runner.py --task-id <task-id> --timeout 300 --stream -- godot --headless --path . --script tests/run_tests.gd
  ```
- Produce visual proof: contact sheet over checkerboard, and a board/probe/fixture screenshot or playable inspection fixture showing the animation in context.
- Get mandatory peer-review signoff before calling the task done.

## Reference

Read `references/retro-diffusion-idle-import-case.md` when recreating the July 2026 idle-generation workflow, diagnosing Retro Diffusion browser quirks, or needing the exact original proof and pitfalls.
