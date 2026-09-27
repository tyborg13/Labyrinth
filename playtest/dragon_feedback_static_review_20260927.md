# Dragon feedback static review — 2026-09-27

Reviewer: cutout worker, separately reviewing unowned integration changes.
This is a scoped review of the dirty shared branch based on `44e856d04`, not
committed exact-HEAD signoff. No Godot or production edits were performed during
this review. The root held the native Vaeloryx lease.

## Scope and independence

The preliminary non-cutout review covered encounter data/shared geometry and
resolution, reward/acquisition/NPC flow, save recovery, additive analytics,
trophy Time/relay interactions, production presentation and the corresponding
tests, specifications and realistic inspection fixtures. Later follow-up covered
the canceled-area repair, its prepared test/probe, the reduced Pass assertion
correction and new typed Array assignments across the pending GDScript changes.

The review excludes independent signoff on this worker's five cutout repairs,
board-tooltip repair and subsequent authored relay-origin fix. The relay defect
was initially found independently, then fixed under root authorization and
separately reviewed by the presentation worker; see
[trophy notes](dragon_trophy_feedback_notes.md). Authorship is not erased by
the earlier review role.

No additional confirmed blocking implementation defect was found in the reviewed
unowned changes after the known canceled-area finding was assigned for repair.
This does not establish complete regression, all-build balance or final readiness.
The [acceptance matrix](dragon_feedback_revision_20260927.md) owns current gates.

## Scoped static signoff: canceled areas

Reviewed production boundary: `scripts/dragon_presentation.gd::tiles()` only.
The new fallback requires both transport kind and action type to be genuine
single-target melee/ranged/push/pull. Thus `gale_force` transported as `push`
cannot accidentally qualify, nor can resolved ground/meteor AoE. An explicitly
empty Crownfire/Faultline area remains empty while actual ranged Skyhook retains
its ordinary target fallback and nonempty held breaths retain every cell.

The prepared `dragon_area_presentation_suite.gd` declares real warnings, removes
the real Fire/spires through engine helpers, then uses real resolver steps.
It checks prior warning existence, empty post-counterplay threat and result,
unchanged player HP and no invented target. Actual Skyhook and Cinder Breath are
controls. The production RunScene probe samples the canceled cast in normal and
reduced motion, checks area/depth exclusion of the safe player, preserves HP and
requires a still reduced rig. No tiles are fabricated in the resulting step.

Verdict: **scoped signoff, no findings**, now including independently inspected
runtime/renderer proof. The actual resolver suite passes in run
`dragon-boss-encounters-milestone-rewards-1790533825546276000-30109`.
The accepted `output/dragon-revision/canceled-area-01.json` records eight native
1920×1080/100% images; all eight copied images in
`/private/tmp/dragon-canceled-area-proof-01` were independently viewed at original
resolution. Crownfire/Faultline have no impact at safe player (2,4), retain visible
cast presentation, preserve 20/24 HP and use rest rigs in reduced motion. The
four recorded action witnesses have empty effect tiles, source-only depth tile
(4,3), and no failures. Source hashes below remain unchanged. The standalone
launcher applies the parallel runtime before suite work.

The corrected standalone Zekarion suite also passes in run
`dragon-boss-encounters-milestone-rewards-1790533835937684000-30144`; its actual
Godot log was read. This replaces the previously pending old-routing rerun.

## Scoped signoff: actual reduced Pass queue

Reviewed boundary: `tests/dragon_presentation_feedback_probe.gd` lines 247,
251 and the existing comparison loop at 277–278. `checked_fields` now uses
`turn_queue` rather than the absent `initiative_actors`; expected state must have
that queue. The reference is computed by independent engine resolution before
the actual `_on_pass_turn_pressed` call. Dictionary/array equality compares every
scheduled actor-entry field, and `initiative_clock` remains in the same settled
comparison with expected/actual values retained in the witness.

A missing actual queue now differs from the real expected array; the expectation
guard prevents absent-field equality from silently passing. The existing lock,
real player-activation and required-subaction checks remain intact.

