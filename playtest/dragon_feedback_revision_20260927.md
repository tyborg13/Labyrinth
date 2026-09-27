# Dragon playtest feedback revision — 2026-09-27

Status: implementation and technical acceptance are complete. All six revised
native encounter studies, the final integrated regression, all seven cutout
receipts and independent visual reviews, the current packaged-resource smoke,
and all 15 refreshed inspection-save generation/reload checks pass. The final
wallet acknowledgment repair has independent scoped signoff and an expected-
failing baseline followed by 108 passing checks.

Committed-HEAD peer review and post-commit fixture/source verification are
recorded in the external final receipts described below. Recording those
receipts does not change the reviewed commit. No publication is approved.

The original native pass and review at `44e856d04` are baseline evidence only.
User feedback supersedes the earlier conclusion that this revision was ready.
This document is the current acceptance index; the owning notes retain the
experiments, rejected witnesses, diagnoses and detailed proof receipts.

## Evidence index

- **N — Native play:** [native journal](dragon_feedback_native_20260927.md).
  Preserved opening saves, actual actions, mistakes, analytics audits and bounded
  cohort assessments. Native play is separate from staged renderer fixtures.
- **P — Presentation:** [presentation notes](dragon_presentation_feedback_notes.md).
  Accepted [feedback03](../output/dragon-revision/presentation-feedback-03.json)
  has 167 inspected 1920×1080/100% images and 133 witnesses, including 87 semantic
  action stages, legal front/rear idle snapshots and actual reduced-motion Pass
  parity for eight real state fields. Its old `initiative_actors` comparison used
  an absent field; accepted [queue04](../output/dragon-revision/presentation-queue-04.json)
  now compares the actual `turn_queue` across nine real Pass activations with no
  failures. Its new pixel review covers eight reduced compound-action frames;
  the scoped independent review verifies the runtime receipt and queue witnesses.
  Accepted fan02, Thar-order01 and legacy-refuge01 addenda cover the later
  breath geometry, order overlap and saved Noctyrax warning states. The new
  explicit-empty-area correction is accepted separately in canceled-area-01;
  see the [scoped review](dragon_feedback_static_review_20260927.md).
- **R — Reward/NPC:** [reward notes](dragon_reward_feedback_notes.md).
  Focused logic and 14 inspected reward/Man v3 renderer frames cover acquisition,
  map fade, dialogue/service separation, persistence failure/retry and input paths.
- **U — Victory tooltip:** [tooltip notes](dragon_reward_tooltip_notes.md).
  The corrected ten-image native renderer proof passes, including stationary
  pointer, reduced motion, reward tooltip/focus and restored combat inspection.
  Native Thar02/03 separately corroborate the repaired victory transition.
- **T — Trophies:** [trophy notes](dragon_trophy_feedback_notes.md).
  Hourglass/Coil v3 has ten inspected frames. Focused tests now pass both Worldroot
  remote-payment/Coil interaction and bent relay Push/Chain routing; the latter
  has an expected-failing baseline and passing corrected runs plus scoped review.
  Exact run IDs and transcripts are retained there.
- **C — Cutouts:** [cutout notes](dragon_cutout_feedback_notes.md).
  All seven final-v2 captures and post-batch current-source verifiers pass:
  3,696 timed board frames, 80 clips and 80 pixel-identical editable-scene reloads.
  Independent visual acceptance carries byte-identical full cycles from the
  inspected predecessors and adds fresh peaks/native boards. All seven changed
  editor focus-glow screenshots were inspected and accepted. The fresh
  production-only package passes for 32 actors on the official macOS release
  template, with 2,297 packed production files matching current source exactly.
  That bounded package check is not Windows certification.
- **W — Wallet acknowledgment:** [repair and regression](dragon_wallet_ack_review_20260927.md).
  The native Man save exposed stale embedded outbox entries restored during UI
  refresh. Both purchase handlers now synchronize/save acknowledgment first.
  The actual-RunScene test fails on the old code and passes 108 checks after
  correction, including failed acknowledgment/reload for Man and campfire.
  The complete post-fix integrated suite also passes with runner exit 0.
