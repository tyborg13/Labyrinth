# Escape the Umbra — Steam gameplay trailer

This folder contains the editable Remotion project and deterministic gameplay captures for the first Steam store trailer for **Escape the Umbra**.

The current cut is intentionally gameplay-first after a short setting hook. Its sequence is:

1. The prison and the objective: the only way out is deeper.
2. A deeper, engine-generated route with cleared history and legal next-room choices.
3. Pre-battle threat and loadout inspection.
4. A real Cleaver Hook card play forcing three enemies into an environmental fire-trap kill.
5. A real Wildfire Halo card play landing a complete three-enemy AOE kill.
6. A real Lantern Shot card play revealing enemies in the current-build Fringe Umbra.
7. A run-building montage from a deeper run: buying from a Blacksmith, claiming a treasure-room relic, learning generated post-combat magic, attuning that new spell in the production Magic menu, and collecting then equipping a real combat drop among mixed-rarity loadouts.
8. The choice to resist the shadow, the current title, and a compact "Wishlist on [Steam]" call to action.

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

The render command produces 1920x1080, 30 fps, H.264 video with 48 kHz stereo AAC audio. The checked master is approximately 57.5 seconds.

The production render intentionally uses one deterministic Chromium worker. Trailer text is committed as transparent title artwork generated from the exact game font, avoiding Chromium's unreliable runtime loading of this custom TTF during long renders. Each card also has a generated `-fill.png` layer: the title arrives with its small Crumble gaps filled, settles, and then sheds those pieces downward to reveal the native face.

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

Available deterministic captures are `route`, `prebattle`, `trap_combo`, `aoe`, `umbra`, `merchant`, `relic`, `spell`, `magic_equip`, and `equipment`. The tactical and progression clips use production `RunEngine`, `CombatEngine`, and `RunScene` transitions rather than simulated compositing. Tactical clips preserve engine-generated non-start room layouts—including walls, doors, moss, terrain, and loot—and play their visible hand cards through the same select, target, center-stage card, discard, and resolution path as normal gameplay. Progression captures seed a plausible level-seven run, then use generated depth-five rooms and the production purchase, reward, drag, and equip paths. Relic and learned-magic captures render the real `RunScene` in a larger 16:9 reward viewport, position its production choice host before it becomes visible, assert that the selected control clears a bottom safety margin, and downsample the complete screen to 1080p. The capture scene remains hidden until the requested run state is loaded, and the transcode physically strips capture pre-roll so frame zero can never expose the starting room. Pass one or more clip ids to refresh only those captures, for example `marketing/trailer/scripts/capture-footage.sh route prebattle merchant relic magic_equip`.

Set `LABYRINTH_TASK_ID` if the worktree uses a different task id:

```sh
LABYRINTH_TASK_ID=my-task-id marketing/trailer/scripts/capture-footage.sh
```

## Edit notes

- Composition id: `EscapeTheUmbraTrailer`
- Source: `src/Trailer.tsx`
- Output duration: 1724 frames at 30 fps
- Promo typography in `public/title-cards/` is generated from the game's readable Labyrinth Crumble font; music, sound effects, and key art are linked through `public/game-assets`.
- Promo copy uses that single game-native face at large sizes with no pixel-font labels, UI cards, frame counters, or secondary gameplay taglines.
- Tactical shots visibly establish the hand card, zoom into its production center-stage play animation, then pan focus to the board resolution with impact zoom, brightness accents, and deterministic screen shake.
- The `GROW STRONGER` montage crossfades among five legal non-start run states. Merchant, relic, and magic-reward beats use a single eased approach, a held choice view, a restrained selection impact, and one eased pullback; their source playback is slightly slowed so the lower options remain readable. The following menu cameras use one subtle zoom and one continuous action-led follow from the newly acquired spell or item toward its equipped destination, then gently pull back.
- Progression clips are muted in the edit, so item and spell acquisitions do not trigger the old repeated collection sound; the score and tactical combat impacts remain.
- The final CTA uses a transparent inverse-white derivative of Valve's approved Steam® logo artwork with clear space and no colored tile or compositing into the game mark. Preserve the legal attribution in `public/branding/README.md` when preparing distribution copy.
- The old teaser is not an editorial or visual reference for this cut.
