# boon-01 feedback 2 — director windowed review of round 1

The offer screen is right: separate cards with tags, the Take nothing pill and the NPC dialogue box. Keep it. The
captures from my windowed run are in `output/boon-01/director_r1/`. Fix the following:

1. **Relic boon text repeats the name.**
   - Trinket currently reads "Reinforced Shield." under the socket that already shows the name. The rules line must
     be the relic's own effect text (its existing description, keywords included).
   - Pawned Light: the relic's effect text, then `Start at half HP.` with the HP keyword as now. It currently reads
     "Quarry Signet. Start at half HP."
   - Armory and Heirloom are unchanged.
2. **The tooltip stack appears at open and covers the screen.**
   - On the secondary step (Elemental Gift, Blood Price, Purge), the first card's full tooltip stack shows as soon as
     the step opens. It covers the banner, the rules line and the next card.
   - Match the reward screen: no tooltip stack at open. It shows only on pointer hover, or after the player moves
     focus with the keyboard or controller.
   - When it shows, clamp its top to ≥ (rules line bottom + 8 px). It never overlaps the banner or the rules line.
3. **The rules line collides with the cards.** The `Lose 5 max HP. Choose 1 of 5 rare spells.` line at y 205 overlaps
   the card tops and cost medallions. Move the secondary card row so the top of the cost medallion sits at y ≥ 245,
   with ≥ 16 px of clearance below the rules line. Keep the Back pill where it is.
4. **The Purge selection is too subtle.** A selected card keeps the 20 px lift, and its tag pill changes from `OWNED` to
   `REMOVE`, drawn in the warning colour token. Deselecting restores `OWNED`.
5. Re-run the windowed probe contract with these geometry changes, at 1 px tolerances. Add a capture
   `secondary_open_no_tooltip.png`, taken right after Blood Price opens with no input.
6. The full suite took 884.5 s against a 900 s budget. Don't add runtime to the suite. If your new tests are slow,
   move their heavy parts into the focused boon suite, and report the full-suite time.
