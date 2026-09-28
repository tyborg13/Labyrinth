# Dragon pressure revision — 2026-09-28

User correction: **all six dragons** require harder tactical decisions. Fire,
Earth and Lightning were examples, not priority exceptions. The prior pass's
native outcomes do not establish acceptance: ordinary attack / free sidestep
must fail repeatedly for meaningful reasons, without relying on pilot error,
fatigue, hidden helpers, raw HP inflation or one movement-card use per fight.

## Design and acceptance

Couple body attacks with geographically independent, bounded fields. Warnings
must include every layer; fixed fields stay anchored after displacement and
save/reload. Clearing fuel, breaking spires, reducing Mantle, killing helpers,
using Light, defending or spending movement/Time must change future danger.
Verify repeated opportunity costs in at least two parts of every first cycle.
Keep normal repeat cadence initially; all openings resolve at clock 12.

Prototype: Fire uses seven-cell bent bands, breath plus adjacent cinder heat,
Crownfire plus pursuit, and Maw renews the band. Earth pairs four breakable
spires, pulses them alongside Claw/Breath, then consumes them in Faultline.
Ice places Shatter directly after two-layer Mantle, then a bounded cross trail
and Talon plus trail burst. Air's actual Dive wake persists into a broad Gale;
Eye trades its weaker close strike against its outer ring. Lightning uses a
seven-cell charged band and adjacent Overload, retains charge, and combines
field pulses with live shots. Shadow announces fixed ground sweeps around the
player's declared position during Eclipse and later attacks, so moving Light
away from braziers alone cannot solve every layer.

## UI statement

The board and existing intent row must expose each compound danger and its
clock without lengthy prose. Shadow spell layers use the production FX
vocabulary. A successfully committed Moltshard exchange gives a short visible
Ember receipt and audible cue, including reduced-motion support. Stormroad
Coil copy retains the mechanical effect and drops redundant targeting prose.

## Integration and proof ledger

- Preserved the user's two blank lines in the old inspection guide, commit
  `9028313e5`; integrated current **local** master (no fetch) at `caea023d2`.
- Clean worker preflight passed. Risk tier high; all-six native gameplay,
  accurate preview/resolution/save regression, balance/spec/analytics updates,
  full Godot suite, exact-HEAD independent signoff and reset fixtures required.
- Integration wallet regression: PASS 108, expected injected ack-failure logs.
- Integration Ember Hearth lifecycle: PASS. No pressure acceptance claimed yet.
- Current publication authorization: none. Do not push, land or clean up.
- Focused production checks `dragon-pressure-committed-03`: PASS. This caught
  and repaired Tharokh's body AoEs destroying his own newly raised pressure.
- Independent mechanics `dragon-pressure-mechanics-01`: 237 checks, expected
  failure exposed stale Skybreak conductor warnings and Overload's post-field
  illusion retarget; pillar-based test witnesses were corrected separately.
- `dragon-pressure-mechanics-02`: PASS 251 checks after preview fixes;
  `dragon-pressure-committed-review-01`: PASS, separate reviewer invocation.
  Both logs live in their task-local homes under `/private/tmp/labyrinth-godot-home/`.
- Runtime and Python scorer now both identify `dragon_pressure_v3`. Older
  saved warning payloads remain intact at the explicit balance transition.
  Gust Step intrinsic score remains 2.71; only encounter assumptions changed.
- [Native pressure journal](dragon_pressure_native_20260928.md) records the
  paused first Fire attempt, the superseded Noct01 prototype, and the complete
  Noct02 study. All-six difficulty acceptance remains pending.
- `dragon-pressure-mechanics-03`: 267 checks; the two new bounded synthetic
  trap-policy assertions failed as expected. The real follow-up shot favored
  its reachable actor, while its warning incorrectly borrowed primary trap
  priority. Shared target selection repaired that mismatch.
- `dragon-pressure-mechanics-04`: PASS 267, independently reviewed against its
  log and the shared selection code. Preview provenance now identifies the
  dragon; private-copy forecasting leaves live state/RNG untouched. No new
  behavioral or recursion finding remains in that scoped review.
- Presentation `pressure-presentation-04`: PASS, 32 original 1920×1080
  images inspected. Later v05 and warning v04 renders also pass, but the
  independent image review still finds Noct's repeated thin curves and faint
  release stream below the requested quality. Art refinement remains open.
  [Presentation receipt](dragon_pressure_presentation_20260928.md) separates
  renderer correctness, artistic assessment and gameplay acceptance.
