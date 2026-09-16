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
- Leave consumes nothing and resolves the encounter. Continue after a graft
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

Surface: a full-screen NPC workbench. The player question is “Which card do I
want to preserve in this equipment?” Graft is the single destructive commit;
Leave is always available before commitment. The highest-rarity compatible
recipient and a compatible donor are initially displayed, but no destructive
card selection is assumed. Single-card recipients and existing inherited slots
select their sole valid replacement automatically after a source is chosen.

The top equipment rail chooses what to keep; the compact donor rail filters to
the same type. Shared CardWidgets show real effective cards. The selected target
becomes an exact preview, with the replaced card named below it. Focus exposes
the card's exact rules in one detail line. The footer explicitly names the piece
that will be destroyed and any automatic equip or empty-slot consequence.
No confirmation wizard, currency transaction, or extra Next button is introduced.

Native buttons use UiSkin, UiTypography, and UiTooltipPanel. Pointer, keyboard,
controller activation, directional focus, Tab traversal, Back, and paged-inventory
focus recovery share the same workbench. Focus remains within the modal and never
defaults to Graft. The existing device prompt bar sits clear of the title and
names the focused action. The result's cards can be focused for rules inspection.

The ritual fades the sacrificed piece and unpicks its cards, carries luminous
violet strands into the chosen card, stitches the new pattern, then reveals the
surviving equipment and its final cards. Existing UI audio cues mark selection,
unpick, binding, and completion. Inputs are locked during this roughly two-second
sequence. Reduced motion omits strand travel and idle motion and resolves after
a short 0.18-second beat; the static result communicates the same outcome.

The artwork consists of independent ImageGen assets: a masked tailor portrait,
an empty gothic atelier, and a distinct needle/thread map emblem. Text, equipment,
cards, selection, and animation are all live UI. See the provenance manifest in
[graftwright_art.json](graftwright_art.json).

Design reference: [Monster Train's official unit-synthesis description](https://www.themonstertrain.com/dlc/the-last-divinity)
uses a whole-unit sacrifice to strengthen another unit. The inference applied here
is to keep both objects and the irreversible cost visible together. Deterministic
selection also follows the clarity goal reflected in
[Blizzard's 2.5 tempering notes](https://news.blizzard.com/en-us/article/24244466/diablo-iv-patch-notes-2-5).
These are mechanical references, not a claim that this UI reproduces either game.

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
with three cleared combats and accepts ordinary loadout options.

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
  save rejection, large inventory paging, and replacement of an inherited slot.
  Dispatches GUI pointer/key/controller events and asserts navigation and outcome.
- `tests/run_tests.gd`: full regression, including an end-to-end six-boss route
  that resolves Graftwright visits and retains the original victory assertions.
- `tests/test_icon_identity_policy.py`: unique map emblem registration.

UI rubric: immediate comprehension, hierarchy, gameplay visibility, compact copy,
state/consequence, interaction completeness, cohesion, accessibility, layout
resilience, and visual proof are checked on the states above. Inventory rails use
explicit page arrows, with no desktop horizontal scrollbars. Alternate resolution
and scale configurations are outside this task's requested proof matrix; normal
UI scaling remains supported by the workbench's fit-to-view canvas.
