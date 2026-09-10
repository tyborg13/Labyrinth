# Boss section map

New runs use six saved, procedurally generated sections. The existing seeded
order shuffles Tharokh, Vyraketh, Vaeloryx, Iskaldra and Zekarion; Noctyrax is
always last. Each boss owns an independent painted background. Generation does
not depend on section art, boss order or discovery state.

## Route contract

| Section | Room visits, including boss | Fights, including boss |
| --- | ---: | ---: |
| I | 10 | 6 |
| II | 11 | 6 |
| III | 11 | 7 |
| IV | 11 | 7 |
| V | 11 | 7 |
| VI | 12 | 7 |
| Full run | 66 | 40 |

Every complete path obeys these budgets. Each section has 20–26 possible nodes
including its entry threshold, three or four branch decisions, and no backward
travel or room-skipping shortcuts. Branches preserve the fight budget while
varying services, elemental fights and their order. A threshold is an interlude,
not an additional encounter counted in the 66 visits. Room coordinates remain
stable depth-compatible identifiers for encounter generation and persistence;
separate step and lane fields control the left-to-right presentation.

The four local depth bands retain the existing enemy density, objective rolls,
Umbra escalation and boss rules. This is an initial pacing implementation for
inspection; the 66/40 budget is verified, while full-run elapsed time and
attrition still need human playtesting. Mini-bosses are not implemented or
advertised by this map. Encounters, cards and their scoring coefficients are
unchanged.

## Discovery and decisions

From the current room, identify the next two transitions. The third transition
shows an unknown medallion. Farther topology is hidden by a separate procedural
fog shader, except for two service landmarks and the boss. Discovery persists;
committing to another branch does not erase already learned information.

Each section owns two Scout uses. Scout starts at an adjacent branch, reveals
new identities up to four transitions from the current room, and never changes
topology or moves the player. Empty, invalid and exhausted requests do not spend
a use. Reopening the map, loading a save or viewing history does not refill it.

The first event prototype is **The Lost Cartographer**: take 25 Embers, or reveal
all reachable routes up to four transitions ahead. The event blocks travel until
resolved, persists the outcome, and cannot grant either choice twice. A survey
with no new discoveries is disabled. This is a real event transaction, not an
unimplemented icon placeholder.

## Runtime presentation and input

The map is a mostly full-screen modal over the board. After an encounter and its
reward sequence finish, it opens once for the next room choice. Closing it keeps
it closed until another relevant room state; the Map button, M shortcut and
controller map action reopen it. A combat map can be inspected without bypassing
the encounter. Reward, dialogue and animation locks keep their input priority.
Scavenger dialogue/shop remains its own interaction; leaving the shop opens
the map once for onward travel. Closing that map is respected on later refreshes.

A node selects a route preview. The action button commits legal adjacent travel.
The preview identifies its physical north/east/south door, known next rooms and
landmarks kept or left behind. In a Reach the Exit encounter the action is
**Show door**: close the map and highlight the matching board exit. The player
must reach that actual exit. Crossing it commits its exact destination through
rewards, saving, reloading and automatic travel; it cannot reopen free route
selection. Each outgoing branch has its own door, separate from the arrival.

Section tabs allow reviewing reached sections with discovered history intact.
A cleared boss keeps a dedicated Next section action available while inspecting
its map, including after reopening; controller focus starts on that action.
Future tabs are disabled and do not disclose the future boss order. History
cannot travel or spend the active section's Scout uses. All interactive pieces
remain native focusable buttons with mouse, keyboard and controller input.

`section_map_panel.gd` composes independent header, tabs, legend, preview and
actions. `section_map_node.gd` renders each independent room button with painted
emblems and medallions. `section_map_canvas.gd` owns route curves; the fog shader
receives dynamic openings. No routes, labels, icons, fog or taglines are baked
into the six background paintings. `section_map_skin.gd` owns this menu's
purpose-built frame treatment. Generation prompts are retained beside this
specification.

UI rubric: native 1920×1080 at 100% scale is the acceptance configuration.
Hierarchy, body-text readability, clear interaction/disabled/focus states,
consistent painted materials, independent assets, rule-accurate action text and
no ornamental taglines apply. The bespoke mostly full-screen map and dedicated
frame assets are explicit user-requested exceptions to preferring shared small
modal surfaces. Fresh renderer proofs cover start, a three-room fork, scouting,
history, all six backgrounds, reward entry, keyboard/controller focus, event
resolution and physical door inspection.

## Saves, recovery and analytics

`section_map_version: 1`, `map_sections` and the stored `rooms` graph distinguish
new runs. Legacy runs lacking the marker retain their original circular map and
legacy generation/repair rules. No in-progress run is converted to a different
route. New-run recovery maps lost Embers to an existing combat/boss near the old
depth, keeping every generated service and connection intact. The selected
recovery coordinate is saved and the matching encounter owns the Ember pile.
The map exposes its recovery badge and amount through fog without granting the
unknown room identity. Route previews explicitly keep or leave those lost Embers;
the badge survives resume and disappears after collection.

Map decisions and reveals enter a saved ordered outbox. The live game and
headless console flush them to existing local append-only analytics after a
successful save, using the same run-id/revision idempotency keys. See
[analytics.md](analytics.md) for the additive events. The console supports
`scout N` and `event embers|survey` in addition to ordinary room movement.

## Owning checks

- `tests/section_map_test.gd`: 32 seeds, all route budgets, boss order, stored
  identities, door mapping, fog knowledge, Scout transactions, event choices,
  save/load, legacy preservation, actual escape/reward/resume and Ember recovery.
- `tests/dragon_boss_test.gd`: complete six-boss traversal with section events.
- `tests/section_map_probe.gd`: independent panel states and all six backgrounds.
- `tests/section_map_flow_probe.gd`: real run-scene reward, map, input and door flow.
- `tests/section_map_review_probe.gd`: boss completion/controller transition, real
  completed history, recovery before discovery/resume/collection, and shop leave.
- `tests/run_tests.gd`: integration suite, including the section-map suite and
  explicit legacy map fixtures.
- `tests/test_icon_identity_policy.py`: unique concept artwork registry.
