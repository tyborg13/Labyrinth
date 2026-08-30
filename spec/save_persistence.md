# Run Save Persistence

`user://current_run.save` is the authoritative resumable run slot. It remains a
Godot `store_var` dictionary for backward compatibility. Writes use a validated
temporary file and a short-lived `.backup` during replacement so an interrupted
write can recover the last complete dictionary. Loading prefers the live slot
and falls back to that backup only when the live value is unreadable or is not a
dictionary. A known-valid backup is never removed until either the previous
valid live slot has replaced it or the new validated temporary file is live.

`user://progression.json` uses the same validated temporary/current/backup
replacement for permanent progression. Loading falls back to the last complete
profile when the live JSON is corrupt or an interrupted replacement leaves only
the backup, so an update or migration cannot truncate learned skills, embers,
Moltshards, discoveries, or run history.

Progression schema 7 stores first-run onboarding under
`guided_combat_tutorial` as a versioned record with `status` and
`completed_steps`. The completed-step list contains only committed gameplay
milestones; hover, focus, selected cards, open previews, targets, and other
transient motor phases are deliberately reconstructed from the current run on
resume. A brand-new profile starts `active`. Profiles from an older schema that
have already begun a run—or that contain the retired
`combat_micro_prompt_states` notes—migrate to `legacy_exempt`, so an update does
not force veteran players through onboarding. Explicit replay resets just this
record, while completion and dismissal remain permanent profile choices. Every
runtime tutorial mutation increments `progression_revision` and is mirrored into
the resumable run at the next committed persistence boundary.

## Committed boundaries

RunScene persists only after an irreversible mutation is internally coherent:

- New run creation, room travel, and pre-battle combat start.
- A printed card play. The checkpoint includes every resolved action in a
  compound card, the removed hand card, destination pile, health cost,
  card-play/time counters, player/enemy/terrain changes, pickups, traps, loot,
  deck order, elemental intensity, statuses, and RNG state.
- Each committed use of the independent player movement pool. The checkpoint
  includes the resolved path and destination, remaining and total movement,
  player/enemy/terrain changes, pickups, traps, loot, statuses, and RNG state.
- Pass and player-activation completion, including the scheduled player
  timeline entry. Exhausting card plays alone does not end the activation,
  because the player may still spend movement before passing.
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
Pre-cursor saves written during the older pass animation can contain an empty
`current_actor` plus the queued timeline. Load recognizes that exact legacy
shape, marks it as a transition, builds the same deterministic snapshot cursor
from its saved RNG state, and persists the repair before continuing.

Terminal victory/defeat progression is finalized at the committed boundary
before the resumable slot is cleared. This prevents a close during the terminal
animation from restoring the last combat or losing ember banking/recovery data.
If profile persistence fails, the resumable slot keeps the unprocessed terminal
snapshot, including held embers, so a later resume can retry exactly once.
Explicit save/quit checks the held committed state during terminal presentation
and never replaces that unprocessed terminal snapshot with the finalized display state.
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
action counters, player movement capacity/remaining, room loot, and `rng_state`. A pending combat continuation
advances through saved post-action snapshots; it never calls enemy action
resolution again.

Each newly written run carries `run_content_schema`. A save below the current
schema is migrated as a complete Variant graph before Grimoire normalization or
other subsystem repair, because content ids can appear in loadouts, card piles,
rewards, merchant state, loot ids, relics, intent state, analytics context,
dictionary keys, and pending combat snapshots. Exact aliases restore current
card, equipment, relic, intent, and structural terrain ids; known ids inside
namespaced or composite strings are replaced longest-first. Any remaining
retired vocabulary token in denormalized notices or logs is neutralized. The
same pre-normalization pass repairs profile discovery ids.

After a successful one-time repair, RunScene stamps the current schema and
immediately writes the repaired run through the validated temporary/backup
replacement pipeline. It also persists a changed profile separately. This
prevents quitting before the next gameplay boundary—or cloud synchronization—
from restoring the pre-migration binary. Current-schema saves skip the recursive
scan on later resumes.

Inspection fixtures use the same relative `user://current_run.save` contract in
an isolated custom user directory. Running `tools/inspection_fixture.py` again
intentionally resets that namespace to the fixture's starting moment. Merely
quitting and relaunching its printed launch command does not rerun the generator,
so Continue resumes the latest in-session commit exactly like a normal run.
