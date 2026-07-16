# Escape the Umbra — Steam gameplay trailer

This folder contains the editable Remotion project and deterministic gameplay captures for the first Steam store trailer for **Escape the Umbra**.

The tightened third cut is intentionally gameplay-first after a short setting hook. Its sequence is:

1. The prison and the objective: the only way out is deeper.
2. A deeper, engine-generated route with cleared history and legal next-room choices.
3. Pre-battle threat and loadout inspection.
4. Forced movement into an environmental fire trap.
5. A Lightning-3 Thunderline multi-kill.
6. Lantern Shot revealing enemies in the Heart Umbra.
7. A compact run-building montage: buying from an Arcanist, claiming a treasure-room relic, learning generated post-combat magic, and collecting then equipping a real combat drop.
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

The render command produces 1920x1080, 30 fps, H.264 video with 48 kHz stereo AAC audio. The checked master is 39.5 seconds at roughly 12.8 Mbps total bitrate.

The production render intentionally uses one deterministic Chromium worker. Trailer text is committed as transparent title artwork generated from the exact game font, avoiding Chromium's unreliable runtime loading of this custom TTF during long renders.

Regenerate that title artwork after changing the copy, size, color, or source font:

```sh
python3 scripts/render-title-cards.py
```

## Refresh gameplay footage

Run the capture script from the repository root inside an adopted Labyrinth task worktree:

```sh
marketing/trailer/scripts/capture-footage.sh
```

It invokes the production Godot scene through the parallel-safe task runner, renders each clip at 1920x1080/30 fps, and transcodes the Movie Maker intermediates to H.264 edit clips in `public/footage/`.

Available deterministic captures are `route`, `prebattle`, `trap_combo`, `aoe`, `umbra`, `merchant`, `relic`, `spell`, and `equipment`. The tactical and progression clips use production `RunEngine`, `CombatEngine`, and `RunScene` transitions rather than simulated compositing. The capture scene remains hidden until the requested run state is loaded, and the transcode physically strips capture pre-roll so frame zero can never expose the starting room. Pass one or more clip ids to refresh only those captures, for example `marketing/trailer/scripts/capture-footage.sh route prebattle merchant relic`.

Set `LABYRINTH_TASK_ID` if the worktree uses a different task id:

```sh
LABYRINTH_TASK_ID=my-task-id marketing/trailer/scripts/capture-footage.sh
```

## Edit notes

- Composition id: `EscapeTheUmbraTrailer`
- Source: `src/Trailer.tsx`
- Output duration: 1185 frames at 30 fps
- Promo typography in `public/title-cards/` is generated from the game's readable Labyrinth Crumble font; music, sound effects, and key art are linked through `public/game-assets`.
- Promo copy uses that single game-native face at large sizes with no pixel-font labels, UI cards, frame counters, or secondary gameplay taglines.
- Tactical shots use impact-focused zoom, brightness accents, and deterministic screen shake in the Remotion composition.
- The `GROW STRONGER` montage crossfades among four legal non-start run states, accelerates only the playback timing, and leaves each production acquisition/equip animation intact.
- The final CTA uses a transparent inverse-white derivative of Valve's approved Steam® logo artwork with clear space and no colored tile or compositing into the game mark. Preserve the legal attribution in `public/branding/README.md` when preparing distribution copy.
- The old teaser is not an editorial or visual reference for this cut.