- **M — Mechanics:** `tests/dragon_feedback_mechanics_test.gd`,
  `tests/dragon_committed_patterns_test.gd`, the focused trophy/reward suites,
  and Python heuristic context/surface checks have passing focused receipts.
  These establish specific behavior, not complete regression or universal balance.
  Current rules/rationale live in [dragon encounter spec](../spec/dragon_boss_encounters.md),
  [balance heuristic](../spec/card_balance_heuristic.md),
  [analytics](../spec/analytics.md) and [save persistence](../spec/save_persistence.md).

## Current acceptance matrix

“Accepted” below means the stated scoped witness or cohort is accepted. It does
not close the branch-wide gates at the end of this document.

| ID | Observable result | Current state / evidence |
| --- | --- | --- |
| G1 | Boss relic plays standard acquisition animation, then smooth map transition | R/U accepted; native Vyr, Thar, Isk, Vael and Zek corroborate acquisition/map flow. Noct01 verifies the final next-run gift milestone and Complete Ascent→victory path, with audited banking/completion boundaries. Stale combat tooltip is repaired and verified. |
| G2 | All six dragons visibly breathe/cast/strike with established elemental effects | P accepted for normal/reduced actions and visible misses; canceled-area-01 independently verifies no fabricated Crownfire/Faultline target impacts. Queue04 verifies actual queue/clock parity through real reduced Pass playback. |
| G3 | Setup/defense turns create readable secondary pressure and fewer free damage windows | Implemented. All six revised native cohorts completed/audited. Vyr02 provisionally accepted; Isk01, Vael01, Zek01 and Noct01 retained with explicit acquired-build limits. Thar03's bounded placement is retained by worker assessment, not independent self-signoff. Forgiving windows and pilot errors remain documented. |
| G4 | Gust Step resolves from one target without a second targeting state | M PASS; native studies verify enemy shortcuts, movement-only use, and skipped illegal movement with retained attack. |
| G5 | First-dragon unlock is ordinary flavorful Man dialogue; recurring service is a separate room choice | R accepted: focused checks and 14 inspected frames cover first/repeat, persistence and input paths. |
| V1 | Fire coverage and secondary threats make escape cost position or defense | N Vyr02 provisionally accepted: widened shoulder coverage costs a movement-card play; Maw control/retreat remains useful. P fan02 accepted. |
| V2 | Crowncoal Heart exact rules read concisely | Updated copy inspected in reward/trophy proof and native victory. |
| T1 | Spires cover meaningful routes; breaking and navigating compete | N Thar03 completed/audited. Deliberate alignment breaks the approach spine; Rubble spends the full movement budget; clearing earns the later safe corridor. Retained for this cohort, not universal difficulty proof. |
| T2 | Worldheart conversion is a justified 1 or 2, with explosion retained | Cap2 implemented; focused trophy/reward checks PASS; native reward copy and later Isk defense effects audited. |
| T3 | Spires use procedural earth-outcrop vocabulary; attacks have flair | P accepted and native Thar corroborates style. Canceled Faultline with no surviving spires passes the independently inspected explicit-empty-area addendum. |
| I1 | Two-wide ice lance leaves Ice over its entire declared path | M/P accepted; N Isk01 audit confirms full six-cell lanes, held reanchoring and bounded owned-trail replacement. |
| I2 | Rear idle has no section gaps through the whole cycle | C final-v2 unchanged-source receipt and independent whole-cycle carry/fresh-board review accepted; P live integration accepted. |
| I3 | Crystal Mantle count, layer breaking and mitigation are obvious | M/P accepted for counts and prevented-damage popup; N audits three broken layers and 13 prevented damage. Native sampling did not capture the brief popup, so P supplies its legibility proof. |
| I4 | Winter’s Hourglass has an interesting Time effect | T accepted: bounded stored Time, exact cost preview/payment, carry/save behavior and ten-frame visual proof. |
| I5 | Mantle/setup supplies secondary pressure and fewer free turns | N Isk01 audited and retained: armor breaking spends plays, defense absorbs a chosen hit, and a movement card enables repositioning. No general multi-build claim. |
| A1 | Rear idle articulates parts and wing anatomy is corrected | C rebuilt rear anatomy/segmentation, final-v2 stable-source receipt and independent cycle/peak review accepted; P live idle accepted. |
| A2 | Skyhook is not selected as an already irrelevant threat without another purpose | M legality checks PASS; N Vael01 completed/audited. The first pull reaches a trap after a pilot route error; the second hit consumes a defense card, while an early pass preserves the player-first Dive tie. |
| A3 | Razor Dive intent pattern and damage do not overlap | P measured layout and swept-pattern presentation accepted at 1920×1080/100%. |
| A4 | Air geometry and displacement have distinct tactical identity | M/P swept Dive and nearest-body radial force accepted; N Vael01 retained. Pull destinations, the banked control turn and displacement of held attacks matter; the first Dive/Gale pair still permits easy ranged offense with this build. |
| A5 | Eye of the Storm creates a threat rather than retreat plus Block alone | M/P threatening ring and safe distances accepted; N Vael01 confirms advancing into the safe center. An attacking movement card plus one free step avoids the first Eye; no claim of uniformly costly escapes. |
| Z1 | Rear idle seams are repaired | C final-v2 stable-source receipt and independent cycle/peak review accepted; P live integration accepted. |
| Z2 | Wisp idle articulates segments | C segmented whole-cycle proof, final-v2 stable-source receipt and independent fresh-board review accepted; P live integration accepted. |
| Z3 | Wisp-supported pressure is preserved | N Zek01 completed/audited and retained: first replacement costs both T5 plays and zero boss damage. Second replacement loses 7 HP to its spawn trap and dies to Worldheart; neither replacement's attack is natively exercised. |
| Z4 | Dragon cashes in accumulated Electrified tiles with declared damage/status | M/P declared-charge snapshot, single-hit/consumption behavior and Overload presentation accepted. N Zek01 confirms two declared areas resolving/consuming after escape; escapes are cheap, no Shock rider applies, and charge replacement/later additions remain focused-test evidence. |
| Z5 | New summons wait until the player receives a reaction turn | M PASS for Wisp/Acolyte next-player slot, serialized queue and later normal activation. N Zek01 confirms 70 before helper71 and 139 before helper140, both killed before acting. N Noct01 confirms player37 before helper52 and player110 before helper116; both actually activate, and the first replacement later lands a defended hit. |
| Z6 | Stormroad Coil uses Electrified terrain to extend ranged reach | T accepted: both range/LOS legs, direct preference, Worldroot payment, bent Push/Chain false-positive/negative regression and preview/commit parity. |
| N1 | Shadow attacks are distinct, pressured and expressive | M/P accepted; N Noct01 completed/audited and retained for its acquired skirmisher cohort. Refuge routing, Claw retreat and the piercing two-wide Breath are distinct. The 11-HP Breath hit is an admitted lane error, not a demonstrated hidden-hit or UI defect. |
| N2 | Player arrival relights braziers; new boss intents do not auto-relight | M walk/Blink arrival and legacy checks PASS; P saved-warning addendum accepted. N Noct01 naturally relights far brazier at T6 via player_arrival, observes forecast −9 Stoneskin/−2 HP→Safe, and avoids Eclipse. Prior snuffs persist until arrival; repeated relight cycles are not claimed. |
| N3 | Killed Acolytes can be replaced with fair summon timing | M cap/reaction checks PASS. N Noct01 verifies two replacements after initial-helper kills, reaction slots and actual activations; the first later costs 4 Block, while the second dies to existing Fire. Initial helper kill refunds and forgiving pressure are documented. |
| N4 | Brazier state and interaction helpers meet shared UI quality | P two-line Light/snuff/relight plates and health-bar clearance accepted, including saved-warning addendum. N Noct01 corroborates the live T6 state label and forecast change on relighting. |
| N5 | Idle splitting is repaired throughout the cycle | C final-v2 stable-source receipt and independent cycle/peak review accepted; P live integration accepted. |