- Icon identity policy: PASS 5 tests after the presentation/pressure changes.
- Earth spire route repair: the generated depth-8 entry held `(2,3)`, `(1,2)`,
  `(1,6)`, `(2,5)`. Ordinary advance `(1,4)→(2,4)→(3,4)` previously suppressed
  all four at Stonewake resolution because temporary player occupancy counted
  against structural exits. Terrain-only exit counting retains occupied-mark,
  floor-connectivity and two-whole-body-exit guards. The coordinator's
  [baseline log](/private/tmp/labyrinth-godot-home/dragon-spire-routes-baseline/godot.log)
  failed exactly 1 of 26 checks; the
  [fixed log](/private/tmp/labyrinth-godot-home/dragon-spire-routes-fixed/godot.log)
  passed all 26 and raised the exact held field at clock 18. The same checks
  now live in `dragon_spire_routes_suite.gd`, imported by the full suite and
  retained behind the focused launcher. Full02 below verifies the extraction;
  native Earth difficulty acceptance remains pending.

- Full regression `dragon-pressure-full-01` exposed six stale Overload test
  expectations. The reviewer split current retained radius-one behavior from
  explicitly serialized legacy consuming exact-cell behavior in the two owning
  suites. `dragon-pressure-full-02`: PASS after the integrated rerun, including the
  278 pressure checks, 26 spire checks, current/legacy Overload and live exchange
  behavior. The expected injected analytics acknowledgment error is exercised;
  the pre-existing ObjectDB shutdown warning remains. Python heuristic context
  and surface suites also pass (1 + 6 tests).
- Native Noct01 showed the nearest-brazier sweep often missed the player's
  actual Light refuge. Current fields now opt into immutable player-position
  anchors, with Eclipse radius 3, Claw 2 and Breath 1. Light still avoids the
  separate darkness hit; the held sweep remains guardable. Unflagged saved
  actions retain nearest-brazier behavior. `dragon-pressure-mechanics-05`:
  PASS 278, including production save/reload and legacy anchor witnesses.
  Native Noct02 below assesses these anchors; nominal radius alone is not an
  escape-distance proof around LOS blockers.

- Native Noct02: victory on T11, clock 178, at 6/24 HP after spending the one
  Defiance charge. The independent event/save audit reconciles 24 cards and
  101 boss damage (76 cards, 24 Crowncoal, 1 Worldheart). Repeated Eclipse
  responses include extra movement and a guard/Time tradeoff; T5's third
  attack crosses the next Eclipse deadline, while T10's two attacks and shallow
  ordinary retreat fail against the live Claw. Pilot targeting/route mistakes
  and hidden helper lethality do not count as required tactical costs. The
  reviewer recommends retaining this tuning while checking the other five.
  The victory milestone is prepared, not claimed, in the persisted save.
- Warning review found Air Eye's `Safe within 1` clause falsely promised safety
  despite the same intent's close bite. Removed the redundant safety promise
  from ring summaries while preserving ring bounds and Mantle text. Focused
  `pressure-ring-copy-01`: PASS, four 1920×1080 originals. The coordinator
  independently inspected Eye: `Ring 2–5` and the separate bite are legible,
  with no clipping or changed geometry. This is copy proof, not Air play proof.

- Independent challenge review found stale public Grimoire rules: consuming
  exact-cell Overload, a safe Air eye, a single Ice lane, and non-direct Mantle
  damage. Nine entries now describe the current retained adjacent charges,
  separate live bolt, Dive wake, close bite, crossed Ice and direct-hit armor.
  The reviewer checked the copy against production and resolved the finding.
  `pressure-grimoire-01`: PASS, nine 1920×1080/100% originals; the coordinator
  inspected all nine and found full titles/rules legible and unclipped. The scorer's six short role
  summaries now match its existing detailed v3 context; Python suites remain
  PASS (1 + 6), with no intrinsic coefficient change.

- Native Earth01 now completes at T8, clock 119, 13/24 HP. Its audit separates
  two real spire clears and useful hybrid guard from a rubble-route mistake,
  an input bug workaround and Fatigue; the independent review below requires tuning.
- Native Earth exposed a finite-Umbra UI bug excluding visible terrain and traps
  from movement/attack shortcuts. The narrow repair preserves hidden-target
  filtering and enemy-only push rules. Focused regression passes, the old filter
  fails seven targeted assertions, and separate source review approves the fix.
  Root verified the repaired Sidestep spire click in the resumed real fight;
  renderer probe `visible-terrain-shortcut-02` also passes two 1920×1080/100%
  originals, inspected independently by root. The visible-spire offer and its
  destroyed Rubble state are legible; hidden targets remain filtered. Probe01
  is preserved but superseded because its fixture pointer began at (0,0).
- Shadow presentation v07 passes all 34 images. Root and independent reviewer
  inspected the broader textured Night Coil stream and reduced exchange cue.
  Visible-source Starless v02 passes five images; exposed billows and impact
  meet the material/depth bar. Most of the source path is actor-occluded, so
  this is not claimed as a fully visible maw-to-target demonstration. No further
  artistic revision is pending on the inspected material.

