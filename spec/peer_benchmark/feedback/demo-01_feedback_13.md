# demo-01 — round 13 (delta review 4d01206d9)

The reviewer is right that my 'separated by >= peak width' clause lets two distinct hits 11 ms apart pass as one. Drop the distance veto between distinct local maxima; deduplicate flat plateaus only. Add the reviewer's broad-cue regressions for locate() and audit(), fix the README. Full finding: /private/tmp/labyrinth_codex/review/demo-01-4d01206d9.md

Focused tests only; do not commit.
