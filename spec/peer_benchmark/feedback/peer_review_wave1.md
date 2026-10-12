# Peer review wave 1 (master..8c71fa17b) — reviewer subagent report

## Peer review: `master..8c71fa17b` (ev-01, ev-02, feel-01, biome-01, sfx-00 + director fixes)

**Verdict: REQUEST_CHANGES at 8c71fa17b.** There are 2 major findings and no blockers.

Note: the worktree HEAD moved to 83b26b846 (itb-02/map work landed) while I was reviewing. Every line number below comes from `git show 8c71fa17b:<file>`. I changed nothing in the worktree. The one repro script lives in my scratchpad.

### Findings, most severe first

**1. MAJOR: `Engine.time_scale` can stay at 0 for good, even after the run scene exits.**
- **Where:** `scripts/combat_pacing.gd:112-117` (`_begin_scope`).
- **What breaks:**
  - If a hit-stop is active with no scope (any hit shown while `_animation_lock` is on outside a card or enemy scope, such as movement collisions, traps or fatigue), `_begin_scope` sets `_base_scale = Engine.time_scale`, which is `0.0` at that moment.
  - From then on, `current_scale()` (:119-122) returns 0, the hit-stop restore (`combat_hit_stop.gd:63`) writes 0, and `end_scope` (:167-169) writes 0.
  - `present_hits` (:391) guards this exact case for itself; `_begin_scope` does not.
- **Confirmed with a headless repro** (fixture owner, scope-less `present_hits`, then `begin_card()`): `time_scale` stayed at 0.0 after 400 ms, after `end_scope()`, and after the owner node was freed.
- **Reachability:** the main movement path waits on the presentation clock, so the trigger is uncommon. Still, nothing rules out `begin_card`/`begin_enemies` starting inside a 40–130 ms scope-less stop, and the result is a game-wide freeze of every timer and tween.
- **Fix:**
  - When the scope is empty, set `_base_scale = hit_stop.previous_scale if hit_stop.active else Engine.time_scale` (expose `_previous_scale`).
  - Never adopt or restore a base scale ≤ 0: clamp to 1.0 in `_apply_speed` and `end_scope`.
  - Add a suite case: scope-less request → `begin_card` → wait → assert the scale is back to speed/1.0.

**2. MAJOR: Combat rules changed for players without omens (player Expose).**
- **Where:** `scripts/combat_engine.gd:4671-4673`. `_damage_player` now adds and consumes `player.expose` on every direct hit.
- **What breaks:**
  - Master already applies Expose to the hero from two enemy intents (`combat_engine.gd:6114-6115`) but never consumed it:
    - Bile Bloomer "Shard Mark" (`data/enemies.json:607`, expose 2)
    - Noctyrax "Void Claw" (`data/enemies.json:1569`, expose 1)
  - In every run, the next hit after those attacks now deals +2 / +1. That breaks ev-01's "combat rules for players without omens are byte-identical".
  - The changed mechanic hasn't been scored with the balance heuristic (AGENTS.md), and `spec/events.md:123` describes only the omen use.
  - The suite's "No-omen combat state is byte-identical" check (`event_rules_suite.gd:451-454`) can't detect this.
- **Fix, either option:**
  - Gate it: keep omen Expose in its own field, e.g. `player["omen_expose"]`, consumed only in `_damage_player`.
  - Or get explicit owner sign-off: score Bile Bloomer/Noctyrax, document the change, add a regression test for enemy-applied hero Expose, and confirm intent and lethal previews include it.

**3. MINOR (presentation risk and performance): overlay refresh repeats the board render every frame and can leave a stale board.**
- **Where:** `combat_pacing.gd:179-193`.
- **What breaks:**
  - `_process` re-renders `_last_state`/`_last_presentation` through `_render_board_state` every frame while any popup, flash, death or surface overlay is still alive, whether or not a scope is active.
  - During animations this doubles the heaviest per-frame call (`run_scene.gd:25573`).
  - After `finish_enemies` (`run_scene.gd:24243`, which runs before the pickup, victory, fatigue and draw flows), it can overwrite the planning view that `_refresh_stage_view` submits directly (`run_scene.gd:18031`). When the overlays expire it leaves that last animation frame on screen, because nothing refreshes the stage afterwards.
