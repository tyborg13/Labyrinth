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
  an input bug workaround and Fatigue; independent difficulty review is pending.
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

## Current completion boundary

Noct02 and Earth01 have complete native outcomes; Earth difficulty review is
pending. Fire01 is resuming for later-cycle assessment, followed by Ice, Air
and Lightning. Remaining native acceptance, a stable commit, exact-HEAD
independent review and eight final reset/reload fixtures are still required.
The prior full regression passed; the new targeting repair needs its integrated
verification. No push, landing or cleanup is authorized.
