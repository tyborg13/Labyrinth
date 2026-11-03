# el-04 — battlefield rule views (director-built; Codex reviews)

Owner direction (2026-10-23): every battlefield rule gets an in-game name, an icon and one sentence, shown right above
the objective, like the wind chip. One signal per concept. Base: integration after el-02 (rule icons registered,
instance sentences in data).

## 1. Rule panel (replaces the wind chip `En02WindChip`)
- A twin of the objective HUD (`scripts/combat_objective_hud.gd`): same gilded frame, icon well, typography roles and
  colours, same width, docked 8 px above the objective. As built, it hides while the objective is hidden or playing its
  intro.
- Kicker: `BATTLEFIELD` (eyebrow on the type scale, 14 px, `Palette.GOLD`; the objective's kicker moved to 14 px too). When the rule ends after a number of beats, append
  ` · N BEATS LEFT` (`1 BEAT LEFT` when N is 1). There's no suffix while the source holds it.
- Title: the rule name (section role, 19 px, `Palette.GOLD_BRIGHT`), e.g. `Gust`. Directional rules (Gust;
  Wildfire `toward_player` once locked) get the existing 12 px `DirectionArrow` after the name, in screen direction.
- Detail: the instance sentence from data, verbatim (body role, 14 px, `Palette.TEXT_2`). It wraps to at most three
  lines; the panel grows downward-up so its bottom edge keeps the 8 px gap.
- Icon well: the rule icon (`wind`, `wildfire`, `frostbite`, `lightning_storm`, `upheaval`, `shadowstep`).
- Tooltip: the glossary definition of the rule.
- Visible only in combat while `BattlefieldRules.panel(state)` is non-empty; it hides with the objective intro and
  shows when the objective settles.

## 2. Turn-clock beat token
- `BattlefieldRules.project_turn_order` already inserts `{kind: "beat", rule, at}` entries. The turn-order strip draws
  each one in a normal rail slot (index-based heights keep the rail's animation intact): the rule icon in a gold-rimmed
  round token, 62% of the slot height, with the same time numeral column as portraits.
- Tooltip: `<Rule name> — <sentence>`.

## 3. Forecast previews (the next beat) — as built
- Tiles: the next beat's `catch`/`freeze`/`strike`/`rise` tiles are marked as a threat at rest, with the existing red
  threat marking. One signal per concept: a tile that will hurt you looks like every other threat. The element shows
  in the panel and the beat token, not as new board colours.
- Only when the beat fires before the hero's next turn: the rail shows a beat entry before the next player entry.
  Snares keep their own pressure view; Warband orders and ordinary sources use `scripts/battlefield_rule_view.gd`.
- Moves (el-05, as built): Gust keeps its existing landing ghosts.
  - **Upheaval** throws use the same pale ghost, of the occupant, where it lands: the battlefield sets a unit down,
    the same concept as wind.
  - **Shadowstep** Blinks use the enemy-move ghost (violet, pulsing), drawn as the Umbra shade. The movers are hidden,
    so the forecast keeps only their visible landings (`emergences`, no actor or origin). The shade is the
    `umbra_presence` figure as pale light, at about the hero's height.
  - Both show only when the beat lands before the hero acts again.
- Turn-order rail: a beat is a round gold-rimmed rule token on a faded stroke, with the usual time numeral. Its tooltip
  is `<Rule> — <sentence>`.
- Card landing strip (el-05): a beat before your landing shows as the same rule token, with its time numeral. It is an
  event, not an actor: with only beats ahead of you, ACT AGAIN still shows.

## Proof
- Real renderer, 1920×1080, 100% UI scale: one Warband and one Snare per element. The UI identity lint ratchet passes,
  and the director judges the captures.
- Codex peer review of the diff.
