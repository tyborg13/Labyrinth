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
including its entry threshold, three or four groups of routes, and no backward
travel or room-skipping shortcuts. Between groups, routes split or merge only
between neighboring lanes; no edge jumps from top to bottom and no two edges
cross between columns. Every room remains reachable, each section has at least
six complete route combinations, and the boss is the only unavoidable
convergence. Outer branches persist while short middle branches allow gradual
changes of route. Branches preserve the fight budget while varying services,
encounter elements and their order. A threshold is an interlude,
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

Each section owns two Scout uses. Activate Scout, then choose a visible unknown
room that is still reachable on the current section's routes. That room's
identity is revealed and its outgoing connections become visible, with unknown
neighbors shown as outlines. Scout never identifies those neighbors, changes
topology, or moves the player. Known rooms, undiscovered topology, abandoned
branches, other sections, blocked encounter modes and exhausted requests do not
spend a use or emit an event. Reopening the map, loading a save or viewing
history does not refill it. A distant recovery marker can be scouted when its
room is still reachable, without revealing its identity merely by showing the
marker.

The first event prototype is **The Lost Cartographer**: take 25 Embers, or reveal
all reachable routes up to four transitions ahead. The event blocks travel until
resolved, persists the outcome, and cannot grant either choice twice. A survey
with no new discoveries is disabled. This is a real event transaction, not an
unimplemented icon placeholder.

## Runtime presentation and input

The map is a mostly full-screen modal over the board. After an encounter and its
reward sequence finish, it opens once for the next room choice. Closing it keeps
it closed until another relevant room state. The map icon in the top-right
utility row beside loadout, Grimoire and settings, the M shortcut and controller
map action reopen it. The icon uses the existing ActionIconLibrary map_rooms
identity with a registered line-art toolbar presentation, native header-button
styling, and the Map [M] tooltip. Its folded-map silhouette shares the neighboring
Loadout, Grimoire and Menu controls' line weight, ink and transparent background. The detached
map text button is removed; the turn rail anchors below the utility row. Closing
a toolbar-opened map restores toolbar focus and controller navigation. A combat map can be inspected without bypassing
the encounter. Reward, dialogue and animation locks keep their input priority.
Scavenger dialogue/shop remains its own interaction; leaving the shop opens
the map once for onward travel. Closing that map is respected on later refreshes.

A single click, Enter, or controller confirm on an available room starts a
0.28-second press-and-settle acknowledgement before committing legal adjacent
travel. A brief highlight replaces scaling and the expanding outline at reduced
motion, lasting 0.14 seconds. The existing dry forged-metal UI click sounds on
all input paths; a pointer press is not sounded twice at release. There is no persistent room selection or
second confirmation button. Hover or native focus exposes a shared tooltip
with a room name and one short state line: Current room, Already visited, Not
yet visited, No longer reachable or Undiscovered. Scout targets use Scout to
reveal. Route connections communicate where branches go; previews do not list
next rooms, door directions, or landmarks kept/left. Ordinary encounters are
called Standard combat regardless of element; tougher or elite tiers are not
advertised. The exact lost-Ember amount, when present, fits on the same state
line. Inspecting an unavailable room never travels.
The first activation owns the acknowledgement; rapid repeat activations cannot
queue a second entry. Escape/Back cancels pending entry while keeping the map
open. Closing, changing sections, changing run state or rebuilding geometry
discards pending activation so stale timers cannot commit later. Scout reveals
and physical-exit previews use the same brief acknowledgement and guards.

Scout is a separate, fixed action beside the legend: activate Scout, then choose
an unknown room to reveal it. Only eligible unknown rooms gain the large bright
availability treatment; known travel destinations cannot be entered in this
mode. Native focus starts on an unknown target, and directional navigation
visits the targets. Entering targeting mode spends nothing; only a valid room
activation spends a use, returns to normal travel, and keeps the player in the
current room. Keyboard/controller focus stays on the newly identified room. Escape/controller Back first cancels targeting and
restores Scout-button focus. A second Back closes the map. Clicking Cancel Scout
also cancels, and closing or changing sections discards targeting.