## Native assessment boundaries

Vyr02's no-hit first-gate win now pays a movement-card play for the broadened
breath and uses control/retreat for Maw. The independent fun review provisionally
accepts those costs instead of demanding unavoidable damage. Isk01 spends timing,
armor-breaking, defense and movement resources; prior Worldheart and a picked-up
Jaw Trap contribute. The audited assessment retains the encounter for that build.

Thar03's new flank spine requires deliberate alignment; the trap wake and Rubble
then consume the cohort's whole three-move allowance. Clearing it earns a safe
Faultline corridor. The corrected Sidestep target retains its attack, so the older
pilot error is not counted as pressure. The seven-activation win is still forgiving
for Cleaver/Boots/control, and its two lost HP are Fatigue. The worker's audited
retention assessment is not independent signoff on its own placement change.

Vael01 completes in seven activations with 13 cards and 10/24 HP before the reward's
six healing. Its losses are 4 from the first Skyhook plus triggered trap, 2 Fatigue
and 4 from final-turn entries into the player's own Crowncoal Fire. The missed
Kite attack and hazardous routes are pilot/selection outcomes, not required
encounter sacrifices. Defense absorbs the second Skyhook; an early pass retains
the clock 80 Dive tie and banks a play for the next control turn. Eye rewards
advancing rather than repeated retreat. Retain this bounded cohort assessment:
three prior trophies materially help, including 19 Crowncoal damage and a 3-Time
discount, while the first Dive/Gale pair remains a forgiving ranged window.

