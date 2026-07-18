# Production Capture Workflow

## Source Of Truth

Use:

- `tools/steam_trailer_capture.gd` for deterministic game state and production interactions;
- `marketing/trailer/scripts/capture-footage.sh` for task-safe Godot Movie Maker capture, trimming, and H.264 transcode;
- `marketing/trailer/public/footage/` for committed edit sources;
- `marketing/trailer/README.md` for current clip ids and render commands.

Do not construct gameplay screens with React, image generation, or hand-positioned game assets.

## Existing Capture Set

The established capture ids are:

- `route`
- `prebattle`
- `trap_combo`
- `aoe`
- `umbra`
- `merchant`
- `relic`
- `spell`
- `magic_equip`
- `equipment`

Recapture only the affected ids after a focused edit request. Add a new id only when the required production state cannot be expressed cleanly by an existing capture.

## Legal Run State

- Seed deterministic state, but make it look like a run a player could actually reach.
- Use a generated non-start room for every gameplay beat.
- Preserve walls, doors, props, terrain, moss, loot, and populated encounters.
- For route footage, produce a connected cleared path and legal next-room choices. Make unchosen rooms plausible for their depth and branch.
- For progression, use a deeper character with believable level, resources, mixed-rarity equipment, learned magic, reserve magic, and multiple inventory choices.
- Use production purchase, claim, drag, swap, equip, and deck-rebuild handlers. Avoid writing the final state directly when the trailer is supposed to show the interaction.

## Card Capture Contract

1. Put the real card in the visible production hand.
2. Select it through the same handler as normal play.
3. Supply legal production targeting.
4. Preserve the center-stage card animation.
5. Let the engine discard and resolve the card normally.
6. Assert the expected tactical outcome in the capture script.

For environmental or AOE showcases, assert the specific targets killed and any terrain or trap state that made the turn possible. For Umbra footage, assert the light source location and the before/after visibility change.

## Deferred UI And Starting-Room Safety

`RunScene` and its `CanvasLayer` overlays may draw stale or incomplete frames after a state change appears complete.

- Keep the production scene hidden while preparing the requested UI.
- Wait for the deferred interface to reach the intended state.
- Physically trim the Movie Maker source after the measured safe frame; opacity or a later overlay is not enough.
- Inspect a dense contact sheet of the first second of every recaptured source.
- Inspect the encoded source at frame zero.
- Reject any frame showing the starting room, an underlying unrelated room, a half-built overlay, or empty UI.

The route and prebattle raw trims are implementation details in `capture-footage.sh`; measure them again when the underlying UI timing changes.

## Full Reward UI

Reward options live in CanvasLayers, so scaling the parent `Control` does not move those pixels.

- Mount the production `RunScene` inside a larger 16:9 `SubViewport` when full choice panels do not fit.
- Reposition the production choice host before it becomes visible.
- Assert a bottom safety margin for the complete selected control, including descriptions, card tips, and borders.
- Downsample the complete viewport to 1920x1080.
- Inspect the raw encoded frame before adding any Remotion crop or zoom.

If pixels are absent from the source, recapture them. Do not attempt to reveal them with a later camera transform.

## Parallel-Safe Capture

Run from the adopted task worktree:

```bash
marketing/trailer/scripts/capture-footage.sh <clip-id>...
```

Set the current task id when needed:

```bash
LABYRINTH_TASK_ID=<task-id> marketing/trailer/scripts/capture-footage.sh <clip-id>...
```

Use the repository wrapper rather than invoking Godot capture directly. Confirm the transcode completed and inspect the resulting `public/footage/<clip-id>.mp4` before opening Remotion.

## Source Proof

For every changed capture, retain uniquely named proof outside the committed source tree:

- an ffprobe summary;
- full-resolution frames before, during, and after the action;
- a dense contact sheet for the first second;
- a dense contact sheet across the complete action;
- explicit evidence for legal state and expected outcome assertions.

Do not treat a composed trailer frame as proof that the underlying source is complete.
