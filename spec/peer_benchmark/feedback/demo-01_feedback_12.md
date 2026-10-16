# demo-01 — round 12 (delta review 4401ec2da: one Medium)

Repeated-cue ambiguity is still bypassable (seed 7: the sparse shortlist drops a competitor before the guard). Make the
rule conservative and simple: compute the dense correlation over the whole search window; if ANY second peak (separated
by ≥ the cue's own peak width) reaches ≥ 0.5 correlation, the row is `unmeasured (ambiguous)`. No shortlist before the
guard. Add the seed-7 regression and a sweep over overlap seeds 1–20 asserting no false measured offset. Focused tests
only; do not commit. The sync table stays informational.
