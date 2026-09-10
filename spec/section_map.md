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
shows a broken outline with a question mark. Farther topology is hidden by a separate procedural
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

A single click, Enter, or controller confirm on an available room commits its
legal adjacent travel immediately. There is no persistent room selection or
second confirmation button. Hover or native focus exposes a shared tooltip
with the room identity, physical north/east/south door, known next rooms, and
landmarks kept or left behind. Already bypassed landmarks do not appear as a
new consequence. Inspecting an unavailable room shows its reason without travel.

Scout is a separate, fixed action beside the legend: activate Scout, then choose
an available branch to reveal it. Entering targeting mode spends nothing; only
a valid branch activation spends a use, returns to normal travel, and keeps the
player in the current room. Escape/controller Back first cancels targeting and
restores Scout-button focus. A second Back closes the map. Clicking Cancel Scout
also cancels, and closing or changing sections discards targeting.

In a Reach the Exit encounter, a room activation closes the map and highlights
the matching board exit. The tooltip explains that the player must reach that
actual door. Crossing it commits its exact destination through rewards, saving,
reloading and automatic travel; it cannot reopen free route selection. Each
outgoing branch has its own door, separate from the arrival. Ordinary combat
allows inspection and scouting but does not allow map travel.

The Lost Cartographer uses a dedicated encounter panel with its two choices;
room travel stays blocked until one resolves. This event panel replaces the
former overloaded map footer. Controller focus starts on the event's first
choice and returns to available rooms after resolving it.

Section tabs allow reviewing reached sections with discovered history intact.
A cleared boss exposes Next section in the header, including after reopening;
controller focus starts on that action. Future tabs are disabled and do not
disclose the future boss order. History cannot travel or spend the active
section's Scout uses. Switching sections restores focus to the rebuilt tab.
The user-approved round bronze section seals are preserved. Up/down navigation
visits immediate choices in screen order, then reaches the section tabs or Scout;
left/right and normal native navigation remain available for route inspection.
The active controller prompt names the focused action: Enter, Scout, Show exit,
Inspect, an event choice, or section navigation. Back says Cancel Scout while
targeting and Close otherwise. These labels use the existing device glyph system.

`section_map_panel.gd` composes independent header, tabs, legend, optional
focus/hover tooltip, Scout targeting and event choice surfaces.
`section_map_node.gd` renders independent native room buttons with painted
emblems and medallions. `section_map_canvas.gd` owns route curves; the fog shader
receives dynamic openings. No routes, labels, icons, fog or taglines are baked
into the six background paintings. Shared `UiSkin` action buttons and
`UiTooltipPanel` tooltips retain the established metal and brass vocabulary.

The map answers “which room can I enter now?” in a static frame. Available rooms
have larger bright seals with four small cardinal points. A slow, 5.5% maximum
scale pulse draws attention to them; reduced motion freezes their geometry
without changing the static availability mark. Current position retains its
room emblem with a filled downward pointer. Visited rooms carry a broad stamped
ring and a large check seal. Bypassed rooms recede with dark emblems and faint
dashed paths. Future room icons are smaller and muted; unknown identities have
broken rings. Boss medallions are approximately three times the diameter of
ordinary future rooms and almost twice the diameter of immediate choices.

Room nodes have no attached room names, door labels, status captions, or recovery
amount text. The compact independent legend names the room symbols. Exact
identities, room state and lost-Ember amounts appear on hover or keyboard/controller
focus. Focus brackets remain distinct from availability and completion marks.
The four depth captions are removed from the field; depth-compatible encounter
rules and graph coordinates are unchanged. The map does not require hover to
inspect mechanics: native focus exposes the same tooltip.

Connections leave and enter medallions horizontally, then curve between lanes.
Only immediate exits carry small direction cues aligned to the curve tangent.
The inspected branch's possible continuation is subdued; completed travel stays
visible without competing with immediate choices. Generation prompts are
retained beside this specification.

Design statement: this is the map/room-choice surface. The player's question is
which available room to enter; a single room activation advances that choice.
Availability, current position and completion are persistent, while exact route
consequences are optional hover/focus details. Pointer, keyboard and controller
share the same activation rules, with explicit Scout targeting/cancel and focus
recovery. Native 1920×1080 at 100% scale proofs cover opening choices, history,
boss hierarchy, normal/reduced motion, optional details, Scout cancel/commit,
single-action travel by all three inputs, event resolution, physical door
inspection, recovery and all six backgrounds. The mostly full-screen map and
its authored frames remain explicit user-requested exceptions to preferring
shared small modal surfaces.

## Saves, recovery and analytics

`section_map_version: 1`, `map_sections` and the stored `rooms` graph distinguish
new runs. Legacy runs lacking the marker retain their original circular map and
legacy generation/repair rules. No in-progress run is converted to a different
route. New-run recovery maps lost Embers to an existing combat/boss near the old
depth, keeping every generated service and connection intact. The selected
recovery coordinate is saved and the matching encounter owns the Ember pile.
The map exposes its recovery badge through fog without granting the unknown
room identity; focus/hover details retain the exact amount. Route previews explicitly keep or leave those lost Embers;
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