Verdict: **scoped signoff, no findings**, including the independently read runtime
receipt and saved witnesses. `output/dragon-revision/presentation-queue-04.json`
records one accepted Metal attempt, exit 0, 167 images at 1920×1080/100%, and
`DRAGON PRESENTATION FEEDBACK: PASS[]`. Its saved witnesses in
`/private/tmp/dragon-presentation-queue-proof-04/witnesses.json` have no failures
and nine actual Pass comparisons: Tharokh 2, Iskaldra 2, Zekarion 3 and Noctyrax 2.
Every comparison includes `turn_queue` and `initiative_clock`; clocks 9/18/27 and
HP match the independent reference. The run is
`dragon-presentation-queue-04-1790533900151310000-30361-dragon_presentation_feed-1`.
This review establishes the assertion and runtime receipt; it does not claim
fresh independent pixel inspection of all 167 images. The reward worker inspected
the eight corrected reduced compound-action frames. Prior feedback03's old
missing-field comparison remains insufficient for queue equality on its own.

Reviewed source hashes (SHA-256; these bind only the snapshot inspected here):

| File | SHA-256 |
| --- | --- |
| `scripts/dragon_presentation.gd` | `85fc67256ea602933f004f0fb4705db3bf3d8fc688db61aa51c866eb63750422` |
| `tests/suites/dragon_area_presentation_suite.gd` | `76520424fac2085edd34f62c357efef7be841b86332939863397eb673700aea8` |
| `tests/dragon_area_presentation_test.gd` | `f8a4d7e5a7e29fa3d71be1d7d6aa518c048a7fae22644c0d37979f60730e54e6` |
| `tests/dragon_canceled_area_probe.gd` | `e310ca68ca37a1d0f0c3937ab765cc6e763be15160876390c879e6f3bd1734b5` |
| `tests/dragon_presentation_feedback_probe.gd` | `fa4b2b2c6d36be1dba5c7ba77538bc995a5beab97d18658d36d8a731b566a099` |

## Scoped signoff: trophy inline-token descriptions

Reviewed only the newly authorized two-string replacement in `data/relics.json`,
against `/private/tmp/dragon_trophy_description_replacements.json`. Both current
descriptions equal the saved `after` strings and differ from `before` solely by
replacing Ice/Time or ranged/range words with their established inline tokens.
Numbers, conditions, duration, line of sight and visibility clauses are intact.
This is not a new review of the earlier Hourglass/Coil mechanical redesign.

Independently viewed `hourglass_rules.png` and `coil_rules.png` at their original
1920×1080 size from `output/dragon-revision/trophy-icons-04.json`. Both panels fit
without clipping or lost rules. Hourglass visibly retains the first-Ice-card
condition, reserve/cap 3, non-Ice payment, minimum Time 1, combat duration and live
3/3 counter. Coil retains single-target ranged eligibility, one relay through
Electrified, normal range on each leg, line of sight and both visibility limits.
Ice element, Time, Ranged, Range and Electrified use their existing distinct
identities; no icon assets, paths or registry identities change in this patch.

Verdict: **scoped signoff, no findings**. The manifest reports one accepted Metal
attempt, exit 0, ten 1920×1080/100% images, and the runtime log says
`DRAGON TROPHY FEEDBACK PROOF: PASS`. Run:
`dragon-trophy-icons-04-1790536501586954000-33378-dragon_trophy_feedback_p-1`.
This independent pixel review covers only the two rules panels; the author owns
inspection of the other eight images. The current relic-data SHA-256 is
`5ad29c68b2eaba690951ecfb24b9abd7b8da1d5d000fad514dbbe7a2d03569c6`.

## Windows typed Array audit

The added/modified-line scan included tracked GDScript changes and all new
production/test GDScript files. No newly introduced typed Array assignment uses
a bare literal or conditional literal; no newly added typed Array parameter
default uses a literal. Eleven new typed initializers call helpers whose declared
return types match their destination: presentation tiles, body footprint, actor
passable tiles, meteor/spire candidates, live/shape tiles, outcome feedback and
surface tiles. New empty typed locals omit an initializer; collection population
uses append/append_array/assign. The earlier directional/geometric membership
constants are now intentionally untyped, and the unused cinder default is gone.

This is a static audit of newly introduced assignments, not a Windows runtime
certificate or a cleanup of all pre-existing typed-literal syntax in the project.
`git diff --check` passes. No new production change is recommended by this scan.

## Residual proof boundaries

Realistic acquired-build fixtures are not continuous full descents. Staged
presentation probes intentionally isolate actions and cannot establish encounter
pressure. Native studies must retain their actual card/movement costs, pilot
mistakes and damage sources rather than judging fun from final HP alone.

Full integrated regression, remaining native studies, all seven final
source-bound cutout receipts, committed exact-HEAD
independent review and refreshed inspection fixtures remain root-owned gates.
No publication approval or branch-wide signoff is granted by this note.
