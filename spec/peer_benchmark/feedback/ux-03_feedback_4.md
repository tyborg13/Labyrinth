# ux-03 — round 4 (peer review of 723f52579: CHANGES REQUESTED; director rulings included)

Work on top of 723f52579. Do not commit.

1. **Blocker — card keyword tooltips gained a stray line** on 9 cards (Crosswind, Rockburst, bottled_gale, cyclone_seal,
   dust_devil, gale_ward, shattered_reflection, unsealed_gale, vortex): `action_icon_library.gd:688` sets the description
   to `default_title` when `body_lines` is empty, so one-line contextual tooltips repeat their label ("PUSH 2 IN ANY OPEN
   DIRECTION." + "Push"). Revert to `"\n".join(body_lines)` (`Glossary.definition` already falls back to the label).
   Add a structural regression check over **every card** in the base vs HEAD comparison: the number of tooltip body lines
   per keyword panel is unchanged (no text pinned).
2. **Choice fallback must not cover the top HUD** (director ruling). Fallback order becomes: 3 columns below the row →
   4 columns below → **5 columns below** → above the row with its top bounded by the TopBar's bottom + 12 px (covering
   the room-title banner is allowed only here; the TopBar never). If even that cannot fit, keep the above-row placement
   and shrink nothing — report the case. Probe: assert no overlap with the TopBar rect in every choice case at all three
   sizes; exercise the top clamp (a test that removes it fails).
3. **Owned stack must not cover the tray** when the tray wraps (5 per row): anchor at max(hovered icon bottom, tray
   bottom) + 8 px (pass the tray rect through `bind_relic`). Probe a 15-relic tray hovering indices 0, 4, 9, 14 at all
   three sizes: no overlap with any tray badge, still on screen.
4. **Opt-in callers**: `run_scene.gd:16014-16023` (DragonRewardRules, mouse filter STOP) must pass `true` so its icons get
   the styled glossary stack; drop the no-op opt-in at `skill_tree_view.gd:1276` (its label ignores the mouse).
5. **Coverage test in the suite**: move the glossary coverage check (every keyword/icon token resolves to a non-empty
   definition) into a `tests/suites/*_suite.gd` wired into `tests/run_tests.gd`.
6. **One click guard**: keep a single mechanism for "a mouse click never pins; keyboard/controller focus pins" and
   delete the other two; mouse-wheel events never dismiss a pinned stack. Tests: click does not pin; click elsewhere
   un-pins a keyboard-pinned stack; `prepare_navigation_focus` path; wheel does not dismiss.
7. **Skills have one source**: `skills.json` owns skill descriptions. Remove the 31 copied `skill_*` glossary entries;
   `ActionIcons.tooltip(skill_*)` reads `SkillTreeLibrary` (name + description). Keep the glossary for keywords, statuses,
   surfaces and icons only.
8. **Lookup cost**: give `Glossary` a non-copying internal accessor used by `name_for`/`definition` (the deep copy in
   `lookup` made `tooltip()` 3.7× slower; it runs twice per status badge per draw). Public `lookup` may keep copying.

Proof: glossary tests, the suite (with the moved coverage check), probe logic at 1920/1670/1536, UI lint, icon identity,
full suite; list the three windowed probe commands.