- Independent Earth01 review rejects difficulty acceptance: the dedicated clear
  and useful hybrid guard are too sparse for the repeated-cost gate. Only the
  Bedrock retained-spire radius increases 1→2; Claw, Faultline, HP, damage and
  cadence remain. The first native corridor at (4,5) lies two cells from its
  surviving (3,6) spire. A distinct authored two-spire regression checks guard,
  clearing, farther refuge and preservation of old saved narrow warnings.
  Separate static review approves the bounded change; Python scorer suites
  pass 1 + 6. `dragon-pressure-mechanics-06` passes all 294 checks. Fresh
  `pressure-earth-breath-01` passes five 1920×1080/100% originals, all inspected
  by root: four compound warning rows and the Worldspines Grimoire entry are
  legible and unclipped, including the expanded Breath field.
- Local checkpoint `98358f0a4` commits the all-six pressure, shadow/exchange,
  copy and visible-terrain shortcut changes. The subsequent bounded Earth
  tuning and final evidence will be committed after remaining native checks.
- Native Fire01 completes T7/clock114 at 6 HP and claims its milestone.
  Independent review retains the tested depth-4 F2 tuning: the observed heavy
  pair has no safe two-point endpoint in the recorded Breath/heat union, and
  later Stone Plate consumes a defensive play for useful absorption. Exclude
  pilot mistakes, unproven Blink necessity, Fatigue and unnecessary final Root.
- Fresh native Earth02 completes T8/clock118 at 13 HP. Breath now consumes
  5 actual Block in the old outer corridor, followed by Faultline consuming
  5 hybrid Block. The second cycle includes a dedicated spire clear, a real
  push-into-trap reward and a low-Time draw choice before the next Breath.
  Full event/save accounting is in the native journal. Independent review
  retains this depth-8 F3 tuning for its useful consecutive defensive phases
  and dedicated clear. The fast draw line was chosen; a one-tick-later return
  also wins the player-first tie and is not credited as a forced timing cost.
  Ice, Air and Lightning native assessments follow serially.

- Checkpoint `556ad0970` commits the bounded Earth tuning and three completed
  native verdicts. The separate [integrated source review](dragon_pressure_source_review_20260928.md)
  approves the v3 delta at that exact checkpoint with no actionable findings.
  Final gameplay, integrated regression, fixture and exact final-HEAD gates
  remain as stated below.

- Integrated `dragon-pressure-full-03`: PASS, wrapper 99908 exited 0 on the
  current committed production code. This includes the 294 pressure checks,
  visible-terrain shortcut regression, spire routes and exchange recovery.
  Expected injected acknowledgment/legacy-save diagnostics and the existing
  ObjectDB shutdown warning remain. No implementation change was made during
  the run; only review documentation was pending.

- `dragon-pressure-committed-05`: PASS on checkpoint `556ad0970`, wrapper
  31511 exited 0. Ice01 then completed but independent review returned **TUNE**:
  its useful guard was too sparse, and the observed T4 ordinary step to `(2,1)`
  avoided both live Talon and the trail after two attacks. Root on T2 was a
  chosen line, not a demonstrated necessity: a three-step unshrunk-Shatter
  escape remained on the recorded opening board.
- Bounded Ice trial increases only Rime Talon's live pursuit 2→3. Health,
  damage, armor, cadence and the exact-cell trail burst are unchanged. A
  controlled post-Whiteout rules witness checks real one-point movement,
  read-only warnings, actual bite/guard/Root resolution and saved legacy
  Move-2 behavior. Separate static review approves the corrected trial; Python
  scorer/context suites pass (1 + 6). Runtime proof and a fresh native Ice02
  remain pending. The independent reviewer also checked a proposed two-step
  `(2,2)→(1,2)→(1,1)` escape against Ice01's actual opening save and later
  events: `(1,1)` is a structural pillar, unchanged by Shatter. That particular
  counterexample is invalid; the legal westward one-step alternative is also
  covered by the controlled pursuit witness. This is bounded route analysis,
  not native acceptance.

- `dragon-pressure-mechanics-07`: PASS 318, wrapper 59213 exited 0. The
  revised Ice bite catches both controlled one-point refuges while guard,
  Root and legacy serialized Move-2 behavior resolve correctly. Fresh
  `pressure-ice-pursuit-01`: PASS four real-renderer 1920×1080/100% originals,
  all inspected by root. The full four-part cycle remains readable; Rime's
  Move 3, scaled bite, separate marked-trail hit and ghost path are legible
  without clipping. These are correctness/readability proofs; native Ice02
  remains required. Air01 has now completed; its independent audit is pending.

- Checkpoint `cf826c8fb` commits the bounded Ice pursuit change, focused
  PASS 318 and four inspected warning renders. Fresh native Ice02 remains the
  difficulty gate for that change.