Zek01 completes in ten activations with 19 cards and 17/24 HP before six healing.
Reprise's 1 HP cost and 2 Fatigue explain all health loss; five dragon hits spend
24 Block and 10 Stoneskin. The first replacement takes both T5 plays to remove,
and a later turn deliberately accepts Skybreak to keep two attacks and a
Worldheart helper kill. The second replacement is weakened by its spawn trap;
neither replacement attacks. Retain the acquired cohort assessment with all four
prior trophies, Shield/Buckler/Boots synergy, two cheap Overload escapes and the
unexercised native charge-replacement/conditional-Shock alternatives explicit.
Stormroad reward, 110 unbanked Embers, six healing and cleared map are audited.

Noct01 uses the preselected depth24 skirmisher cohort without Pilgrim Boots,
with all five earned trophies. Nine activations and 20 cards end at clock142
with 7/24 HP: 2 Fatigue and an avoidable 11-Pierce Breath hit explain the loss.
One natural arrival relights the far brazier and changes the forecast to Safe;
both Eclipses then miss in Light. Both replacements receive a prior player turn
and actually activate; one later spends 4 Block, while the other dies to Fire.
Retain the bounded assessment with efficient initial kill refunds, strong relic
support, one relight cycle and the candid lane mistake explicit. Pre/post-claim
snapshots distinguish durable gift preparation from later banking and run
completion. The next-run gift is queued, not consumed by this cohort.

These are realistic staged acquired-build studies, not continuous full descents
or proof that every build has equivalent pressure. The native journal preserves
all attempts, mistakes and source corrections. All six revised encounters now
have completed audited native studies. Technical proof is complete; the final
committed-HEAD review and verification are recorded separately below.

## Canceled-area repair

