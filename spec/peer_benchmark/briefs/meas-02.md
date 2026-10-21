# meas-02 — How hard is the Warband next to Guardians and dragons? (measurement only)

## Header
- **Owner, 2026-10-21 (after the Warband order clips):** "They seem to have 6 enemies a piece and a decent chunk of
  health. With the leader already being a stronger enemy placed far away, will this be too hard relative even to the
  existing boss fights and minibosses?"
- **What exists:** spx-01's sweep (`tools/encounter_sweep.gd`) and policy-v2 bot (`tools/encounter_bot.gd`) measure two
  cohorts, `standard` and `warband`, per tier (baseline: `spec/peer_benchmark/encounter_redesign/baseline.md`,
  revision-6 data in `measurements/revision6/`). Guardians and dragons have never been measured.
- **Base:** integration HEAD (revision-7 maps, spx-07's spread spawns and locked wind). **Owned:** the sweep and bot tools,
  their tests, `spec/peer_benchmark/encounter_redesign/` (new `measurements/revision7/` and `baseline_revision7.md`).
  No gameplay, data or balance change. Nothing else is touched; spx-06 runs in parallel (Snare files only).

## Change (director decisions; exact)
1. **Two new cohorts** in the sweep and the bot, available for revisions 5+:
   - `guardian`: rooms of type `guardian`, with their room's own objective and tier.
   - `boss`: each section's dragon room, with its own objective; measured with the tier-3 deck preset.
   The bot policy, its search limits and `policy_sha256` stay exactly as they are. Where a Guardian or dragon mechanic
   needs a bot hook it lacks (for example an unrevealed phase), stop and report it as `TODO_DESIGN_<what>`; don't invent
   policy.
2. **Measure on revision 7, current integration, 200 runs per group, first seed 1**, same workers and report format:
   - `standard` and `warband`, tiers 1–3 (re-measured: spawns changed in spx-07);
   - `guardian`, every tier Guardians appear in;
   - `boss`, 50 runs per dragon (six dragons; 300 total).
3. **Report** `baseline_revision7.md`: one table with win rate, turns and HP lost (median, P10–P90) per group, plus a
   composition table (units, spawn HP, leader distance) for `guardian` and `boss` like `composition.md`. Add one short
   paragraph that only states the comparisons (Warband vs standard vs Guardian vs boss at matching tiers); no
   recommendations.

## Keep
The bot policy and its limits, the revision-6 data and report, every gameplay rule and number.

## Proof
- Tool tests for the new cohorts (selection, objective, deck preset), the existing sweep/bot tests, and the full report.
- Focused tests while building; both full suites once at the end.

## Out of scope
Any tuning. The director decides changes from the report.
