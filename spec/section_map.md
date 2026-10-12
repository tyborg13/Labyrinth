# Boss section map

New runs use six saved, procedurally generated sections. The existing seeded
order shuffles Tharokh, Vyraketh, Vaeloryx, Iskaldra and Zekarion; Noctyrax is
always last. Each boss owns an independent painted background. Generation does
not depend on section art, boss order or discovery state.

## Route contract

New runs use layout revision **4**. Sections have 10, 11, 11, 11, 11 and
12 room visits respectively, including the boss (66 visits overall). The
threshold is step 0, visually centered at lane 1.5; rooms occupy steps 1 through
S−1 and lanes 0–3. The boss is step S. Boss order, encounter tuning and service
transactions are unchanged.

Each section is the union of exactly five section-seeded lane walks. The first
two walks start in different lanes; each move stays in its lane or moves one
lane, uniformly among crossing-free moves. Duplicate nodes and edges merge.
The threshold connects to every opening room, and all Hearths connect to the
boss. Every room step has at least two nodes. Rejections use the same RNG stream
(up to 50 topology attempts and 50 section attempts), followed by a deterministic
legal fallback. No stored graph is regenerated.

Step 1 is all combat, step ceil(S/2) is all treasure, and step S−1 is all
**Ember Hearth**. Other nodes roll combat 46, mystery 22, Guardian 10,
Scavenger 10, Graftwright 6 and event 6. Bounded weighted type repair verifies
all incoming paths and the complete route constraints before accepting a section.
Guardians occupy steps 3 through S−3; Scavengers start at step 3. A Graftwright
requires at least three fights on every incoming route, counting hidden
mystery combats. See [graftwright.md](graftwright.md) for the service itself.
Identical adjacent Guardian, Scavenger, Graftwright, Hearth or treasure nodes
are forbidden. At a split, child types differ; combat can repeat at a three-way
split. The all-combat opening row therefore has three threshold children.
Parents cannot fork into the fixed treasure or Hearth rows. Topologies whose
outgoing doors overlap a destination's incoming threshold are rejected, retaining
the existing UP/RIGHT/DOWN direction mapping and all physical exit options.

Every complete route has F−1 through F+1 non-boss fights, where F is
5, 5, 6, 6, 6 and 6 respectively. Fights count combat, Guardian and hidden
mystery-combat. Each route has at most one Guardian and at least one non-fight
service besides the fixed treasure/Hearth rows (event, Scavenger, Graftwright,
or non-combat mystery). Each section has at least two Guardians and one
Scavenger, with both Guardian and bypass routes. All Guardians carry that
section's exact Guardian identity and trophy; a route cannot duplicate it.
`guardians` stores every coordinate and `guardian` retains the first as a
compatibility alias.

Coordinates are unique persistent ids on Chebyshev depth rings. Divide the
S−1 room steps as evenly as possible among three local bands, assigning the
remainder to later bands: 9 steps use 3/3/3, 10 use 3/3/4, and 11 use 3/4/4.
If a band's nodes exceed its `8 * depth` ring capacity, move its last step to
the next band until it fits. Bosses retain the fourth local depth. Step/lane
fields independently control presentation.

## Discovery and decisions

In revision 4, sections I–V reveal and outline all current-section nodes and
edges from entry, with no fog. Future sections remain hidden behind disabled
tabs. Noctyrax's section VI retains the next-two-transition identities,
third-transition outlines and fog shader. Every node in its treasure row and
Hearth row, every Guardian and the boss are landmarks visible through fog.
Knowledge persists when committing to a branch, saving, resuming or viewing
history.

**Mystery rooms** are displayed as **Unknown room**, using the existing broken
ring and question mark until a dedicated emblem is supplied. Their seeded
hidden type rolls event 70, combat 20, treasure 5, Scavenger 5. The hidden type
is never shown before Scout or entry. Tooltips retain the normal room-state
line. Once scouted, their name becomes **Unknown room · <Type name>**, such as
**Unknown room · Event** or **Unknown room · Standard combat**. Entering converts
`type` to the stored `mystery_type`, adds normal combat/service fields, records
`was_mystery: true`, and uses the ordinary resolved room transaction. The
original seeded identity remains saved. A physical door to an unscouted mystery
uses the same Unknown-room emblem; after Scout it uses the revealed type's
emblem.

Each section still owns two Scouts. In revision 4 sections I–V, Scout targets
only unentered, unscouted mysteries that remain reachable in the current section.
Section VI keeps the legacy target rule: outlined, unrevealed, reachable rooms.
Scouting a mystery in either case sets `scouted: true` and shows its hidden type's
emblem over the unknown ring without converting the node. Scout reveals/outlines
the selected room and outlines its outgoing destinations; it never moves the
player. A mystery can be both a Scout target and an immediate travel choice.
Abandoned branches, other sections, blocked encounter modes and exhausted or
repeated requests spend nothing and emit nothing. Reopening, loading or browsing
history never refills the budget. Event contents are owned separately; map
generation places `event` nodes only.

### Older layouts

Saved revisions 1–3 keep their stored topology and original knowledge rules:
the next two transitions reveal identities, the third outlines unknown rooms,
and farther topology remains fogged except landmarks and the boss. Scout still
reveals one reachable outlined unknown room, with ordinary `scope: room`
analytics. Revision 3's grouped three-lane routes retain exact section fight
budgets, one optional Guardian and seeded eligible Graftwright conversion.
Legacy circular-map saves remain circular. None of these layouts are upgraded
or regenerated on load.

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
emblems and medallions. Revision-4 rooms use four lanes at
`y = 116 + (field_h − 232) * lane / 3.0`, with deterministic coordinate-hash
jitter of up to ±16 pixels horizontally and ±12 vertically after step/lane
placement. Thresholds and bosses remain centered without jitter. `section_map_canvas.gd` owns route curves; the fog shader
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
dashed paths. Revision-4 revealed future room icons use 85% opacity; older layouts retain
their muted icons. Available, current, visited and bypassed styles remain as
before. Unknown identities have broken rings. Boss medallions are approximately three times the diameter of
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
new runs. New generation records `section_map_layout_revision: 4` for the
four-lane layout. That marker does not trigger regeneration: previously
saved section maps keep their exact stored connections. Legacy runs lacking the
section-map marker retain their original circular map and generation/repair rules. No in-progress run is converted to a different
route. New-run recovery maps lost Embers to an existing combat, Guardian or boss
node near the old depth, keeping every generated service and connection intact.
The selected recovery coordinate is saved and the matching encounter owns the
Ember pile without changing its roster: a Guardian or boss node still fights its
own leader, so the map stays truthful. The pile lands on the empty floor tile
nearest the board center: never under a unit, NPC, trap, terrain object, other
loot, brazier, ground surface or exit target.
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

- `tests/section_map_v2_test.gd`: 64 seeds × 6 sections, walk union, planar edges,
  placement constraints, exhaustive route budgets, depth capacity, mystery entry,
  Scout, section VI knowledge and revision-3 save/play compatibility.
- `tests/section_map_test.gd`: preserved revision-3 checks plus revision-4 checks;
  32 older-layout seeds, all route budgets, boss order, stored
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