`DragonPresentation.tiles()` previously fell back to a target coordinate when an
explicit resolved area was empty. If all Crownfire fuel or all Faultline spires
were removed before resolution, that fallback invented a visual impact despite
the resolver reporting no affected cells. The reward worker's prepared fix
restricts fallback to genuine single-target actions. Read-only review found no
blocking issue in that change or its resolver-backed regression and production
RunScene addendum. Actual Skyhook and full held-breath controls protect ordinary
target fallback and nonempty miss areas. Resolver tests pass; canceled-area-01's
eight 1920×1080/100% images are independently inspected with no target impact,
unchanged HP and reduced rest rigs. Scoped signoff closes this narrow defect.

## Completion gates

- [x] Complete and independently review the canceled-area presentation correction,
  passing focused regression and eight inspected 1920×1080/100% renderer frames.
- [x] Complete and audit Vael01, retaining the bounded assessment and recorded
  pilot mistakes in the native journal; no further tuning proposed for this cohort.
- [x] Complete and audit Zek01, retaining the bounded acquired-build assessment,
  helper/defense opportunity costs and explicit limits; no further tuning proposed.
- [x] Complete and audit Noct01, including natural arrival relighting, actual
  replacement activation and the final reward boundary. Retain the bounded
  acquired-build assessment; no observed defect justifies further mechanics edits.
- [x] Run full integrated regression. The latest post-wallet runtime rerun
  `dragon-feedback-integrated-after-wallet` passed with exit 0 in session 63950,
  followed by passing focused checks for the final art data. The earlier
  corrected `tests/run_tests.gd` rerun
  passed with verified runner exit 0 in
  `dragon-boss-encounters-milestone-rewards-1790536614403264000-33594`.
  All 40 assertions from the earlier failed run are resolved after independently
  reviewed test repairs and relic description fixes; the
  [integrated receipt](dragon_feedback_integrated_suite_20260927.md) retains both
  outcomes and their scope. The standalone Zekarion cutout test and Queue04's
  corrected real-queue assertion also pass, with scoped
  [runtime receipt review](dragon_feedback_static_review_20260927.md).
- [x] Freeze production sources and accept all seven final cutout cases with
  independent visual review and successful verification against the same input
  closure. Final-v2 session 52299 exited0; all 80 editable reloads are identical.
- [x] Refresh the packaged-resource check after the final rig promotion:
  official macOS release-runtime smoke passes all 32 actors and 2,297 production
  file bindings with no mismatches.
- [x] Refresh all 15 self-resetting user inspection fixtures. Generation/reload
  batch session 84927 exited0, including resets of the three played interaction
  saves. The [inspection guide](dragon_feedback_inspection_20260927.md) supplies
  exact launch commands and preserves the observed limits.
- [ ] Wait for user inspection and explicit publication approval before pushing,
  landing or cleaning up. Nothing has been published.

## Post-commit evidence

The exact committed HEAD, independent branch-wide reviewer verdict, clean-tree
check, repeated all-seven source verification and all 15 standard fixture
verifiers belong to `/private/tmp/dragon-feedback-inspection/final-v2/`:
`exact-head-review.md`, `verify-results.json`, and `final-handoff.json`.
The final handoff is permitted only when these identify the same clean HEAD and
pass. They are external to the repository to avoid changing the commit merely
to record its own review. Scoped reviews above do not substitute for that
branch-wide signoff. Any later source edit requires renewed affected proof and
review; publication still requires explicit user approval of the reviewed HEAD.

## Design and rationale ownership

The combat board answers what will hurt the player, where and when. Declared
patterns and result snapshots own the presentation; movement, attack, defense,
control and accepting damage remain valid competing choices. Exact mechanics,
cycle/order decisions, geometry and balance assumptions belong to the linked
encounter/balance specifications and native/presentation notes.

Reward/NPC surfaces answer what was earned and which service is being selected.
Trophy acquisition settles before the map appears; ordinary dialogue and repeat
services stay distinct. Card/relic surfaces preserve exact rules and deterministic
preview/commit agreement. Shared icon, typography, tooltip and input components
are reused. The owning R/T/U notes retain accessibility, layout, persistence and
interaction proof rather than duplicating obsolete chronological checkpoints here.