- Independent Air01 review retains current depth-16 LV3/F3 tuning. Thirteen
  cards and 95 events reconcile 72 boss damage; victory is T7/clock99, with
  the milestone claimed and section IV map reached. Useful guard is spent in
  separate first-cycle phases (Skyhook 6, Eye 7). At T5/clock66, two four-Time
  cards return the player at83, after both Skyhook66 and Dive79; one four-Time
  card returns at79 and wins the tie before Dive. Deferring a play is a real
  alternative to accepting that consecutive pressure. The first Dive's cheap
  escape came from a consumed Air trap pushing the player out of its sweep;
  later ordinary retreat did not solve the repeated sequence. Root immunity
  confusion, the poorer Eye endpoint, optional potion, Fatigue and final low HP
  do not count as required costs. No Air tuning change is needed.

- Integrated `dragon-pressure-full-04`: **PASS**, wrapper 43738 exited 0 on
  committed production `cf826c8fb`, including the revised 318-check pressure
  suite. The injected acknowledgment failure, legacy-save preservation warning
  and existing ObjectDB shutdown warning are the documented expected diagnostics.
  No production file changed during the run. The native runtime lease then
  returned to the pilot for Lightning while Ice02's independent audit proceeds.


- Independent Ice02 review **retains** the three-step Rime on `cf826c8fb`.
  The completed native fight and 155-event audit reconcile 16 cards, 71
  card-receipt damage plus one separate Worldheart pulse. Two Mantle shots
  consume 7 Block + 3 Stoneskin; no enemy attack removes player HP. At the
  first Rime, all 15 ordinary F3 endpoints admit a legal trap-free whole-body
  Move3 bite, including all six endpoints outside the retained trail. A
  deliberately escape-favoring Gust geometry bound covers 136 movement
  allocations across 10 cast/body pairs and still finds a bite route for each.
  This is a code-grounded route-existence bound, not an engine replay or an
  exhaustive strategy search. Even zero-card return61 follows Rime60.
  The actual finite Jaw/Root therefore buys meaningful control, alongside the
  recurring useful Mantle defense. Exclude the optional T2 armor strip, freely
  avoided T6 Shatter, T8 bad-approach recovery, Fatigue and final HP. No further
  Ice tuning is justified. Frozen review and reproducible route script/JSON:
  `/private/tmp/dragon-pressure-native/iskaldra-02-complete/`.
  Review SHA-256 `a6e787f4e0f444143abc8b8b7d32360125bb3215d62b774d66bf32d9424f9715`;
  route JSON `d7dadeadf9f6bed9939a62fa59ea60ad276ad80290641f934d941070b2beb09e`.

- Independent Lightning01 review **retains** current tuning without requiring
  another native attempt. The completed run is a defeat at T6/clock105, with
  boss 45 HP: 148 events, 14 cards, 59 total enemy HP damage and 32 useful
  defense. Its loss, helper-finishing error, assumed summoned-kill refund,
  skill misunderstandings, shallow retreat and unused Draught do not establish
  difficulty. In the recorded first cycle, all 11 ordinary F3 endpoints at
  T2 remain reachable by live Lash; all 16 at T3 remain inside Overload's
  live range. The early Pass plus useful guard and later dedicated Call
  guard supply repeated costs. There is fair precommit T6 counterplay:
  Frost on the publicly Chilled, nonimmune boss then discounted Cinch
  freezes/skips Lash, gives 7 Block and returns at104 before Overload105.
  The two possible Wisp shots fit the available defense/HP budget. This is
  a static, source-grounded alternative, not a native replay or a guaranteed
  winning policy. Frozen evidence is in
  `/private/tmp/dragon-pressure-native/zekarion-01-complete/`.

## Current completion boundary

All six dragons now have completed natural-build native fights and bounded
independent **retain** verdicts: Fire01, Earth02, Ice02, Air01, Lightning01
and Noct02. Five finish in victory; Lightning finishes in defeat, with fair
precommit counterplay checked separately and its pilot mistakes excluded.
These studies establish the observed choices, not all builds, boss orders,
optimal play or a corrected native Lightning victory.

The final integrated suite, focused mechanics and changed warning renderer
checks pass on production `cf826c8fb`. The closing commit changes only review
and inspection documentation; no further runtime test is warranted by those
text edits. Final exact-HEAD independent signoff and all eight generated,
reload-verified fixture handoffs are recorded outside the worktree in
`/private/tmp/dragon-pressure-inspection/v3/final-handoff.json`, so their
post-commit certification does not alter the reviewed HEAD. The inspection
[guide](dragon_pressure_inspection_20260928.md) contains each reset command.
Publication remains subject to the user's inspection and explicit approval.
