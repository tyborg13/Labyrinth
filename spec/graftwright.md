# Graftwright equipment inheritance

The Graftwright is an optional non-combat encounter that gives surplus equipment
a use during the current run. Its workbench keeps the donor and recipient visible
together: select a card to carry forward, select the card it replaces, then Graft.
The whole donor is consumed. The recipient keeps its identity and card count.

## Rules and pacing

- Both pieces must be owned, distinct, and the same native equipment type.
- One graft is available per encounter, with no additional Ember charge.
- Each item has one inherited slot. Later grafts replace that slot; sacrificing
  the item can carry its inherited card onward, including its original provenance.
- An identical-card replacement is rejected before anything is consumed.
- Sacrificing equipped gear automatically equips the recipient. If Open Arsenal
  has both pieces equipped, the survivor occupies its native slot and the extra
  trinket slot becomes empty. The preview names this consequence.
- Skip consumes nothing and resolves the encounter. Continue after a graft
  returns to the ordinary map flow. Travel cannot bypass an unresolved encounter.

Section-map layout revision 3 converts about one fifth of eligible ordinary
service opportunities into Graftwrights. A service is eligible only after three
combats on **every incoming route**, calculated from completed group fight budgets
and preceding fights on the current branch. The runtime also requires three
cleared combat/boss rooms. Campfires, bosses, and the 66-room/40-fight route budgets
are preserved. Generation is seeded; saved older maps retain their original
topology. Legacy circular maps do not gain retroactive Graftwright nodes.

One inherited slot preserves a multi-card item's authored identity while allowing
an improved hybrid. Encounter frequency, one use, and sacrificing an entire item
are the initial limits; these are tuning choices for inspection. No card effect,
time cost, combat coefficient, or intrinsic heuristic assumption changes. Shadow
Step still scores 2.54 in the current heuristic. Hybrid-package strength needs
ordinary run playtesting; this implementation does not claim a measured win-rate
or economy balance result.

## Presentation and input

Surface: an NPC introduction followed by a full-screen workbench. The player
question is “Which card do I want to preserve in equipment I improve?” The
introduction uses the established dialogue material and explains same-type
pieces, one transferred card, replacement, and irreversible sacrifice in the
Graftwright's voice. **Browse equipment** opens the workbench; **Skip** resolves
the encounter without consuming anything. With no compatible pair, the dialogue
offers Skip directly. Dialogue is shown when entering an unused encounter; a
saved completed graft resumes its result without replaying the introduction.

Both **Sacrifice** and **Improve** start empty. Neither equipment nor cards are
selected by rarity or another heuristic. Empty mounts say **Choose**; selected
mounts say **Change**. Either piece may be chosen first. Choosing an incompatible
Improve type clears the old sacrifice instead of silently supplying another.
Single-card recipients and existing inherited slots still select their sole
valid replacement after a source card is chosen. Graft is the single destructive
commit; Skip remains available throughout the uncommitted workbench.

The work trays have opaque bronze rims and stitched title/footer rails, with
translucent suede centers that reveal the atelier. Empty trays are compact and
expand only when their equipment's cards need space. Equipment rows combine a
recessed mount with a name and concrete equip/destroy consequence. Equipment
textures use cached visible-alpha bounds, so transparent source padding cannot
offset the item in its circular aperture. Headings, browser Back, replacement
names, and the consumed-equipment label are centered in the artwork's measured
rails. Shared UI fonts use restrained top lighting, fine texture, and a soft
shadow rather than a blanket thick outline; dialogue body text remains plain.

Red **Sacrifice / Will be destroyed** and green **Improve / Stays equipped** (or
the actual inventory/equip consequence) identify each piece. Clicking a mount
opens a native scrolling five-column grid grouped by Weapon, Offhand, Armor,
Boots, and Trinket. Every category is browsable, including empty categories.
Incompatible sacrifices are disabled; the footer names the required type and
provides **Choose equipment to improve**, preserving the browsed category.
Recipient choices without another matching piece identify that missing pair.
Counts, equipped/improving markers, and selection remain visible. Choosing an
item immediately returns to the workbench; Back preserves the current selection.
The browser hides the prior controls so its transparency reveals only the
atelier, never ghosted cards or overlapping labels. There are no horizontal
pagers or mixed equipment rails.

