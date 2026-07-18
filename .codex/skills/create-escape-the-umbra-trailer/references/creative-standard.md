# Creative Standard

## Brand Truth

- Call the game **Escape the Umbra**. Treat **Labyrinth of Ash** as a retired working title.
- Present a prison labyrinth whose only path to escape runs deeper into the shadow.
- Treat the shadow dragon as the eventual goal, not current playable footage. Existing main-menu dragon art may establish the narrative threat if it is not labeled or framed as gameplay.
- Do not use the old teaser as a creative, editorial, pacing, typography, or footage reference.

## Trailer Promise

Make the audience understand this loop without explanatory taglines:

1. Plan a descent through a dangerous generated route.
2. Read a populated tactical room and the threats within it.
3. Play cards through their natural hand, targeting, center-stage, and resolution flow.
4. Build large turns from positioning, terrain, traps, elements, combos, and complete multi-kills.
5. Claim meaningful rewards and reshape the run through merchants, relics, magic, and equipment.
6. Go deeper into the Umbra in pursuit of escape.

Prioritize legibility over the number of features. A first-time viewer should be able to name what changed after each shot.

## Gameplay Authenticity

- Use legal production state from the current build.
- Use engine-generated non-start rooms with walls, doors, terrain, props, moss, loot, and enemies. Empty grids make the game look unfinished.
- Use realistic deeper-run health, level, inventory, rarity mix, route history, and available choices.
- Let editing heighten a real event; never short-circuit the event to make capture easier.
- Verify the current visual quality of every showcased card. Exclude placeholder-looking effects even when the underlying mechanic is strong.
- Make environmental and AOE showcase results decisive. If the shot promises a perfect multi-kill, every intended visible target must die.
- Make light mechanics spatially truthful: the light source must land in darkness and visibly clear the corresponding Umbra area.

## Card-First Storytelling

Cards are the game's primary verb. Give them screen time.

- Establish the relevant card in the hand before it is played.
- Preserve the production animation that carries the card to center stage.
- Make the card readable at center without covering it with trailer text.
- Shift focus to the board only as the effect begins resolving.
- Hold long enough to read the outcome, not merely the particles.

Do not show a board effect that appears to trigger on its own.

## Progression Storytelling

Build progression beats from one plausible deeper run:

- buy through a real merchant interface;
- claim a relic from a complete, readable set of choices;
- learn a spell from a legal post-combat reward;
- open the Magic menu and attune the newly learned spell;
- acquire equipment through its real reward path;
- open the character menu and equip it among multiple unequipped items and mixed-rarity gear.

Show each interaction just long enough to understand the choice and result. Do not return to the starting room between beats.

## Typography And Copy

- Use the readable game-native Labyrinth Crumble face for promotional copy.
- Pre-render finite title copy with `marketing/trailer/scripts/render-title-cards.py`; do not rely on runtime FontFace loading.
- Bring title text in with its gaps filled. After it settles, let the small fill pieces fall away to reveal the native Crumble texture. Do not crumble the title into existence.
- Use large, terse, action-oriented lines. Avoid secondary taglines and generic glowing UI panels, pills, frames, counters, or techno labels.
- Give each narrative card enough time to read at normal speed. In the current cut, “Will you let the shadow consume you?” needs a generous hold, and “Or will you...” needs an even more deliberate pause before the title.

## Steam Call To Action

- Set the final phrase as a single visual sentence: `WISHLIST ON [STEAM LOGO]`.
- Place the Steam mark immediately beside `WISHLIST ON`, aligned as the final word rather than a separate badge.
- Use the approved transparent inverse-white Steam artwork without a blue square, distortion, effects, or collision with the game logo.
- Preserve the source and attribution in `marketing/trailer/public/branding/README.md`.
- Make the CTA large enough to dominate the end card while preserving Steam clear space.