- **Fix:** skip the refresh if a render already happened this frame, only refresh while a scope is active, and clear retained overlays (or ask the scene to refresh the stage) at scope end.

**4. MINOR (test regression): an existing probe is broken.**
- **Where:** `tests/section_map_flow_probe.gd:181,184,188,196` still use `_event_panel`/`_event_embers`, which ev-02 (db94d2120) removed from `section_map_panel.gd`.
- **What breaks:** the probe dereferences null and crashes.
- **Fix:** drive `_event_view` (choose → Continue), or move that coverage into the real-scene flow `event_view_suite` already has.

**5. MINOR: Windows `Array[T]` rule violations.**
- Production: `scripts/combat_pacing.gd:275` (`var hits: Array[Dictionary] = []`) and `:338` (`deaths`).
- Probe: `tests/combat_feel_probe.gd:85` (`Array[String] = ["normal"]`) and `:226` (a non-empty literal, the exact pattern that fails on Windows).
- **Fix:** declare without an initializer, or use `.assign()` / a typed helper.

**6. MINOR (UX): the pause menu can't be reached while an event is open.**
- **Where:** `event_view.gd:355,366` returns true for every key and joypad press, and `run_scene.gd:2117-2119` returns before any other handler. The view also covers the HUD (full-rect, `MOUSE_FILTER_STOP`, z 1200).
- **What breaks:** no menu, settings or save-and-quit until the event is resolved.
- **Fix:** let the menu/Start action pass through.

**7. MINOR (robustness): the event view can soft-lock.**
- **Where:** `activate_choice` sets `_busy = true` (`event_view.gd:333`) and relies on a new `present()` signature to clear it.
- **What breaks:** if the scene ignores the request (`_on_section_map_event` returns early on `_animation_lock`, `run_scene.gd:34584`) or the rules return the same state, `present()` returns early (`event_view.gd:161`). All further input is then dropped.
- **Fix:** clear `_busy` when the signature hasn't changed.

**8. MINOR: allocations added to hot paths.**
- **Biome lookup on every animation frame:** `run_scene.gd:18048-18052` `_apply_biome_presentation` runs inside every `_render_board_state` (:25788). Each call does a deep copy in `room_metadata`, deep-duplicates `Biomes.definition()` (`biome_library.gd:38-40,124-125`) and calls `OS.get_cmdline_user_args()` (`biome_library.gd:42-48`). Cache the biome id and colours when the room changes.
- **Movement capacity for every run:** `combat_engine.gd:2852-2856` `player_movement_capacity` → `OmenRules.first_movement` (`omen_rules.gd:85-86` → 45-55 → 9-15) allocates two typed arrays per call even with no omens, and pathing/AI forecasts call it often. Return early when `omens` is empty or the turn isn't 1.
- **Board draw:** per-tile `{}` default allocations at `combat_board_view.gd:16712` (`_draw_board_surface`) and `:9052` (`_unit_impact_strength`).
- No per-frame texture loads were found; biome textures are cached by path.

**9. MINOR (analytics): event card claims and skips look like combat rewards.**
- **Where:** they're logged as ordinary `reward_choice` with `choice_kind: "heal_skip"` (`run_scene.gd:27383, 32868-32877`).
- **Fix:** add additive `reward_kind: "event"` and `event_id` fields (the pending reward already carries them, `event_rules.gd:181`) and update `spec/analytics.md`.

