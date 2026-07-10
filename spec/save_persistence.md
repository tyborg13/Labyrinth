# Run Save Persistence

`user://current_run.save` is the authoritative resumable run slot. It remains a
Godot `store_var` dictionary for backward compatibility. Writes use a validated
temporary file and a short-lived `.backup` during replacement so an interrupted
write can recover the last complete dictionary. Loading prefers the live slot
and falls back to that backup only when the live value is unreadable or is not a
dictionary. A known-valid backup is never removed until either the previous
valid live slot has replaced it or the new validated temporary file is live.

## Committed boundaries

RunScene persists only after an irreversible mutation is internally coherent:

- New run creation, room travel, and pre-battle combat start.
- A full card play or the Basic Attack/Basic Move fallback. The checkpoint
  includes every resolved action in a compound card, the removed hand card,
  destination pile, health cost, card-play/time counters, player/enemy/terrain
  changes, pickups, traps, loot, deck order, elemental intensity, statuses, and
  RNG state.
- Pass or automatic player-activation completion, including the scheduled
  player timeline entry.
- Enemy initiative activation, start-of-turn status resolution, every resolved
  enemy action, post-action RNG state, intent reassignment, rescheduling, and
  the next player-turn preparation/draw. CombatEngine emits full commit steps
  between presentation steps; RunScene saves each commit before animating it.
- Combat completion and the resulting reward, room, victory, or defeat state.
- Card/heal reward choice, relic claim, merchant transaction, campfire continue
  choice, equipment/magic/item loadout change, card upgrade, level-up, and
  Grimoire/tutorial progression changes embedded in the run.

While an animation plays, RunScene holds the latest committed run dictionary
separately from the displayed before/after snapshots. Window-close and explicit
save paths read that held dictionary, so they cannot overwrite a newer commit
with the pre-animation state. Once presentation catches up, the normal run and
combat dictionaries replace the hold.

Pass and intermediate enemy checkpoints include a bounded
`pending_combat_checkpoints` continuation cursor. Its entries are already
resolved, coherent combat snapshots with their post-action RNG state—not an
action or animation cursor. Continue consumes and persists those snapshots in
order until the next playable player turn or terminal outcome. This prevents an
empty actor from becoming a second player activation and prevents relaunch from
re-running enemy actions, RNG, counters, or start-of-turn effects.

Terminal victory/defeat progression is finalized at the committed boundary
before the resumable slot is cleared. This prevents a close during the terminal
animation from restoring the last combat or losing ember banking/recovery data.
If profile persistence fails, the resumable slot keeps the unprocessed terminal
snapshot, including held embers, so a later resume can retry exactly once.
Campfire Embrace likewise clears the run only after the bank/rest profile write
succeeds; a failed write leaves the previous resumable run unchanged.

## State intentionally excluded

The save never includes hover state, card drag state, a selected but uncommitted
card/target/orientation, shortcut preview state, tooltips, focus, animation
frames, board presentation overrides, or other modal UI state. These are reset
when a run is loaded. A compound card is saved only after all required/optional
target decisions have produced its final coherent combat result.

## Resume and namespaces

Resume loads the complete run dictionary and repairs missing legacy defaults
through `RunEngine.repair_loaded_run_state`. Combat state already contains board
positions, ordered piles, HP/defenses/statuses, actors, initiative clock/queue,
action counters, room loot, and `rng_state`. A pending combat continuation
advances through saved post-action snapshots; it never calls enemy action
resolution again.

Inspection fixtures use the same relative `user://current_run.save` contract in
an isolated custom user directory. Running `tools/inspection_fixture.py` again
intentionally resets that namespace to the fixture's starting moment. Merely
quitting and relaunching its printed launch command does not rerun the generator,
so Continue resumes the latest in-session commit exactly like a normal run.
