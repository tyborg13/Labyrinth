# Effect reminders and descriptions

Effect tooltips are reminders, usually one or two short sentences. State the
effect, its trigger and any necessary amount or duration. Explain another named
effect in its own nested tooltip. Do not repeat shared hazards, targeting laws,
large-character deduplication, preview behavior or hypothetical exceptions in
every description.

Relics and abilities describe what changes: the condition, optional choice or
cost, and the result. Keep restrictions that change eligibility, such as
single-target attacks, a required defense, once-per-turn limits and range.
Remove caveats already implied by the trigger or the core rules. For example,
“temporary light lasts longer” does not also need “permanent light is unchanged.”

Use the existing mechanic icons in relic and ability descriptions, including
their accessible text expansion. Use ordinary words around them; avoid engine
terms such as actor, footprint, explicit cost, configured pattern and relay node.
“Beside” and “cardinal neighbors” refer to the four adjacent tiles, not diagonals.

## Sources

- `scripts/action_icon_library.gd`: keyword hover reminders and nested keywords.
- `scripts/board_surface_presentation.gd::tooltip`: board-tile hover summaries.
- `data/grimoire.json`: reference entries; a separate source from keyword hover.
- `data/relics.json` and `data/skills.json`: description fields with mechanic icons
  and value placeholders. Gameplay effects remain in their effect definitions.
- `scripts/run_scene.gd`: contextual action-button hints.

Changing a rule means checking every relevant source above. In particular,
ordinary Electrified remains available after conducting an attack; Stormcoal
Fire is consumed when used as a conductor. Avoid wording that treats those two
surfaces as having the same consumption rule.

The September feedback pass audited all 60 relics, all 30 ability definitions and
all keyword entries. The before/after inventory and focused validation receipts
are under `output/board-surface-refactor/feedback-pass/copy/`. Native tooltip and
card presentation proof is owned by the UI pass.