**10. MINOR: Combat speed applies to the victory beat in one case only.**
- **Where:** when a card lands the killing blow, `_play_post_combat_victory` (`run_scene.gd:22311` / `22407`) runs while the mode is still "combat" (it's set at :22314 / :22411) and the card scope is still open.
- **What breaks:** the victory overlay plays at Fast/Fastest. When the enemy phase ends the fight, the scope is already closed (:24243), so it plays at 1.0. The brief says rewards always run at 1.0.
- **Fix:** call `end_scope()` before the victory presentation.

**11. MINOR: architecture drift.**
- **`combat_pacing.gd` depends on run_scene internals:** it reaches into about 12 private members by string, at :152, 175-182, 193, 263, 284, 346, 415-451 and 470. Renames would only break at runtime.
- **Duplicated presentation:** it also runs a second, enemy-phase-only path for defeat dissolves, ground feedback and popups, separate from run_scene's.
- **Rules helpers call engine internals:** EventRules/OmenRules call private RunEngine/CombatEngine methods (`event_rules.gd:224,266,296,327,346`; `omen_rules.gd:67`).
- **run_scene growth is within budget:** +84/−19 total; added lines per unit are ev-01 11, feel-01 33, ev-02 31, biome 9.

**12. MINOR (sfx director fix): the loudness-tolerance waiver keys on the wrong signal.**
- **Where:** `tools/sfx_lab/build.py:162-163` waives the tolerance whenever the encoded peak is ≥ −1.5 dBFS, not when normalization actually applied its cap (`peak_cap_applied`, `common.py:343`).
- **What breaks:** a loud, uncapped take with encoder drift can pass outside tolerance. Neither director fix (no-clip cap, tolerance waiver) has a test.
- **Fix:** key on `peak_cap_applied` and add two tests.

**13. NIT: reforge can consume an owned pack item.**
- **Where:** `event_rules.gd:235-258`.
- **What breaks:** reforge can pick a piece already in the pack, silently removing that copy and destroying its grafts.
- **Fix:** exclude owned pieces, as `_gear_or_relic` already does.

### Your seven questions

1. **Saves, omen ticks and time scale.**
   - Saves are sound. Choosing applies effects and moves to the result page in one step (`event_rules.gd:147-172`), and choosing again on the result page is rejected. On load, `repair_loaded_run_state` re-enters the event with its saved event state (`run_engine.gd:362-363`). Continue clears the room and opens the card choice (`event_rules.gd:174-184`). Claims are checked against the offer, reroll is blocked, and Skip grants nothing. Save/load is tested on the choices page, the result page and the card chooser (`event_rules_suite.gd:527-575`). I found no way to apply an effect twice.
   - Omens tick once on victory (including Reach Exit escape, guardian and boss), defeat, and before Last Door retreat (`run_engine.gd:1208-1212`, retreat at :1222). A per-room `omen_combat_finished` flag prevents a double tick and is cleared on combat entry (:961, :1144). Last Door keeps the run state, so the tick sticks.
   - Time scale: pause/menu, map, modals and leaving combat mode all fall back to the base scale. Ending combat mid-stop and leaving the scene both restore it. SFX timers ignore time scale. The one defect is finding 1.
2. **Determinism.** Every no-omen path returns early. The Hunted extra enemy uses its own salted RNG. Biome is derived and never saved. Hit-stop and pacing are presentation-only; the feel suite checks the card's resolved state equals the resolver's. The exception is finding 2.
3. **Windows typed arrays:** see finding 5. I found no conditional (`x if c else arr`) assignments to typed arrays.
4. **Architecture:** see finding 11. Growth is within budget.
5. **Test quality:** edits to existing suites are adaptations, not loosening. `section_map_suite` now asserts the result page then Continue, and expects 30 Embers per the new data. The dragon_boss, graftwright and review-probe tests pick the first available choice and skip event rewards. No assertions were deleted. Gaps: the broken flow probe (finding 4), no test for finding 1, and the omen byte-identity test is too weak to catch finding 2.
6. **Licence/IP:** clean.
   - Provenance: `spec/assets/events/hashes.json` has 38 records (27 paintings plus 11 seals) with raw and output hashes, and `spec/assets/biomes/raw_sha256.txt` has 36 biome raws.
   - The sfx tools reject `mixkit` / `sfx-sources-excluded*` paths, including through symlinks (`common.py:71-78`), and this is tested.
   - No audio files are committed, and the excluded folder appears only in docs and tests.
7. **Performance:** see findings 3 and 8. I found no O(n²) loops over the board per frame.

### Tests I ran

| Test | Result |
|---|---|
| `test_icon_identity_policy` | 6 OK |
| `test_process_event_art` | 3 OK |
| `test_process_biome_art` | 6 OK |
| `test_sfx_lab` (sfx venv) | 19 OK |
| Headless Godot repro of finding 1 | Confirmed the freeze |

Repro script: `/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/020b9ac4-7b92-4113-a7d2-bc6e802828dd/scratchpad/repro/hitstop_scope_repro.gd`

**Verdict: REQUEST_CHANGES at 8c71fa17b** (major 1: time-scale freeze; major 2: player Expose rules change for runs without omens).
