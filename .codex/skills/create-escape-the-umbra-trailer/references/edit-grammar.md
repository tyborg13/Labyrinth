# Edit Grammar

## Camera Principle

Give the camera one job at a time: keep the current gameplay decision or result near the visual center. Move only when the focus moves.

- Use `useCurrentFrame()`, `interpolate()`, and `spring()` for deterministic motion.
- Use one easing curve for one semantic phase.
- Avoid CSS animations and transitions.
- Avoid independently eased multi-waypoint tracks; they visibly stop, restart, and change direction.
- Avoid unseeded randomness. Tie deterministic shake to a short impact envelope.
- Use `premountFor` on sequences with video or other loading-sensitive content.

## Tactical Card Shot

Use this sequence:

1. **Establish:** frame the hand and let the relevant card become identifiable.
2. **Commit:** preserve the production move into the center-stage play area.
3. **Read:** zoom subtly enough to make the centered card prominent.
4. **Resolve:** begin a smooth pan or focus shift toward the real board target as the card resolves.
5. **Impact:** add restrained scale, brightness, and deterministic shake at the actual hit or kill.
6. **Result:** hold the changed board long enough to count kills or understand the environmental interaction.

Do not begin the pan before the audience has seen the card. Do not shake during targeting or navigation.

## Merchant, Relic, And Magic Choices

Use four continuous phases:

1. approach the complete option area with one eased pan and zoom;
2. hold the choices without drifting for roughly 0.8–1.2 seconds or as readability requires;
3. add one small selection-timed shake, scale, or brightness accent;
4. pull back once after the result is visible.

Center on the actual lower-screen options. Keep every relevant title, description, card tip, and border visible. Remove vignette or shading that reduces choice readability.

## Magic And Equipment Swaps

Use an action-led follow instead of a tour of the menu:

1. hold or apply a restrained approach zoom once the menu is stable;
2. center the newly acquired item or spell at its source;
3. interpolate the focus continuously toward the destination during the real drag or swap;
4. hold the equipped result;
5. pull back once.

Keep scale changes small. Do not visit unrelated panels, reverse direction, or add selection shake unless the real landing needs a subtle accent. Align follow timing to full-resolution source frames rather than guessing from the composition timeline.

## Map Shot

- Frame the active traversal rooms and connecting path, even when they sit near a screen edge.
- Pan or change transform origin toward the traversed rooms before zooming.
- Keep the cleared route and legal unchosen branches readable.
- Hold only long enough to read the promotional line and understand the descent; do not linger on a static map.

## Promotional Text

- Use generated transparent title art from `marketing/trailer/public/title-cards/`.
- Bring the complete filled letterforms in cleanly.
- After the line settles, animate only the small fill pieces downward to expose the Crumble gaps.
- Use the native Crumble face as the final state.
- Keep text large, centered, and concise. Avoid generic UI containers and subordinate taglines.
- Measure narrative holds at normal playback speed, not while scrubbing.

## Transitions

- Prefer a motivated cut or clean crossfade between complete scenes.
- Trim source clips so the outgoing scene remains valid until the transition begins and the incoming scene is valid from its first contributing frame.
- Never use an unrelated room as a transition buffer.
- Inspect every boundary frame-by-frame. A two-frame starting-room flash is still a failure.
- Do not leave a static tail after the meaningful action unless it is an intentional reading hold.

## Pacing

Alternate tension, action, and comprehension. Let each shot answer one question before moving on.

- Spend time before a choice so options can be read.
- Spend time after an impact so the result can be understood.
- Avoid stacking camera travel, text animation, card movement, and a major hit at the same instant.
- If a viewer familiar with the game cannot parse a beat at normal speed, slow or simplify it.

## Audio

- Preserve score continuity across the montage.
- Use tactical impacts sparingly and synchronize them to real resolution frames.
- Keep acquisition and menu-navigation clips muted when their repeated collection sounds fight the score.
- Audit transitions for clicks, abrupt music edits, unintended source audio, and excessive peaks.
