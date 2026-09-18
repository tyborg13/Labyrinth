# Board pickup feedback

## Surface and intent

The combat board answers “what did I collect, and where did it go?” after walking,
using a movement card, or being moved by an enemy. The acquired object's existing
icon travels with the established acquisition beam to its hand slot, draw pile,
or inventory button. The hand, pile count, and inventory remain the lasting
ownership evidence. Reduced Motion instead shows the same icon at the destination
with a short anchored receipt. Effects ignore input and release before actions
unlock; pointer and controller collection retain their normal activation paths.

## Investigation and presentation contract

The destination beam existed in `04e17b456` (August 29, 2026) and remains in the
current code. Normal walking still triggered it during the September 18
reproduction. It was a faint, brief streak while the acquired icon stayed at the
source. Reduced Motion deliberately skipped the beam, leaving only an ITEM FOUND
or GEAR FOUND banner at the source. Enemy-phase feedback enumerated item cards
only, so equipment collected through forced movement had no acquisition cue.

`RunScene._animate_board_pickup_acquisitions` now serves both player and enemy
presentation boundaries. It includes newly claimed item cards and equipment,
ignores missed loot and already-claimed objects, and preserves the existing
per-copy hand destination mapping. Acquisition rules, timing costs, saves, and
analytics are unchanged.

- With ordinary motion, the existing item/equipment icon follows the beam's
  progress and shrinks into the receiving location. Pickup beams receive a small
  opacity increase; other loadout/relic effects retain their existing treatment.
- A movement-card action's intermediate snapshot still contains the played card.
  Hand geometry excludes that departing slot, as the draw presentation does.
- A controller-focused board tucks the hand below the viewport. Hand receipts
  retain the incoming slot's horizontal position and stay 32 pixels above the
  viewport bottom so the arriving icon remains visible.
- Reduced Motion uses a stationary icon plus IN HAND, NEXT DRAW, or IN INVENTORY
  for 0.45 seconds. The source banner ties collection to the board. No travel,
  spin, scale tween, destination pulse, or beam is created for this path.
- Transient icons, beams, and receipts are cleaned up before the input lock ends.
  Multiple pickups remain distinct; presentation grants no objects itself.

## Verification

Run the focused rules test through the task runner:

```sh
python3 tools/godot_task_runner.py --task-id <task-id> --stream -- godot --headless --path . --script tests/item_pickup_test.gd
```

Use the production scene and real renderer at 1920x1080 / 100% UI scale:

```sh
python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --timeout 60 --expect-size 1920x1080 --result-manifest <fresh-manifest.json> tests/item_pickup_probe.gd --task-id <task-id>
```

The probe covers ordinary hand/draw/inventory destinations, equipment, movement
cards, controller activation and focus recovery, pointer handoff, Reduced Motion
for all destinations and the tucked controller hand, and a real Chainbound Gaoler
pull collecting both an item and equipment. It asserts visible beam progress,
icon identity and travel, exact target geometry, onscreen arrival, committed
ownership, and cleanup. Existing tooltip, pile activation, duplicate pickup slot,
post-pickup movement/alignment, and navigation checks remain in the same probe.

The old probe accepted mere beam-node existence and captured its invisible first
frame. It now waits for visible progress. Hand assertions use the production
hand-widget lookup because native `find_children` type filtering does not reliably
resolve the script-defined CardWidget class in a clean worktree.

The full Godot suite was also exercised for the shared presentation boundary.
No balance or icon registry changes are involved. Hardware controller validation
and alternate resolutions/scales are outside this focused proof.

## UI rubric record

| Gate | Result |
| --- | --- |
| Immediate comprehension | Pass: the acquired identity moves to its receiving location; ownership persists afterward. |
| Visual hierarchy | Pass: the existing short source flourish precedes one directional transfer. |
| Gameplay visibility | Pass: no new modal or persistent board obstruction. |
| Compact, precise copy | Pass: Reduced Motion receipts use two or three destination words beside the destination. |
| State and consequence | Pass: actual ownership, distinct item icon, and destination agree. |
| Interaction completeness | Pass: pointer/controller activation, focus recovery, pile keyboard acceptance, and modality handoff exercised. |
| Visual cohesion | Pass: existing icons, acquisition effect, banner, and UiTypography roles are reused. |
| Accessibility | Pass: stationary destination identity and text replace travel with Reduced Motion enabled. |
| Layout resilience | Pass: all proof uses 1920x1080 / 100%; receipts and controller arrivals remain onscreen. |
| Visual proof | Pass: the focused real-renderer probe captures visible transfers and stationary receipts for pixel inspection. |
