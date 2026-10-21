# Boss section map

New runs use six saved, procedurally generated sections. The existing seeded
order shuffles Tharokh, Vyraketh, Vaeloryx, Iskaldra and Zekarion; Noctyrax is
always last. Each boss owns an independent painted background. Generation does
not depend on section art, boss order or discovery state.

## Route contract

New runs use layout revision **7** (map-03, below). Saved revisions 3–6 keep their
exact graphs and original generation paths. Revision 6 extends revision 5’s five-lane,
six-walk solver with the post-solver substitution below. The revision-4 base
route contract is retained here for older layouts. Sections have 10, 11, 11, 11, 11 and
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
5, 5, 6, 6, 6 and 6 respectively. Fights count combat, special, Guardian and hidden
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

## Revision 7 web and scrolling map (map-03)

Owner, 2026-10-21: the walk maps read as "a few straight lines with a couple of branches"; the approved mockup
(inbox `map-branching-v2`) keeps a dense web of choices and scrolls sideways. Reference model and measurements:
`spec/peer_benchmark/staged/map-03/`.

**Generator.** Seven lanes (0–6); the threshold sits at lane 3 and fans out up, straight and down to three opening
combats (top lane 0 or 1, lane 3, bottom lane 5 or 6). Each later row is built top to bottom: a room takes one, two or
three exits (weights 32/58/10) to adjacent lanes in the next column, as a contiguous range that never crosses the room
above it, and shares that room's last exit 45% of the time (a merge). Rooms leading into the Relic row (step
ceil(S/2)) and the Ember Hearth row (S−1) have one door and merge 75% of the time. Rows hold 2–6 rooms (at most 4 in the
two gathering rows); no lane set repeats three rows running; a row that fails is re-rolled up to 24 times, a section up
to 400 times, and room types then use the revision-5 solver (64 nodes per attempt, then a new web). Sections also fit
their depth-ring capacity. Measured over 200 seeds × 6 sections: 40% of rooms fork, every route meets at least 3 real
choices (median 5), choices are never more than 2 rooms apart, and at most 3 where single doors gather into the Relic
and Hearth rows; about 42 rooms per section; generation takes about 0.2 s per run (0.4 s worst).

