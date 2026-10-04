# Visual pass 4: pre-battle, NPC scenes, character menu, combat HUD

Owner request (2026-10-03): polish the screens the earlier beautify passes did not
reach (the pre-battle menu, the Scavenger and Graftwright scenes, and the character
menu), then take a second look at the main combat screen.

Claude owns the design; Codex implements discrete, well-specified units, and a
separate Codex image-generation run produces any painted assets after Claude has
approved them. Each unit has a brief here and a target mockup (`mockups/*.jpg`,
rendered at 1920x1080 from real game art). Mockups are the visual target, not a
pixel contract: match their hierarchy, proportions, spacing rhythm, colours and
materials, and use the brief for exact rules.

## Direction

- **Scene first, chrome second.** Painted scenes (Scavenger stall, Graftwright
  atelier, the torch-lit hall) carry the mood. UI sits on them as warm ink glass
  with the fine gilded hairline (`UiGildedFrame`), not as heavy opaque boxes.
- **One component vocabulary everywhere** (built once in unit 0):
  - *Card strip*: a one-line card row (art thumbnail, name, ×count) used wherever
    a deck is listed (pre-battle kit, character menu).
  - *Socket*: a round bronze socket that holds an equipment/item/relic icon.
  - *Stat chip*: a pill with an icon socket, a value and a letter-spaced label.
  - *Ink pool stage*: a painted ground pool under a standing figure with a faint
    warm spotlight (pre-battle foes, character paper doll).
  - *Section header*: gold letter-spaced eyebrow, optional count, fading rule.
- **Type and colour follow `spec/visual_design_system.md`.** Titles are
  `GOLD_BRIGHT` display type; eyebrows are letter-spaced UI caps; semantic colour
  only (crimson enemy HP, teal ally HP, violet Umbra, ember for the primary action).
- **One primary action per screen** (Start, Graft, the selected shop mode) wears
  the ember-bronze plate; everything else is a quieter ink plate.
- **Keep every behaviour.** Inputs (pointer, keyboard, controller), focus order,
  tooltips/inspection, rules text, analytics and save/resume behaviour are
  unchanged unless a brief says otherwise.

## Units

| Unit | Brief | Owner |
| --- | --- | --- |
| 0 | [Shared components](unit_0_shared_components.md) | Codex (implement) |
| 1 | [Pre-battle scouting report](unit_1_pre_battle.md) | Codex (implement) |
| 2 | [Character menu](unit_2_character_menu.md) | Codex (implement) |
| 3 | [Scavenger stall](unit_3_scavenger.md) | Codex (implement) |
| 4 | [Graftwright atelier](unit_4_graftwright.md) | Codex (implement) |
| 5 | [Combat HUD](unit_5_combat_hud.md) | Codex (implement) |

Painted assets for this pass are generated separately, approved by Claude, and
recorded with their prompts and hashes under `spec/assets/visual_pass_4/`.
