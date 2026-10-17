# boon-01 feedback 1 — director decisions for every TODO_DESIGN + offer screen layout

The windowed proof ran (7 captures). The rules work. The offer screen needs the layout below. Reference captures:
`/Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/baseline/run_reward.png` (post-combat reward
screen, the template) and your own `heirloom_prompt.png` (the NPC dialogue box, which is right as is).

## Decisions
1. `TODO_DESIGN_ARMORY_UNCOMMON_EQUIPMENT`: equipment tiers are common/rare/epic/legendary. Armory gives a random
   **rare** piece for a random slot whose starter you have, replacing that starter. Set `"rarity": "rare"` and make
   Armory eligible in production rolls. The text stays `<Item> replaces your <starter piece>.` Re-run the power
   comparison for Armory and report it.
2. `TODO_DESIGN_VITALITY_CURRENT_HP`: +6 max HP **and** +6 current HP (you start the run at full).
3. `TODO_DESIGN_HEIRLOOM_RESUME_LABEL`: `CHOOSING AN HEIRLOOM` (it joins `SAVED_RUN_MODE_LABELS` in the same style).
4. `TODO_DESIGN_BOON_SECONDARY_BACK_LABEL`: `Back`, the label the Graftwright picker already uses.
5. `TODO_DESIGN_BOON_MODAL_GEOMETRY`: below. Remove every TODO_DESIGN key from `data/opening_boons.json`.

## Offer screen (1920x1080, 100% UI scale)
- Drop the single framed panel that holds all three columns. The screen has three parts: the cards, a skip pill and
  the NPC dialogue box.
- **NPC dialogue box.** It is the run's existing dialogue box with exactly the geometry and skin of `heirloom_prompt.png`
  (x 323–1559, y 842–1059): portrait, `EMACIATED MAN`, and the line `You'll want something in your hands down there.
  Choose.` It has no buttons while the offer shows. "Good. Go on." and "Then go with nothing." follow in the same box,
  as now.
- **Room header.** Hide the room title header ("Choose Door") while the overlay is open. It currently shows through
  under the input hint bar. The hint bar stays.
- **Boon cards.** Three cards, each 300 x 400, gap 56, so the row spans x 454–1466, at y 210–610.
  - Skin: the reward card frame family. If no reward-frame variant fits a non-spell card, use the current panel
    surface skin with its existing gold focus frame.
  - Focus and hover: the reward cards' existing highlight and lift.
  - Column tag: `BUILD SEED`, `SHAPING` or `BARGAIN` in a small pill centred on the card's top border (the same pill
    style as the reward cards' `NEW` tag), 16 px small caps. The tag replaces the old column headings.
  - Title: centred, top at y+40, the card-title role (the font and size of "Quick Stab" on reward cards).
  - Preview zone: y+96 to y+236 (140 px), centred:
    - Heirloom, Armory: the item socket (96 px) with the item name under it, as now.
    - Trinket, Pawned Light: the relic socket (96 px) with the relic name under it.
    - Elemental Gift, Blood Price, Focus: the existing card strip listing the offered spells (the 3, 5 or 4 rolled
      spells), with the full-card hover preview beside the card, as now.
    - Vitality: the `health` keyword glyph at 64 px, with `+6` beside it in the card stat numerals (the style of
      the "6" on reward cards).
    - Debt: the `ember` keyword glyph at 64 px with `+120`, styled the same way.
    - Purge: nothing. Its rules text centres vertically in the card instead.
  - Rules text: centred alignment, from y+256, width 252 (24 px side padding), body role, at most 4 lines. Nothing
    may touch the frame. The current captures run text into the left border.
- **Skip pill.** `Take nothing` is a pill button centred under the cards (top y 650), in the exact style and height
  of the reward screen's `SKIP & RECOVER` pill, without an icon. It replaces the plain text line on the frame
  border.
- **Input.** Keyboard and controller focus moves left/right across the cards, and down reaches the pill. A/Enter
  takes the focused option. B/Esc does nothing on the offer step, because the choice must be made or explicitly
  declined.

## Secondary step (Elemental Gift, Blood Price, Purge)
- The cards and pill are replaced by a reward-screen row. The dialogue box stays, with the same line.
- Top: the reward screen's banner, at the same position and size, showing the boon name in caps (`ELEMENTAL GIFT`,
  `BLOOD PRICE`, `PURGE`). Under it, the boon's rules text as one centred body line at y 205.
- Cards: full spell cards at reward-screen size, centred, with a gap of 58 for 3 cards and 24 for 4–6 cards, top at
  the reward screen's card top. Hover shows the full tooltip stack, as on the reward screen.
- `Back`: a pill in the same position and style as `Take nothing`. B/Esc does the same. Both return to the offer
  step without spending the choice.
- Purge:
  - Clicking a starter card selects it: it lifts 20 px and takes the focus frame. Clicking a selected card
    deselects it.
  - On the second selection, open the existing `magic_purge_confirmation` dialog listing both spells. Confirm
    removes them. Cancel clears both selections.
  - Each copy of a duplicate starter is its own card.

## Proof
- Re-run the windowed probe and add these captures:
  - `offer_all_previews`: a seed whose three offers are a spell-strip boon, an object boon and a glyph boon
  - `purge_two_selected`, before the confirmation opens
  - `blood_price_five_cards`
- Keep the existing captures.
- Update the probe contract for the new node names and geometry, with 1 px tolerances.
- Re-run the focused boon tests, then the full Godot and Python suites.
