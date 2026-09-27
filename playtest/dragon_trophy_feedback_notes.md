# Dragon trophy feedback iteration

Scope: Winter's Hourglass (`winters_hour`) and Stormroad Coil, following the
user's feedback that Freeze was too rare and Stormroad did not supply its named
relay fantasy. Stable IDs, icon identities and acquisition sources are retained.

Hourglass now rewards Ice/non-Ice sequencing: first Ice card each activation
banks 3 Time, capped at 3, and non-Ice cards spend only what reduces actual Time
to a floor of 1. Reserve persists for this combat and appears on the relic badge;
card badges and forecasts show actual discounted Time. The cost tooltip names
the amount consumed. Free Borrowed Time preserves it.

Coil adds one automatic visible Electrified relay to single-target ranged
actions. Both legs use normal range and LOS; direct contact wins. A deterministic
shared helper serves legal targets, preview and commit, including any clickable
large-body square. The action trace supplies the two explicit visual legs. This
does not consume ground, add damage, create targeting steps, or extend melee and
AOE. Native Chain/conduction remain downstream mechanics.

Acceptance/proof: focused logic checks cover immutable exact previews, save and
activation boundaries, free-card interaction, source events, blocked legs,
ownership, no network amplification, footprints and identical commit results.
Fresh 1920x1080 at 100% visual proof must show readable counter/cost updates,
both preview/animation legs, reduced motion, and exact rules text. Verification completed through the shared Godot launch lease.

Balance rationale is paired in spec/card_balance_heuristic.md and the scorer
encounter assumptions. Conditional trophy value is excluded from intrinsic card
scores; bank production is capped at 3 per activation and relay reach at 2R
before existing Chain/conduction. Instrumentation is additive in analytics.md;
persistence uses the existing combat checkpoint and activation flags.


## Verification and inspected proof

`tests/dragon_trophy_feedback_test.gd`: PASS through the task runner. Card costs
and reserve are identical across save/reload and preview/commit. The test covers
first-Ice once-per-activation behavior, within-combat carry, Time-one floor,
Borrowed Time, discard exclusion, source events, both LOS legs, range ceiling,
direct-shot preference, ownership, non-ranged exclusion and large-body contact.
The JSON files parse and both new scorer context fields load.

`tests/dragon_trophy_feedback_probe.gd`: final v3 PASS, ten real Metal renderer
PNGs at 1920x1080 and 100% UI scale, copied to
`/private/tmp/dragon-trophy-feedback-proof-v3`. Every final PNG was viewed at
original resolution. The fixture is a focused interaction scene (four ordinary
cards, 20/24 HP, 12-HP Crawler, two trophies), not a boss balance/fun result.
Actual card selection/confirmation plays Frostbolt and Pale Spark; the visible
reserve changes 0 → 3 → 1, hand Time changes immediately, and the initiative
preview reports Pale Spark +1. The target remains a single choice with both
purple ground route segments, then two real projectile beats. Reduced motion
keeps exact targeting/payment and returns usable input. Rules tooltips fit with
large existing body typography, correct Time/Electrified icon identities, and
a visible 3/3 reserve.

The initial probe accidentally inspected RunScene's unrelated stored
presentation instead of the live board; v2 corrected that and passed. Pixel
review then found the probe-mounted tooltips were below RunScene's CanvasLayer
and the test cursor was at the viewport origin; v3 fixed the proof mounting and
used a native viewport mouse motion. Neither issue required gameplay changes.

Rubric: immediate comprehension, visual hierarchy, gameplay visibility, precise
rules/state/consequence, interaction completeness, visual cohesion, accessibility,
layout resilience, and visual proof PASS. Existing hourglass/coil art, Time card
badges, tooltip panels, ground arcs, projectile feedback, and all input/target
confirmation paths are reused. No icon registry change. Independent exact-HEAD
review, broader regression and resettable user inspection remain root-owned.

Commands from the task worktree:

```sh
python3 tools/godot_task_runner.py --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --stream -- godot --headless --path . --script tests/dragon_trophy_feedback_test.gd
python3 tools/visual_probe_runner.py tests/dragon_trophy_feedback_probe.gd --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --no-headless --display-driver macos --audio-driver Dummy --timeout 60 --expect-size 1920x1080 --min-images 10
```

The bounded 60-second probe allowance covers ten captures, two complete real
card presentation paths, native tooltip layout and reduced-motion replay.

Final static interaction review found Worldroot's remote-origin payment could
follow Coil's delivery origin. The payment now retains the original validated
action while relay routing is selected from the pre-payment snapshot. A focused
stacked-ground regression was added: remote Rubble is consumed, relay Rubble and
both Electrified tiles remain, and preview equals commit. This interaction check
passes in the focused trophy rerun recorded below; it does not change the
ordinary two-leg visual path inspected above.

## Bent relay displacement regression