Shared CardWidgets show the actual effective cards on both sides. A violet
**Carry forward** treatment identifies the source, dimmed **Lost** cards explain
the rest of the sacrifice, and red **Replaced** identifies the recipient's old
card. That old card stays visible until commitment. An attached old-name →
new-name strip makes the final replacement explicit. The finished card is green
and marked **Inherited**. These cues use text and shape as well as color.
The Graft action is a purpose-built needle-and-thread clasp. No generic action
skin is stretched behind an item or card, no card selection commits implicitly,
and no confirmation wizard or extra Next button is introduced.

Native Buttons preserve pointer, keyboard, controller activation, directional
focus, Tab traversal, and Back. The grid traps focus while open and scrolls with
focus. Its whole canvas, including its dimmer, renders above CardWidget's raised
cost badges. Padding inside the scroll viewport protects focus brackets. Pointer
and keyboard interaction use lift, soft glow, and selection ribbons. Corner brackets appear
only on the focused controller object; switching back to keyboard or pointer
removes them. Focus never defaults to Graft. The device prompt bar names the
focused action and shows Skip before commitment, Continue on the result, and Back while browsing
equipment or inspecting a card. Right-click, F1, or controller Y opens a deliberate, anchored rules popover; Back restores
focus without selecting or consuming anything. The native per-icon tooltips are
retained. Result cards can be inspected with Accept; initial result focus remains
on Continue. Ordinary card selection never opens this popover.

