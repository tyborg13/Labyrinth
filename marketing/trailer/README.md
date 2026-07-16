# Escape the Umbra — Steam gameplay trailer

This folder contains the editable Remotion project and deterministic gameplay captures for the first Steam store trailer for **Escape the Umbra**.

The 47.5-second cut is intentionally gameplay-first after a short setting hook. Its sequence is:

1. The prison and the objective: the only way out is deeper.
2. Route choice and room commitment.
3. Pre-battle threat and loadout inspection.
4. Forced movement into an environmental fire trap.
5. A Lightning-3 Thunderline multi-kill.
6. Lantern Shot revealing enemies in the Heart Umbra.
7. Card reward and run-building loop.
8. The current title, the shadow dragon objective, and a Steam wishlist call to action.

The shadow-dragon illustration is existing main-menu key art and is used only for the narrative opening/end card. It is not presented as captured gameplay.

## Render

Node.js 26+ and npm are required.

```sh
cd marketing/trailer
npm install
npm run lint
npm run render
```

The Steam master is written to:

```text
marketing/trailer/out/escape-the-umbra-steam-trailer.mp4
```

The render command produces 1920x1080, 30 fps, H.264 video with 48 kHz stereo AAC audio. The checked master is 47.533 seconds at roughly 10.8 Mbps total bitrate.

## Refresh gameplay footage

Run the capture script from the repository root inside an adopted Labyrinth task worktree:

```sh
marketing/trailer/scripts/capture-footage.sh
```

It invokes the production Godot scene through the parallel-safe task runner, renders each clip at 1920x1080/30 fps, and transcodes the Movie Maker intermediates to H.264 edit clips in `public/footage/`.

Available deterministic captures are `route`, `prebattle`, `trap_combo`, `aoe`, `umbra`, and `reward`. The tactical clips use production `CombatEngine` transitions and `RunScene` board animation rather than simulated compositing.

Set `LABYRINTH_TASK_ID` if the worktree uses a different task id:

```sh
LABYRINTH_TASK_ID=my-task-id marketing/trailer/scripts/capture-footage.sh
```

## Edit notes

- Composition id: `EscapeTheUmbraTrailer`
- Source: `src/Trailer.tsx`
- Output duration: 1426 frames at 30 fps
- Fonts, music, sound effects, and key art are linked from the game repository through `public/game-fonts` and `public/game-assets`.
- The old teaser is not an editorial or visual reference for this cut.
