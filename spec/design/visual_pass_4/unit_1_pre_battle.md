# Unit 1: pre-battle scouting report

Target: `mockups/prebattle.jpg`. Today's screen: `baseline/pre_battle_01_foes.jpg`,
`baseline/pre_battle_06_boss.jpg`, `baseline/pre_battle_known_moves.jpg`.

The pre-battle overlay is built in `scripts/run_scene.gd`
(`_build_pre_battle_overlay`, `_rebuild_pre_battle_overlay`, `_build_pre_battle_*`).
Move the rebuilt layout into a new `scripts/pre_battle_view.gd` helper (per
`spec/development_workflow.md`, don't keep growing `run_scene.gd`). `run_scene.gd`
keeps ownership of state, signals, input and the entry animation, and calls the
helper to build the content. Preserve every existing node name that tests or
focus logic look up; where a name must change, update the tests in the same
change.

## Keep

- **Frame and scrim:** the ornate skull frame (`pre_battle_frame_v8.png`), its
  outer size and placement, the scrim, and the entry animation (including
  reduced motion).
- **Behaviour:**
  - all buttons (Position N/M when present, Equip, Start) and their hover, focus
    and controller behaviour;
  - foe inspection (the known-moves modal);
  - equipment and card hover/click inspection;
  - the Grimoire notice;
  - analytics.
- **Content:** all text content and rules text.

## Change

### Header (content top to about y 330 on screen)

- **Eyebrow:**
  - Centred, letter-spaced UI caps 15 px `TEXT_2`: `DEPTH 3`, a small `GOLD_DIM`
    diamond, then the Umbra tier in `UMBRA` (e.g. `FRINGE UMBRA`).
  - When there is no Umbra tier, show only the depth.
- **Title:**
  - Centred, display font about 58 px, `GOLD_BRIGHT`, with a 3 px black drop
    shadow and a faint warm glow.
  - It replaces the teal accent title. Elemental rooms keep gold for the title
    and use their element accent only on the eyebrow diamond.
- **Objective:**
  - One centred plate under the title, flanked by gilded rules that fade out to
    the left and right.
  - The plate: oxblood ink gradient, 1 px `DANGER` border at 55 %, 2 px radius.
  - Contents: the existing objective icon (22 px), the eyebrow `OBJECTIVE`
    (letter-spaced, a muted rose), then the objective description (UI 19, `TEXT`).
  - Boss and guardian objectives show the boss name exactly as today.
  - The objective title (`DEFEAT ALL ENEMIES`) becomes the eyebrow plus the
    description; keep both strings available to tests.
- **Buttons:** remove them from the header (see Actions).

### Body: two columns separated by a vertical 1 px gold rule (fades at both ends)

**Left: Foes stage (about 660 px wide).**

- **Header:** a section header `FOES` with the count.
- **Layout:**
  - 1–3 foes: one row.
  - 4–6 foes: two rows; the second row is centred.
- **Each foe** is a column about 206 px wide:
  - **Stage:** an ink pool stage (unit 0) under a sprite drawn at about 220 px
    (1–3 foes) or about 150 px (4+ foes), with nearest filtering.
  - **HP badge:**
    - A pill at the sprite's top-right: oxblood gradient, 1 px `DANGER` border,
      a small heart and the HP number in UI 17.
    - Use the existing heart icon if the probe shows it reads; otherwise draw a
      heart glyph.
  - **Name:** below the sprite, UI 19 `TEXT`, centred; it may wrap to 2 lines.
  - **Move tags:**
    - Below the name, on one centred line where possible.
    - Each tag is the existing intent icon (18 px) plus its word (UI 14,
      `TEXT_2`), with no boxes. Keep the existing tag choice and the "+N"
      overflow behaviour.
- **Leader:** a boss or leader foe sits in the centre slot, about 15 % larger,
  with a small `LEADER` eyebrow above the HP badge.
- **Hint:** under the foes, a muted eyebrow hint (`TEXT_3`, 13 px): "Hover or
  select a foe to read its moves". Show it only for pointer input; controller
  users get the existing prompt glyph flow.

**Right: Your Kit (about 404 px wide).**

- **Header:** a section header `YOUR KIT`.
- **Health row:**
  - The player head portrait (`assets/art/portraits/player_reaver.png`, 56 px)
    in a slanted window like the initiative rail.
  - "Health" in UI 17 and the value in UI 19, ally teal.
  - A 12 px teal health bar.
  - If Defiance exists, show it as a small stat value right-aligned on the
    same row (e.g. defiance icon + `0/1`).
- **Gear row:** the `GEAR` eyebrow, then 5 sockets (unit 0, 50 px) in slot order,
  keeping the existing equipment hover/click inspection.
- **Attuned magic:** an eyebrow plus `6 / 6` right-aligned, then a 2-column grid
  of card strips (unit 0) with ×N counts.
- **Active deck:** an eyebrow plus `N cards` right-aligned, then a 2-column card
  strip grid.
  - When the grid would overflow the column, it scrolls inside the column using
    the project's themed scrollbar. Never shrink text below 14 px.
- **Behaviour:** card strips keep the existing card hover/click inspection.

### Actions

- **Placement:** bottom of the Foes column, right-aligned to the column's edge,
  in this order: [Position N/M] [Equip] [Start].
- **Start:**
  - The ember-bronze primary plate, about 170×58, UI 24.
  - It keeps the existing selected/hover glow and the start sound.
- **Equip and Position:** secondary ink plates, 46 px tall. Equip keeps its icon.

### Foe inspection modal (known moves)

- **Panel:** restyle to the shared ink glass with the gilded hairline (no flat
  black box).
- **Portrait:** the foe sprite on an ink pool stage at the left.
- **Name and stats:** name in UI 30 `TEXT`; `HP 9/9` in `DANGER_BRIGHT` and base
  initiative in `STEEL`.
- **Section header:** `KNOWN MOVES`.
- **Each move row:**
  - The intent icon in a 40 px socket.
  - The move name (UI 18) and its effect line (14, `TEXT_2`).
  - A time chip at the right. Use the card time watch art scaled to 34 px if it
    reads, otherwise keep the existing TIME chip restyled to ink and gold.
- **Close:** a round ✕ socket at the top-right.

## Proof

Update the pre-battle probes (`tests/pre_battle_material_polish_probe.gd`,
`tests/pre_battle_preview_probe.gd`, `tests/pre_battle_deck_fit_probe.gd`) to cover:

- 1, 3, 5 and 6 foes;
- a boss;
- an elemental room;
- the true-bearing header;
- known-moves expanded;
- Start hover and focus;
- reduced motion;
- an 18-card and a 28-card deck (scrolling).

Save fresh 1920×1080 screenshots. Keep the fit assertions meaningful (no
clipping, no text under 14 px, every card listed).

`pre_battle_preview_probe.gd` already fails on master (`Compound Warden` move
icons, boss leader objective). Don't hide that. If your change makes those
assertions pass naturally, good; otherwise leave them as they were.
