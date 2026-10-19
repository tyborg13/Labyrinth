# rr-16 feedback 1 (director, from the Codex re-review at ae4d86b8f)

The seven original findings are fixed (verified). Two remain; both are generic-tool robustness, with no visual change.
Review: `/private/tmp/labyrinth_codex/review/rr-16-ae4d86b8f.md`; evidence `/private/tmp/rr16-review-proof/`
(`mode-runtime.log`, `curved-reach.json`, `review.json`).

1. **Rotation-only tracks keep support modes** (`tools/humanoid_cutout/compiler.py:83`). A numeric track of any channel
   must not make the compiler omit the effective `forward_mode` support metadata. Regression: adding a zero-valued
   `foot_near.lean_deg` channel to a clip with a `body` support leaves both views' compiled output byte-identical (the
   review saw the foot move (20,31) → (20,30)).
2. **Reach minimum on curved paths** (`tools/humanoid_cutout/reach.py:69`). The chord between two samples bounds the
   path only when the target moves along a straight segment in that interval. When any contributing channel is
   nonlinear there (smoothstep, or mixed interpolations), use a conservative bound instead: always subdivide the
   interval down to 1e-6 phase where the sampled distances come within the chain's (L1 + L2) × the interval's maximum
   per-step motion of the minimum, or another bound you prove is conservative. Keep chord pruning only for intervals
   proven linear. Regression: the review's 40/20 chain with mixed linear and smoothstep translations between .5001 and
   .5009 fails with the true minimum (23.113 px at .500730940, below 24). The current Thrall data still passes with the
   same documented overreach list.

Proof: the rr-16 focused tests and regressions, the rr11/rr15 gates, the Seer rr10 set, and a mutation for each fix
(guard removed → caught). Thrall and Seer compiled output unchanged. No full suites, no windowed runs.
