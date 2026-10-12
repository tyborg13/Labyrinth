# fix-01 — Peer-review fixes for wave 1 (ev-01, ev-02, feel-01, biome-01, sfx-00, itb-02)

## Header
- Goal: resolve every finding of the wave-1 peer review (`spec/peer_benchmark/feedback/peer_review_wave1.md`) with a
  regression check that fails before and passes after where the finding is behavioural. Finding 1 headless repro:
  `spec/peer_benchmark/feedback/hitstop_scope_repro.gd`.
- Base: `codex/peer-benchmark` (director gives the commit). itb-01, meta-01, sfx-01 run in parallel and also touch
  `run_scene.gd`, `combat_board_view.gd`, `combat_engine.gd`: keep each edit there minimal and local.
- Owned files: `scripts/combat_pacing.gd`, `scripts/combat_hit_stop.gd`, `scripts/combat_engine.gd` (finding 2 + 8
  only), `scripts/omen_rules.gd`, `scripts/event_rules.gd`, `scripts/event_view.gd`, `scripts/biome_library.gd`,
  `scripts/movement_undo_button.gd`, `scripts/run_scene.gd` (≤ 40 changed lines), `scripts/combat_board_view.gd`
  (finding 8 allocations only), `tools/sfx_lab/build.py`, `tests/test_sfx_lab.py`, `tests/section_map_flow_probe.gd`,
  `tests/combat_feel_probe.gd`, the matching suites under `tests/suites/` (combat_feel, event_rules, event_view,
  movement_undo, biome), `spec/analytics.md`, `spec/events.md`, `spec/combat_feel.md`, `spec/card_balance_heuristic.md`
  (only if the scorer needs a new assumption), `tools/` balance scorer files only if needed for finding 2.
- Rules: Windows typed-array rule; no new player-facing text except where stated; deterministic tests.
- Contract: risk tier standard. Acceptance: each numbered item below met with its proof.

## Change (numbered, testable)
1. **Time-scale freeze (major).** In `combat_pacing.gd` `_begin_scope`: when no scope is active, take the base scale
   from the hit-stop's saved previous scale if a hit-stop is active, else `Engine.time_scale`. Never adopt, apply or
   restore a base ≤ 0 (clamp to 1.0 in `_apply_speed`, `end_scope` and the hit-stop restore). Suite case: scope-less
   hit-stop request → `begin_card()` during the stop → wait past the stop → assert `Engine.time_scale` equals the
   combat-speed scale; after `end_scope()` and after freeing the owner it equals 1.0. Must fail on the base commit.
2. **Hero Expose (major) — director decision: keep it working.** On master, enemy intents (Bile Bloomer "Shard Mark"
   expose 2, Noctyrax "Void Claw" expose 1) put Expose on the hero and the hero status pip shows it, but it never did
   anything; the keyword text says "The next hit against the target deals additional damage equal to Expose." ev-01's
   consumption in `_damage_player` makes the displayed rule true; keep it, and:
   a. Enemy intent damage previews against the hero and the lethal/danger preview include the hero's current Expose
      on the first hit that would land (same place Block is accounted for).
   b. Regression suite: Shard Mark applies 2 → next enemy hit deals +2 and clears it; preview numbers match; an
      omen-free run's combat state hash changes only through this rule (update `event_rules_suite` byte-identity
      check to exclude nothing else, and add a check that would catch a different player-field change).
   c. Score Bile Bloomer and Noctyrax with the balance heuristic (`spec/card_balance_heuristic.md` scorer) before and
      after; report both numbers in the result. Document the rule in `spec/events.md` (omen use) and the enemy/status
      spec where Expose on the hero is described (add one line if none exists).
3. **Overlay refresh.** `combat_pacing.gd` `_process`: refresh only while a scope is active, never twice in a frame
   (skip if `_render_board_state` already ran this frame), and at scope end clear retained overlays or request the
   scene's normal stage refresh so no stale animation frame stays on screen. Suite: after `finish_enemies` and the
   overlays expiring, the rendered state equals the planning state.
4. **Broken probe.** `tests/section_map_flow_probe.gd`: drive `_event_view` (choose → Continue) instead of the removed
   `_event_panel`/`_event_embers`; it must run to PASS headless.
5. **Typed arrays.** Fix `combat_pacing.gd` `hits`/`deaths` declarations and `combat_feel_probe.gd` lines with
   non-empty typed literals (typed helper or `.assign()`). Grep the whole wave (`git diff master --name-only`) for any
   other `Array[...] = [` non-empty literal or conditional assignment and fix them.
6. **Pause during events.** `event_view.gd` must not consume the pause/menu action (Esc on keyboard, Start on
   controller): let it reach the existing pause handler; the pause menu opens over the event (z above the view) and
   closing it returns focus to the event's focused choice. Probe/suite: Esc during an event opens the menu.
7. **Event soft-lock.** `event_view.gd`: clear `_busy` when `present()` receives an unchanged signature, and when the
   scene declines the request (`_on_section_map_event` early return): the view stays interactive. Suite case.
8. **Hot-path allocations.** Cache the biome id/colours per room (invalidate on room change or biome override) instead
   of deep copies and `OS.get_cmdline_user_args()` per render; `OmenRules.first_movement` returns early when there are
   no omens or it isn't turn 1; replace per-tile `{}` defaults in `_draw_board_surface` and `_unit_impact_strength`
   with shared constants. No behaviour change (existing suites green; biome suite unchanged).
9. **Analytics.** Event card claims/skips: additive `reward_kind: "event"` and `event_id` on `reward_choice`; update
   `spec/analytics.md`.
10. **Victory at 1.0.** Call the pacing `end_scope()` before the post-combat victory presentation in both card-kill
    paths so rewards/victory always play at 1.0. Suite: card-kill at Fastest → victory beat scale 1.0.
11. **Movement undo input.** `run_scene._input` currently `await`s `movement_undo_button.handle_input(event)`, so the
    undo key is marked handled only after the undo animation. Split into a synchronous `consumes_input(event) -> bool`
    (marks handled immediately) and a non-awaited `request_undo()`; behaviour and tests otherwise unchanged.
12. **Sound lab tolerance.** `build.py`: waive the loudness tolerance only when normalization actually applied its
    peak cap (`peak_cap_applied`), not by encoded peak; add two tests (capped take passes below target; uncapped take
    outside tolerance fails) plus one test for the no-clip cap in `common.normalize`.
13. **Reforge.** `event_rules.gd` reforge excludes pieces already owned (pack or equipped), like `_gear_or_relic`.
    Suite case.

## Keep
- All owner-facing visuals, text and timings; feel-01 tuning values; event data; omen rules other than item 2.

## Proof
- Each behavioural item has a suite case that fails on the base commit (state which in the result).
- Keep green: full suite, combat_feel, event_rules, event_view, movement_undo, biome, section_map v2, dragon_boss,
  `tests/test_sfx_lab.py`.
- Windowed checks for the director: the pause-over-event probe command, and the combat feel probe command.

## Out of scope
- The architecture-drift notes (pacing reaching into run_scene privates, rules helpers calling engine privates):
  logged as debt for a later refactor unit. Don't restructure them here.
