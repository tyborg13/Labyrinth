# Unit 2: character menu

Target: `mockups/character.jpg`. Today's screens: `baseline/character_gear.jpg`,
`baseline/character_magic.jpg`, `baseline/character_skills.jpg`.

The overlay is built in `scripts/run_scene.gd`:
- `_rebuild_progression_overlay`, `_build_progression_resource_summary` and
  `_build_character_overlay_tabs`;
- `_build_equipment_overlay_body` with the loadout, equipped-items and inventory
  columns;
- `_build_magic_overlay_body` with the attuned and inventory columns;
- `_build_skill_tree_overlay_body` and `scripts/skill_tree_view.gd`.

Move rebuilt presentation into `scripts/character_menu_view.gd` (or a few focused
helpers) rather than growing `run_scene.gd`. `run_scene.gd` keeps state and
actions.

**Interaction model is unchanged.** Keep all of these exactly as they are today:
- equipping and unequipping, slot selection and swap;
- attunement swaps (select attuned, then learned);
- item equip and unequip;
- unread/NEW markers;
- tab switching (pointer, keyboard, LB/RB);
- controller focus order and back/close;
- tooltips and card or equipment inspection;
- the combat-locked state;
- reduced motion.

This unit changes presentation only.

## Frame and header

- **Panel:** keep the panel size and placement. Use the shared ink glass with
  the gilded hairline and bold corner brackets (`UiGildedFrame` major-dialog
  treatment). Add a subtle warm radial lift behind the paper doll.
- **Title:**
  - An eyebrow `THE REAVER · LEVEL N` (letter-spaced, `TEXT_2`) above the
    title `Character` (display, about 46 px, `GOLD_BRIGHT`).
  - The level moves from its own chip into this eyebrow.
- **Stats** (top right), as unit 0 stat chips in one style:
  - Skill points: value `GOLD_BRIGHT`.
  - Moltshards: value soft violet (`UMBRA` lightened).
  - Defiance `0/0 · next 4`: value `GOLD_BRIGHT`.
  - Each uses its existing icon. Keep every existing value and string, and the
    unread/attention state if a stat has one.
- **Close:** a round ✕ socket (unit 0 socket, 40 px) instead of the square X.

## Tabs

- **Style:** bookmark tabs attached to a full-width gold hairline under them.
- **Active tab:** a raised ink plate with a 1 px gold edge (no bottom edge), a
  `GOLD_BRIGHT` label (UI 21), and a 2 px `EMBER` underline glow.
- **Inactive tabs:** bare `TEXT_2` labels with a hover brighten.
- **Badges:** keep the unread count badges.

## Gear tab: three columns

1. **Equipped (about 420 px).**
   - **Header:** section header `EQUIPPED`.
   - **Paper doll:**
     - The existing loadout hero preview, enlarged to about 260 px tall, on a
       unit 0 ink pool stage.
     - Five 62 px sockets arranged around the hero, each with its slot caption
       underneath (UI 13, letter-spaced, `TEXT_3`):
       - Trinket top centre.
       - Weapon left upper, Armor left lower.
       - Offhand right upper, Boots right lower.
     - Sockets keep today's slot buttons' behaviour (select, inspect, focus).
       Empty slots use the socket empty state.
   - **Items:**
     - Below the doll: section header `ITEMS` with `1 / 2`, then one row per
       item slot.
     - Each row: a 46 px socket, a type eyebrow and the name (UI 18).
     - Empty slots: a dashed row with muted copy.
2. **Pack (about 400 px).**
   - **Header:** section header `PACK` with `N gear · M items`.
   - **Rows:** inventory entries as rows like the item rows: socket, a
     `Weapon · Common` eyebrow, the name, and the granted cards' names as one
     muted line.
   - **Selected row:** gold border and soft ember glow, with its existing
     actions (Equip, Inspect, …) as compact secondary buttons inside the row.
   - **Empty states:** muted centred copy, using the existing strings.
3. **Deck (remaining width, about 500 px).**
   - **Header:** section header `DECK` with `N cards`.
   - **Groups:** in today's order (attuned magic, items, then one per
     equipment source). Each group header is an eyebrow plus the source name
     in `TEXT` (e.g. `WEAPON  Iron Cleaver`).
   - **Cards:** under each header, a 2-column grid of card strips (unit 0) with
     ×N counts. Keep hover/click card inspection.

## Magic tab

- **Attuned (left):**
  - Section header `ATTUNED MAGIC` with `6 / 6`.
  - One card strip per slot, 34 px tall.
  - The selected slot uses the strip's selected state; empty slots use a
    dashed strip.
- **Learned (middle):**
  - Section header `LEARNED MAGIC` with its count.
  - A card-strip list.
  - The swap-target highlight uses the hover/focus state; locked entries use
    the locked state.
- **Deck (right):** the same deck column as the Gear tab.

## Skills tab

- **Keep** the tree layout and logic.
- **Styling only:**
  - The legend becomes four small chips in eyebrow style.
  - The detail panel uses ink glass with a section header.
  - The `No Skill Points` / learn button uses the primary plate when learning
    is possible and the quiet plate otherwise.
  - Connector lines become 2 px `GOLD_DIM` with rounded joins; available paths
    use teal and learned paths gold.
- **Out of scope:** don't re-route the tree.

## Proof

- **Probes:** update `tests/character_menu_polish_probe.gd` and
  `tests/loadout_material_polish_probe.gd`, and add states where missing.
- **States to capture:**
  - Gear idle;
  - a selected pack item;
  - a selected equipped slot;
  - items full and empty;
  - Magic idle;
  - a magic swap selected;
  - Skills with points available and with none;
  - controller focus on a socket;
  - the combat-locked menu;
  - reduced motion.
- **Screenshots:** save fresh 1920×1080 screenshots.
- **Tests:** keep all character, loadout and progression tests green.