In a Reach the Exit encounter, a room activation closes the map and highlights
the matching board exit. The live Show exit action prompt and board highlight
identify the action. Crossing that physical door commits its exact destination through rewards, saving,
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
targeting and Close otherwise. During acknowledgement, prompts say Entering,
Scouting or Showing exit, and Back says Cancel. These labels use the existing
device glyph system.

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
room emblem with a larger filled downward pointer and a 5.5-pixel outline,
stronger than the completed-room 4-pixel outline. Its 43-pixel medallion radius
also exceeds the completed-room 33-pixel radius. Visited rooms carry a stamped
ring and a large check seal. Bypassed rooms recede with dark emblems and faint
dashed paths. Future room icons are smaller and muted; unknown identities have
broken rings. Boss medallions are approximately three times the diameter of
ordinary future rooms and almost twice the diameter of immediate choices.

The painted medallion is an offset oval. SectionMapSkin caches 96 samples of its
actual alpha edge and outward normals, so current, visited, available and hover
outlines follow its contour with consistent spacing. It also caches a textured
mesh from the inside brass lip to the texture edges. The full medallion draws
below the interior art and this rim draws above it: no sword, pack or other room
image can obscure the painted frame. The shared drawing helper also renders
48-pixel legend seals and the destination emblems above physical doors; opaque
square artwork is clipped inside the rim before the frame is drawn on top.
Modern combat doors use the same crossed-swords Standard combat identity as
the map and legend. Legacy elemental door identities remain supported.

Room nodes have no attached room names, door labels, status captions, or recovery
amount text. The larger, framed independent legend names the room symbols. Exact
identities, room state and lost-Ember amounts appear on hover or keyboard/controller
focus. Focus brackets remain distinct from availability and completion marks.
The four depth captions are removed from the field; depth-compatible encounter
rules and graph coordinates are unchanged. The map does not require hover to
inspect mechanics: native focus exposes the same tooltip.

Connections leave and enter medallions horizontally, then curve between lanes.
Only immediate exits carry small direction cues aligned to the curve tangent.
The inspected branch's possible continuation is subdued; completed travel stays
visible without competing with immediate choices. Only edges whose endpoints
are already revealed or outlined are drawn, above the fog so learned
connections remain legible. Fog recedes around a scouted room and its neighboring
outlines while farther unknown topology stays absent. Generation prompts are
retained beside this specification.

Design statement: this is the map/room-choice surface. The player's question is
which available room to enter; a single room activation advances that choice.
Availability, current position, completion and known connections are persistent;
room names and short state lines are optional hover/focus details. Scout answers
which unknown room to identify, with eligible targets shown directly on the map. Pointer, keyboard and controller
share the same activation rules, with explicit Scout targeting/cancel and focus
recovery. Native 1920×1080 at 100% scale proofs cover opening choices, history,
boss hierarchy, normal/reduced motion, optional details, Scout cancel/commit,
single-action travel by all three inputs, acknowledgement sound/motion and
cancellation, utility-toolbar focus/activation/return and turn-rail clearance,
event resolution, all six physical destination emblems, recovery and complete
route geometry on all six backgrounds. The mostly full-screen map and
its authored frames remain explicit user-requested exceptions to preferring
shared small modal surfaces.

## Saves, recovery and analytics

`section_map_version: 1`, `map_sections` and the stored `rooms` graph distinguish
new runs. New generation also records `section_map_layout_revision: 2` for the
neighboring-lane layout. That marker does not trigger regeneration: previously
saved section maps keep their exact stored connections. Legacy runs lacking the
section-map marker retain their original circular map and generation/repair rules. No in-progress run is converted to a different
route. New-run recovery maps lost Embers to an existing combat/boss near the old
depth, keeping every generated service and connection intact. The selected
recovery coordinate is saved and the matching encounter owns the Ember pile.
The map exposes its recovery badge through fog without granting the unknown
room identity; focus/hover details retain the exact amount. The connections and
recovery badge show the route to the pile; tooltips do not repeat those paths.
The badge survives resume and disappears after collection.

Map decisions and reveals enter a saved ordered outbox. The live game and
headless console flush them to existing local append-only analytics after a
successful save, using the same run-id/revision idempotency keys. See
[analytics.md](analytics.md) for the additive events. The console supports
`scout` lists visible unknown targets; `scout N` selects their zero-based index,
independent of the travel list. `event embers|survey` remains available alongside
ordinary room movement.

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
