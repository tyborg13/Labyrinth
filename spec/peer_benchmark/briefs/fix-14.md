# fix-14 — Deferred death cascades get their own owning step (fix-12 follow-up)

## Header
- fix-12 (`codex/fix-12`) made every loss in a Tether or Mimic turn play once, on the step that owns it: arrival,
  action, then each reaction, with intermediate snapshots. It used its three rounds. Its final handoff
  (`tests/fix_12_implementation.md`, "Open issues") reports one gap it left on purpose:
  - Deferred death cascades resolve **after** the trace's capture points (`board_attack_rules.gd:239`, via
    `CombatEngine._flush_surface_deaths` at `combat_engine.gd:12115`): Ember Tick death bursts, surface deaths and
    their chains.
  - Before fix-12 that tail was bundled into the beam, so it was shown, credited to the wrong step. After fix-12 it is
    **not shown at all**. Reproduction: hero real loss 7, shown 4; the Thrall resolves to 0 HP but is presented at 6.
    Evidence: `/private/tmp/labyrinth_codex/fix-12-feedback3-residual.log`; fixture
    `/private/tmp/fix-12-rereview/followups.gd` (`tether_reaction_kills_hero`, two HP-1 Ember Ticks at `(1,3)` and
    `(2,4)`).
  - This is a regression against the base, so fix-12 merges only together with this unit.
- Base `codex/fix-12`. Risk tier: standard. Owned: the reaction trace and its presentation (fix-12's files), the
  capture of the flush tail, analytics (additive), and tests. New headless programs: append them last in
  `tests/headless_test_programs.json` and add the matching `POST_SNARE_PROGRAMS` line.

## Change
1. **The cascade owns its losses.** After the action and its reactions, the deferred flush tail is one more owning
   step in the trace, in resolution order: each death burst (Ember Tick, surface death, chained bursts) presents its
   realized losses once, at its own tile, with its existing burst effect, on an intermediate snapshot.
2. **Totals always match.** For every unit, the shown losses over the whole enemy turn equal the real HP change, and
   every defeat is shown once on the step that caused it. Make the fix-12 popup-total helper check whole-turn totals,
   and run it on every fix-12 and fix-14 case.
3. **Scope.** Tether and Mimic turns use the trace (fix-12). Check whether an ordinary enemy turn whose attack kills
   an Ember Tick shows its burst correctly on the base. Report it with evidence, and don't change other mechanics'
   legacy payloads here.

## Proof
- The reviewer's fixture as a test: the hero shows −7 in total (the beam's part plus the bursts), the Thrall's
  defeat is shown once on the step that kills it, and analytics carries the cascade losses on the cascade.
- A firing case where the beam kills an Ember Tick whose burst hits the hero.
- Mutations: drop the cascade step, which must fail; bundle the tail into the beam again, which must fail.
- Focused tests (fix-12, fix-11, en03, en06, enemy-no-action, the Ember Tick suites). No full suites.
- The windowed probe gains one capture of a burst popup mid-cascade; list the command (`--timeout 60`).

## Out of scope
- Other enemy mechanics' presentation, popup styling, and burst rules.
