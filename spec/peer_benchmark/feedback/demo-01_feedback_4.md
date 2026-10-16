# demo-01 — round 4 (comparison policy decision)

Decision: the native take may only lag the headless run, never lead, and lag may grow by at most 2 frames total.
Rule: after pairing events/rows by order (identical kinds, payloads and states), the per-item offset
(native frame − headless frame) must be in [0, 2] and non-decreasing over time. Fire Volley (+0 at startup, +1 from the
first cue on) passes. Report each clip's offset profile (first frame where the offset changes, and to what) in the
record/compare reports. Anything else still fails. Focused tests + validate only; do not commit; same windowed list.
