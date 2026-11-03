# fix-15 — Defiance bookkeeping survives the reaction trace (fix-14 follow-up)

## Header
- fix-12 + fix-14 (`codex/fix-14` at e1c9217ac) make every loss in a Tether or Mimic turn play once, on its owning
  step. Their final Codex review (`/private/tmp/labyrinth_codex/review/fix-14-e1c9217ac.md`) found one regression
  against the base:
  - the snapshot helper (`scripts/reaction_presentation_trace.gd:5`) drops Defiance history and its event revision;
  - Tether HP 8 → 4 shows five damage; Mimic 8 → 2 shows seven;
  - a current-action revival is attributed to Retaliate;
  - a three-HP cascade hit reports six damage.
  The reviewer's controls pass on the base and with a temporary metadata correction (evidence in the review).
- fix-14 used its three rounds, so this is its follow-up. Base `codex/fix-14`; fix-12, fix-14 and fix-15 merge
  together. Risk tier: standard. Owned: `scripts/reaction_presentation_trace.gd`, the owner-baseline and action-result
  plumbing fix-14 added, and tests.

## Change
1. Owner baselines and action results carry Defiance bookkeeping (history and event revision) unchanged. The
   revision advances per owner step exactly as the resolver advances it.
2. Revivals are attributed to the step that caused them: a current-action revival to the action, a historical one
   to its own owner.
3. Add Defiance to the fix-14 matrix as an outcome: a revival on the owning step, with and without a following
   cascade. Keep the whole-turn totals equal to the HP changes, and defeats and revivals shown once on their owner.
4. Regressions: the reviewer's Tether and Mimic cases and the three-HP cascade hit. A mutation that drops the history
   again must fail.

## Proof
- The matrix, fix-12/fix-14 suites and the reviewer reproductions. Ordinary turns stay byte-identical to base.
- Focused tests only; the director runs the full suites at the joint merge.

## Out of scope
- Defiance rules and its presentation style.
