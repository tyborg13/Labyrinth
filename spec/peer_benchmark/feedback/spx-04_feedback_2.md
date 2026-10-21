# spx-04 feedback 2 (Codex peer review of 0df82a848: CHANGES REQUESTED)

1. **The Stormcaller and its held wind: a director decision; no behaviour change.** The Stormcaller commands the wind
   and stands firm in it, like the base Gale Herald (`force_anchored`). The order's text was wrong, not the code.
   - The director changed the data to "Its wind never drops: a gust slides everyone else 1 tile every round." in
     `data/special_encounters.json` and its staged copy, in this worktree too. Don't edit it.
   - Keep the captain anchored. The preview correctly shows no slide for it.
   - Make sure the tooltip and objective Order lines read the new text.
2. **Medium: the wind test accepts the wrong displacement.**
   - `warband_orders_suite.gd:277` compares resolution with a forecast from the same resolver. A 2-tile push still
     passes.
   - Assert independent expected one-tile destinations for every unit, with the captain expected to stay put.
   - Add a collision case: a unit blocked by a pillar or another unit stops, using the existing collision rules.
   - Mutation-check it: a 2-tile push and a sliding captain must both fail.
3. Focused tests only. No visible change is expected beyond the order text.
