**Medium — moss candidates introduce unnecessary redraws during actor movement.** The [new candidate]( /private/tmp/labyrinth_codex/review/bug-01-5b12d3630/scripts/combat_board_view.gd:3686) reaches a [movement guard](/private/tmp/labyrinth_codex/review/bug-01-5b12d3630/scripts/combat_board_view.gd:3641) that compares only moving actors, ignoring stationary actors already fixing the effective opacity.

Reproduction: moss pillar `(6,6)`, stationary hero `(5,6)`, warden moving from `(6,5)` toward `(5,5)`. Submit interpolation at **15% then 20%**, retaining draw tile `(6,5)`. Body and moss alpha both remain **0.32**, yet pillar `(6,6)` is queued. Removing only `candidates.append(moss)` eliminates that redraw. The [negative regression fails at HEAD](/private/tmp/bug_01_rereview2_evidence/actor_negative_head.log) and [passes without the candidate](/private/tmp/bug_01_rereview2_evidence/actor_negative_without_moss_candidate.log).

Fix: compare complete previous/next effective tint during movement, including unchanged actors and objects. Add this negative regression alongside a positive moss-only opacity transition.

Other verification:

- Original brazier reproduction now queues both onset and removal.
- Shared helper matches old drawing across **600 cases**, including texture, rectangle, tint, profile and flip argument.
- Four focused programs pass; dump-enabled floor passes **106 cases, 163,253 checks**.
- [Mutations](/private/tmp/bug_01_rereview2_evidence/mutations.json): **3 caught, 0 survived**—candidate removal fails exactly the two new moss checks; flip and moss-eligibility mutations fail the independent oracle.
- No new typed-array violations, production tunables, dead runtime code or stray files found. Quarantine unchanged. All mutations restored; checkout clean.
- Full Godot/Python results reviewed from the handoff, not independently rerun. No windowed runs.

CHANGES REQUESTED