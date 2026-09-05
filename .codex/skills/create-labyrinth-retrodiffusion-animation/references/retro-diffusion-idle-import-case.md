# Retro Diffusion Idle Import Case

This reference summarizes the archived implementation thread `019f2480-1301-7d91-b1cd-fbaa62d9c5fc` and reviewer thread `019f24d8-f819-7190-a58a-7455e914317f`.

## Request

The user asked Codex to use Retro Diffusion through Chrome/Computer Use to generate missing Labyrinth character idle animations. The final clarified settings were **Advanced Animations -> Idle -> 16 frames**, with explicit approval to spend Retro Diffusion credits.

Targets:

- enemies: `cinder_ooze`, `cinder_droplet`, `bile_bloomer`, `chainbound_gaoler`, `grave_surgeon`, `frostglass_lancer`
- NPCs: `arcanist`, `blacksmith`

## Browser Findings

- The app tab was already on Retro Diffusion Advanced Animations with Idle selected.
- Duration initially showed 8 frames; the user changed the requirement to 16 frames.
- The generate button showed about `$0.14` per generation during that run.
- Chrome upload initially failed with `Not allowed`; enabling **Allow access to file URLs** for the Codex Chrome Extension fixed it.
- The visible upload control label changed between `Input Image * upload dropzone` and `Input Image upload dropzone`.
- Each successful 16-frame idle generation exposed:
  - a `1020x1020` PNG sheet
  - a `255x255` GIF preview
- `pageAssets.bundle()` could download the selected PNG but took a very long time for the first sheet. Direct `curl -L` from the revealed CloudFront PNG URL was used for later sheets.
- A timeout during Grave Surgeon generation did not necessarily mean a usable result existed; the agent checked queue state, prompt text, recent images, and balance before retrying. The balance had not changed and the page still showed the previous result, so retrying was correct.

## Import Contract

The committed idle sheets were native `1020x1020` PNGs:

- 4 columns
- 4 rows
- 16 frames
- 255x255 frame cells
- row-major order
- non-ping-pong playback

Metadata fields used:

```json
"idle_sheet_columns": 4,
"idle_sheet_rows": 4,
"idle_sheet_order": "row_major",
"idle_sheet_ping_pong": false
```

The renderer discovers same-stem idle files beside the static art path, for example `assets/art/enemies/cinder_ooze.png` -> `assets/art/enemies/cinder_ooze_idle.png`.

## Matte Cleanup

Retro Diffusion attempted transparent backgrounds but left magenta/purple residue on some sheets. The successful cleanup removed only suspicious exterior matte pixels near transparency and preserved interior colors. Removal counts varied widely:

- Cinder Ooze: about 3.7k pixels
- Cinder Droplet: 4 pixels
- Bile Bloomer: about 5.9k pixels
- Chainbound Gaoler: about 16.8k pixels

The workflow created checkerboard contact sheets after heavier cleanup and visually inspected them before continuing.

## Proof And Follow-Up

Initial proof:

- JSON parse checks for `data/enemies.json` and `data/npcs.json`
- all eight sheets were `1020x1020`
- bright/magenta edge matte scan showed no remaining bright edge residue after cleanup
- contact sheet over checkerboard
- full Godot suite passed
- reviewer signoff
- inspection fixture opened a combat room showing the new animated final-art enemies

Follow-up issue:

- User saw shadow flicker between silhouette shadows and an old oval fallback.
- Cause: some Retro Diffusion 255px frames had opaque bounds, but broad silhouette polygon simplification produced no drawable polygons.
- Fix: `CombatBoardView` retries shadow extraction at a finer simplify epsilon before falling back to an oval.
- Additional proof: all 128 new idle frames reported drawable silhouette polygons, full Godot suite passed, reviewer signed off, and the inspection fixture was regenerated.

## Durable findings from this case

- `assets/art`: Retro Diffusion advanced idle sheets use native 4x4 cells.
- `scripts/combat_board_view.gd`: Unit shadow simplification can drop generated idle frames; keep the finer retry path before oval fallback.