**Doors face their lane.** A room's door leads up, right or down as its destination's lane is above, level or below;
the boss and the next threshold are always straight ahead. A room entered from below never has a door down, and one
entered from above never has a door up, so no exit reuses an entry wall; a room entered from both sides continues
straight. (The revision 5/6 mapping, by exit count, forced every fork's children to a single exit.)

**Fights.** With this many forks a route may run two fights under the section target (F−2 through F+1); every other
type rule is unchanged.

**Fallback.** If generation or special placement is ever exhausted, the section uses its stored revision-7 web from
`data/section_map_v7_fallbacks.json` (one per section, made by the ordinary generator; `tools/section_map_v7_fallbacks.gd`
regenerates it). It stores the hidden type of each mystery room too, since that decides whether the room counts as a
fight, so the stored section is legal for every run seed. No natural fallback occurred in 512 seeds.

**Presentation.** Revision 7 sections are wider than the field and scroll sideways: 240 px columns, odd lanes staggered
right and even lanes left by 22 px, rooms at their usual sizes, and neighbours in a column spread sideways so they never
touch at their largest size (an actionable Guardian beside an enlarged choice). Rooms hit-test as circles. The map opens
with the player's room 38% from the left and recentres when the room changes; the wheel, a drag, a trackpad pan and the
right stick scroll it, and focus keeps the focused room 150 px inside the edges. Rooms forward the wheel and drags to the
map, so both work over a room; a press that moves 6 px or more is a drag and never travels, while a smaller wobble is
still a click. The painting drifts at 0.3× the scroll.
Dark fades mark the edges with more map, and a slim gold-on-ink track sits at the bottom. Trails keep the sideways
S-curves but are inked dots: solid gold where walked, glowing larger dots for the current choices, brighter dots for the
planned route under the pointer, plain dots ahead and small faded dots for rooms no longer reachable; every room sits on
a soft ground shadow. The room you stand in shows the lantern; choosing a room walks the lantern along the trail for
0.62 s before travel (reduced motion skips the walk). Section VI fog keeps its openings for rooms on screen first.

## Revision 6 special encounters (spx-02)

`data/special_encounters.json` and the four map emblems are installed byte for
byte from `spec/peer_benchmark/staged/spx/`; `assets/art/icons/map/provenance.json`
retains the approved hashes. `SpecialEncounterLibrary` owns `definition(type)`,
`variant(type, biome)`, `enabled_types()`, `display_name(room)` and
`tooltip_line(room)`. Definitions and variants are private copies. Only Warband
is enabled; the other three concepts are registered but cannot spawn.

After the revision-5 type solver, revision 6 draws the weighted request of two
(weight 3) or three (weight 2), caps it by enabled types and feasible legal slots,
and converts rolled standard combats. With the current catalog every section
has exactly one Warband. The section RNG selects types and cells; a bounded
12,000-node search and canonical bounded repair preserve seed determinism. If
no special fits, the generator uses its existing deterministic legal topology
and repeats placement. Revisions 3–5 never execute this pass or consume its RNG.

Specials occupy steps 3 through S−2. They never replace mysteries (including
hidden combat), never share an edge with a Guardian, and satisfy their type’s
minimum outgoing-edge count (two for Umbral Snare). Types are distinct within
each section. Every complete route, including recombinations of the generating
walks, has at most two specials; if two or more are placed, at least two routes
contain one. At least one route has none. Special counts replace combat in fight
budgets. The underlying graph, Guardian rules, service rules and mystery fields
are preserved. All specials are landmarks, including through section VI fog.

A saved special has `type: "special"`, `special_type`, and `special_variant`
(the section dragon’s earth/fire/air/ice/lightning/shadow biome). The original
rolled combat element remains intact. Room entry, pre-battle, recovery, cleared
room handling and equipment pity treat special rooms as combat. RoomGenerator
receives all three fields; until spx-03 supplies its special combat rules, the
existing generic fight generation remains supported. The run captures the
starting enemy roster’s Ember sum in `special_starting_reward_embers` before
combat, so deaths, fleeing enemies, summons, saves and reloads cannot change it.

Successful specials offer four distinct cards: three from the room’s element
and one general offer in elemental rooms, or four general offers in neutral
rooms. The ordinary first three offers stay in place; the fourth uses the room’s
element filter (or the general pool for neutral rooms). If all four are below
Rare, only the last elemental slot, or the last slot in a neutral room, is
rerolled. It keeps that slot’s element filter and the usual rarity and card offer
weights among Rare/Epic/Legendary. An off-element deferred card replaces the
general slot; other deferrals use the first compatible slot. The Rare floor is
checked again after insertion, preserving all three elemental offers and
reserving the final slot for any required reroll without erasing the deferral.

The Ember reward replaces per-kill earnings with 1.5 times the starting roster’s
`reward_embers` sum, using the ordinary half-up rounding and combat omen scaling.
The existing regular-enemy depth rules have no Ember modifier. The usual combat
relic Ember bonus still applies. Warband’s equipment bonus forces the ordinary
room drop if necessary and resets equipment pity as a normal drop does. It uses
the existing pickup placement factory when RoomGenerator does not yet provide
special loot. Special rewards never offer relics and cannot be granted twice.
`objective.goal_met`, when present, is authoritative; a Warband victory otherwise
meets its unfailable goal. Future failable types must provide that saved result.
A failed goal receives standard cards and per-kill Embers; disabled bonus kinds
are intentionally deferred until their types are enabled.

Map titles read `Warband · <captain title>` from the biome variant, or the other
type’s name. Tooltips show title, the protected `tooltip_line`, then the existing
state line, identically for hover and focus. Medallion sizes, contours, animation,
availability, current, visited and bypassed states use the standard combat
presentation. Chronicle paths persist `special_<type>` in their existing string
schema and obtain the corresponding name and emblem from the catalog/registry.

Revision 6’s legend includes only concepts present in the displayed section,
ordered Standard combat, Warband, Umbral Snare, Ember Hoarder, Last Light,
Guardian combat, Event, Scavenger, Graftwright, Relic, Ember Hearth, Boss,
Unknown room. Native label widths determine an even gap from 40 down to 12px
beside Scout. Only if 12px cannot fit does it split into two centred rows; the
frame follows the existing 48px emblem height per row. Saved older layouts
retain their nine-concept legend and all existing probe assertions.

`special_type` and `special_variant` remain in the persisted room metadata read
by combat start/end context builders. spx-01 owns their analytics context fields;
this unit does not modify `analytics_store.gd`. The physical-door hover label in
`run_scene.gd::_room_hover_hint` reads the same library name for special rooms,
with its existing depth suffix. Starting-roster and goal-result metadata are
additive and use the ordinary save format.

### Special proof

- `tests/special_encounter_test.gd`: revision 6 at 64 seeds × 6 sections with
  exhaustive routes; nine pre-change golden graphs across revisions 3–5;
  future-enabled placement seam at another 64 × 6 sections; rewards, explicit
  roster overrides, omen scaling, equipment pity, replay protection, names,
  pre-battle/direct entry and production save/load repair. `--feedback-only`
  focuses on rewards/resume, 64 reward seeds across all five elements plus
  neutral, forced same-filter Rare floors, staged/installed emblem loading, and
  library names above physical doors. It also runs the assertion-free forced
  fallback regression in `tests/helpers/special_placement_regressions.gd`, paired
  one-exit/two-exit Snare fixtures across 64 seeds, positive equipment-pity resets
  through both entry paths, and `finish_combat` deferral integration including a
  general-only Rare offer. The full special suite counts outgoing edges and
  Guardian adjacency independently of production eligibility helpers.
- `tests/special_encounter_legend_test.gd`: fullest legal enabled section (seed 0,
  section II, ten concepts), independent literals for the approved thirteen-type
  order and labels, gaps, Scout clearance, and the two-row fallback at a
  debug-only 1000px legend width.
- `tests/test_special_encounter_assets.py`: protected JSON/provenance bytes and
  every approved emblem hash, plus a Windows typed-array source guard for new
  special scripts and the rarity helper; `tests/test_icon_identity_policy.py`
  includes all four distinct concepts. The UI identity lint remains unchanged.
- `tests/special_encounter_probe.gd`: eight real-renderer captures (future,
  available, pointer hover, native focus, visited, bypassed, fullest legend,
  section VI fog landmark), 1920×1080 at 100% UI scale in the project’s fixed-size
  capture viewport, independent of Retina desktop/window geometry. Pointer
  motion enters that viewport’s real GUI hit testing; the probe checks the
  hovered Warband button and the visible tooltip’s complete three-line text.
  `--logic-only` exercises all states, hover and focus headlessly, without
  claiming renderer captures; its debug-only 1280×720 root window verifies that
  capture geometry remains 1920×1080. Windowed execution and image inspection
  belong to the design owner, because the implementation sandbox has no macOS
  window-server access.

Generate the proof contract headlessly, then run the windowed proof on the
owner’s machine (each command starts in this task worktree):

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-02 && python3 tools/godot_task_runner.py --task-id spx-02 --stream -- godot --headless --path . --script tests/special_encounter_probe.gd -- --logic-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-02 && python3 tools/godot_task_runner.py --task-id spx-02 --stream -- godot --headless --path . --script tests/special_encounter_probe.gd -- --proof-contract-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-02 && python3 tools/visual_probe_runner.py --task-id spx-02 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract /private/tmp/labyrinth-inspection-manifests/spx-02-visual-contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/spx-02-visual-result.json tests/special_encounter_probe.gd
```

Captures are emitted under the runner’s isolated `user://spx-02-map-proof/`;
the probe prints its absolute directory and the result manifest records the
validated image paths. No capture is claimed from headless proof-contract
creation. The design owner owns the playable inspection fixture, image judge,
commit, peer review and publication.

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

Event rooms select authored encounters from `data/events.json`, with seeded
section-appropriate choices, trade-offs and timed omens. Choices and result pages
persist until Continue; travel remains blocked until the encounter finishes.
Legacy mid-event saves retain The Lost Cartographer and its choice ids. See
[events.md](events.md) for selection, rules, saves and the data-only authoring
contract.

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

On the first visit to a section's start room, closing the Emaciated Man's opening dialogue by pointer, keyboard or controller queues the existing map transition, including after leaving his level-up service. The map centers on the current room, retains its existing travel availability marks, and controller focus starts on the available room with the lowest lane. Room activation continues through the same physical-door travel, save and analytics boundary. Closing the map leaves working doors and the hint “Choose your path on the map [M]” for the rest of that visit, with the map-action glyph on controller. The existing hint plate is horizontally centered, its bottom 16 px above the visible bottom action buttons (Speak), or 72 px above the viewport bottom when no buttons are shown; text uses Text 17 px in TEXT_2. Repeated refreshes do not reopen it; loading clears this presentation state, and narration must replay and close to request it again. Other rooms and start-room revisits retain their existing flow. Sections II–VI currently lack opening NPC/narration data; `TODO_DESIGN_SECTION_START_NARRATION` in `start_room_map_flow.gd` reserves the owner's script while preserving those thresholds' existing automatic map handoff.

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

Authored events use the existing encounter panel for title, body, available and
disabled choices, then result text and Continue. Controller focus begins on an
available event choice and returns to route selection after completion. Event
card offers continue through the existing reward chooser. See [events.md](events.md).

Section tabs allow reviewing reached sections with discovered history intact.
After a non-final dragon reward, CONTINUE automatically descends to the next
section's entry room through the section title transition, without an
intervening map action. For destinations that auto-open their map, the title
cross-fades straight into the live section map at 2.60s over 0.40s, cubic in-out.
The title and band fade away as the map frame, header, nodes, paths and legend
fade in. The painting dims to the map's own background modulate and eases from
the title's pushed-in fullscreen crop to the exact map-field cover-fit rectangle.
The entry room loads underneath and remains covered until the map is closed;
no board reveal intervenes. Planning music starts once at this handoff.
Reduced motion uses a stationary 0.30s cross-fade after its existing hold;
skipping uses 0.12s. Destinations that cannot auto-open the map retain the
existing black arrival and room-entry reveal.
Loading a cleared boss room whose next section has not been entered replays
the transition. An entry-save failure reverses to the already-claimed reward
screen, where CONTINUE retries without granting rewards again. The final
dragon's COMPLETE ASCENT retains its existing completion path.
Future tabs are disabled and do not
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
new runs. New generation records `section_map_layout_revision: 6` for the
four-lane layout. That marker does not trigger regeneration: previously
saved section maps keep their exact stored connections. Legacy runs lacking the
section-map marker retain their original circular map and generation/repair rules. No in-progress run is converted to a different
route. New-run recovery maps lost Embers to an existing combat, special, Guardian or boss
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
independent of the travel list. `event` lists authored choices;
`event <choice_id>` resolves and `event continue` advances. Cartographer retains
`event embers|survey`. Event state, seen ids and omens resume through the same
save format; see [events.md](events.md).

## Owning checks

- `tests/section_map_v7_test.gd`: revision 7 over 40 seeds × 6 sections: lanes, row widths, non-crossing trails,
  route choices and gaps, lane-facing doors with no exit through an entry wall, scrolling positions with no touching
  rooms; saved revisions 5 and 6 match digests taken at the pre-map-03 base; the forced fallback obeys every rule and
  places special encounters; real pointer input on the panel (a drag from a room scrolls and never travels, activation
  after a drag, a sub-threshold click, the wheel over a room, the lantern held after a finished walk and reset on arrival).
- `tests/map_03_probe.gd`: native revision-7 captures (section start, mid-run, hover, the lantern's walk frames,
  scrolled end, section VI fog, a stepped scroll); `--logic-only` checks scroll offsets and the real-time walk.
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