The subsequent static interaction review found that Chain forecast primary Push
from the player while commitment used Coil's delivery origin. With actual Razor
Gale and Brightglass Lens, a player at (1,2) relays through (2,3) to a lit enemy
at (4,3). Commitment pushes that enemy to (4,2); the old forecast predicted
(5,3). It therefore incorrectly hit a second enemy at (6,3), or missed a legal
second enemy at (4,1). The planner now uses the resolved `_origin_tile`, matching
commitment and retaining the existing player fallback for direct attacks.

`_test_relay_force_chain` checks both layouts' actual HP, displaced position and
route geometry, immutable preview/commit equality, and an unchanged direct
route with/without Coil ownership. A controlled baseline run temporarily
restored only the old forecast expression and failed exactly the four expected
follow-up HP/trace-count assertions. The corrected expression was restored
automatically; the focused trophy, Chain, board surface and surface relic tests
then passed. The standalone dragon reward suite also passed; its error output
is the expected deliberately blocked persistence/outbox recovery coverage.
No renderer claim is made for this new bent-route fixture.

All runs used `tools/godot_task_runner.py`, task ID
`dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange`, sequentially
under the explicit Godot lease. Full runner logs reside at
`/private/tmp/labyrinth-godot-home/<run-id>/godot.log`; copied transcripts are
listed below.

| Check | Run ID | Transcript |
| --- | --- | --- |
| Old forecast, expected exit 1 | `dragon-boss-encounters-milestone-rewards-1790532313737277000-28275` | `/private/tmp/dragon-relay-chain-baseline.txt` |
| Trophy, exit 0 | `dragon-boss-encounters-milestone-rewards-1790532349034508000-28390` | `/private/tmp/dragon-relay-fixed-dragon_trophy_feedback_test.gd.txt` |
| Chain, exit 0 | `dragon-boss-encounters-milestone-rewards-1790532349735137000-28392` | `/private/tmp/dragon-relay-fixed-chain_attack_test.gd.txt` |
| Board surface, exit 0 | `dragon-boss-encounters-milestone-rewards-1790532350327837000-28394` | `/private/tmp/dragon-relay-fixed-board_surface_core_test.gd.txt` |
| Surface relic, exit 0 | `dragon-boss-encounters-milestone-rewards-1790532351039477000-28396` | `/private/tmp/dragon-relay-fixed-surface_relic_test.gd.txt` |
| Dragon rewards, exit 0 | `dragon-boss-encounters-milestone-rewards-1790532351673761000-28398` | `/private/tmp/dragon-relay-fixed-dragon_rewards_test.gd.txt` |

The separate presentation worker inspected the narrow code/test change, expected
baseline failures and corrected passes, and supplied scoped signoff with no
findings. Its scope includes the accompanying text-only combat log correction
to “Crystal Mantle layers”; it is not final branch or exact-HEAD signoff. The
cutout worker released the Godot lease after final session 65004 exited 0; no
files were staged or committed by that worker.


## Inline icon copy addendum — 2026-09-27

The integrated description audit found four real omissions: the Hourglass's Ice
and Time terms and Coil's Ranged and Range terms bypassed established inline
icons. Only the two description strings changed. The Hourglass uses `element_ice`,
which is distinct from `surface_ice`; other terms use `time`, `ranged` and `range`.
Effects, values, targeting and icon registries are unchanged.

Fresh native proof `output/dragon-revision/trophy-icons-04.json` exited 0 and
validated all ten 1920×1080 / 100% images, with `DRAGON TROPHY FEEDBACK PROOF: PASS`.
All ten were inspected at original resolution. Both rules panels fit completely,
show the correct inline identities, and retain exact timing/range/visibility
limits. The counter still moves 0 → 3 → 1, card Time reflects payment, the relay
has two legs, and the reduced-motion path preserves the same reserve payment.
This remains a staged interaction proof rather than encounter-balance evidence.

The presentation worker independently compared the two description replacements
against the trophy rules and inspected both updated rule-panel PNGs at original
resolution. Scoped copy and pixel approval found no clipping, identity error or
changed mechanic. This is not final exact-HEAD whole-branch review.

Runner namespace:
`dragon-trophy-icons-04-1790536501586954000-33378-dragon_trophy_feedback_p-1`.
Stable copied images: `/private/tmp/dragon-trophy-icons-proof-04`.

```sh
python3 tools/visual_probe_runner.py tests/dragon_trophy_feedback_probe.gd --task-id dragon-trophy-icons-04 --no-headless --rendering-method mobile --rendering-driver metal --min-images 10 --expect-size 1920x1080 --result-manifest output/dragon-revision/trophy-icons-04.json
```

The corrected full integrated suite subsequently passed, runner exit 0, under
`dragon-boss-encounters-milestone-rewards-1790536614403264000-33594`. This includes
the unchanged description-icon audit; all four omissions are resolved. The
cutout reviewer independently confirmed the exact before/after token-only diff,
the two original-resolution rules images, and the accepted native receipt.