The [durable copy preference](game_ui_rubric.md#durable-player-preference-relevant-anchored-copy)
forbids decorative floating taglines and automatic repetition of visible card
rules. This screen uses only anchored identity, action, state, or consequence
copy. Save failure and the Open Arsenal empty-slot consequence have dedicated
backing; ordinary selection does not produce a bottom-of-screen explanation.

The ritual first lowers the Graftwright's occupied forearm toward the sacrifice
(0.44 seconds), then lifts and carries the chosen real card along interwoven
violet silk into the replacement slot (1.8 seconds). The donor equipment stays
visible throughout transfer. Once the inherited card lands, its ribbon changes
to **Inherited** and the entire sacrifice panel unravels from top to bottom over
0.72 seconds. A CanvasGroup includes the frame, paint, labels, equipment, and
raised cost badges in one dissolve: a fine luminous violet edge and irregular
paint fragments reveal the original workshop beneath. The surviving panel is
untouched. The silk finishes fading while the donor unravels.

Input stays locked for the roughly three-second sequence; the transaction is
still saved before any animation. The result fades in over 0.28 seconds only
after dissolution completes. **Completed equipment, its frame and shadow remain
stationary**; completion bobbing is explicitly retired. Reduced motion omits
gesture, travel, and disintegration and resolves after the existing 0.18-second
beat. The static result communicates the same consumption and inherited card.

The existing masked tailor remains behind a foreground layer taken from the
exact original atelier: the bench and separately traced silhouettes of the
thread spools, pincushion, pins, and draped cloth occlude the portrait during its
segmented idle. Texture-mapped polygons sample the original painting at
its source coordinates; no rectangular background patch cuts across the body.
Portrait and bench share the same fit-to-view coordinate space, so their perspective does not drift with viewport size. Additional ImageGen art
provides a quiet workmat, recessed equipment cradle, and ritual clasp. Text,
cards, selection, and animation are all live UI. Exact new prompts, source paths,
and hashes are in [graftwright_art.json](graftwright_art.json).

Design references: [Monster Train's official unit-synthesis description](https://www.themonstertrain.com/dlc/the-last-divinity)
uses a whole-unit sacrifice to strengthen another unit. The inference applied here
is to keep both objects and the irreversible cost visible together. Deterministic
selection follows the clarity goal in [Blizzard's 2.5 tempering notes](https://news.blizzard.com/en-us/article/24244466/diablo-iv-patch-notes-2-5).
[Last Epoch's crafting developer post](https://forum.lastepoch.com/t/crafting-changes-coming-to-eternal-legends-update-0-8-4/45597/1)
places the concrete gains and costs in a crafting outcome panel. Our application
is an anchored replacement strip and result, rather than a detached instruction.
These references inform the design; this UI does not reproduce their layouts.

## State and integration

`equipment_grafts[equipment_id] = {index, card_id, source}` is run-only state.
`GameData.equipment_cards(id, run_state)` overlays one entry onto immutable authored
data; deck compilation, live loadout details, and shop inspection use that view.
The global Grimoire describes authored equipment. Selling or sacrificing an item
removes its graft record. Existing collected-item drop exclusions remain in place;
later shop copies have their authored cards. No grafts enter the progression
profile or a new run.

`GraftwrightRules.apply` validates the full request before duplicating a committed
transaction. It removes the donor, updates equipment and deck, marks the room
used/cleared, and stores its result and one outbox event. The live scene saves this
snapshot **before** starting the ritual. A save rejection leaves the original
equipment and a retryable preview; a reload during the ritual opens the finished
result. Repeated requests cannot consume twice. Analytics use the existing saved,
append-only map outbox and idempotency keys; see [analytics.md](analytics.md).

The manual console exposes `graft KEEP_ID DONOR_ID SOURCE_INDEX TARGET_INDEX`
with zero-based indexes and `leave`. It saves through its normal isolated session
boundary. `inspection_fixture.py --scenario graftwright` uses a generated room
with three cleared combats and accepts ordinary loadout options. The main menu
recognizes Graftwright saves both before and after the ritual, displays the saved
encounter in its resume summary, and keeps Continue available. Fixture verification
checks that same menu predicate as well as the persisted state contract.

## Verification and UI rubric

- `tests/graftwright_test.gd`: atomic validation, same-type rules, carry-forward,
  one inherited slot, save serialization/repair, Open Arsenal, equip/re-equip,
  sales, profile separation, normal map entry, onward combat deck, and minimum
  combat counts on every incoming edge across 64 seeds.
- `tests/graftwright_console_test.gd`: actual console parsing, persisted graft,
  repeat protection, leave, and one append-only analytics event after replay.
- `tests/graftwright_probe.gd`: native Metal-rendered 1920x1080 SubViewport at
  100% UI scale. Source images are not resized. Covers initial, selected, ritual,
  result/reload, no donor, controller, reduced motion, map, three-card equipment,
  save rejection, categorized large inventories, source-only selection, modal
  pointer/focus isolation, explicit pointer/F1/controller rule inspection, and
  replacement of an inherited slot, entry dialogue, empty mounts, either item
  chosen first, incompatible-category recovery, and equipment-preserving Skip
  from dialogue, empty inventory, and workbench.
  Dispatches GUI pointer/key/controller events and asserts navigation and outcome.
- `tests/graftwright_motion_probe.gd`: native 1920x1080 animation frames with
  timestamps; pixel comparisons prove that the portrait moves while the bench
  and above-counter spools remain in front, and the result equipment remains stationary. It records preparation, transfer,
  dissolution, and result in order, plus the reduced-motion transaction.
- `tests/main_menu_resume_test.gd`: production-menu eligibility before and after
  a graft, saved encounter label, unchanged save contents, and rejection of a
  mismatched room type.
- `tests/graftwright_resume_probe.gd`: copies the actual generated fixture into
  an isolated namespace, clicks Continue in the real main menu, completes a graft,
  then returns through a fresh menu using controller input to resume the result.
  Captures native 1920x1080 menu, entry dialogue, and workbench states at 100% UI scale.
- `tests/run_tests.gd`: full regression, including an end-to-end six-boss route
  that resolves Graftwright visits and retains the original victory assertions.
- `tests/test_icon_identity_policy.py`: unique map emblem registration.

UI rubric: immediate comprehension, hierarchy, gameplay visibility, compact copy,
state/consequence, interaction completeness, cohesion, accessibility, layout
resilience, and visual proof are checked on the states above. Equipment browsing
uses a type-organized grid with vertical scrolling and no horizontal pagers. Alternate resolution
and scale configurations are outside this task's requested proof matrix; normal
UI scaling remains supported by the workbench's fit-to-view canvas.

### Interaction and cutout refinement

The player still chooses a sacrifice, an item to improve, and the card swap. This pass makes those two roles and the completed graft the largest in-panel headings, gives every active control distinct pointer-hover, navigation-focus and held states, and encloses gear behind the painted cradle lip. The completed framed assembly remains still over a grounded shadow. The existing NPC painting becomes a front-only editable cutout with a coordinated torso, head and needle-hand idle; the counter and its props stay in front. Proof covers native 1920×1080/100% hover/press and input handoff, the complete cutout idle, reduced motion, and real graft/save/resume behavior.

### Final ritual flourish

Design statement: on the existing Graftwright workbench, the player has already
committed a clear card swap. The new motion connects the NPC's needle to that
transaction, then visibly consumes the donor only after its card has arrived.
The unchanged source/target hierarchy, shared CardWidgets and result panel carry
all rules and consequences; the effect adds no copy or decisions. Pointer,
keyboard and controller keep the same input lock and result focus, while reduced
motion bypasses the spectacle. Native 1920×1080/100% proof covers the whole gesture,
the dissolve at multiple heights, the result transition and stationary mount.
