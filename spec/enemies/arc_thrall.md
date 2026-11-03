# Arc Thrall (`arc_thrall`)

Binding source: owner-approved `thrall-rework-v1` (2026-10-30). Arc Thrall keeps
10 HP, initiative 11, 9 Embers and its existing assets. Encounter tables are
unchanged. Initial compositions no longer add or replace units to form pairs.

1. **Arc Bolt** (`arc_bolt`): Time 5, weight 3. Existing Move Toward 2, then
   ranged lightning damage 3, range 3, with the existing Electrified surface rider
   on the target tile. These are the same primitives as Zekarion's Storm Lash.
   Ordinary movement, line of sight, targeting, depth scaling, damage and surface
   rules apply. No new action type, keyword, status or targeting rule is added.
2. **Arc Jab** is unchanged: Time 4, weight 2, Move Toward 2, melee damage 3,
   Shock 1. Neither intent needs another Thrall.
3. No enemy path or threat is injected at rest. Hovering uses the same path,
   threat-tile and damage-preview pipeline as other enemies.
4. Arc Bolt uses the approved cast clip whose asset data name remains `tether`.
   Runtime routing selects it for the Thrall's ranged lightning action. Playback
   uses existing lightning ranged VFX and sound, with the existing clip contact.
   Art, rig, motion data, fonts and audio bytes are unchanged.
5. Legacy saves convert held `tether` intents to the current, depth-scaled Arc
   Bolt; retired action and step IDs migrate on load. Historical analytics are
   left intact. Dynamo and Snare IDs remain save-compatible.
6. Arc Bolt's Electrified tiles fuel the existing rules: Dynamo discharge strikes
   every Electrified tile for 4; lightning Snare strikes them after each player
   turn for 3. Their wording, timing and numbers are unchanged.

Authored cadence before spawn stagger is 11 + 5 = 16 for Arc Bolt and 11 + 4 = 15
for Arc Jab, weighted 15.6. This is an authored comparison, not measured uptime.
Standard local-depth and DepthRules modifiers apply to both attacks.

Proof lives in `tests/suites/thr01_suite.gd`, the retained Gloam Stalker coverage
in `tests/suites/en03_enemies_suite.gd`, and `tests/thr01_probe.gd`. Matched natural
lightning Warband, ordinary Thrall-room and Snare measurements were one-time
validation using the unchanged committed combat policy; their measurement
scripts are retired. The director owns tuning and windowed inspection.
