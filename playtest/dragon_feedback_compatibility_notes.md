# Dragon feedback integrated compatibility repair

Root assigned this worker seven failures from the normal exit-1 integrated run
`dragon-boss-encounters-milestone-rewards-1790534298746688000-30940` (40 total).
The other 33 failures belong to the reward/NPC worker's separate scope.
No production change or Godot launch was made during this triage; root was playing
native Zekarion. These are authored test corrections, not independent signoff.

| Failure | Cause and retained contract |
| --- | --- |
| Specialist count and two Zekarion Shock checks | Overload retains save ID `tempest_breath`, but now snapshots and consumes Electrified ground with no conduction. Wisp's reusable, conduction-dependent Shock assertions remain. Surface review names the exact Wisp specialist and verifies Zekarion's separate policy; enemy acceptance resolves a real committed Overload and checks damage, no Shock, disconnected charges, exact consumption, escape and Ice replacement. |
| Tempest Breath range 3 | The obsolete range-based corner test is replaced by a nonempty announced Overload: occupied/disconnected charges are dangerous; an uncharged corner and charge added after declaration stay safe; consumption and replacement agree with the warning. |
| Boss entry y=122 and header height≤110 | The authored header now includes a 32px status row, giving height134 and board top156. Tests retain width/aspect/rail/title/utility/hand exclusions and add status containment and four-pixel board clearance. The existing boss visual probe gets the same contract. |
| Generic routing exclusion | This failure comes from Tharokh, not Zekarion. Bedrock Breath now supports ranged delivery. The test asserts its breath clip and retains exclusions for non-actions and unrelated actor types; the existing committed-AoE breath assertion remains. |

Changed test boundaries: `tests/suites/surface_core_review_suite.gd` specialist
audit; `tests/suites/enemy_surface_acceptance_suite.gd` specialist/Overload tests;
`tests/suites/actor_presentation_suite.gd` normal entry; `tests/suites/tharokh_cutout_suite.gd`
routing; `tests/run_tests.gd` Overload and debug boss fixture functions plus the
renamed invocation; `tests/dragon_boss_probe.gd` header contract. Shared reward,
campfire, Pass and Man functions are outside this worker's edits.

Validation: `git diff --check` passes. The presentation worker independently
reviewed the seven corrected contracts and found no blocking issue or unsafe
new typed-array assignments. The complete integrated rerun passed with exit 0
in `dragon-boss-encounters-milestone-rewards-1790536614403264000-33594`;
the cutout worker inspected its `godot.log` and `TEST RESULT: PASS`. This covers
the listed suites and both `run_tests.gd` functions. The expected legacy
conversion warning and ObjectDB cleanup warning are recorded, with no ERROR
or test failure. These test-only edits do not alter the final cutout source
closure. This is scoped validation of test compatibility, not a branch-wide
or Windows-export certification.
